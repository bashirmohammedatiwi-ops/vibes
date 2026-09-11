"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { SparkChart } from "@/components/ui/spark-chart";
import { LoadingBlock } from "@/components/page-header";
import { Alert } from "@/components/ui/alert";
import { DashboardHero } from "@/components/dashboard/dashboard-hero";
import { DashboardKpis } from "@/components/dashboard/dashboard-kpis";
import { TaskInbox, type InboxItem } from "@/components/dashboard/task-inbox";
import { PriorityRail } from "@/components/dashboard/priority-rail";
import { TodayAgenda } from "@/components/dashboard/today-agenda";
import { ModerationQueue } from "@/components/dashboard/moderation-queue";
import { PlatformHealth } from "@/components/dashboard/platform-health";
import { QuickActions } from "@/components/quick-actions";
import { IconActivity, IconCalendar } from "@/components/nav-icons";
import {
  ACTIVITY_LABELS,
  BOOKING_STATUS_LABELS,
  PROPERTY_TYPE_LABELS,
  activityEntityHref,
} from "@/lib/constants";
import { api } from "@/lib/api";
import { formatMoney, formatMonthShort, relativeTimeAr } from "@/lib/dates";
import type { DashboardStats } from "@/lib/types";

function greeting() {
  const h = new Date().getHours();
  if (h < 12) return "صباح الخير";
  if (h < 17) return "مساء الخير";
  return "مساء النور";
}

function todayLabel() {
  return new Date().toLocaleDateString("ar-IQ", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });
}

