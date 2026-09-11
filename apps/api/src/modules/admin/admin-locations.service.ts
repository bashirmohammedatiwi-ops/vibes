import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminLocationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
  ) {}

  private invalidateCache() {
    return this.cache.del('cache:provinces:all');
  }

  provinces() {
    return this.prisma.province.findMany({
      include: { cities: { orderBy: { nameAr: 'asc' } }, _count: { select: { cities: true } } },
      orderBy: { nameAr: 'asc' },
    });
  }

  async createProvince(user: AuthUser, data: { nameAr: string; nameEn: string; slug: string }) {
    const existing = await this.prisma.province.findUnique({ where: { slug: data.slug } });
    if (existing) throw new ConflictException('المحافظة موجودة');
    const province = await this.prisma.province.create({ data });
    await this.activity.log({
      userId: user.id,
      action: 'location.province.create',
      entityType: 'province',
      entityId: province.id,
    });
    await this.invalidateCache();
    return province;
  }

  async createCity(
    user: AuthUser,
    provinceId: string,
    data: { nameAr: string; nameEn: string; slug: string },
  ) {
    await this.ensureProvince(provinceId);
    const city = await this.prisma.city.create({
      data: { ...data, provinceId },
    });
    await this.activity.log({
      userId: user.id,
      action: 'location.city.create',
      entityType: 'city',
      entityId: city.id,
    });
    await this.invalidateCache();
    return city;
  }

  async deleteCity(user: AuthUser, id: string) {
    const count = await this.prisma.property.count({ where: { cityId: id } });
    if (count > 0) throw new ConflictException('لا يمكن حذف مدينة مرتبطة بأماكن');
    await this.prisma.city.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'location.city.delete',
      entityType: 'city',
      entityId: id,
    });
    await this.invalidateCache();
    return { deleted: true };
  }

  async deleteProvince(user: AuthUser, id: string) {
    await this.ensureProvince(id);

    const [cities, properties] = await Promise.all([
      this.prisma.city.count({ where: { provinceId: id } }),
      this.prisma.property.count({ where: { city: { provinceId: id } } }),
    ]);
    if (properties > 0) throw new ConflictException('لا يمكن حذف محافظة مرتبطة بأماكن');
    if (cities > 0) throw new ConflictException('احذف مدن المحافظة أولاً');

    await this.prisma.province.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'location.province.delete',
      entityType: 'province',
      entityId: id,
    });
    await this.invalidateCache();
    return { deleted: true };
  }

  async updateProvince(user: AuthUser, id: string, data: { nameAr: string; nameEn?: string }) {
    await this.ensureProvince(id);
    const province = await this.prisma.province.update({
      where: { id },
      data: { nameAr: data.nameAr, nameEn: data.nameEn ?? data.nameAr },
    });
    await this.activity.log({
      userId: user.id,
      action: 'location.province.update',
      entityType: 'province',
      entityId: id,
      metadata: { name: data.nameAr },
    });
    await this.invalidateCache();
    return province;
  }

  async updateCity(user: AuthUser, id: string, data: { nameAr: string; nameEn?: string }) {
    const city = await this.prisma.city.findUnique({ where: { id } });
    if (!city) throw new NotFoundException('المدينة غير موجودة');
    const updated = await this.prisma.city.update({
      where: { id },
      data: { nameAr: data.nameAr, nameEn: data.nameEn ?? data.nameAr },
    });
    await this.activity.log({
      userId: user.id,
      action: 'location.city.update',
      entityType: 'city',
      entityId: id,
      metadata: { name: data.nameAr },
    });
    await this.invalidateCache();
    return updated;
  }

  private ensureProvince(id: string) {
    return this.prisma.province.findUnique({ where: { id } }).then((p) => {
      if (!p) throw new NotFoundException('المحافظة غير موجودة');
      return p;
    });
  }
}
