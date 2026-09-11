"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { Alert } from "@/components/ui/alert";
import { EmptyState } from "@/components/empty-state";
import { LoadingBlock } from "@/components/page-header";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PhoneActions } from "@/components/phone-actions";
import { StatStrip } from "@/components/ui/stat-strip";
import { useToast } from "@/components/ui/toast";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Input } from "@/components/ui/input";
import {
  ACTIVITY_LABELS,
  BOOKING_STATUS_LABELS,
  KYC_STATUS_LABELS,
  PROPERTY_STATUS_LABELS,
  PROPERTY_TYPE_LABELS,
} from "@/lib/constants";
import { api } from "@/lib/api";
import { formatMoney, formatShortDayAr, relativeTimeAr } from "@/lib/dates";
import { IconBuilding, IconCalendar, IconUsers, IconWallet } from "@/components/nav-icons";

type ProviderDetail = {
  provider: {
    id: string;
    businessName?: string | null;
    verified: boolean;
    kycStatus: string;
    rejectionReason?: string | null;
    createdAt: string;
    user?: { id: string; name?: string | null; phone: string; isActive: boolean; createdAt: string };
    _count?: { properties: number };
  };
  properties: Array<{
    id: string;
    name: string;
    type: string;
    status: string;
    slug: string;
    city?: { nameAr: string };
    _count?: { bookings: number; reviews: number };
  }>;
  stats: {
    revenue: number | string;
    confirmedBookings: number;
    bookingsByStatus: Array<{ status: string; count: number }>;
  };
  recentBookings: Array<{
    id: string;
    status: string;
    startDate: string;
    totalPrice: number | string;
    property?: { name: string };
    user?: { name?: string | null; phone: string };
  }>;
  recentActivities: Array<{
    id: string;
    action: string;
    createdAt: string;
    user?: { name?: string | null };
  }>;
};

