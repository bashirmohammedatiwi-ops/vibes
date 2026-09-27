"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { ListRow } from "@/components/ui/list-row";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { SkeletonList } from "@/components/ui/skeleton";
import { StatStrip } from "@/components/ui/stat-strip";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { IconUsers } from "@/components/nav-icons";
import { PhoneActions } from "@/components/phone-actions";
import { useToast } from "@/components/ui/toast";
import { KYC_STATUS_LABELS, PROPERTY_TYPE_LABELS } from "@/lib/constants";
import { PaginationBar } from "@/components/pagination-bar";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import type { Paginated, PropertyType } from "@/lib/types";

type Provider = {
  id: string;
  businessName?: string;
  verified: boolean;
  kycStatus: string;
  rejectionReason?: string | null;
  requestNote?: string;
  placeTypes?: string;
  user?: { id: string; name?: string; phone: string };
  _count?: { properties: number };
};

function placeTypesLabel(value?: string) {
  if (!value) return "";
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => PROPERTY_TYPE_LABELS[item as PropertyType] ?? item)
    .join(" · ");
}

export default function ProvidersPage() {
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<Provider> | null>(null);
  const [kycFilter, setKycFilter] = useState("pending");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [rejectId, setRejectId] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [revokeId, setRevokeId] = useState<string | null>(null);
  const [revokeReason, setRevokeReason] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const kyc = kycFilter === "verified" ? "verified" : kycFilter === "rejected" ? "rejected" : kycFilter === "pending" ? "pending" : undefined;
      setData(await api<Paginated<Provider>>(`/api/admin/providers${buildQuery({ page, pageSize: 20, q, kyc })}`));
    } finally {
      setLoading(false);
    }
  }, [page, q, kycFilter]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  async function reject() {
    if (!rejectId || !rejectReason.trim()) return;
    try {
      await api(`/api/admin/providers/${rejectId}/reject`, {
        method: "PATCH",
        body: JSON.stringify({ reason: rejectReason.trim() }),
      });
      toast("تم الرفض");
      setRejectId(null);
      setRejectReason("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الرفض", "error");
    }
  }

  async function verify(id: string) {
    try {
      await api(`/api/admin/providers/${id}/verify`, { method: "PATCH" });
      toast("تم توثيق المزود");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التوثيق", "error");
    }
  }

  async function revoke() {
    if (!revokeId) return;
    try {
      await api(`/api/admin/providers/${revokeId}/revoke`, {
        method: "PATCH",
        body: JSON.stringify({ reason: revokeReason.trim() || undefined }),
      });
      toast("تم إلغاء التوثيق");
      setRevokeId(null);
      setRevokeReason("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإلغاء", "error");
    }
  }

  const items = data?.items ?? [];
  const filtered = items;

  const pendingCount = kycFilter === "pending" ? (data?.total ?? items.length) : items.filter((i) => !i.verified && i.kycStatus === "PENDING").length;
  const verifiedCount = kycFilter === "verified" ? (data?.total ?? items.length) : items.filter((i) => i.verified).length;

  function ProviderActions({ item }: { item: Provider }) {
    return (
      <div className="flex flex-wrap gap-2">
        <PhoneActions phone={item.user?.phone} compact />
        <Link href={`/providers/${item.id}`}>
          <Button variant="ghost" className="px-2 py-1 text-xs">CRM</Button>
        </Link>
        {item.user?.id && (
          <Link href={`/users/${item.user.id}`}>
            <Button variant="ghost" className="px-2 py-1 text-xs">الملف</Button>
          </Link>
        )}
        {item.verified ? (
          <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setRevokeId(item.id)}>
            إلغاء التوثيق
          </Button>
        ) : (
          <>
            <Button className="px-2 py-1 text-xs" onClick={() => verify(item.id)}>موافقة</Button>
            <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => setRejectId(item.id)}>رفض</Button>
          </>
        )}
      </div>
    );
  }

  return (
    <PageShell>
      <PageHeader
        title="المزودون"
        description="راجع طلبات أصحاب المزارع والقاعات. بعد الموافقة يُدار التقويم من تطبيقهم، والصور يرفعها الفريق."
        eyebrow="VIBES Admin"
        onRefresh={load}
        refreshing={loading}
        action={
          <Button
            variant="ghost"
            disabled={exporting}
            onClick={() => exportCsv(`/api/admin/providers/export${buildQuery({ q, kyc: kycFilter || undefined })}`, "providers.csv")}
          >
            تصدير CSV
          </Button>
        }
      />

      <HelpTip>المالك لا يرفع صور المكان. بعد موافقتك يفتح له تطبيق الإدارة لتسجيل الحجوزات الخارجية حتى يظهر التوفر الحقيقي. فريق VIBES يصور المكان عند النشر.</HelpTip>

      <StatStrip
        stats={[
          { label: "بانتظار المراجعة", value: pendingCount, accent: pendingCount > 0, icon: <IconUsers className="h-5 w-5" /> },
          { label: "موثّقون", value: verifiedCount, icon: <IconUsers className="h-5 w-5" /> },
          { label: "إجمالي المزودين", value: data?.total ?? items.length, icon: <IconUsers className="h-5 w-5" /> },
        ]}
      />

      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4 sm:p-5">
          <FilterChips
            value={kycFilter || "all"}
            onChange={(id) => { setPage(1); setKycFilter(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "pending", label: "قيد المراجعة" },
              { id: "verified", label: "موثّق" },
              { id: "rejected", label: "مرفوض" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input placeholder="بحث بالاسم أو الهاتف..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} className="max-w-sm flex-1" />
          </PageToolbar>
        </div>

        {loading && <div className="p-5"><SkeletonList count={4} /></div>}

        <div className="list-rows p-4 md:hidden">
          {filtered.map((item) => (
            <ListRow
              key={item.id}
              onClick={() => window.location.assign(`/providers/${item.id}`)}
              title={item.businessName ?? item.user?.name ?? "—"}
              subtitle={
                <>
                  <span dir="ltr">{item.user?.phone}</span>
                  {" · "}
                  {item._count?.properties ?? 0} مكان
                  {placeTypesLabel(item.placeTypes) ? ` · ${placeTypesLabel(item.placeTypes)}` : ""}
                  {item.requestNote ? ` · ${item.requestNote}` : ""}
                  {item.kycStatus === "REJECTED" && item.rejectionReason && (
                    <span className="mt-1 block text-danger">سبب الرفض: {item.rejectionReason}</span>
                  )}
                </>
              }
              badge={
                <Badge variant={item.verified ? "success" : "warning"}>
                  {item.verified ? "موثّق" : KYC_STATUS_LABELS[item.kycStatus] ?? item.kycStatus}
                </Badge>
              }
              footer={<ProviderActions item={item} />}
            />
          ))}
        </div>

        {!loading && (
          <DataTable
            columns={[
              { key: "name", header: "الاسم", cell: (item) => item.businessName ?? item.user?.name ?? "—" },
              {
                key: "phone",
                header: "الهاتف",
                cell: (item) => (
                  <>
                    <div dir="ltr">{item.user?.phone}</div>
                    <PhoneActions phone={item.user?.phone} compact />
                  </>
                ),
              },
              { key: "props", header: "الأماكن", cell: (item) => item._count?.properties ?? 0 },
              { key: "types", header: "النوع", cell: (item) => placeTypesLabel(item.placeTypes) || "—" },
              {
                key: "kyc",
                header: "التحقق",
                cell: (item) => (
                  <>
                    <Badge variant={item.verified ? "success" : "warning"}>
                      {item.verified ? "موثّق" : KYC_STATUS_LABELS[item.kycStatus] ?? item.kycStatus}
                    </Badge>
                    {item.kycStatus === "REJECTED" && item.rejectionReason && (
                      <div className="mt-1 max-w-[180px] text-xs text-danger">{item.rejectionReason}</div>
                    )}
                  </>
                ),
              },
              { key: "actions", header: "إجراء", cell: (item) => <ProviderActions item={item} /> },
            ]}
            rows={filtered}
            rowKey={(item) => item.id}
            empty={!filtered.length ? <EmptyState title="لا يوجد مزودون" description="جرّب تغيير الفلاتر" /> : undefined}
          />
        )}
        {data && (
          <div className="border-t border-line px-5 py-4">
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="مزود" onPage={setPage} />
          </div>
        )}
      </Card>

      <ConfirmDialog
        open={!!rejectId}
        title="رفض الحساب"
        message="اكتب سبباً واضحاً. لن يتمكن المالك من إدارة الحجوزات حتى توافق لاحقاً."
        confirmLabel="رفض"
        danger
        confirmDisabled={!rejectReason.trim()}
        onConfirm={reject}
        onClose={() => {
          setRejectId(null);
          setRejectReason("");
        }}
      >
        <Input className="mb-1" placeholder="سبب الرفض..." value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} />
      </ConfirmDialog>

      <ConfirmDialog
        open={!!revokeId}
        title="إلغاء التوثيق"
        message="سيعود الحساب لحالة المراجعة. أماكنه المنشورة تبقى كما هي، ولن يدخل بوابة الإدارة حتى توافق مجدداً."
        confirmLabel="إلغاء التوثيق"
        danger
        onConfirm={revoke}
        onClose={() => {
          setRevokeId(null);
          setRevokeReason("");
        }}
      >
        <Input className="mb-1" placeholder="السبب (اختياري)..." value={revokeReason} onChange={(e) => setRevokeReason(e.target.value)} />
      </ConfirmDialog>
    </PageShell>
  );
}
