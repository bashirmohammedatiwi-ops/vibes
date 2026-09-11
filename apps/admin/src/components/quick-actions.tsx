import Link from "next/link";
import {
  IconBuilding,
  IconCalendar,
  IconPlus,
  IconUsers,
  IconWallet,
} from "@/components/nav-icons";

const actions = [
  { href: "/properties/new", label: "مكان جديد", desc: "مزرعة أو قاعة", Icon: IconPlus, accent: true },
  { href: "/bookings/new", label: "حجز يدوي", desc: "طلب هاتفي", Icon: IconCalendar, accent: true },
  { href: "/bookings", label: "الحجوزات", desc: "تأكيد وإلغاء", Icon: IconCalendar },
  { href: "/payments?pending=1", label: "مراجعة الدفع", desc: "إثباتات بانتظارك", Icon: IconWallet },
  { href: "/calendar", label: "التقويم", desc: "هذا الشهر", Icon: IconCalendar },
  { href: "/providers", label: "المزودون", desc: "موافقة الحساب", Icon: IconUsers },
  { href: "/properties", label: "كل الأماكن", desc: "تعديل ونشر", Icon: IconBuilding },
];

export function QuickActions({ compact }: { compact?: boolean }) {
  if (compact) {
    return (
      <div className="dash-quick-grid">
        {actions.map(({ href, label, Icon, accent }) => (
          <Link key={href} href={href} className={`dash-quick-item ${accent ? "dash-quick-item-accent" : ""}`}>
            <span className="dash-quick-icon">
              <Icon className="h-4 w-4" />
            </span>
            <span className="truncate text-xs font-semibold">{label}</span>
          </Link>
        ))}
      </div>
    );
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {actions.map(({ href, label, desc, Icon, accent }) => (
        <Link
          key={href}
          href={href}
          className={`group card-premium card-interactive flex items-start gap-3.5 p-4 ${
            accent ? "quick-action-accent" : ""
          }`}
        >
          <span
            className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ${
              accent ? "bg-accent text-white" : "bg-accent-soft text-accent"
            }`}
          >
            <Icon className="h-5 w-5" />
          </span>
          <span className="min-w-0 pt-0.5">
            <div className="font-bold text-ink">{label}</div>
            <div className="mt-0.5 text-xs leading-5 text-muted">{desc}</div>
          </span>
        </Link>
      ))}
    </div>
  );
}
