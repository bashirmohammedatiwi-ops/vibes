import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PropertyStatus } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AmenitySyncService } from '../../common/services/amenity-sync.service';
import { CacheService } from '../../common/services/cache.service';
import { NotificationService } from '../../common/services/notification.service';
import { PaginationService, PropertyQueryBuilder } from '../../common/services/query-helpers';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { uniqueSlug } from '../../common/utils/slug.util';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminCreatePropertyDto, AdminUpdatePropertyDto } from './dto/admin-property.dto';

const propertyInclude = {
  city: { include: { province: true } },
  media: { orderBy: { sortOrder: 'asc' as const } },
  amenityLinks: { include: { amenity: true }, orderBy: { sortOrder: 'asc' as const } },
  createdBy: { select: { id: true, name: true, phone: true } },
  provider: { include: { user: { select: { name: true, phone: true } } } },
  _count: { select: { bookings: true, reviews: true } },
};

@Injectable()
export class AdminPropertiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly queryBuilder: PropertyQueryBuilder,
    private readonly activity: ActivityLogService,
    private readonly notifications: NotificationService,
    private readonly cache: CacheService,
    private readonly amenitySync: AmenitySyncService,
  ) {}

  private invalidatePublicCache() {
    return this.cache.invalidatePrefix('cache:properties:');
  }

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where = this.queryBuilder.buildFilters(query);

    const [items, total] = await Promise.all([
      this.prisma.property.findMany({
        where,
        include: propertyInclude,
        orderBy: [{ featured: 'desc' }, { updatedAt: 'desc' }],
        skip,
        take,
      }),
      this.prisma.property.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  getOne(id: string) {
    return this.prisma.property.findUnique({
      where: { id },
      include: {
        ...propertyInclude,
        priceRules: { orderBy: [{ priority: 'desc' as const }, { createdAt: 'desc' as const }] },
        availabilitySlots: { orderBy: { date: 'asc' }, take: 60 },
        reviews: {
          include: { user: { select: { name: true, phone: true } } },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
      },
    }).then((p) => {
      if (!p) throw new NotFoundException('المكان غير موجود');
      return p;
    });
  }

  async create(user: AuthUser, dto: AdminCreatePropertyDto) {
    const slug = dto.slug
      ? dto.slug
      : await uniqueSlug(dto.name, async (s) => !!(await this.prisma.property.findUnique({ where: { slug: s } })));

    const status = dto.status ?? PropertyStatus.DRAFT;
    const property = await this.prisma.property.create({
      data: {
        createdById: user.id,
        type: dto.type,
        slug,
        name: dto.name,
        nameEn: dto.nameEn ?? '',
        description: dto.description ?? '',
        descriptionEn: dto.descriptionEn ?? '',
        metaTitle: dto.metaTitle ?? dto.name,
        metaDescription: dto.metaDescription ?? (dto.description ?? '').slice(0, 160),
        cityId: dto.cityId,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        capacity: dto.capacity ?? 0,
        bookingMode: dto.bookingMode,
        morningStart: dto.morningStart,
        morningEnd: dto.morningEnd,
        eveningStart: dto.eveningStart,
        eveningEnd: dto.eveningEnd,
        pricePerDay: dto.pricePerDay,
        weekendPrice: dto.weekendPrice,
        priceMorningShift: dto.priceMorningShift,
        priceEveningShift: dto.priceEveningShift,
        phone: dto.phone,
        whatsapp: dto.whatsapp,
        featured: dto.featured ?? false,
        isNew: dto.isNew ?? false,
        amenities: dto.amenities ?? [],
        tags: dto.tags ?? [],
        rules: dto.rules ?? '',
        internalNotes: dto.internalNotes ?? '',
        status,
        publishedAt: status === PropertyStatus.APPROVED ? new Date() : null,
        ...(dto.providerId ? { providerId: dto.providerId } : {}),
      },
      include: propertyInclude,
    });

    await this.activity.log({
      userId: user.id,
      action: 'property.create',
      entityType: 'property',
      entityId: property.id,
      metadata: { name: property.name, type: property.type },
    });

    if (status === PropertyStatus.PENDING) {
      await this.notifications.propertyPending({ id: property.id, name: property.name });
    }

    if (dto.amenityIds !== undefined) {
      await this.amenitySync.replacePropertyAmenities(property.id, dto.amenityIds);
    } else if (dto.amenities !== undefined) {
      await this.amenitySync.replaceFromLegacyNames(property.id, dto.amenities ?? []);
    }
    await this.invalidatePublicCache();

    return this.getOne(property.id);
  }

  async update(user: AuthUser, id: string, dto: Partial<AdminUpdatePropertyDto>) {
    const existing = await this.getOne(id);
    let slug = existing.slug;

    if (dto.slug && dto.slug !== existing.slug) {
      slug = await uniqueSlug(dto.slug, async (s) => {
        const found = await this.prisma.property.findUnique({ where: { slug: s } });
        return !!found && found.id !== id;
      });
    } else if (dto.name && dto.name !== existing.name && !dto.slug) {
      slug = await uniqueSlug(dto.name, async (s) => {
        const found = await this.prisma.property.findUnique({ where: { slug: s } });
        return !!found && found.id !== id;
      });
    }

    const status = dto.status ?? existing.status;
    const property = await this.prisma.property.update({
      where: { id },
      data: {
        type: dto.type,
        slug,
        name: dto.name,
        nameEn: dto.nameEn,
        description: dto.description,
        descriptionEn: dto.descriptionEn,
        metaTitle: dto.metaTitle,
        metaDescription: dto.metaDescription,
        cityId: dto.cityId,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        capacity: dto.capacity,
        bookingMode: dto.bookingMode,
        morningStart: dto.morningStart,
        morningEnd: dto.morningEnd,
        eveningStart: dto.eveningStart,
        eveningEnd: dto.eveningEnd,
        pricePerDay: dto.pricePerDay,
        weekendPrice: dto.weekendPrice,
        priceMorningShift: dto.priceMorningShift,
        priceEveningShift: dto.priceEveningShift,
        phone: dto.phone,
        whatsapp: dto.whatsapp,
        featured: dto.featured,
        isNew: dto.isNew,
        amenities: dto.amenities,
        tags: dto.tags,
        rules: dto.rules,
        internalNotes: dto.internalNotes,
        status,
        publishedAt:
          status === PropertyStatus.APPROVED && !existing.publishedAt ? new Date() : existing.publishedAt,
        ...(dto.providerId !== undefined ? { providerId: dto.providerId || null } : {}),
      },
      include: propertyInclude,
    });

    if (dto.amenityIds !== undefined) {
      await this.amenitySync.replacePropertyAmenities(id, dto.amenityIds);
    } else if (dto.amenities !== undefined) {
      await this.amenitySync.replaceFromLegacyNames(id, dto.amenities ?? []);
    }
    await this.activity.log({
      userId: user.id,
      action: 'property.update',
      entityType: 'property',
      entityId: id,
    });
    await this.invalidatePublicCache();

    return this.getOne(id);
  }

  async remove(user: AuthUser, id: string) {
    await this.getOne(id);
    await this.prisma.property.delete({ where: { id } });
    await this.activity.log({
      userId: user.id,
      action: 'property.delete',
      entityType: 'property',
      entityId: id,
    });
    await this.invalidatePublicCache();
    return { deleted: true };
  }

  async publish(user: AuthUser, id: string) {
    await this.getOne(id);
    const property = await this.prisma.property.update({
      where: { id },
      data: { status: PropertyStatus.APPROVED, publishedAt: new Date() },
      include: propertyInclude,
    });
    await this.activity.log({
      userId: user.id,
      action: 'property.publish',
      entityType: 'property',
      entityId: id,
    });
    await this.invalidatePublicCache();
    return property;
  }

  async suspend(user: AuthUser, id: string) {
    await this.getOne(id);
    const property = await this.prisma.property.update({
      where: { id },
      data: { status: PropertyStatus.SUSPENDED },
      include: propertyInclude,
    });
    await this.activity.log({
      userId: user.id,
      action: 'property.suspend',
      entityType: 'property',
      entityId: id,
    });
    await this.invalidatePublicCache();
    return property;
  }

  async reject(user: AuthUser, id: string, reason: string) {
    if (!reason.trim()) {
      throw new BadRequestException('أضف سبب الرفض');
    }
    const property = await this.prisma.property.update({
      where: { id },
      data: {
        status: PropertyStatus.REJECTED,
        rejectionReason: reason.trim(),
      },
      include: propertyInclude,
    });

    await this.activity.log({
      userId: user.id,
      action: 'property.reject',
      entityType: 'property',
      entityId: id,
      metadata: { reason },
    });
    await this.invalidatePublicCache();

    return property;
  }

  async bulk(user: AuthUser, action: string, ids: string[]) {
    if (!ids.length) return { updated: 0 };

    const data: Record<string, CallableFunction> = {
      publish: () =>
        this.prisma.property.updateMany({
          where: { id: { in: ids } },
          data: { status: PropertyStatus.APPROVED, publishedAt: new Date() },
        }),
      suspend: () =>
        this.prisma.property.updateMany({
          where: { id: { in: ids } },
          data: { status: PropertyStatus.SUSPENDED },
        }),
      feature: () => this.prisma.property.updateMany({ where: { id: { in: ids } }, data: { featured: true } }),
      unfeature: () => this.prisma.property.updateMany({ where: { id: { in: ids } }, data: { featured: false } }),
      delete: () => this.prisma.property.deleteMany({ where: { id: { in: ids } } }),
    };

    const fn = data[action];
    if (!fn) return { updated: 0, error: 'unknown action' };
    await fn();

    await this.activity.log({
      userId: user.id,
      action: 'property.bulk',
      entityType: 'property',
      metadata: { action, count: ids.length, ids: ids.slice(0, 20) },
    });
    await this.invalidatePublicCache();

    return { updated: ids.length, action };
  }

  async duplicate(user: AuthUser, sourceId: string) {
    const source = await this.prisma.property.findUnique({
      where: { id: sourceId },
      include: {
        media: { orderBy: { sortOrder: 'asc' } },
        amenityLinks: { orderBy: { sortOrder: 'asc' } },
        priceRules: { where: { isActive: true } },
      },
    });
    if (!source) throw new NotFoundException('المكان غير موجود');

    const baseSlug = `${source.slug}-copy`;
    let slug = baseSlug;
    let i = 1;
    while (await this.prisma.property.findUnique({ where: { slug } })) {
      slug = `${baseSlug}-${i++}`;
    }

    const copy = await this.prisma.property.create({
      data: {
        createdById: user.id,
        type: source.type,
        slug,
        name: `${source.name} (نسخة)`,
        nameEn: source.nameEn,
        description: source.description,
        descriptionEn: source.descriptionEn,
        metaTitle: source.metaTitle,
        metaDescription: source.metaDescription,
        cityId: source.cityId,
        address: source.address,
        latitude: source.latitude,
        longitude: source.longitude,
        capacity: source.capacity,
        bookingMode: source.bookingMode,
        morningStart: source.morningStart,
        morningEnd: source.morningEnd,
        eveningStart: source.eveningStart,
        eveningEnd: source.eveningEnd,
        pricePerDay: source.pricePerDay,
        weekendPrice: source.weekendPrice,
        priceMorningShift: source.priceMorningShift,
        priceEveningShift: source.priceEveningShift,
        phone: source.phone,
        whatsapp: source.whatsapp,
        amenities: source.amenities ?? [],
        tags: source.tags ?? [],
        rules: source.rules,
        internalNotes: source.internalNotes,
        status: PropertyStatus.DRAFT,
        featured: false,
        isNew: false,
      },
      include: propertyInclude,
    });

    if (source.media.length) {
      await this.prisma.media.createMany({
        data: source.media.map((m, index) => ({
          propertyId: copy.id,
          uploadedById: user.id,
          type: m.type,
          status: m.status,
          url: m.url,
          thumbnailUrl: m.thumbnailUrl,
          caption: m.caption,
          altText: m.altText,
          sortOrder: index,
          isPrimary: index === 0,
          mimeType: m.mimeType,
        })),
      });
    }

    if (source.amenityLinks.length) {
      await this.prisma.propertyAmenity.createMany({
        data: source.amenityLinks.map((link, index) => ({
          propertyId: copy.id,
          amenityId: link.amenityId,
          value: link.value,
          sortOrder: index,
        })),
        skipDuplicates: true,
      });
    }

    if (source.priceRules.length) {
      await this.prisma.priceRule.createMany({
        data: source.priceRules.map(({ id: _id, propertyId: _pid, createdAt: _c, updatedAt: _u, ...rule }) => ({
          ...rule,
          propertyId: copy.id,
        })),
      });
    }

    await this.activity.log({
      userId: user.id,
      action: 'property.duplicate',
      entityType: 'property',
      entityId: copy.id,
      metadata: { sourceId },
    });

    return this.getOne(copy.id);
  }
}
