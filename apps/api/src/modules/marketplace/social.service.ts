import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, CollectionVisibility, SocialPostStatus, UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';

const propertyCard = {
  city: { include: { province: true } },
  media: { orderBy: { sortOrder: 'asc' as const }, take: 5, where: { status: 'READY' as const } },
};

@Injectable()
export class SocialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly lifecycle: MarketplaceLifecycleService,
  ) {}

  async listCollections(user: AuthUser) {
    await this.ensureDefault(user.id);
    return this.prisma.collection.findMany({
      where: { userId: user.id },
      include: {
        items: {
          include: { property: { include: propertyCard } },
          orderBy: { createdAt: 'desc' },
        },
        _count: { select: { items: true } },
      },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async listPublicCollections() {
    return this.prisma.collection.findMany({
      where: {
        visibility: CollectionVisibility.PUBLIC,
        items: { some: {} },
      },
      include: {
        user: { select: { name: true } },
        _count: { select: { items: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 30,
    });
  }

  async getCollection(user: AuthUser, id: string) {
    const collection = await this.prisma.collection.findUnique({
      where: { id },
      include: {
        items: {
          include: { property: { include: propertyCard } },
          orderBy: { createdAt: 'desc' },
        },
        user: { select: { id: true, name: true } },
      },
    });
    if (!collection) throw new NotFoundException('القائمة غير موجودة');
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    if (collection.userId !== user.id && collection.visibility !== CollectionVisibility.PUBLIC && !staff) {
      throw new ForbiddenException('هذه القائمة خاصة');
    }
    return collection;
  }

  async createCollection(user: AuthUser, dto: { name: string; description?: string; visibility?: CollectionVisibility }) {
    const name = dto.name.trim();
    if (name.length < 2) throw new BadRequestException('اسم القائمة قصير');
    return this.prisma.collection.create({
      data: {
        userId: user.id,
        name,
        description: dto.description?.trim() ?? '',
        visibility: dto.visibility ?? CollectionVisibility.PRIVATE,
      },
    });
  }

  async updateCollection(
    user: AuthUser,
    id: string,
    dto: {
      name?: string;
      description?: string;
      visibility?: CollectionVisibility;
      coverUrl?: string;
    },
  ) {
    const collection = await this.prisma.collection.findUnique({ where: { id } });
    if (!collection || collection.userId !== user.id) throw new ForbiddenException('غير مسموح');
    const name = dto.name?.trim();
    if (name !== undefined && name.length < 2) throw new BadRequestException('اسم القائمة قصير');
    return this.prisma.collection.update({
      where: { id },
      data: {
        ...(name ? { name } : {}),
        ...(dto.description !== undefined ? { description: dto.description.trim() } : {}),
        ...(dto.visibility ? { visibility: dto.visibility } : {}),
        ...(dto.coverUrl !== undefined
          ? { coverUrl: dto.coverUrl.trim() || null }
          : {}),
      },
    });
  }

  async deleteCollection(user: AuthUser, id: string) {
    const collection = await this.prisma.collection.findUnique({ where: { id } });
    if (!collection || collection.userId !== user.id) throw new ForbiddenException('غير مسموح');
    if (collection.isDefault) throw new BadRequestException('لا يمكن حذف القائمة الافتراضية');
    await this.prisma.collection.delete({ where: { id } });
    return { deleted: true };
  }

  async addItem(user: AuthUser, collectionId: string, propertyId: string, note?: string) {
    const collection = await this.prisma.collection.findUnique({ where: { id: collectionId } });
    if (!collection || collection.userId !== user.id) throw new ForbiddenException('غير مسموح');
    const property = await this.prisma.property.findUnique({ where: { id: propertyId } });
    if (!property) throw new NotFoundException('المكان غير موجود');
    const item = await this.prisma.collectionItem.upsert({
      where: { collectionId_propertyId: { collectionId, propertyId } },
      update: { note: note?.trim() ?? '' },
      create: { collectionId, propertyId, note: note?.trim() ?? '' },
    });
    if (!collection.coverUrl && property) {
      const media = await this.prisma.media.findFirst({
        where: { propertyId, status: 'READY' },
        orderBy: { isPrimary: 'desc' },
      });
      if (media) {
        await this.prisma.collection.update({
          where: { id: collectionId },
          data: { coverUrl: media.url },
        });
      }
    }
    return item;
  }

  async removeItem(user: AuthUser, collectionId: string, propertyId: string) {
    const collection = await this.prisma.collection.findUnique({ where: { id: collectionId } });
    if (!collection || collection.userId !== user.id) throw new ForbiddenException('غير مسموح');
    await this.prisma.collectionItem.deleteMany({ where: { collectionId, propertyId } });
    return { removed: true };
  }

  async follow(user: AuthUser, providerId: string) {
    const provider = await this.prisma.provider.findUnique({ where: { id: providerId } });
    if (!provider) throw new NotFoundException('المزود غير موجود');
    if (provider.userId === user.id) throw new BadRequestException('لا يمكنك متابعة نفسك');
    await this.prisma.providerFollow.upsert({
      where: { userId_providerId: { userId: user.id, providerId } },
      update: {},
      create: { userId: user.id, providerId },
    });
    await this.lifecycle.notifyUser({
      userId: provider.userId,
      type: 'SOCIAL',
      title: 'متابع جديد',
      body: 'شخص بدأ بمتابعة أماكنك',
      linkUrl: `/providers/${providerId}`,
      entityType: 'provider',
      entityId: providerId,
    });
    return { following: true };
  }

  async unfollow(user: AuthUser, providerId: string) {
    await this.prisma.providerFollow.deleteMany({ where: { userId: user.id, providerId } });
    return { following: false };
  }

  async listFollowing(user: AuthUser) {
    const rows = await this.prisma.providerFollow.findMany({
      where: { userId: user.id },
      include: {
        provider: {
          include: {
            user: { select: { id: true, name: true, avatar: true } },
            _count: { select: { followers: true, properties: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((row) => ({
      id: row.provider.id,
      businessName: row.provider.businessName,
      verified: row.provider.verified,
      user: row.provider.user,
      followers: row.provider._count.followers,
      propertiesCount: row.provider._count.properties,
      following: true,
    }));
  }

  async followStatus(user: AuthUser | undefined, providerId: string) {
    const [following, followers] = await Promise.all([
      user
        ? this.prisma.providerFollow.findUnique({
            where: { userId_providerId: { userId: user.id, providerId } },
          })
        : Promise.resolve(null),
      this.prisma.providerFollow.count({ where: { providerId } }),
    ]);
    return { following: !!following, followers };
  }

  async providerProfile(providerId: string, user?: AuthUser) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      include: {
        user: { select: { id: true, name: true, phone: true, avatar: true } },
        properties: {
          where: { status: 'APPROVED' },
          include: propertyCard,
          orderBy: { featured: 'desc' },
          take: 40,
        },
        _count: { select: { followers: true, properties: true } },
      },
    });
    if (!provider) throw new NotFoundException('المزود غير موجود');
    const following = user
      ? !!(await this.prisma.providerFollow.findUnique({
          where: { userId_providerId: { userId: user.id, providerId } },
        }))
      : false;
    return { ...provider, following };
  }

  async feed(user: AuthUser | undefined, query: { page?: string; pageSize?: string }) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const followingIds = user
      ? (
          await this.prisma.providerFollow.findMany({
            where: { userId: user.id },
            select: { providerId: true },
          })
        ).map((f) => f.providerId)
      : [];

    const where = {
      status: SocialPostStatus.PUBLISHED,
      ...(followingIds.length
        ? { OR: [{ property: { providerId: { in: followingIds } } }, { userId: user?.id }] }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.socialPost.findMany({
        where,
        include: {
          user: { select: { id: true, name: true, avatar: true } },
          property: { select: { id: true, name: true } },
          likes: user ? { where: { userId: user.id }, select: { id: true } } : false,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.socialPost.count({ where }),
    ]);

    return this.pagination.wrap(
      items.map((post) => ({
        ...post,
        liked: Array.isArray(post.likes) ? post.likes.length > 0 : false,
        likes: undefined,
      })),
      total,
      page,
      pageSize,
    );
  }

  async createPost(user: AuthUser, dto: { bookingId: string; caption?: string; mediaUrls?: string[] }) {
    const booking = await this.prisma.booking.findUnique({ where: { id: dto.bookingId } });
    if (!booking || booking.userId !== user.id) throw new ForbiddenException('غير مسموح');
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException('انشر التجربة بعد اكتمال الحجز');
    }
    const existing = await this.prisma.socialPost.findUnique({ where: { bookingId: booking.id } });
    if (existing) throw new BadRequestException('نشرت تجربة هذا الحجز مسبقاً');

    const urls = (dto.mediaUrls ?? []).filter((u) => typeof u === 'string' && u.startsWith('http')).slice(0, 6);
    if (!urls.length && !dto.caption?.trim()) {
      throw new BadRequestException('أضف وصفاً أو صورة');
    }

    return this.prisma.socialPost.create({
      data: {
        userId: user.id,
        bookingId: booking.id,
        propertyId: booking.propertyId,
        caption: dto.caption?.trim() ?? '',
        mediaUrls: urls,
      },
    });
  }

  async toggleLike(user: AuthUser, postId: string) {
    const post = await this.prisma.socialPost.findUnique({ where: { id: postId } });
    if (!post || post.status !== SocialPostStatus.PUBLISHED) {
      throw new NotFoundException('المنشور غير موجود');
    }
    const existing = await this.prisma.socialPostLike.findUnique({
      where: { postId_userId: { postId, userId: user.id } },
    });
    if (existing) {
      await this.prisma.$transaction([
        this.prisma.socialPostLike.delete({ where: { id: existing.id } }),
        this.prisma.socialPost.update({
          where: { id: postId },
          data: { likesCount: { decrement: 1 } },
        }),
      ]);
      return { liked: false };
    }
    await this.prisma.$transaction([
      this.prisma.socialPostLike.create({ data: { postId, userId: user.id } }),
      this.prisma.socialPost.update({
        where: { id: postId },
        data: { likesCount: { increment: 1 } },
      }),
    ]);
    if (post.userId !== user.id) {
      await this.lifecycle.notifyUser({
        userId: post.userId,
        type: 'SOCIAL',
        title: 'إعجاب بتجربتك',
        body: post.caption.slice(0, 80) || 'أحدهم أعجب بتجربتك',
        linkUrl: `/experiences`,
        entityType: 'social',
        entityId: postId,
      });
    }
    return { liked: true };
  }

  async listComments(postId: string) {
    const post = await this.prisma.socialPost.findUnique({ where: { id: postId } });
    if (!post || post.status !== SocialPostStatus.PUBLISHED) {
      throw new NotFoundException('المنشور غير موجود');
    }
    return this.prisma.socialPostComment.findMany({
      where: { postId },
      include: { user: { select: { id: true, name: true } } },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });
  }

  async comment(user: AuthUser, postId: string, body: string) {
    const text = body.trim();
    if (text.length < 1) throw new BadRequestException('التعليق فارغ');
    const post = await this.prisma.socialPost.findUnique({ where: { id: postId } });
    if (!post || post.status !== SocialPostStatus.PUBLISHED) {
      throw new NotFoundException('المنشور غير موجود');
    }
    const [comment] = await this.prisma.$transaction([
      this.prisma.socialPostComment.create({
        data: { postId, userId: user.id, body: text },
        include: { user: { select: { id: true, name: true } } },
      }),
      this.prisma.socialPost.update({
        where: { id: postId },
        data: { commentsCount: { increment: 1 } },
      }),
    ]);
    if (post.userId !== user.id) {
      await this.lifecycle.notifyUser({
        userId: post.userId,
        type: 'SOCIAL',
        title: 'تعليق على تجربتك',
        body: text.slice(0, 80),
        linkUrl: '/experiences',
        entityType: 'social',
        entityId: postId,
      });
    }
    return comment;
  }

  async report(user: AuthUser, postId: string, reason: string) {
    const post = await this.prisma.socialPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('المنشور غير موجود');
    await this.prisma.socialPostReport.upsert({
      where: { postId_userId: { postId, userId: user.id } },
      update: { reason: reason.trim() },
      create: { postId, userId: user.id, reason: reason.trim() },
    });
    const reports = await this.prisma.socialPostReport.count({ where: { postId } });
    if (reports >= 3 && post.status === SocialPostStatus.PUBLISHED) {
      await this.prisma.socialPost.update({
        where: { id: postId },
        data: { status: SocialPostStatus.REPORTED },
      });
    }
    return { reported: true };
  }

  private async ensureDefault(userId: string) {
    const existing = await this.prisma.collection.findFirst({
      where: { userId, isDefault: true },
    });
    if (existing) return existing;
    return this.prisma.collection.create({
      data: { userId, name: 'محفوظاتي', isDefault: true },
    });
  }
}
