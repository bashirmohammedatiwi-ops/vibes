import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingOrigin, BookingStatus, OfferStatus, PaymentStatus, ShiftType } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PaginationService } from '../../common/services/query-helpers';
import { summarizeCoverage } from '../../common/utils/coverage.util';
import { bookingDaysConflict, resolveBookingMode } from '../../common/utils/shift.util';
import { resolveBookingShift } from '../../common/utils/pricing.util';
import { PrismaService } from '../../prisma/prisma.service';

const ACTIVE_STATUSES: BookingStatus[] = [
  BookingStatus.PENDING,
  BookingStatus.AWAITING_PAYMENT,
  BookingStatus.CONFIRMED,
];

/**
 * Provider self-service portal: every query is force-scoped to properties
 * owned by the authenticated provider — there is no way to address another
 * provider's property, booking or revenue.
 */
@Injectable()
export class ProviderPortalService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
  ) {}

  private async requireProvider(user: AuthUser) {
    const provider = await this.prisma.provider.findUnique({ where: { userId: user.id } });
    if (!provider) throw new ForbiddenException('هذا الحساب ليس مزوداً');
    return provider;
  }

  /** Returns the provider id, verifying the property belongs to them. */
  async assertOwnedProperty(user: AuthUser, propertyId: string) {
    const provider = await this.requireProvider(user);
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: { provider: { select: { userId: true } } },
    });
    if (!property || property.provider?.userId !== user.id) {
      throw new NotFoundException('المكان غير موجود');
    }
    return { provider, property };
  }

  properties(user: AuthUser) {
    return this.prisma.provider
      .findUnique({ where: { userId: user.id } })
      .then((provider) => {
        if (!provider) throw new ForbiddenException('هذا الحساب ليس مزوداً');
        return this.prisma.property.findMany({
          where: { providerId: provider.id },
          include: {
            city: { select: { nameAr: true } },
            media: { where: { isPrimary: true }, take: 1, select: { url: true } },
            _count: { select: { bookings: true, reviews: true } },
          },
          orderBy: { updatedAt: 'desc' },
        });
      });
  }

  async overview(user: AuthUser) {
    const provider = await this.requireProvider(user);
    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);

    const [propertyCount, activeBookings, pendingBookings, monthAgg, upcoming, followersCount, pendingOffers, coverage] =
      await Promise.all([
      this.prisma.property.count({ where: { providerId: provider.id } }),
      this.prisma.booking.count({
        where: { property: { providerId: provider.id }, status: { in: ACTIVE_STATUSES } },
      }),
      this.prisma.booking.count({
        where: { property: { providerId: provider.id }, status: BookingStatus.PENDING },
      }),
      this.prisma.booking.aggregate({
        where: {
          property: { providerId: provider.id },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
          createdAt: { gte: monthStart },
        },
        _sum: { totalPrice: true },
        _count: true,
      }),
      this.prisma.booking.findMany({
        where: { property: { providerId: provider.id }, status: { in: ACTIVE_STATUSES }, startDate: { gte: new Date() } },
        include: { property: { select: { name: true } }, user: { select: { name: true, phone: true } } },
        orderBy: { startDate: 'asc' },
        take: 6,
      }),
      this.prisma.providerFollow.count({ where: { providerId: provider.id } }),
      this.prisma.priceOffer.count({
        where: { providerId: provider.id, status: OfferStatus.PENDING },
      }),
      this.coverage(provider.id),
    ]);

    return {
      propertyCount,
      activeBookings,
      pendingBookings,
      monthRevenue: monthAgg._sum.totalPrice ?? 0,
      monthBookings: monthAgg._count,
      upcoming,
      followersCount,
      pendingOffers,
      coverage,
    };
  }

  async bookings(user: AuthUser, query: Record<string, string | undefined>) {
    const provider = await this.requireProvider(user);
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where = {
      property: { providerId: provider.id },
      ...(query.status ? { status: query.status as BookingStatus } : {}),
      ...(query.propertyId ? { propertyId: query.propertyId } : {}),
      ...(query.origin === 'EXTERNAL' || query.origin === 'PLATFORM'
        ? { origin: query.origin as BookingOrigin }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        include: {
          user: { select: { name: true, phone: true } },
          property: { select: { id: true, name: true } },
          payment: { select: { status: true, method: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.booking.count({ where }),
    ]);
    return this.pagination.wrap(items, total, page, pageSize);
  }

  async bookingDetail(user: AuthUser, bookingId: string) {
    await this.requireProvider(user);
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        user: { select: { name: true, phone: true } },
        property: {
          select: { id: true, name: true, providerId: true },
        },
        payment: true,
      },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    const property = await this.prisma.property.findUnique({
      where: { id: booking.propertyId },
      include: { provider: { select: { userId: true } } },
    });
    if (property?.provider?.userId !== user.id) {
      throw new NotFoundException('الحجز غير موجود');
    }
    return booking;
  }

  /** Monthly revenue + bookings for the last N months (confirmed & completed). */
  async revenue(user: AuthUser, months = 6) {
    const provider = await this.requireProvider(user);
    const since = new Date();
    since.setMonth(since.getMonth() - (months - 1));
    since.setDate(1);
    since.setHours(0, 0, 0, 0);

    const bookings = await this.prisma.booking.findMany({
      where: {
        property: { providerId: provider.id },
        status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        payment: { status: PaymentStatus.PAID },
        createdAt: { gte: since },
      },
      select: { totalPrice: true, createdAt: true },
    });

    const buckets = new Map<string, { revenue: number; bookings: number }>();
    for (let i = 0; i < months; i++) {
      const d = new Date(since);
      d.setMonth(since.getMonth() + i);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      buckets.set(key, { revenue: 0, bookings: 0 });
    }
    for (const booking of bookings) {
      const d = new Date(booking.createdAt);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      const bucket = buckets.get(key);
      if (bucket) {
        bucket.revenue += Number(booking.totalPrice);
        bucket.bookings += 1;
      }
    }
    return Array.from(buckets.entries()).map(([month, value]) => ({ month, ...value }));
  }

  async createExternal(
    user: AuthUser,
    dto: {
      propertyId: string;
      startDate: string;
      endDate?: string;
      shift?: ShiftType;
      guestName?: string;
      guestPhone?: string;
      guests?: number;
      totalPrice?: number;
      notes?: string;
    },
  ) {
    const { property } = await this.assertOwnedProperty(user, dto.propertyId);
    const start = new Date(`${dto.startDate}T00:00:00.000Z`);
    const end = dto.endDate
      ? new Date(`${dto.endDate}T00:00:00.000Z`)
      : new Date(start.getTime() + 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('تواريخ الحجز غير صالحة');
    }

    const mode = resolveBookingMode(property.type, property.bookingMode);
    const shift = resolveBookingShift(mode, dto.shift);

    const active = await this.prisma.booking.findMany({
      where: {
        propertyId: property.id,
        status: { in: ACTIVE_STATUSES },
        startDate: { lt: end },
        endDate: { gt: start },
      },
    });
    for (const existing of active) {
      if (bookingDaysConflict(start, end, shift, existing.startDate, existing.endDate, existing.shift)) {
        throw new BadRequestException('هذه التواريخ محجوزة مسبقاً');
      }
    }

    return this.prisma.booking.create({
      data: {
        propertyId: property.id,
        startDate: start,
        endDate: end,
        shift,
        guests: dto.guests ?? 1,
        status: BookingStatus.CONFIRMED,
        origin: BookingOrigin.EXTERNAL,
        guestName: dto.guestName?.trim() || 'ضيف خارجي',
        guestPhone: dto.guestPhone?.trim() || null,
        totalPrice: dto.totalPrice ?? 0,
        notes: dto.notes?.trim() || 'حجز خارجي سجّله المالك',
      },
      include: {
        property: { select: { id: true, name: true } },
        user: { select: { name: true, phone: true } },
      },
    });
  }

  async cancelExternal(user: AuthUser, bookingId: string) {
    const booking = await this.bookingDetail(user, bookingId);
    if (booking.origin !== BookingOrigin.EXTERNAL) {
      throw new BadRequestException('يمكن إلغاء الحجوزات الخارجية فقط من هنا');
    }
    if (booking.status === BookingStatus.CANCELLED) {
      return booking;
    }
    return this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: BookingStatus.CANCELLED },
      include: {
        property: { select: { id: true, name: true } },
        user: { select: { name: true, phone: true } },
      },
    });
  }

  private async coverage(providerId: string) {
    const horizon = 30;
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + horizon);

    const properties = await this.prisma.property.findMany({
      where: { providerId },
      select: { id: true },
    });
    const propertyIds = properties.map((p) => p.id);

    const [bookings, slots] = await Promise.all([
      propertyIds.length
        ? this.prisma.booking.findMany({
            where: {
              propertyId: { in: propertyIds },
              status: { in: ACTIVE_STATUSES },
              startDate: { lt: end },
              endDate: { gt: start },
            },
            select: { propertyId: true, startDate: true, endDate: true, origin: true },
          })
        : Promise.resolve([]),
      propertyIds.length
        ? this.prisma.availabilitySlot.findMany({
            where: {
              propertyId: { in: propertyIds },
              isAvailable: false,
              date: { gte: start, lt: end },
            },
            select: { propertyId: true, date: true },
          })
        : Promise.resolve([]),
    ]);

    return summarizeCoverage({
      horizon,
      propertyIds,
      bookings,
      closed: slots,
    });
  }
}
