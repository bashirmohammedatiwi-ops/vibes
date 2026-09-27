"use client";

import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Label, Select } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { SimpleUpload } from "@/components/simple-upload";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { api, uploadFiles } from "@/lib/api";
import type { HomeSpotlight, Paginated, Property } from "@/lib/types";

export default function SpotlightsPage() {
  const { toast } = useToast();
  const [items, setItems] = useState<HomeSpotlight[]>([]);
  const [places, setPlaces] = useState<Property[]>([]);
  const [initialLoading, setInitialLoading] = useState(true);
  const [title, setTitle] = useState("");
  const [propertyId, setPropertyId] = useState("");
  const [height, setHeight] = useState("176");
  const [imageUrl, setImageUrl] = useState("");
  const [editForm, setEditForm] = useState<HomeSpotlight | null>(null);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  async function load() {
    const [spotlights, properties] = await Promise.all([
      api<HomeSpotlight[]>("/api/admin/spotlights"),
      api<Paginated<Property>>("/api/admin/properties?status=APPROVED&pageSize=100"),
    ]);
    setItems(spotlights);
    setPlaces(properties.items);
    if (!propertyId && properties.items[0]) setPropertyId(properties.items[0].id);
  }

  useEffect(() => {
    load().catch(() => undefined).finally(() => setInitialLoading(false));
  }, []);

  function parsedHeight(value: string) {
    const next = Number(value);
    if (!Number.isFinite(next)) return 176;
    return Math.min(280, Math.max(140, Math.round(next)));
  }

  async function uploadImage(file: File, target: "new" | "edit") {
    setUploading(true);
    try {
      const media = await uploadFiles<{ url: string }>("/api/media/upload", "file", [file]);
      if (target === "new") setImageUrl(media.url);
      else if (editForm) setEditForm({ ...editForm, imageUrl: media.url });
      toast("تم رفع الصورة");
    } catch (err) {
      toast(err instanceof Error ? err.message : "فشل الرفع", "error");
    } finally {
      setUploading(false);
    }
  }

  async function create(event: React.FormEvent) {
    event.preventDefault();
    if (!imageUrl) {
      toast("ارفع صورة أولاً", "error");
      return;
    }
    if (!propertyId) {
      toast("اختر المكان المرتبط", "error");
      return;
    }
    setLoading(true);
    try {
      await api("/api/admin/spotlights", {
        method: "POST",
        body: JSON.stringify({
          title: title.trim(),
          imageUrl,
          propertyId,
          height: parsedHeight(height),
          isActive: true,
          sortOrder: items.length,
        }),
      });
      setTitle("");
      setImageUrl("");
      setHeight("176");
      toast("أُضيف المكان المميز");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإنشاء", "error");
    } finally {
      setLoading(false);
    }
  }

  async function saveEdit() {
    if (!editForm) return;
    if (!editForm.propertyId) {
      toast("اختر المكان المرتبط", "error");
      return;
    }
    try {
      await api(`/api/admin/spotlights/${editForm.id}`, {
        method: "PATCH",
        body: JSON.stringify({
          title: editForm.title,
          imageUrl: editForm.imageUrl,
          propertyId: editForm.propertyId,
          height: parsedHeight(String(editForm.height)),
          sortOrder: editForm.sortOrder,
          isActive: editForm.isActive,
        }),
      });
      setEditForm(null);
      toast("تم الحفظ");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    }
  }

  async function toggle(item: HomeSpotlight) {
    await api(`/api/admin/spotlights/${item.id}`, {
      method: "PATCH",
      body: JSON.stringify({ isActive: !item.isActive }),
    });
    toast(item.isActive ? "أُوقف العرض" : "ظهر في الرئيسية");
    await load();
  }

  async function remove() {
    if (!deleteId) return;
    await api(`/api/admin/spotlights/${deleteId}`, { method: "DELETE" });
    toast("تم الحذف");
    setDeleteId(null);
    await load();
  }

  return (
    <PageShell>
      <PageHeader
        title="أماكن مميزة"
        description="صور متحركة بحجم بانر في الصفحة الرئيسية، كل صورة تفتح مكاناً تحدده"
        eyebrow="VIBES Admin"
      />
      <HelpTip>
        ارفع صورة عريضة، اربطها بمكان، واختر الارتفاع بين ١٤٠ و ٢٨٠. التطبيق يحرّك الصورة ببطء ويفتح المكان عند الضغط.
      </HelpTip>

      <Card>
        <h2 className="card-section-title">إضافة مكان مميز</h2>
        <form onSubmit={create} className="space-y-4">
          <SimpleUpload
            onFiles={(files) => files[0] && uploadImage(files[0], "new")}
            uploading={uploading}
            previewUrl={imageUrl || null}
            label="ارفع صورة البانر"
            hint="يفضل 1200×560 بكسل"
          />
          <div className="grid gap-3 md:grid-cols-2">
            <div>
              <Label>عنوان يظهر على الصورة</Label>
              <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="اختياري" />
            </div>
            <div>
              <Label>الارتفاع في التطبيق</Label>
              <Input
                type="number"
                min={140}
                max={280}
                value={height}
                onChange={(e) => setHeight(e.target.value)}
              />
            </div>
            <div className="md:col-span-2">
              <Label>المكان المرتبط *</Label>
              <Select value={propertyId} onChange={(e) => setPropertyId(e.target.value)} required>
                <option value="">اختر مكاناً</option>
                {places.map((place) => (
                  <option key={place.id} value={place.id}>
                    {place.name}
                  </option>
                ))}
              </Select>
            </div>
          </div>
          <Button type="submit" disabled={loading || !imageUrl}>
            {loading ? "جاري الإضافة..." : "إضافة"}
          </Button>
        </form>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        {initialLoading ? (
          <SkeletonList count={2} />
        ) : items.map((item) => (
          <div key={item.id} className="banner-card">
            <div className="aspect-[21/9] bg-surface">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={item.imageUrl} alt={item.title || item.property?.name || ""} className="h-full w-full object-cover" />
            </div>
            <div className="p-4">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <div className="font-bold">{item.title || item.property?.name || "مكان مميز"}</div>
                  <div className="text-sm text-muted">
                    {item.property?.name ?? "بدون مكان"} · ارتفاع {item.height}
                  </div>
                </div>
                <Badge variant={item.isActive ? "success" : "muted"}>{item.isActive ? "يعمل" : "متوقف"}</Badge>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setEditForm(item)}>تعديل</Button>
                <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => toggle(item)}>
                  {item.isActive ? "إيقاف" : "تشغيل"}
                </Button>
                <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => setDeleteId(item.id)}>حذف</Button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {!initialLoading && !items.length && (
        <EmptyState title="لا توجد أماكن مميزة" description="ارفع صورة واربطها بمكان لتظهر في أسفل أقسام الرئيسية" />
      )}

      <Modal open={!!editForm} title="تعديل المكان المميز" onClose={() => setEditForm(null)}>
        {editForm && (
          <div className="space-y-3">
            <SimpleUpload
              onFiles={(files) => files[0] && uploadImage(files[0], "edit")}
              uploading={uploading}
              previewUrl={editForm.imageUrl}
              label="الصورة"
            />
            <div>
              <Label>العنوان</Label>
              <Input value={editForm.title} onChange={(e) => setEditForm({ ...editForm, title: e.target.value })} />
            </div>
            <div>
              <Label>الارتفاع</Label>
              <Input
                type="number"
                min={140}
                max={280}
                value={editForm.height}
                onChange={(e) => setEditForm({ ...editForm, height: Number(e.target.value) })}
              />
            </div>
            <div>
              <Label>المكان</Label>
              <Select
                value={editForm.propertyId}
                onChange={(e) => setEditForm({ ...editForm, propertyId: e.target.value })}
              >
                {places.map((place) => (
                  <option key={place.id} value={place.id}>{place.name}</option>
                ))}
              </Select>
            </div>
            <Button onClick={saveEdit}>حفظ</Button>
          </div>
        )}
      </Modal>

      <ConfirmDialog
        open={!!deleteId}
        title="حذف العرض"
        message="حذف هذا المكان المميز من الصفحة الرئيسية؟"
        confirmLabel="حذف"
        danger
        onConfirm={remove}
        onClose={() => setDeleteId(null)}
      />
    </PageShell>
  );
}
