import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class UserNotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
  ) {}

  async list(user: AuthUser, query: { page?: string; pageSize?: string }) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const [items, total, unread] = await Promise.all([
      this.prisma.userNotification.findMany({
        where: { userId: user.id },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.userNotification.count({ where: { userId: user.id } }),
      this.prisma.userNotification.count({ where: { userId: user.id, isRead: false } }),
    ]);
    return { ...this.pagination.wrap(items, total, page, pageSize), unread };
  }

  async markRead(user: AuthUser, id?: string) {
    await this.prisma.userNotification.updateMany({
      where: { userId: user.id, ...(id ? { id } : { isRead: false }) },
      data: { isRead: true },
    });
    return { ok: true };
  }

  async unreadCount(user: AuthUser) {
    const unread = await this.prisma.userNotification.count({
      where: { userId: user.id, isRead: false },
    });
    return { unread };
  }
}
