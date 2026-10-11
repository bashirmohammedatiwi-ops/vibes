import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ClaimStatus, ConversationKind, KycStatus, MessageKind, UserRole } from '@prisma/client';
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

  async claimPlace(user: AuthUser, propertyId: string) {
    if (!propertyId?.trim()) throw new BadRequestException('اختر المكان أولاً');
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: { provider: { include: { user: { select: { id: true } } } } },
    });
    if (!property) throw new NotFoundException('المكان غير موجود');
    if (property.provider?.userId === user.id) {
      throw new BadRequestException('هذا المكان مرتبط بحسابك بالفعل');
    }

    const existing = await this.prisma.placeClaim.findUnique({
      where: { userId_propertyId: { userId: user.id, propertyId } },
    });
    if (existing?.status === ClaimStatus.PENDING || existing?.status === ClaimStatus.APPROVED) {
      return {
        id: existing.id,
        status: existing.status,
        conversationId: existing.conversationId,
        propertyName: property.name,
      };
    }

    if (existing?.status === ClaimStatus.REJECTED) {
      const reopened = await this.prisma.placeClaim.update({
        where: { id: existing.id },
        data: { status: ClaimStatus.PENDING },
      });
      await this.prisma.message.create({
        data: {
          conversationId: existing.conversationId,
          kind: MessageKind.SYSTEM,
          body: `أُعيد طلب ربط «${property.name}» بحسابك. الفريق يراجع الملكية قبل الربط.`,
        },
      });
      await this.notifications.providerRequest({
        id: reopened.id,
        businessName: property.name,
        phone: user.phone,
      });
      return {
        id: reopened.id,
        status: reopened.status,
        conversationId: reopened.conversationId,
        propertyName: property.name,
      };
    }

    const conversation = await this.prisma.conversation.create({
      data: {
        kind: ConversationKind.CLAIM,
        guestUserId: user.id,
        propertyId,
        participants: { create: { userId: user.id } },
        messages: {
          create: {
            kind: MessageKind.SYSTEM,
            body: `طلب ربط «${property.name}» بهذا الحساب. اكتب ما يثبت أن المكان لك، والفريق يربط الحساب بعد التأكد.`,
          },
        },
      },
    });
    const claim = await this.prisma.placeClaim.create({
      data: {
        userId: user.id,
        propertyId,
        conversationId: conversation.id,
      },
    });
    await this.notifications.providerRequest({
      id: claim.id,
      businessName: property.name,
      phone: user.phone,
    });
    return {
      id: claim.id,
      status: claim.status,
      conversationId: conversation.id,
      propertyName: property.name,
    };
  }

  myClaims(user: AuthUser) {
    return this.prisma.placeClaim.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
      include: {
        property: { select: { id: true, name: true, city: { select: { nameAr: true } } } },
      },
    });
  }

  listClaims(status?: string) {
    const where =
      status === 'APPROVED' || status === 'REJECTED' || status === 'PENDING'
        ? { status: status as ClaimStatus }
        : { status: ClaimStatus.PENDING };
    return this.prisma.placeClaim.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 40,
      include: {
        user: { select: { id: true, name: true, phone: true } },
        property: {
          select: {
            id: true,
            name: true,
            provider: { select: { businessName: true, user: { select: { phone: true } } } },
          },
        },
      },
    });
  }

  async approveClaim(staff: AuthUser, id: string) {
    const claim = await this.prisma.placeClaim.findUnique({
      where: { id },
      include: { user: true, property: true },
    });
    if (!claim) throw new NotFoundException('طلب الربط غير موجود');
    if (claim.status === ClaimStatus.APPROVED) return claim;

    const provider = await this.prisma.provider.upsert({
      where: { userId: claim.userId },
      update: { verified: true, kycStatus: KycStatus.VERIFIED, rejectionReason: null },
      create: {
        userId: claim.userId,
        businessName: claim.user.name || claim.property.name,
        verified: true,
        kycStatus: KycStatus.VERIFIED,
      },
    });

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: claim.userId },
        data: { role: UserRole.PROVIDER },
      }),
      this.prisma.property.update({
        where: { id: claim.propertyId },
        data: { providerId: provider.id },
      }),
      this.prisma.placeClaim.update({
        where: { id },
        data: { status: ClaimStatus.APPROVED },
      }),
      this.prisma.message.create({
        data: {
          conversationId: claim.conversationId,
          kind: MessageKind.SYSTEM,
          body: `تم ربط «${claim.property.name}» بحسابك. ستظهر حجوزات هذا المكان في بوابة المزود.`,
        },
      }),
    ]);

    await this.activity.log({
      userId: staff.id,
      action: 'placeClaim.approve',
      entityType: 'placeClaim',
      entityId: id,
      metadata: { propertyId: claim.propertyId, userId: claim.userId },
    });
    await this.cache.del(userCacheKey(claim.userId));
    return { ok: true };
  }

  async linkPlaceForUser(
    staff: AuthUser,
    userId: string,
    propertyId: string,
    conversationId?: string,
  ) {
    const [account, property] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId } }),
      this.prisma.property.findUnique({ where: { id: propertyId } }),
    ]);
    if (!account) throw new NotFoundException('المستخدم غير موجود');
    if (!property) throw new NotFoundException('المكان غير موجود');

    const provider = await this.prisma.provider.upsert({
      where: { userId },
      update: { verified: true, kycStatus: KycStatus.VERIFIED, rejectionReason: null },
      create: {
        userId,
        businessName: account.name || property.name,
        verified: true,
        kycStatus: KycStatus.VERIFIED,
      },
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: { role: UserRole.PROVIDER },
    });
    await this.prisma.property.update({
      where: { id: propertyId },
      data: { providerId: provider.id },
    });

    const existingClaim = await this.prisma.placeClaim.findUnique({
      where: { userId_propertyId: { userId, propertyId } },
    });
    let claimConversationId = existingClaim?.conversationId;
    if (existingClaim) {
      await this.prisma.placeClaim.update({
        where: { id: existingClaim.id },
        data: { status: ClaimStatus.APPROVED },
      });
    } else {
      const created = await this.prisma.conversation.create({
        data: {
          kind: ConversationKind.CLAIM,
          guestUserId: userId,
          propertyId,
          participants: { create: { userId } },
        },
      });
      claimConversationId = created.id;
      await this.prisma.placeClaim.create({
        data: {
          userId,
          propertyId,
          conversationId: created.id,
          status: ClaimStatus.APPROVED,
        },
      });
    }

    const notice = `تم ربط «${property.name}» بحسابك. ستجده في بوابة أماكني.`;
    const rooms = new Set(
      [claimConversationId, conversationId].filter((id): id is string => !!id),
    );
    for (const room of rooms) {
      await this.prisma.message.create({
        data: { conversationId: room, kind: MessageKind.SYSTEM, body: notice },
      });
    }

    await this.activity.log({
      userId: staff.id,
      action: 'placeClaim.link',
      entityType: 'property',
      entityId: propertyId,
      metadata: { userId },
    });
    await this.cache.del(userCacheKey(userId));
    return { ok: true, propertyName: property.name };
  }

  async rejectClaim(staff: AuthUser, id: string) {
    const claim = await this.prisma.placeClaim.findUnique({
      where: { id },
      include: { property: true },
    });
    if (!claim) throw new NotFoundException('طلب الربط غير موجود');
    if (claim.status === ClaimStatus.APPROVED) {
      throw new BadRequestException('الطلب مربوط بالفعل');
    }

    await this.prisma.$transaction([
      this.prisma.placeClaim.update({
        where: { id },
        data: { status: ClaimStatus.REJECTED },
      }),
      this.prisma.message.create({
        data: {
          conversationId: claim.conversationId,
          kind: MessageKind.SYSTEM,
          body: `لم يُربط «${claim.property.name}» بهذا الحساب. يمكنك إعادة الطلب لاحقاً إذا توفّر ما يثبت الملكية.`,
        },
      }),
    ]);

    await this.activity.log({
      userId: staff.id,
      action: 'placeClaim.reject',
      entityType: 'placeClaim',
      entityId: id,
    });
    return { ok: true };
  }
}
