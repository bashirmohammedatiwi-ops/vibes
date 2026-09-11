"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";
import { IconCalendar } from "@/components/nav-icons";
import { BOOKING_STATUS_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { formatDayAr, localIsoDate } from "@/lib/dates";
import type { CalendarBooking } from "@/components/calendar/calendar-utils";
import { overlapsDay } from "@/components/calendar/calendar-utils";

export function TodayAgenda() {
  const [bookings, setBookings] = useState<CalendarBooking[]>([]);
  const [loading, setLoading] = useState(true);
  const today = localIsoDate(new Date());
  const month = today.slice(0, 7);

  useEffect(() => {
    setLoading(true);
    api<{ bookings: CalendarBooking[] }>(`/api/admin/calendar${buildQuery({ month })}`)
      .then((data) => {
        const todayItems = data.bookings.filter((b) =>
          overlapsDay(b.startDate, b.endDate, new Date(today)),
        );
        setBookings(todayItems.slice(0, 5));
      })
      .catch(() => setBookings([]))
      .finally(() => setLoading(false));
  }, [month, today]);

  return (
    <div className="dash-panel h-full">
      <div className="dash-panel-head">
        <div className="flex items-center gap-2.5">
          <span className="dash-panel-icon">
            <IconCalendar className="h-4 w-4" />
          </span>
          <div>
            <h2 className="dash-panel-title">جدول اليوم</h2>
            <p className="dash-panel-desc">{formatDayAr(today)}</p>
          </div>
        </div>
        <Badge variant={bookings.length ? "warning" : "muted"}>{bookings.length}</Badge>
      </div>

      <div className="dash-agenda-list">
        {loading && <p className="py-8 text-center text-sm text-muted">جاري التحميل...</p>}
        {!loading && bookings.length === 0 && (
          <EmptyState variant="calendar" title="لا حجوزات اليوم" description="يوم هادئ على التقويم" />
        )}
        {!loading &&
          bookings.map((b) => (
            <Link key={b.id} href={`/bookings/${b.id}`} className="dash-agenda-item">
              <div className="min-w-0 flex-1">
                <div className="truncate font-semibold text-ink">{b.property?.name ?? "—"}</div>
                <div className="text-xs text-muted">
                  {b.user?.name ?? b.user?.phone}
                  {b.shift && b.shift !== "FULL" && (
                    <span className="text-accent"> · {SHIFT_TYPE_LABELS[b.shift]}</span>
                  )}
                </div>
              </div>
              <Badge variant={b.status === "CONFIRMED" || b.status === "COMPLETED" ? "success" : "warning"}>
                {BOOKING_STATUS_LABELS[b.status] ?? b.status}
              </Badge>
            </Link>
          ))}
      </div>

      <Link href="/calendar" className="mt-4 block">
        <Button variant="ghost" className="w-full" size="sm">
          فتح التقويم
        </Button>
      </Link>
    </div>
  );
}
