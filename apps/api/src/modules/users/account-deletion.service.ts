import { BadRequestException, Injectable } from '@nestjs/common';
import { BookingStatus, UserRole } from '@prisma/client';
import { CacheService } from '../../common/services/cache.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { ConversationsService } from '../marketplace/conversations.service';
import { userCacheKey } from '../auth/jwt.strategy';

/**
 * حذف حساب الزبون (متطلب App Store و Google Play).
 * - يُلغى ما لم يُدفع من حجوزات (قيد الانتظار).
 * - الحجوزات المؤكدة/المكتملة تبقى سجلاً تجارياً لصاحب المكان لكن بلا هوية الزبون.
 * - تُحذف البيانات الشخصية: الجلسات، الأجهزة، المفضلة، القوائم، المتابعات، الإشعارات، المنشورات.
 * - الرقم يتحرر — التسجيل به لاحقاً يُنشئ حساباً جديداً تماماً.
 */
@Injectable()
export class AccountDeletionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    private readonly conversations: ConversationsService,
  ) {}

  async deleteAccount(authUser: AuthUser) {
    const userId = authUser.id;
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, isActive: true, provider: { select: { id: true } } },
    });
    if (!user || !user.isActive) return { deleted: true };
    if (user.role === UserRole.ADMIN || user.role === UserRole.STAFF) {
      throw new BadRequestException('حسابات الموظفين تُدار من لوحة التحكم.');
    }
    // صاحب مكان: أماكنه وحجوزات ضيوفه مرتبطة بحسابه — نسجّل طلب حذف يصل للدعم
    // فوراً (من داخل التطبيق) ويُنفَّذ بعد ترتيب الحجوزات القائمة.
    if (user.role !== UserRole.CUSTOMER || user.provider) {
      const conv = await this.conversations.openSupport(authUser);
      await this.conversations.send(authUser, conv.id, {
        body: 'طلب حذف الحساب: أرجو حذف حسابي (صاحب مكان) وبياناتي الشخصية نهائياً.',
      });
      return {
        deleted: false,
        requested: true,
        message: 'استلمنا طلب حذف حسابك. سيُحذف خلال 7 أيام بعد ترتيب حجوزات أماكنك القائمة، وسنبلغك في محادثة الدعم.',
      };
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.updateMany({
        where: { userId, status: { in: [BookingStatus.PENDING, BookingStatus.AWAITING_PAYMENT] } },
        data: { status: BookingStatus.CANCELLED },
      });
      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.deviceToken.deleteMany({ where: { userId } });
      await tx.favorite.deleteMany({ where: { userId } });
      await tx.collection.deleteMany({ where: { userId } });
      await tx.providerFollow.deleteMany({ where: { userId } });
      await tx.userNotification.deleteMany({ where: { userId } });
      await tx.socialPostLike.deleteMany({ where: { userId } });
      await tx.socialPostComment.deleteMany({ where: { userId } });
      await tx.socialPostReport.deleteMany({ where: { userId } });
      await tx.socialPost.deleteMany({ where: { userId } });
      await tx.user.update({
        where: { id: userId },
        data: {
          phone: `deleted:${userId}`,
          name: null,
          pinHash: null,
          avatar: null,
          isActive: false,
        },
      });
    });
    await this.cache.del(userCacheKey(userId));
    return { deleted: true };
  }
}
