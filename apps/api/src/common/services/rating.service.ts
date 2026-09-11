import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class RatingService {
  constructor(private readonly prisma: PrismaService) {}

  async refreshProperty(propertyId: string) {
    const agg = await this.prisma.review.aggregate({
      where: { propertyId, isVisible: true },
      _avg: { rating: true },
      _count: { id: true },
    });

    await this.prisma.property.update({
      where: { id: propertyId },
      data: {
        ratingAvg: agg._avg.rating ?? 0,
        ratingCount: agg._count.id,
      },
    });
  }
}
