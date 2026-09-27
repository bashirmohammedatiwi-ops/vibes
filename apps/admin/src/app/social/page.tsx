"use client";

import { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
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
import { relativeTimeAr } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

const STATUS: Record<string, { label: string; variant: "success" | "warning" | "danger" | "muted" | "default" }> = {
  PUBLISHED: { label: "منشور", variant: "success" },
  HIDDEN: { label: "مخفي", variant: "muted" },
  REPORTED: { label: "مُبلَّغ", variant: "danger" },
};

type PostRow = {
  id: string;
  caption: string;
  status: string;
  likesCount: number;
  commentsCount: number;
  createdAt: string;
  user?: { name?: string | null; phone: string };
  property?: { name: string };
  _count?: { reports: number };
};

type PostDetail = PostRow & {
  comments?: Array<{ id: string; body: string; createdAt: string; user?: { name?: string | null; phone: string } }>;
  reports?: Array<{ id: string; reason: string; createdAt: string; user?: { name?: string | null; phone: string } }>;
};

export default function SocialPage() {
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const search = useSearchParams();
  const [data, setData] = useState<Paginated<PostRow> | null>(null);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState(search.get("status") ?? "");
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);
  const [detail, setDetail] = useState<PostDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<PostRow>>(
          `/api/admin/social${buildQuery({ status, q: qDebounced, page, pageSize: 15 })}`,
        ),
      );
    } finally {
      setLoading(false);
    }
  }, [status, qDebounced, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  async function moderate(id: string, next: string) {
    try {
      await api(`/api/admin/social/${id}`, { method: "PATCH", body: JSON.stringify({ status: next }) });
      toast(next === "HIDDEN" ? "تم إخفاء المنشور" : "تم النشر");
      await load();
      if (detail?.id === id) {
        setDetail({ ...detail, status: next });
      }
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function openDetail(id: string) {
    setDetailLoading(true);
    try {
      setDetail(await api<PostDetail>(`/api/admin/social/${id}`));
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر فتح المنشور", "error");
    } finally {
      setDetailLoading(false);
    }
  }

  return (
    <PageShell>
      <PageHeader title="التجارب الاجتماعية" description="راجع المنشورات والإبلاغات وأخفِ غير المناسب" eyebrow="محتوى" />
      <HelpTip>المنشورات المرتبطة بحجز مكتمل. ثلاث بلاغات تخفي المنشور تلقائياً بانتظار قرارك.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <FilterChips
            value={status || "all"}
            onChange={(id) => { setPage(1); setStatus(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "PUBLISHED", label: "منشور" },
              { id: "REPORTED", label: "مُبلَّغ" },
              { id: "HIDDEN", label: "مخفي" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث في الوصف أو المكان..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Button variant="ghost" onClick={load}>تحديث</Button>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/social/export${buildQuery({ status, q: qDebounced })}`, "social.csv")}
            >
              تصدير CSV
            </Button>
          </PageToolbar>
        </div>
        {loading ? <SkeletonList /> : !data?.items.length ? (
          <EmptyState title="لا تجارب بعد" description="التجارب بعد اكتمال الحجز تظهر هنا للمراجعة" />
        ) : (
          <>
            <DataTable
              rows={data.items}
              rowKey={(row) => row.id}
              onRowClick={(row) => openDetail(row.id)}
              columns={[
                {
                  key: "post",
                  header: "المنشور",
                  cell: (row) => (
                    <div>
                      <div className="line-clamp-2 font-medium">{row.caption || "بدون وصف"}</div>
                      <div className="text-xs text-muted">{row.property?.name} · {row.user?.name ?? row.user?.phone}</div>
                    </div>
                  ),
                },
                { key: "likes", header: "تفاعل", cell: (row) => `${row.likesCount} إعجاب · ${row.commentsCount} تعليق` },
                { key: "reports", header: "بلاغات", cell: (row) => row._count?.reports ?? 0 },
                {
                  key: "status",
                  header: "الحالة",
                  cell: (row) => <Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label ?? row.status}</Badge>,
                },
                { key: "when", header: "النشر", cell: (row) => relativeTimeAr(row.createdAt) },
                {
                  key: "act",
                  header: "",
                  cell: (row) => (
                    <div className="flex gap-2">
                      {row.status !== "HIDDEN" && (
                        <Button size="sm" variant="ghost" onClick={() => moderate(row.id, "HIDDEN")}>إخفاء</Button>
                      )}
                      {row.status !== "PUBLISHED" && (
                        <Button size="sm" onClick={() => moderate(row.id, "PUBLISHED")}>نشر</Button>
                      )}
                    </div>
                  ),
                },
              ]}
            />
            <div className="space-y-2 p-3 md:hidden">
              {data.items.map((row) => (
                <ListRow
                  key={row.id}
                  onClick={() => openDetail(row.id)}
                  title={row.caption || row.property?.name || "تجربة"}
                  subtitle={`${row.likesCount} إعجاب · ${row._count?.reports ?? 0} بلاغ`}
                  badge={<Badge variant={STATUS[row.status]?.variant ?? "default"}>{STATUS[row.status]?.label}</Badge>}
                />
              ))}
            </div>
            <PaginationBar page={page} totalPages={data.totalPages} onPage={setPage} />
          </>
        )}
      </Card>
      <Modal open={!!detail || detailLoading} title={detail?.property?.name || "التجربة"} onClose={() => setDetail(null)}>
        {detailLoading && !detail ? <p className="text-sm text-muted">جارٍ التحميل…</p> : null}
        {detail ? (
          <div className="space-y-4 text-sm">
            <p className="leading-6">{detail.caption || "بدون وصف"}</p>
            <div className="text-xs text-muted">
              {detail.user?.name ?? detail.user?.phone} · {relativeTimeAr(detail.createdAt)}
            </div>
            <div className="flex gap-2">
              {detail.status !== "HIDDEN" && (
                <Button size="sm" variant="ghost" onClick={() => moderate(detail.id, "HIDDEN")}>إخفاء</Button>
              )}
              {detail.status !== "PUBLISHED" && (
                <Button size="sm" onClick={() => moderate(detail.id, "PUBLISHED")}>نشر</Button>
              )}
            </div>
            <div>
              <div className="mb-2 font-bold">التعليقات</div>
              {!detail.comments?.length ? (
                <p className="text-muted">لا تعليقات</p>
              ) : (
                <ul className="space-y-2">
                  {detail.comments.map((comment) => (
                    <li key={comment.id} className="border-b border-line pb-2">
                      <div className="font-medium">{comment.user?.name ?? comment.user?.phone}</div>
                      <div>{comment.body}</div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            <div>
              <div className="mb-2 font-bold">البلاغات</div>
              {!detail.reports?.length ? (
                <p className="text-muted">لا بلاغات</p>
              ) : (
                <ul className="space-y-2">
                  {detail.reports.map((report) => (
                    <li key={report.id} className="border-b border-line pb-2">
                      <div className="font-medium">{report.user?.name ?? report.user?.phone}</div>
                      <div>{report.reason || "بدون سبب"}</div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        ) : null}
      </Modal>
    </PageShell>
  );
}
