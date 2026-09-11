import type { ReactNode } from "react";

type Variant = "default" | "search" | "calendar" | "payment";

const icons: Record<Variant, ReactNode> = {
  default: (
    <svg className="h-7 w-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <rect x="4" y="4" width="16" height="16" rx="4" />
      <path d="M8 12h8" strokeLinecap="round" />
    </svg>
  ),
  search: (
    <svg className="h-7 w-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <circle cx="11" cy="11" r="6" />
      <path d="M20 20l-3-3" strokeLinecap="round" />
    </svg>
  ),
  calendar: (
    <svg className="h-7 w-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M8 3v4M16 3v4M3 10h18" strokeLinecap="round" />
    </svg>
  ),
  payment: (
    <svg className="h-7 w-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <rect x="2" y="6" width="20" height="14" rx="2" />
      <path d="M2 10h20" />
    </svg>
  ),
};

type Props = {
  title: string;
  description?: string;
  action?: React.ReactNode;
  variant?: Variant;
};

export function EmptyState({ title, description, action, variant = "default" }: Props) {
  return (
    <div className="empty-state-wrap">
      <div className="empty-state-icon-wrap">{icons[variant]}</div>
      <p className="empty-state-title">{title}</p>
      {description && <p className="empty-state-desc">{description}</p>}
      {action && <div className="empty-state-action">{action}</div>}
    </div>
  );
}
