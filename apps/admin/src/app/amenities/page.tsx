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
import { api, isAdmin } from "@/lib/api";
import { PROPERTY_TYPE_LABELS } from "@/lib/constants";
import type { Amenity, PropertyType } from "@/lib/types";

const TYPE_FILTERS: Array<{ value: string; label: string }> = [
  { value: "", label: "الكل" },
  { value: "FARM", label: PROPERTY_TYPE_LABELS.FARM },
  { value: "HALL", label: PROPERTY_TYPE_LABELS.HALL },
  { value: "DECORATION", label: PROPERTY_TYPE_LABELS.DECORATION },
];

type FormState = {
  nameAr: string;
  nameEn: string;
  icon: string;
  category: string;
  appliesTo: PropertyType[];
  sortOrder: string;
  isActive: boolean;
};

const EMPTY_FORM: FormState = {
  nameAr: "",
  nameEn: "",
  icon: "",
  category: "عام",
  appliesTo: [],
  sortOrder: "0",
  isActive: true,
};

export default function AmenitiesPage() {
  const { toast } = useToast();
  const [amenities, setAmenities] = useState<Amenity[]>([]);
  const [loading, setLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState("");
  const [q, setQ] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Amenity | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Amenity | null>(null);

  const admin = isAdmin();

  async function load() {
    const data = await api<Amenity[]>("/api/admin/amenities");
    setAmenities(data);
  }

  useEffect(() => {
    load().catch(() => undefined).finally(() => setLoading(false));
  }, []);

  const grouped = useMemo(() => {
    const qNorm = q.trim().toLowerCase();
    const visible = amenities.filter((a) => {
      if (typeFilter && !a.appliesTo.includes(typeFilter as PropertyType)) return false;
      if (qNorm && !a.nameAr.toLowerCase().includes(qNorm) && !a.nameEn.toLowerCase().includes(qNorm)) return false;
      return true;
    });
    const map = new Map<string, Amenity[]>();
    for (const amenity of visible) {
      const key = amenity.category || "عام";
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(amenity);
    }
    return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0], "ar"));
  }, [amenities, typeFilter, q]);

  function openCreate() {
    setEditing(null);
    setForm(EMPTY_FORM);
    setModalOpen(true);
  }

  function openEdit(amenity: Amenity) {
    setEditing(amenity);
    setForm({
      nameAr: amenity.nameAr,
      nameEn: amenity.nameEn,
      icon: amenity.icon,
      category: amenity.category || "عام",
      appliesTo: amenity.appliesTo,
      sortOrder: String(amenity.sortOrder ?? 0),
      isActive: amenity.isActive,
    });
    setModalOpen(true);
  }

  function toggleAppliesTo(type: PropertyType) {
    setForm((f) => ({
      ...f,
      appliesTo: f.appliesTo.includes(type)
        ? f.appliesTo.filter((t) => t !== type)
        : [...f.appliesTo, type],
    }));
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form.nameAr.trim()) return;
    setSaving(true);
    try {
      const body = JSON.stringify({
        nameAr: form.nameAr.trim(),
        nameEn: form.nameEn.trim(),
        icon: form.icon.trim(),
        category: form.category.trim() || "عام",
        appliesTo: form.appliesTo,
        sortOrder: Number(form.sortOrder) || 0,
        isActive: form.isActive,
      });
      if (editing) {
        await api(`/api/admin/amenities/${editing.id}`, { method: "PATCH", body });
        toast("تم تحديث الميزة");
      } else {
        await api("/api/admin/amenities", { method: "POST", body });
        toast("تمت إضافة الميزة");
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
      await api(`/api/admin/amenities/${deleteTarget.id}`, { method: "DELETE" });
      toast("تم حذف الميزة");
      setDeleteTarget(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
      setDeleteTarget(null);
    }
  }

  if (loading) return <LoadingBlock />;

  return (
    <AdminOnly>
      <PageShell>
        <PageHeader
          title="مزايا الأماكن"
          description="كتالوج المزايا مقسّم حسب النوع — تظهر لكل مكان المزايا المناسبة لنوعه فقط"
          eyebrow="VIBES Admin"
          action={
            admin ? (
              <Button onClick={openCreate}>+ ميزة جديدة</Button>
            ) : undefined
          }
        />

        {!admin && <HelpTip>عرض فقط — الإضافة والتعديل متاحان للمدير.</HelpTip>}

        <PageToolbar>
          <Input
            className="max-w-xs flex-1"
            placeholder="بحث عن ميزة..."
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          <div className="flex flex-wrap gap-2">
            {TYPE_FILTERS.map((f) => (
              <ToggleChip key={f.value} active={typeFilter === f.value} onClick={() => setTypeFilter(f.value)}>
                {f.label}
              </ToggleChip>
            ))}
          </div>
        </PageToolbar>

        {grouped.length === 0 && (
          <Card className="py-10 text-center text-sm text-muted">
            {amenities.length === 0
              ? "لا توجد مزايا بعد — أضف أول ميزة لتظهر في نماذج الأماكن"
              : "لا نتائج مطابقة للفلتر الحالي"}
          </Card>
        )}

        <div className="space-y-6">
          {grouped.map(([category, items]) => (
            <section key={category}>
              <div className="section-header mb-3">
                <h2>{category}</h2>
                <span className="text-xs text-muted">{items.length} ميزة</span>
              </div>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {items.map((amenity) => (
                  <Card key={amenity.id} className="flex flex-col gap-3 p-4">
                    <div className="flex items-start justify-between gap-2">
                      <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent-soft text-xl" aria-hidden>
                        {amenity.icon || "🏷️"}
                      </span>
                      <div className="flex items-center gap-1.5">
                        {!amenity.isActive && <Badge variant="muted">معطّلة</Badge>}
                        {amenity.appliesTo.map((t) => (
                          <Badge key={t} variant="default">{PROPERTY_TYPE_LABELS[t]}</Badge>
                        ))}
                      </div>
                    </div>
                    <div>
                      <div className="font-bold text-ink">{amenity.nameAr}</div>
                      {amenity.nameEn && <div className="text-xs text-muted" dir="ltr">{amenity.nameEn}</div>}
                    </div>
                    <div className="mt-auto flex items-center justify-between gap-2">
                      <span className="text-[11px] text-muted">
                        مستخدمة في {amenity._count?.properties ?? 0} مكاناً
                      </span>
                      {admin && (
                        <div className="flex gap-2 text-xs font-semibold">
                          <button type="button" className="text-accent underline" onClick={() => openEdit(amenity)}>
                            تعديل
                          </button>
                          <button type="button" className="text-danger underline" onClick={() => setDeleteTarget(amenity)}>
                            حذف
                          </button>
                        </div>
                      )}
                    </div>
                  </Card>
                ))}
              </div>
            </section>
          ))}
        </div>

        <Modal
          open={modalOpen}
          title={editing ? `تعديل: ${editing.nameAr}` : "ميزة جديدة"}
          onClose={() => setModalOpen(false)}
        >
          <form onSubmit={save} className="space-y-4">
            <div className="grid grid-cols-[1fr_80px] gap-3">
              <div>
                <Label>الاسم بالعربية</Label>
                <Input value={form.nameAr} onChange={(e) => setForm((f) => ({ ...f, nameAr: e.target.value }))} required placeholder="مثال: مسبح" />
              </div>
              <div>
                <Label>الأيقونة</Label>
                <Input value={form.icon} onChange={(e) => setForm((f) => ({ ...f, icon: e.target.value }))} placeholder="🏊" className="text-center" />
              </div>
            </div>
            <div>
              <Label>الاسم بالإنجليزية</Label>
              <Input dir="ltr" value={form.nameEn} onChange={(e) => setForm((f) => ({ ...f, nameEn: e.target.value }))} placeholder="Swimming pool" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>الفئة</Label>
                <Input value={form.category} onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))} placeholder="عام" />
              </div>
              <div>
                <Label>الترتيب</Label>
                <Input type="number" min={0} value={form.sortOrder} onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))} />
              </div>
            </div>
            <div>
              <Label>تظهر لأنواع</Label>
              <div className="flex flex-wrap gap-2">
                {(Object.keys(PROPERTY_TYPE_LABELS) as PropertyType[]).map((t) => (
                  <ToggleChip key={t} active={form.appliesTo.includes(t)} onClick={() => toggleAppliesTo(t)}>
                    {PROPERTY_TYPE_LABELS[t]}
                  </ToggleChip>
                ))}
              </div>
              <p className="mt-1.5 text-[11px] text-muted">اتركها فارغة لتظهر لكل الأنواع.</p>
            </div>
            <label className="flex cursor-pointer items-center gap-2 text-sm text-ink">
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm((f) => ({ ...f, isActive: e.target.checked }))}
                className="h-4 w-4 accent-indigo-600"
              />
              مفعّلة
            </label>
            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="ghost" onClick={() => setModalOpen(false)}>إلغاء</Button>
              <Button type="submit" disabled={saving}>{editing ? "حفظ التعديلات" : "إضافة الميزة"}</Button>
            </div>
          </form>
        </Modal>

        <ConfirmDialog
          open={!!deleteTarget}
          title="حذف الميزة"
          message={`حذف «${deleteTarget?.nameAr}»؟ لا يمكن الحذف إذا كانت مستخدمة في أماكن.`}
          confirmLabel="نعم، احذف"
          danger
          onConfirm={confirmDelete}
          onClose={() => setDeleteTarget(null)}
        />
      </PageShell>
    </AdminOnly>
  );
}
