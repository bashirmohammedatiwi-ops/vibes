"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Input, Label, Select } from "@/components/ui/input";
import { HelpTip } from "@/components/help-tip";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { AdminOnly } from "@/components/admin-only";
import { useToast } from "@/components/ui/toast";
import { api, isAdmin } from "@/lib/api";
import type { Province } from "@/lib/types";

function slugify(text: string) {
  return text
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^\w\u0600-\u06FF-]/g, "")
    .slice(0, 48) || "item";
}

export default function LocationsPage() {
  const { toast } = useToast();
  const [provinces, setProvinces] = useState<Province[]>([]);
  const [provinceName, setProvinceName] = useState("");
  const [cityProvinceId, setCityProvinceId] = useState("");
  const [cityName, setCityName] = useState("");
  const [loading, setLoading] = useState(false);
  const [initialLoading, setInitialLoading] = useState(true);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);
  const [deleteProvinceTarget, setDeleteProvinceTarget] = useState<{ id: string; name: string; cities: number } | null>(null);
  const [renameTarget, setRenameTarget] = useState<{ type: "province" | "city"; id: string; name: string } | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const [q, setQ] = useState("");

  async function load() {
    setProvinces(await api<Province[]>("/api/admin/locations/provinces"));
  }

  useEffect(() => {
    load().catch(() => undefined).finally(() => setInitialLoading(false));
  }, []);

  async function addProvince(e: React.FormEvent) {
    e.preventDefault();
    if (!provinceName.trim()) return;
    setLoading(true);
    try {
      const slug = slugify(provinceName);
      await api("/api/admin/locations/provinces", {
        method: "POST",
        body: JSON.stringify({ nameAr: provinceName.trim(), nameEn: provinceName.trim(), slug }),
      });
      setProvinceName("");
      toast("تمت إضافة المحافظة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإضافة", "error");
    } finally {
      setLoading(false);
    }
  }

  async function addCity(e: React.FormEvent) {
    e.preventDefault();
    if (!cityProvinceId || !cityName.trim()) return;
    setLoading(true);
    try {
      const slug = slugify(cityName);
      await api(`/api/admin/locations/provinces/${cityProvinceId}/cities`, {
        method: "POST",
        body: JSON.stringify({ nameAr: cityName.trim(), nameEn: cityName.trim(), slug }),
      });
      setCityName("");
      toast("تمت إضافة المدينة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإضافة", "error");
    } finally {
      setLoading(false);
    }
  }

  async function confirmRename() {
    if (!renameTarget || !renameValue.trim()) return;
    try {
      const path =
        renameTarget.type === "province"
          ? `/api/admin/locations/provinces/${renameTarget.id}`
          : `/api/admin/locations/cities/${renameTarget.id}`;
      await api(path, {
        method: "PATCH",
        body: JSON.stringify({ nameAr: renameValue.trim(), nameEn: renameValue.trim() }),
      });
      toast("تم تعديل الاسم");
      setRenameTarget(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التعديل", "error");
    }
  }

  async function confirmDeleteCity() {
    if (!deleteTarget) return;
    try {
      await api(`/api/admin/locations/cities/${deleteTarget.id}`, { method: "DELETE" });
      toast("تم حذف المدينة");
      setDeleteTarget(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف — قد تكون مرتبطة بأماكن", "error");
    }
  }

  async function confirmDeleteProvince() {
    if (!deleteProvinceTarget) return;
    try {
      await api(`/api/admin/locations/provinces/${deleteProvinceTarget.id}`, { method: "DELETE" });
      toast("تم حذف المحافظة");
      setDeleteProvinceTarget(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف — احذف مدنها أولاً", "error");
    }
  }

  if (initialLoading) return <LoadingBlock />;

  const admin = isAdmin();
  const qNorm = q.trim().toLowerCase();
  const visibleProvinces = qNorm
    ? provinces
        .map((p) => ({
          ...p,
          cities: p.cities.filter((c) => c.nameAr.toLowerCase().includes(qNorm) || p.nameAr.toLowerCase().includes(qNorm)),
        }))
        .filter((p) => p.nameAr.toLowerCase().includes(qNorm) || p.cities.length > 0)
    : provinces;

  return (
    <AdminOnly>
      <PageShell>
        <PageHeader title="المدن والمحافظات" description="تُستخدم عند إضافة الأماكن — اضغط اسم المدينة لتعديلها" eyebrow="VIBES Admin" />

        {!admin && <HelpTip>عرض فقط — إضافة أو حذف المدن متاح للمدير.</HelpTip>}

        {admin && (
          <div className="grid gap-5 lg:grid-cols-2">
            <Card>
              <h2 className="card-section-title">إضافة محافظة</h2>
              <form onSubmit={addProvince} className="space-y-3">
                <div>
                  <Label>اسم المحافظة</Label>
                  <Input value={provinceName} onChange={(e) => setProvinceName(e.target.value)} placeholder="مثال: بغداد" required />
                </div>
                <Button type="submit" disabled={loading}>إضافة المحافظة</Button>
              </form>
            </Card>

            <Card>
              <h2 className="card-section-title">إضافة مدينة</h2>
              <form onSubmit={addCity} className="space-y-3">
                <div>
                  <Label>المحافظة</Label>
                  <Select value={cityProvinceId} onChange={(e) => setCityProvinceId(e.target.value)} required>
                    <option value="">— اختر المحافظة —</option>
                    {provinces.map((p) => <option key={p.id} value={p.id}>{p.nameAr}</option>)}
                  </Select>
                </div>
                <div>
                  <Label>اسم المدينة</Label>
                  <Input value={cityName} onChange={(e) => setCityName(e.target.value)} placeholder="مثال: الكرخ" required />
                </div>
                <Button type="submit" disabled={loading}>إضافة المدينة</Button>
              </form>
            </Card>
          </div>
        )}

        <Card padded={false} className="overflow-hidden">
          <div className="border-b border-line p-4 sm:p-5">
            <div className="section-header mb-0">
              <h2>القائمة ({provinces.length} محافظة)</h2>
            </div>
            <PageToolbar className="mb-0 mt-3">
              <Input className="max-w-sm flex-1" placeholder="بحث عن محافظة أو مدينة..." value={q} onChange={(e) => setQ(e.target.value)} />
            </PageToolbar>
          </div>
          <div className="grid gap-4 p-4 md:grid-cols-2 lg:grid-cols-3 lg:p-5">
            {visibleProvinces.map((p) => (
              <div key={p.id} className="location-card">
                <div className="flex items-start justify-between gap-2">
                  <div className="font-bold text-accent">{p.nameAr}</div>
                  {admin && (
                    <div className="flex shrink-0 gap-2">
                      <button
                        type="button"
                        className="text-xs font-semibold text-accent underline"
                        onClick={() => {
                          setRenameTarget({ type: "province", id: p.id, name: p.nameAr });
                          setRenameValue(p.nameAr);
                        }}
                      >
                        تعديل
                      </button>
                      <button
                        type="button"
                        className="text-xs font-semibold text-danger underline"
                        onClick={() => setDeleteProvinceTarget({ id: p.id, name: p.nameAr, cities: p.cities.length })}
                      >
                        حذف
                      </button>
                    </div>
                  )}
                </div>
                <div className="mt-1 text-xs text-muted">{p.cities.length} مدينة</div>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {p.cities.map((c) => (
                    <span key={c.id} className="city-tag">
                      {admin ? (
                        <button
                          type="button"
                          className="hover:text-accent"
                          onClick={() => {
                            setRenameTarget({ type: "city", id: c.id, name: c.nameAr });
                            setRenameValue(c.nameAr);
                          }}
                        >
                          {c.nameAr}
                        </button>
                      ) : (
                        c.nameAr
                      )}
                      {admin && (
                        <button type="button" className="text-danger transition hover:text-danger-hover" onClick={() => setDeleteTarget({ id: c.id, name: c.nameAr })} aria-label="حذف">×</button>
                      )}
                    </span>
                  ))}
                </div>
              </div>
            ))}
            {!visibleProvinces.length && (
              <p className="py-8 text-center text-sm text-muted md:col-span-2 lg:col-span-3">لا نتائج لهذا البحث</p>
            )}
          </div>
        </Card>

        <ConfirmDialog
          open={!!renameTarget}
          title={renameTarget?.type === "province" ? "تعديل المحافظة" : "تعديل المدينة"}
          message={`الاسم الحالي: ${renameTarget?.name ?? ""}`}
          confirmLabel="حفظ"
          confirmDisabled={!renameValue.trim()}
          onConfirm={confirmRename}
          onClose={() => setRenameTarget(null)}
        >
          <Input value={renameValue} onChange={(e) => setRenameValue(e.target.value)} placeholder="الاسم الجديد" />
        </ConfirmDialog>

        <ConfirmDialog
          open={!!deleteTarget}
          title="حذف المدينة"
          message={`حذف «${deleteTarget?.name}»؟ لا يمكن إذا كانت مرتبطة بأماكن.`}
          confirmLabel="نعم، احذف"
          danger
          onConfirm={confirmDeleteCity}
          onClose={() => setDeleteTarget(null)}
        />

        <ConfirmDialog
          open={!!deleteProvinceTarget}
          title="حذف المحافظة"
          message={
            deleteProvinceTarget?.cities
              ? `«${deleteProvinceTarget.name}» تحتوي ${deleteProvinceTarget.cities} مدينة — احذف المدن أولاً.`
              : `حذف «${deleteProvinceTarget?.name}»؟ لا يمكن إذا كانت مرتبطة بأماكن.`
          }
          confirmLabel="نعم، احذف"
          danger
          confirmDisabled={!!deleteProvinceTarget?.cities}
          onConfirm={confirmDeleteProvince}
          onClose={() => setDeleteProvinceTarget(null)}
        />
      </PageShell>
    </AdminOnly>
  );
}
