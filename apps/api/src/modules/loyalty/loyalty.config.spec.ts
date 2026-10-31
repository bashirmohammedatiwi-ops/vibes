import { loyaltyDiscount, loyaltyProgress, normalizeLoyaltyConfig } from './loyalty.config';

describe('loyalty progress', () => {
  it('counts up to the required bookings', () => {
    expect(loyaltyProgress(0, 0, 5)).toMatchObject({ stamps: 0, remaining: 5, rewardsAvailable: 0 });
    expect(loyaltyProgress(4, 0, 5)).toMatchObject({ stamps: 4, remaining: 1, rewardsAvailable: 0 });
  });

  it('unlocks a reward on the fifth completed booking', () => {
    expect(loyaltyProgress(5, 0, 5)).toMatchObject({ rewardsAvailable: 1, stamps: 5, remaining: 0 });
  });

  it('starts a new cycle once the reward is used', () => {
    expect(loyaltyProgress(5, 1, 5)).toMatchObject({ rewardsAvailable: 0, stamps: 0, remaining: 5 });
    expect(loyaltyProgress(7, 1, 5)).toMatchObject({ rewardsAvailable: 0, stamps: 2, remaining: 3 });
  });

  it('returns the reward when its booking is cancelled', () => {
    // الإلغاء يخرج الحجز من activeRewards
    expect(loyaltyProgress(5, 0, 5).rewardsAvailable).toBe(1);
  });

  it('stacks unused rewards and never goes negative', () => {
    expect(loyaltyProgress(10, 0, 5).rewardsAvailable).toBe(2);
    expect(loyaltyProgress(4, 2, 5).rewardsAvailable).toBe(0);
  });
});

describe('loyalty discount', () => {
  it('takes the percent and honours the cap', () => {
    expect(loyaltyDiscount(1_000_000, { percent: 25, maxDiscount: 0 })).toBe(250_000);
    expect(loyaltyDiscount(1_000_000, { percent: 25, maxDiscount: 100_000 })).toBe(100_000);
  });
});

describe('loyalty config', () => {
  it('defaults to five bookings and 25% for each world, separately', () => {
    const config = normalizeLoyaltyConfig(null);
    for (const type of ['FARM', 'HALL', 'DECORATION'] as const) {
      expect(config.programs[type]).toMatchObject({ enabled: true, required: 5, percent: 25 });
    }
  });

  it('clamps bad admin input', () => {
    const config = normalizeLoyaltyConfig({ programs: { FARM: { required: 0, percent: 500 } } });
    expect(config.programs.FARM).toMatchObject({ required: 1, percent: 100 });
  });
});
