"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DetailCard } from "@/components/ui/detail-card";
import { ErrorBanner } from "@/components/ui/error-banner";
import { ListRow } from "@/components/ui/list-row";
import { Input, Label, Select } from "@/components/ui/input";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { useToast } from "@/components/ui/toast";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PhoneActions } from "@/components/phone-actions";
import { BOOKING_STATUS_LABELS, KYC_STATUS_LABELS, USER_ROLE_LABELS } from "@/lib/constants";
import { api, isAdmin } from "@/lib/api";
import { formatMoney } from "@/lib/dates";

type UserDetail = {
  id: string;
  phone: string;
  name?: string | null;
  role: string;
  isActive: boolean;
  createdAt: string;
  provider?: { id: string; businessName?: string | null; verified: boolean; kycStatus: string } | null;
  bookings: Array<{ id: string; status: string; totalPrice: number | string; startDate: string; property?: { name: string } }>;
  _count?: { bookings: number; reviews: number };
};

export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const { toast } = useToast();
  const [user, setUser] = useState<UserDetail | null>(null);
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [deactivateOpen, setDeactivateOpen] = useState(false);
  const [pendingRole, setPendingRole] = useState<string | null>(null);

  const load = useCallback(async () => {
    const data = await api<UserDetail>(`/api/admin/users/${params.id}`);
    setUser(data);
    setName(data.name ?? "");
  }, [params.id]);

  useEffect(() => {
    load()
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, [load]);

  async function saveName() {
    try {
      await api(`/api/admin/users/${params.id}`, { method: "PATCH", body: JSON.stringify({ name }) });
      toast("تم حفظ الاسم");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    }
  }

  const admin = isAdmin();

  async function toggleActive() {
    if (!user || !admin) return;
    try {
      await api(`/api/admin/users/${params.id}`, { method: "PATCH", body: JSON.stringify({ isActive: !user.isActive }) });
      toast(user.isActive ? "تم التعطيل" : "تم التفعيل");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  function onRoleChange(role: string) {
    if (!user) return;
    if (role === "ADMIN" && user.role !== "ADMIN") {
      setPendingRole(role);
      return;
    }
    updateRole(role);
  }

  async function updateRole(role: string) {
    if (!admin) return;
    try {
      await api(`/api/admin/users/${params.id}`, { method: "PATCH", body: JSON.stringify({ role }) });
      toast("تم تحديث الدور");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  if (error) {
    return (
      <ErrorBanner
        message={error}
        onRetry={() => { setError(null); setLoading(true); load().catch((err: Error) => setError(err.message)).finally(() => setLoading(false)); }}
        backHref="/users"
        backLabel="العودة للمستخدمين"
      />
    );
  }
  if (loading || !user) return <LoadingBlock />;

  return (
    <PageShell className="page-shell-narrow">
      <PageHeader
        title={user.name ?? user.phone}
        description={user.phone}
        eyebrow="VIBES Admin"
        back={{ href: "/users", label: "العودة للمستخدمين" }}
        action={<Badge variant={user.isActive ? "success" : "danger"}>{user.isActive ? "نشط" : "معطّل"}</Badge>}
      />

      <PhoneActions phone={user.phone} />

      <DetailCard title="معلومات الحساب">
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <Label>الاسم</Label>
            <div className="mt-1 flex gap-2">
              <Input value={name} onChange={(e) => setName(e.target.value)} />
              <Button variant="ghost" onClick={saveName}>حفظ</Button>
            </div>
          </div>
          <div>
            <Label>الدور</Label>
            {admin ? (
              <Select className="mt-1" value={user.role} onChange={(e) => onRoleChange(e.target.value)}>
                {Object.entries(USER_ROLE_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>{v}</option>
                ))}
              </Select>
            ) : (
              <div className="mt-2 py-2 text-sm font-semibold">{USER_ROLE_LABELS[user.role] ?? user.role}</div>
            )}
          </div>
        </div>
        <div className="mt-4 flex flex-wrap gap-4 text-sm">
          <Badge>{user._count?.bookings ?? 0} حجز</Badge>
          <Badge variant="muted">{user._count?.reviews ?? 0} تقييم</Badge>
          <span className="text-muted">انضم {new Date(user.createdAt).toLocaleDateString("ar-IQ")}</span>
        </div>
        {admin && (
          user.isActive ? (
            <Button variant="ghost" className="mt-4" onClick={() => setDeactivateOpen(true)}>تعطيل الحساب</Button>
          ) : (
            <Button variant="ghost" className="mt-4" onClick={toggleActive}>تفعيل الحساب</Button>
          )
        )}
      </DetailCard>

      {user.provider && (
        <DetailCard title="ملف المزود">
          <p className="text-sm leading-7">
            {user.provider.businessName ?? "—"} · {user.provider.verified ? "موثّق" : (KYC_STATUS_LABELS[user.provider.kycStatus] ?? user.provider.kycStatus)}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Link href={`/providers/${user.provider.id}`} className="text-sm font-semibold text-accent underline">CRM المزود</Link>
            <Link href={`/bookings/new?phone=${encodeURIComponent(user.phone)}&name=${encodeURIComponent(user.name ?? "")}`} className="text-sm font-semibold text-accent underline">حجز للعميل</Link>
          </div>
        </DetailCard>
      )}

      <DetailCard title="آخر الحجوزات">
        <div className="list-rows">
          {user.bookings.map((b) => (
            <Link key={b.id} href={`/bookings/${b.id}`}>
              <ListRow
                title={b.property?.name ?? "—"}
                meta={<span className="text-muted">{BOOKING_STATUS_LABELS[b.status] ?? b.status} · {formatMoney(b.totalPrice)}</span>}
              />
            </Link>
          ))}
          {!user.bookings.length && <p className="text-sm text-muted">لا توجد حجوزات</p>}
        </div>
      </DetailCard>

      <ConfirmDialog
        open={!!pendingRole}
        title="ترقية إلى مدير"
        message="هذا الحساب سيصبح مديراً ويستطيع تغيير كل شيء في اللوحة. متأكد؟"
        confirmLabel="نعم، ترقية"
        danger
        onConfirm={async () => {
          if (!pendingRole) return;
          await updateRole(pendingRole);
          setPendingRole(null);
        }}
        onClose={() => setPendingRole(null)}
      />
      <ConfirmDialog
        open={deactivateOpen}
        title="تعطيل الحساب"
        message="تعطيل هذا الحساب يمنع الدخول والحجز. يمكنك تفعيله لاحقاً."
        confirmLabel="تعطيل"
        danger
        onConfirm={async () => {
          await toggleActive();
          setDeactivateOpen(false);
        }}
        onClose={() => setDeactivateOpen(false)}
      />
    </PageShell>
  );
}
