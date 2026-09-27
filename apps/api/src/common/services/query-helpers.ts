import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

@Injectable()
export class PaginationService {
  parse(page?: string, pageSize?: string) {
    const p = Math.max(1, Number(page) || 1);
    const size = Math.min(100, Math.max(1, Number(pageSize) || 20));
    return { page: p, pageSize: size, skip: (p - 1) * size, take: size };
  }

  wrap<T>(items: T[], total: number, page: number, pageSize: number): PaginatedResult<T> {
    return {
      items,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize) || 1,
    };
  }
}

export type PropertyWhere = Prisma.PropertyWhereInput;

@Injectable()
export class PropertyQueryBuilder {
  buildFilters(query: {
    q?: string;
    type?: string;
    status?: string;
    cityId?: string;
    province?: string;
    featured?: string;
    isNew?: string;
    source?: string;
    providerId?: string;
  }): PropertyWhere {
    const where: PropertyWhere = {};

    if (query.type) where.type = query.type as never;
    if (query.status && query.status !== 'all') where.status = query.status as never;
    if (query.cityId) where.cityId = query.cityId;
    if (query.province) where.city = { province: { slug: query.province } };
    if (query.featured === 'true') where.featured = true;
    if (query.isNew === 'true') where.isNew = true;
    if (query.providerId) where.providerId = query.providerId;
    if (query.source === 'provider') where.providerId = { not: null };
    if (query.source === 'team') where.providerId = null;
    if (query.q) {
      where.OR = [
        { name: { contains: query.q, mode: 'insensitive' } },
        { description: { contains: query.q, mode: 'insensitive' } },
        { address: { contains: query.q, mode: 'insensitive' } },
        { slug: { contains: query.q, mode: 'insensitive' } },
      ];
    }
    return where;
  }
}

@Injectable()
export class QueryHelpersModule {}

// re-export helpers as injectable group via admin module
