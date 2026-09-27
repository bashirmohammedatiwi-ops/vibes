"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { PaginationBar } from "@/components/pagination-bar";
import { DataTable } from "@/components/ui/data-table";
import { ListRow } from "@/components/ui/list-row";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { useCsvExport } from "@/lib/use-csv-export";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { api, buildQuery } from "@/lib/api";
import { formatMoney, relativeTimeAr } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

const STATUS: Record<string, { label: string; variant: "success" | "warning" | "danger" | "muted" | "default" }> = {
  PENDING: { label: "بانتظار المراجعة", variant: "warning" },
  APPROVED: { label: "مقبول", variant: "success" },
  REJECTED: { label: "مرفوض", variant: "danger" },
  CANCELLED: { label: "ملغى", variant: "muted" },
};

type RefundRow = {
  id: string;
  reason: string;
  amount: number | string;
  status: string;
  createdAt: string;
  user?: { name?: string | null; phone: string };
  booking?: {
    id: string;
    status: string;
    startDate: string;
    property?: { name: string };
  };
};

type CancellationRow = {
  id: string;
  reason: string;
  expectedRefund: number | string;
  status: string;
  createdAt: string;
  user?: { name?: string | null; phone: string };
  booking?: { id: string; property?: { name: string } };
};

export default function RefundsPage() {
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const search = useSearchParams();
  const [data, setData] = useState<(Paginated<RefundRow> & { cancellations?: CancellationRow[] }) | null>(null);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState("PENDING");
  const [q, setQ] = useState(search.get("q") ?? "");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);
  const [review, setReview] = useState<{ id: string; kind: "refund" | "cancel" } | null>(null);
  const [approve, setApprove] = useState(true);
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<RefundRow> & { cancellations?: CancellationRow[] }>(
          `/api/admin/refunds${buildQuery({ status, q: qDebounced, page, pageSize: 15 })}`,
        ),
      );
    } finally {
      setLoading(false);
    }
  }, [status, qDebounced, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  async function submit() {
    if (!review) return;
    setSaving(true);
    try {
      const path = review.kind === "refund" ? `/api/admin/refunds/${review.id}` : `/api/admin/cancellations/${review.id}`;
      await api(path, { method: "PATCH", body: JSON.stringify({ approve, adminNote: note || undefined }) });
      toast(approve ? "تم قبول الطلب" : "تم رفض الطلب");
      setReview(null);
      setNote("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التنفيذ", "error");
    } finally {
      setSaving(false);
    }
  }

  const pendingCancellations = (data?.cancellations ?? []).filter((c) => !status || c.status === status);

  return (
    <PageShell>
      <PageHeader title="الإلغاء والاسترداد" description="راجع طلبات الإلغاء بعد التأكيد وأعد المبالغ وفق السياسة" eyebrow="تشغيل" />
      <HelpTip>السياسة: استرداد كامل قبل 7 أيام، نصف المبلغ قبل 3 أيام، وبدون استرداد بعد ذلك.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <FilterChips
            value={status || "all"}
            onChange={(id) => { setPage(1); setStatus(id === "all" ? "" : id); }}
            options={[
              { id: "PENDING", label: "بانتظار" },
              { id: "APPROVED", label: "مقبول" },
              { id: "REJECTED", label: "مرفوض" },
              { id: "all", label: "الكل" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Button variant="ghost" onClick={load}>تحديث</Button>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/refunds/export${buildQuery({ status, q: qDebounced })}`, "refunds.csv")}
            >
              تصدير CSV
            </Button>
          </PageToolbar>
        </div>
        {loading ? <SkeletonList /> : !data?.items.length && !pendingCancellations.length ? (
          <EmptyState title="لا طلبات" description="طلبات الإلغاء والاسترداد من التطبيق تظهر هنا" />
        ) : (
          <>
            <DataTable
              rows={data?.items ?? []}
              rowKey={(row) => row.id}
              columns={[
                { key: "place", header: "الحجز", cell: (row) => (
                  <div>
                    <div className="font-bold">{row.booking?.property?.name ?? "حجز"}</div>
                    <div className="text-xs text-muted">{row.user?.name ?? row.user?.phone}</div>
                  </div>
                ) },
                { key: "amount", header: "المبلغ", cell: (row) => formatMoney(row.amount) },
                { key: "reason", header: "السبب", cell: (row) => <span className="line-clamp-2">{row.reason || "—"}</span> },
                { key: "status", header: "الحالة", cell: (row) => <Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label ?? row.status}</Badge> },
                { key: "when", header: "التقديم", cell: (row) => relativeTimeAr(row.createdAt) },
                {
                  key: "act",
                  header: "",
                  cell: (row) => row.status === "PENDING" ? (
                    <Button size="sm" onClick={() => { setReview({ id: row.id, kind: "refund" }); setApprove(true); }}>مراجعة</Button>
                  ) : row.booking?.id ? <Link href={`/bookings/${row.booking.id}`} className="text-accent underline">الحجز</Link> : null,
                },
              ]}
            />
            {pendingCancellations.length > 0 && (
              <div className="border-t border-line p-4">
                <div className="mb-3 text-sm font-bold">طلبات الإلغاء</div>
                <div className="space-y-2">
                  {pendingCancellations.map((row) => (
                    <ListRow
                      key={row.id}
                      title={row.booking?.property?.name ?? "إلغاء"}
                      subtitle={`${row.user?.phone ?? ""} · متوقع ${formatMoney(row.expectedRefund)}`}
                      badge={
                        row.status === "PENDING" ? (
                          <Button size="sm" onClick={() => { setReview({ id: row.id, kind: "cancel" }); setApprove(true); }}>مراجعة</Button>
                        ) : (
                          <Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label}</Badge>
                        )
                      }
                    />
                  ))}
                </div>
              </div>
            )}
            <PaginationBar page={page} totalPages={data?.totalPages ?? 1} onPage={setPage} />
          </>
        )}
      </Card>

      <Modal open={!!review} onClose={() => setReview(null)} title="مراجعة الطلب">
        <div className="space-y-3">
          <div className="flex gap-2">
            <Button variant={approve ? "primary" : "ghost"} onClick={() => setApprove(true)}>قبول</Button>
            <Button variant={!approve ? "primary" : "ghost"} onClick={() => setApprove(false)}>رفض</Button>
          </div>
          <Textarea placeholder={approve ? "ملاحظة اختيارية" : "سبب الرفض"} value={note} onChange={(e) => setNote(e.target.value)} />
          <Button disabled={saving} onClick={submit}>{saving ? "جارٍ الحفظ..." : "تأكيد القرار"}</Button>
        </div>
      </Modal>
    </PageShell>
  );
}
