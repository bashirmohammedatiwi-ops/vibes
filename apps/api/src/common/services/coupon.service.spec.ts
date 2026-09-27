import { CouponService } from './coupon.service';

describe('CouponService.listPublic', () => {
  it('يخفي الرموز السرية والمستنفدة ويعرض الترويجية فقط', async () => {
    const prisma = {
      coupon: {
        findMany: jest.fn().mockResolvedValue([
          {
            code: 'SECRET',
            description: 'خصم داخلي',
            discountType: 'PERCENT',
            discountValue: 10,
            minBookingTotal: null,
            expiresAt: null,
            appliesToTypes: [],
            property: null,
            maxUses: 1,
            usedCount: 1,
          },
          {
            code: 'VIBES10',
            description: 'خصم العيد',
            discountType: 'PERCENT',
            discountValue: 10,
            minBookingTotal: 100000,
            expiresAt: null,
            appliesToTypes: ['FARM'],
            property: { id: 'p1', name: 'مزرعة' },
            maxUses: 50,
            usedCount: 3,
          },
        ]),
      },
    };
    const service = new CouponService(prisma as never);
    const result = await service.listPublic();
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      code: 'VIBES10',
      description: 'خصم العيد',
      discountType: 'PERCENT',
      discountValue: 10,
      minBookingTotal: 100000,
      expiresAt: null,
      appliesToTypes: ['FARM'],
      property: { id: 'p1', name: 'مزرعة' },
    });
  });

  it('يصفي حسب نوع المكان', async () => {
    const prisma = {
      coupon: {
        findMany: jest.fn().mockResolvedValue([
          {
            code: 'HALL20',
            description: 'قاعات',
            discountType: 'FIXED',
            discountValue: 20000,
            minBookingTotal: null,
            expiresAt: null,
            appliesToTypes: ['HALL'],
            property: null,
            maxUses: null,
            usedCount: 0,
          },
        ]),
      },
    };
    const service = new CouponService(prisma as never);
    expect(await service.listPublic('FARM')).toEqual([]);
    expect(await service.listPublic('HALL')).toHaveLength(1);
  });
});
