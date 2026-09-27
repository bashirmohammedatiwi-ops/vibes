import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { BookingStatus, UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { SocialService } from './social.service';

describe('SocialService', () => {
  const user = { id: 'u1', phone: '9647700000000', role: UserRole.CUSTOMER } as AuthUser;
  let prisma: Record<string, any>;
  let lifecycle: { notifyUser: jest.Mock };
  let service: SocialService;

  beforeEach(() => {
    prisma = {
      provider: { findUnique: jest.fn() },
      providerFollow: {
        upsert: jest.fn(),
        deleteMany: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      collection: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn(), findMany: jest.fn() },
      booking: { findUnique: jest.fn() },
      socialPost: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
      socialPostComment: { create: jest.fn() },
      $transaction: jest.fn(),
    };
    lifecycle = { notifyUser: jest.fn() };
    service = new SocialService(prisma as never, { parse: jest.fn(), wrap: jest.fn() } as never, lifecycle as never);
  });

  it('يمنع متابعة الحساب نفسه', async () => {
    prisma.provider.findUnique.mockResolvedValue({ id: 'pr1', userId: 'u1' });
    await expect(service.follow(user, 'pr1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('يرفض قائمة باسم قصير', async () => {
    await expect(service.createCollection(user, { name: 'أ' })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('يمنع حذف القائمة الافتراضية', async () => {
    prisma.collection.findUnique.mockResolvedValue({ id: 'c1', userId: 'u1', isDefault: true });
    await expect(service.deleteCollection(user, 'c1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('يحدّث وصف القائمة لصاحبها', async () => {
    prisma.collection.findUnique.mockResolvedValue({ id: 'c1', userId: 'u1', isDefault: false });
    prisma.collection.update.mockResolvedValue({ id: 'c1', description: 'أماكن العيد' });
    const result = await service.updateCollection(user, 'c1', { description: ' أماكن العيد ' });
    expect(prisma.collection.update).toHaveBeenCalledWith({
      where: { id: 'c1' },
      data: { description: 'أماكن العيد' },
    });
    expect(result).toEqual({ id: 'c1', description: 'أماكن العيد' });
  });

  it('يعيّن غلاف القائمة من رابط صورة', async () => {
    prisma.collection.findUnique.mockResolvedValue({ id: 'c1', userId: 'u1', isDefault: false });
    prisma.collection.update.mockResolvedValue({ id: 'c1', coverUrl: 'https://img/cover.jpg' });
    await service.updateCollection(user, 'c1', { coverUrl: ' https://img/cover.jpg ' });
    expect(prisma.collection.update).toHaveBeenCalledWith({
      where: { id: 'c1' },
      data: { coverUrl: 'https://img/cover.jpg' },
    });
  });

  it('يمنع الوصول إلى قائمة خاصة لشخص آخر', async () => {
    prisma.collection.findUnique.mockResolvedValue({
      id: 'c1',
      userId: 'other',
      visibility: 'PRIVATE',
    });
    await expect(service.getCollection(user, 'c1')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('يرفض نشر تجربة قبل اكتمال الحجز', async () => {
    prisma.booking.findUnique.mockResolvedValue({
      id: 'b1',
      userId: 'u1',
      status: BookingStatus.CONFIRMED,
    });
    await expect(service.createPost(user, { bookingId: 'b1', caption: 'تجربة جميلة' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('ينبّه صاحب التجربة عند تعليق شخص آخر', async () => {
    prisma.socialPost.findUnique.mockResolvedValue({
      id: 'p1',
      userId: 'other',
      status: 'PUBLISHED',
    });
    prisma.$transaction.mockResolvedValue([{ id: 'c1', body: 'رائع' }]);
    await service.comment(user, 'p1', 'رائع');
    expect(lifecycle.notifyUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'other',
        type: 'SOCIAL',
        linkUrl: '/experiences',
      }),
    );
  });

  it('يعيد المزودين المتابَعين مع أعداد المتابعين', async () => {
    prisma.providerFollow.findMany.mockResolvedValue([
      {
        provider: {
          id: 'pr1',
          businessName: 'مزارع دجلة',
          verified: true,
          user: { id: 'u2', name: 'علي', avatar: null },
          _count: { followers: 12, properties: 3 },
        },
      },
    ]);
    await expect(service.listFollowing(user)).resolves.toEqual([
      {
        id: 'pr1',
        businessName: 'مزارع دجلة',
        verified: true,
        user: { id: 'u2', name: 'علي', avatar: null },
        followers: 12,
        propertiesCount: 3,
        following: true,
      },
    ]);
  });

  it('يعرض القوائم العامة التي فيها عناصر فقط', async () => {
    prisma.collection.findMany.mockResolvedValue([{ id: 'c1', name: 'عيد' }]);
    await service.listPublicCollections();
    expect(prisma.collection.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          visibility: 'PUBLIC',
          items: { some: {} },
        }),
      }),
    );
  });
});
