import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, PaymentMethod, PaymentStatus, ShiftType, UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CouponService } from '../../common/services/coupon.service';
import { NotificationService } from '../../common/services/notification.service';
import { MarketplaceLifecycleService } from '../marketplace/marketplace-lifecycle.service';
import { calculateBookingTotal, resolveBookingShift, type PriceRuleLike } from '../../common/utils/pricing.util';
import { bookingDaysConflict, resolveBookingMode } from '../../common/utils/shift.util';
import { PrismaService } from '../../prisma/prisma.service';

export interface CreateBookingDto {
  propertyId: string;
  startDate: string;
  endDate: string;
  shift?: ShiftType;
  guests?: number;
  notes?: string;
  proofUrl?: string;
  couponCode?: string;
}

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
    private readonly coupons: CouponService,
    private readonly lifecycle: MarketplaceLifecycleService,
  ) {}

  async create(user: AuthUser, dto: CreateBookingDto) {
    const property = await this.prisma.property.findUnique({ where: { id: dto.propertyId } });
    if (!property || property.status !== 'APPROVED') {
      throw new NotFoundException('المكان غير موجود');
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (end <= start) {
      throw new BadRequestException('تاريخ النهاية يجب أن يكون بعد البداية');
    }

    const mode = resolveBookingMode(property.type, property.bookingMode);
    const shift = resolveBookingShift(mode, dto.shift);

    const activeBookings = await this.prisma.booking.findMany({
      where: {
        propertyId: dto.propertyId,
        status: { in: [BookingStatus.PENDING, BookingStatus.AWAITING_PAYMENT, BookingStatus.CONFIRMED] },
        startDate: { lt: end },
        endDate: { gt: start },
      },
    });

    for (const existing of activeBookings) {
      if (bookingDaysConflict(start, end, shift, existing.startDate, existing.endDate, existing.shift)) {
        throw new BadRequestException('هذه التواريخ أو الشفت محجوز');
      }
    }

    const [rules, slots] = await Promise.all([
      this.prisma.priceRule.findMany({ where: { propertyId: dto.propertyId, isActive: true } }),
      this.prisma.availabilitySlot.findMany({
        where: {
          propertyId: dto.propertyId,
          date: { gte: start, lt: end },
        },
      }),
    ]);

    const baseTotal = calculateBookingTotal(property, rules as PriceRuleLike[], start, end, slots, shift);

    // Coupon discount is validated against the pre-discount total, then applied
    // atomically together with the booking row.
    let couponValidation: Awaited<ReturnType<CouponService['validate']>> | null = null;
    if (dto.couponCode?.trim()) {
      couponValidation = await this.coupons.validate(dto.couponCode, property, baseTotal, user.id);
    }
    const totalPrice = couponValidation ? couponValidation.totalAfterDiscount : baseTotal;

    const booking = await this.prisma.$transaction(async (tx) => {
      const created = await tx.booking.create({
        data: {
          userId: user.id,
          propertyId: dto.propertyId,
          startDate: start,
          endDate: end,
          shift,
          guests: dto.guests ?? 1,
          notes: dto.notes,
          status: dto.proofUrl ? BookingStatus.AWAITING_PAYMENT : BookingStatus.PENDING,
          totalPrice,
          discountAmount: couponValidation?.discount ?? 0,
          couponId: couponValidation?.coupon.id,
          payment: {
            create: {
              method: PaymentMethod.MANUAL,
              amount: totalPrice,
              proofUrl: dto.proofUrl,
              status: PaymentStatus.PENDING,
            },
          },
        },
        include: { payment: true, property: true, user: true },
      });
      if (couponValidation) {
        await this.coupons.applyToBooking(
          couponValidation.coupon.id,
          created.id,
          user.id,
          couponValidation.discount,
          tx,
        );
      }
      return created;
    });

    await this.notifications.notifyBookingEvent(booking, 'created');
    if (dto.proofUrl && booking.payment) {
      await this.notifications.paymentProof({ id: booking.payment.id, booking });
    }
    await this.lifecycle.afterBookingCreated(booking.id);

    return booking;
  }

  /** حجز واحد بضماناته — يستخدمه صاحبه والفريق وصاحب المكان */
  async getOne(id: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        property: {
          include: {
            city: { include: { province: true } },
            provider: { select: { userId: true } },
            media: { orderBy: { isPrimary: 'desc' }, take: 1, select: { url: true, posterUrl: true } },
          },
        },
        payment: true,
        conversation: { select: { id: true } },
        invoice: { select: { id: true, number: true, status: true } },
        cancellationRequests: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { id: true, status: true, expectedRefund: true, reason: true },
        },
      },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    const [decorated] = await this.attachCanReview(booking.userId, [booking]);
    return decorated;
  }

  async list(user: AuthUser) {
    // Capped: this endpoint predates admin pagination and is still used by
    // the mobile app for "my bookings" / provider views, which never need
    // more than a few hundred rows. Staff should use the paginated
    // /api/admin/bookings endpoint instead.
    const isStaff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    if (isStaff) {
      return this.prisma.booking.findMany({
        include: {
          user: true,
          property: true,
          payment: true,
          conversation: { select: { id: true } },
          invoice: { select: { id: true, number: true, status: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 300,
      });
    }

    if (user.role === UserRole.PROVIDER) {
      return this.prisma.booking.findMany({
        where: { property: { provider: { userId: user.id } } },
        include: {
          user: true,
          property: { include: { city: true } },
          payment: true,
          conversation: { select: { id: true } },
          invoice: { select: { id: true, number: true, status: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 300,
      });
    }

    const mine = await this.prisma.booking.findMany({
      where: { userId: user.id },
      include: {
        property: {
          include: {
            city: true,
            media: { orderBy: { isPrimary: 'desc' }, take: 1, select: { url: true, posterUrl: true } },
          },
        },
        payment: true,
        conversation: { select: { id: true } },
        invoice: { select: { id: true, number: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 300,
    });
    return this.attachCanReview(user.id, mine);
  }

  private async attachCanReview<
    T extends { userId: string | null; propertyId: string; status: BookingStatus },
  >(userId: string | null, bookings: T[]): Promise<Array<T & { canReview: boolean }>> {
    if (!userId) {
      return bookings.map((booking) => ({ ...booking, canReview: false }));
    }
    const completedIds = [
      ...new Set(
        bookings
          .filter((booking) => booking.status === BookingStatus.COMPLETED)
          .map((booking) => booking.propertyId),
      ),
    ];
    const reviewed = new Set(
      completedIds.length
        ? (
            await this.prisma.review.findMany({
              where: { userId, propertyId: { in: completedIds } },
              select: { propertyId: true },
            })
          ).map((review) => review.propertyId)
        : [],
    );
    return bookings.map((booking) => ({
      ...booking,
      canReview:
        booking.status === BookingStatus.COMPLETED && !reviewed.has(booking.propertyId),
    }));
  }

  async quote(
    user: AuthUser | null,
    dto: { propertyId: string; startDate: string; endDate: string; shift?: ShiftType; couponCode?: string },
  ) {
    const property = await this.prisma.property.findUnique({ where: { id: dto.propertyId } });
    if (!property || property.status !== 'APPROVED') {
      throw new NotFoundException('المكان غير موجود');
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('تواريخ الحجز غير صالحة');
    }

    const mode = resolveBookingMode(property.type, property.bookingMode);
    const shift = resolveBookingShift(mode, dto.shift);

    const [rules, slots] = await Promise.all([
      this.prisma.priceRule.findMany({ where: { propertyId: dto.propertyId, isActive: true } }),
      this.prisma.availabilitySlot.findMany({
        where: { propertyId: dto.propertyId, date: { gte: start, lt: end } },
      }),
    ]);

    const baseTotal = calculateBookingTotal(property, rules as PriceRuleLike[], start, end, slots, shift);
    const nights = Math.max(1, Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));

    let discount = 0;
    let couponCode: string | null = null;
    if (dto.couponCode?.trim()) {
      const validation = await this.coupons.validate(dto.couponCode, property, baseTotal, user?.id);
      discount = validation.discount;
      couponCode = validation.coupon.code;
    }

    return {
      available: true,
      totalPrice: baseTotal - discount,
      originalTotal: baseTotal,
      discount,
      couponCode,
      nights,
      shift,
    };
  }

  async cancelByCustomer(user: AuthUser, id: string) {
    const booking = await this.prisma.booking.findUnique({ where: { id } });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    if (booking.userId !== user.id) throw new ForbiddenException('غير مسموح');
    if (
      booking.status !== BookingStatus.PENDING &&
      booking.status !== BookingStatus.AWAITING_PAYMENT
    ) {
      throw new BadRequestException('لا يمكن إلغاء هذا الحجز بعد تأكيده — تواصل مع الدعم');
    }

    const updated = await this.prisma.booking.update({
      where: { id },
      data: { status: BookingStatus.CANCELLED },
      include: { payment: true, property: true, user: true },
    });
    await this.notifications.notifyBookingEvent(
      { ...updated, propertyId: updated.propertyId, status: updated.status },
      'status',
    );
    await this.lifecycle.afterBookingStatusChanged(updated.id, updated.status);
    return updated;
  }

  async attachPaymentProof(user: AuthUser, id: string, proofUrl: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: { payment: true },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    if (booking.userId !== user.id) throw new ForbiddenException('غير مسموح');
    if (booking.status === BookingStatus.CANCELLED || booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException('لا يمكن إرفاق إثبات لهذا الحجز');
    }

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.AWAITING_PAYMENT,
        payment: booking.payment
          ? { update: { proofUrl, status: PaymentStatus.PENDING } }
          : {
              create: {
                method: PaymentMethod.MANUAL,
                amount: booking.totalPrice,
                proofUrl,
                status: PaymentStatus.PENDING,
              },
            },
      },
      include: { payment: true, property: true, user: true },
    });

    if (updated.payment) {
      await this.notifications.paymentProof({ id: updated.payment.id, booking: updated });
    }
    return updated;
  }

  async updateStatus(user: AuthUser, id: string, status: BookingStatus) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: { property: { include: { provider: true } }, payment: true },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');

    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    if (user.role === UserRole.PROVIDER) {
      const ownerId = booking.property.provider?.userId;
      if (!ownerId || ownerId !== user.id) {
        throw new ForbiddenException('لا يمكنك تعديل حجز لا يخص أماكنك');
      }
    } else if (!staff) {
      throw new ForbiddenException('غير مسموح');
    }

    const paymentStatus =
      status === BookingStatus.CONFIRMED || status === BookingStatus.COMPLETED
        ? PaymentStatus.PAID
        : undefined;

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status,
        payment: paymentStatus ? { update: { status: paymentStatus } } : undefined,
      },
      include: { payment: true, property: true, user: true },
    });

    await this.notifications.notifyBookingEvent({ ...updated, propertyId: updated.propertyId, status: updated.status }, 'status');
    if (status === BookingStatus.CONFIRMED) {
      await this.lifecycle.afterPaymentConfirmed(updated.id);
    } else {
      await this.lifecycle.afterBookingStatusChanged(updated.id, status);
    }
    return updated;
  }
}
