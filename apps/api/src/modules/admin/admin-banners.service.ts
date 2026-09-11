import { Injectable, NotFoundException } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

export type BannerInput = {
  title: string;
  subtitle?: string;
  imageUrl: string;
  linkUrl?: string;
  sortOrder?: number;
  isActive?: boolean;
};

@Injectable()
export class AdminBannersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
  ) {}

  private invalidateCache() {
    return this.cache.del('cache:banners:active');
  }

  list() {
    return this.prisma.banner.findMany({ orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }] });
  }

  publicList() {
    return this.prisma.banner.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  create(user: AuthUser, dto: BannerInput) {
    return this.prisma.banner
      .create({
        data: {
          title: dto.title,
          subtitle: dto.subtitle ?? '',
          imageUrl: dto.imageUrl,
          linkUrl: dto.linkUrl,
          sortOrder: dto.sortOrder ?? 0,
          isActive: dto.isActive ?? true,
        },
      })
      .then(async (banner) => {
        await this.activity.log({
          userId: user.id,
          action: 'banner.create',
          entityType: 'banner',
          entityId: banner.id,
        });
        await this.invalidateCache();
        return banner;
      });
  }

  async update(user: AuthUser, id: string, dto: Partial<BannerInput>) {
    await this.ensure(id);
    const banner = await this.prisma.banner.update({ where: { id }, data: dto });
    await this.activity.log({
      userId: user.id,
      action: 'banner.update',
      entityType: 'banner',
      entityId: id,
    });
    await this.invalidateCache();
    return banner;
  }

  async remove(user: AuthUser, id: string) {
    await this.ensure(id);
    await this.prisma.banner.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'banner.delete',
      entityType: 'banner',
      entityId: id,
    });
    await this.invalidateCache();
    return { deleted: true };
  }

  private ensure(id: string) {
    return this.prisma.banner.findUnique({ where: { id } }).then((b) => {
      if (!b) throw new NotFoundException('البانر غير موجود');
      return b;
    });
  }
}
