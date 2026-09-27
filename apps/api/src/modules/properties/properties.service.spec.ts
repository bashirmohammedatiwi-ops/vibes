import { NotFoundException } from '@nestjs/common';
import { PropertyStatus } from '@prisma/client';
import { PropertiesService } from './properties.service';

describe('PropertiesService.similar', () => {
  let prisma: Record<string, any>;
  let service: PropertiesService;

  beforeEach(() => {
    prisma = {
      property: { findUnique: jest.fn(), findMany: jest.fn() },
    };
    service = new PropertiesService(
      prisma as never,
      {} as never,
      {} as never,
      {} as never,
      { get: jest.fn(), set: jest.fn(), keyFrom: jest.fn() } as never,
      {} as never,
    );
  });

  it('يرفض مكاناً غير منشور', async () => {
    prisma.property.findUnique.mockResolvedValue({
      id: 'p1',
      type: 'FARM',
      cityId: 'c1',
      status: PropertyStatus.DRAFT,
    });
    await expect(service.similar('p1')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('يكمل بأماكن مميزة إن نقصت نفس المدينة والنوع', async () => {
    prisma.property.findUnique.mockResolvedValue({
      id: 'p1',
      type: 'FARM',
      cityId: 'c1',
      status: PropertyStatus.APPROVED,
    });
    prisma.property.findMany
      .mockResolvedValueOnce([{ id: 'p2' }])
      .mockResolvedValueOnce([{ id: 'p3' }]);

    await expect(service.similar('p1')).resolves.toEqual([{ id: 'p2' }, { id: 'p3' }]);
    expect(prisma.property.findMany).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: expect.objectContaining({
          featured: true,
          id: { notIn: ['p1', 'p2'] },
        }),
      }),
    );
  });
});
