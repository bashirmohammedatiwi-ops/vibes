import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { KycStatus, UserRole } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { NotificationService } from '../../common/services/notification.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { userCacheKey } from '../auth/jwt.strategy';
import { PrismaService } from '../../prisma/prisma.service';

const providerInclude = {
  user: { select: { id: true, name: true, phone: true, role: true } },
  _count: { select: { properties: true } },
};

@Injectable()
export class ProvidersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
  ) {}

  list() {
    return this.prisma.provider.findMany({
      include: providerInclude,
      orderBy: { createdAt: 'desc' },
    });
  }

  async me(user: AuthUser) {
    return this.prisma.provider.findUnique({
      where: { userId: user.id },
      include: providerInclude,
    });
  }

  async becomeProvider(
    user: AuthUser,
    dto: { businessName?: string; placeTypes?: string[]; note?: string } = {},
  ) {
    const existing = await this.prisma.provider.findUnique({ where: { userId: user.id } });
    const placeTypes = (dto.placeTypes ?? [])
      .map((item) => item.trim().toUpperCase())
      .filter((item) => ['FARM', 'HALL', 'DECORATION'].includes(item))
      .join(',');
    const requestNote = dto.note?.trim() ?? '';

    if (existing?.kycStatus === KycStatus.VERIFIED) {
      return this.prisma.provider.update({
        where: { id: existing.id },
        data: {
          businessName: dto.businessName ?? existing.businessName,
          placeTypes: placeTypes || existing.placeTypes,
        },
        include: providerInclude,
      });
    }

    const provider = await this.prisma.provider.upsert({
      where: { userId: user.id },
      update: {
        businessName: dto.businessName ?? existing?.businessName,
        kycStatus: KycStatus.PENDING,
        verified: false,
        rejectionReason: null,
        requestNote: requestNote || existing?.requestNote || '',
        placeTypes: placeTypes || existing?.placeTypes || '',
      },
      create: {
        userId: user.id,
        businessName: dto.businessName,
        kycStatus: KycStatus.PENDING,
        requestNote,
        placeTypes,
      },
      include: providerInclude,
    });

    const isNewRequest = !existing || existing.kycStatus === KycStatus.REJECTED;
    if (isNewRequest) {
      await this.notifications.providerRequest({
        id: provider.id,
        businessName: provider.businessName,
        phone: provider.user.phone,
      });
    }

    return provider;
  }

  async verify(staff: AuthUser, id: string) {
    const provider = await this.prisma.provider.findUnique({ where: { id } });
    if (!provider) throw new NotFoundException('المزود غير موجود');

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: provider.userId },
        data: { role: UserRole.PROVIDER },
      });
      return tx.provider.update({
        where: { id },
        data: { verified: true, kycStatus: KycStatus.VERIFIED, rejectionReason: null },
        include: providerInclude,
      });
    });

    await this.activity.log({
      userId: staff.id,
      action: 'provider.verify',
      entityType: 'provider',
      entityId: id,
    });
    await this.cache.del(userCacheKey(provider.userId));

    return updated;
  }

  async reject(staff: AuthUser, id: string, reason?: string) {
    const provider = await this.prisma.provider.findUnique({ where: { id } });
    if (!provider) throw new NotFoundException('المزود غير موجود');
    if (!reason?.trim()) {
      throw new BadRequestException('أضف سبب الرفض');
    }

    const updated = await this.prisma.provider.update({
      where: { id },
      data: {
        verified: false,
        kycStatus: KycStatus.REJECTED,
        rejectionReason: reason.trim(),
      },
      include: providerInclude,
    });

    await this.activity.log({
      userId: staff.id,
      action: 'provider.reject',
      entityType: 'provider',
      entityId: id,
      metadata: { reason: reason.trim() },
    });
    await this.cache.del(userCacheKey(provider.userId));

    return updated;
  }

  async revoke(staff: AuthUser, id: string, reason?: string) {
    const provider = await this.prisma.provider.findUnique({ where: { id } });
    if (!provider) throw new NotFoundException('المزود غير موجود');
    if (!provider.verified) throw new BadRequestException('المزود غير موثّق');

    const updated = await this.prisma.provider.update({
      where: { id },
      data: {
        verified: false,
        kycStatus: KycStatus.PENDING,
        rejectionReason: reason?.trim() || 'تم إلغاء التوثيق',
      },
      include: providerInclude,
    });

    await this.activity.log({
      userId: staff.id,
      action: 'provider.revoke',
      entityType: 'provider',
      entityId: id,
    });
    await this.cache.del(userCacheKey(provider.userId));

    return updated;
  }
}
