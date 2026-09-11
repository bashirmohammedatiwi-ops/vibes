"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ListRow } from "@/components/ui/list-row";
import { EmptyState } from "@/components/empty-state";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { IconCalendar } from "@/components/nav-icons";
import type { CalendarBooking } from "@/components/calendar/calendar-utils";
import { bookingStatusVariant, formatMonthLabel } from "@/components/calendar/calendar-utils";
import { BOOKING_STATUS_LABELS, FARM_SHIFTS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { formatDayAr, formatMoney } from "@/lib/dates";
import { propertyUsesShifts } from "@/lib/shifts";
import type { PropertyType, ShiftType } from "@/lib/types";
import { Input } from "@/components/ui/input";

type Props = {
  selectedDays: string[];
  dayBookings: CalendarBooking[];
  month: string;
  monthBookingCount: number;
  blockedCount: number;
  busyDayCount: number;
  propertyId: string;
  propertyName?: string;
  propertyType?: PropertyType;
  activeShift: ShiftType;
  onShiftChange: (shift: ShiftType) => void;
  savingDay: boolean;
  onOpenDay: (open: boolean, shift?: ShiftType) => void;
  onGoToday: () => void;
  onPriceOverride?: (price: number) => void;
  upcoming: CalendarBooking[];
};

export function CalendarDayPanel({
  selectedDays,
  dayBookings,
  month,
  monthBookingCount,
  blockedCount,
  busyDayCount,
  propertyId,
  propertyName,
  propertyType,
  activeShift,
  onShiftChange,
  savingDay,
  onOpenDay,
  onGoToday,
  onPriceOverride,
  upcoming,
}: Props) {
  const farm = propertyUsesShifts(propertyType);
  const [priceInput, setPriceInput] = useState("");

  const dayRevenue = useMemo(
    () =>
      dayBookings.reduce((sum, b) => sum + Number((b as CalendarBooking & { totalPrice?: number | string }).totalPrice ?? 0), 0),
    [dayBookings],
  );

  if (selectedDays.length > 0) {
    const primaryDay = selectedDays[0];
    return (
      <aside className="cal-sidebar animate-fade-up">
        <div className="cal-sidebar-card">
          <div className="cal-sidebar-header">
            <div className="cal-sidebar-date">
              {selectedDays.length === 1 ? formatDayAr(primaryDay) : `${selectedDays.length} أيام محددة`}
            </div>
            <p className="cal-sidebar-sub">
              {dayBookings.length} حجز
              {dayRevenue > 0 && ` · ${formatMoney(dayRevenue)}`}
              {propertyName ? ` · ${propertyName}` : ""}
            </p>
            {selectedDays.length > 1 && (
              <p className="mt-1 text-xs text-muted">
                {selectedDays.slice(0, 4).map((d) => formatDayAr(d)).join(" · ")}
                {selectedDays.length > 4 && ` +${selectedDays.length - 4}`}
              </p>
            )}
          </div>
          <div className="cal-sidebar-body space-y-4">
            {dayBookings.length === 0 ? (
              <EmptyState
                variant="calendar"
                title="لا حجوزات"
                description="هذا اليوم خالٍ من الحجوزات في الفلتر الحالي"
              />
            ) : (
              <div className="list-rows">
                {dayBookings.map((b) => (
                  <Link key={b.id} href={`/bookings/${b.id}`}>
                    <ListRow
                      title={b.property?.name ?? "—"}
                      subtitle={
                        <>
                          {b.user?.name ?? b.user?.phone}
                          {b.shift && b.shift !== "FULL" && (
                            <span className="ms-1 text-accent">· {SHIFT_TYPE_LABELS[b.shift] ?? b.shift}</span>
                          )}
                        </>
                      }
                      badge={
                        <Badge variant={bookingStatusVariant(b.status)}>
                          {BOOKING_STATUS_LABELS[b.status] ?? b.status}
                        </Badge>
                      }
                    />
                  </Link>
                ))}
              </div>
            )}

            {propertyId ? (
              <div className="rounded-xl border border-line bg-surface p-3">
                <p className="mb-3 text-xs font-semibold text-muted">إدارة التوفر لهذا المكان</p>
                {farm && (
                  <div className="mb-3 flex flex-wrap gap-1.5">
                    {FARM_SHIFTS.map((shift) => (
                      <ToggleChip
                        key={shift}
                        active={activeShift === shift}
                        onClick={() => onShiftChange(shift)}
                      >
                        {SHIFT_TYPE_LABELS[shift]}
                      </ToggleChip>
                    ))}
                  </div>
                )}
                <div className="flex flex-wrap gap-2">
                  <Button variant="ghost" size="sm" disabled={savingDay} onClick={() => onOpenDay(false, activeShift)}>
                    إغلاق {selectedDays.length > 1 ? "الأيام" : farm ? "الشفت" : "اليوم"}
                  </Button>
                  <Button size="sm" disabled={savingDay} onClick={() => onOpenDay(true, activeShift)}>
                    فتح للحجز
                  </Button>
                </div>
                {onPriceOverride && (
                  <div className="mt-3 border-t border-line pt-3">
                    <p className="mb-1.5 text-xs text-muted">سعر خاص لهذا اليوم (د.ع)</p>
                    <div className="mt-1.5 flex gap-2">
                      <Input
                        type="number"
                        min={0}
                        placeholder="مثال: 150000"
                        value={priceInput}
                        onChange={(e) => setPriceInput(e.target.value)}
                        className="flex-1 text-sm"
                      />
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={savingDay || !priceInput.trim()}
                        onClick={() => {
                          const price = Number(priceInput);
                          if (Number.isFinite(price) && price > 0) {
                            onPriceOverride(price);
                            setPriceInput("");
                          }
                        }}
                      >
                        تطبيق
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <p className="rounded-xl border border-dashed border-line bg-surface px-3 py-2.5 text-xs leading-6 text-muted">
                لإغلاق أو فتح يوم، اختر مكاناً محدداً من القائمة أعلاه.
              </p>
            )}

            <Button variant="ghost" size="sm" className="w-full" onClick={() => onGoToday()}>
              إلغاء التحديد
            </Button>
          </div>
        </div>
      </aside>
    );
  }

  return (
    <aside className="cal-sidebar animate-fade-up">
      <div className="cal-sidebar-card">
        <div className="cal-sidebar-header cal-sidebar-header-muted">
          <div className="flex items-center gap-2.5">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent-soft text-accent">
              <IconCalendar className="h-5 w-5" />
            </span>
            <div>
              <div className="cal-sidebar-date text-lg">{formatMonthLabel(month)}</div>
              <p className="cal-sidebar-sub text-muted">نظرة عامة على الشهر</p>
            </div>
          </div>
        </div>
        <div className="cal-sidebar-body space-y-3">
          <div className="cal-mini-stat">
            <span className="text-muted">حجوزات الشهر</span>
            <span className="font-bold text-accent">{monthBookingCount}</span>
          </div>
          <div className="cal-mini-stat">
            <span className="text-muted">أيام بها حجوزات</span>
            <span className="font-bold text-ink">{busyDayCount}</span>
          </div>
          <div className="cal-mini-stat">
            <span className="text-muted">أيام مغلقة</span>
            <span className="font-bold text-danger">{blockedCount}</span>
          </div>
          {upcoming.length > 0 && (
            <div className="mt-4 border-t border-line pt-4">
              <p className="mb-2 text-xs font-semibold text-muted">أقرب الحجوزات</p>
              <div className="space-y-2">
                {upcoming.slice(0, 4).map((b) => (
                  <Link key={b.id} href={`/bookings/${b.id}`} className="block rounded-lg border border-line bg-paper px-3 py-2 text-xs transition hover:bg-accent-soft">
                    <div className="font-semibold text-ink">{b.property?.name ?? "—"}</div>
                    <div className="text-muted">
                      {formatDayAr(b.startDate.slice(0, 10))}
                      {b.shift && b.shift !== "FULL" && ` · ${SHIFT_TYPE_LABELS[b.shift]}`}
                    </div>
                  </Link>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </aside>
  );
}
