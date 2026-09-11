import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { KycStatus, UserRole } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { NotificationService } from '../../common/services/notification.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
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

  async becomeProvider(user: AuthUser, businessName?: string) {
    const existing = await this.prisma.provider.findUnique({ where: { userId: user.id } });

    if (existing?.kycStatus === KycStatus.VERIFIED) {
      return this.prisma.provider.update({
        where: { id: existing.id },
        data: { businessName: businessName ?? existing.businessName },
        include: providerInclude,
      });
    }

    const provider = await this.prisma.provider.upsert({
      where: { userId: user.id },
      update: {
        businessName: businessName ?? existing?.businessName,
        kycStatus: KycStatus.PENDING,
        verified: false,
        rejectionReason: null,
      },
      create: {
        userId: user.id,
        businessName,
        kycStatus: KycStatus.PENDING,
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

    return updated;
  }
}
