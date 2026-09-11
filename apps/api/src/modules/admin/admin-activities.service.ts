import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminActivitiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.AdminActivityWhereInput = {};

    if (query.action) where.action = { contains: query.action };
    if (query.entityType) where.entityType = query.entityType;
    if (query.userId) where.userId = query.userId;
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(`${query.to}T23:59:59.999Z`);
    }
    if (query.entityId) where.entityId = query.entityId;
    if (query.q) {
      where.OR = [
        { entityId: { contains: query.q } },
        { action: { contains: query.q, mode: 'insensitive' } },
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.adminActivity.findMany({
        where,
        include: { user: { select: { id: true, name: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.adminActivity.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  async exportCsv(query: Record<string, string | undefined>) {
    const where: Prisma.AdminActivityWhereInput = {};
    if (query.action) where.action = { contains: query.action };
    if (query.entityType) where.entityType = query.entityType;
    if (query.userId) where.userId = query.userId;
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(`${query.to}T23:59:59.999Z`);
    }

    const rows = await this.prisma.adminActivity.findMany({
      where,
      include: { user: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
      take: 5000,
    });

    const header = 'created_at,user_name,phone,action,entity_type,entity_id,metadata';
    const csvEscape = (value: string) => `"${value.replace(/"/g, '""')}"`;
    const lines = rows.map((row) =>
      [
        row.createdAt.toISOString(),
        csvEscape(row.user?.name ?? ''),
        row.user?.phone ?? '',
        csvEscape(row.action),
        row.entityType,
        row.entityId ?? '',
        csvEscape(JSON.stringify(row.metadata ?? {})),
      ].join(','),
    );

    return [header, ...lines].join('\n');
  }
}
