"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { useToast } from "@/components/ui/toast";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { HelpTip } from "@/components/help-tip";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell, ContentPanel, ContentToolbar, ContentFooter } from "@/components/page-shell";
import { DataTable } from "@/components/ui/data-table";
import { FilterPanel, PageToolbar } from "@/components/ui/page-toolbar";
import { ListRow } from "@/components/ui/list-row";
import { SkeletonList } from "@/components/ui/skeleton";
import { Alert } from "@/components/ui/alert";
import { IconStar } from "@/components/nav-icons";
import { BULK_ACTION_LABELS, PROPERTY_STATUS_LABELS, PROPERTY_TYPE_LABELS, STATUS_VARIANT } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { formatMoney } from "@/lib/dates";
import type { Paginated, Property, PropertyStatus, PropertyType, Province } from "@/lib/types";
import { Modal } from "@/components/ui/modal";
import { Textarea } from "@/components/ui/input";
import { useDebouncedValue } from "@/hooks/use-debounced-value";

type ConfirmState =
  | { kind: "bulk-delete"; count: number }
  | { kind: "delete"; id: string; name: string }
  | { kind: "reject"; id: string; name: string }
  | null;

export default function PropertiesPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<Property> | null>(null);
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [type, setType] = useState("");
  const [status, setStatus] = useState(() => searchParams.get("status") ?? "");
  const [featured, setFeatured] = useState("");
  const [source, setSource] = useState(() => searchParams.get("source") ?? "");
  const [province, setProvince] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [provinces, setProvinces] = useState<Province[]>([]);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<ConfirmState>(null);
  const [pendingBulkAction, setPendingBulkAction] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState("صور غير كافية");
  const [rejectCustom, setRejectCustom] = useState("");

  const REJECT_REASONS = ["صور غير كافية", "معلومات غير دقيقة", "السعر غير مناسب", "سبب آخر"];

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await api<Paginated<Property>>(
        `/api/admin/properties${buildQuery({ q: qDebounced, type, status, province, source, featured: featured === "true" ? "true" : undefined, page, pageSize: 15 })}`,
      );
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل الأماكن");
    } finally {
      setLoading(false);
    }
  }, [qDebounced, type, status, featured, province, source, page]);

  useEffect(() => {
    api<Province[]>("/api/provinces").then(setProvinces).catch(() => undefined);
  }, []);

  useEffect(() => {
    const s = searchParams.get("status");
    if (s !== null) setStatus(s);
    const src = searchParams.get("source");
    if (src !== null) setSource(src);
  }, [searchParams]);

  useEffect(() => {
    load();
  }, [load]);

  async function bulk(action: string) {
    if (!selected.size) return;
    if (action === "delete") {
      setPendingBulkAction(action);
      setConfirm({ kind: "bulk-delete", count: selected.size });
      return;
    }
    await runBulk(action);
  }

  async function runBulk(action: string) {
    try {
      await api("/api/admin/properties/bulk", {
        method: "POST",
        body: JSON.stringify({ action, ids: [...selected] }),
      });
      toast(`تم ${BULK_ACTION_LABELS[action] ?? action} ${selected.size} مكان`);
      setSelected(new Set());
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التنفيذ", "error");
    }
  }

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function publish(id: string) {
    await api(`/api/admin/properties/${id}/publish`, { method: "POST" });
    toast("تم نشر المكان");
    await load();
  }

  async function duplicate(id: string) {
    try {
      const copy = await api<Property>(`/api/admin/properties/${id}/duplicate`, { method: "POST" });
      toast("تم إنشاء نسخة مسودة — أكملها ثم انشر");
      router.push(`/properties/${copy.id}/edit`);
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر النسخ", "error");
    }
  }

  async function suspend(id: string) {
    await api(`/api/admin/properties/${id}/suspend`, { method: "POST" });
    toast("تم إيقاف المكان");
    await load();
  }

  async function rejectProperty(id: string, reason: string) {
    await api(`/api/admin/properties/${id}/reject`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    });
    toast("تم رفض المكان");
    await load();
  }

  async function remove(id: string) {
    await api(`/api/admin/properties/${id}`, { method: "DELETE" });
    toast("تم الحذف");
    await load();
  }

  async function handleConfirm() {
    if (!confirm) return;
    if (confirm.kind === "bulk-delete" && pendingBulkAction) {
      await runBulk(pendingBulkAction);
      setPendingBulkAction(null);
    } else if (confirm.kind === "delete") {
      await remove(confirm.id);
    } else if (confirm.kind === "reject") {
      const reason = rejectReason === "سبب آخر" ? rejectCustom.trim() : rejectReason;
      if (reason) await rejectProperty(confirm.id, reason);
      setRejectCustom("");
    }
    setConfirm(null);
  }

  function propertyMetrics(item: Property) {
    const parts: string[] = [];
    if (item.viewCount) parts.push(`${item.viewCount} مشاهدة`);
    if (item.ratingCount) parts.push(`★ ${Number(item.ratingAvg ?? 0).toFixed(1)} (${item.ratingCount})`);
    if (item._count?.bookings) parts.push(`${item._count.bookings} حجز`);
    return parts.length ? parts.join(" · ") : null;
  }

  const cover = (item: Property) => item.media?.find((m) => m.isPrimary)?.url ?? item.media?.[0]?.url;

  async function toggleFeatured(item: Property) {
    try {
      await api(`/api/admin/properties/${item.id}`, {
        method: "PATCH",
        body: JSON.stringify({ featured: !item.featured }),
      });
      toast(item.featured ? "أُلغي التمييز" : "تم تمييز المكان");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function toggleNew(item: Property) {
    try {
      await api(`/api/admin/properties/${item.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isNew: !item.isNew }),
      });
      toast(item.isNew ? "أُزيل من الجديدة" : "ظهرت ضمن الجديدة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  function FeaturedStar({ item }: { item: Property }) {
    return (
      <button
        type="button"
        title={item.featured ? "إلغاء التمييز" : "تمييز"}
        className={`featured-star ${item.featured ? "featured-star-active" : ""}`}
        onClick={(e) => {
          e.stopPropagation();
          toggleFeatured(item);
        }}
      >
        <IconStar className="h-4 w-4" />
      </button>
    );
  }

  function PropertyActions({ item }: { item: Property }) {
    return (
      <div className="flex flex-wrap gap-2">
        {(item.type === "FARM" || item.type === "HALL") && (
          <Button
            variant={item.isNew ? "primary" : "ghost"}
            className="px-2 py-1 text-xs"
            onClick={() => toggleNew(item)}
          >
            {item.isNew ? "جديدة" : "تفعيل جديدة"}
          </Button>
        )}
        <Link href={`/properties/${item.id}/edit`}>
          <Button variant="ghost" className="px-2 py-1 text-xs">تعديل</Button>
        </Link>
        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => duplicate(item.id)}>نسخ</Button>
        {item.status === "PENDING" && (
          <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => setConfirm({ kind: "reject", id: item.id, name: item.name })}>
            رفض
          </Button>
        )}
        {item.status !== "APPROVED" && (
          <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => publish(item.id)}>نشر</Button>
        )}
        {item.status === "APPROVED" && (
          <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => suspend(item.id)}>إيقاف</Button>
        )}
        <Button
          variant="danger"
          className="px-2 py-1 text-xs"
          onClick={() => setConfirm({ kind: "delete", id: item.id, name: item.name })}
        >
          حذف
        </Button>
      </div>
    );
  }

  return (
    <PageShell>
      <PageHeader
        title="الأماكن"
        description="أضف وعدّل المزارع والقاعات — أو راجع ما رفعه مزود"
        eyebrow="VIBES Admin"
        action={
          <>
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv("/api/admin/reports/properties/export", "properties.csv")}>تصدير CSV</Button>
            <Link href="/map">
              <Button variant="ghost">الخريطة</Button>
            </Link>
            <Link href="/properties/new">
              <Button>+ مكان جديد</Button>
            </Link>
          </>
        }
      />

      <HelpTip>النجمة تميّز المكان. «تفعيل جديدة» على المزرعة أو القاعة يظهرها في قسم الجديدة بالصفحة الرئيسية.</HelpTip>

      <ContentPanel>
        {selected.size > 0 && (
          <div className="bulk-bar">
            <span className="text-sm font-bold">{selected.size} محدد — ماذا تريد أن تفعل؟</span>
            <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => bulk("publish")}>نشر</Button>
            <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => bulk("feature")}>تمييز</Button>
            <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => bulk("unfeature")}>إلغاء التمييز</Button>
            <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => bulk("suspend")}>إيقاف</Button>
            <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => bulk("delete")}>حذف</Button>
          </div>
        )}
        <ContentToolbar>
          <FilterChips
            value={status || "all"}
            onChange={(id) => { setPage(1); setStatus(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "DRAFT", label: "مسودة" },
              { id: "PENDING", label: "بانتظار المراجعة" },
              { id: "APPROVED", label: "منشور" },
              { id: "REJECTED", label: "مرفوض" },
              { id: "SUSPENDED", label: "متوقف" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="ابحث بالاسم..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Button variant="ghost" onClick={() => setShowFilters((v) => !v)}>
              {showFilters ? "إخفاء فلاتر" : "المزيد من الفلاتر"}
            </Button>
          </PageToolbar>
          <FilterPanel open={showFilters}>
            <Select value={type} onChange={(e) => { setPage(1); setType(e.target.value); }}>
              <option value="">كل الأنواع</option>
              {(Object.keys(PROPERTY_TYPE_LABELS) as PropertyType[]).map((t) => (
                <option key={t} value={t}>{PROPERTY_TYPE_LABELS[t]}</option>
              ))}
            </Select>
            <Select value={province} onChange={(e) => { setPage(1); setProvince(e.target.value); }}>
              <option value="">كل المحافظات</option>
              {provinces.map((p) => (
                <option key={p.id} value={p.slug}>{p.nameAr}</option>
              ))}
            </Select>
            <Select value={featured} onChange={(e) => { setPage(1); setFeatured(e.target.value); }}>
              <option value="">الكل</option>
              <option value="true">مميزة فقط</option>
            </Select>
            <Select value={source} onChange={(e) => { setPage(1); setSource(e.target.value); }}>
              <option value="">كل المصادر</option>
              <option value="team">أضافه الفريق</option>
              <option value="provider">مقدم من المزود</option>
            </Select>
          </FilterPanel>
        </ContentToolbar>

        {error && <div className="content-alert"><Alert variant="danger">{error}</Alert></div>}
        {loading && <div className="p-5"><SkeletonList count={5} /></div>}

        <div className="list-rows p-4 md:hidden">
          {(data?.items ?? []).map((item) => (
            <ListRow
              key={item.id}
              onClick={() => router.push(`/properties/${item.id}/edit`)}
              leading={
                <div className="flex gap-2">
                  <input type="checkbox" checked={selected.has(item.id)} onChange={() => toggleSelect(item.id)} onClick={(e) => e.stopPropagation()} className="mt-1" />
                  <div className="property-thumb h-14 w-20 shrink-0">
                    {cover(item) ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={cover(item)} alt="" className="h-full w-full object-cover" />
                    ) : null}
                  </div>
                </div>
              }
              title={
                <span className="flex items-center gap-1.5">
                  <FeaturedStar item={item} />
                  {item.name}
                </span>
              }
              subtitle={
                <>
                  {PROPERTY_TYPE_LABELS[item.type]} · {item.city?.nameAr ?? "—"}
                  {propertyMetrics(item) && <span className="block text-accent/80">{propertyMetrics(item)}</span>}
                </>
              }
              badge={
                <div className="flex flex-wrap gap-1">
                  <Badge variant={STATUS_VARIANT[item.status]}>{PROPERTY_STATUS_LABELS[item.status]}</Badge>
                  {item.providerId && <Badge variant="muted">مزود</Badge>}
                </div>
              }
              meta={<span className="text-sm font-bold">{formatMoney(item.pricePerDay)}</span>}
              footer={<div onClick={(e) => e.stopPropagation()}><PropertyActions item={item} /></div>}
            />
          ))}
        </div>

        {!loading && (
          <DataTable
            columns={[
              {
                key: "select",
                header: "",
                className: "w-8",
                cell: (item) => <input type="checkbox" checked={selected.has(item.id)} onChange={() => toggleSelect(item.id)} />,
              },
              {
                key: "name",
                header: "المكان",
                cell: (item) => (
                  <div className="flex items-center gap-3">
                    <div className="property-thumb h-12 w-16 shrink-0">
                      {cover(item) ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={cover(item)} alt="" className="h-full w-full object-cover" />
                      ) : null}
                    </div>
                    <div className="flex items-center gap-1.5">
                      <FeaturedStar item={item} />
                      <span className="font-semibold">{item.name}</span>
                    </div>
                  </div>
                ),
              },
              { key: "type", header: "النوع", cell: (item) => PROPERTY_TYPE_LABELS[item.type] },
              { key: "city", header: "المدينة", cell: (item) => item.city?.nameAr ?? "—" },
              {
                key: "metrics",
                header: "الأداء",
                cell: (item) => (
                  <span className="text-xs text-muted">
                    {propertyMetrics(item) ?? "—"}
                  </span>
                ),
              },
              { key: "price", header: "السعر", cell: (item) => <span className="font-semibold">{formatMoney(item.pricePerDay)}</span> },
              {
                key: "status",
                header: "الحالة",
                cell: (item) => (
                  <div className="flex flex-wrap items-center gap-1">
                    <Badge variant={STATUS_VARIANT[item.status]}>{PROPERTY_STATUS_LABELS[item.status]}</Badge>
                    {item.providerId && <Badge variant="muted">مزود</Badge>}
                  </div>
                ),
              },
              { key: "actions", header: "إجراءات", cell: (item) => <PropertyActions item={item} /> },
            ]}
            rows={data?.items ?? []}
            rowKey={(item) => item.id}
            onRowClick={(item) => router.push(`/properties/${item.id}/edit`)}
            empty={!data?.items.length ? <EmptyState title="لا توجد أماكن" description="جرّب تغيير الفلاتر أو أضف مكاناً جديداً" action={<Link href="/properties/new"><Button>+ مكان جديد</Button></Link>} /> : undefined}
          />
        )}

        {data && (
          <ContentFooter>
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="مكان" onPage={setPage} />
          </ContentFooter>
        )}
      </ContentPanel>

      <ConfirmDialog
        open={!!confirm && confirm.kind !== "reject"}
        title={confirm?.kind === "bulk-delete" ? "حذف جماعي" : "حذف المكان"}
        message={
          confirm?.kind === "bulk-delete"
            ? `حذف ${confirm.count} مكان نهائياً؟ لا يمكن التراجع.`
            : confirm?.kind === "delete"
              ? `حذف «${confirm.name}» نهائياً؟ لا يمكن التراجع.`
              : ""
        }
        confirmLabel="حذف"
        danger
        onConfirm={handleConfirm}
        onClose={() => { setConfirm(null); setPendingBulkAction(null); }}
      />

      <Modal
        open={confirm?.kind === "reject"}
        onClose={() => setConfirm(null)}
        title={confirm?.kind === "reject" ? `رفض «${confirm.name}»` : "رفض المكان"}
      >
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2">
            {REJECT_REASONS.map((r) => (
              <button
                key={r}
                type="button"
                className={`rounded-full px-3 py-1.5 text-sm font-semibold transition ${
                  rejectReason === r ? "bg-accent text-white" : "border border-line bg-surface text-muted"
                }`}
                onClick={() => setRejectReason(r)}
              >
                {r}
              </button>
            ))}
          </div>
          {rejectReason === "سبب آخر" && (
            <Textarea value={rejectCustom} onChange={(e) => setRejectCustom(e.target.value)} placeholder="سبب الرفض..." rows={3} />
          )}
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setConfirm(null)}>إلغاء</Button>
            <Button variant="danger" onClick={handleConfirm}>تأكيد الرفض</Button>
          </div>
        </div>
      </Modal>
    </PageShell>
  );
}
