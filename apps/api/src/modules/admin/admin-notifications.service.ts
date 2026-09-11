import { Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PaginationService } from '../../common/services/query-helpers';

@Injectable()
export class AdminNotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.TeamNotificationWhereInput = {};
    if (query.unread === 'true') where.isRead = false;
    if (query.type) where.type = query.type as NotificationType;
    if (query.q) {
      where.OR = [
        { title: { contains: query.q, mode: 'insensitive' } },
        { body: { contains: query.q, mode: 'insensitive' } },
      ];
    }

    const [items, total, unreadCount] = await Promise.all([
      this.prisma.teamNotification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.teamNotification.count({ where }),
      this.prisma.teamNotification.count({ where: { isRead: false } }),
    ]);

    return { ...this.pagination.wrap(items, total, page, pageSize), unreadCount };
  }

  markRead(id: string) {
    return this.prisma.teamNotification.update({
      where: { id },
      data: { isRead: true },
    });
  }

  markAllRead() {
    return this.prisma.teamNotification.updateMany({
      where: { isRead: false },
      data: { isRead: true },
    });
  }

  async remove(id: string) {
    const existing = await this.prisma.teamNotification.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('الإشعار غير موجود');
    await this.prisma.teamNotification.delete({ where: { id } });
    return { deleted: true };
  }

  /** Clears read notifications older than the given number of days (default 30). */
  async clearRead(days = 30) {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - Math.max(0, days));
    const { count } = await this.prisma.teamNotification.deleteMany({
      where: { isRead: true, createdAt: { lt: cutoff } },
    });
    return { deleted: count };
  }

  async exportCsv(query: Record<string, string | undefined> = {}) {
    const where: Prisma.TeamNotificationWhereInput = {};
    if (query.unread === 'true') where.isRead = false;
    if (query.type) where.type = query.type as NotificationType;
    if (query.q) {
      where.OR = [
        { title: { contains: query.q, mode: 'insensitive' } },
        { body: { contains: query.q, mode: 'insensitive' } },
      ];
    }

    const rows = await this.prisma.teamNotification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 5000,
    });

    const cell = (value?: string | null) => `"${(value ?? '').replace(/"/g, '""')}"`;
    const header = 'id,type,title,body,link,entity_type,entity_id,is_read,created_at';
    const lines = rows.map((n) =>
      [
        n.id,
        n.type,
        cell(n.title),
        cell(n.body),
        cell(n.linkUrl),
        n.entityType ?? '',
        n.entityId ?? '',
        n.isRead,
        n.createdAt.toISOString(),
      ].join(','),
    );
    return [header, ...lines].join('\n');
  }
}
