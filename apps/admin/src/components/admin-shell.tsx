"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, buildQuery, clearToken, getToken, getUserRole, isAdmin, syncAuthCookies } from "@/lib/api";
import { USER_ROLE_LABELS } from "@/lib/constants";
import { BrandLogo } from "@/components/brand-logo";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { GlobalSearch, SearchButton } from "@/components/global-search";
import { ScrollRestorer } from "@/components/scroll-restorer";
import { ThemeToggle } from "@/components/theme-toggle";
import { Fab } from "@/components/ui/fab";
import { IconBell, IconLogout, IconPlus, NAV_COLORS, NAV_ICONS } from "@/components/nav-icons";

type NavLink = { href: string; label: string; badge?: boolean; adminOnly?: boolean };

const sections: Array<{ title: string; links: NavLink[] }> = [
  {
    title: "اليوم",
    links: [
      { href: "/", label: "الرئيسية" },
      { href: "/notifications", label: "الإشعارات", badge: true },
    ],
  },
    {
      title: "الحجوزات",
      links: [
        { href: "/bookings", label: "الحجوزات" },
        { href: "/calendar", label: "التقويم" },
        { href: "/disputes", label: "النزاعات" },
        { href: "/conversations", label: "المحادثات" },
        { href: "/refunds", label: "الإلغاء والاسترداد" },
        { href: "/offers", label: "عروض الأسعار" },
      ],
    },
    {
      title: "المالية",
      links: [
        { href: "/payments", label: "المدفوعات" },
        { href: "/invoices", label: "الفواتير" },
        { href: "/coupons", label: "الكوبونات", adminOnly: true },
      ],
    },
    {
      title: "المحتوى",
      links: [
        { href: "/properties", label: "الأماكن" },
        { href: "/amenities", label: "المزايا", adminOnly: true },
        { href: "/map", label: "الخريطة" },
        { href: "/banners", label: "البانرات" },
        { href: "/spotlights", label: "أماكن مميزة" },
        { href: "/reviews", label: "التقييمات" },
        { href: "/collections", label: "القوائم" },
        { href: "/social", label: "التجارب" },
      ],
    },
  {
    title: "الأشخاص",
    links: [
      { href: "/providers", label: "المزودون" },
      { href: "/users", label: "المستخدمون", adminOnly: true },
      { href: "/locations", label: "المدن", adminOnly: true },
    ],
  },
  {
    title: "المتابعة",
    links: [
      { href: "/reports", label: "التقارير" },
      { href: "/analytics", label: "التحليلات" },
      { href: "/activity", label: "سجل النشاط" },
      { href: "/settings", label: "الإعدادات", adminOnly: true },
      { href: "/integrations", label: "التكاملات" },
    ],
  },
];

const providerSections: Array<{ title: string; links: NavLink[] }> = [
  {
    title: "بوابة المالك",
    links: [
      { href: "/provider", label: "نظرة عامة" },
      { href: "/provider/bookings", label: "حجوزاتي" },
      { href: "/profile", label: "ملفي" },
    ],
  },
];

const mobileTabs = [
  { href: "/", label: "الرئيسية" },
  { href: "/bookings", label: "الحجوزات" },
  { href: "/payments", label: "الدفع" },
  { href: "/properties", label: "الأماكن" },
];

function isActivePath(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  return pathname === href || pathname.startsWith(`${href}/`);
}

function pageTitle(pathname: string) {
  if (pathname === "/provider/bookings") return "حجوزاتي";
  if (pathname.startsWith("/provider/properties/")) return "إدارة المكان";
  if (pathname === "/provider") return "بوابة المالك";
  if (pathname === "/coupons") return "الكوبونات";
  if (pathname === "/amenities") return "مزايا الأماكن";
  if (pathname === "/") return "الرئيسية";
  if (pathname.startsWith("/properties/new")) return "مكان جديد";
  if (pathname.startsWith("/properties/") && pathname.endsWith("/edit")) return "تعديل المكان";
  if (pathname.startsWith("/bookings/new")) return "حجز يدوي";
  if (pathname.startsWith("/bookings/")) return "تفاصيل الحجز";
  if (pathname.startsWith("/providers/")) return "ملف المزود";
  if (pathname === "/disputes") return "النزاعات";
  if (pathname === "/conversations") return "المحادثات";
  if (pathname === "/invoices") return "الفواتير";
  if (pathname === "/offers") return "عروض الأسعار";
  if (pathname === "/collections") return "القوائم";
  if (pathname === "/social") return "التجارب";
  if (pathname === "/profile") return "ملفي";
  if (pathname === "/integrations") return "التكاملات";
  if (pathname === "/map") return "الخريطة";
  if (pathname.startsWith("/users/")) return "ملف المستخدم";
  const all = sections.flatMap((s) => s.links);
  const hit = all.find((l) => isActivePath(pathname, l.href) && l.href !== "/");
  return hit?.label ?? "لوحة التحكم";
}

