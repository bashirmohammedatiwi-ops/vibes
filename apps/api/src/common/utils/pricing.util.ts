import { BadRequestException } from '@nestjs/common';
import { PropertyType, ShiftType } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import {
  dateKey,
  eachDay,
  modeAllowsFull,
  modeAllowsShift,
  resolveBookingMode,
  resolveShiftTimes,
  shiftsRequiredForBooking,
  type BookingModeValue,
  type PropertyShiftTimes,
  type ShiftTimes,
} from './shift.util';

export type PriceRuleLike = {
  id?: string;
  name?: string;
  ruleType: string;
  daysOfWeek?: number[] | null;
  startDate?: Date | string | null;
  endDate?: Date | string | null;
  fullDayPrice?: Decimal | number | null;
  morningPrice?: Decimal | number | null;
  eveningPrice?: Decimal | number | null;
  priority?: number | null;
  isActive?: boolean;
} & PropertyShiftTimes;

export type PropertyPricing = {
  type?: string;
  bookingMode?: string | null;
  pricePerDay: Decimal | number;
  weekendPrice?: Decimal | number | null;
  priceMorningShift?: Decimal | number | null;
  priceEveningShift?: Decimal | number | null;
} & PropertyShiftTimes;

export type AvailabilitySlot = {
  date: Date;
  shift: ShiftType;
  isAvailable: boolean;
  priceOverride?: Decimal | number | null;
};

export type DayPricing = {
  full: number;
  morning: number;
  evening: number;
  times: ShiftTimes;
  mode: BookingModeValue;
  rule: PriceRuleLike | null;
};

function toNumber(value: Decimal | number | null | undefined): number | null {
  if (value == null) return null;
  return Number(value);
}

function isWeekend(date: Date) {
  const day = date.getUTCDay();
  return day === 5 || day === 6;
}

function slotLookup(slots: AvailabilitySlot[]) {
  return new Map(slots.map((slot) => [`${dateKey(slot.date)}:${slot.shift}`, slot]));
}

function ruleTypeRank(rule: PriceRuleLike) {
  return rule.ruleType === 'DATE_RANGE' ? 1 : 0;
}

function ruleCoversDate(rule: PriceRuleLike, date: Date) {
  if (rule.isActive === false) return false;
  if (rule.ruleType === 'DATE_RANGE') {
    if (!rule.startDate || !rule.endDate) return false;
    const day = dateKey(date);
    return dateKey(new Date(rule.startDate)) <= day && day <= dateKey(new Date(rule.endDate));
  }
  if (rule.ruleType === 'WEEKDAY') {
    const days = rule.daysOfWeek ?? [];
    return days.includes(date.getUTCDay());
  }
  return false;
}

/**
 * Picks the active rule that governs a date: highest priority wins,
 * date-range rules beat weekday rules at equal priority.
 */
export function applicableRule(rules: PriceRuleLike[] | null | undefined, date: Date): PriceRuleLike | null {
  const matching = (rules ?? []).filter((rule) => ruleCoversDate(rule, date));
  if (!matching.length) return null;
  matching.sort(
    (a, b) =>
      (b.priority ?? 0) - (a.priority ?? 0) || ruleTypeRank(b) - ruleTypeRank(a),
  );
  return matching[0];
}

/**
 * Resolves prices and shift times for one date against property defaults
 * and the highest-priority applicable rule. On a day governed by a rule,
 * shift prices default to 50% of the rule's effective full price unless
 * the rule sets explicit shift prices. Days without rules keep the legacy
 * property behavior (explicit shift prices or 50% of the weekend-aware day price).
 */
export function resolveDayPricing(
  property: PropertyPricing,
  rules: PriceRuleLike[] | null | undefined,
  date: Date,
): DayPricing {
  const rule = applicableRule(rules, date);

  const weekendRate = toNumber(property.weekendPrice);
  const defaultFull =
    isWeekend(date) && weekendRate != null ? weekendRate : Number(property.pricePerDay);
  const full = toNumber(rule?.fullDayPrice) ?? defaultFull;

  const morning = toNumber(rule?.morningPrice) ?? (rule ? full * 0.5 : toNumber(property.priceMorningShift) ?? full * 0.5);
  const evening = toNumber(rule?.eveningPrice) ?? (rule ? full * 0.5 : toNumber(property.priceEveningShift) ?? full * 0.5);

  return {
    full,
    morning,
    evening,
    times: resolveShiftTimes(property, rule),
    mode: resolveBookingMode((property.type as PropertyType) ?? PropertyType.FARM, property.bookingMode),
    rule,
  };
}

export function shiftPriceFromDayPricing(day: DayPricing, shift: ShiftType): number {
  switch (shift) {
    case ShiftType.MORNING:
      return day.morning;
    case ShiftType.EVENING:
      return day.evening;
    default:
      return day.full;
  }
}

/** Resolves the requested shift against the property booking mode. */
export function resolveBookingShift(mode: BookingModeValue, requested?: ShiftType): ShiftType {
  if (!modeAllowsShift(mode)) return ShiftType.FULL;
  if (requested === ShiftType.MORNING || requested === ShiftType.EVENING) return requested;
  if (requested === ShiftType.FULL) {
    if (!modeAllowsFull(mode)) {
      throw new BadRequestException('هذا المكان يقبل الحجز بالشفتات فقط (صباحية/مسائية)');
    }
    return ShiftType.FULL;
  }
  return modeAllowsFull(mode) ? ShiftType.FULL : ShiftType.MORNING;
}

export function assertShiftAvailability(
  shift: ShiftType,
  start: Date,
  end: Date,
  slots: AvailabilitySlot[],
) {
  const map = slotLookup(slots);
  for (const day of eachDay(start, end)) {
    for (const required of shiftsRequiredForBooking(shift)) {
      const slot = map.get(`${dateKey(day)}:${required}`);
      if (slot && !slot.isAvailable) {
        throw new BadRequestException(`التاريخ ${dateKey(day)} غير متاح للشفت المطلوب`);
      }
    }
  }
}

export function calculateBookingTotal(
  property: PropertyPricing,
  rules: PriceRuleLike[] | null | undefined,
  start: Date,
  end: Date,
  slots: AvailabilitySlot[] = [],
  shift: ShiftType = ShiftType.FULL,
) {
  const days = eachDay(start, end);
  if (!days.length) {
    throw new BadRequestException('مدة الحجز غير صالحة');
  }

  assertShiftAvailability(shift, start, end, slots);

  const map = slotLookup(slots);
  let total = 0;

  for (const day of days) {
    const dayPricing = resolveDayPricing(property, rules, day);
    const slot = map.get(`${dateKey(day)}:${shift}`);
    const base = shiftPriceFromDayPricing(dayPricing, shift);
    total += slot?.priceOverride != null ? Number(slot.priceOverride) : base;
  }

  return total;
}
