type Point = { label: string; value: number };

export function SparkChart({ data, formatValue }: { data: Point[]; formatValue?: (v: number) => string }) {
  const max = Math.max(...data.map((d) => d.value), 1);

  return (
    <div className="spark-chart">
      <div className="spark-bars">
        {data.map((point) => {
          const pct = Math.max(8, (point.value / max) * 100);
          return (
            <div key={point.label} className="spark-bar-col">
              <div className="spark-bar-value">{formatValue ? formatValue(point.value) : point.value}</div>
              <div className="spark-bar-track">
                <div className="spark-bar-fill" style={{ height: `${pct}%` }} title={formatValue?.(point.value)} />
              </div>
              <div className="spark-bar-label">{point.label}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function DonutRing({
  value,
  max,
  label,
  sublabel,
}: {
  value: number;
  max: number;
  label: string;
  sublabel?: string;
}) {
  const pct = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;

  return (
    <div className="donut-ring">
      <div
        className="donut-ring-chart"
        style={{ background: `conic-gradient(var(--color-accent) ${pct * 3.6}deg, var(--color-line) 0deg)` }}
      >
        <div className="donut-ring-inner">
          <div className="text-2xl font-bold text-ink">{value}</div>
          <div className="text-[10px] font-semibold text-muted">{pct}%</div>
        </div>
      </div>
      <div className="mt-3 text-center">
        <div className="text-sm font-bold text-ink">{label}</div>
        {sublabel && <div className="mt-0.5 text-xs text-muted">{sublabel}</div>}
      </div>
    </div>
  );
}
