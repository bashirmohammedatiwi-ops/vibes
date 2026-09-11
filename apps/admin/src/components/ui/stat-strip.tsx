import type { ReactNode } from "react";

type Stat = {
  label: string;
  value: ReactNode;
  hint?: string;
  accent?: boolean;
  alert?: boolean;
  icon?: ReactNode;
};

export function StatStrip({ stats }: { stats: Stat[] }) {
  return (
    <div className="page-kpi-row animate-fade-up animate-fade-up-delay-1">
      {stats.map((s, i) => (
        <div
          key={s.label}
          className={`page-kpi-item ${s.accent ? "page-kpi-item-accent" : ""} ${s.alert ? "page-kpi-item-alert" : ""}`}
          style={{ animationDelay: `${i * 0.04}s` }}
        >
          {s.icon && <span className="page-kpi-icon">{s.icon}</span>}
          <div className="min-w-0 flex-1">
            <div className="page-kpi-label">{s.label}</div>
            <div className="page-kpi-value">{s.value}</div>
            {s.hint && <div className="page-kpi-hint">{s.hint}</div>}
          </div>
        </div>
      ))}
    </div>
  );
}
