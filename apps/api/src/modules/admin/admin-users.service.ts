import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole, Prisma } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CacheService } from '../../common/services/cache.service';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';
import { userCacheKey } from '../auth/jwt.strategy';

@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.UserWhereInput = {};

    if (query.role) where.role = query.role as UserRole;
    if (query.isActive === 'true') where.isActive = true;
    if (query.isActive === 'false') where.isActive = false;
    if (query.q) {
      where.OR = [
        { phone: { contains: query.q } },
        { name: { contains: query.q, mode: 'insensitive' } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        include: {
          provider: true,
          _count: { select: { bookings: true, reviews: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.user.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  getOne(id: string) {
    return this.prisma.user
      .findUnique({
        where: { id },
        include: {
          provider: true,
          bookings: {
            take: 10,
            orderBy: { createdAt: 'desc' },
            include: { property: { select: { name: true } } },
          },
          _count: { select: { bookings: true, reviews: true } },
        },
      })
      .then((user) => {
        if (!user) throw new NotFoundException('المستخدم غير موجود');
        return user;
      });
  }

  async create(admin: AuthUser, data: { phone: string; name?: string; role?: UserRole }) {
    if (admin.role !== UserRole.ADMIN) {
      throw new BadRequestException('فقط المدير يمكنه إنشاء مستخدم');
    }

    const phone = data.phone.replace(/\s+/g, '');
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing) throw new BadRequestException('رقم الهاتف مسجّل مسبقاً');

    const role = data.role ?? UserRole.CUSTOMER;
    if (role === UserRole.ADMIN) {
      throw new BadRequestException('لا يمكن إنشاء مدير مباشرة — رقِّ حساباً موجوداً');
    }

    const created = await this.prisma.user.create({
      data: {
        phone,
        name: data.name?.trim() || null,
        role,
        isActive: true,
      },
      include: { provider: true, _count: { select: { bookings: true, reviews: true } } },
    });

    await this.activity.log({
      userId: admin.id,
      action: 'user.create',
      entityType: 'user',
      entityId: created.id,
      metadata: { phone, role },
    });

    return created;
  }

  async update(user: AuthUser, id: string, data: { role?: UserRole; name?: string; isActive?: boolean }) {
    const target = await this.getOne(id);

    if (data.role === UserRole.ADMIN && user.role !== UserRole.ADMIN) {
      throw new BadRequestException('فقط المدير يمكنه تعيين مدير');
    }
    if (target.id === user.id && data.isActive === false) {
      throw new BadRequestException('لا يمكنك تعطيل حسابك');
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        role: data.role,
        name: data.name,
        isActive: data.isActive,
      },
      include: { provider: true, _count: { select: { bookings: true, reviews: true } } },
    });

    await this.activity.log({
      userId: user.id,
      action: 'user.update',
      entityType: 'user',
      entityId: id,
      metadata: data as Record<string, unknown>,
    });
    await this.cache.del(userCacheKey(id));
    if (data.isActive === false) {
      await this.prisma.refreshToken.updateMany({
        where: { userId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    return updated;
  }

  /**
   * Users with history are deactivated instead of deleted so bookings, payments
   * and reviews keep a valid owner.
   */
  async remove(admin: AuthUser, id: string) {
    if (admin.role !== UserRole.ADMIN) {
      throw new BadRequestException('فقط المدير يمكنه حذف مستخدم');
    }
    if (id === admin.id) {
      throw new BadRequestException('لا يمكنك حذف حسابك');
    }

    const target = await this.prisma.user.findUnique({
      where: { id },
      include: {
        provider: { select: { id: true } },
        _count: {
          select: { bookings: true, reviews: true, createdProperties: true, media: true },
        },
      },
    });
    if (!target) throw new NotFoundException('المستخدم غير موجود');
    if (target.role === UserRole.ADMIN) {
      throw new BadRequestException('نزّل دور المدير أولاً قبل الحذف');
    }

    const hasHistory =
      target._count.bookings > 0 ||
      target._count.reviews > 0 ||
      target._count.createdProperties > 0 ||
      target._count.media > 0;

    if (hasHistory) {
      const deactivated = await this.prisma.user.update({
        where: { id },
        data: { isActive: false },
        include: { provider: true, _count: { select: { bookings: true, reviews: true } } },
      });
      await this.activity.log({
        userId: admin.id,
        action: 'user.deactivate',
        entityType: 'user',
        entityId: id,
        metadata: { reason: 'has-history' },
      });
      await this.cache.del(userCacheKey(id));
      return { deleted: false, deactivated: true, user: deactivated };
    }

    await this.prisma.user.delete({ where: { id } });
    await this.activity.log({
      userId: admin.id,
      action: 'user.delete',
      entityType: 'user',
      entityId: id,
      metadata: { phone: target.phone },
    });
    await this.cache.del(userCacheKey(id));
    return { deleted: true, deactivated: false };
  }
}
