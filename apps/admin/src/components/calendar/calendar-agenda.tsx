"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/empty-state";
import type { CalendarBooking } from "@/components/calendar/calendar-utils";
import { bookingStatusVariant, dayNumber, monthShort } from "@/components/calendar/calendar-utils";
import { BOOKING_STATUS_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { formatShortDayAr, parseLocalDate } from "@/lib/dates";

type Props = {
  month: string;
  bookings: CalendarBooking[];
};

function groupByStartDate(bookings: CalendarBooking[]) {
  const groups = new Map<string, CalendarBooking[]>();
  for (const b of bookings) {
    const key = b.startDate.slice(0, 10);
    const list = groups.get(key) ?? [];
    list.push(b);
    groups.set(key, list);
  }
  return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
}

export function CalendarAgenda({ month, bookings }: Props) {
  const [y, m] = month.split("-").map(Number);
  const monthStart = new Date(y, m - 1, 1);
  const monthEnd = new Date(y, m, 0);

  const inMonth = bookings.filter((b) => {
    const start = parseLocalDate(b.startDate.slice(0, 10));
    const end = parseLocalDate(b.endDate.slice(0, 10));
    return start <= monthEnd && end >= monthStart;
  });

  const groups = groupByStartDate(inMonth);

  return (
    <section className="cal-agenda-section animate-fade-up animate-fade-up-delay-1">
      <div className="cal-agenda-header">
        <div>
          <h2 className="text-base font-bold text-ink">جدول الشهر</h2>
          <p className="text-xs text-muted">مرتب حسب تاريخ بداية الحجز</p>
        </div>
        <Badge>{inMonth.length} حجز</Badge>
      </div>

      {groups.length === 0 ? (
        <EmptyState variant="calendar" title="لا حجوزات هذا الشهر" description="جرّب شهراً آخر أو أزل فلتر المكان" />
      ) : (
        groups.map(([dateKey, items]) => (
          <div key={dateKey} className="cal-agenda-group">
            <div className="cal-agenda-date-row">
              <div className="cal-agenda-date-badge">
                <span>{monthShort(dateKey)}</span>
                <span>{dayNumber(dateKey)}</span>
              </div>
              <span>{items.length} حجز يبدأ في هذا اليوم</span>
            </div>
            {items.map((b) => (
              <Link key={b.id} href={`/bookings/${b.id}`} className="cal-agenda-item">
                <div className="cal-agenda-time">
                  {formatShortDayAr(b.startDate)}
                  {b.endDate.slice(0, 10) !== b.startDate.slice(0, 10) && (
                    <> → {formatShortDayAr(b.endDate)}</>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="font-semibold text-ink">{b.property?.name ?? "—"}</div>
                  <div className="text-xs text-muted">
                    {b.user?.name ?? b.user?.phone}
                    {b.shift && b.shift !== "FULL" && (
                      <span className="text-accent"> · {SHIFT_TYPE_LABELS[b.shift]}</span>
                    )}
                  </div>
                </div>
                <Badge variant={bookingStatusVariant(b.status)}>
                  {BOOKING_STATUS_LABELS[b.status] ?? b.status}
                </Badge>
              </Link>
            ))}
          </div>
        ))
      )}
    </section>
  );
}
