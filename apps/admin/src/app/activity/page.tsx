"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { FilterPanel } from "@/components/ui/page-toolbar";
import { SkeletonList } from "@/components/ui/skeleton";
import { Input, Select } from "@/components/ui/input";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import {
  ACTIVITY_LABELS,
  BOOKING_STATUS_LABELS,
  BULK_ACTION_LABELS,
  ENTITY_TYPE_LABELS,
  PAYMENT_STATUS_LABELS,
  PROPERTY_STATUS_LABELS,
  PROPERTY_TYPE_LABELS,
  USER_ROLE_LABELS,
  activityEntityHref,
} from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { relativeTimeAr } from "@/lib/dates";
import type { ActivityRecord, Paginated, PropertyStatus, PropertyType } from "@/lib/types";

function formatMetadata(action: string, metadata?: Record<string, unknown> | null) {
  if (!metadata || !Object.keys(metadata).length) return null;
  const parts: string[] = [];
  if (metadata.name) parts.push(String(metadata.name));
  if (typeof metadata.type === "string") {
    const typeLabel = PROPERTY_TYPE_LABELS[metadata.type as PropertyType];
    if (typeLabel) parts.push(typeLabel);
  }
  if (typeof metadata.status === "string") {
    const statusLabel =
      BOOKING_STATUS_LABELS[metadata.status] ??
      PROPERTY_STATUS_LABELS[metadata.status as PropertyStatus] ??
      PAYMENT_STATUS_LABELS[metadata.status] ??
      USER_ROLE_LABELS[metadata.status] ??
      metadata.status;
    parts.push(`الحالة: ${statusLabel}`);
  }
  if (metadata.reason) parts.push(String(metadata.reason));
  if (action === "property.bulk" && metadata.action) {
    parts.push(`إجراء: ${BULK_ACTION_LABELS[String(metadata.action)] ?? String(metadata.action)}`);
  }
  if (typeof metadata.count === "number") parts.push(`${metadata.count} عنصر`);
  return parts.length ? parts.join(" · ") : null;
}

export default function ActivityPage() {
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<ActivityRecord> | null>(null);
  const [page, setPage] = useState(1);
  const [action, setAction] = useState("");
  const [entityType, setEntityType] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const result = await api<Paginated<ActivityRecord>>(
        `/api/admin/activities${buildQuery({ page, pageSize: 30, action, entityType, from, to, q: q || undefined })}`,
      );
      setData(result);
    } finally {
      setLoading(false);
    }
  }, [page, action, entityType, from, to, q]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  const actionOptions = [...new Set(Object.keys(ACTIVITY_LABELS))];

  return (
    <PageShell>
      <PageHeader
        title="سجل النشاط"
        description="كل إجراءات الفريق — اضغط على أي سطر للانتقال"
        eyebrow="VIBES Admin"
        action={
          <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/activities/export${buildQuery({ action, entityType, from, to })}`, "activity.csv")}>
            تصدير CSV
          </Button>
        }
      />

      <HelpTip>استخدم الفلاتر للبحث عن إجراء معيّن أو فترة زمنية</HelpTip>

      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4 sm:p-5">
          <FilterPanel open>
            <Select value={action} onChange={(e) => { setPage(1); setAction(e.target.value); }}>
              <option value="">كل الإجراءات</option>
              {actionOptions.map((a) => (
                <option key={a} value={a}>{ACTIVITY_LABELS[a] ?? a}</option>
              ))}
            </Select>
            <Select value={entityType} onChange={(e) => { setPage(1); setEntityType(e.target.value); }}>
              <option value="">كل الأنواع</option>
              {Object.entries(ENTITY_TYPE_LABELS).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </Select>
            <Input type="date" value={from} onChange={(e) => { setPage(1); setFrom(e.target.value); }} title="من" />
            <Input type="date" value={to} onChange={(e) => { setPage(1); setTo(e.target.value); }} title="إلى" />
            <Input placeholder="بحث (هاتف، ID، إجراء)..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} className="min-w-[200px] flex-1" />
          </FilterPanel>
          <div className="mt-3">
            <Button variant="ghost" onClick={load}>تحديث</Button>
          </div>
        </div>

        {loading && <div className="p-5"><SkeletonList count={6} /></div>}

        <div className="timeline px-5 py-4">
          {(data?.items ?? []).map((item, i) => {
            const href = activityEntityHref(item.entityType, item.entityId);
            const meta = formatMetadata(item.action, item.metadata);
            const inner = (
              <>
                <span className={`timeline-dot ${i === 0 ? "timeline-dot-urgent" : ""}`} />
                <div className="min-w-0 flex-1">
                  <div className="font-semibold text-ink">{ACTIVITY_LABELS[item.action] ?? item.action}</div>
                  <div className="mt-0.5 text-sm text-muted">
                    {item.user?.name ?? item.user?.phone}
                    {item.user?.id && (
                      <>
                        {" "}
                        <Link href={`/users/${item.user.id}`} className="font-semibold text-accent underline" onClick={(e) => e.stopPropagation()}>
                          ملف
                        </Link>
                      </>
                    )}
                    {item.entityType && (
                      <span className="text-muted-light"> — {ENTITY_TYPE_LABELS[item.entityType] ?? item.entityType}</span>
                    )}
                  </div>
                  {meta && <div className="mt-1 text-xs text-muted-light">{meta}</div>}
                </div>
                <Badge variant="muted">{relativeTimeAr(item.createdAt)}</Badge>
              </>
            );
            const cls = "timeline-item transition hover:opacity-85";
            return href ? (
              <Link key={item.id} href={href} className={cls}>
                {inner}
              </Link>
            ) : (
              <div key={item.id} className={cls}>
                {inner}
              </div>
            );
          })}
        </div>

        {!loading && !(data?.items ?? []).length && (
          <EmptyState title="لا يوجد نشاط" description="جرّب تغيير الفلاتر أو نطاق التاريخ" />
        )}

        {data && (
          <div className="border-t border-line px-5 py-4">
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="حركة" onPage={setPage} />
          </div>
        )}
      </Card>
    </PageShell>
  );
}
