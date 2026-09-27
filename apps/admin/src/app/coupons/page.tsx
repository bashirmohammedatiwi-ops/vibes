"use client";

import { useEffect, useMemo, useState } from "react";
import { AdminOnly } from "@/components/admin-only";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { HelpTip } from "@/components/help-tip";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Label, Select } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { useToast } from "@/components/ui/toast";
import { api } from "@/lib/api";
import { formatMoney } from "@/lib/dates";
import { PROPERTY_TYPE_LABELS } from "@/lib/constants";
import type { Paginated, PropertyType } from "@/lib/types";

type Coupon = {
  id: string;
  code: string;
  description: string;
  discountType: "PERCENT" | "FIXED";
  discountValue: number | string;
  minBookingTotal?: number | string | null;
  maxUses?: number | null;
  maxUsesPerUser?: number | null;
  usedCount: number;
  startsAt?: string | null;
  expiresAt?: string | null;
  appliesToTypes: PropertyType[];
  property?: { id: string; name: string } | null;
  isActive: boolean;
  _count?: { redemptions: number };
};

type FormState = {
  code: string;
  description: string;
  discountType: "PERCENT" | "FIXED";
  discountValue: string;
  minBookingTotal: string;
  maxUses: string;
  maxUsesPerUser: string;
  startsAt: string;
  expiresAt: string;
  appliesToTypes: PropertyType[];
  propertyId: string;
  isActive: boolean;
};

const EMPTY_FORM: FormState = {
  code: "",
  description: "",
  discountType: "PERCENT",
  discountValue: "",
  minBookingTotal: "",
  maxUses: "",
  maxUsesPerUser: "",
  startsAt: "",
  expiresAt: "",
  appliesToTypes: [],
  propertyId: "",
  isActive: true,
};

function formatDateTime(value?: string | null) {
  if (!value) return "—";
  return new Date(value).toLocaleDateString("ar-IQ", { year: "numeric", month: "short", day: "numeric" });
}

function couponState(coupon: Coupon) {
  const now = new Date();
  if (!coupon.isActive) return { label: "معطّل", variant: "muted" as const };
  if (coupon.expiresAt && new Date(coupon.expiresAt) < now) return { label: "منتهي", variant: "danger" as const };
  if (coupon.startsAt && new Date(coupon.startsAt) > now) return { label: "لم يبدأ", variant: "warning" as const };
  if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) return { label: "استُهلك", variant: "danger" as const };
  return { label: "نشط", variant: "success" as const };
}

