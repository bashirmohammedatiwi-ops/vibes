import Link from "next/link";
import type { InboxItem } from "@/components/dashboard/task-inbox";

export function PriorityRail({ items }: { items: InboxItem[] }) {
  const urgent = items.filter((i) => i.urgent).slice(0, 4);
  if (urgent.length === 0) return null;

  return (
    <section className="dash-priority-rail animate-fade-up animate-fade-up-delay-2">
      <div className="dash-priority-rail-label">ابدأ من هنا</div>
      <div className="dash-priority-rail-track">
        {urgent.map((item) => (
          <Link key={item.href} href={item.href} className="dash-priority-chip">
            <span className="dash-priority-chip-count">{item.value}</span>
            <span className="min-w-0 truncate font-semibold">{item.label}</span>
          </Link>
        ))}
      </div>
    </section>
  );
}
