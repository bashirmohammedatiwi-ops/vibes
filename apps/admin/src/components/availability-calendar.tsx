"use client";

import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { HelpTip } from "@/components/help-tip";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { FARM_SHIFTS, SHIFT_SHORT_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { localIsoDate } from "@/lib/dates";
import { DEFAULT_SHIFT_TIMES, formatShiftRange, propertyUsesShifts } from "@/lib/shifts";
import type { AvailabilitySlot, PropertyType, ShiftTimes, ShiftType } from "@/lib/types";

type Props = {
  propertyType: PropertyType;
  slots: AvailabilitySlot[];
  shiftTimes?: ShiftTimes;
  onBulkSet: (
    dates: string[],
    isAvailable: boolean,
    options?: { priceOverride?: number; shift?: ShiftType; shifts?: ShiftType[] },
  ) => Promise<void>;
  onClear?: (dates: string[], shifts?: ShiftType[]) => Promise<void>;
  onMonthChange?: (month: string) => void;
};

const WEEKDAYS = ["أحد", "إثن", "ثلا", "أرب", "خمي", "جمع", "سبت"];

function monthKey(date: Date) {
  return new Intl.DateTimeFormat("ar-IQ", { month: "long", year: "numeric" }).format(date);
}

function slotKey(date: string, shift: ShiftType) {
  return `${date.slice(0, 10)}:${shift}`;
}

export function AvailabilityCalendar({ propertyType, slots, shiftTimes = DEFAULT_SHIFT_TIMES, onBulkSet, onClear, onMonthChange }: Props) {
  const usesShifts = propertyUsesShifts(propertyType);
  const [cursor, setCursor] = useState(() => new Date());
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [activeShift, setActiveShift] = useState<ShiftType>("FULL");
  const [priceOverride, setPriceOverride] = useState("");
  const [loading, setLoading] = useState(false);
  const today = localIsoDate(new Date());

  const slotMap = useMemo(
    () => new Map(slots.map((s) => [slotKey(s.date, s.shift), s])),
    [slots],
  );

  const days = useMemo(() => {
    const start = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
    const end = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0);
    const pad = start.getDay();
    const cells: (Date | null)[] = Array.from({ length: pad }, () => null);
    for (let d = 1; d <= end.getDate(); d++) {
      cells.push(new Date(cursor.getFullYear(), cursor.getMonth(), d));
    }
    return cells;
  }, [cursor]);

  function toggle(date: Date) {
    const key = localIsoDate(date);
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  function monthIso(d: Date) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
  }

  function changeMonth(delta: number) {
    const next = new Date(cursor.getFullYear(), cursor.getMonth() + delta, 1);
    setCursor(next);
    onMonthChange?.(monthIso(next));
  }

  function goThisMonth() {
    const next = new Date();
    setCursor(next);
    onMonthChange?.(monthIso(next));
  }
  function selectWeekends() {
    const next = new Set<string>();
    for (const date of days) {
      if (!date) continue;
      const dow = date.getDay();
      if (dow === 5 || dow === 6) next.add(localIsoDate(date));
    }
    setSelected(next);
  }

  function dayShiftState(dateKey: string, shift: ShiftType) {
    const slot = slotMap.get(slotKey(dateKey, shift));
    if (slot && !slot.isAvailable) return "closed";
    if (slot?.isAvailable) return "open";
    return "default";
  }

  async function apply(isAvailable: boolean, allShifts = false) {
    if (!selected.size) return;
    setLoading(true);
    try {
      const override = priceOverride ? Number(priceOverride) : undefined;
      const dates = [...selected];
      if (usesShifts && allShifts) {
        await onBulkSet(dates, isAvailable, { priceOverride: override, shifts: [...FARM_SHIFTS] });
      } else if (usesShifts) {
        await onBulkSet(dates, isAvailable, { priceOverride: override, shift: activeShift });
      } else {
        await onBulkSet(dates, isAvailable, { priceOverride: override, shift: "FULL" });
      }
      setSelected(new Set());
      setPriceOverride("");
    } finally {
      setLoading(false);
    }
  }

  async function clearSelection() {
    if (!selected.size || !onClear) return;
    setLoading(true);
    try {
      await onClear([...selected], usesShifts ? [activeShift] : undefined);
      setSelected(new Set());
      setPriceOverride("");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <HelpTip>
        {usesShifts
          ? "للمزارع: اختر الشفت (صباحي / مسائي / كامل) ثم حدّد الأيام. يمكنك إغلاق شفت واحد دون التأثير على الآخر."
          : "اضغط على الأيام ثم «فتح للحجز» أو «إغلاق». الجمعة والسبت يظهران بلون مختلف."}
      </HelpTip>

      {usesShifts && (
        <div className="avail-shift-panel">
          <div className="mb-3 text-xs font-semibold text-muted">الشفت النشط للتحرير</div>
          <div className="flex flex-wrap gap-2">
            {FARM_SHIFTS.map((shift) => (
              <ToggleChip
                key={shift}
                active={activeShift === shift}
                onClick={() => setActiveShift(shift)}
              >
                {SHIFT_TYPE_LABELS[shift]} · {formatShiftRange(shift, shiftTimes)}
              </ToggleChip>
            ))}
          </div>
        </div>
      )}

      <div className="flex flex-wrap items-center justify-between gap-2">
        <Button type="button" variant="ghost" onClick={() => changeMonth(-1)}>
          الشهر السابق
        </Button>
        <div className="font-semibold">{monthKey(cursor)}</div>
        <div className="flex gap-2">
          <Button type="button" variant="ghost" onClick={goThisMonth}>هذا الشهر</Button>
          <Button type="button" variant="ghost" onClick={() => changeMonth(1)}>
            الشهر التالي
          </Button>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-3 text-xs text-muted">
        <span className="flex items-center gap-1"><span className="inline-block h-3 w-3 rounded border border-success/30 bg-success-soft" /> متاح</span>
        <span className="flex items-center gap-1"><span className="inline-block h-3 w-3 rounded border border-danger/30 bg-danger-soft" /> مغلق</span>
        <span className="flex items-center gap-1"><span className="inline-block h-3 w-3 rounded border border-accent/40 bg-accent/20" /> نهاية أسبوع</span>
        {usesShifts && (
          <span className="flex items-center gap-1">
            <span className="inline-flex gap-0.5">
              <span className="inline-block h-3 w-2 rounded-sm bg-accent/70" />
              <span className="inline-block h-3 w-2 rounded-sm bg-accent/40" />
              <span className="inline-block h-3 w-2 rounded-sm bg-accent/20" />
            </span>
            ص/م/ك
          </span>
        )}
        <button type="button" className="text-accent underline" onClick={selectWeekends}>تحديد الجمعة والسبت</button>
        {selected.size > 0 && (
          <button type="button" className="font-semibold text-muted underline" onClick={() => setSelected(new Set())}>إلغاء التحديد</button>
        )}
      </div>

      <div className="grid grid-cols-7 gap-1 text-center text-xs font-semibold text-muted">
        {WEEKDAYS.map((d) => (
          <div key={d} className="py-1">{d}</div>
        ))}
      </div>

      <div className="grid grid-cols-7 gap-1">
        {days.map((date, i) => {
          if (!date) return <div key={`empty-${i}`} />;
          const key = localIsoDate(date);
          const isSelected = selected.has(key);
          const weekend = date.getDay() === 5 || date.getDay() === 6;
          const activeSlot = slotMap.get(slotKey(key, usesShifts ? activeShift : "FULL"));
          const unavailable = activeSlot && !activeSlot.isAvailable;
          const price = activeSlot?.priceOverride != null ? Number(activeSlot.priceOverride) : null;

          return (
            <button
              key={key}
              type="button"
              onClick={() => toggle(date)}
              className={`avail-day-cell ${
                isSelected
                  ? "avail-day-selected"
                  : unavailable
                    ? "avail-day-closed"
                    : activeSlot?.isAvailable
                      ? "avail-day-open"
                      : weekend
                        ? "avail-day-weekend"
                        : "avail-day-default"
              } ${key === today ? "avail-day-today" : ""}`}
            >
              <div>{date.getDate()}</div>
              {usesShifts && (
                <div className="mt-1 flex justify-center gap-0.5">
                  {FARM_SHIFTS.map((shift) => {
                    const state = dayShiftState(key, shift);
                    return (
                      <span
                        key={shift}
                        title={SHIFT_SHORT_LABELS[shift]}
                        className={`h-1.5 w-1.5 rounded-full ${
                          state === "closed"
                            ? "bg-danger"
                            : shift === activeShift
                              ? "bg-accent"
                              : state === "open"
                                ? "bg-success"
                                : "bg-line"
                        }`}
                      />
                    );
                  })}
                </div>
              )}
              {price ? (
                <div className={`text-[9px] font-normal ${isSelected ? "text-white/80" : "text-muted"}`}>
                  {(price / 1000).toFixed(0)} ألف
                </div>
              ) : null}
            </button>
          );
        })}
      </div>

      {selected.size > 0 && (
        <div className="avail-bulk-bar">
          <p className="mb-1 text-sm font-medium">
            {selected.size} يوم محدد
            {usesShifts && ` · ${SHIFT_TYPE_LABELS[activeShift]}`}
          </p>
          {usesShifts && (
            <p className="mb-3 text-xs text-muted">
              أوقات الشفت: {formatShiftRange(activeShift, shiftTimes)}
            </p>
          )}
          <div className="flex flex-wrap items-end gap-3">
            <div className="min-w-[160px]">
              <label className="mb-1 block text-xs font-semibold text-muted">سعر خاص (اختياري)</label>
              <Input value={priceOverride} onChange={(e) => setPriceOverride(e.target.value)} placeholder="بالدينار" />
            </div>
            <Button type="button" disabled={loading} onClick={() => apply(true)}>
              فتح للحجز
            </Button>
            <Button type="button" variant="danger" disabled={loading} onClick={() => apply(false)}>
              إغلاق
            </Button>
            {usesShifts && (
              <>
                <Button type="button" variant="ghost" disabled={loading} onClick={() => apply(true, true)}>
                  فتح كل الشفتات
                </Button>
                <Button type="button" variant="ghost" disabled={loading} onClick={() => apply(false, true)}>
                  إغلاق كل الشفتات
                </Button>
              </>
            )}
            {onClear && (
              <Button
                type="button"
                variant="ghost"
                disabled={loading}
                onClick={clearSelection}
                title="إزالة التخصيص والسعر الخاص لهذه الأيام"
              >
                مسح التخصيص
              </Button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
