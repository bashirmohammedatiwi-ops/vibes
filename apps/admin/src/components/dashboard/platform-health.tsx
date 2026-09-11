import type { DashboardStats } from "@/lib/types";
import { StatStrip } from "@/components/ui/stat-strip";
import { IconChart, IconUsers, IconWallet, IconCalendar } from "@/components/nav-icons";

export function PlatformHealth({ stats }: { stats: DashboardStats }) {
  const publishRate =
    stats.properties > 0
      ? Math.round(((stats.properties - stats.draftProperties) / stats.properties) * 100)
      : 0;
  const confirmRate =
    stats.bookings > 0 ? Math.round((stats.confirmedBookings / stats.bookings) * 100) : 0;

  return (
    <StatStrip
      stats={[
        {
          label: "المستخدمون",
          value: stats.users,
          hint: "إجمالي الحسابات",
          icon: <IconUsers className="h-5 w-5" />,
        },
        {
          label: "إجمالي الحجوزات",
          value: stats.bookings,
          hint: `${stats.confirmedBookings} مؤكد (${confirmRate}%)`,
          icon: <IconCalendar className="h-5 w-5" />,
        },
        {
          label: "دفعات بانتظارك",
          value: stats.pendingPaymentProofs ?? 0,
          hint: stats.pendingPaymentProofs ? "راجع صفحة المدفوعات" : "لا شيء معلّق",
          accent: (stats.pendingPaymentProofs ?? 0) > 0,
          icon: <IconWallet className="h-5 w-5" />,
        },
        {
          label: "نسبة النشر",
          value: `${publishRate}%`,
          hint: `${stats.properties - stats.draftProperties} من ${stats.properties} منشور`,
          icon: <IconChart className="h-5 w-5" />,
        },
      ]}
    />
  );
}
