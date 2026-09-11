import Link from "next/link";
import type { ReactNode } from "react";

export function Fab({
  href,
  onClick,
  label,
  children,
  className = "",
}: {
  href?: string;
  onClick?: () => void;
  label: string;
  children: ReactNode;
  className?: string;
}) {
  const cls = `fab animate-fab-pop ${className}`;

  if (href) {
    return (
      <Link href={href} className={cls} aria-label={label}>
        {children}
      </Link>
    );
  }

  return (
    <button type="button" className={cls} onClick={onClick} aria-label={label}>
      {children}
    </button>
  );
}
