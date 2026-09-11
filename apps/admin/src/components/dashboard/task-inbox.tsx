import Link from "next/link";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";
import {
  IconBell,
  IconBuilding,
  IconCalendar,
  IconUsers,
  IconWallet,
} from "@/components/nav-icons";

export type InboxItem = {
  key: string;
  label: string;
  value: number;
  href: string;
  urgent: boolean;
  hint: string;
};

const TASK_ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  payments: IconWallet,
  disputed: IconCalendar,
  properties: IconBuilding,
  providerProps: IconBuilding,
  providers: IconUsers,
  notifications: IconBell,
  drafts: IconBuilding,
  today: IconCalendar,
};

export function TaskInbox({ items }: { items: InboxItem[] }) {
  const urgent = items.filter((i) => i.urgent);
  const routine = items.filter((i) => !i.urgent);

  if (items.length === 0) {
    return (
      <div className="dash-panel">
        <EmptyState
          title="لا مهام معلّقة"
          description="يمكنك إضافة مكان أو مراجعة الحجوزات"
          variant="calendar"
          action={
            <div className="flex flex-wrap justify-center gap-2">
              <Link href="/properties/new">
                <Button>+ مكان جديد</Button>
              </Link>
              <Link href="/bookings">
                <Button variant="ghost">الحجوزات</Button>
              </Link>
            </div>
          }
        />
      </div>
    );
  }

  return (
    <div className="dash-panel dash-panel-flush">
      {urgent.length > 0 && (
        <div className="dash-inbox-section">
          <div className="dash-inbox-section-head">
            <span className="dash-inbox-badge dash-inbox-badge-urgent">عاجل</span>
            <span className="text-xs text-muted">{urgent.length} مهمة</span>
          </div>
          <ul className="dash-inbox-list">
            {urgent.map((item) => (
              <InboxRow key={item.href} item={item} />
            ))}
          </ul>
        </div>
      )}

      {routine.length > 0 && (
        <div className={`dash-inbox-section ${urgent.length > 0 ? "border-t border-line" : ""}`}>
          {urgent.length > 0 && (
            <div className="dash-inbox-section-head">
              <span className="dash-inbox-badge">متابعة</span>
            </div>
          )}
          <ul className="dash-inbox-list">
            {routine.map((item) => (
              <InboxRow key={item.href} item={item} />
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function InboxRow({ item }: { item: InboxItem }) {
  const Icon = TASK_ICONS[item.key] ?? IconBell;
  return (
    <li>
      <Link href={item.href} className={`dash-inbox-row ${item.urgent ? "dash-inbox-row-urgent" : ""}`}>
        <span className={`dash-inbox-icon ${item.urgent ? "dash-inbox-icon-urgent" : ""}`}>
          <Icon className="h-4 w-4" />
        </span>
        <div className="min-w-0 flex-1">
          <div className="font-semibold text-ink">{item.label}</div>
          <div className="mt-0.5 text-xs leading-5 text-muted">{item.hint}</div>
        </div>
        <span className={`dash-inbox-count ${item.urgent ? "dash-inbox-count-urgent" : ""}`}>
          {item.value}
        </span>
      </Link>
    </li>
  );
}
