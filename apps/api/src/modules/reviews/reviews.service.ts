import { Injectable } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { RatingService } from '../../common/services/rating.service';
import { NotificationService } from '../../common/services/notification.service';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ReviewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rating: RatingService,
    private readonly notifications: NotificationService,
  ) {}

  async upsert(userId: string, propertyId: string, rating: number, comment: string) {
    const existing = await this.prisma.review.findUnique({
      where: { userId_propertyId: { userId, propertyId } },
    });

    const review = await this.prisma.review.upsert({
      where: { userId_propertyId: { userId, propertyId } },
      update: { rating, comment },
      create: { userId, propertyId, rating, comment },
      include: { property: { select: { id: true, name: true } } },
    });

    await this.rating.refreshProperty(propertyId);

    if (!existing) {
      await this.notifications.reviewNew(review);
    }

    return review;
  }

  list(propertyId: string) {
    return this.prisma.review.findMany({
      where: { propertyId, isVisible: true },
      include: { user: { select: { name: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }
}
