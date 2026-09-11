import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DiscountType, Prisma, PropertyType } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CouponService } from '../../common/services/coupon.service';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminCouponDto } from './dto/admin-coupon.dto';

@Injectable()
export class AdminCouponsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly activity: ActivityLogService,
    private readonly coupons: CouponService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.CouponWhereInput = {};
    if (query.activeOnly === 'true') where.isActive = true;
    if (query.q) where.code = { contains: query.q };

    const [items, total] = await Promise.all([
      this.prisma.coupon.findMany({
        where,
        include: {
          property: { select: { id: true, name: true } },
          _count: { select: { redemptions: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.coupon.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  async create(user: AuthUser, dto: AdminCouponDto) {
    const code = dto.code.trim().toUpperCase();
    const clash = await this.prisma.coupon.findUnique({ where: { code } });
    if (clash) throw new BadRequestException('هذا الرمز مستخدم مسبقاً');
    this.validateValues(dto);

    const coupon = await this.prisma.coupon.create({
      data: {
        code,
        description: dto.description?.trim() ?? '',
        discountType: dto.discountType ?? DiscountType.PERCENT,
        discountValue: dto.discountValue,
        minBookingTotal: dto.minBookingTotal,
        maxUses: dto.maxUses,
        maxUsesPerUser: dto.maxUsesPerUser,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        appliesToTypes: dto.appliesToTypes ?? [],
        propertyId: dto.propertyId || null,
        isActive: dto.isActive ?? true,
      },
    });

    await this.activity.log({
      userId: user.id,
      action: 'coupon.create',
      entityType: 'coupon',
      entityId: coupon.id,
      metadata: { code: coupon.code },
    });
    return coupon;
  }

  async update(user: AuthUser, id: string, dto: Partial<AdminCouponDto>) {
    const existing = await this.prisma.coupon.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('الكوبون غير موجود');
    if (dto.code && dto.code.trim().toUpperCase() !== existing.code) {
      const clash = await this.prisma.coupon.findUnique({ where: { code: dto.code.trim().toUpperCase() } });
      if (clash) throw new BadRequestException('هذا الرمز مستخدم مسبقاً');
    }
    this.validateValues(dto);

    const coupon = await this.prisma.coupon.update({
      where: { id },
      data: {
        ...(dto.code !== undefined ? { code: dto.code.trim().toUpperCase() } : {}),
        ...(dto.description !== undefined ? { description: dto.description.trim() } : {}),
        ...(dto.discountType !== undefined ? { discountType: dto.discountType } : {}),
        ...(dto.discountValue !== undefined ? { discountValue: dto.discountValue } : {}),
        ...(dto.minBookingTotal !== undefined ? { minBookingTotal: dto.minBookingTotal } : {}),
        ...(dto.maxUses !== undefined ? { maxUses: dto.maxUses } : {}),
        ...(dto.maxUsesPerUser !== undefined ? { maxUsesPerUser: dto.maxUsesPerUser } : {}),
        ...(dto.startsAt !== undefined ? { startsAt: dto.startsAt ? new Date(dto.startsAt) : null } : {}),
        ...(dto.expiresAt !== undefined ? { expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null } : {}),
        ...(dto.appliesToTypes !== undefined ? { appliesToTypes: dto.appliesToTypes } : {}),
        ...(dto.propertyId !== undefined ? { propertyId: dto.propertyId || null } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });

    await this.activity.log({
      userId: user.id,
      action: 'coupon.update',
      entityType: 'coupon',
      entityId: id,
      metadata: { code: coupon.code },
    });
    return coupon;
  }

  async remove(user: AuthUser, id: string) {
    const existing = await this.prisma.coupon.findUnique({
      where: { id },
      include: { _count: { select: { redemptions: true } } },
    });
    if (!existing) throw new NotFoundException('الكوبون غير موجود');
    if (existing._count.redemptions > 0) {
      // Keep the audit trail: deactivate instead of deleting used coupons.
      await this.prisma.coupon.update({ where: { id }, data: { isActive: false } });
      await this.activity.log({
        userId: user.id,
        action: 'coupon.deactivate',
        entityType: 'coupon',
        entityId: id,
        metadata: { code: existing.code, reason: 'used' },
      });
      return { deactivated: true };
    }
    await this.prisma.coupon.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'coupon.delete',
      entityType: 'coupon',
      entityId: id,
      metadata: { code: existing.code },
    });
    return { deleted: true };
  }

  /** Preview endpoint for the manual booking form. */
  async validate(user: AuthUser, dto: { code: string; propertyId: string; total: number }) {
    const property = await this.prisma.property.findUnique({ where: { id: dto.propertyId } });
    if (!property) throw new NotFoundException('المكان غير موجود');
    const provider = await this.prisma.provider.findUnique({ where: { userId: user.id } });
    const validation = await this.coupons.validate(dto.code, property, dto.total, provider?.userId);
    return {
      valid: true,
      code: validation.coupon.code,
      discount: validation.discount,
      totalAfterDiscount: validation.totalAfterDiscount,
    };
  }

  private validateValues(dto: Partial<AdminCouponDto>) {
    if (dto.discountType === DiscountType.PERCENT && dto.discountValue != null && Number(dto.discountValue) > 100) {
      throw new BadRequestException('نسبة الخصم لا يمكن أن تتجاوز 100%');
    }
    if (dto.discountValue != null && Number(dto.discountValue) < 0) {
      throw new BadRequestException('قيمة الخصم غير صالحة');
    }
    if (dto.startsAt && dto.expiresAt && new Date(dto.startsAt) > new Date(dto.expiresAt)) {
      throw new BadRequestException('بداية الصلاحية بعد نهايتها');
    }
  }
}
