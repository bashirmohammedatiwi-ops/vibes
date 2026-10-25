"use client";

import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Alert } from "@/components/ui/alert";
import { SimpleUpload } from "@/components/simple-upload";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Modal } from "@/components/ui/modal";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { useToast } from "@/components/ui/toast";
import { api, uploadFilesWithProgress } from "@/lib/api";
import { RATIO_OPTIONS, type MediaItem, type TargetRatio } from "@/lib/types";

const MEDIA_FILTERS = [
  { value: "", label: "الكل" },
  { value: "IMAGE", label: "الصور" },
  { value: "VIDEO", label: "فيديو المعرض" },
  { value: "REEL", label: "ريلز استكشف" },
  { value: "PANORAMA", label: "360°" },
];

type UploadState = {
  active: boolean;
  percent: number;
  name: string;
};

type Props = {
  propertyId: string;
  initialMedia?: MediaItem[];
  onChange?: (media: MediaItem[]) => void;
};

function formatDuration(seconds?: number | null) {
  if (!seconds) return null;
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${minutes}:${String(rest).padStart(2, "0")}`;
}

/** Polls PROCESSING videos until the pipeline resolves them. */
function useProcessingPoller(
  items: MediaItem[],
  onResolved: (updated: MediaItem) => void,
) {
  const processingIds = items
    .filter((item) => item.status === "PROCESSING" || item.status === "UPLOADING")
    .map((item) => item.id)
    .join(",");

  useEffect(() => {
    if (!processingIds) return;
    const ids = processingIds.split(",");
    let cancelled = false;

    const tick = async () => {
      for (const id of ids) {
        try {
          const fresh = await api<MediaItem>(`/api/media/${id}`);
          if (cancelled) return;
          if (fresh.status !== "PROCESSING" && fresh.status !== "UPLOADING") {
            onResolved(fresh);
          } else {
            onResolved({ ...fresh, type: "VIDEO" });
          }
        } catch {
          /* transient — next tick retries */
        }
      }
    };

    const interval = setInterval(tick, 3000);
    void tick();
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [processingIds]);
}

export function MediaGallery({ propertyId, initialMedia = [], onChange }: Props) {
  const { toast } = useToast();
  const [items, setItems] = useState<MediaItem[]>(
    [...initialMedia].sort((a, b) => a.sortOrder - b.sortOrder),
  );
  const [uploading, setUploading] = useState<UploadState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editId, setEditId] = useState<string | null>(null);
  const [editCaption, setEditCaption] = useState("");
  const [editAlt, setEditAlt] = useState("");
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [ratio, setRatio] = useState<TargetRatio>("auto");
  const [filter, setFilter] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  function sync(next: MediaItem[]) {
    setItems(next);
    onChange?.(next);
  }

  useProcessingPoller(items, (fresh) => {
    setItems((current) => {
      const next = current.map((m) => (m.id === fresh.id ? { ...m, ...fresh } : m));
      onChange?.(next);
      return next;
    });
  });

  const hasVideos = items.some((m) => m.type === "VIDEO");
  const processingCount = items.filter((m) => m.status === "PROCESSING").length;

  async function onUpload(files: FileList | null) {
    if (!files?.length) return;
    setUploading({ active: true, percent: 0, name: files[0].name });
    setError(null);
    try {
      const uploaded = await uploadFilesWithProgress<MediaItem[]>(
        `/api/admin/properties/${propertyId}/media/bulk`,
        "files",
        Array.from(files),
        {
          fields: { targetRatio: ratio !== "auto" ? ratio : undefined },
          onProgress: (percent) => setUploading((state) => (state ? { ...state, percent } : state)),
        },
      );
      sync([...items, ...uploaded].sort((a, b) => a.sortOrder - b.sortOrder));
      const videos = uploaded.filter((m) => m.type === "VIDEO").length;
      toast(
        videos > 0
          ? `تم رفع ${uploaded.length} ملفاً — ${videos} فيديو قيد المعالجة`
          : `تم رفع ${uploaded.length} صورة`,
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "فشل الرفع");
    } finally {
      setUploading(null);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  async function onUploadPano(files: FileList | null) {
    if (!files?.length) return;
    const images = Array.from(files).filter((f) => f.type.startsWith("image/"));
    if (!images.length) {
      setError("صورة 360° يجب أن تكون ملف صورة");
      return;
    }
    setUploading({ active: true, percent: 0, name: images[0].name });
    setError(null);
    try {
      const uploaded = await uploadFilesWithProgress<MediaItem[]>(
        `/api/admin/properties/${propertyId}/media/bulk`,
        "files",
        images,
        {
          fields: { kind: "panorama" },
          onProgress: (percent) => setUploading((state) => (state ? { ...state, percent } : state)),
        },
      );
      sync([...items, ...uploaded].sort((a, b) => a.sortOrder - b.sortOrder));
      toast(`تم رفع ${uploaded.length} صورة جولة 360°`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "فشل الرفع");
    } finally {
      setUploading(null);
    }
  }

  async function onUploadReel(files: FileList | null) {
    if (!files?.length) return;
    const videos = Array.from(files).filter((f) => f.type.startsWith("video/"));
    if (!videos.length) {
      setError("الريل يجب أن يكون ملف فيديو");
      return;
    }
    setUploading({ active: true, percent: 0, name: videos[0].name });
    setError(null);
    try {
      const uploaded = await uploadFilesWithProgress<MediaItem[]>(
        `/api/admin/properties/${propertyId}/media/bulk`,
        "files",
        videos,
        {
          fields: { kind: "reel" },
          onProgress: (percent) => setUploading((state) => (state ? { ...state, percent } : state)),
        },
      );
      sync([...items, ...uploaded].sort((a, b) => a.sortOrder - b.sortOrder));
      const processing = uploaded.filter((m) => m.status === "PROCESSING").length;
      toast(
        processing > 0
          ? `تم رفع ${uploaded.length} ريل — قيد المعالجة السحابية (HLS متعدد الجودات)`
          : `تم رفع ${uploaded.length} ريل`,
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "فشل الرفع");
    } finally {
      setUploading(null);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  async function retryProcessing(item: MediaItem) {
    try {
      await api(`/api/admin/media/${item.id}/reprocess`, {
        method: "POST",
        body: JSON.stringify({ targetRatio: ratio !== "auto" ? ratio : "auto" }),
      });
      sync(items.map((m) => (m.id === item.id ? { ...m, status: "PROCESSING", processingProgress: 0, processingError: null } : m)));
      toast("أعيد الفيديو لطابور المعالجة");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر إعادة المعالجة", "error");
    }
  }

  async function setPrimary(mediaId: string) {
    try {
      const updated = await api<MediaItem[]>(`/api/admin/properties/${propertyId}/media/${mediaId}/primary`, { method: "PATCH" });
      sync([...updated].sort((a, b) => a.sortOrder - b.sortOrder));
      toast("تم تعيين الصورة الرئيسية");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التعيين", "error");
    }
  }

  async function saveMeta() {
    if (!editId) return;
    try {
      const updated = await api<MediaItem>(`/api/admin/media/${editId}`, {
        method: "PATCH",
        body: JSON.stringify({ caption: editCaption.trim(), altText: editAlt.trim() }),
      });
      sync(items.map((m) => (m.id === editId ? { ...m, ...updated } : m)));
      toast("تم حفظ بيانات الملف");
      setEditId(null);
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    }
  }

  function openEdit(item: MediaItem) {
    setEditId(item.id);
    setEditCaption(item.caption ?? "");
    setEditAlt(item.altText ?? "");
  }

  async function remove() {
    if (!deleteId) return;
    try {
      await api(`/api/admin/media/${deleteId}`, { method: "DELETE" });
      sync(items.filter((m) => m.id !== deleteId));
      toast("تم الحذف");
      setDeleteId(null);
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
    }
  }

  async function move(index: number, direction: -1 | 1) {
    const target = index + direction;
    if (target < 0 || target >= items.length) return;
    const reordered = [...items];
    const [moved] = reordered.splice(index, 1);
    reordered.splice(target, 0, moved);
    sync(reordered);
    try {
      const updated = await api<MediaItem[]>(`/api/admin/properties/${propertyId}/media/reorder`, {
        method: "PATCH",
        body: JSON.stringify({ mediaIds: reordered.map((m) => m.id) }),
      });
      sync([...updated].sort((a, b) => a.sortOrder - b.sortOrder));
    } catch {
      /* revert silently */
    }
  }

  const visibleItems = filter ? items.filter((m) => m.type === filter) : items;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h3 className="font-semibold">الصور والفيديو</h3>
          <p className="text-sm text-muted">
            ارفع صوراً وفيديوهات — الصورة الأولى أو «الرئيسية» تظهر في القائمة، والفيديو يعالج تلقائياً بملصق ونسخ متعددة
          </p>
        </div>
        {items.length > 0 && (
          <div className="flex gap-2">
            {MEDIA_FILTERS.map((f) => (
              <ToggleChip key={f.value} active={filter === f.value} onClick={() => setFilter(f.value)}>
                {f.label}
              </ToggleChip>
            ))}
          </div>
        )}
      </div>

      <div className="rounded-xl border border-line bg-paper p-3">
        <span className="mb-2 block text-xs font-medium text-ink">نسخة إضافية بالمسافة (للفيديو فقط — اختياري)</span>
        <div className="flex flex-wrap gap-2">
          {RATIO_OPTIONS.map((option) => (
            <ToggleChip
              key={option.value}
              active={ratio === option.value}
              onClick={() => setRatio(option.value)}
            >
              {option.label}
            </ToggleChip>
          ))}
        </div>
        <p className="mt-2 text-[11px] text-muted">
          {RATIO_OPTIONS.find((o) => o.value === ratio)?.hint} — أثناء المعالجة يُستخرج ملصق تلقائي ويُحسب عدد الثواني والنسبة الأصلية.
        </p>
      </div>

      <SimpleUpload
        onFiles={onUpload}
        accept="image/*,video/*"
        multiple
        uploading={!!uploading}
        label="اسحب الصور أو الفيديو هنا"
        hint="JPG / PNG / MP4 — حتى 200MB لكل فيديو"
      />

      <div className="rounded-xl border border-dashed border-accent/50 bg-accent-soft/40 p-3">
        <div className="mb-2 flex items-center gap-2">
          <span className="text-lg" aria-hidden>🌐</span>
          <div>
            <h4 className="text-sm font-bold">جولات 360°</h4>
            <p className="text-xs text-muted">
              صور بانورامية استوائية (نسبة 2:1) — تُعرض في التطبيق بعارض غامر يدور حول المكان بالسحب
            </p>
          </div>
        </div>
        <SimpleUpload
          onFiles={onUploadPano}
          accept="image/*"
          multiple
          uploading={!!uploading}
          label="اسحب صور 360° هنا"
          hint="ملفات JPG/PNG من كاميرا 360 أو تطبيق بانوراما"
        />
      </div>

      <div className="rounded-xl border border-dashed border-reel/60 bg-gradient-to-l from-reel-soft/50 to-transparent p-3">
        <div className="mb-2 flex items-center gap-2">
          <span className="text-lg" aria-hidden>📱</span>
          <div>
            <h4 className="text-sm font-bold">ريلز «استكشف» — فيديو عمودي 9:16</h4>
            <p className="text-xs text-muted">
              فيديو عمودي يظهر في قسم استكشف (شاشة الريلز) وفي صفحة المكان. القياس الأمثل: 1080×1920، مدة 10-60 ثانية
            </p>
          </div>
        </div>
        <SimpleUpload
          onFiles={onUploadReel}
          accept="video/*"
          uploading={!!uploading}
          label="اسحب فيديو الريل العمودي هنا"
          hint="MP4 عمودي (9:16) — حتى 200MB، تُعالج الجودات تلقائياً في السحابة"
        />
      </div>

      {uploading && (
        <div className="space-y-1.5">
          <div className="flex justify-between text-xs text-muted">
            <span className="truncate">جاري رفع {uploading.name}</span>
            <span>{uploading.percent}%</span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-accent-soft">
            <div className="h-full rounded-full bg-accent transition-all" style={{ width: `${uploading.percent}%` }} />
          </div>
        </div>
      )}

      {error && <Alert variant="danger">{error}</Alert>}

      {!items.length && !uploading && (
        <p className="rounded-lg bg-accent-soft px-4 py-3 text-sm text-warning">
          ارفع صورتين واضحتين على الأقل قبل النشر — الصورة الرئيسية تظهر في قائمة الأماكن.
        </p>
      )}

      {processingCount > 0 && (
        <p className="rounded-lg bg-accent-soft px-4 py-2.5 text-sm text-accent">
          🔄 {processingCount} فيديو قيد المعالجة — ستظهر النتائج تلقائياً بعد لحظات
        </p>
      )}

      {visibleItems.length > 0 && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {visibleItems.map((item) => {
            const index = items.findIndex((m) => m.id === item.id);
            const processing = item.status === "PROCESSING";
            const failed = item.status === "FAILED";
            return (
              <div key={item.id} className="media-card">
                <div className="media-card-preview">
                  {processing ? (
                    <div className="flex h-full w-full flex-col items-center justify-center gap-2 bg-ink/5">
                      <span className="text-2xl" aria-hidden>🎬</span>
                      <span className="text-xs font-semibold text-accent">
                        معالجة... {item.processingProgress ?? 0}%
                      </span>
                      <div className="h-1.5 w-3/4 overflow-hidden rounded-full bg-accent-soft">
                        <div
                          className="h-full rounded-full bg-accent transition-all"
                          style={{ width: `${item.processingProgress ?? 0}%` }}
                        />
                      </div>
                    </div>
                  ) : failed ? (
                    <div className="flex h-full w-full flex-col items-center justify-center gap-2 bg-danger-soft px-3 text-center">
                      <span className="text-xs font-semibold text-danger">فشلت المعالجة</span>
                      <span className="line-clamp-2 text-[11px] text-muted">{item.processingError}</span>
                      <Button type="button" size="sm" variant="ghost" onClick={() => retryProcessing(item)}>
                        إعادة المحاولة
                      </Button>
                    </div>
                  ) : item.type === "PANORAMA" ? (
                    <div className="relative h-full w-full">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={item.url} alt="" className="h-full w-full object-cover" loading="lazy" decoding="async" />
                      <span className="absolute inset-0 flex items-center justify-center">
                        <span className="rounded-lg border border-accent/60 bg-ink/70 px-3 py-1 text-xs font-bold text-accent">
                          360°
                        </span>
                      </span>
                    </div>
                  ) : item.type === "VIDEO" || item.type === "REEL" ? (
                    item.posterUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={item.posterUrl} alt="" className="h-full w-full object-cover" loading="lazy" decoding="async" />
                    ) : (
                      <video src={item.url} className="h-full w-full object-cover" controls preload="metadata" />
                    )
                  ) : (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={item.url} alt="" className="h-full w-full object-cover" loading="lazy" decoding="async" />
                  )}
                  {item.isPrimary && (
                    <span className="absolute left-2 top-2">
                      <Badge variant="success">الرئيسية</Badge>
                    </span>
                  )}
                  {item.aspectRatio && item.type === "VIDEO" && !processing && !failed && (
                    <span className="absolute right-2 top-2 flex gap-1">
                      <Badge variant="muted">{item.aspectRatio}</Badge>
                      {formatDuration(item.durationSec) && <Badge variant="muted">{formatDuration(item.durationSec)}</Badge>}
                    </span>
                  )}
                  {item.type === "REEL" && !processing && !failed && (
                    <span className="absolute right-2 top-2 flex gap-1">
                      <Badge variant="success">ريل · استكشف</Badge>
                      {item.aspectRatio && <Badge variant="muted">{item.aspectRatio}</Badge>}
                      {formatDuration(item.durationSec) && <Badge variant="muted">{formatDuration(item.durationSec)}</Badge>}
                    </span>
                  )}
                </div>
                <div className="media-card-body space-y-2">
                  {(item.caption || item.altText) && (
                    <p className="text-xs text-muted line-clamp-2">{item.caption || item.altText}</p>
                  )}
                  {item.type === "PANORAMA" && !processing && !failed && (
                    <Button
                      type="button"
                      variant="ghost"
                      className="px-2 py-1 text-xs"
                      onClick={() => window.open(item.url, "_blank")}
                    >
                      🌐 معاينة 360°
                    </Button>
                  )}
                  {(item.type === "VIDEO" || item.type === "REEL") && !processing && !failed && item.posterUrl && (
                    <Button
                      type="button"
                      variant="ghost"
                      className="px-2 py-1 text-xs"
                      onClick={() => window.open(item.hlsUrl ?? item.url, "_blank")}
                    >
                      ▶ تشغيل الفيديو
                    </Button>
                  )}
                  <div className="flex flex-wrap gap-2">
                    {!item.isPrimary && item.type !== "PANORAMA" && (
                      <Button type="button" variant="ghost" className="px-2 py-1 text-xs" onClick={() => setPrimary(item.id)}>
                        جعلها رئيسية
                      </Button>
                    )}
                    <Button type="button" variant="ghost" className="px-2 py-1 text-xs" onClick={() => openEdit(item)}>
                      وصف
                    </Button>
                    <Button type="button" variant="ghost" className="px-2 py-1 text-xs" disabled={index === 0} onClick={() => move(index, -1)}>
                      ←
                    </Button>
                    <Button type="button" variant="ghost" className="px-2 py-1 text-xs" disabled={index === items.length - 1} onClick={() => move(index, 1)}>
                      →
                    </Button>
                    <Button type="button" variant="danger" className="mr-auto px-2 py-1 text-xs" onClick={() => setDeleteId(item.id)}>
                      حذف
                    </Button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
      <Modal open={!!editId} onClose={() => setEditId(null)} title="بيانات الملف">
        <div className="space-y-3">
          <div>
            <Label htmlFor="caption">تعليق / وصف</Label>
            <Input id="caption" value={editCaption} onChange={(e) => setEditCaption(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="altText">نص بديل (SEO)</Label>
            <Input id="altText" value={editAlt} onChange={(e) => setEditAlt(e.target.value)} />
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setEditId(null)}>إلغاء</Button>
            <Button onClick={saveMeta}>حفظ</Button>
          </div>
        </div>
      </Modal>
      <ConfirmDialog
        open={!!deleteId}
        title="حذف الملف"
        message="حذف هذا الملف من المكان؟ سيُحذف مع أي ملصقات أو نسخ مشتقة منه."
        confirmLabel="حذف"
        danger
        onConfirm={remove}
        onClose={() => setDeleteId(null)}
      />
    </div>
  );
}
