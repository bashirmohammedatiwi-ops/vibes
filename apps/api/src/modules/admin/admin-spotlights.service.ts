import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

export type SpotlightInput = {
  title?: string;
  imageUrl: string;
  propertyId: string;
  height?: number;
  sortOrder?: number;
  isActive?: boolean;
};

const spotlightInclude = {
  property: {
    select: {
      id: true,
      name: true,
      type: true,
      slug: true,
    },
  },
} as const;

@Injectable()
export class AdminSpotlightsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
  ) {}

  private invalidateCache() {
    return this.cache.del('cache:spotlights:active');
  }

  private clampHeight(height?: number) {
    if (height == null) return 176;
    return Math.min(280, Math.max(140, Math.round(height)));
  }

  list() {
    return this.prisma.homeSpotlight.findMany({
      include: spotlightInclude,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  publicList() {
    return this.prisma.homeSpotlight.findMany({
      where: { isActive: true },
      include: spotlightInclude,
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async create(user: AuthUser, dto: SpotlightInput) {
    await this.ensureProperty(dto.propertyId);
    const item = await this.prisma.homeSpotlight.create({
      data: {
        title: dto.title?.trim() ?? '',
        imageUrl: dto.imageUrl,
        propertyId: dto.propertyId,
        height: this.clampHeight(dto.height),
        sortOrder: dto.sortOrder ?? 0,
        isActive: dto.isActive ?? true,
      },
      include: spotlightInclude,
    });
    await this.activity.log({
      userId: user.id,
      action: 'spotlight.create',
      entityType: 'home_spotlight',
      entityId: item.id,
    });
    await this.invalidateCache();
    return item;
  }

  async update(user: AuthUser, id: string, dto: Partial<SpotlightInput>) {
    await this.ensure(id);
    if (dto.propertyId) await this.ensureProperty(dto.propertyId);
    const item = await this.prisma.homeSpotlight.update({
      where: { id },
      data: {
        ...(dto.title !== undefined ? { title: dto.title.trim() } : {}),
        ...(dto.imageUrl !== undefined ? { imageUrl: dto.imageUrl } : {}),
        ...(dto.propertyId !== undefined ? { propertyId: dto.propertyId } : {}),
        ...(dto.height !== undefined ? { height: this.clampHeight(dto.height) } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
      include: spotlightInclude,
    });
    await this.activity.log({
      userId: user.id,
      action: 'spotlight.update',
      entityType: 'home_spotlight',
      entityId: id,
    });
    await this.invalidateCache();
    return item;
  }

  async remove(user: AuthUser, id: string) {
    await this.ensure(id);
    await this.prisma.homeSpotlight.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'spotlight.delete',
      entityType: 'home_spotlight',
      entityId: id,
    });
    await this.invalidateCache();
  }

  private async ensure(id: string) {
    const item = await this.prisma.homeSpotlight.findUnique({ where: { id } });
    if (!item) throw new NotFoundException('العنصر غير موجود');
    return item;
  }

  private async ensureProperty(id: string) {
    const property = await this.prisma.property.findUnique({ where: { id } });
    if (!property) throw new BadRequestException('المكان المرتبط غير موجود');
    return property;
  }
}
