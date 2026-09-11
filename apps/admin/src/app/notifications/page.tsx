"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { ListRow } from "@/components/ui/list-row";
import { Alert } from "@/components/ui/alert";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { NOTIFICATION_TYPE_LABELS } from "@/lib/constants";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { relativeTimeAr } from "@/lib/dates";
import type { Paginated, TeamNotification } from "@/lib/types";

export default function NotificationsPage() {
  const router = useRouter();
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<TeamNotification> & { unreadCount?: number } | null>(null);
  const [unreadOnly, setUnreadOnly] = useState(true);
  const [typeFilter, setTypeFilter] = useState("");
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [clearOpen, setClearOpen] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await api<Paginated<TeamNotification> & { unreadCount?: number }>(
        `/api/admin/notifications${buildQuery({ unread: unreadOnly ? "true" : undefined, type: typeFilter || undefined, q: qDebounced || undefined, page, pageSize: 20 })}`,
      );
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل الإشعارات");
    } finally {
      setLoading(false);
    }
  }, [unreadOnly, typeFilter, qDebounced, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  async function markRead(n: TeamNotification, e?: React.MouseEvent) {
    e?.stopPropagation();
    if (n.isRead) return;
    try {
      await api(`/api/admin/notifications/${n.id}/read`, { method: "PATCH" });
      setData((prev) =>
        prev
          ? {
              ...prev,
              unreadCount: Math.max(0, (prev.unreadCount ?? 1) - 1),
              items: prev.items.map((item) => (item.id === n.id ? { ...item, isRead: true } : item)),
            }
          : prev,
      );
      toast("تم تعليم الإشعار كمقروء");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function openNotification(n: TeamNotification) {
    if (!n.isRead) {
      await api(`/api/admin/notifications/${n.id}/read`, { method: "PATCH" }).catch(() => undefined);
    }
    if (n.linkUrl) {
      router.push(n.linkUrl);
    } else if (!n.isRead) {
      await load();
    }
  }

  async function markAll() {
    try {
      await api("/api/admin/notifications/read-all", { method: "POST" });
      toast("تم تعليم الكل كمقروء");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function remove(n: TeamNotification, e?: React.MouseEvent) {
    e?.stopPropagation();
    try {
      await api(`/api/admin/notifications/${n.id}`, { method: "DELETE" });
      toast("تم حذف الإشعار");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
    }
  }

  async function clearRead() {
    try {
      const res = await api<{ deleted: number }>("/api/admin/notifications/clear-read", {
        method: "POST",
        body: JSON.stringify({ olderThanDays: 30 }),
      });
      toast(res.deleted ? `تم حذف ${res.deleted} إشعاراً مقروءاً` : "لا إشعارات قديمة للحذف");
      setClearOpen(false);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التنظيف", "error");
    }
  }

  return (
    <PageShell>
      <PageHeader
        title="الإشعارات"
        description={data?.unreadCount ? `${data.unreadCount} جديدة — اضغط للانتقال` : "لا إشعارات جديدة"}
        eyebrow="VIBES Admin"
        onRefresh={load}
        refreshing={loading}
        action={
          <div className="flex flex-wrap gap-2">
            <Button variant="ghost" onClick={() => { setPage(1); setUnreadOnly((v) => !v); }}>
              {unreadOnly ? "عرض الكل" : "الجديدة فقط"}
            </Button>
            {(data?.unreadCount ?? 0) > 0 && (
              <Button variant="ghost" onClick={markAll}>تعليم الكل كمقروء</Button>
            )}
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() =>
                exportCsv(
                  `/api/admin/notifications/export${buildQuery({ unread: unreadOnly ? "true" : undefined, type: typeFilter || undefined, q: qDebounced || undefined })}`,
                  "notifications.csv",
                )
              }
            >
              تصدير CSV
            </Button>
            <Button variant="ghost" onClick={() => setClearOpen(true)}>تنظيف المقروء</Button>
          </div>
        }
      />

      <HelpTip>اضغط على الإشعار لفتح المطلوب — الوقت يظهر بشكل نسبي مثل «منذ ساعة».</HelpTip>

      <Card padded={false} className="overflow-hidden">
        <div className="flex flex-wrap gap-3 border-b border-line p-4">
          <Input placeholder="بحث..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} className="max-w-xs flex-1" />
          <select
            className="input-field max-w-[200px]"
            value={typeFilter}
            onChange={(e) => { setPage(1); setTypeFilter(e.target.value); }}
          >
            <option value="">كل الأنواع</option>
            {Object.entries(NOTIFICATION_TYPE_LABELS).map(([k, v]) => (
              <option key={k} value={k}>{v}</option>
            ))}
          </select>
        </div>
        {error && (
          <div className="border-b border-line p-4">
            <Alert variant="danger">{error}</Alert>
          </div>
        )}
        {loading && (
          <div className="p-5">
            <SkeletonList count={5} />
          </div>
        )}
        {!loading && (
          <div className="list-rows p-2">
            {(data?.items ?? []).map((n) => (
              <ListRow
                key={n.id}
                onClick={() => openNotification(n)}
                className={!n.isRead ? "border-accent/20 bg-accent-soft/40" : ""}
                leading={!n.isRead ? <span className="status-dot status-dot-warning mt-1.5 shrink-0" /> : undefined}
                title={
                  <span className="flex flex-wrap items-center gap-2">
                    {n.title}
                    {"type" in n && n.type && (
                      <Badge variant="muted">{NOTIFICATION_TYPE_LABELS[String(n.type)] ?? String(n.type)}</Badge>
                    )}
                  </span>
                }
                subtitle={n.body}
                meta={<span className="text-xs text-muted-light">{relativeTimeAr(n.createdAt)}</span>}
                badge={
                  <span className="flex items-center gap-2">
                    {!n.isRead && (
                      <Button variant="ghost" className="px-2 py-1 text-xs" onClick={(e) => markRead(n, e)}>
                        مقروء
                      </Button>
                    )}
                    <Button variant="ghost" className="px-2 py-1 text-xs" onClick={(e) => remove(n, e)} aria-label="حذف الإشعار">
                      حذف
                    </Button>
                    {n.linkUrl && <span className="rounded-lg bg-accent-soft px-2.5 py-1 text-xs font-bold text-accent">فتح</span>}
                  </span>
                }
              />
            ))}
          </div>
        )}
        {!loading && !data?.items.length && (
          <EmptyState title="لا توجد إشعارات" description={unreadOnly ? "كل شيء مقروء" : "لم يصل أي إشعار بعد"} />
        )}
        {data && (
          <div className="border-t border-line px-5 py-4">
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="إشعار" onPage={setPage} />
          </div>
        )}
      </Card>

      <ConfirmDialog
        open={clearOpen}
        title="تنظيف الإشعارات المقروءة"
        message="سيتم حذف الإشعارات المقروءة الأقدم من 30 يوماً. الإشعارات الجديدة لن تتأثر."
        confirmLabel="تنظيف"
        danger
        onConfirm={clearRead}
        onClose={() => setClearOpen(false)}
      />
    </PageShell>
  );
}