export default function ProviderDetailPage() {
  const params = useParams<{ id: string }>();
  const { toast } = useToast();
  const [data, setData] = useState<ProviderDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectReason, setRejectReason] = useState("");

  async function load() {
    setError(null);
    try {
      setData(await api<ProviderDetail>(`/api/admin/providers/${params.id}`));
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر التحميل");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load().catch(() => undefined);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.id]);

  async function verify() {
    try {
      await api(`/api/admin/providers/${params.id}/verify`, { method: "PATCH" });
      toast("تم توثيق المزود");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التوثيق", "error");
    }
  }

  async function reject() {
    if (!rejectReason.trim()) return;
    try {
      await api(`/api/admin/providers/${params.id}/reject`, {
        method: "PATCH",
        body: JSON.stringify({ reason: rejectReason.trim() }),
      });
      toast("تم الرفض");
      setRejectOpen(false);
      setRejectReason("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الرفض", "error");
    }
  }

  if (loading) return <LoadingBlock />;
  if (error || !data) {
    return (
      <PageShell>
        <Alert variant="danger">{error ?? "المزود غير موجود"}</Alert>
        <Link href="/providers" className="mt-4 inline-block text-sm font-bold text-accent">← المزودون</Link>
      </PageShell>
    );
  }

  const { provider, properties, stats, recentBookings, recentActivities } = data;
  const pendingBookings = stats.bookingsByStatus.find((s) => s.status === "PENDING")?.count ?? 0;

  return (
    <PageShell>
      <PageHeader
        title={provider.businessName ?? provider.user?.name ?? "مزود"}
        description={`${provider.user?.phone ?? ""} · ${KYC_STATUS_LABELS[provider.kycStatus] ?? provider.kycStatus}`}
        eyebrow="CRM · المزودون"
        action={
          <div className="flex flex-wrap gap-2">
            <Link href="/providers">
              <Button variant="ghost" size="sm">← القائمة</Button>
            </Link>
            {provider.user?.id && (
              <Link href={`/users/${provider.user.id}`}>
                <Button variant="ghost" size="sm">ملف المستخدم</Button>
              </Link>
            )}
            {!provider.verified && (
              <>
                <Button size="sm" onClick={verify}>موافقة</Button>
                <Button size="sm" variant="danger" onClick={() => setRejectOpen(true)}>رفض</Button>
              </>
            )}
          </div>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <Badge variant={provider.verified ? "success" : "warning"}>
          {provider.verified ? "موثّق" : KYC_STATUS_LABELS[provider.kycStatus]}
        </Badge>
        <PhoneActions phone={provider.user?.phone} />
        {provider.rejectionReason && (
          <span className="text-sm text-danger">سبب الرفض: {provider.rejectionReason}</span>
        )}
      </div>

      <StatStrip
        stats={[
          { label: "الأماكن", value: provider._count?.properties ?? properties.length, icon: <IconBuilding className="h-5 w-5" /> },
          { label: "حجوزات مؤكدة", value: stats.confirmedBookings, icon: <IconCalendar className="h-5 w-5" /> },
          { label: "إيرادات", value: formatMoney(stats.revenue), icon: <IconWallet className="h-5 w-5" /> },
          { label: "قيد الانتظار", value: pendingBookings, accent: pendingBookings > 0, icon: <IconUsers className="h-5 w-5" /> },
        ]}
      />

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Card padded={false} className="overflow-hidden">
            <div className="border-b border-line px-5 py-4">
              <h2 className="font-bold">أماكن المزود</h2>
            </div>
            <DataTable
              columns={[
                {
                  key: "name",
                  header: "الاسم",
                  cell: (p) => (
                    <Link href={`/properties/${p.id}/edit`} className="font-semibold hover:text-accent">
                      {p.name}
                    </Link>
                  ),
                },
                { key: "type", header: "النوع", cell: (p) => PROPERTY_TYPE_LABELS[p.type as keyof typeof PROPERTY_TYPE_LABELS] ?? p.type },
                { key: "city", header: "المدينة", cell: (p) => p.city?.nameAr ?? "—" },
                {
                  key: "status",
                  header: "الحالة",
                  cell: (p) => (
                    <Badge variant={p.status === "APPROVED" ? "success" : "warning"}>
                      {PROPERTY_STATUS_LABELS[p.status as keyof typeof PROPERTY_STATUS_LABELS] ?? p.status}
                    </Badge>
                  ),
                },
                { key: "bookings", header: "حجوزات", cell: (p) => p._count?.bookings ?? 0 },
              ]}
              rows={properties}
              rowKey={(p) => p.id}
              empty={<EmptyState title="لا أماكن بعد" description="لم يرفع المزود أي مكان" />}
            />
          </Card>

          <Card padded={false} className="overflow-hidden">
            <div className="border-b border-line px-5 py-4">
              <h2 className="font-bold">آخر الحجوزات</h2>
            </div>
            <DataTable
              columns={[
                {
                  key: "property",
                  header: "المكان",
                  cell: (b) => (
                    <Link href={`/bookings/${b.id}`} className="font-semibold hover:text-accent">
                      {b.property?.name ?? "—"}
                    </Link>
                  ),
                },
                { key: "customer", header: "العميل", cell: (b) => b.user?.name ?? b.user?.phone ?? "—" },
                { key: "date", header: "التاريخ", cell: (b) => formatShortDayAr(b.startDate) },
                {
                  key: "status",
                  header: "الحالة",
                  cell: (b) => (
                    <Badge variant={b.status === "CONFIRMED" ? "success" : "warning"}>
                      {BOOKING_STATUS_LABELS[b.status] ?? b.status}
                    </Badge>
                  ),
                },
                { key: "price", header: "المبلغ", cell: (b) => formatMoney(b.totalPrice) },
              ]}
              rows={recentBookings}
              rowKey={(b) => b.id}
              empty={<EmptyState title="لا حجوزات" />}
            />
          </Card>
        </div>

        <aside className="space-y-6">
          <Card className="space-y-3">
            <h2 className="font-bold">معلومات الحساب</h2>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between gap-2">
                <dt className="text-muted">الهاتف</dt>
                <dd dir="ltr">{provider.user?.phone}</dd>
              </div>
              <div className="flex justify-between gap-2">
                <dt className="text-muted">الاسم</dt>
                <dd>{provider.user?.name ?? "—"}</dd>
              </div>
              <div className="flex justify-between gap-2">
                <dt className="text-muted">نشط</dt>
                <dd>{provider.user?.isActive ? "نعم" : "لا"}</dd>
              </div>
              <div className="flex justify-between gap-2">
                <dt className="text-muted">تاريخ التسجيل</dt>
                <dd>{formatShortDayAr(provider.createdAt)}</dd>
              </div>
            </dl>
          </Card>

          <Card className="space-y-3">
            <h2 className="font-bold">سجل النشاط</h2>
            {recentActivities.length ? (
              <ul className="space-y-3 text-sm">
                {recentActivities.map((a) => (
                  <li key={a.id} className="border-b border-line pb-2 last:border-0">
                    <div className="font-semibold">{ACTIVITY_LABELS[a.action] ?? a.action}</div>
                    <div className="text-xs text-muted">
                      {a.user?.name ?? "الفريق"} · {relativeTimeAr(a.createdAt)}
                    </div>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-muted">لا نشاط مسجّل</p>
            )}
            <Link href="/activity" className="text-xs font-bold text-accent hover:underline">سجل النشاط الكامل</Link>
          </Card>
        </aside>
      </div>

      <ConfirmDialog
        open={rejectOpen}
        title="رفض المزود"
        message="اكتب سبب الرفض"
        confirmLabel="رفض"
        danger
        confirmDisabled={!rejectReason.trim()}
        onConfirm={reject}
        onClose={() => {
          setRejectOpen(false);
          setRejectReason("");
        }}
      >
        <Input placeholder="سبب الرفض..." value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} />
      </ConfirmDialog>
    </PageShell>
  );
}
