import Link from "next/link";
import type { DashboardStats } from "@/lib/types";
import { formatMoney } from "@/lib/dates";
import {
  IconBuilding,
  IconCalendar,
  IconChart,
  IconUsers,
  IconWallet,
} from "@/components/nav-icons";

export function DashboardKpis({ stats }: { stats: DashboardStats }) {
  const published = stats.properties - stats.draftProperties;
  const publishRate = stats.properties > 0 ? Math.round((published / stats.properties) * 100) : 0;
  const pendingPayments = stats.pendingPaymentProofs ?? 0;

  const items = [
    {
      key: "revenue",
      label: "إيرادات مؤكدة",
      value: formatMoney(stats.totalRevenue),
      hint: `${stats.confirmedBookings} حجز مؤكد`,
      href: "/reports",
      icon: IconWallet,
      color: "teal",
      featured: true,
    },
    {
      key: "monthly",
      label: "حجوزات الشهر",
      value: stats.monthlyBookings,
      hint: `${stats.bookings} إجمالي`,
      href: "/bookings",
      icon: IconCalendar,
      color: "sky",
    },
    {
      key: "properties",
      label: "أماكن منشورة",
      value: published,
      hint: `${stats.featuredProperties} مميز · ${stats.draftProperties} مسودة`,
      href: "/properties",
      icon: IconBuilding,
      color: "violet",
    },
    {
      key: "users",
      label: "المستخدمون",
      value: stats.users,
      hint: "حسابات مسجّلة",
      href: "/users",
      icon: IconUsers,
      color: "indigo",
    },
    {
      key: "payments",
      label: "دفعات معلّقة",
      value: pendingPayments,
      hint: pendingPayments ? "تحتاج مراجعتك" : "لا شيء معلّق",
      href: "/payments?pending=1",
      icon: IconWallet,
      color: "amber",
      alert: pendingPayments > 0,
    },
    {
      key: "publish",
      label: "نسبة النشر",
      value: `${publishRate}%`,
      hint: `${published} من ${stats.properties}`,
      href: "/properties",
      icon: IconChart,
      color: "rose",
    },
  ];

  return (
    <section className="dash-kpi-grid animate-fade-up animate-fade-up-delay-1">
      {items.map((item, i) => {
        const Icon = item.icon;
        return (
          <Link
            key={item.key}
            href={item.href}
            className={`dash-kpi-card ${item.featured ? "dash-kpi-card-featured" : ""} ${item.alert ? "dash-kpi-card-alert" : ""}`}
            style={{ animationDelay: `${i * 0.04}s` }}
          >
            <span className={`dash-kpi-icon icon-chip icon-chip-${item.color}`}>
              <Icon className="h-[18px] w-[18px]" />
            </span>
            <div className="min-w-0 flex-1">
              <div className="dash-kpi-label">{item.label}</div>
              <div className="dash-kpi-value">{item.value}</div>
              <div className="dash-kpi-hint">{item.hint}</div>
            </div>
          </Link>
        );
      })}
    </section>
  );
}
