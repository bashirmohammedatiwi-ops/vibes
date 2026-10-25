"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { Bell, CalendarDays, Heart, LogOut, MessageCircle, Search, Sparkles, Tag, User } from "lucide-react";
import { Logo } from "./logo";
import { useAuth } from "@/lib/auth";
import { api } from "@/lib/api";

const NAV = [
  { href: "/search?type=FARM", label: "المزارع", match: "FARM" },
  { href: "/search?type=HALL", label: "القاعات", match: "HALL" },
  { href: "/search?type=DECORATION", label: "التزيين", match: "DECORATION" },
  { href: "/offers", label: "العروض" },
  { href: "/nadeem", label: "نديم", icon: Sparkles },
];

export function Header() {
  const { user, ready, logout } = useAuth();
  const pathname = usePathname();
  const router = useRouter();
  const [menu, setMenu] = useState(false);
  const [counts, setCounts] = useState({ notes: 0, chats: 0 });
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!user) return;
    const load = () =>
      Promise.all([
        api<{ unread: number }>("/api/notifications/unread").catch(() => ({ unread: 0 })),
        api<{ unread: number }>("/api/conversations/unread").catch(() => ({ unread: 0 })),
      ]).then(([n, c]) => setCounts({ notes: n.unread, chats: c.unread }));
    load();
    const t = setInterval(load, 60_000);
    return () => clearInterval(t);
  }, [user, pathname]);

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (!menuRef.current?.contains(e.target as Node)) setMenu(false);
    };
    document.addEventListener("click", close);
    return () => document.removeEventListener("click", close);
  }, []);

  useEffect(() => setMenu(false), [pathname]);

  return (
    <header className="sticky top-0 z-40 border-b border-line/70 bg-white/90 backdrop-blur-xl">
      <div className="container-x flex h-16 items-center gap-4">
        <Logo />
        <nav className="mr-4 hidden items-center gap-1 lg:flex">
          {NAV.map((n) => {
            const Icon = n.icon;
            return (
              <Link
                key={n.href}
                href={n.href}
                className="flex items-center gap-1 rounded-full px-3.5 py-2 text-sm font-bold text-ink-2 transition hover:bg-cream hover:text-ink"
              >
                {Icon && <Icon className="h-4 w-4 text-brass" />}
                {n.label}
              </Link>
            );
          })}
        </nav>
        <div className="flex-1" />
        <Link
          href="/search"
          className="hidden items-center gap-2 rounded-full border border-line bg-cream px-4 py-2 text-sm font-semibold text-ink-3 transition hover:border-line-strong md:flex"
        >
          <Search className="h-4 w-4" />
          ابحث عن مكان…
        </Link>
        {ready && user ? (
          <>
            <IconLink href="/messages" label="الرسائل" count={counts.chats}>
              <MessageCircle className="h-5 w-5" />
            </IconLink>
            <IconLink href="/notifications" label="الإشعارات" count={counts.notes}>
              <Bell className="h-5 w-5" />
            </IconLink>
            <div className="relative" ref={menuRef}>
              <button
                onClick={() => setMenu((m) => !m)}
                className="flex h-10 items-center gap-2 rounded-full border border-line bg-white pl-3 pr-1 transition hover:shadow-[var(--shadow-soft)]"
              >
                <span className="flex h-8 w-8 items-center justify-center rounded-full bg-midnight text-sm font-black text-brass-light">
                  {(user.name || "V").trim().charAt(0)}
                </span>
                <span className="hidden max-w-28 truncate text-sm font-bold sm:block">{user.name || "حسابي"}</span>
              </button>
              {menu && (
                <div className="absolute left-0 top-12 w-56 overflow-hidden rounded-2xl border border-line bg-white py-1.5 shadow-[var(--shadow-card)] animate-fade-up">
                  <MenuItem href="/bookings" icon={CalendarDays} label="حجوزاتي" />
                  <MenuItem href="/favorites" icon={Heart} label="المفضلة" />
                  <MenuItem href="/offers" icon={Tag} label="العروض والكوبونات" />
                  <MenuItem href="/messages" icon={MessageCircle} label="الرسائل" />
                  <MenuItem href="/account" icon={User} label="حسابي" />
                  <div className="my-1 border-t border-line" />
                  <button
                    onClick={async () => {
                      await logout();
                      router.push("/");
                    }}
                    className="flex w-full items-center gap-3 px-4 py-2.5 text-sm font-bold text-danger hover:bg-danger-pale"
                  >
                    <LogOut className="h-4 w-4" />
                    تسجيل الخروج
                  </button>
                </div>
              )}
            </div>
          </>
        ) : ready ? (
          <Link href={`/login?next=${encodeURIComponent(pathname)}`} className="btn btn-primary h-10 px-5 text-sm">
            تسجيل الدخول
          </Link>
        ) : (
          <span className="skeleton h-10 w-28 rounded-full" />
        )}
      </div>
    </header>
  );
}

function IconLink({ href, label, count, children }: { href: string; label: string; count: number; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      aria-label={label}
      className="relative hidden h-10 w-10 items-center justify-center rounded-full text-ink-2 transition hover:bg-cream hover:text-ink sm:flex"
    >
      {children}
      {count > 0 && (
        <span className="num absolute -right-0.5 -top-0.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-rose px-1 text-[10px] font-bold text-white">
          {count > 99 ? "99+" : count}
        </span>
      )}
    </Link>
  );
}

function MenuItem({ href, icon: Icon, label }: { href: string; icon: React.ComponentType<{ className?: string }>; label: string }) {
  return (
    <Link href={href} className="flex items-center gap-3 px-4 py-2.5 text-sm font-bold text-ink-2 hover:bg-cream hover:text-ink">
      <Icon className="h-4 w-4 text-brass-deep" />
      {label}
    </Link>
  );
}
