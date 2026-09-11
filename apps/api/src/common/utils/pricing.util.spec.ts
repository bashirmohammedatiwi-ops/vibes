import { BadRequestException } from '@nestjs/common';
import { ShiftType } from '@prisma/client';
import {
  applicableRule,
  calculateBookingTotal,
  resolveBookingShift,
  resolveDayPricing,
  type PriceRuleLike,
  type PropertyPricing,
} from './pricing.util';
import { resolveShiftTimes } from './shift.util';

const property: PropertyPricing = {
  type: 'FARM',
  bookingMode: 'HYBRID',
  pricePerDay: 100_000,
  weekendPrice: 150_000,
  priceMorningShift: 60_000,
  priceEveningShift: 70_000,
};

const day = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

// 2026-09-09 Wednesday (weekday), 2026-09-10 Thursday, 2026-09-11 Friday + 2026-09-12 Saturday (Iraq weekend: Fri+Sat)
const WEDNESDAY = day('2026-09-09');
const THURSDAY = day('2026-09-10');
const FRIDAY = day('2026-09-11');
const SATURDAY = day('2026-09-12');
const SUNDAY = day('2026-09-13');

const weekdayRule: PriceRuleLike = {
  ruleType: 'WEEKDAY',
  daysOfWeek: [4, 5], // Thu + Fri
  fullDayPrice: 200_000,
  morningPrice: 90_000,
  eveningPrice: 120_000,
  priority: 0,
  isActive: true,
};

const seasonRule: PriceRuleLike = {
  ruleType: 'DATE_RANGE',
  startDate: '2026-09-10',
  endDate: '2026-09-12',
  fullDayPrice: 500_000,
  priority: 5,
  isActive: true,
  eveningStart: '19:00',
};

describe('applicableRule', () => {
  it('returns null when no rule matches', () => {
    const rule = applicableRule([weekdayRule], SATURDAY);
    expect(rule).toBeNull();
  });

  it('matches weekday rules by day of week', () => {
    expect(applicableRule([weekdayRule], THURSDAY)).toBe(weekdayRule);
    expect(applicableRule([weekdayRule], FRIDAY)).toBe(weekdayRule);
  });

  it('prefers higher priority', () => {
    const low: PriceRuleLike = { ...weekdayRule, priority: 1, fullDayPrice: 1 };
    const high: PriceRuleLike = { ...weekdayRule, priority: 9, fullDayPrice: 2 };
    expect(applicableRule([low, high], THURSDAY)).toBe(high);
  });

  it('prefers date-range rules at equal priority', () => {
    expect(applicableRule([weekdayRule, seasonRule], THURSDAY)).toBe(seasonRule);
  });

  it('ignores inactive rules', () => {
    expect(applicableRule([{ ...weekdayRule, isActive: false }], THURSDAY)).toBeNull();
  });

  it('date range boundaries are inclusive', () => {
    expect(applicableRule([seasonRule], day('2026-09-12'))).toBe(seasonRule);
    expect(applicableRule([seasonRule], day('2026-09-13'))).toBeNull();
  });
});

describe('resolveDayPricing', () => {
  it('uses property defaults outside any rule', () => {
    const dayPricing = resolveDayPricing(property, [weekdayRule], WEDNESDAY);
    expect(dayPricing.full).toBe(100_000);
    expect(dayPricing.morning).toBe(60_000);
    expect(dayPricing.evening).toBe(70_000);
    expect(dayPricing.rule).toBeNull();
  });

  it('falls back to the weekend rate on Friday/Saturday', () => {
    const dayPricing = resolveDayPricing(property, [], FRIDAY);
    expect(dayPricing.full).toBe(150_000);
  });

  it('applies weekday rule prices on matching days', () => {
    const dayPricing = resolveDayPricing(property, [weekdayRule], THURSDAY);
    expect(dayPricing.full).toBe(200_000);
    expect(dayPricing.morning).toBe(90_000);
    expect(dayPricing.evening).toBe(120_000);
  });

  it('rule day without explicit shift prices defaults shifts to 50% of the governed full price', () => {
    const rule: PriceRuleLike = { ruleType: 'WEEKDAY', daysOfWeek: [5], priority: 0, isActive: true };
    const dayPricing = resolveDayPricing(property, [rule], FRIDAY);
    expect(dayPricing.full).toBe(150_000);
    expect(dayPricing.morning).toBe(75_000);
    expect(dayPricing.evening).toBe(75_000);
  });

  it('rule full price without shift prices defaults shifts to 50%', () => {
    const dayPricing = resolveDayPricing(property, [seasonRule], THURSDAY);
    expect(dayPricing.full).toBe(500_000);
    expect(dayPricing.morning).toBe(250_000);
    expect(dayPricing.evening).toBe(250_000);
  });

  it('rule shift times override property times', () => {
    const dayPricing = resolveDayPricing(property, [seasonRule], THURSDAY);
    expect(dayPricing.times.eveningShiftStart).toBe('19:00');
    expect(dayPricing.times.morningShiftStart).toBe('08:00');
  });
});

