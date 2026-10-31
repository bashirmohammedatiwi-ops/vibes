import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { CacheService } from '../../common/services/cache.service';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

const LOCATIONS_TTL_SECONDS = 300;

@ApiTags('locations')
@Controller()
export class LocationsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
  ) {}

  @Public()
  @Get('provinces')
  provinces() {
    return this.cache.getOrSet('cache:provinces:all', LOCATIONS_TTL_SECONDS, async () => {
      const [provinces, places] = await Promise.all([
        this.prisma.province.findMany({
          include: { cities: true },
          orderBy: { nameAr: 'asc' },
        }),
        this.prisma.property.groupBy({
          by: ['cityId', 'type'],
          where: { status: 'APPROVED' },
          _count: { _all: true },
        }),
      ]);
      // placeCounts لكل نوع: المحافظة بلا أماكن تظهر «قريباً» ولا تُفتح
      return provinces.map((province) => {
        const cityIds = new Set(province.cities.map((city) => city.id));
        const placeCounts: Record<string, number> = {};
        for (const row of places) {
          if (cityIds.has(row.cityId)) {
            placeCounts[row.type] = (placeCounts[row.type] ?? 0) + row._count._all;
          }
        }
        return { ...province, placeCounts };
      });
    });
  }

  @Public()
  @Get('banners')
  banners() {
    return this.cache.getOrSet('cache:banners:active', LOCATIONS_TTL_SECONDS, () =>
      this.prisma.banner.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      }),
    );
  }

  @Public()
  @Get('spotlights')
  spotlights() {
    return this.cache.getOrSet('cache:spotlights:active', LOCATIONS_TTL_SECONDS, () =>
      this.prisma.homeSpotlight.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
        select: {
          id: true,
          title: true,
          imageUrl: true,
          height: true,
          propertyId: true,
          property: { select: { id: true, name: true, type: true } },
        },
      }),
    );
  }
}
