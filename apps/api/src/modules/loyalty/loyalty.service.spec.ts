import { BadRequestException } from '@nestjs/common';
import { PropertyType } from '@prisma/client';
import { LoyaltyService } from './loyalty.service';

function setup(paidCompleted: number, activeRewards: number, config?: object) {
  const count = jest
    .fn()
    .mockImplementation(({ where }: { where: { status?: unknown } }) =>
      Promise.resolve(where.status === 'COMPLETED' ? paidCompleted : activeRewards),
    );
  const tx = { booking: { count }, $executeRaw: jest.fn().mockResolvedValue(1) };
  const prisma = {
    ...tx,
    platformSetting: { findUnique: jest.fn().mockResolvedValue(config ? { value: JSON.stringify(config) } : null) },
  };
  const cache = { getOrSet: (_k: string, _t: number, load: () => unknown) => load(), del: jest.fn() };
  const service = new LoyaltyService(prisma as never, cache as never, {} as never);
  return { service, tx };
}

describe('LoyaltyService', () => {
  it('offers 25% on the booking after five completed in the same world', async () => {
    const { service } = setup(5, 0);
    await expect(service.offer('u1', PropertyType.FARM, 1_000_000)).resolves.toMatchObject({
      eligible: true,
      discount: 250_000,
      totalAfterDiscount: 750_000,
    });
  });

  it('counts only the booking world when checking progress', async () => {
    const { service, tx } = setup(2, 0);
    await service.offer('u1', PropertyType.HALL, 100);
    for (const [args] of tx.booking.count.mock.calls) {
      expect(args.where.property).toEqual({ type: PropertyType.HALL });
      expect(args.where.userId).toBe('u1');
    }
  });

  it('shows progress without a discount before the fifth booking', async () => {
    const { service } = setup(4, 0);
    await expect(service.offer('u1', PropertyType.FARM, 1_000_000)).resolves.toMatchObject({
      eligible: false,
      discount: 0,
      stamps: 4,
      remaining: 1,
    });
  });

  it('offers nothing to guests or when the program is off', async () => {
    await expect(setup(5, 0).service.offer(undefined, PropertyType.FARM, 100)).resolves.toBeNull();
    await expect(
      setup(5, 0, { enabled: false }).service.offer('u1', PropertyType.FARM, 100),
    ).resolves.toBeNull();
  });

  it('claims under a lock and returns the discount', async () => {
    const { service, tx } = setup(5, 0);
    await expect(service.claim(tx as never, 'u1', PropertyType.FARM, 800_000)).resolves.toBe(200_000);
    expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
  });

  it('refuses a second claim of the same reward', async () => {
    const { service, tx } = setup(5, 1);
    await expect(service.claim(tx as never, 'u1', PropertyType.FARM, 800_000)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