function SidebarContent({
  pathname,
  unread,
  admin,
  provider,
  role,
  onNavigate,
  onLogout,
}: {
  pathname: string;
  unread: number;
  admin: boolean;
  provider: boolean;
  role: string | null;
  onNavigate?: () => void;
  onLogout: () => void;
}) {
  const initial = role ? (USER_ROLE_LABELS[role]?.[0] ?? "V") : "V";

  return (
    <div className="relative flex h-full flex-col">
      <div className="sidebar-header px-1 pt-1">
        <BrandLogo size="md" variant="light" />
      </div>

      {!provider && (
        <Link href="/properties/new" className="sidebar-cta" onClick={onNavigate}>
          <IconPlus className="h-4 w-4" />
          إضافة مكان
        </Link>
      )}

      <nav className="soft-scroll min-h-0 flex-1 space-y-6 overflow-y-auto pb-4">
        {(provider ? providerSections : sections).map((section) => {
          const links = section.links.filter((link) => !("adminOnly" in link && link.adminOnly) || admin);
          if (!links.length) return null;
          return (
            <div key={section.title}>
              <div className="section-label mb-2.5 px-3">{section.title}</div>
              <div className="space-y-0.5">
                {links.map((link) => {
                  const active = isActivePath(pathname, link.href);
                  const Icon = NAV_ICONS[link.href];
                  const color = NAV_COLORS[link.href] ?? "indigo";
                  return (
                    <Link
                      key={link.href}
                      href={link.href}
                      onClick={onNavigate}
                      className={`nav-item ${active ? "nav-item-active" : ""}`}
                    >
                      <span className={`nav-icon-wrap icon-chip icon-chip-${color}`}>
                        {Icon ? <Icon className="h-[17px] w-[17px]" /> : null}
                      </span>
                      <span className="flex-1">{link.label}</span>
                      {link.badge && unread > 0 && (
                        <span className="nav-badge rounded-full px-2 py-0.5 text-[10px]">
                          {unread > 99 ? "99+" : unread}
                        </span>
                      )}
                    </Link>
                  );
                })}
              </div>
            </div>
          );
        })}
      </nav>

      <div className="sidebar-footer mt-auto space-y-2 border-t pt-4">
        {role && (
          <div className="sidebar-user">
            <span className="sidebar-user-avatar" aria-hidden>{initial}</span>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-bold text-ink">{USER_ROLE_LABELS[role] ?? role}</div>
              <div className="text-[11px] text-muted">{provider ? "مالك مكان" : "فريق VIBES"}</div>
            </div>
          </div>
        )}
        <Link href="/profile" className="nav-item" onClick={onNavigate}>
          <span className="nav-icon-wrap icon-chip icon-chip-indigo">
            <svg className="h-[17px] w-[17px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75">
              <circle cx="12" cy="8" r="4" />
              <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" strokeLinecap="round" />
            </svg>
          </span>
          <span>ملفي</span>
        </Link>
        <button type="button" className="nav-item w-full" onClick={onLogout}>
          <span className="nav-icon-wrap icon-chip icon-chip-rose">
            <IconLogout className="h-[17px] w-[17px]" />
          </span>
          <span>تسجيل الخروج</span>
        </button>
      </div>
    </div>
  );
}

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [unread, setUnread] = useState(0);
  const [menuOpen, setMenuOpen] = useState(false);
  const [logoutOpen, setLogoutOpen] = useState(false);
  const [admin, setAdmin] = useState(false);
  const [isProvider, setIsProvider] = useState(false);
  const [role, setRole] = useState<string | null>(null);
  const [today, setToday] = useState("");

  useEffect(() => {
    setToday(
      new Intl.DateTimeFormat("ar-IQ", { weekday: "long", day: "numeric", month: "long" }).format(new Date()),
    );
  }, []);

  useEffect(() => {
    syncAuthCookies();
    setAdmin(isAdmin());
    const currentRole = getUserRole();
    setIsProvider(currentRole === "PROVIDER");
    setRole(currentRole);
  }, [pathname]);

  useEffect(() => {
    if (pathname !== "/login" && !getToken()) {
      router.replace("/login");
    }
  }, [pathname, router]);

  // Providers live in the portal: keep them out of staff routes.
  useEffect(() => {
    if (pathname === "/login") return;
    if (getUserRole() === "PROVIDER" && !pathname.startsWith("/provider") && pathname !== "/profile") {
      router.replace("/provider");
    }
  }, [pathname, router]);

  useEffect(() => {
    setMenuOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (pathname === "/login" || !getToken()) return;
    const poll = () => {
      api<{ unreadCount?: number }>(`/api/admin/notifications${buildQuery({ pageSize: 1 })}`)
        .then((d) => setUnread(d.unreadCount ?? 0))
        .catch(() => undefined);
    };
    poll();
    const id = setInterval(poll, 60_000);
    return () => clearInterval(id);
  }, [pathname]);

  if (pathname === "/login") {
    return <>{children}</>;
  }

  return (
    <div className="app-canvas min-h-screen">
      <ScrollRestorer />
      <GlobalSearch />

      <aside
        className={`sidebar-bloom fixed inset-y-0 right-0 z-50 flex w-[17rem] flex-col p-5 transition-transform lg:translate-x-0 xl:w-[18rem] ${
          menuOpen ? "translate-x-0" : "translate-x-full lg:translate-x-0"
        }`}
      >
        <SidebarContent
          pathname={pathname}
          unread={unread}
          admin={admin}
          provider={isProvider}
          role={role}
          onNavigate={() => setMenuOpen(false)}
          onLogout={() => setLogoutOpen(true)}
        />
      </aside>

      {menuOpen && (
        <button
          type="button"
          className="sidebar-overlay fixed inset-0 z-40 lg:hidden"
          onClick={() => setMenuOpen(false)}
          aria-label="إغلاق القائمة"
        />
      )}

      <div className="relative z-10 lg:mr-[17rem] xl:mr-[18rem]">
        <header className="topbar topbar-bloom sticky top-0 z-30 flex items-center gap-3 px-4 py-2.5 lg:px-6">
          <Link href="/" className="flex shrink-0 items-center gap-2 lg:hidden">
            <BrandLogo size="sm" showWordmark={false} variant="light" />
          </Link>

          <div className="hidden min-w-0 lg:block">
            <div className="flex items-center gap-2">
              <div className="topbar-eyebrow">{isProvider ? "VIBES · بوابة المالك" : "VIBES · Admin"}</div>
              {today && (
                <span className="topbar-date-chip hidden xl:inline-flex">{today}</span>
              )}
            </div>
            <div className="topbar-title">{pageTitle(pathname)}</div>
          </div>

          <div className="hidden flex-1 justify-center lg:flex">
            <SearchButton />
          </div>

          <div className="ms-auto flex items-center gap-2">
            <div className="lg:hidden">
              <SearchButton compact />
            </div>
            <ThemeToggle />
            <Link href="/notifications" className="topbar-icon-btn relative" aria-label="الإشعارات">
              <IconBell className="h-[18px] w-[18px]" />
              {unread > 0 && (
                <span className="absolute -top-1 -left-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1 text-[9px] font-bold text-white">
                  {unread > 99 ? "99+" : unread}
                </span>
              )}
            </Link>
            {!isProvider && (
              <Link href="/properties/new" className="btn-primary hidden h-10 items-center gap-1.5 rounded-xl px-4 text-sm font-semibold sm:inline-flex">
                <IconPlus className="h-4 w-4" />
                مكان جديد
              </Link>
            )}
            <button
              type="button"
              className="topbar-icon-btn relative px-3 text-sm font-semibold lg:hidden"
              onClick={() => setMenuOpen((v) => !v)}
              aria-label="القائمة"
            >
              {menuOpen ? "✕" : "☰"}
            </button>
          </div>
        </header>

        <main key={pathname} className="page-enter relative mx-auto max-w-[1480px] px-4 pb-28 pt-5 lg:px-8 lg:pb-10 lg:pt-6">
          {children}
        </main>
      </div>

      {!isProvider && !pathname.startsWith("/properties/new") && (
        <Fab href="/properties/new" label="إضافة مكان جديد">
          <IconPlus className="h-5 w-5" />
        </Fab>
      )}

      <nav className="mobile-tab-bar fixed inset-x-0 bottom-0 z-40 px-2 py-2 lg:hidden">
        <div className="grid grid-cols-5 gap-0.5">
          {mobileTabs.map((tab) => {
            const active = isActivePath(pathname, tab.href);
            const Icon = NAV_ICONS[tab.href];
            return (
              <Link key={tab.href} href={tab.href} className={`mobile-tab ${active ? "mobile-tab-active" : ""}`}>
                <span className="mobile-tab-icon">{Icon ? <Icon className="h-4 w-4" /> : null}</span>
                {tab.label}
              </Link>
            );
          })}
          <button type="button" onClick={() => setMenuOpen(true)} className="mobile-tab">
            <span className="mobile-tab-icon">
              <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75">
                <path d="M4 7h16M4 12h16M4 17h16" strokeLinecap="round" />
              </svg>
            </span>
            المزيد
          </button>
        </div>
      </nav>

      <ConfirmDialog
        open={logoutOpen}
        title="تسجيل الخروج"
        message="الخروج من لوحة التحكم؟"
        confirmLabel="خروج"
        danger
        onConfirm={() => {
          clearToken();
          setLogoutOpen(false);
          router.replace("/login");
        }}
        onClose={() => setLogoutOpen(false)}
      />
    </div>
  );
}
