import type { ReactNode } from "react";

/** Consistent outer wrapper for admin pages */
export function PageShell({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`page-shell ${className}`.trim()}>{children}</div>;
}

/** Unified card for filters + tables + lists */
export function ContentPanel({
  children,
  className = "",
  flush = true,
}: {
  children: ReactNode;
  className?: string;
  flush?: boolean;
}) {
  return (
    <div className={`content-panel ${flush ? "content-panel-flush" : ""} ${className}`.trim()}>
      {children}
    </div>
  );
}

/** Toolbar zone inside ContentPanel */
export function ContentToolbar({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`content-toolbar ${className}`}>{children}</div>;
}

/** Footer zone for pagination */
export function ContentFooter({ children }: { children: ReactNode }) {
  return <div className="content-footer">{children}</div>;
}
