import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { RatingService } from '../../common/services/rating.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminReviewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly activity: ActivityLogService,
    private readonly rating: RatingService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.ReviewWhereInput = {};

    if (query.propertyId) where.propertyId = query.propertyId;
    if (query.visible === 'true') where.isVisible = true;
    if (query.visible === 'false') where.isVisible = false;
    if (query.minRating) where.rating = { gte: Number(query.minRating) };
    if (query.q) {
      where.OR = [
        { comment: { contains: query.q, mode: 'insensitive' } },
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
        { property: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(`${query.to}T23:59:59.999Z`);
    }

    const [items, total] = await Promise.all([
      this.prisma.review.findMany({
        where,
        include: {
          user: { select: { id: true, name: true, phone: true } },
          property: { select: { id: true, name: true, slug: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.review.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  async setVisibility(user: AuthUser, id: string, isVisible: boolean, adminNote?: string) {
    const review = await this.prisma.review.findUnique({ where: { id } });
    if (!review) throw new NotFoundException('التقييم غير موجود');

    const updated = await this.prisma.review.update({
      where: { id },
      data: { isVisible, adminNote },
      include: {
        user: { select: { name: true, phone: true } },
        property: { select: { name: true } },
      },
    });

    await this.rating.refreshProperty(review.propertyId);
    await this.activity.log({
      userId: user.id,
      action: isVisible ? 'review.show' : 'review.hide',
      entityType: 'review',
      entityId: id,
    });

    return updated;
  }

  async remove(user: AuthUser, id: string) {
    const review = await this.prisma.review.findUnique({ where: { id } });
    if (!review) throw new NotFoundException('التقييم غير موجود');

    await this.prisma.review.delete({ where: { id } });
    await this.rating.refreshProperty(review.propertyId);
    await this.activity.log({
      userId: user.id,
      action: 'review.delete',
      entityType: 'review',
      entityId: id,
    });

    return { deleted: true };
  }

  async bulk(user: AuthUser, ids: string[], action: 'show' | 'hide' | 'delete') {
    const results = [];
    for (const id of ids) {
      try {
        if (action === 'delete') {
          await this.remove(user, id);
        } else {
          await this.setVisibility(user, id, action === 'show');
        }
        results.push({ id, ok: true });
      } catch (err) {
        results.push({ id, ok: false, error: err instanceof Error ? err.message : 'failed' });
      }
    }
    return { updated: results.filter((r) => r.ok).length, failed: results.filter((r) => !r.ok).length, results };
  }

  async exportCsv(query: Record<string, string | undefined> = {}) {
    const { items } = await this.list({ ...query, page: '1', pageSize: '5000' });
    const header = 'id,property,customer,phone,rating,visible,comment,created_at';
    const lines = items.map((r) =>
      [
        r.id,
        `"${(r.property?.name ?? '').replace(/"/g, '""')}"`,
        `"${(r.user?.name ?? '').replace(/"/g, '""')}"`,
        r.user?.phone ?? '',
        r.rating,
        r.isVisible,
        `"${(r.comment ?? '').replace(/"/g, '""')}"`,
        r.createdAt,
      ].join(','),
    );
    return [header, ...lines].join('\n');
  }
}
