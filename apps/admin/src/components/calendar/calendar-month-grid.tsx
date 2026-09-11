"use client";

import type { CalendarCell } from "@/components/calendar/calendar-utils";
import { dayKey, heatLevel, WEEKDAYS } from "@/components/calendar/calendar-utils";

type Props = {
  cells: CalendarCell[];
  maxBookings: number;
  selectedDays: Set<string>;
  onToggleDay: (key: string) => void;
};

export function CalendarMonthGrid({ cells, maxBookings, selectedDays, onToggleDay }: Props) {
  const today = dayKey(new Date());

  return (
    <div className="cal-grid-card animate-fade-up">
      <div className="cal-grid-inner">
        <div className="cal-weekdays">
          {WEEKDAYS.map((w, i) => (
            <div key={w} className={`cal-weekday ${i === 5 || i === 6 ? "cal-weekday-weekend" : ""}`}>
              {w}
            </div>
          ))}
        </div>

        <div className="cal-grid">
          {cells.map((cell, i) => {
            if (!cell.date) {
              return <div key={`pad-${i}`} className="cal-cell-v2-empty" aria-hidden />;
            }

            const key = dayKey(cell.date);
            const isSelected = selectedDays.has(key);
            const isToday = key === today;
            const weekend = cell.date.getDay() === 5 || cell.date.getDay() === 6;
            const heat = heatLevel(cell.bookings, maxBookings);

            const classes = [
              "cal-cell-v2",
              weekend ? "cal-cell-v2-weekend" : "",
              heat > 0 ? `cal-cell-v2-heat-${heat}` : "",
              cell.blocked > 0 ? "cal-cell-v2-blocked" : "",
              isSelected ? "cal-cell-v2-selected" : "",
              isToday ? "cal-cell-v2-today" : "",
            ]
              .filter(Boolean)
              .join(" ");

            return (
              <button
                key={key}
                type="button"
                onClick={() => onToggleDay(key)}
                className={classes}
                aria-label={`${cell.date.getDate()} — ${cell.bookings} حجز`}
                aria-pressed={isSelected}
              >
                <span className="cal-day-num">{cell.date.getDate()}</span>
                <div className="cal-dots">
                  {Array.from({ length: Math.min(cell.bookings, 4) }).map((_, di) => (
                    <span key={di} className="cal-dot cal-dot-booking" />
                  ))}
                  {cell.blocked > 0 && <span className="cal-dot cal-dot-blocked" title="يوم مغلق" />}
                </div>
              </button>
            );
          })}
        </div>

        <div className="cal-legend">
          <span className="cal-legend-item">
            <span className="cal-legend-swatch" style={{ background: "var(--color-paper)" }} />
            فارغ
          </span>
          <span className="cal-legend-item">
            <span className="cal-legend-swatch cal-cell-v2-heat-2" style={{ width: "0.75rem", height: "0.75rem" }} />
            حجوزات
          </span>
          <span className="cal-legend-item">
            <span className="cal-legend-swatch" style={{ background: "var(--color-accent-soft)" }} />
            نهاية أسبوع
          </span>
          <span className="cal-legend-item">
            <span className="cal-legend-swatch" style={{ background: "var(--color-danger)", borderRadius: "999px", width: "0.5rem", height: "0.5rem" }} />
            مغلق يدوياً
          </span>
          <span className="cal-legend-item">
            <span className="cal-legend-swatch" style={{ boxShadow: "0 0 0 2px var(--color-accent)" }} />
            اليوم
          </span>
        </div>
      </div>
    </div>
  );
}
