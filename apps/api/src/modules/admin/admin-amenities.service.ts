import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PropertyType, Prisma } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminAmenityDto } from './dto/admin-amenity.dto';

@Injectable()
export class AdminAmenitiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
  ) {}

  list(query: Record<string, string | undefined>) {
    const where: Prisma.AmenityWhereInput = {};
    if (query.type) {
      where.appliesTo = { has: query.type as PropertyType };
    }
    if (query.category) where.category = query.category;
    if (query.q) {
      where.OR = [
        { nameAr: { contains: query.q } },
        { nameEn: { contains: query.q, mode: 'insensitive' } },
      ];
    }
    if (query.activeOnly === 'true') where.isActive = true;

    return this.prisma.amenity.findMany({
      where,
      include: { _count: { select: { properties: true } } },
      orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
    });
  }

  async create(user: AuthUser, dto: AdminAmenityDto) {
    await this.assertUniqueSlug(dto.slug ?? null, dto.nameAr);
    const amenity = await this.prisma.amenity.create({
      data: {
        nameAr: dto.nameAr.trim(),
        nameEn: dto.nameEn?.trim() ?? '',
        slug: dto.slug?.trim() || this.slugify(dto.nameAr.trim()),
        icon: dto.icon ?? '',
        category: dto.category?.trim() || 'general',
        appliesTo: dto.appliesTo ?? [],
        sortOrder: dto.sortOrder ?? 0,
        isActive: dto.isActive ?? true,
        isSystem: false,
      },
    });
    await this.activity.log({
      userId: user.id,
      action: 'amenity.create',
      entityType: 'amenity',
      entityId: amenity.id,
      metadata: { name: amenity.nameAr },
    });
    return amenity;
  }

  async update(user: AuthUser, id: string, dto: Partial<AdminAmenityDto>) {
    const existing = await this.prisma.amenity.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('الميزة غير موجودة');

    if (dto.slug && dto.slug !== existing.slug) {
      await this.assertUniqueSlug(dto.slug);
    }

    const amenity = await this.prisma.amenity.update({
      where: { id },
      data: {
        ...(dto.nameAr !== undefined ? { nameAr: dto.nameAr.trim() } : {}),
        ...(dto.nameEn !== undefined ? { nameEn: dto.nameEn.trim() } : {}),
        ...(dto.slug !== undefined ? { slug: dto.slug.trim() } : {}),
        ...(dto.icon !== undefined ? { icon: dto.icon } : {}),
        ...(dto.category !== undefined ? { category: dto.category.trim() || 'general' } : {}),
        ...(dto.appliesTo !== undefined ? { appliesTo: dto.appliesTo } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });

    // Keep the legacy JSON mirror coherent when a display name changes.
    if (dto.nameAr !== undefined && dto.nameAr.trim() !== existing.nameAr) {
      await this.renameInLegacyJson(existing.nameAr, amenity.nameAr);
    }

    await this.activity.log({
      userId: user.id,
      action: 'amenity.update',
      entityType: 'amenity',
      entityId: id,
      metadata: { name: amenity.nameAr },
    });
    return amenity;
  }

  async remove(user: AuthUser, id: string) {
    const existing = await this.prisma.amenity.findUnique({
      where: { id },
      include: { _count: { select: { properties: true } } },
    });
    if (!existing) throw new NotFoundException('الميزة غير موجودة');
    if (existing._count.properties > 0) {
      throw new BadRequestException(
        `لا يمكن حذف ميزة مستخدمة في ${existing._count.properties} مكاناً — عطّلها بدلاً من الحذف`,
      );
    }
    await this.prisma.amenity.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'amenity.delete',
      entityType: 'amenity',
      entityId: id,
      metadata: { name: existing.nameAr },
    });
    return { deleted: true };
  }

  private async assertUniqueSlug(slug: string | null, nameAr?: string) {
    if (slug) {
      const clash = await this.prisma.amenity.findUnique({ where: { slug } });
      if (clash) throw new BadRequestException('المعرّف (slug) مستخدم مسبقاً');
      return;
    }
    if (nameAr) {
      const clash = await this.prisma.amenity.findFirst({ where: { nameAr: nameAr.trim() } });
      if (clash) throw new BadRequestException('توجد ميزة بنفس الاسم');
    }
  }

  /** Swaps the old display name for the new one in every mirrored JSON column. */
  private async renameInLegacyJson(oldName: string, newName: string) {
    const properties = await this.prisma.property.findMany({
      where: { amenities: { array_contains: oldName } },
      select: { id: true, amenities: true },
    });
    for (const property of properties) {
      const current = Array.isArray(property.amenities) ? (property.amenities as string[]) : [];
      await this.prisma.property.update({
        where: { id: property.id },
        data: { amenities: current.map((name) => (name === oldName ? newName : name)) },
      });
    }
  }

  private slugify(name: string) {
    return `am-${Buffer.from(name, 'utf8').toString('hex').slice(0, 40)}`;
  }
}
