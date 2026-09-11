"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Textarea } from "@/components/ui/input";
import { useToast } from "@/components/ui/toast";
import { PROPERTY_TYPE_LABELS, STATUS_VARIANT } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { formatMoney } from "@/lib/dates";
import type { Paginated, Property } from "@/lib/types";

const REJECT_REASONS = ["صور غير كافية", "معلومات غير دقيقة", "السعر غير مناسب", "سبب آخر"];

export function ModerationQueue({ onChanged }: { onChanged?: () => void }) {
  const { toast } = useToast();
  const [items, setItems] = useState<Property[]>([]);
  const [loading, setLoading] = useState(true);
  const [rejectId, setRejectId] = useState<string | null>(null);
  const [reason, setReason] = useState(REJECT_REASONS[0]);
  const [customReason, setCustomReason] = useState("");
  const [busy, setBusy] = useState(false);

  function load() {
    setLoading(true);
    api<Paginated<Property>>(
      `/api/admin/properties${buildQuery({ status: "PENDING", source: "provider", pageSize: 6 })}`,
    )
      .then((res) => setItems(res.items))
      .catch(() => setItems([]))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    load();
  }, []);

  async function publish(id: string) {
    setBusy(true);
    try {
      await api(`/api/admin/properties/${id}/publish`, { method: "POST" });
      toast("تم نشر المكان");
      load();
      onChanged?.();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر النشر", "error");
    } finally {
      setBusy(false);
    }
  }

  async function submitReject() {
    if (!rejectId) return;
    const finalReason = reason === "سبب آخر" ? customReason.trim() : reason;
    if (!finalReason) return;
    setBusy(true);
    try {
      await api(`/api/admin/properties/${rejectId}/reject`, {
        method: "POST",
        body: JSON.stringify({ reason: finalReason }),
      });
      toast("تم رفض المكان");
      setRejectId(null);
      setCustomReason("");
      load();
      onChanged?.();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الرفض", "error");
    } finally {
      setBusy(false);
    }
  }

  if (!loading && items.length === 0) return null;

  return (
    <>
      <div className="dash-panel dash-panel-flush overflow-hidden animate-fade-up">
        <div className="dash-feed-head">
          <div>
            <h2 className="dash-panel-title">طابور مراجعة المزودين</h2>
            <p className="dash-panel-desc">انشر أو ارفض بسرعة</p>
          </div>
          <Link href="/properties?status=PENDING&source=provider" className="text-xs font-bold text-accent hover:underline">
            عرض الكل
          </Link>
        </div>

        {loading ? (
          <p className="px-5 py-8 text-center text-sm text-muted">جاري التحميل...</p>
        ) : (
          <div className="divide-y divide-line">
            {items.map((item) => (
              <div key={item.id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-semibold text-ink">{item.name}</span>
                    <Badge variant={STATUS_VARIANT[item.status]}>{PROPERTY_TYPE_LABELS[item.type]}</Badge>
                    <Badge variant="muted">مزود</Badge>
                  </div>
                  <p className="mt-1 text-xs text-muted">
                    {item.city?.nameAr ?? "—"} · {formatMoney(item.pricePerDay)} · {(item.media?.length ?? 0)} صورة
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Link href={`/properties/${item.id}/edit`}>
                    <Button variant="ghost" size="sm">مراجعة</Button>
                  </Link>
                  <Button size="sm" disabled={busy} onClick={() => publish(item.id)}>نشر</Button>
                  <Button variant="danger" size="sm" disabled={busy} onClick={() => setRejectId(item.id)}>رفض</Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <Modal open={!!rejectId} onClose={() => setRejectId(null)} title="رفض المكان">
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2">
            {REJECT_REASONS.map((r) => (
              <button
                key={r}
                type="button"
                className={`rounded-full px-3 py-1.5 text-sm font-semibold transition ${
                  reason === r ? "bg-accent text-white" : "border border-line bg-surface text-muted hover:bg-accent-soft"
                }`}
                onClick={() => setReason(r)}
              >
                {r}
              </button>
            ))}
          </div>
          {reason === "سبب آخر" && (
            <Textarea value={customReason} onChange={(e) => setCustomReason(e.target.value)} placeholder="اكتب سبب الرفض..." rows={3} />
          )}
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setRejectId(null)}>إلغاء</Button>
            <Button variant="danger" disabled={busy} onClick={submitReject}>تأكيد الرفض</Button>
          </div>
        </div>
      </Modal>
    </>
  );
}
