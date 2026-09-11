import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, PaymentMethod, PaymentStatus, Prisma, PropertyType, ShiftType, UserRole } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CouponService } from '../../common/services/coupon.service';
import { NotificationService } from '../../common/services/notification.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PaginationService } from '../../common/services/query-helpers';
import { calculateBookingTotal, resolveBookingShift, type PriceRuleLike } from '../../common/utils/pricing.util';
import { bookingDaysConflict, resolveBookingMode } from '../../common/utils/shift.util';
import { PrismaService } from '../../prisma/prisma.service';
import {
  AdminBookingQuoteDto,
  AdminBulkBookingsDto,
  AdminCreateBookingDto,
  AdminRescheduleBookingDto,
} from './dto/admin-common.dto';

const bookingInclude = {
  user: { select: { id: true, name: true, phone: true } },
  property: {
    select: {
      id: true,
      name: true,
      type: true,
      slug: true,
      city: { select: { nameAr: true } },
    },
  },
  payment: true,
};

@Injectable()
export class AdminBookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly activity: ActivityLogService,
    private readonly notifications: NotificationService,
    private readonly coupons: CouponService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.BookingWhereInput = {};

    if (query.status) where.status = query.status as BookingStatus;
    if (query.propertyId) where.propertyId = query.propertyId;
    if (query.q) {
      where.OR = [
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
        { property: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    if (query.from || query.to) {
      where.startDate = {};
      if (query.from) where.startDate.gte = new Date(query.from);
      if (query.to) where.startDate.lte = new Date(query.to);
    }
    if (query.shift) where.shift = query.shift as ShiftType;
    if (query.paymentStatus || query.paymentMethod) {
      where.payment = {
        ...(query.paymentStatus ? { status: query.paymentStatus as PaymentStatus } : {}),
        ...(query.paymentMethod ? { method: query.paymentMethod as PaymentMethod } : {}),
      };
    }

    const [items, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        include: bookingInclude,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.booking.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  getOne(id: string) {
    return this.prisma.booking
      .findUnique({
        where: { id },
        include: {
          ...bookingInclude,
          property: {
            include: {
              city: { include: { province: true } },
              media: { where: { isPrimary: true }, take: 1 },
            },
          },
        },
      })
      .then((booking) => {
        if (!booking) throw new NotFoundException('الحجز غير موجود');
        return booking;
      });
  }

  async updateStatus(user: AuthUser, id: string, status: BookingStatus, adminNote?: string) {
    const booking = await this.getOne(id);
    const paymentStatus =
      status === BookingStatus.CONFIRMED || status === BookingStatus.COMPLETED
        ? PaymentStatus.PAID
        : undefined;

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status,
        notes: adminNote ? [booking.notes, adminNote].filter(Boolean).join('\n') : booking.notes,
        payment: paymentStatus
          ? { update: { status: paymentStatus } }
          : undefined,
      },
      include: bookingInclude,
    });

    await this.activity.log({
      userId: user.id,
      action: 'booking.status',
      entityType: 'booking',
      entityId: id,
      metadata: { status, previous: booking.status },
    });

    await this.notifications.notifyBookingEvent({ id: updated.id, status: updated.status, propertyId: updated.propertyId }, 'status');

    return updated;
  }

  private loadActiveRules(propertyId: string) {
    return this.prisma.priceRule
      .findMany({ where: { propertyId, isActive: true } })
      .then((rules) => rules as PriceRuleLike[]);
  }

  private resolveShift(
    property: { type: PropertyType; bookingMode?: string | null },
    shift?: ShiftType,
  ) {
    const mode = resolveBookingMode(property.type, property.bookingMode);
    return resolveBookingShift(mode, shift);
  }

  private async checkAvailability(
    propertyId: string,
    start: Date,
    end: Date,
    shift: ShiftType,
    excludeBookingId?: string,
  ) {
    const activeBookings = await this.prisma.booking.findMany({
      where: {
        propertyId,
        ...(excludeBookingId ? { id: { not: excludeBookingId } } : {}),
        status: { in: [BookingStatus.PENDING, BookingStatus.AWAITING_PAYMENT, BookingStatus.CONFIRMED] },
        startDate: { lt: end },
        endDate: { gt: start },
      },
    });

    for (const existing of activeBookings) {
      if (bookingDaysConflict(start, end, shift, existing.startDate, existing.endDate, existing.shift)) {
        return { available: false as const, conflict: existing };
      }
    }
    return { available: true as const };
  }

  async quote(dto: AdminBookingQuoteDto) {
    const property = await this.prisma.property.findUnique({ where: { id: dto.propertyId } });
    if (!property || property.status !== 'APPROVED') {
      throw new NotFoundException('المكان غير موجود أو غير منشور');
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('تواريخ الحجز غير صالحة');
    }

    const shift = await this.resolveShift(property, dto.shift);
    const availability = await this.checkAvailability(dto.propertyId, start, end, shift, dto.excludeBookingId);

    const [rules, slots] = await Promise.all([
      this.loadActiveRules(dto.propertyId),
      this.prisma.availabilitySlot.findMany({
        where: { propertyId: dto.propertyId, date: { gte: start, lt: end } },
      }),
    ]);

    const baseTotal = calculateBookingTotal(property, rules, start, end, slots, shift);
    const nights = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));

    let discount = 0;
    let couponCode: string | null = null;
    if (dto.couponCode?.trim()) {
      const validation = await this.coupons.validate(dto.couponCode, property, baseTotal);
      discount = validation.discount;
      couponCode = validation.coupon.code;
    }

    return {
      available: availability.available,
      totalPrice: baseTotal - discount,
      originalTotal: baseTotal,
      discount,
      couponCode,
      nights,
      shift,
      capacity: property.capacity,
    };
  }

  async reschedule(staff: AuthUser, id: string, dto: AdminRescheduleBookingDto) {
    const booking = await this.getOne(id);
    if ([BookingStatus.CANCELLED, BookingStatus.COMPLETED].includes(booking.status as never)) {
      throw new BadRequestException('لا يمكن إعادة جدولة هذا الحجز');
    }

    const property = await this.prisma.property.findUnique({ where: { id: booking.propertyId } });
    if (!property) throw new NotFoundException('المكان غير موجود');

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('تواريخ الحجز غير صالحة');
    }

    const shift = await this.resolveShift(property, dto.shift ?? booking.shift);
    const availability = await this.checkAvailability(booking.propertyId, start, end, shift, id);
    if (!availability.available) {
      throw new BadRequestException('هذه التواريخ أو الشفت محجوز');
    }

    const [rules, slots] = await Promise.all([
      this.loadActiveRules(booking.propertyId),
      this.prisma.availabilitySlot.findMany({
        where: { propertyId: booking.propertyId, date: { gte: start, lt: end } },
      }),
    ]);
    const totalPrice = calculateBookingTotal(property, rules, start, end, slots, shift);

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        startDate: start,
        endDate: end,
        shift,
        totalPrice,
        notes: dto.adminNote ? [booking.notes, dto.adminNote].filter(Boolean).join('\n') : booking.notes,
        payment: { update: { amount: totalPrice } },
      },
      include: bookingInclude,
    });

    await this.activity.log({
      userId: staff.id,
      action: 'booking.reschedule',
      entityType: 'booking',
      entityId: id,
      metadata: { startDate: dto.startDate, endDate: dto.endDate, shift },
    });

    return updated;
  }

  async bulkUpdateStatus(staff: AuthUser, dto: AdminBulkBookingsDto) {
    const results = [];
    for (const id of dto.ids) {
      try {
        const updated = await this.updateStatus(staff, id, dto.status, dto.adminNote);
        results.push({ id, ok: true, booking: updated });
      } catch (err) {
        results.push({ id, ok: false, error: err instanceof Error ? err.message : 'failed' });
      }
    }
    return { updated: results.filter((r) => r.ok).length, failed: results.filter((r) => !r.ok).length, results };
  }

  private async findOrCreateCustomer(phone: string, name?: string) {
    const normalized = phone.replace(/\s+/g, '');
    let user = await this.prisma.user.findUnique({ where: { phone: normalized } });
    if (!user) {
      user = await this.prisma.user.create({
        data: { phone: normalized, name: name?.trim() || null, role: UserRole.CUSTOMER },
      });
    } else if (name?.trim() && !user.name) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { name: name.trim() },
      });
    }
    return user;
  }

  async create(staff: AuthUser, dto: AdminCreateBookingDto) {
    const property = await this.prisma.property.findUnique({ where: { id: dto.propertyId } });
    if (!property || property.status !== 'APPROVED') {
      throw new NotFoundException('المكان غير موجود أو غير منشور');
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('تواريخ الحجز غير صالحة');
    }

    const shift = await this.resolveShift(property, dto.shift);
    const availability = await this.checkAvailability(dto.propertyId, start, end, shift);
    if (!availability.available) {
      throw new BadRequestException('هذه التواريخ أو الشفت محجوز');
    }

    const [rules, slots] = await Promise.all([
      this.loadActiveRules(dto.propertyId),
      this.prisma.availabilitySlot.findMany({
        where: { propertyId: dto.propertyId, date: { gte: start, lt: end } },
      }),
    ]);

    const baseTotal = calculateBookingTotal(property, rules, start, end, slots, shift);
    const customer = await this.findOrCreateCustomer(dto.customerPhone, dto.customerName);

    let couponValidation: Awaited<ReturnType<CouponService['validate']>> | null = null;
    if (dto.couponCode?.trim()) {
      couponValidation = await this.coupons.validate(dto.couponCode, property, baseTotal, customer.id);
    }
    const totalPrice = couponValidation ? couponValidation.totalAfterDiscount : baseTotal;

    const bookingStatus = dto.confirmImmediately ? BookingStatus.CONFIRMED : BookingStatus.PENDING;
    const paymentStatus = dto.confirmImmediately ? PaymentStatus.PAID : PaymentStatus.PENDING;

    const booking = await this.prisma.$transaction(async (tx) => {
      const created = await tx.booking.create({
        data: {
          userId: customer.id,
          propertyId: dto.propertyId,
          startDate: start,
          endDate: end,
          shift,
          guests: dto.guests ?? 1,
          notes: dto.notes,
          status: bookingStatus,
          totalPrice,
          discountAmount: couponValidation?.discount ?? 0,
          couponId: couponValidation?.coupon.id,
          payment: {
            create: {
              method: PaymentMethod.MANUAL,
              amount: totalPrice,
              status: paymentStatus,
            },
          },
        },
        include: bookingInclude,
      });
      if (couponValidation) {
        await this.coupons.applyToBooking(
          couponValidation.coupon.id,
          created.id,
          customer.id,
          couponValidation.discount,
          tx,
        );
      }
      return created;
    });

    await this.activity.log({
      userId: staff.id,
      action: 'booking.create',
      entityType: 'booking',
      entityId: booking.id,
      metadata: { customerPhone: customer.phone, confirmImmediately: !!dto.confirmImmediately },
    });

    await this.notifications.bookingCreated(booking);
    if (dto.confirmImmediately) {
      await this.notifications.bookingStatus(booking);
    }

    return booking;
  }

  stats() {
    return Promise.all([
      this.prisma.booking.count(),
      this.prisma.booking.count({ where: { status: BookingStatus.PENDING } }),
      this.prisma.booking.count({ where: { status: BookingStatus.CONFIRMED } }),
      this.prisma.booking.count({ where: { status: BookingStatus.COMPLETED } }),
      this.prisma.booking.aggregate({
        where: { status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] } },
        _sum: { totalPrice: true },
      }),
    ]).then(([total, pending, confirmed, completed, revenue]) => ({
      total,
      pending,
      confirmed,
      completed,
      revenue: revenue._sum.totalPrice ?? 0,
    }));
  }
}
