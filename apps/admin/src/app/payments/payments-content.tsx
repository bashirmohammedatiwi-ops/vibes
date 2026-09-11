"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { ImagePreview } from "@/components/image-preview";
import { PhoneActions } from "@/components/phone-actions";
import { Input, Select, Textarea } from "@/components/ui/input";
import { useToast } from "@/components/ui/toast";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell, ContentPanel, ContentToolbar, ContentFooter } from "@/components/page-shell";
import { PageToolbar, FilterPanel } from "@/components/ui/page-toolbar";
import { ListRow } from "@/components/ui/list-row";
import { Alert } from "@/components/ui/alert";
import { SkeletonList } from "@/components/ui/skeleton";
import { PaymentInstructions } from "@/components/payment-instructions";
import { PAYMENT_METHOD_LABELS, PAYMENT_STATUS_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { formatMoney, relativeTimeAr } from "@/lib/dates";
import type { Paginated, PaymentRecord } from "@/lib/types";

type ReviewDraft = { adminNote: string; transactionRef: string };

export default function PaymentsContent() {
  const searchParams = useSearchParams();
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<PaymentRecord> & { pendingProof?: number } | null>(null);
  const [status, setStatus] = useState("");
  const [method, setMethod] = useState("");
  const [hasProof, setHasProof] = useState(() => (searchParams.get("pending") === "1" ? "true" : ""));
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reviewId, setReviewId] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Record<string, ReviewDraft>>({});
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [rejectId, setRejectId] = useState<string | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkLoading, setBulkLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await api<Paginated<PaymentRecord> & { pendingProof?: number }>(
        `/api/admin/payments${buildQuery({ status, method, hasProof, q: qDebounced, from, to, page, pageSize: 15 })}`,
      );
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل المدفوعات");
    } finally {
      setLoading(false);
    }
  }, [status, method, hasProof, qDebounced, from, to, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  useEffect(() => {
    if (searchParams.get("pending") === "1") {
      setHasProof("true");
      setStatus("PENDING");
      setPage(1);
    }
  }, [searchParams]);

  function getDraft(id: string): ReviewDraft {
    return drafts[id] ?? { adminNote: "", transactionRef: "" };
  }

  function setDraft(id: string, patch: Partial<ReviewDraft>) {
    setDrafts((prev) => ({ ...prev, [id]: { ...getDraft(id), ...patch } }));
  }

  async function review(id: string, nextStatus: string, note?: string) {
    const draft = getDraft(id);
    const adminNote = (note ?? draft.adminNote).trim();
    if (nextStatus === "FAILED" && !adminNote) {
      toast("اكتب ملاحظة قصيرة قبل المتابعة", "error");
      return;
    }
    try {
      await api(`/api/admin/payments/${id}/review`, {
        method: "PATCH",
        body: JSON.stringify({
          status: nextStatus,
          adminNote: adminNote || undefined,
          transactionRef: draft.transactionRef || undefined,
        }),
      });
      toast(nextStatus === "PAID" ? "تم قبول الدفع — الحجز مؤكد تلقائياً" : "تم رفض الدفع");
      setReviewId(null);
      setRejectId(null);
      setRejectNote("");
      setDrafts((prev) => {
        const next = { ...prev };
        delete next[id];
        return next;
      });
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر المراجعة", "error");
    }
  }

  useEffect(() => {
    setSelected(new Set());
  }, [status, method, hasProof, qDebounced, from, to, page]);

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function bulkApprove() {
    const ids = [...selected].filter((id) => {
      const p = data?.items.find((x) => x.id === id);
      return p?.status === "PENDING" && p?.proofUrl;
    });
    if (!ids.length) {
      toast("اختر دفعات معلقة لها إثبات", "error");
      return;
    }
    setBulkLoading(true);
    try {
      const res = await api<{ updated: number; failed: number }>("/api/admin/payments/bulk", {
        method: "POST",
        body: JSON.stringify({ ids, status: "PAID" }),
      });
      toast(`تم تأكيد ${res.updated} دفعة${res.failed ? ` — فشل ${res.failed}` : ""}`);
      setSelected(new Set());
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التأكيد الجماعي", "error");
    } finally {
      setBulkLoading(false);
    }
  }

  function chipValue() {
    if (hasProof === "true" || status === "PENDING") return "pending";
    if (status === "PAID") return "paid";
    if (status === "FAILED") return "failed";
    if (status === "REFUNDED") return "refunded";
    return "all";
  }

  function applyChip(id: string) {
    setPage(1);
    if (id === "pending") {
      setHasProof("true");
      setStatus("PENDING");
    } else if (id === "paid") {
      setHasProof("");
      setStatus("PAID");
    } else if (id === "failed") {
      setHasProof("");
      setStatus("FAILED");
    } else if (id === "refunded") {
      setHasProof("");
      setStatus("REFUNDED");
    } else {
      setHasProof("");
      setStatus("");
    }
  }

  return (
    <PageShell>
      <PageHeader
        title="المدفوعات"
        description={data?.pendingProof ? `${data.pendingProof} دفعة تحتاج موافقتك` : "لا توجد دفعات بانتظار المراجعة"}
        eyebrow="VIBES Admin"
        onRefresh={load}
        refreshing={loading}
        action={
          <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/reports/payments/export${buildQuery({ status, method, hasProof, q: qDebounced, from, to })}`, "payments.csv")}>
            تصدير CSV
          </Button>
        }
      />

      <HelpTip>افتح إثبات التحويل، قارنه بتعليمات الحساب أدناه، تأكد من المبلغ، ثم اضغط «تأكيد الدفع». الحجز يتأكد تلقائياً.</HelpTip>

      <PaymentInstructions />

      <ContentPanel>
        <ContentToolbar>
          <FilterChips
            value={chipValue()}
            onChange={applyChip}
            options={[
              { id: "all", label: "الكل" },
              { id: "pending", label: "تحتاج موافقة" },
              { id: "paid", label: "مؤكدة" },
              { id: "failed", label: "مرفوضة" },
              { id: "refunded", label: "مستردة" },
            ]}
          />
          {selected.size > 0 && (
            <div className="mt-4 flex flex-wrap items-center gap-2 rounded-xl border border-accent/30 bg-accent-soft/40 px-4 py-3">
              <span className="text-sm font-semibold">{selected.size} محدد</span>
              <Button size="sm" disabled={bulkLoading} onClick={bulkApprove}>تأكيد الدفع (جماعي)</Button>
              <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>إلغاء التحديد</Button>
            </div>
          )}
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث بالاسم أو الهاتف..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Button variant="ghost" onClick={() => setShowFilters((v) => !v)}>
              {showFilters ? "إخفاء فلاتر" : "المزيد من الفلاتر"}
            </Button>
          </PageToolbar>
          <FilterPanel open={showFilters}>
            <Select value={method} onChange={(e) => { setPage(1); setMethod(e.target.value); }}>
              <option value="">كل الطرق</option>
              {Object.entries(PAYMENT_METHOD_LABELS).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </Select>
            <Input type="date" value={from} onChange={(e) => { setPage(1); setFrom(e.target.value); }} title="من" />
            <Input type="date" value={to} onChange={(e) => { setPage(1); setTo(e.target.value); }} title="إلى" />
          </FilterPanel>
        </ContentToolbar>

        {error && (
          <div className="content-alert">
            <Alert variant="danger">{error}</Alert>
          </div>
        )}

        {loading && <div className="p-5"><SkeletonList count={4} /></div>}

        <div className="list-rows p-4">
          {!loading && (data?.items ?? []).map((p) => (
            <ListRow
              key={p.id}
              className={p.status === "PENDING" && p.proofUrl ? "border-accent/30 bg-accent-soft/30" : ""}
              leading={
                p.status === "PENDING" && p.proofUrl ? (
                  <input
                    type="checkbox"
                    checked={selected.has(p.id)}
                    onChange={() => toggleSelect(p.id)}
                    className="mt-1"
                    aria-label="تحديد"
                  />
                ) : undefined
              }
              title={p.booking?.property?.name ?? "—"}
              subtitle={
                <>
                  {p.booking?.user?.name ?? p.booking?.user?.phone} · {formatMoney(p.amount)}
                  <span className="mx-2 text-line">·</span>
                  {PAYMENT_METHOD_LABELS[p.method] ?? p.method} · {relativeTimeAr(p.createdAt)}
                </>
              }
              meta={<PhoneActions phone={p.booking?.user?.phone} compact />}
              badge={
                <Badge variant={p.status === "PAID" ? "success" : p.status === "PENDING" ? "warning" : p.status === "FAILED" ? "danger" : p.status === "REFUNDED" ? "muted" : "default"}>
                  {PAYMENT_STATUS_LABELS[p.status] ?? p.status}
                </Badge>
              }
              footer={
                <>
                  {p.proofUrl && (
                    <button type="button" onClick={() => setPreviewUrl(p.proofUrl!)} className="text-sm font-semibold text-accent underline">
                      معاينة إثبات الدفع
                    </button>
                  )}
                  {(p.adminNote || p.transactionRef || p.reviewedAt) && (
                    <div className="space-y-0.5 text-xs text-muted">
                      {p.transactionRef && <div dir="ltr">مرجع: {p.transactionRef}</div>}
                      {p.adminNote && <div>ملاحظة: {p.adminNote}</div>}
                      {p.reviewedAt && <div>رُاجع {relativeTimeAr(p.reviewedAt)}</div>}
                    </div>
                  )}
                  <div className="flex flex-wrap gap-2">
                    <Link href={`/payments/${p.id}`}>
                      <Button variant="ghost" className="px-2 py-1 text-xs">تفاصيل الدفعة</Button>
                    </Link>
                    {p.booking?.id && (
                      <Link href={`/bookings/${p.booking.id}`}>
                        <Button variant="ghost" className="px-2 py-1 text-xs">عرض الحجز</Button>
                      </Link>
                    )}
                    {p.status === "PENDING" && p.proofUrl && (
                      <Button className="px-2 py-1 text-xs" onClick={() => review(p.id, "PAID")}>تأكيد الدفع</Button>
                    )}
                    {p.status === "PENDING" && (
                      <>
                        <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => setRejectId(p.id)}>رفض</Button>
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setReviewId(reviewId === p.id ? null : p.id)}>
                          {reviewId === p.id ? "إغلاق" : "خيارات أخرى"}
                        </Button>
                      </>
                    )}
                  </div>
                  {reviewId === p.id && (
                    <div className="space-y-2 rounded-xl border border-line bg-surface p-3">
                      <Input placeholder="رقم المعاملة (اختياري)" value={getDraft(p.id).transactionRef} onChange={(e) => setDraft(p.id, { transactionRef: e.target.value })} dir="ltr" />
                      <Textarea placeholder="ملاحظة للفريق (اختياري)" value={getDraft(p.id).adminNote} onChange={(e) => setDraft(p.id, { adminNote: e.target.value })} />
                      <div className="flex gap-2">
                        <Button className="px-2 py-1 text-xs" onClick={() => review(p.id, "PAID")}>تأكيد الدفع</Button>
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setReviewId(null)}>إلغاء</Button>
                      </div>
                    </div>
                  )}
                </>
              }
            />
          ))}
        </div>

        {!loading && !data?.items.length && (
          <EmptyState title="لا توجد مدفوعات" description="جرّب تغيير الفلاتر أو انتظر إثباتات جديدة" />
        )}

        {data && (
          <ContentFooter>
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="دفعة" onPage={setPage} />
          </ContentFooter>
        )}
      </ContentPanel>

      <ImagePreview url={previewUrl} title="إثبات الدفع" onClose={() => setPreviewUrl(null)} />

      <ConfirmDialog
        open={!!rejectId}
        title="رفض الدفع"
        message="اكتب سبب الرفض — يظهر في سجل الفريق."
        confirmLabel="رفض"
        danger
        confirmDisabled={!rejectNote.trim()}
        onConfirm={() => rejectId && review(rejectId, "FAILED", rejectNote)}
        onClose={() => { setRejectId(null); setRejectNote(""); }}
      >
        <Textarea placeholder="مثال: المبلغ غير مطابق" value={rejectNote} onChange={(e) => setRejectNote(e.target.value)} />
      </ConfirmDialog>

    </PageShell>
  );
}
