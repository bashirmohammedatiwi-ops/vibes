"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { Notification, Paged } from "@/lib/types";
import { relTime } from "@/lib/format";
import { EmptyState, PageSkeleton, RequireAuth } from "@/components/require-auth";

export default function NotificationsPage() {
  return (
    <RequireAuth title="سجّل الدخول لعرض إشعاراتك">
      <List />
    </RequireAuth>
  );
}

/** روابط التطبيق (/booking/…، /chat/…، /property/…) → صفحات الموقع. */
function webLink(n: Notification): string | null {
  const l = n.linkUrl ?? "";
  let m = l.match(/\/bookings?\/([\w-]+)/);
  if (m) return `/bookings/${m[1]}`;
  m = l.match(/\/chat\/([\w-]+)/);
  if (m) return `/messages/${m[1]}`;
  m = l.match(/\/property\/([\w-]+)/);
  if (m) return `/go/${m[1]}`;
  if (n.entityType === "booking" && n.entityId) return `/bookings/${n.entityId}`;
  if (n.entityType === "conversation" && n.entityId) return `/messages/${n.entityId}`;
  return null;
}

function List() {
  const [data, setData] = useState<(Paged<Notification> & { unread: number }) | null>(null);
  useEffect(() => {
    api<Paged<Notification> & { unread: number }>("/api/notifications?page=1&pageSize=50")
      .then((d) => {
        setData(d);
        if (d.unread) api("/api/notifications/read", { method: "PATCH" }).catch(() => undefined);
      })
      .catch(() => setData({ items: [], total: 0, page: 1, pageSize: 50, totalPages: 0, unread: 0 }));
  }, []);
  if (!data) return <PageSkeleton />;
  return (
    <div className="container-x max-w-3xl py-8">
      <h1 className="text-2xl font-black md:text-3xl">الإشعارات</h1>
      <div className="mt-5 space-y-2">
        {data.items.length === 0 ? (
          <EmptyState icon="🔔" title="لا إشعارات" text="ستصلك هنا تحديثات حجوزاتك ورسائلك." />
        ) : (
          data.items.map((n) => {
            const href = webLink(n);
            const body = (
              <div className={`card flex gap-3 p-4 ${n.isRead ? "" : "border-brass/40 bg-brass-pale/25"}`}>
                <span className={`mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full ${n.isRead ? "bg-line" : "bg-rose"}`} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <span className="font-black">{n.title}</span>
                    <span className="shrink-0 text-[11px] text-ink-3">{relTime(n.createdAt)}</span>
                  </div>
                  {n.body && <p className="mt-0.5 text-sm text-ink-2">{n.body}</p>}
                </div>
              </div>
            );
            return href ? (
              <Link key={n.id} href={href} className="block transition hover:opacity-90">
                {body}
              </Link>
            ) : (
              <div key={n.id}>{body}</div>
            );
          })
        )}
      </div>
    </div>
  );
}
