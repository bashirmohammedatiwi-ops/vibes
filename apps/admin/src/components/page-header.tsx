import { BackLink } from "@/components/ui/detail-card";
import { Button } from "@/components/ui/button";

export function PageHeader({
  title,
  description,
  action,
  eyebrow,
  back,
  onRefresh,
  refreshing,
  variant = "default",
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
  eyebrow?: string;
  back?: { href: string; label: string };
  onRefresh?: () => void;
  refreshing?: boolean;
  variant?: "default" | "compact";
}) {
  if (variant === "compact") {
    return (
      <div className="page-header-compact mb-5">
        {back && (
          <div className="mb-2">
            <BackLink href={back.href}>{back.label}</BackLink>
          </div>
        )}
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="min-w-0">
            {eyebrow && <div className="page-eyebrow">{eyebrow}</div>}
            <h1 className="page-title-compact">{title}</h1>
            {description && <p className="page-desc-compact">{description}</p>}
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {onRefresh && (
              <Button variant="ghost" size="sm" onClick={onRefresh} disabled={refreshing} aria-label="تحديث">
                <RefreshIcon spinning={refreshing} />
              </Button>
            )}
            {action}
          </div>
        </div>
      </div>
    );
  }

  return (
    <header className="page-head-card page-head-modern animate-fade-up">
      {back && (
        <div className="mb-3">
          <BackLink href={back.href}>{back.label}</BackLink>
        </div>
      )}
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-0 flex-1">
          {eyebrow && <div className="page-eyebrow">{eyebrow}</div>}
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="page-title">{title}</h1>
            {onRefresh && (
              <Button
                variant="ghost"
                size="sm"
                onClick={onRefresh}
                disabled={refreshing}
                className="shrink-0"
                aria-label="تحديث"
              >
                <RefreshIcon spinning={refreshing} />
              </Button>
            )}
          </div>
          {description && <p className="page-desc">{description}</p>}
        </div>
        {action && (
          <div className="dash-hero-actions shrink-0">{action}</div>
        )}
      </div>
    </header>
  );
}

function RefreshIcon({ spinning }: { spinning?: boolean }) {
  return (
    <svg
      className={`h-4 w-4 ${spinning ? "animate-spin" : ""}`}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
    >
      <path d="M21 12a9 9 0 11-2.64-6.36" strokeLinecap="round" />
      <path d="M21 3v6h-6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function StatCard({
  label,
  value,
  hint,
  accent,
  icon,
}: {
  label: string;
  value: React.ReactNode;
  hint?: string;
  accent?: boolean;
  icon?: React.ReactNode;
}) {
  return (
    <div className={`page-kpi-item ${accent ? "page-kpi-item-accent" : ""}`}>
      {icon && <span className="page-kpi-icon">{icon}</span>}
      <div className="min-w-0 flex-1">
        <div className="page-kpi-label">{label}</div>
        <div className="page-kpi-value">{value ?? "—"}</div>
        {hint && <div className="page-kpi-hint">{hint}</div>}
      </div>
    </div>
  );
}

export function LoadingBlock({ label = "جاري التحميل..." }: { label?: string }) {
  return (
    <div className="loading-block">
      <div className="loading-block-spinner">
        <span className="inline-block h-10 w-10 animate-spin rounded-full border-[3px] border-accent/20 border-t-accent" />
      </div>
      <span className="text-sm font-semibold text-muted">{label}</span>
    </div>
  );
}