function buildInbox(stats: DashboardStats): InboxItem[] {
  return [
    {
      key: "payments",
      label: "دفعات تحتاج موافقتك",
      value: stats.pendingPaymentProofs ?? 0,
      href: "/payments?pending=1",
      urgent: (stats.pendingPaymentProofs ?? 0) > 0,
      hint: "راجع إثبات التحويل واضغط تأكيد",
    },
    {
      key: "disputed",
      label: "حجوزات فيها نزاع",
      value: stats.disputedBookings ?? 0,
      href: "/bookings?status=DISPUTED",
      urgent: (stats.disputedBookings ?? 0) > 0,
      hint: "تحتاج قرار: تأكيد أو إلغاء",
    },
    {
      key: "properties",
      label: "أماكن بانتظار المراجعة",
      value: stats.pendingProperties ?? 0,
      href: "/properties?status=PENDING",
      urgent: (stats.pendingProperties ?? 0) > 0,
      hint: "راجع التفاصيل ثم انشر",
    },
    {
      key: "providerProps",
      label: "أماكن رفعها مزود",
      value: stats.pendingProviderProperties ?? 0,
      href: "/properties?status=PENDING&source=provider",
      urgent: (stats.pendingProviderProperties ?? 0) > 0,
      hint: "مراجعة قبل النشر للعامة",
    },
    {
      key: "providers",
      label: "مزودون بانتظار الموافقة",
      value: stats.pendingProviders ?? 0,
      href: "/providers",
      urgent: (stats.pendingProviders ?? 0) > 0,
      hint: "وافق ليتمكنوا من الرفع",
    },
    {
      key: "notifications",
      label: "إشعارات جديدة",
      value: stats.unreadNotifications ?? 0,
      href: "/notifications",
      urgent: (stats.unreadNotifications ?? 0) > 0,
      hint: "تنبيهات الفريق",
    },
    {
      key: "drafts",
      label: "أماكن مسودة",
      value: stats.draftProperties ?? 0,
      href: "/properties?status=DRAFT",
      urgent: false,
      hint: "أكمل الصور ثم انشر",
    },
    {
      key: "today",
      label: "حجوزات اليوم",
      value: stats.todayCheckIns ?? 0,
      href: "/calendar",
      urgent: false,
      hint: "من جدول الحجوزات",
    },
  ]
    .filter((i) => i.urgent || i.value > 0)
    .sort((a, b) => {
      if (a.urgent !== b.urgent) return a.urgent ? -1 : 1;
      return b.value - a.value;
    });
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  function load() {
    setLoading(true);
    setError(null);
    api<DashboardStats>("/api/admin/dashboard/stats")
      .then(setStats)
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    load();
    const timer = setInterval(() => {
      if (document.visibilityState === "visible") load();
    }, 60_000);
    return () => clearInterval(timer);
  }, []);

  const inbox = useMemo(() => (stats ? buildInbox(stats) : []), [stats]);

  const urgentTotal = useMemo(
    () =>
      (stats?.unreadNotifications ?? 0) +
      (stats?.pendingPaymentProofs ?? 0) +
      (stats?.disputedBookings ?? 0) +
      (stats?.pendingProperties ?? 0) +
      (stats?.pendingProviders ?? 0),
    [stats],
  );

  const subtitle =
    urgentTotal > 0
      ? "راجع المهام العاجلة أولاً، ثم تابع الحجوزات والتقارير."
      : "لا مهام عاجلة — وقت مناسب لإضافة أماكن أو مراجعة الأداء.";

  return (
    <div className="dash-shell">
      {error && <Alert variant="danger" className="animate-fade-up">{error}</Alert>}
      {loading && !stats && <LoadingBlock />}

      {stats && (
        <>
          <DashboardHero
            greeting={greeting()}
            dateLabel={todayLabel()}
            urgentTotal={urgentTotal}
            loading={loading}
            onRefresh={load}
            subtitle={subtitle}
          />

          <DashboardKpis stats={stats} />

          <PlatformHealth stats={stats} />

          <PriorityRail items={inbox} />

          <div className="dash-main-grid">
            <div className="dash-main-primary space-y-6">
              <section>
                <div className="dash-section-head">
                  <div>
                    <h2 className="dash-section-title">مركز العمليات</h2>
                    <p className="dash-section-desc">المهام التي تحتاج إجراءك</p>
                  </div>
                </div>
                <TaskInbox items={inbox} />
              </section>

              <ModerationQueue onChanged={load} />
            </div>

            <aside className="dash-main-aside space-y-5">
              <TodayAgenda />

              <div className="dash-panel">
                <div className="dash-panel-head">
                  <div>
                    <h2 className="dash-panel-title">اختصارات</h2>
                    <p className="dash-panel-desc">وصول سريع</p>
                  </div>
                </div>
                <QuickActions compact />
              </div>
            </aside>
          </div>

          {(stats.monthlyRevenue?.length ?? 0) > 0 && (
            <section className="dash-analytics">
              <div className="dash-section-head">
                <div>
                  <h2 className="dash-section-title">تحليل الأداء</h2>
                  <p className="dash-section-desc">آخر 6 أشهر</p>
                </div>
                <Link href="/reports" className="text-xs font-bold text-accent hover:underline">
                  التقارير الكاملة
                </Link>
              </div>
              <div className="dash-analytics-grid">
                <Card className="dash-chart-card">
                  <h3 className="dash-chart-title">الإيرادات</h3>
                  <SparkChart
                    data={stats.monthlyRevenue.map((row) => ({
                      label: formatMonthShort(row.month),
                      value: row.revenue,
                    }))}
                    formatValue={(v) => formatMoney(v)}
                  />
                </Card>
                <Card className="dash-chart-card">
                  <h3 className="dash-chart-title">عدد الحجوزات</h3>
                  <SparkChart
                    data={stats.monthlyRevenue.map((row) => ({
                      label: formatMonthShort(row.month),
                      value: row.bookings,
                    }))}
                  />
                </Card>
                <Card className="dash-chart-card dash-chart-card-breakdown">
                  <h3 className="dash-chart-title">الأماكن حسب النوع</h3>
                  <div className="space-y-3">
                    {stats.propertiesByType.map((row) => {
                      const max = Math.max(...stats.propertiesByType.map((r) => r.count), 1);
                      const pct = (row.count / max) * 100;
                      return (
                        <div key={row.type}>
                          <div className="mb-1 flex justify-between text-sm">
                            <span className="font-medium">{PROPERTY_TYPE_LABELS[row.type]}</span>
                            <Badge>{row.count}</Badge>
                          </div>
                          <div className="dash-bar-track">
                            <div className="dash-bar-fill" style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </Card>
                {(stats.propertiesByProvince?.length ?? 0) > 0 && (
                  <Card className="dash-chart-card dash-chart-card-breakdown">
                    <h3 className="dash-chart-title">الأماكن حسب المحافظة</h3>
                    <div className="space-y-3">
                      {stats.propertiesByProvince.slice(0, 8).map((row) => {
                        const max = Math.max(...stats.propertiesByProvince.map((r) => r.count), 1);
                        const pct = (row.count / max) * 100;
                        return (
                          <div key={row.name}>
                            <div className="mb-1 flex justify-between text-sm">
                              <span className="font-medium">{row.name}</span>
                              <Badge>{row.count}</Badge>
                            </div>
                            <div className="dash-bar-track">
                              <div className="dash-bar-fill" style={{ width: `${pct}%` }} />
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </Card>
                )}
              </div>
            </section>
          )}

          <div className="dash-feed-grid">
            <Card padded={false} className="dash-feed-card overflow-hidden">
              <div className="dash-feed-head">
                <div className="flex items-center gap-2.5">
                  <span className="dash-panel-icon">
                    <IconCalendar className="h-4 w-4" />
                  </span>
                  <h2 className="font-bold">آخر الحجوزات</h2>
                </div>
                <Link href="/bookings" className="text-xs font-bold text-accent hover:underline">
                  عرض الكل
                </Link>
              </div>
              <div>
                {stats.recentBookings.map((b, i) => (
                  <Link
                    key={b.id}
                    href={`/bookings/${b.id}`}
                    className={`dash-feed-row ${i > 0 ? "border-t border-line" : ""}`}
                  >
                    <div className="flex min-w-0 items-center gap-3">
                      <span
                        className={`status-dot ${b.status === "CONFIRMED" || b.status === "COMPLETED" ? "status-dot-success" : b.status === "DISPUTED" ? "status-dot-danger" : "status-dot-warning"}`}
                      />
                      <div className="min-w-0">
                        <div className="truncate font-semibold">{b.property?.name ?? "—"}</div>
                        <div className="text-xs text-muted">{b.user?.name ?? b.user?.phone}</div>
                      </div>
                    </div>
                    <div className="ms-3 shrink-0 text-left">
                      <Badge variant={b.status === "CONFIRMED" || b.status === "COMPLETED" ? "success" : "warning"}>
                        {BOOKING_STATUS_LABELS[b.status] ?? b.status}
                      </Badge>
                      <div className="mt-1 text-xs font-bold">{formatMoney(b.totalPrice)}</div>
                    </div>
                  </Link>
                ))}
                {!stats.recentBookings.length && (
                  <p className="px-5 py-10 text-center text-sm text-muted">لا حجوزات بعد</p>
                )}
              </div>
            </Card>

            <Card padded={false} className="dash-feed-card overflow-hidden">
              <div className="dash-feed-head">
                <div className="flex items-center gap-2.5">
                  <span className="dash-panel-icon">
                    <IconActivity className="h-4 w-4" />
                  </span>
                  <h2 className="font-bold">نشاط الفريق</h2>
                </div>
                <Link href="/activity" className="text-xs font-bold text-accent hover:underline">
                  السجل
                </Link>
              </div>
              <div className="timeline px-5 py-4">
                {stats.recentActivities.slice(0, 6).map((a, i) => {
                  const href = activityEntityHref(a.entityType, a.entityId);
                  const inner = (
                    <>
                      <span className={`timeline-dot ${i === 0 ? "timeline-dot-urgent" : ""}`} />
                      <div className="min-w-0 flex-1 pb-1">
                        <div className="font-semibold">{ACTIVITY_LABELS[a.action] ?? a.action}</div>
                        <div className="text-xs text-muted">
                          {a.user?.name ?? a.user?.phone} · {relativeTimeAr(a.createdAt)}
                        </div>
                      </div>
                    </>
                  );
                  return href ? (
                    <Link key={a.id} href={href} className="timeline-item transition hover:opacity-80">
                      {inner}
                    </Link>
                  ) : (
                    <div key={a.id} className="timeline-item">
                      {inner}
                    </div>
                  );
                })}
                {!stats.recentActivities.length && (
                  <p className="py-6 text-center text-sm text-muted">لا نشاط بعد</p>
                )}
              </div>
            </Card>
          </div>
        </>
      )}
    </div>
  );
}