export default function CouponsPage() {
  const { toast } = useToast();
  const [data, setData] = useState<Paginated<Coupon> | null>(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [activeOnly, setActiveOnly] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Coupon | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Coupon | null>(null);
  const [properties, setProperties] = useState<Array<{ id: string; name: string }>>([]);

  async function load() {
    const params = new URLSearchParams({ page: String(page), pageSize: "20" });
    if (q.trim()) params.set("q", q.trim());
    if (activeOnly) params.set("activeOnly", "true");
    const result = await api<Paginated<Coupon>>(`/api/admin/coupons?${params.toString()}`);
    setData(result);
  }

  useEffect(() => {
    load().catch(() => undefined).finally(() => setLoading(false));
  }, [page, activeOnly]);

  useEffect(() => {
    api<Paginated<{ id: string; name: string }>>("/api/admin/properties?pageSize=200")
      .then((res) => setProperties(res.items.map((p) => ({ id: p.id, name: p.name }))))
      .catch(() => undefined);
  }, []);

  function openCreate() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setModalOpen(true);
  }

  function openEdit(coupon: Coupon) {
    setEditing(coupon);
    setForm({
      code: coupon.code,
      description: coupon.description,
      discountType: coupon.discountType,
      discountValue: String(coupon.discountValue),
      minBookingTotal: coupon.minBookingTotal != null ? String(coupon.minBookingTotal) : "",
      maxUses: coupon.maxUses != null ? String(coupon.maxUses) : "",
      maxUsesPerUser: coupon.maxUsesPerUser != null ? String(coupon.maxUsesPerUser) : "",
      startsAt: coupon.startsAt ? coupon.startsAt.slice(0, 10) : "",
      expiresAt: coupon.expiresAt ? coupon.expiresAt.slice(0, 10) : "",
      appliesToTypes: coupon.appliesToTypes,
      propertyId: coupon.property?.id ?? "",
      isActive: coupon.isActive,
    });
    setModalOpen(true);
  }

  function toggleType(type: PropertyType) {
    setForm((f) => ({
      ...f,
      appliesToTypes: f.appliesToTypes.includes(type)
        ? f.appliesToTypes.filter((t) => t !== type)
        : [...f.appliesToTypes, type],
    }));
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form.code.trim() || !form.discountValue) return;
    setSaving(true);
    try {
      const body = JSON.stringify({
        code: form.code.trim().toUpperCase(),
        description: form.description.trim(),
        discountType: form.discountType,
        discountValue: Number(form.discountValue),
        minBookingTotal: form.minBookingTotal ? Number(form.minBookingTotal) : undefined,
        maxUses: form.maxUses ? Number(form.maxUses) : undefined,
        maxUsesPerUser: form.maxUsesPerUser ? Number(form.maxUsesPerUser) : undefined,
        startsAt: form.startsAt || undefined,
        expiresAt: form.expiresAt || undefined,
        appliesToTypes: form.appliesToTypes,
        propertyId: form.propertyId || undefined,
        isActive: form.isActive,
      });
      if (editing) {
        await api(`/api/admin/coupons/${editing.id}`, { method: "PATCH", body });
        toast("تم تحديث الكوبون");
      } else {
        await api("/api/admin/coupons", { method: "POST", body });
        toast("تم إنشاء الكوبون");
      }
      setModalOpen(false);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  async function confirmDelete() {
    if (!deleteTarget) return;
    try {
      const result = await api<{ deleted?: boolean; deactivated?: boolean }>(`/api/admin/coupons/${deleteTarget.id}`, { method: "DELETE" });
      toast(result.deactivated ? "الكوبون مستخدم — تم تعطيله بدلاً من حذفه" : "تم حذف الكوبون");
      setDeleteTarget(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
      setDeleteTarget(null);
    }
  }

  const totalPages = data?.totalPages ?? 1;

  const summary = useMemo(() => {
    const items = data?.items ?? [];
    return {
      active: items.filter((c) => couponState(c).label === "نشط").length,
      uses: items.reduce((sum, c) => sum + (c._count?.redemptions ?? 0), 0),
    };
  }, [data]);

  if (loading) return <LoadingBlock />;

  return (
    <AdminOnly>
      <PageShell>
        <PageHeader
          title="الكوبونات والعروض"
          description="أكواد خصم بنسبة أو مبلغ — حدود استخدام وفترات صلاحية وحصر بالأنواع أو الأماكن"
          eyebrow="VIBES Admin"
          action={<Button onClick={openCreate}>+ كوبون جديد</Button>}
        />
        <HelpTip>اترك الوصف فارغاً ليبقى الكوبون سرياً — يظهر في التطبيق فقط إن كان نشطاً وله وصف.</HelpTip>

        <div className="grid gap-3 sm:grid-cols-3">
          <Card className="p-4"><div className="text-xs text-muted">نشطة (بالصفحة)</div><div className="text-xl font-bold">{summary.active}</div></Card>
          <Card className="p-4"><div className="text-xs text-muted">مرات استخدام (بالصفحة)</div><div className="text-xl font-bold">{summary.uses}</div></Card>
          <Card className="p-4"><div className="text-xs text-muted">الإجمالي</div><div className="text-xl font-bold">{data?.total ?? 0}</div></Card>
        </div>

        <PageToolbar>
          <Input
            className="max-w-xs flex-1"
            placeholder="بحث برمز الخصم..."
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && load().catch(() => undefined)}
          />
          <ToggleChip active={activeOnly} onClick={() => setActiveOnly((v) => !v)}>النشطة فقط</ToggleChip>
        </PageToolbar>

        <Card padded={false} className="overflow-hidden">
          {!data?.items.length ? (
            <p className="py-10 text-center text-sm text-muted">لا كوبونات بعد — أنشئ أول عرض لتحفيز الحجوزات</p>
          ) : (
            <div className="divide-y divide-line">
              {data.items.map((coupon) => {
                const state = couponState(coupon);
                return (
                  <div key={coupon.id} className="flex flex-wrap items-center justify-between gap-3 p-4">
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="rounded-lg bg-accent-soft px-2.5 py-1 font-mono text-sm font-bold text-accent" dir="ltr">
                          {coupon.code}
                        </span>
                        <Badge variant={state.variant}>{state.label}</Badge>
                        <span className="font-bold text-ink">
                          {coupon.discountType === "PERCENT" ? `${Number(coupon.discountValue)}%` : formatMoney(coupon.discountValue)}
                        </span>
                        {coupon.minBookingTotal != null && (
                          <Badge variant="muted">حد أدنى {formatMoney(coupon.minBookingTotal)}</Badge>
                        )}
                      </div>
                      <p className="mt-1 text-xs text-muted">
                        استخدام: {coupon._count?.redemptions ?? 0}{coupon.maxUses != null ? ` / ${coupon.maxUses}` : " (بلا حد)"}
                        {coupon.maxUsesPerUser != null && ` · لكل مستخدم ${coupon.maxUsesPerUser}`}
                        {" · صلاحية: "}{formatDateTime(coupon.startsAt)} → {formatDateTime(coupon.expiresAt)}
                        {coupon.appliesToTypes.length > 0 && ` · ${coupon.appliesToTypes.map((t) => PROPERTY_TYPE_LABELS[t]).join("، ")}`}
                        {coupon.property && ` · حصر بمكان: ${coupon.property.name}`}
                      </p>
                    </div>
                    <div className="flex gap-2 text-xs font-semibold">
                      <button type="button" className="text-accent underline" onClick={() => openEdit(coupon)}>تعديل</button>
                      <button type="button" className="text-danger underline" onClick={() => setDeleteTarget(coupon)}>حذف</button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </Card>

        {totalPages > 1 && (
          <div className="flex items-center justify-between text-sm">
            <Button variant="ghost" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>السابق</Button>
            <span className="text-muted">صفحة {page} من {totalPages}</span>
            <Button variant="ghost" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>التالي</Button>
          </div>
        )}

        <Modal open={modalOpen} title={editing ? `تعديل: ${editing.code}` : "كوبون جديد"} onClose={() => setModalOpen(false)}>
          <form onSubmit={save} className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>الرمز *</Label>
                <Input dir="ltr" value={form.code} onChange={(e) => setForm((f) => ({ ...f, code: e.target.value.toUpperCase() }))} placeholder="SUMMER25" required />
              </div>
              <div>
                <Label>النوع</Label>
                <Select value={form.discountType} onChange={(e) => setForm((f) => ({ ...f, discountType: e.target.value as FormState["discountType"] }))}>
                  <option value="PERCENT">نسبة مئوية %</option>
                  <option value="FIXED">مبلغ ثابت (د.ع)</option>
                </Select>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>{form.discountType === "PERCENT" ? "نسبة الخصم (0-100) *" : "مبلغ الخصم (د.ع) *"}</Label>
                <Input type="number" min={0} value={form.discountValue} onChange={(e) => setForm((f) => ({ ...f, discountValue: e.target.value }))} required />
              </div>
              <div>
                <Label>الحد الأدنى للحجز</Label>
                <Input type="number" min={0} value={form.minBookingTotal} onChange={(e) => setForm((f) => ({ ...f, minBookingTotal: e.target.value }))} placeholder="اختياري" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>حد الاستخدام الكلي</Label>
                <Input type="number" min={1} value={form.maxUses} onChange={(e) => setForm((f) => ({ ...f, maxUses: e.target.value }))} placeholder="غير محدود" />
              </div>
              <div>
                <Label>لكل مستخدم</Label>
                <Input type="number" min={1} value={form.maxUsesPerUser} onChange={(e) => setForm((f) => ({ ...f, maxUsesPerUser: e.target.value }))} placeholder="غير محدود" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>يبدأ</Label>
                <Input type="date" value={form.startsAt} onChange={(e) => setForm((f) => ({ ...f, startsAt: e.target.value }))} />
              </div>
              <div>
                <Label>ينتهي</Label>
                <Input type="date" value={form.expiresAt} onChange={(e) => setForm((f) => ({ ...f, expiresAt: e.target.value }))} />
              </div>
            </div>
            <div>
              <Label>ينطبق على أنواع</Label>
              <div className="flex flex-wrap gap-2">
                {(Object.keys(PROPERTY_TYPE_LABELS) as PropertyType[]).map((t) => (
                  <ToggleChip key={t} active={form.appliesToTypes.includes(t)} onClick={() => toggleType(t)}>
                    {PROPERTY_TYPE_LABELS[t]}
                  </ToggleChip>
                ))}
              </div>
            </div>
            <div>
              <Label>حصر بمكان محدد</Label>
              <Select value={form.propertyId} onChange={(e) => setForm((f) => ({ ...f, propertyId: e.target.value }))}>
                <option value="">كل الأماكن</option>
                {properties.map((p) => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </Select>
            </div>
            <label className="flex cursor-pointer items-center gap-2 text-sm text-ink">
              <input type="checkbox" checked={form.isActive} onChange={(e) => setForm((f) => ({ ...f, isActive: e.target.checked }))} className="h-4 w-4 accent-indigo-600" />
              مفعّل
            </label>
            <div className="flex justify-end gap-2 pt-1">
              <Button type="button" variant="ghost" onClick={() => setModalOpen(false)}>إلغاء</Button>
              <Button type="submit" disabled={saving}>{editing ? "حفظ" : "إنشاء الكوبون"}</Button>
            </div>
          </form>
        </Modal>

        <ConfirmDialog
          open={!!deleteTarget}
          title="حذف الكوبون"
          message={deleteTarget?._count?.redemptions ? "الكوبون مستخدم في حجوزات — سيُعطّل بدلاً من حذفه للحفاظ على السجل." : `حذف «${deleteTarget?.code}»؟`}
          confirmLabel="تأكيد"
          danger
          onConfirm={confirmDelete}
          onClose={() => setDeleteTarget(null)}
        />
      </PageShell>
    </AdminOnly>
  );
}
