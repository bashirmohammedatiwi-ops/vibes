import { BadRequestException, Injectable } from '@nestjs/common';
import { BookingStatus, UserRole } from '@prisma/client';
import { CacheService } from '../../common/services/cache.service';
import { PrismaService } from '../../prisma/prisma.service';
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
  ) {}

  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, isActive: true, provider: { select: { id: true } } },
    });
    if (!user || !user.isActive) return { deleted: true };
    if (user.role !== UserRole.CUSTOMER || user.provider) {
      throw new BadRequestException('حسابات أصحاب الأماكن والموظفين تُحذف عبر الدعم — تواصل معنا وسنحذفه لك.');
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