describe('resolveShiftTimes', () => {
  it('falls back to defaults when nothing set', () => {
    const times = resolveShiftTimes(null, null);
    expect(times.morningShiftStart).toBe('08:00');
    expect(times.eveningShiftEnd).toBe('22:00');
    expect(times.fullShiftStart).toBe('08:00');
    expect(times.fullShiftEnd).toBe('22:00');
  });

  it('property times override defaults', () => {
    const times = resolveShiftTimes({ morningStart: '07:00', eveningEnd: '23:30' }, null);
    expect(times.morningShiftStart).toBe('07:00');
    expect(times.fullShiftEnd).toBe('23:30');
  });

  it('rule times override property times', () => {
    const times = resolveShiftTimes(
      { eveningStart: '16:00' },
      { eveningStart: '20:00' },
    );
    expect(times.eveningShiftStart).toBe('20:00');
  });
});

describe('resolveBookingShift', () => {
  it('forces FULL for FULL_DAY mode', () => {
    expect(resolveBookingShift('FULL_DAY', ShiftType.MORNING)).toBe(ShiftType.FULL);
    expect(resolveBookingShift('FULL_DAY', undefined)).toBe(ShiftType.FULL);
  });

  it('rejects FULL for SHIFTS mode and defaults to MORNING', () => {
    expect(() => resolveBookingShift('SHIFTS', ShiftType.FULL)).toThrow(BadRequestException);
    expect(resolveBookingShift('SHIFTS', undefined)).toBe(ShiftType.MORNING);
    expect(resolveBookingShift('SHIFTS', ShiftType.EVENING)).toBe(ShiftType.EVENING);
  });

  it('accepts every shift in HYBRID mode', () => {
    expect(resolveBookingShift('HYBRID', ShiftType.FULL)).toBe(ShiftType.FULL);
    expect(resolveBookingShift('HYBRID', ShiftType.MORNING)).toBe(ShiftType.MORNING);
  });
});

describe('calculateBookingTotal', () => {
  it('sums per-day resolved prices for shift bookings', () => {
    // Thu + Fri with weekday rule => 90k + 90k morning
    const total = calculateBookingTotal(property, [weekdayRule], THURSDAY, day('2026-09-12'), [], ShiftType.MORNING);
    expect(total).toBe(180_000);
  });

  it('uses weekend base rate without rules', () => {
    // Fri full day => 150k, Sat (weekend) => 150k
    const total = calculateBookingTotal(property, [], FRIDAY, SUNDAY, [], ShiftType.FULL);
    expect(total).toBe(300_000);
  });

  it('slot price override beats rules', () => {
    const slots = [
      { date: THURSDAY, shift: ShiftType.FULL, isAvailable: true, priceOverride: 777_000 },
    ];
    // eachDay is end-exclusive: Thu..Fri covers Thursday only
    const total = calculateBookingTotal(property, [seasonRule], THURSDAY, FRIDAY, slots, ShiftType.FULL);
    expect(total).toBe(777_000);
  });

  it('mixed rules across a multi-day range each apply to their own days', () => {
    // Thu/Fri/Sat all inside the inclusive season range => 500k each; weekday rule is outranked
    const total = calculateBookingTotal(property, [weekdayRule, seasonRule], THURSDAY, SUNDAY, [], ShiftType.FULL);
    expect(total).toBe(1_500_000);
  });
});
