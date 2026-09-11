"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CalendarAgenda } from "@/components/calendar/calendar-agenda";
import { CalendarDayPanel } from "@/components/calendar/calendar-day-panel";
import { CalendarMonthGrid } from "@/components/calendar/calendar-month-grid";
import {
  buildMonthGrid,
  dayKey,
  formatMonthLabel,
  overlapsDay,
  type CalendarBooking,
} from "@/components/calendar/calendar-utils";
import { Alert } from "@/components/ui/alert";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { StatStrip } from "@/components/ui/stat-strip";
import { Select } from "@/components/ui/input";
import { SkeletonList } from "@/components/ui/skeleton";
import { PROPERTY_TYPE_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { useToast } from "@/components/ui/toast";
import { IconBuilding, IconCalendar, IconChart } from "@/components/nav-icons";
import type { PropertyType, ShiftType } from "@/lib/types";
import { propertyUsesShifts } from "@/lib/shifts";
import { api, buildQuery } from "@/lib/api";
import { formatDayAr, localIsoDate, parseLocalDate } from "@/lib/dates";

type CalendarData = {
  month: string;
  bookings: CalendarBooking[];
  blockedSlots: Array<{ date: string; shift?: string; property?: { name: string; type?: string } }>;
};

export default function CalendarPage() {
  const { toast } = useToast();
  const [month, setMonth] = useState(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
  });
  const [data, setData] = useState<CalendarData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [propertyId, setPropertyId] = useState("");
  const [propertyType, setPropertyType] = useState("");
  const [properties, setProperties] = useState<Array<{ id: string; name: string; type: PropertyType }>>([]);
  const [selectedDays, setSelectedDays] = useState<Set<string>>(new Set());
  const [savingDay, setSavingDay] = useState(false);
  const [activeShift, setActiveShift] = useState<ShiftType>("FULL");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(
        await api<CalendarData>(
          `/api/admin/calendar${buildQuery({ month, propertyId, propertyType: propertyType || undefined })}`,
        ),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل التقويم");
    } finally {
      setLoading(false);
    }
  }, [month, propertyId, propertyType]);

  useEffect(() => {
    api<{ items: Array<{ id: string; name: string; type: PropertyType }> }>("/api/admin/properties?pageSize=200")
      .then((res) => setProperties(res.items.map((p) => ({ id: p.id, name: p.name, type: p.type }))))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    load().catch(() => undefined);
    setSelectedDays(new Set());
  }, [load]);

  function toggleDay(key: string) {
    setSelectedDays((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  async function setDayOpen(open: boolean, shift?: ShiftType) {
    const dates = [...selectedDays];
    if (!propertyId || !dates.length) {
      toast("اختر مكاناً وأياماً أولاً", "error");
      return;
    }
    setSavingDay(true);
    try {
      const selected = properties.find((p) => p.id === propertyId);
      const body: Record<string, unknown> = { dates, isAvailable: open };
      if (selected && propertyUsesShifts(selected.type)) {
        body.shift = shift ?? activeShift;
      }
      await api(`/api/admin/properties/${propertyId}/availability/bulk`, {
        method: "POST",
        body: JSON.stringify(body),
      });
      toast(open ? `تم فتح ${dates.length} يوم للحجز` : `تم إغلاق ${dates.length} يوم`);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    } finally {
      setSavingDay(false);
    }
  }

  async function setDayPrice(price: number) {
    const dates = [...selectedDays];
    if (!propertyId || dates.length !== 1) {
      toast("اختر يوماً واحداً لتعيين السعر", "error");
      return;
    }
    setSavingDay(true);
    try {
      const selected = properties.find((p) => p.id === propertyId);
      const body: Record<string, unknown> = {
        dates,
        isAvailable: true,
        priceOverride: price,
      };
      if (selected && propertyUsesShifts(selected.type)) {
        body.shift = activeShift;
      }
      await api(`/api/admin/properties/${propertyId}/availability/bulk`, {
        method: "POST",
        body: JSON.stringify(body),
      });
      toast(`تم تعيين السعر ${price.toLocaleString("ar-IQ")} د.ع`);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    } finally {
      setSavingDay(false);
    }
  }

  function shift(delta: number) {
    const [y, m] = month.split("-").map(Number);
    const d = new Date(y, m - 1 + delta, 1);
    setMonth(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
  }

  function goToday() {
    const d = new Date();
    setMonth(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
    setSelectedDays(new Set([localIsoDate(d)]));
  }

  const bookings = data?.bookings ?? [];
  const blockedSlots = data?.blockedSlots ?? [];

  const grid = useMemo(
    () => buildMonthGrid(month, bookings, blockedSlots),
    [month, bookings, blockedSlots],
  );

  const maxBookings = useMemo(
    () => Math.max(...grid.filter((c) => c.date).map((c) => c.bookings), 1),
    [grid],
  );

  const busyDayCount = useMemo(
    () => grid.filter((c) => c.date && c.bookings > 0).length,
    [grid],
  );

  const selectedDaysList = [...selectedDays].sort();
  const dayBookings = selectedDaysList.length
    ? bookings.filter((b) =>
        selectedDaysList.some((d) => overlapsDay(b.startDate, b.endDate, parseLocalDate(d))),
      )
    : [];

  const propertyName = properties.find((p) => p.id === propertyId)?.name;
  const selectedPropertyType = properties.find((p) => p.id === propertyId)?.type;
  const todayKey = dayKey(new Date());
  const todayBookings = bookings.filter((b) => overlapsDay(b.startDate, b.endDate, new Date())).length;

  return (
    <PageShell>
      <PageHeader
        title="التقويم"
        description="شبكة حرارية للحجوزات — اضغط يوماً للتفاصيل وإدارة التوفر"
        eyebrow="VIBES Admin"
        onRefresh={load}
        refreshing={loading}
      />

      {error && <Alert variant="danger">{error}</Alert>}

      <StatStrip
        stats={[
          {
            label: "حجوزات الشهر",
            value: loading ? "—" : bookings.length,
            accent: true,
            icon: <IconCalendar className="h-5 w-5" />,
          },
          {
            label: "حجوزات اليوم",
            value: loading ? "—" : todayBookings,
            hint: formatDayAr(todayKey),
            icon: <IconChart className="h-5 w-5" />,
          },
          {
            label: "أيام نشطة",
            value: loading ? "—" : busyDayCount,
            icon: <IconBuilding className="h-5 w-5" />,
          },
          {
            label: "أيام مغلقة",
            value: loading ? "—" : blockedSlots.length,
            hint: propertyName ?? "كل الأماكن",
          },
        ]}
      />

      <div className="cal-toolbar animate-fade-up">
        <div className="cal-month-nav">
          <Button variant="ghost" size="sm" onClick={() => shift(-1)} aria-label="الشهر السابق">
            ←
          </Button>
          <div className="cal-month-label">
            <strong>{formatMonthLabel(month)}</strong>
            <span>{propertyName ?? "كل الأماكن"}</span>
          </div>
          <Button variant="ghost" size="sm" onClick={() => shift(1)} aria-label="الشهر التالي">
            →
          </Button>
          <Button variant="accent" size="sm" onClick={goToday}>
            اليوم
          </Button>
        </div>
        <Select
          value={propertyType}
          onChange={(e) => setPropertyType(e.target.value)}
          className="min-w-[9rem]"
        >
          <option value="">كل الأنواع</option>
          {Object.entries(PROPERTY_TYPE_LABELS).map(([key, label]) => (
            <option key={key} value={key}>{label}</option>
          ))}
        </Select>
        <Select
          value={propertyId}
          onChange={(e) => setPropertyId(e.target.value)}
          className="min-w-[12rem] max-w-xs"
        >
          <option value="">كل الأماكن</option>
          {properties.map((p) => (
            <option key={p.id} value={p.id}>{p.name}</option>
          ))}
        </Select>
      </div>

      <HelpTip variant="info">
        كلما زادت كثافة اللون الأخضر زادت الحجوزات في ذلك اليوم. النقطة الحمراء تعني إغلاقاً يدوياً.
      </HelpTip>

      {loading ? (
        <SkeletonList count={8} />
      ) : (
        <>
          <div className="cal-layout">
            <CalendarMonthGrid
              cells={grid}
              maxBookings={maxBookings}
              selectedDays={selectedDays}
              onToggleDay={toggleDay}
            />
            <CalendarDayPanel
              selectedDays={selectedDaysList}
              dayBookings={dayBookings}
              month={month}
              monthBookingCount={bookings.length}
              blockedCount={blockedSlots.length}
              busyDayCount={busyDayCount}
              propertyId={propertyId}
              propertyName={propertyName}
              propertyType={selectedPropertyType}
              activeShift={activeShift}
              onShiftChange={setActiveShift}
              savingDay={savingDay}
              onOpenDay={(open, shift) => setDayOpen(open, shift)}
              onPriceOverride={propertyId ? setDayPrice : undefined}
              onGoToday={() => setSelectedDays(new Set())}
              upcoming={bookings}
            />
          </div>

          <CalendarAgenda month={month} bookings={bookings} />

          {blockedSlots.length > 0 && (
            <section className="cal-agenda-section animate-fade-up">
              <div className="cal-agenda-header">
                <div>
                  <h2 className="text-base font-bold text-ink">أيام مغلقة يدوياً</h2>
                  <p className="text-xs text-muted">من إعدادات توفر الأماكن</p>
                </div>
                <Badge variant="danger">{blockedSlots.length}</Badge>
              </div>
              <div className="cal-blocked-grid">
                {blockedSlots.slice(0, 48).map((s, i) => (
                  <span key={`${s.date}-${s.shift ?? "FULL"}-${i}`} className="cal-blocked-chip">
                    {formatDayAr(s.date.slice(0, 10))}
                    {s.shift && s.shift !== "FULL" && ` · ${SHIFT_TYPE_LABELS[s.shift] ?? s.shift}`}
                    {s.property?.name && ` · ${s.property.name}`}
                  </span>
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </PageShell>
  );
}
