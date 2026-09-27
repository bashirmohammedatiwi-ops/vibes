"use client";

import { useCallback, useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
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
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { formatMoney, relativeTimeAr } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

const STATUS: Record<string, { label: string; variant: "success" | "warning" | "danger" | "muted" | "default" }> = {
  PENDING: { label: "بانتظار الرد", variant: "warning" },
  ACCEPTED: { label: "مقبول", variant: "success" },
  DECLINED: { label: "مرفوض", variant: "danger" },
  EXPIRED: { label: "منتهٍ", variant: "muted" },
};

type OfferRow = {
  id: string;
  status: string;
  amount: number | string;
  createdAt: string;
  startDate?: string;
  endDate?: string;
  property?: { name: string };
  customer?: { name?: string | null; phone: string };
  provider?: { businessName?: string | null };
};

export default function OffersPage() {
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<OfferRow> | null>(null);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState("");
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<OfferRow>>(
          `/api/admin/offers${buildQuery({ status, q: qDebounced, page, pageSize: 15 })}`,
        ),
      );
    } finally {
      setLoading(false);
    }
  }, [status, qDebounced, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  return (
    <PageShell>
      <PageHeader title="عروض الأسعار" description="عروض خاصة يرسلها المالك لعميل وتاريخ محدد" eyebrow="تشغيل" />
      <HelpTip>قبول العرض من التطبيق ينشئ حجزاً بالسعر المعتمد مباشرة.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <FilterChips
            value={status || "all"}
            onChange={(id) => { setPage(1); setStatus(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "PENDING", label: "بانتظار" },
              { id: "ACCEPTED", label: "مقبول" },
              { id: "DECLINED", label: "مرفوض" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="المكان أو رقم العميل..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Select value={status} onChange={(e) => { setPage(1); setStatus(e.target.value); }} className="max-w-[180px]">
              <option value="">كل الحالات</option>
              <option value="PENDING">بانتظار</option>
              <option value="ACCEPTED">مقبول</option>
              <option value="DECLINED">مرفوض</option>
              <option value="EXPIRED">منتهٍ</option>
            </Select>
            <Button variant="ghost" onClick={load}>تحديث</Button>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/offers/export${buildQuery({ status, q: qDebounced })}`, "offers.csv")}
            >
              تصدير CSV
            </Button>
          </PageToolbar>
        </div>
        {loading ? <SkeletonList /> : !data?.items.length ? (
          <EmptyState title="لا عروض بعد" description="عندما يرسل المالك سعراً خاصاً سيظهر هنا" />
        ) : (
          <>
            <DataTable
              rows={data.items}
              rowKey={(row) => row.id}
              columns={[
                { key: "place", header: "المكان", cell: (row) => (
                  <div>
                    <div className="font-bold">{row.property?.name ?? "عرض"}</div>
                    <div className="text-xs text-muted">{row.provider?.businessName ?? ""}</div>
                  </div>
                ) },
                { key: "customer", header: "العميل", cell: (row) => row.customer?.name ?? row.customer?.phone ?? "—" },
                { key: "amount", header: "المبلغ", cell: (row) => formatMoney(row.amount) },
                {
                  key: "status",
                  header: "الحالة",
                  cell: (row) => <Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label ?? row.status}</Badge>,
                },
                { key: "when", header: "الإرسال", cell: (row) => relativeTimeAr(row.createdAt) },
              ]}
            />
            <div className="space-y-2 p-3 md:hidden">
              {data.items.map((row) => (
                <ListRow
                  key={row.id}
                  title={row.property?.name ?? "عرض"}
                  subtitle={`${row.customer?.phone ?? ""} · ${formatMoney(row.amount)}`}
                  badge={<Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label ?? row.status}</Badge>}
                />
              ))}
            </div>
            <PaginationBar page={page} totalPages={data.totalPages} onPage={setPage} />
          </>
        )}
      </Card>
    </PageShell>
  );
}
