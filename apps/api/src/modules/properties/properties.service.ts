import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { KycStatus, Prisma, PropertyStatus, UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { AmenitySyncService } from '../../common/services/amenity-sync.service';
import { CacheService } from '../../common/services/cache.service';
import { NotificationService } from '../../common/services/notification.service';
import { PaginationService, PropertyQueryBuilder } from '../../common/services/query-helpers';
import { resolveDayPricing, type PriceRuleLike, type PropertyPricing } from '../../common/utils/pricing.util';
import { dateKey, eachDay, resolveBookingMode, resolveShiftTimes, shiftsRequiredForBooking } from '../../common/utils/shift.util';
import { uniqueSlug } from '../../common/utils/slug.util';
import { PrismaService } from '../../prisma/prisma.service';
import { CreatePropertyDto, UpdatePropertyDto } from './dto/create-property.dto';

const CACHE_NAMESPACE = 'properties';
const LIST_TTL_SECONDS = 30;
const DETAIL_TTL_SECONDS = 60;

const include = {
  city: { include: { province: true } },
  media: { orderBy: { sortOrder: 'asc' as const }, where: { status: 'READY' as const } },
  amenityLinks: {
    include: { amenity: { select: { id: true, nameAr: true, nameEn: true, icon: true, category: true } } },
    orderBy: { sortOrder: 'asc' as const },
  },
  provider: { include: { user: { select: { name: true, phone: true } } } },
  _count: { select: { reviews: true } },
};

function isStaff(user: AuthUser) {
  return user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
}

function contentChanged(
  property: {
    name: string;
    description: string;
    cityId: string;
    address: string | null;
    type: string;
    capacity: number;
    pricePerDay: Prisma.Decimal;
    latitude: Prisma.Decimal;
    longitude: Prisma.Decimal;
    amenities: Prisma.JsonValue;
  },
  dto: UpdatePropertyDto,
) {
  if (dto.name !== undefined && dto.name !== property.name) return true;
  if (dto.description !== undefined && dto.description !== property.description) return true;
  if (dto.cityId !== undefined && dto.cityId !== property.cityId) return true;
  if (dto.address !== undefined && (dto.address ?? null) !== property.address) return true;
  if (dto.type !== undefined && dto.type !== property.type) return true;
  if (dto.capacity !== undefined && dto.capacity !== property.capacity) return true;
  if (dto.pricePerDay !== undefined && Number(dto.pricePerDay) !== Number(property.pricePerDay)) return true;
  if (dto.latitude !== undefined && Number(dto.latitude) !== Number(property.latitude)) return true;
  if (dto.longitude !== undefined && Number(dto.longitude) !== Number(property.longitude)) return true;
  if (dto.amenities !== undefined) {
    return JSON.stringify(dto.amenities) !== JSON.stringify(property.amenities ?? []);
  }
  return false;
}

@Injectable()
export class PropertiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly queryBuilder: PropertyQueryBuilder,
    private readonly notifications: NotificationService,
    private readonly cache: CacheService,
    private readonly amenitySync: AmenitySyncService,
  ) {}

  async list(params: {
    type?: string;
    status?: string;
    cityId?: string;
    featured?: string;
    page?: string;
    pageSize?: string;
    q?: string;
  }) {
    const cacheKey = CacheService.keyFrom(`${CACHE_NAMESPACE}:list`, params);
    return this.cache.getOrSet(cacheKey, LIST_TTL_SECONDS, async () => {
      const where = this.queryBuilder.buildFilters({
        ...params,
        status: PropertyStatus.APPROVED,
      });
      const { page, pageSize, skip, take } = this.pagination.parse(params.page, params.pageSize);

      const [items, total] = await Promise.all([
        this.prisma.property.findMany({
          where,
          include,
          orderBy: [{ featured: 'desc' }, { ratingAvg: 'desc' }, { createdAt: 'desc' }],
          skip,
          take,
        }),
        this.prisma.property.count({ where }),
      ]);

      if (params.page) {
        return this.pagination.wrap(items, total, page, pageSize);
      }
      return items;
    });
  }

  async listMine(user: AuthUser) {
    const provider = await this.prisma.provider.findUnique({ where: { userId: user.id } });
    if (!provider) return [];

    return this.prisma.property.findMany({
      where: { providerId: provider.id },
      include,
      orderBy: { updatedAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const cacheKey = CacheService.keyFrom(`${CACHE_NAMESPACE}:detail:id`, { id });
    const cached = await this.cache.get<Prisma.PropertyGetPayload<{ include: typeof include }>>(cacheKey);
    if (cached) return cached;

    const property = await this.prisma.property.findUnique({
      where: { id },
      include: {
        ...include,
        reviews: {
          where: { isVisible: true },
          include: { user: { select: { name: true } } },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
      },
    });
    if (!property || property.status !== PropertyStatus.APPROVED) {
      throw new NotFoundException('المكان غير موجود');
    }

    // View counter is best-effort: only incremented on cache misses, trading
    // exact accuracy for avoiding a write on every single page view.
    void this.prisma.property.update({ where: { id }, data: { viewCount: { increment: 1 } } }).catch(() => undefined);
    await this.cache.set(cacheKey, property, DETAIL_TTL_SECONDS);

    return property;
  }

  async metaBySlug(slug: string) {
    const property = await this.prisma.property.findFirst({
      where: { slug, status: PropertyStatus.APPROVED },
      select: {
        name: true,
        nameEn: true,
        metaTitle: true,
        metaDescription: true,
        description: true,
        slug: true,
        type: true,
        ratingAvg: true,
        ratingCount: true,
        pricePerDay: true,
        city: { select: { nameAr: true, province: { select: { nameAr: true } } } },
        media: { where: { isPrimary: true }, take: 1, select: { url: true, altText: true } },
      },
    });
    if (!property) throw new NotFoundException('المكان غير موجود');

    const title = property.metaTitle || property.name;
    const description = property.metaDescription || property.description.slice(0, 160);
    const image = property.media[0]?.url;

    return {
      title,
      description,
      name: property.name,
      nameEn: property.nameEn,
      slug: property.slug,
      type: property.type,
      pricePerDay: property.pricePerDay,
      ratingAvg: property.ratingAvg,
      ratingCount: property.ratingCount,
      city: property.city.nameAr,
      province: property.city.province.nameAr,
      og: { title, description, image, url: `/places/${property.slug}` },
    };
  }

  async findBySlug(slug: string) {
    const cacheKey = CacheService.keyFrom(`${CACHE_NAMESPACE}:detail:slug`, { slug });
    const cached = await this.cache.get<Prisma.PropertyGetPayload<{ include: typeof include }>>(cacheKey);
    if (cached) return cached;

    const property = await this.prisma.property.findUnique({
      where: { slug },
      include: {
        ...include,
        reviews: {
          where: { isVisible: true },
          include: { user: { select: { name: true } } },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
      },
    });
    if (!property || property.status !== PropertyStatus.APPROVED) {
      throw new NotFoundException('المكان غير موجود');
    }
    void this.prisma.property
      .update({ where: { id: property.id }, data: { viewCount: { increment: 1 } } })
      .catch(() => undefined);
    await this.cache.set(cacheKey, property, DETAIL_TTL_SECONDS);
    return property;
  }

  async create(user: AuthUser, dto: CreatePropertyDto) {
    const provider = await this.ensureVerifiedProvider(user.id);
    const slug = await uniqueSlug(
      dto.name,
      async (s) => !!(await this.prisma.property.findUnique({ where: { slug: s } })),
    );

    const property = await this.prisma.property.create({
      data: {
        providerId: provider.id,
        type: dto.type,
        slug,
        name: dto.name,
        description: dto.description ?? '',
        cityId: dto.cityId,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        capacity: dto.capacity ?? 0,
        pricePerDay: dto.pricePerDay,
        amenities: dto.amenities ?? [],
        status: PropertyStatus.PENDING,
      },
      include,
    });

    await this.notifications.propertyPending(property);

    if (dto.amenities !== undefined) {
      await this.amenitySync.replaceFromLegacyNames(property.id, dto.amenities ?? []);
    }
    await this.invalidateCache();
    return property;
  }

  async update(user: AuthUser, id: string, dto: UpdatePropertyDto) {
    const property = await this.findOwned(user, id);
    const providerEdit = !isStaff(user);
    if (providerEdit) {
      await this.ensureVerifiedProvider(user.id);
    }

    const shouldReReview =
      providerEdit &&
      contentChanged(property, dto) &&
      (property.status === PropertyStatus.APPROVED ||
        property.status === PropertyStatus.REJECTED ||
        property.status === PropertyStatus.SUSPENDED);

    const updated = await this.prisma.property.update({
      where: { id },
      data: {
        ...(dto.type !== undefined ? { type: dto.type } : {}),
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.description !== undefined ? { description: dto.description } : {}),
        ...(dto.cityId !== undefined ? { cityId: dto.cityId } : {}),
        ...(dto.address !== undefined ? { address: dto.address } : {}),
        ...(dto.latitude !== undefined ? { latitude: dto.latitude } : {}),
        ...(dto.longitude !== undefined ? { longitude: dto.longitude } : {}),
        ...(dto.capacity !== undefined ? { capacity: dto.capacity } : {}),
        ...(dto.pricePerDay !== undefined ? { pricePerDay: dto.pricePerDay } : {}),
        ...(dto.amenities !== undefined ? { amenities: dto.amenities } : {}),
        ...(shouldReReview
          ? { status: PropertyStatus.PENDING, rejectionReason: null, publishedAt: undefined }
          : {}),
      },
      include,
    });

    if (shouldReReview) {
      await this.notifications.propertyPending(updated);
    }
    if (dto.amenities !== undefined) {
      await this.amenitySync.replaceFromLegacyNames(id, dto.amenities ?? []);
    }
    await this.invalidateCache();

    return updated;
  }

  async remove(user: AuthUser, id: string) {
    await this.findOwned(user, id);
    if (!isStaff(user)) {
      throw new ForbiddenException('حذف الأماكن متاح للفريق فقط');
    }
    await this.prisma.property.delete({ where: { id } });
    await this.invalidateCache();
    return { deleted: true };
  }

  async attachMedia(user: AuthUser, propertyId: string, mediaId: string) {
    const property = await this.findOwned(user, propertyId);
    if (!isStaff(user)) {
      await this.ensureVerifiedProvider(user.id);
    }

    const media = await this.prisma.media.findUnique({ where: { id: mediaId } });
    if (!media) throw new NotFoundException('الملف غير موجود');
    if (media.uploadedById && media.uploadedById !== user.id && !isStaff(user)) {
      throw new ForbiddenException('لا يمكنك إرفاق ملف لم ترفعه');
    }
    if (media.propertyId && media.propertyId !== propertyId) {
      throw new BadRequestException('هذا الملف مرتبط بمكان آخر');
    }

    const maxSort = await this.prisma.media.aggregate({
      where: { propertyId },
      _max: { sortOrder: true },
    });
    const isFirst = (await this.prisma.media.count({ where: { propertyId } })) === 0;

    const attached = await this.prisma.media.update({
      where: { id: mediaId },
      data: {
        propertyId,
        sortOrder: (maxSort._max.sortOrder ?? -1) + 1,
        isPrimary: isFirst,
      },
    });

    if (!isStaff(user) && property.status === PropertyStatus.APPROVED) {
      await this.prisma.property.update({
        where: { id: propertyId },
        data: { status: PropertyStatus.PENDING },
      });
      await this.notifications.propertyPending(property);
    }
    await this.invalidateCache();

    return attached;
  }

  async availability(id: string, month?: string) {
    const property = await this.prisma.property.findUnique({ where: { id } });
    if (!property || property.status !== PropertyStatus.APPROVED) {
      throw new NotFoundException('المكان غير موجود');
    }
    const start = month ? new Date(`${month}-01`) : new Date();
    const end = new Date(start);
    end.setMonth(end.getMonth() + 1);

    const [slots, bookings, rules] = await Promise.all([
      this.prisma.availabilitySlot.findMany({
        where: { propertyId: id, date: { gte: start, lt: end } },
        orderBy: [{ date: 'asc' }, { shift: 'asc' }],
      }),
      this.prisma.booking.findMany({
        where: {
          propertyId: id,
          status: { in: ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'] },
          startDate: { lt: end },
          endDate: { gt: start },
        },
        select: { startDate: true, endDate: true, shift: true },
      }),
      this.prisma.priceRule.findMany({ where: { propertyId: id, isActive: true } }),
    ]);

    const bookingDays = new Set(
      bookings.flatMap((b) => eachDay(new Date(b.startDate), new Date(b.endDate)).map(dateKey)),
    );
    const blockedDays = new Set(
      slots.filter((slot) => !slot.isAvailable).map((slot) => dateKey(slot.date)),
    );

    const dayPrices = eachDay(start, end).map((day) => {
      const pricing = resolveDayPricing(property as PropertyPricing, rules as PriceRuleLike[], day);
      const key = dateKey(day);
      return {
        date: key,
        prices: { full: pricing.full, morning: pricing.morning, evening: pricing.evening },
        isBooked: bookingDays.has(key),
        isBlocked: blockedDays.has(key),
        bookableShifts: shiftsRequiredForBooking('FULL').filter((shift) => !blockedDays.has(key)),
      };
    });

    return {
      propertyType: property.type,
      bookingMode: resolveBookingMode(property.type, property.bookingMode),
      shiftTimes: resolveShiftTimes(property),
      slots,
      bookings,
      dayPrices,
    };
  }

  async setStatus(id: string, status: PropertyStatus) {
    const updated = await this.prisma.property.update({
      where: { id },
      data: {
        status,
        publishedAt: status === PropertyStatus.APPROVED ? new Date() : undefined,
      },
    });
    await this.invalidateCache();
    return updated;
  }

  private invalidateCache() {
    return this.cache.invalidatePrefix(`cache:${CACHE_NAMESPACE}:`);
  }

  private async ensureVerifiedProvider(userId: string) {
    const provider = await this.prisma.provider.findUnique({ where: { userId } });
    if (!provider) throw new ForbiddenException('يجب التسجيل كمزود أولاً');
    if (provider.kycStatus !== KycStatus.VERIFIED) {
      throw new ForbiddenException('حساب المزود بانتظار موافقة الفريق قبل إضافة الأماكن');
    }
    return provider;
  }

  private async findOwned(user: AuthUser, id: string) {
    const property = await this.prisma.property.findUnique({
      where: { id },
      include: { provider: true },
    });
    if (!property) throw new NotFoundException('المكان غير موجود');

    if (isStaff(user)) return property;

    if (!property.provider || property.provider.userId !== user.id) {
      throw new NotFoundException('المكان غير موجود');
    }
    return property;
  }
}
