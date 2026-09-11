import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PropertyStatus, PropertyType } from '@prisma/client';
import { CacheService } from '../../common/services/cache.service';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

const CACHE_TTL_SECONDS = 30;

@ApiTags('search')
@Controller('search')
export class SearchController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
  ) {}

  @Public()
  @Get()
  async search(
    @Query('q') q?: string,
    @Query('type') type?: PropertyType,
    @Query('province') province?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('radius') radius?: string,
  ) {
    const cacheKey = CacheService.keyFrom('search', { q, type, province, lat, lng, radius });
    return this.cache.getOrSet(cacheKey, CACHE_TTL_SECONDS, () =>
      this.runSearch({ q, type, province, lat, lng, radius }),
    );
  }

  private async runSearch(params: {
    q?: string;
    type?: PropertyType;
    province?: string;
    lat?: string;
    lng?: string;
    radius?: string;
  }) {
    const { q, type, province, lat, lng, radius } = params;
    const where: Record<string, unknown> = {
      status: PropertyStatus.APPROVED,
    };

    if (type) {
      where.type = type;
    }
    if (province) {
      where.city = { province: { slug: province } };
    }

    let rankedIds: string[] | null = null;
    if (q && q.trim()) {
      // Full-text search over the pg_trgm/tsvector GIN index (see
      // properties_search_idx) instead of a plain ILIKE scan.
      const matches = await this.prisma.$queryRaw<{ id: string }[]>`
        SELECT id FROM properties
        WHERE status = 'APPROVED'
          AND to_tsvector('simple', name || ' ' || description) @@ plainto_tsquery('simple', ${q})
        ORDER BY ts_rank(to_tsvector('simple', name || ' ' || description), plainto_tsquery('simple', ${q})) DESC
        LIMIT 200
      `;
      rankedIds = matches.map((m) => m.id);
      if (!rankedIds.length) return [];
      where.id = { in: rankedIds };
    }

    const properties = await this.prisma.property.findMany({
      where,
      include: {
        city: { include: { province: true } },
        media: { take: 3, orderBy: { sortOrder: 'asc' } },
      },
      take: 50,
    });

    // Prisma can't preserve `id IN (...)` order, so re-sort by text-search rank.
    const ranked = rankedIds
      ? [...properties].sort((a, b) => rankedIds!.indexOf(a.id) - rankedIds!.indexOf(b.id))
      : properties;

    if (!lat || !lng) {
      return ranked;
    }

    const latitude = Number(lat);
    const longitude = Number(lng);
    const meters = Number(radius ?? 10000);

    return ranked.filter((property) => {
      const distance = haversineMeters(
        latitude,
        longitude,
        Number(property.latitude),
        Number(property.longitude),
      );
      return distance <= meters;
    });
  }
}

function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number) {
  const toRad = (value: number) => (value * Math.PI) / 180;
  const earth = 6_371_000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * earth * Math.asin(Math.sqrt(a));
}
