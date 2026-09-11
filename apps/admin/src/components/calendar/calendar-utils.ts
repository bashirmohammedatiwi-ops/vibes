import { localIsoDate, parseLocalDate } from "@/lib/dates";

export const WEEKDAYS = ["أحد", "إثن", "ثلا", "أرب", "خمي", "جمع", "سبت"];
export const MONTH_NAMES = [
  "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
  "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
];

export function formatMonthLabel(month: string) {
  const [y, m] = month.split("-").map(Number);
  return `${MONTH_NAMES[m - 1]} ${y}`;
}

export function dayKey(d: Date) {
  return localIsoDate(d);
}

export function overlapsDay(start: string, end: string, day: Date) {
  const s = new Date(start);
  const e = new Date(end);
  const next = new Date(day);
  next.setDate(next.getDate() + 1);
  return s < next && e > day;
}

export function heatLevel(count: number, max: number) {
  if (count <= 0) return 0;
  if (max <= 1) return Math.min(4, count);
  const ratio = count / max;
  if (ratio >= 0.75) return 4;
  if (ratio >= 0.5) return 3;
  if (ratio >= 0.25) return 2;
  return 1;
}

export function bookingStatusVariant(status: string): "success" | "warning" | "danger" | "muted" | "default" {
  if (status === "CONFIRMED" || status === "COMPLETED") return "success";
  if (status === "DISPUTED") return "danger";
  if (status === "CANCELLED") return "muted";
  if (status === "PENDING" || status === "AWAITING_PAYMENT") return "warning";
  return "default";
}

export type CalendarBooking = {
  id: string;
  totalPrice?: number | string;
  startDate: string;
  endDate: string;
  shift?: string;
  status: string;
  property?: { id: string; name: string; type?: string };
  user?: { name?: string | null; phone: string };
};

export type CalendarBlockedSlot = {
  date: string;
  shift?: string;
  property?: { name: string; type?: string };
};

export type CalendarCell = {
  date: Date | null;
  bookings: number;
  blocked: number;
};

export function buildMonthGrid(
  month: string,
  bookings: CalendarBooking[],
  blockedSlots: CalendarBlockedSlot[],
): CalendarCell[] {
  const [y, m] = month.split("-").map(Number);
  const first = new Date(y, m - 1, 1);
  const daysInMonth = new Date(y, m, 0).getDate();
  const startPad = first.getDay();
  const cells: CalendarCell[] = [];

  for (let i = 0; i < startPad; i++) cells.push({ date: null, bookings: 0, blocked: 0 });

  for (let d = 1; d <= daysInMonth; d++) {
    const date = new Date(y, m - 1, d);
    const key = dayKey(date);
    const dayBookings = bookings.filter((b) => overlapsDay(b.startDate, b.endDate, date)).length;
    const blocked = blockedSlots.filter((s) => s.date.slice(0, 10) === key).length;
    cells.push({ date, bookings: dayBookings, blocked });
  }

  return cells;
}

export function shortWeekday(iso: string) {
  return new Intl.DateTimeFormat("ar-IQ", { weekday: "short" }).format(parseLocalDate(iso));
}

export function dayNumber(iso: string) {
  return parseLocalDate(iso).getDate();
}

export function monthShort(iso: string) {
  return new Intl.DateTimeFormat("ar-IQ", { month: "short" }).format(parseLocalDate(iso));
}
