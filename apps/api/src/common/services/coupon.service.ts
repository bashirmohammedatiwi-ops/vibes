import { BadRequestException, Injectable } from '@nestjs/common';
import { DiscountType, Prisma, PropertyType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export type CouponValidation = {
  coupon: { id: string; code: string; discountType: DiscountType; discountValue: Prisma.Decimal };
  discount: number;
  totalAfterDiscount: number;
};

/**
 * Coupon validation + atomic redemption. Validation is pure-read so it can
 * back both the quote endpoint and booking creation; redemption uses a
 * conditional updateMany to stay race-free under concurrent bookings.
 */
@Injectable()
export class CouponService {
  constructor(private readonly prisma: PrismaService) {}

  async validate(code: string, property: { id: string; type: PropertyType }, total: number, userId?: string): Promise<CouponValidation> {
    const normalized = code.trim().toUpperCase();
    if (!normalized) throw new BadRequestException('أدخل رمز الخصم');

    const coupon = await this.prisma.coupon.findUnique({ where: { code: normalized } });
    if (!coupon || !coupon.isActive) throw new BadRequestException('رمز الخصم غير صالح');
    if (coupon.startsAt && coupon.startsAt > new Date()) throw new BadRequestException('هذا الرمز لم يبدأ بعد');
    if (coupon.expiresAt && coupon.expiresAt < new Date()) throw new BadRequestException('انتهت صلاحية هذا الرمز');
    if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) {
      throw new BadRequestException('استُهلك الحد الأقصى لهذا الرمز');
    }
    if (coupon.propertyId && coupon.propertyId !== property.id) {
      throw new BadRequestException('هذا الرمز مخصص لمكان آخر');
    }
    if (coupon.appliesToTypes.length && !coupon.appliesToTypes.includes(property.type)) {
      throw new BadRequestException('هذا الرمز لا ينطبق على هذا النوع من الأماكن');
    }
    if (coupon.minBookingTotal != null && total < Number(coupon.minBookingTotal)) {
      throw new BadRequestException(`هذا الرمز يتطلب حجباً بقيمة ${Number(coupon.minBookingTotal)} على الأقل`);
    }
    if (userId && coupon.maxUsesPerUser != null) {
      const used = await this.prisma.couponRedemption.count({ where: { couponId: coupon.id, userId } });
      if (used >= coupon.maxUsesPerUser) {
        throw new BadRequestException('لقد استخدمت هذا الرمز من قبل');
      }
    }

    const value = Number(coupon.discountValue);
    const discount =
      coupon.discountType === DiscountType.PERCENT
        ? Math.round(total * (Math.min(value, 100) / 100))
        : Math.min(Math.round(value), total);

    return {
      coupon,
      discount,
      totalAfterDiscount: total - discount,
    };
  }

  /**
   * Atomically consumes one use of the coupon and snapshots the discount on
   * the booking. Call inside the booking creation flow after the quote.
   */
  async applyToBooking(
    couponId: string,
    bookingId: string,
    userId: string,
    discount: number,
    tx?: Prisma.TransactionClient,
  ) {
    const client = tx ?? this.prisma;

    const coupon = await client.coupon.findUnique({ where: { id: couponId } });
    if (!coupon) throw new BadRequestException('رمز الخصم غير صالح');

    if (coupon.maxUses != null) {
      const updated = await client.coupon.updateMany({
        where: { id: couponId, usedCount: { lt: coupon.maxUses } },
        data: { usedCount: { increment: 1 } },
      });
      if (updated.count === 0) {
        throw new BadRequestException('استُهلك الحد الأقصى لهذا الرمز');
      }
    } else {
      await client.coupon.update({ where: { id: couponId }, data: { usedCount: { increment: 1 } } });
    }

    await client.couponRedemption.create({
      data: { couponId, bookingId, userId, discountAmount: discount },
    });
  }

  /**
   * Promotional coupons only (non-empty description). Secret partner codes
   * stay hidden when the admin leaves the description blank.
   */
  async listPublic(propertyType?: PropertyType) {
    const now = new Date();
    const rows = await this.prisma.coupon.findMany({
      where: {
        isActive: true,
        NOT: { description: '' },
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
          { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
        ],
      },
      include: { property: { select: { id: true, name: true } } },
      orderBy: { expiresAt: 'asc' },
      take: 40,
    });

    return rows
      .filter((coupon) => coupon.maxUses == null || coupon.usedCount < coupon.maxUses)
      .filter((coupon) => !propertyType || coupon.appliesToTypes.length === 0 || coupon.appliesToTypes.includes(propertyType))
      .slice(0, 20)
      .map((coupon) => ({
        code: coupon.code,
        description: coupon.description,
        discountType: coupon.discountType,
        discountValue: Number(coupon.discountValue),
        minBookingTotal: coupon.minBookingTotal == null ? null : Number(coupon.minBookingTotal),
        expiresAt: coupon.expiresAt,
        appliesToTypes: coupon.appliesToTypes,
        property: coupon.property,
      }));
  }
}
