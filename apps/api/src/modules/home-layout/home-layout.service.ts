import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  BODY_SECTIONS,
  DEFAULT_HOME_LAYOUT,
  HEADER_SECTIONS,
  HomeLayout,
  normalizeHomeLayout,
  QUICK_LINKS,
} from './home-layout.config';

const KEY = 'home_layout';
const CACHE_KEY = 'cache:home:layout';

@Injectable()
export class HomeLayoutService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    private readonly activity: ActivityLogService,
  ) {}

  layout(): Promise<HomeLayout> {
    return this.cache.getOrSet(CACHE_KEY, 60, () => this.read());
  }

  private async read(): Promise<HomeLayout> {
    const row = await this.prisma.platformSetting.findUnique({ where: { key: KEY } });
    if (!row) return DEFAULT_HOME_LAYOUT;
    try {
      return normalizeHomeLayout(JSON.parse(row.value));
    } catch {
      return DEFAULT_HOME_LAYOUT;
    }
  }

  async admin() {
    const [layout, row] = await Promise.all([this.read(), this.prisma.platformSetting.findUnique({ where: { key: KEY } })]);
    return {
      layout,
      catalog: { header: HEADER_SECTIONS, body: BODY_SECTIONS, quickLinks: QUICK_LINKS },
      updatedAt: row?.updatedAt ?? null,
    };
  }

  async update(user: AuthUser, raw: unknown) {
    const value = JSON.stringify(normalizeHomeLayout(raw));
    await this.prisma.platformSetting.upsert({ where: { key: KEY }, update: { value }, create: { key: KEY, value } });
    await this.cache.del(CACHE_KEY);
    await this.activity.log({ userId: user.id, action: 'home_layout.update', entityType: 'settings', entityId: 'home_layout' });
    return this.admin();
  }

  async reset(user: AuthUser) {
    await this.prisma.platformSetting.deleteMany({ where: { key: KEY } });
    await this.cache.del(CACHE_KEY);
    await this.activity.log({ userId: user.id, action: 'home_layout.reset', entityType: 'settings', entityId: 'home_layout' });
    return this.admin();
  }
}
