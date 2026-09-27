"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
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
import { api, buildQuery, openPrintHtml } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { formatMoney, relativeTimeAr } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

const STATUS: Record<string, { label: string; variant: "success" | "warning" | "danger" | "muted" | "default" }> = {
  ISSUED: { label: "صادرة", variant: "warning" },
  PAID: { label: "مدفوعة", variant: "success" },
  VOID: { label: "ملغاة", variant: "muted" },
  REFUNDED: { label: "مستردة", variant: "danger" },
};

type InvoiceRow = {
  id: string;
  number: string;
  status: string;
  total: number | string;
  issuedAt: string;
  booking?: {
    id: string;
    property?: { name: string };
    user?: { name?: string | null; phone: string };
  };
};

export default function InvoicesPage() {
  const { exportCsv, exporting } = useCsvExport();
  const search = useSearchParams();
  const [data, setData] = useState<Paginated<InvoiceRow> | null>(null);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState("");
  const [q, setQ] = useState(search.get("q") ?? "");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<InvoiceRow>>(
          `/api/admin/invoices${buildQuery({ status, q: qDebounced, page, pageSize: 15 })}`,
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
      <PageHeader
        title="الفواتير"
        description="فواتير مرقمة تصدر تلقائياً عند تأكيد الدفع"
        eyebrow="مالية"
      />
      <HelpTip>الفاتورة تُنشأ مع تأكيد الحجز أو الدفع — الرقم بالصيغة VIB-السنة-التسلسل.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <FilterChips
            value={status || "all"}
            onChange={(id) => { setPage(1); setStatus(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "ISSUED", label: "صادرة" },
              { id: "PAID", label: "مدفوعة" },
              { id: "REFUNDED", label: "مستردة" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="رقم الفاتورة أو العميل..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Select value={status} onChange={(e) => { setPage(1); setStatus(e.target.value); }} className="max-w-[180px]">
              <option value="">كل الحالات</option>
              <option value="ISSUED">صادرة</option>
              <option value="PAID">مدفوعة</option>
              <option value="REFUNDED">مستردة</option>
              <option value="VOID">ملغاة</option>
            </Select>
            <Button variant="ghost" onClick={load}>تحديث</Button>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/invoices/export${buildQuery({ status, q: qDebounced })}`, "invoices.csv")}
            >
              تصدير CSV
            </Button>
          </PageToolbar>
        </div>
        {loading ? <SkeletonList /> : !data?.items.length ? (
          <EmptyState title="لا فواتير بعد" description="ستظهر الفواتير بعد تأكيد الدفعات" />
        ) : (
          <>
            <DataTable
              rows={data.items}
              rowKey={(row) => row.id}
              columns={[
                { key: "number", header: "الرقم", cell: (row) => <span className="font-mono font-bold">{row.number}</span> },
                { key: "place", header: "المكان", cell: (row) => row.booking?.property?.name ?? "—" },
                { key: "customer", header: "العميل", cell: (row) => row.booking?.user?.name ?? row.booking?.user?.phone ?? "—" },
                { key: "total", header: "المبلغ", cell: (row) => formatMoney(row.total) },
                {
                  key: "status",
                  header: "الحالة",
                  cell: (row) => <Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label ?? row.status}</Badge>,
                },
                { key: "when", header: "الإصدار", cell: (row) => relativeTimeAr(row.issuedAt) },
                {
                  key: "booking",
                  header: "",
                  cell: (row) => (
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        className="text-accent underline"
                        onClick={() => {
                          void openPrintHtml(`/api/admin/invoices/${row.id}/print`);
                        }}
                      >
                        طباعة
                      </button>
                      {row.booking?.id ? (
                        <Link href={`/bookings/${row.booking.id}`} className="text-accent underline">
                          الحجز
                        </Link>
                      ) : null}
                    </div>
                  ),
                },
              ]}
            />
            <div className="space-y-2 p-3 md:hidden">
              {data.items.map((row) => (
                <ListRow
                  key={row.id}
                  title={row.number}
                  subtitle={`${row.booking?.property?.name ?? ""} · ${formatMoney(row.total)}`}
                  badge={<Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label ?? row.status}</Badge>}
                  footer={
                    <div className="flex gap-3">
                      <button
                        type="button"
                        className="text-accent underline"
                        onClick={() => {
                          void openPrintHtml(`/api/admin/invoices/${row.id}/print`);
                        }}
                      >
                        طباعة
                      </button>
                      {row.booking?.id ? (
                        <Link href={`/bookings/${row.booking.id}`} className="text-accent underline">
                          الحجز
                        </Link>
                      ) : null}
                    </div>
                  }
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
