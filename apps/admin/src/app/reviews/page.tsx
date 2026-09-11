"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { RatingStars } from "@/components/ui/detail-card";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { SkeletonList } from "@/components/ui/skeleton";
import { Input, Select, Textarea } from "@/components/ui/input";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { ListRow } from "@/components/ui/list-row";
import { PhoneActions } from "@/components/phone-actions";
import { relativeTimeAr } from "@/lib/dates";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { useToast } from "@/components/ui/toast";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import type { Paginated, ReviewRecord } from "@/lib/types";

export default function ReviewsPage() {
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<ReviewRecord> | null>(null);
  const [visible, setVisible] = useState("");
  const [propertyId, setPropertyId] = useState("");
  const [minRating, setMinRating] = useState("");
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [noteId, setNoteId] = useState<string | null>(null);
  const [adminNote, setAdminNote] = useState("");
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkAction, setBulkAction] = useState<"show" | "hide" | "delete" | null>(null);
  const [bulkLoading, setBulkLoading] = useState(false);

  const [properties, setProperties] = useState<Array<{ id: string; name: string }>>([]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const result = await api<Paginated<ReviewRecord>>(
        `/api/admin/reviews${buildQuery({ visible, minRating, propertyId, q: qDebounced, from, to, page, pageSize: 15 })}`,
      );
      setData(result);
    } finally {
      setLoading(false);
    }
  }, [visible, minRating, propertyId, qDebounced, from, to, page]);

  useEffect(() => {
    api<{ items: Array<{ id: string; name: string }> }>("/api/admin/properties?pageSize=200")
      .then((res) => setProperties(res.items.map((p) => ({ id: p.id, name: p.name }))))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    const pid = new URLSearchParams(window.location.search).get("propertyId");
    if (pid) setPropertyId(pid);
  }, []);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  useEffect(() => {
    setSelected(new Set());
  }, [visible, minRating, propertyId, qDebounced, from, to, page]);

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function setVisibility(id: string, isVisible: boolean, note?: string) {
    try {
      await api(`/api/admin/reviews/${id}/visibility`, {
        method: "PATCH",
        body: JSON.stringify({ isVisible, adminNote: note || undefined }),
      });
      toast(isVisible ? "تم إظهار التقييم" : "تم إخفاء التقييم");
      setNoteId(null);
      setAdminNote("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function remove() {
    if (!deleteId) return;
    try {
      await api(`/api/admin/reviews/${deleteId}`, { method: "DELETE" });
      toast("تم الحذف");
      setDeleteId(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
    }
  }

  async function applyBulk() {
    if (!bulkAction || !selected.size) return;
    setBulkLoading(true);
    try {
      const res = await api<{ updated?: number; deleted?: number }>("/api/admin/reviews/bulk", {
        method: "POST",
        body: JSON.stringify({ ids: [...selected], action: bulkAction }),
      });
      const count = res.updated ?? res.deleted ?? selected.size;
      toast(`تم تنفيذ الإجراء على ${count} تقييم`);
      setBulkAction(null);
      setSelected(new Set());
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التنفيذ", "error");
    } finally {
      setBulkLoading(false);
    }
  }

  return (
    <PageShell>
      <PageHeader
        title="التقييمات"
        description="أظهر المناسب وأخفِ غير المناسب عن العملاء"
        eyebrow="VIBES Admin"
        action={
          <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/reviews/export${buildQuery({ visible, minRating, propertyId, q: qDebounced, from, to })}`, "reviews.csv")}>
            تصدير CSV
          </Button>
        }
      />

      <HelpTip>التقييمات الظاهرة تُعرض في التطبيق — يمكنك إخفاء التقييمات غير المناسبة</HelpTip>

      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4 sm:p-5">
          <FilterChips
            value={visible || "all"}
            onChange={(id) => { setPage(1); setVisible(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "false", label: "مخفية" },
              { id: "true", label: "ظاهرة" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث بالاسم أو التعليق..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Select value={propertyId} onChange={(e) => { setPage(1); setPropertyId(e.target.value); }} className="max-w-[220px]">
              <option value="">كل الأماكن</option>
              {properties.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </Select>
            <Select value={minRating} onChange={(e) => { setPage(1); setMinRating(e.target.value); }} className="max-w-[200px]">
              <option value="">كل التقييمات</option>
              {[5, 4, 3, 2, 1].map((r) => (
                <option key={r} value={r}>{r} نجوم فأكثر</option>
              ))}
            </Select>
            <Input type="date" value={from} onChange={(e) => { setPage(1); setFrom(e.target.value); }} className="max-w-[150px]" title="من" />
            <Input type="date" value={to} onChange={(e) => { setPage(1); setTo(e.target.value); }} className="max-w-[150px]" title="إلى" />
            <Button variant="ghost" onClick={load}>تحديث</Button>
          </PageToolbar>
          {selected.size > 0 && (
            <div className="mt-4 flex flex-wrap items-center gap-2 rounded-xl border border-accent/30 bg-accent-soft/40 px-4 py-3">
              <span className="text-sm font-semibold">{selected.size} محدد</span>
              <Button size="sm" onClick={() => setBulkAction("show")}>إظهار</Button>
              <Button size="sm" variant="ghost" onClick={() => setBulkAction("hide")}>إخفاء</Button>
              <Button size="sm" variant="danger" onClick={() => setBulkAction("delete")}>حذف</Button>
              <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>إلغاء التحديد</Button>
            </div>
          )}
        </div>

        {loading && <div className="p-5"><SkeletonList count={4} /></div>}

        <div className="list-rows p-4">
          {(data?.items ?? []).map((review) => (
            <ListRow
              key={review.id}
              leading={
                <input
                  type="checkbox"
                  checked={selected.has(review.id)}
                  onChange={() => toggleSelect(review.id)}
                  className="mt-1"
                  aria-label="تحديد"
                />
              }
              title={
                review.property?.id ? (
                  <Link href={`/properties/${review.property.id}/edit`} className="text-accent hover:underline">
                    {review.property.name}
                  </Link>
                ) : (
                  review.property?.name
                )
              }
              subtitle={
                <span className="flex flex-wrap items-center gap-2">
                  {review.user?.name ?? review.user?.phone}
                  <RatingStars rating={review.rating} />
                  <PhoneActions phone={review.user?.phone} compact />
                  <span className="text-muted-light">{relativeTimeAr(review.createdAt)}</span>
                </span>
              }
              badge={
                <Badge variant={review.isVisible ? "success" : "muted"}>
                  {review.isVisible ? "ظاهر" : "مخفي"}
                </Badge>
              }
              footer={
                <>
                  <p className="text-sm leading-7 text-ink">{review.comment}</p>
                  {review.adminNote && <p className="text-xs text-muted">ملاحظة الإدارة: {review.adminNote}</p>}
                  <div className="flex flex-wrap gap-2">
                    {review.isVisible ? (
                      <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setNoteId(review.id)}>إخفاء عن العملاء</Button>
                    ) : (
                      <Button className="px-2 py-1 text-xs" onClick={() => setVisibility(review.id, true)}>إظهار للعملاء</Button>
                    )}
                    <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => setDeleteId(review.id)}>حذف</Button>
                  </div>
                  {noteId === review.id && (
                    <div className="space-y-2 rounded-xl border border-line bg-surface p-3">
                      <Textarea placeholder="سبب الإخفاء (اختياري)" value={adminNote} onChange={(e) => setAdminNote(e.target.value)} />
                      <div className="flex gap-2">
                        <Button className="px-2 py-1 text-xs" onClick={() => setVisibility(review.id, false, adminNote)}>تأكيد الإخفاء</Button>
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setNoteId(null)}>إلغاء</Button>
                      </div>
                    </div>
                  )}
                </>
              }
            />
          ))}
        </div>

        {!loading && !data?.items.length && (
          <EmptyState title="لا توجد تقييمات" description="جرّب تغيير الفلاتر" />
        )}

        {data && (
          <div className="border-t border-line px-5 py-4">
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="تقييم" onPage={setPage} />
          </div>
        )}
      </Card>

      <ConfirmDialog
        open={!!deleteId}
        title="حذف التقييم"
        message="حذف هذا التقييم نهائياً؟ لا يمكن التراجع."
        confirmLabel="حذف"
        danger
        onConfirm={remove}
        onClose={() => setDeleteId(null)}
      />

      <ConfirmDialog
        open={!!bulkAction}
        title={bulkAction === "delete" ? "حذف جماعي" : bulkAction === "hide" ? "إخفاء جماعي" : "إظهار جماعي"}
        message={`تطبيق الإجراء على ${selected.size} تقييم؟`}
        confirmLabel="تأكيد"
        danger={bulkAction === "delete"}
        confirmDisabled={bulkLoading}
        onConfirm={applyBulk}
        onClose={() => setBulkAction(null)}
      />
    </PageShell>
  );
}
