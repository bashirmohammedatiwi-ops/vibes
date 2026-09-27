import { BookingOrigin } from '@prisma/client';

export type CoverageCounts = {
  days: number;
  propertyCount: number;
  totalSlots: number;
  platformDays: number;
  externalDays: number;
  closedDays: number;
  openDays: number;
};

export function dateOnlyKey(value: Date) {
  return value.toISOString().slice(0, 10);
}

export function localDateOnly(value = new Date()) {
  return new Date(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()));
}

export function eachDateOnly(start: Date, end: Date) {
  const days: Date[] = [];
  const cursor = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()));
  const stop = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()));
  while (cursor < stop) {
    days.push(new Date(cursor));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return days;
}

export function summarizeCoverage(input: {
  horizon?: number;
  propertyIds: string[];
  bookings: Array<{ propertyId: string; startDate: Date; endDate: Date; origin: BookingOrigin }>;
  closed: Array<{ propertyId: string; date: Date }>;
  now?: Date;
}): CoverageCounts {
  const horizon = input.horizon ?? 30;
  const start = localDateOnly(input.now);
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + horizon);
  const totalSlots = input.propertyIds.length * horizon;

  if (input.propertyIds.length === 0) {
    return {
      days: horizon,
      propertyCount: 0,
      totalSlots: 0,
      platformDays: 0,
      externalDays: 0,
      closedDays: 0,
      openDays: 0,
    };
  }

  const occupied = new Map<string, BookingOrigin | 'CLOSED'>();
  for (const booking of input.bookings) {
    for (const day of eachDateOnly(booking.startDate, booking.endDate)) {
      if (day < start || day >= end) continue;
      const key = `${booking.propertyId}:${dateOnlyKey(day)}`;
      if (!occupied.has(key) || booking.origin === BookingOrigin.EXTERNAL) {
        occupied.set(key, booking.origin);
      }
    }
  }
  for (const slot of input.closed) {
    const key = `${slot.propertyId}:${dateOnlyKey(slot.date)}`;
    if (!occupied.has(key)) occupied.set(key, 'CLOSED');
  }

  let platformDays = 0;
  let externalDays = 0;
  let closedDays = 0;
  for (const value of occupied.values()) {
    if (value === BookingOrigin.PLATFORM) platformDays += 1;
    else if (value === BookingOrigin.EXTERNAL) externalDays += 1;
    else closedDays += 1;
  }

  return {
    days: horizon,
    propertyCount: input.propertyIds.length,
    totalSlots,
    platformDays,
    externalDays,
    closedDays,
    openDays: Math.max(0, totalSlots - occupied.size),
  };
}
