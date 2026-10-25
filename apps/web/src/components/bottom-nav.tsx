"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { CalendarDays, Home, Search, Sparkles, User } from "lucide-react";

const TABS = [
  { href: "/", label: "الرئيسية", icon: Home },
  { href: "/search", label: "استكشف", icon: Search },
  { href: "/nadeem", label: "نديم", icon: Sparkles },
  { href: "/bookings", label: "حجوزاتي", icon: CalendarDays },
  { href: "/account", label: "حسابي", icon: User },
];

export function BottomNav() {
  const pathname = usePathname();
  if (pathname.startsWith("/messages/") || pathname === "/login") return null;
  return (
    <nav className="fixed inset-x-3 bottom-3 z-40 rounded-3xl border border-white/60 bg-white/95 shadow-[0_10px_30px_-10px_rgb(15_33_56/0.35)] backdrop-blur-xl md:hidden">
      <div className="flex h-16 items-center">
        {TABS.map((t) => {
          const active = t.href === "/" ? pathname === "/" : pathname.startsWith(t.href);
          const Icon = t.icon;
          return (
            <Link key={t.href} href={t.href} className="flex flex-1 flex-col items-center gap-0.5">
              <span
                className={`flex h-8 w-12 items-center justify-center rounded-full transition ${
                  active ? "bg-midnight text-brass-light" : "text-ink-3"
                }`}
              >
                <Icon className="h-5 w-5" />
              </span>
              <span className={`text-[11px] font-bold ${active ? "text-midnight" : "text-ink-3"}`}>{t.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
