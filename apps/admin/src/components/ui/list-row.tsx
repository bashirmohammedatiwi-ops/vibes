import type { ReactNode } from "react";

type Props = {
  onClick?: () => void;
  leading?: ReactNode;
  title: ReactNode;
  subtitle?: ReactNode;
  meta?: ReactNode;
  badge?: ReactNode;
  footer?: ReactNode;
  className?: string;
};

export function ListRow({ onClick, leading, title, subtitle, meta, badge, footer, className = "" }: Props) {
  return (
    <div
      className={`list-row ${onClick ? "list-row-clickable" : ""} ${className}`}
      onClick={onClick}
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => e.key === "Enter" && onClick() : undefined}
    >
      <div className="flex items-start gap-3">
        {leading}
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <div className="font-semibold text-ink">{title}</div>
              {subtitle && <div className="mt-0.5 text-xs leading-5 text-muted">{subtitle}</div>}
            </div>
            {badge}
          </div>
          {meta && <div className="mt-2 flex flex-wrap items-center gap-2">{meta}</div>}
        </div>
      </div>
      {footer && <div className="list-row-footer">{footer}</div>}
    </div>
  );
}
