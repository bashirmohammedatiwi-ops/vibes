"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { PaginationBar } from "@/components/pagination-bar";
import { DataTable } from "@/components/ui/data-table";
import { ListRow } from "@/components/ui/list-row";
import { SkeletonList } from "@/components/ui/skeleton";
import { useCsvExport } from "@/lib/use-csv-export";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { api, buildQuery } from "@/lib/api";
import { relativeTimeAr } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

type CollectionRow = {
  id: string;
  name: string;
  visibility: string;
  isDefault: boolean;
  updatedAt: string;
  coverUrl?: string | null;
  user?: { name?: string | null; phone: string };
  _count?: { items: number };
};

export default function CollectionsPage() {
  const { exportCsv, exporting } = useCsvExport();
  const router = useRouter();
  const [data, setData] = useState<Paginated<CollectionRow> | null>(null);
  const [loading, setLoading] = useState(true);
  const [visibility, setVisibility] = useState("");
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<CollectionRow>>(
          `/api/admin/collections${buildQuery({ visibility, q: qDebounced, page, pageSize: 15 })}`,
        ),
      );
    } finally {
      setLoading(false);
    }
  }, [visibility, qDebounced, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  return (
    <PageShell>
      <PageHeader title="القوائم" description="قوائم الحفظ الخاصة والعامة التي ينشئها العملاء" eyebrow="اكتشاف" />
      <HelpTip>المفضلة تبقى قائمة مستقلة — القوائم هنا مجموعات إضافية باسم وغلاف.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <PageToolbar className="mb-0">
            <Input className="max-w-sm flex-1" placeholder="اسم القائمة أو العميل..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Select value={visibility} onChange={(e) => { setPage(1); setVisibility(e.target.value); }} className="max-w-[180px]">
              <option value="">كل الظهور</option>
              <option value="PRIVATE">خاصة</option>
              <option value="PUBLIC">عامة</option>
            </Select>
            <Button variant="ghost" onClick={load}>تحديث</Button>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/collections/export${buildQuery({ visibility, q: qDebounced })}`, "collections.csv")}
            >
              تصدير CSV
            </Button>
          </PageToolbar>
        </div>
        {loading ? <SkeletonList /> : !data?.items.length ? (
          <EmptyState title="لا قوائم بعد" description="عندما يحفظ العملاء قوائم ستظهر هنا" />
        ) : (
          <>
            <DataTable
              rows={data.items}
              rowKey={(row) => row.id}
              onRowClick={(row) => router.push(`/collections/${row.id}`)}
              columns={[
                { key: "name", header: "القائمة", cell: (row) => (
                  <div className="flex items-center gap-3">
                    {row.coverUrl ? (
                      <img
                        src={row.coverUrl}
                        alt=""
                        className="h-11 w-16 shrink-0 object-cover"
                        style={{ borderRadius: "10px 3px 10px 10px" }}
                      />
                    ) : null}
                    <div>
                      <div className="font-bold">{row.name}</div>
                      {row.isDefault && <span className="text-xs text-muted">افتراضية</span>}
                    </div>
                  </div>
                ) },
                { key: "user", header: "المالك", cell: (row) => row.user?.name ?? row.user?.phone ?? "—" },
                { key: "items", header: "العناصر", cell: (row) => row._count?.items ?? 0 },
                {
                  key: "vis",
                  header: "الظهور",
                  cell: (row) => <Badge variant={row.visibility === "PUBLIC" ? "success" : "muted"}>{row.visibility === "PUBLIC" ? "عامة" : "خاصة"}</Badge>,
                },
                { key: "when", header: "التحديث", cell: (row) => relativeTimeAr(row.updatedAt) },
              ]}
            />
            <div className="space-y-2 p-3 md:hidden">
              {data.items.map((row) => (
                <ListRow
                  key={row.id}
                  onClick={() => router.push(`/collections/${row.id}`)}
                  leading={row.coverUrl ? (
                    <img
                      src={row.coverUrl}
                      alt=""
                      className="h-11 w-16 shrink-0 object-cover"
                      style={{ borderRadius: "10px 3px 10px 10px" }}
                    />
                  ) : undefined}
                  title={row.name}
                  subtitle={`${row.user?.phone ?? ""} · ${row._count?.items ?? 0} مكان`}
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
