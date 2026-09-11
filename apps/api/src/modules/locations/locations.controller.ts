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
    return this.cache.getOrSet('cache:provinces:all', LOCATIONS_TTL_SECONDS, () =>
      this.prisma.province.findMany({
        include: { cities: true },
        orderBy: { nameAr: 'asc' },
      }),
    );
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
}
