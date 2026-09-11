"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { RatingStars } from "@/components/ui/detail-card";
import { Alert } from "@/components/ui/alert";
import { ErrorBanner } from "@/components/ui/error-banner";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { PropertyHeader } from "@/components/property-header";
import { PageShell } from "@/components/page-shell";
import { Modal } from "@/components/ui/modal";
import { Textarea } from "@/components/ui/input";
import { AvailabilityCalendar } from "@/components/availability-calendar";
import { MediaGallery } from "@/components/media-gallery";
import { PricingEditor } from "@/components/pricing-editor";
import { PropertyForm } from "@/components/property-form";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PhoneActions } from "@/components/phone-actions";
import { SimpleTabs } from "@/components/simple-tabs";
import { useToast } from "@/components/ui/toast";
import { LoadingBlock } from "@/components/page-header";
import { PaginationBar } from "@/components/pagination-bar";
import { EmptyState } from "@/components/empty-state";
import { BOOKING_STATUS_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { formatMoney, formatShortDayAr } from "@/lib/dates";
import type { AvailabilitySlot, Booking, Paginated, PropertyDetail, ShiftTimes, ShiftType } from "@/lib/types";
import { DEFAULT_SHIFT_TIMES } from "@/lib/shifts";

const REJECT_REASONS = ["صور غير كافية", "معلومات غير دقيقة", "السعر غير مناسب", "سبب آخر"];

export default function EditPropertyPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { toast } = useToast();
  const id = params.id;

  const [property, setProperty] = useState<PropertyDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [slots, setSlots] = useState<AvailabilitySlot[]>([]);
  const [shiftTimes, setShiftTimes] = useState<import("@/lib/types").ShiftTimes | null>(null);
  const [tab, setTab] = useState("details");
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [suspendOpen, setSuspendOpen] = useState(false);
  const [publicWebUrl, setPublicWebUrl] = useState<string | undefined>();
  const [bookings, setBookings] = useState<Paginated<Booking> | null>(null);
  const [bookingsPage, setBookingsPage] = useState(1);
  const [bookingsLoading, setBookingsLoading] = useState(false);

  const loadAvailability = useCallback(async (month?: string) => {
    const av = await api<AvailabilitySlot[]>(
      `/api/admin/properties/${id}/availability${buildQuery({ month })}`,
    );
    setSlots(av);
  }, [id]);

  const load = useCallback(async () => {
    const data = await api<PropertyDetail>(`/api/admin/properties/${id}`);
    setProperty(data);
    await loadAvailability();
  }, [id, loadAvailability]);

  useEffect(() => {
    load().catch((err: Error) => setError(err.message));
    api<ShiftTimes>("/api/admin/settings")
      .then((s) =>
        setShiftTimes({
          morningShiftStart: s.morningShiftStart ?? DEFAULT_SHIFT_TIMES.morningShiftStart,
          morningShiftEnd: s.morningShiftEnd ?? DEFAULT_SHIFT_TIMES.morningShiftEnd,
          eveningShiftStart: s.eveningShiftStart ?? DEFAULT_SHIFT_TIMES.eveningShiftStart,
          eveningShiftEnd: s.eveningShiftEnd ?? DEFAULT_SHIFT_TIMES.eveningShiftEnd,
          fullShiftStart: s.fullShiftStart ?? DEFAULT_SHIFT_TIMES.fullShiftStart,
          fullShiftEnd: s.fullShiftEnd ?? DEFAULT_SHIFT_TIMES.fullShiftEnd,
        }),
      )
      .catch(() => setShiftTimes(DEFAULT_SHIFT_TIMES));
    api<{ publicWebUrl: string }>("/api/admin/settings")
      .then((s) => setPublicWebUrl(s.publicWebUrl))
      .catch(() => undefined);
  }, [load]);

  const loadBookings = useCallback(async (page = 1) => {
    setBookingsLoading(true);
    try {
      const result = await api<Paginated<Booking>>(
        `/api/admin/properties/${id}/bookings${buildQuery({ page, pageSize: 10 })}`,
      );
      setBookings(result);
      setBookingsPage(page);
    } catch {
      setBookings(null);
    } finally {
      setBookingsLoading(false);
    }
  }, [id]);

  useEffect(() => {
    const t = new URLSearchParams(window.location.search).get("tab");
    if (t === "photos") setTab("photos");
    if (t === "pricing") setTab("pricing");
    if (t === "bookings") setTab("bookings");
    if (t === "reviews") setTab("reviews");
  }, []);

  useEffect(() => {
    if (tab === "bookings") loadBookings(bookingsPage).catch(() => undefined);
  }, [tab, loadBookings, bookingsPage]);

  async function toggleReviewVisibility(reviewId: string, isVisible: boolean) {
    try {
      await api(`/api/admin/reviews/${reviewId}/visibility`, {
        method: "PATCH",
        body: JSON.stringify({ isVisible }),
      });
      setProperty((prev) =>
        prev
          ? {
              ...prev,
              reviews: prev.reviews?.map((r) => (r.id === reviewId ? { ...r, isVisible } : r)),
            }
          : prev,
      );
      toast(isVisible ? "تم إظهار التقييم" : "تم إخفاء التقييم");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function publish() {
    const photos = property?.media?.length ?? 0;
    if (photos < 1) {
      setTab("photos");
      toast("ارفع صورة واحدة على الأقل قبل النشر", "error");
      return;
    }
    try {
      const updated = await api<PropertyDetail>(`/api/admin/properties/${id}/publish`, { method: "POST" });
      setProperty(updated);
      toast("المكان منشور الآن — يظهر للعملاء");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر النشر", "error");
    }
  }

  async function suspend() {
    const updated = await api<PropertyDetail>(`/api/admin/properties/${id}/suspend`, { method: "POST" });
    setProperty(updated);
    toast("تم إيقاف المكان مؤقتاً");
  }

  async function submitReject() {
    if (!rejectReason.trim()) return;
    try {
      const updated = await api<PropertyDetail>(`/api/admin/properties/${id}/reject`, {
        method: "POST",
        body: JSON.stringify({ reason: rejectReason.trim() }),
      });
      setProperty(updated);
      setRejectOpen(false);
      setRejectReason("");
      toast("تم رفض المكان");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الرفض", "error");
    }
  }

  async function bulkAvailability(
    dates: string[],
    isAvailable: boolean,
    options?: { priceOverride?: number; shift?: ShiftType; shifts?: ShiftType[] },
  ) {
    await api(`/api/admin/properties/${id}/availability/bulk`, {
      method: "POST",
      body: JSON.stringify({ dates, isAvailable, priceOverride: options?.priceOverride, shift: options?.shift, shifts: options?.shifts }),
    });
    await loadAvailability();
    toast("تم تحديث التوفر");
  }

  async function clearAvailability(dates: string[], shifts?: ShiftType[]) {
    const res = await api<{ cleared: number }>(`/api/admin/properties/${id}/availability/clear`, {
      method: "POST",
      body: JSON.stringify({ dates, shifts }),
    });
    await loadAvailability();
    toast(res.cleared ? `تم مسح ${res.cleared} تخصيصاً — عودة للإعداد الافتراضي` : "لا تخصيصات لمسحها");
  }

  if (error) {
    return (
      <ErrorBanner
        message={error}
        onRetry={() => { setError(null); load().catch((err: Error) => setError(err.message)); }}
        backHref="/properties"
        backLabel="العودة للأماكن"
      />
    );
  }

  if (!property) return <LoadingBlock />;

  const tabs = [
    { id: "details", label: "التفاصيل" },
    { id: "pricing", label: "الأسعار" },
    { id: "photos", label: `الصور${property.media?.length ? ` (${property.media.length})` : ""}` },
    { id: "calendar", label: "التوفر" },
    { id: "bookings", label: `الحجوزات${property._count?.bookings ? ` (${property._count.bookings})` : ""}` },
    { id: "reviews", label: `التقييمات${property._count?.reviews ? ` (${property._count.reviews})` : property.reviews?.length ? ` (${property.reviews.length})` : ""}` },
  ];

  return (
    <PageShell className="max-w-5xl">
      <Link href="/properties" className="inline-flex text-sm font-semibold text-accent hover:underline">
        ← العودة للأماكن
      </Link>
      <PropertyHeader property={property} publicWebUrl={publicWebUrl}>
          {property.status !== "APPROVED" ? (
            <>
              <Button onClick={publish}>نشر للعملاء</Button>
              <Button variant="ghost" onClick={() => setRejectOpen(true)}>رفض</Button>
            </>
          ) : (
            <Button variant="ghost" onClick={() => setSuspendOpen(true)}>إيقاف مؤقت</Button>
          )}
          <Button variant="ghost" onClick={async () => {
            try {
              const copy = await api<PropertyDetail>(`/api/admin/properties/${id}/duplicate`, { method: "POST" });
              toast("تم إنشاء نسخة مسودة");
              router.push(`/properties/${copy.id}/edit`);
            } catch (err) {
              toast(err instanceof Error ? err.message : "تعذر النسخ", "error");
            }
          }}>نسخ المكان</Button>
          <Button variant="danger" onClick={() => setDeleteOpen(true)}>حذف</Button>
      </PropertyHeader>

      {(property.phone || property.whatsapp) && (
        <PhoneActions phone={property.whatsapp || property.phone} />
      )}

      {property.status === "PENDING" && property.providerId && (
        <Alert variant="warning">هذا المكان رفعه المزود من التطبيق — راجع الصور والتفاصيل ثم انشر أو ارفض مع سبب.</Alert>
      )}

      {property.status === "REJECTED" && property.rejectionReason && (
        <Alert variant="danger"><strong>سبب الرفض:</strong> {property.rejectionReason}</Alert>
      )}

      {property.status === "DRAFT" && (
        <Alert variant="info">
          <strong>خطوات النشر:</strong> 1) أكمل التفاصيل  2) ارفع الصور  3) اضغط «نشر للعملاء»
          {(property.media?.length ?? 0) < 1 && <span className="mt-1 block">لم تُرفع صور بعد — انتقل لتبويب الصور.</span>}
        </Alert>
      )}

      <SimpleTabs tabs={tabs} active={tab} onChange={setTab} />

      {tab === "details" && (
        <PropertyForm
          initial={property}
          submitLabel="حفظ التعديلات"
          onSaved={(p) => {
            setProperty({ ...property, ...p });
            toast("تم الحفظ");
          }}
        />
      )}

      {tab === "pricing" && (
        <Card>
          <PricingEditor
            propertyId={property.id}
            propertyType={property.type}
            initialRules={property.priceRules ?? []}
            initialMode={property.bookingMode}
            initialTimes={{
              morningStart: property.morningStart,
              morningEnd: property.morningEnd,
              eveningStart: property.eveningStart,
              eveningEnd: property.eveningEnd,
            }}
          />
        </Card>
      )}

      {tab === "photos" && (
        <Card>
          <MediaGallery
            propertyId={property.id}
            initialMedia={property.media}
            onChange={(media) => setProperty((prev) => (prev ? { ...prev, media } : prev))}
          />
        </Card>
      )}

      {tab === "calendar" && (
        <Card>
          <h2 className="mb-2 font-semibold">متى المكان متاح؟</h2>
          <p className="mb-4 text-sm text-muted">
            {property.type === "FARM"
              ? "حدّد التوفر لكل شفت (صباحي / مسائي / يوم كامل) — الأوقات من الإعدادات"
              : "حدّد الأيام المفتوحة للحجز أو أغلق أيام محجوزة"}
          </p>
          <AvailabilityCalendar
            propertyType={property.type}
            slots={slots}
            shiftTimes={shiftTimes ?? DEFAULT_SHIFT_TIMES}
            onBulkSet={bulkAvailability}
            onClear={clearAvailability}
            onMonthChange={loadAvailability}
          />
        </Card>
      )}

      {tab === "bookings" && (
        <Card>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-semibold">سجل الحجوزات</h2>
            <Link href={`/bookings?propertyId=${property.id}`}>
              <Button variant="ghost" className="text-xs">كل الحجوزات</Button>
            </Link>
          </div>
          {bookingsLoading && <p className="text-sm text-muted">جاري التحميل...</p>}
          {!bookingsLoading && !bookings?.items.length && (
            <EmptyState title="لا حجوزات بعد" description="ستظهر هنا عندما يحجز العملاء هذا المكان" />
          )}
          <div className="space-y-2">
            {(bookings?.items ?? []).map((b) => (
              <div key={b.id} className="list-row text-sm">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <Link href={`/bookings/${b.id}`} className="font-semibold text-accent hover:underline">
                    {b.user?.name ?? b.user?.phone}
                  </Link>
                  <Badge variant={b.status === "CONFIRMED" ? "success" : b.status === "CANCELLED" ? "muted" : "warning"}>
                    {BOOKING_STATUS_LABELS[b.status] ?? b.status}
                  </Badge>
                </div>
                <p className="mt-1 text-muted">
                  {formatShortDayAr(b.startDate)} → {formatShortDayAr(b.endDate)}
                  {b.shift && b.shift !== "FULL" && ` · ${SHIFT_TYPE_LABELS[b.shift]}`}
                  {" · "}{formatMoney(b.totalPrice)}
                </p>
              </div>
            ))}
          </div>
          {bookings && bookings.totalPages > 1 && (
            <div className="mt-4 border-t border-line pt-4">
              <PaginationBar page={bookingsPage} totalPages={bookings.totalPages} total={bookings.total} label="حجز" onPage={setBookingsPage} />
            </div>
          )}
        </Card>
      )}

      {tab === "reviews" && (
        <Card>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-semibold">آراء العملاء</h2>
            <Link href={`/reviews?propertyId=${property.id}`}>
              <Button variant="ghost" className="text-xs">إدارة التقييمات</Button>
            </Link>
          </div>
          {!property.reviews?.length ? (
            <EmptyState title="لا تقييمات بعد" description="ستظهر هنا عندما يقيّم العملاء هذا المكان" />
          ) : (
            <div className="space-y-2">
              {property.reviews.map((r) => (
                <div key={r.id} className="list-row text-sm">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="flex items-center gap-2">{r.user?.name ?? r.user?.phone} <RatingStars rating={r.rating} /></span>
                    <div className="flex items-center gap-2">
                      <Badge variant={r.isVisible ? "success" : "muted"}>{r.isVisible ? "ظاهر" : "مخفي"}</Badge>
                      {r.isVisible ? (
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => toggleReviewVisibility(r.id, false)}>إخفاء</Button>
                      ) : (
                        <Button className="px-2 py-1 text-xs" onClick={() => toggleReviewVisibility(r.id, true)}>إظهار</Button>
                      )}
                    </div>
                  </div>
                  {r.comment && <p className="mt-2 leading-6 text-muted">{r.comment}</p>}
                </div>
              ))}
            </div>
          )}
        </Card>
      )}

      <ConfirmDialog
        open={suspendOpen}
        title="إيقاف المكان"
        message="سيختفي المكان من التطبيق مؤقتاً. يمكنك إعادة نشره لاحقاً."
        confirmLabel="إيقاف"
        onConfirm={async () => {
          await suspend();
          setSuspendOpen(false);
        }}
        onClose={() => setSuspendOpen(false)}
      />

      <Modal open={rejectOpen} title="رفض المكان" onClose={() => setRejectOpen(false)}>
        <div className="space-y-3">
          <p className="text-sm text-muted">اختر سبباً أو اكتب ملاحظة:</p>
          <div className="flex flex-wrap gap-2">
            {REJECT_REASONS.map((r) => (
              <ToggleChip key={r} active={rejectReason === r} onClick={() => setRejectReason(r)}>
                {r}
              </ToggleChip>
            ))}
          </div>
          <Textarea value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} placeholder="سبب الرفض..." />
          <div className="flex gap-2">
            <Button variant="danger" onClick={submitReject} disabled={!rejectReason.trim()}>تأكيد الرفض</Button>
            <Button variant="ghost" onClick={() => setRejectOpen(false)}>إلغاء</Button>
          </div>
        </div>
      </Modal>

      <Modal open={deleteOpen} title="حذف المكان" onClose={() => setDeleteOpen(false)}>
        <p className="mb-4 text-sm text-muted">هل أنت متأكد؟ لا يمكن التراجع عن الحذف.</p>
        <div className="flex gap-2">
          <Button variant="danger" onClick={async () => {
            await api(`/api/admin/properties/${id}`, { method: "DELETE" });
            router.push("/properties");
          }}>نعم، احذف</Button>
          <Button variant="ghost" onClick={() => setDeleteOpen(false)}>إلغاء</Button>
        </div>
      </Modal>
    </PageShell>
  );
}
