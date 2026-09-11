"use client";

import { useCallback, useEffect, useState } from "react";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/empty-state";
import { ErrorBanner } from "@/components/ui/error-banner";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { BOOKING_STATUS_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { formatDayAr, formatMoney } from "@/lib/dates";
import type { Booking, Paginated } from "@/lib/types";

const STATUS_FILTERS = [
  { value: "", label: "الكل" },
  { value: "PENDING", label: "بانتظار التأكيد" },
  { value: "CONFIRMED", label: "مؤكدة" },
  { value: "COMPLETED", label: "مكتملة" },
  { value: "CANCELLED", label: "ملغاة" },
];

export default function ProviderBookingsPage() {
  const [data, setData] = useState<Paginated<Booking> | null>(null);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const result = await api<Paginated<Booking>>(
      `/api/provider/bookings${buildQuery({ page, pageSize: 15, status: status || undefined })}`,
    );
    setData(result);
  }, [page, status]);

  useEffect(() => {
    load().catch((err: Error) => setError(err.message)).finally(() => setLoading(false));
  }, [load]);

  async function updateStatus(booking: Booking, next: "CONFIRMED" | "CANCELLED") {
    try {
      await api(`/api/bookings/${booking.id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ status: next }),
      });
      await load();
    } catch (err) {
      alert(err instanceof Error ? err.message : "تعذر التحديث");
    }
  }

  if (error) return <ErrorBanner message={error} onRetry={() => load().catch(() => undefined)} />;
  if (loading) return <LoadingBlock />;

  const totalPages = data?.totalPages ?? 1;

  return (
    <PageShell>
      <PageHeader title="حجوزاتي" description="كل الحجوزات على ممتلكاتك — يمكنك تأكيد الحجوزات الجديدة أو إلغائها" eyebrow="بوابة المالك" />

      <PageToolbar>
        <div className="flex flex-wrap gap-2">
          {STATUS_FILTERS.map((f) => (
            <ToggleChip
              key={f.value}
              active={status === f.value}
              onClick={() => {
                setStatus(f.value);
                setPage(1);
              }}
            >
              {f.label}
            </ToggleChip>
          ))}
        </div>
      </PageToolbar>

      {!data?.items.length ? (
        <EmptyState title="لا حجوزات" description="ستظهر الحجوزات هنا فور حجز العملاء لممتلكاتك" />
      ) : (
        <div className="space-y-2">
          {data.items.map((booking) => (
            <Card key={booking.id} className="flex flex-wrap items-center justify-between gap-3 p-4 text-sm">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-bold">{booking.user?.name ?? booking.user?.phone}</span>
                  <Badge variant={booking.status === "CONFIRMED" ? "success" : booking.status === "CANCELLED" ? "muted" : booking.status === "COMPLETED" ? "default" : "warning"}>
                    {BOOKING_STATUS_LABELS[booking.status] ?? booking.status}
                  </Badge>
                  {Number(booking.discountAmount) > 0 && <Badge variant="success">خصم {formatMoney(booking.discountAmount ?? 0)}</Badge>}
                </div>
                <p className="mt-1 text-xs text-muted">
                  {booking.property?.name} · {formatDayAr(booking.startDate)} → {formatDayAr(booking.endDate)}
                  {booking.shift && booking.shift !== "FULL" && ` · شفت ${booking.shift === "MORNING" ? "صباحي" : "مسائي"}`}
                  {" · "}{formatMoney(booking.totalPrice)}
                </p>
              </div>
              {booking.status === "PENDING" && (
                <div className="flex gap-2">
                  <Button size="sm" onClick={() => updateStatus(booking, "CONFIRMED")}>تأكيد</Button>
                  <Button size="sm" variant="danger" onClick={() => updateStatus(booking, "CANCELLED")}>إلغاء</Button>
                </div>
              )}
            </Card>
          ))}
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex items-center justify-between text-sm">
          <Button variant="ghost" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>السابق</Button>
          <span className="text-muted">صفحة {page} من {totalPages}</span>
          <Button variant="ghost" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>التالي</Button>
        </div>
      )}
    </PageShell>
  );
}
