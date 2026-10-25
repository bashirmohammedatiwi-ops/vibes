"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Lock } from "lucide-react";
import { useAuth } from "@/lib/auth";

export function RequireAuth({ children, title = "سجّل الدخول للمتابعة" }: { children: React.ReactNode; title?: string }) {
  const { user, ready } = useAuth();
  const pathname = usePathname();
  if (!ready) return <PageSkeleton />;
  if (!user)
    return (
      <div className="container-x flex min-h-[55vh] flex-col items-center justify-center py-16 text-center">
        <span className="mb-4 flex h-16 w-16 items-center justify-center rounded-3xl bg-midnight">
          <Lock className="h-7 w-7 text-brass-light" />
        </span>
        <h1 className="text-xl font-black">{title}</h1>
        <p className="mt-1 text-sm text-ink-2">نفس حسابك في تطبيق VIBES — برقم هاتفك ورمزك السري.</p>
        <Link href={`/login?next=${encodeURIComponent(pathname)}`} className="btn btn-primary mt-6 h-12 px-8">
          تسجيل الدخول
        </Link>
      </div>
    );
  return <>{children}</>;
}

export function PageSkeleton() {
  return (
    <div className="container-x space-y-4 py-10">
      <div className="skeleton h-8 w-48 rounded-xl" />
      <div className="skeleton h-28 rounded-3xl" />
      <div className="skeleton h-28 rounded-3xl" />
    </div>
  );
}

export function StatusBadge({ tone, children }: { tone: "warn" | "ok" | "bad" | "muted" | "info"; children: React.ReactNode }) {
  const cls = {
    warn: "bg-warning-pale text-warning",
    ok: "bg-success-pale text-success",
    bad: "bg-danger-pale text-danger",
    muted: "bg-soft text-ink-2",
    info: "bg-sapphire-pale text-sapphire",
  }[tone];
  return <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-black ${cls}`}>{children}</span>;
}

export function EmptyState({ icon, title, text, action }: { icon: string; title: string; text?: string; action?: React.ReactNode }) {
  return (
    <div className="card flex flex-col items-center px-6 py-14 text-center">
      <div className="text-4xl">{icon}</div>
      <h2 className="mt-3 text-lg font-black">{title}</h2>
      {text && <p className="mt-1 max-w-sm text-sm text-ink-2">{text}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}
