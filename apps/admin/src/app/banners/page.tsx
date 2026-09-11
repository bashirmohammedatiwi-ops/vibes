"use client";

import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Label } from "@/components/ui/input";
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
import type { Banner } from "@/lib/types";

/** Accepts an empty value, an in-app path, or an absolute http(s) URL. */
function isValidLink(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return true;
  if (trimmed.startsWith("/")) return true;
  try {
    const url = new URL(trimmed);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

export default function BannersPage() {
  const { toast } = useToast();
  const [items, setItems] = useState<Banner[]>([]);
  const [initialLoading, setInitialLoading] = useState(true);
  const [title, setTitle] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [linkUrl, setLinkUrl] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [editForm, setEditForm] = useState<Banner | null>(null);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  async function load() {
    setItems(await api<Banner[]>("/api/admin/banners"));
  }

  useEffect(() => {
    load().catch(() => undefined).finally(() => setInitialLoading(false));
  }, []);

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
    if (!title.trim()) {
      toast("أضف العنوان الرئيسي", "error");
      return;
    }
    if (!isValidLink(linkUrl)) {
      toast("الرابط غير صحيح — يجب أن يبدأ بـ https:// أو /", "error");
      return;
    }
    setLoading(true);
    try {
      await api("/api/admin/banners", {
        method: "POST",
        body: JSON.stringify({ title, subtitle, imageUrl, linkUrl: linkUrl.trim() || undefined, isActive: true, sortOrder: items.length }),
      });
      setTitle("");
      setSubtitle("");
      setLinkUrl("");
      setImageUrl("");
      toast("تم إضافة البانر");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإنشاء", "error");
    } finally {
      setLoading(false);
    }
  }

  async function saveEdit() {
    if (!editForm) return;
    if (!editForm.title.trim()) {
      toast("أضف العنوان الرئيسي", "error");
      return;
    }
    if (!isValidLink(editForm.linkUrl ?? "")) {
      toast("الرابط غير صحيح — يجب أن يبدأ بـ https:// أو /", "error");
      return;
    }
    try {
      await api(`/api/admin/banners/${editForm.id}`, {
        method: "PATCH",
        body: JSON.stringify({
          title: editForm.title,
          subtitle: editForm.subtitle,
          imageUrl: editForm.imageUrl,
          linkUrl: editForm.linkUrl || undefined,
          sortOrder: editForm.sortOrder,
          isActive: editForm.isActive,
        }),
      });
      setEditForm(null);
      toast("تم التحديث");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function toggle(banner: Banner) {
    await api(`/api/admin/banners/${banner.id}`, {
      method: "PATCH",
      body: JSON.stringify({
        title: banner.title,
        subtitle: banner.subtitle,
        imageUrl: banner.imageUrl,
        linkUrl: banner.linkUrl,
        sortOrder: banner.sortOrder,
        isActive: !banner.isActive,
      }),
    });
    toast(banner.isActive ? "تم إيقاف البانر" : "تم تفعيل البانر");
    await load();
  }

  async function move(index: number, dir: -1 | 1) {
    const next = index + dir;
    if (next < 0 || next >= items.length) return;
    const reordered = [...items];
    const tmp = reordered[index];
    reordered[index] = reordered[next];
    reordered[next] = tmp;
    try {
      await Promise.all(
        reordered.map((b, i) =>
          api(`/api/admin/banners/${b.id}`, {
            method: "PATCH",
            body: JSON.stringify({
              title: b.title,
              subtitle: b.subtitle,
              imageUrl: b.imageUrl,
              linkUrl: b.linkUrl,
              isActive: b.isActive,
              sortOrder: i,
            }),
          }),
        ),
      );
      toast("تم تغيير الترتيب");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر تغيير الترتيب", "error");
    }
  }

  async function remove() {
    if (!deleteId) return;
    await api(`/api/admin/banners/${deleteId}`, { method: "DELETE" });
    toast("تم الحذف");
    setDeleteId(null);
    await load();
  }

  return (
    <PageShell>
      <PageHeader title="البانرات" description="الإعلانات التي تظهر في أعلى التطبيق" eyebrow="VIBES Admin" />

      <HelpTip>ارفع صورة أولاً ثم أضف العنوان — استخدم ↑ ↓ لترتيب ظهور البانرات في التطبيق</HelpTip>

      <Card>
        <h2 className="card-section-title">إضافة بانر جديد</h2>
        <form onSubmit={create} className="space-y-4">
          <SimpleUpload
            onFiles={(files) => files[0] && uploadImage(files[0], "new")}
            uploading={uploading}
            previewUrl={imageUrl || null}
            label="ارفع صورة البانر"
            hint="يفضل 1200×500 بكسل"
          />
          <div className="grid gap-3 md:grid-cols-2">
            <div>
              <Label>العنوان الرئيسي *</Label>
              <Input value={title} onChange={(e) => setTitle(e.target.value)} required placeholder="مثال: عروض الصيف" />
            </div>
            <div>
              <Label>العنوان الفرعي</Label>
              <Input value={subtitle} onChange={(e) => setSubtitle(e.target.value)} placeholder="اختياري" />
            </div>
            <div className="md:col-span-2">
              <Label>رابط عند الضغط (اختياري)</Label>
              <Input value={linkUrl} onChange={(e) => setLinkUrl(e.target.value)} dir="ltr" placeholder="https://... أو /places/slug" />
              {!isValidLink(linkUrl) && (
                <p className="mt-1 text-xs text-danger">رابط غير صحيح — استخدم https:// أو مساراً يبدأ بـ /</p>
              )}
            </div>
          </div>
          <Button type="submit" disabled={loading || !imageUrl}>{loading ? "جاري الإضافة..." : "إضافة البانر"}</Button>
        </form>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        {initialLoading ? (
          <SkeletonList count={4} />
        ) : items.map((banner, i) => (
          <div key={banner.id} className="banner-card">
            <div className="aspect-[21/9] bg-surface">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={banner.imageUrl} alt={banner.title} className="h-full w-full object-cover" />
            </div>
            <div className="p-4">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <div className="font-bold">{banner.title}</div>
                  {banner.subtitle && <div className="text-sm text-muted">{banner.subtitle}</div>}
                </div>
                <Badge variant={banner.isActive ? "success" : "muted"}>{banner.isActive ? "يعمل" : "متوقف"}</Badge>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                <Button variant="ghost" className="px-2 py-1 text-xs" disabled={i === 0} onClick={() => move(i, -1)}>↑ أعلى</Button>
                <Button variant="ghost" className="px-2 py-1 text-xs" disabled={i === items.length - 1} onClick={() => move(i, 1)}>↓ أسفل</Button>
                <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setEditForm(banner)}>تعديل</Button>
                <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => toggle(banner)}>
                  {banner.isActive ? "إيقاف" : "تشغيل"}
                </Button>
                <Button variant="danger" className="px-2 py-1 text-xs" onClick={() => setDeleteId(banner.id)}>حذف</Button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {!initialLoading && !items.length && (
        <EmptyState title="لا توجد بانرات بعد" description="ارفع صورة وأضف عنواناً ليظهر الإعلان في التطبيق" />
      )}

      <Modal open={!!editForm} title="تعديل البانر" onClose={() => setEditForm(null)}>
        {editForm && (
          <div className="space-y-3">
            <SimpleUpload
              onFiles={(files) => files[0] && uploadImage(files[0], "edit")}
              uploading={uploading}
              previewUrl={editForm.imageUrl || null}
              label="تغيير الصورة"
            />
            <div><Label>العنوان</Label><Input value={editForm.title} onChange={(e) => setEditForm({ ...editForm, title: e.target.value })} /></div>
            <div><Label>العنوان الفرعي</Label><Input value={editForm.subtitle} onChange={(e) => setEditForm({ ...editForm, subtitle: e.target.value })} /></div>
            <div><Label>رابط عند الضغط</Label><Input dir="ltr" value={editForm.linkUrl ?? ""} onChange={(e) => setEditForm({ ...editForm, linkUrl: e.target.value })} /></div>
            <Button onClick={saveEdit}>حفظ التعديلات</Button>
          </div>
        )}
      </Modal>

      <ConfirmDialog
        open={!!deleteId}
        title="حذف البانر"
        message="حذف هذا البانر نهائياً؟"
        confirmLabel="حذف"
        danger
        onConfirm={remove}
        onClose={() => setDeleteId(null)}
      />
    </PageShell>
  );
}
