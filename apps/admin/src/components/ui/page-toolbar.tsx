import type { ReactNode } from "react";

export function PageToolbar({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`page-toolbar ${className}`}>{children}</div>;
}

export function FilterPanel({ open, children }: { open: boolean; children: ReactNode }) {
  if (!open) return null;
  return <div className="filter-panel animate-fade-up">{children}</div>;
}
