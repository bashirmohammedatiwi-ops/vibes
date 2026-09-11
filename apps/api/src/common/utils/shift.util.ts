import { PropertyType, ShiftType } from '@prisma/client';

export const FARM_SHIFTS: ShiftType[] = [ShiftType.MORNING, ShiftType.EVENING, ShiftType.FULL];

export type BookingModeValue = 'FULL_DAY' | 'SHIFTS' | 'HYBRID';

export function propertyUsesShifts(type: PropertyType) {
  return type === PropertyType.FARM;
}

/**
 * Default booking mode derived from the property type:
 * - farms historically accept shifts and full days (hybrid)
 * - halls and decoration services book whole days only
 */
export function defaultBookingMode(type: PropertyType): BookingModeValue {
  switch (type) {
    case PropertyType.FARM:
      return 'HYBRID';
    case PropertyType.HALL:
      return 'FULL_DAY';
    default:
      return 'FULL_DAY';
  }
}

export function resolveBookingMode(
  type: PropertyType,
  bookingMode?: string | null,
): BookingModeValue {
  if (bookingMode === 'FULL_DAY' || bookingMode === 'SHIFTS' || bookingMode === 'HYBRID') {
    return bookingMode;
  }
  return defaultBookingMode(type);
}

export function modeAllowsShift(mode: BookingModeValue) {
  return mode === 'SHIFTS' || mode === 'HYBRID';
}

export function modeAllowsFull(mode: BookingModeValue) {
  return mode === 'FULL_DAY' || mode === 'HYBRID';
}

export function shiftsConflict(a: ShiftType, b: ShiftType) {
  if (a === ShiftType.FULL || b === ShiftType.FULL) return true;
  return a === b;
}

export function dateKey(date: Date) {
  return date.toISOString().slice(0, 10);
}

export function eachDay(start: Date, end: Date) {
  const days: Date[] = [];
  const cursor = new Date(start);
  while (cursor < end) {
    days.push(new Date(cursor));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return days;
}

export function bookingDaysConflict(
  startA: Date,
  endA: Date,
  shiftA: ShiftType,
  startB: Date,
  endB: Date,
  shiftB: ShiftType,
) {
  if (startA >= endB || endA <= startB) return false;
  const daysB = new Set(eachDay(startB, endB).map(dateKey));
  for (const day of eachDay(startA, endA)) {
    if (daysB.has(dateKey(day)) && shiftsConflict(shiftA, shiftB)) {
      return true;
    }
  }
  return false;
}

export function shiftsRequiredForBooking(shift: ShiftType): ShiftType[] {
  if (shift === ShiftType.FULL) return FARM_SHIFTS;
  return [shift];
}

export type ShiftTimes = {
  morningShiftStart: string;
  morningShiftEnd: string;
  eveningShiftStart: string;
  eveningShiftEnd: string;
  fullShiftStart: string;
  fullShiftEnd: string;
};

export const DEFAULT_SHIFT_TIMES: ShiftTimes = {
  morningShiftStart: '08:00',
  morningShiftEnd: '14:00',
  eveningShiftStart: '16:00',
  eveningShiftEnd: '22:00',
  fullShiftStart: '08:00',
  fullShiftEnd: '22:00',
};

/** Per-property overrides (nullable columns on properties). */
export type PropertyShiftTimes = Partial<
  Record<'morningStart' | 'morningEnd' | 'eveningStart' | 'eveningEnd', string | null | undefined>
>;

/**
 * Merges shift times: defaults <- property columns <- active rule overrides.
 * The full shift always spans from the morning start to the evening end.
 */
export function resolveShiftTimes(
  property?: PropertyShiftTimes | null,
  rule?: PropertyShiftTimes | null,
): ShiftTimes {
  const pick = (ruleValue: string | null | undefined, propertyValue: string | null | undefined, fallback: string) =>
    (ruleValue || propertyValue || fallback);

  const morningStart = pick(rule?.morningStart, property?.morningStart, DEFAULT_SHIFT_TIMES.morningShiftStart);
  const morningEnd = pick(rule?.morningEnd, property?.morningEnd, DEFAULT_SHIFT_TIMES.morningShiftEnd);
  const eveningStart = pick(rule?.eveningStart, property?.eveningStart, DEFAULT_SHIFT_TIMES.eveningShiftStart);
  const eveningEnd = pick(rule?.eveningEnd, property?.eveningEnd, DEFAULT_SHIFT_TIMES.eveningShiftEnd);

  return {
    morningShiftStart: morningStart,
    morningShiftEnd: morningEnd,
    eveningShiftStart: eveningStart,
    eveningShiftEnd: eveningEnd,
    fullShiftStart: morningStart,
    fullShiftEnd: eveningEnd,
  };
}

export function shiftTimesFromMap(map: Record<string, string>): ShiftTimes {
  return {
    morningShiftStart: map.morningShiftStart || DEFAULT_SHIFT_TIMES.morningShiftStart,
    morningShiftEnd: map.morningShiftEnd || DEFAULT_SHIFT_TIMES.morningShiftEnd,
    eveningShiftStart: map.eveningShiftStart || DEFAULT_SHIFT_TIMES.eveningShiftStart,
    eveningShiftEnd: map.eveningShiftEnd || DEFAULT_SHIFT_TIMES.eveningShiftEnd,
    fullShiftStart: map.fullShiftStart || DEFAULT_SHIFT_TIMES.fullShiftStart,
    fullShiftEnd: map.fullShiftEnd || DEFAULT_SHIFT_TIMES.fullShiftEnd,
  };
}

export function formatShiftTimeRange(shift: ShiftType, times: ShiftTimes) {
  switch (shift) {
    case ShiftType.MORNING:
      return `${times.morningShiftStart} – ${times.morningShiftEnd}`;
    case ShiftType.EVENING:
      return `${times.eveningShiftStart} – ${times.eveningShiftEnd}`;
    default:
      return `${times.fullShiftStart} – ${times.fullShiftEnd}`;
  }
}
