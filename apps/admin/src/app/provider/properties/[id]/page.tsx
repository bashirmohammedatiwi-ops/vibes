"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { AvailabilityCalendar } from "@/components/availability-calendar";
import { PricingEditor } from "@/components/pricing-editor";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/empty-state";
import { ErrorBanner } from "@/components/ui/error-banner";
import { SimpleTabs } from "@/components/simple-tabs";
import { useToast } from "@/components/ui/toast";
import { api, buildQuery } from "@/lib/api";
import { formatDayAr, formatMoney } from "@/lib/dates";
import { DEFAULT_SHIFT_TIMES } from "@/lib/shifts";
import type { AvailabilitySlot, Booking, Paginated, PriceRule, PropertyDetail, ShiftTimes, ShiftType } from "@/lib/types";

export default function ProviderPropertyPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const { toast } = useToast();
  const [property, setProperty] = useState<PropertyDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [slots, setSlots] = useState<AvailabilitySlot[]>([]);
  const [tab, setTab] = useState("pricing");
  const [bookings, setBookings] = useState<Paginated<Booking> | null>(null);
  const [shiftTimes, setShiftTimes] = useState<ShiftTimes>(DEFAULT_SHIFT_TIMES);

  const loadAvailability = useCallback(async (month?: string) => {
    const av = await api<AvailabilitySlot[]>(
      `/api/provider/properties/${id}/availability${buildQuery({ month })}`,
    );
    setSlots(av);
  }, [id]);

  const loadBookings = useCallback(async () => {
    const result = await api<Paginated<Booking>>(
      `/api/provider/bookings${buildQuery({ propertyId: id, pageSize: 10 })}`,
    );
    setBookings(result);
  }, [id]);

  useEffect(() => {
    api<PropertyDetail>(`/api/provider/properties`)
      .then((list) => {
        const mine = (list as unknown as PropertyDetail[]).find((p) => p.id === id);
        if (!mine) throw new Error("المكان غير موجود أو لا يخصك");
        setProperty(mine);
        if (mine.morningStart || mine.eveningStart) {
          setShiftTimes({
            morningShiftStart: mine.morningStart || DEFAULT_SHIFT_TIMES.morningShiftStart,
            morningShiftEnd: mine.morningEnd || DEFAULT_SHIFT_TIMES.morningShiftEnd,
            eveningShiftStart: mine.eveningStart || DEFAULT_SHIFT_TIMES.eveningShiftStart,
            eveningShiftEnd: mine.eveningEnd || DEFAULT_SHIFT_TIMES.eveningShiftEnd,
            fullShiftStart: mine.morningStart || DEFAULT_SHIFT_TIMES.fullShiftStart,
            fullShiftEnd: mine.eveningEnd || DEFAULT_SHIFT_TIMES.fullShiftEnd,
          });
        }
      })
      .catch((err: Error) => setError(err.message));
    loadAvailability().catch(() => undefined);
    loadBookings().catch(() => undefined);
  }, [id, loadAvailability, loadBookings]);

  async function bulkAvailability(
    dates: string[],
    isAvailable: boolean,
    options?: { priceOverride?: number; shift?: ShiftType; shifts?: ShiftType[] },
  ) {
    await api(`/api/provider/properties/${id}/availability/bulk`, {
      method: "POST",
      body: JSON.stringify({ dates, isAvailable, priceOverride: options?.priceOverride, shift: options?.shift, shifts: options?.shifts }),
    });
    await loadAvailability();
    toast("تم تحديث التوفر");
  }

  async function clearAvailability(dates: string[], shifts?: ShiftType[]) {
    const res = await api<{ cleared: number }>(`/api/provider/properties/${id}/availability/clear`, {
      method: "POST",
      body: JSON.stringify({ dates, shifts }),
    });
    await loadAvailability();
    toast(res.cleared ? `تم مسح ${res.cleared} تخصيصاً` : "لا تخصيصات لمسحها");
  }

  if (error) {
    return (
      <ErrorBanner
        message={error}
        onRetry={() => window.location.reload()}
        backHref="/provider"
        backLabel="بوابة المالك"
      />
    );
  }
  if (!property) return <LoadingBlock />;

  const tabs = [
    { id: "pricing", label: "الأسعار" },
    { id: "calendar", label: "التوفر" },
    { id: "bookings", label: `الحجوزات${property._count?.bookings ? ` (${property._count.bookings})` : ""}` },
  ];

  return (
    <PageShell className="max-w-5xl">
      <Link href="/provider" className="inline-flex text-sm font-semibold text-accent hover:underline">
        ← بوابة المالك
      </Link>
      <PageHeader
        title={property.name}
        description="حدّد أسعار الشفتات والأيام، وأوقف التواريخ غير المتاحة"
        eyebrow="إدارة المكان"
        variant="compact"
        action={<Badge variant={property.status === "APPROVED" ? "success" : "muted"}>{property.status === "APPROVED" ? "منشور" : "غير منشور"}</Badge>}
      />

      <SimpleTabs tabs={tabs} active={tab} onChange={setTab} />

      {tab === "pricing" && (
        <Card>
          <PricingEditor
            propertyId={property.id}
            propertyType={property.type}
            initialRules={(property.priceRules ?? []) as PriceRule[]}
            initialMode={property.bookingMode}
            initialTimes={{
              morningStart: property.morningStart,
              morningEnd: property.morningEnd,
              eveningStart: property.eveningStart,
              eveningEnd: property.eveningEnd,
            }}
            apiBase="/api/provider/properties"
          />
        </Card>
      )}

      {tab === "calendar" && (
        <Card>
          <h2 className="mb-2 font-semibold">متى المكان متاح؟</h2>
          <p className="mb-4 text-sm text-muted">أغلق التواريخ المحجوزة يدوياً أو حدّد سعراً خاصاً ليوم بعينه</p>
          <AvailabilityCalendar
            propertyType={property.type}
            slots={slots}
            shiftTimes={shiftTimes}
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
            <Link href="/provider/bookings">
              <Button variant="ghost" className="text-xs">كل الحجوزات</Button>
            </Link>
          </div>
          {!bookings?.items.length ? (
            <EmptyState title="لا حجوزات بعد" description="ستظهر حجوزات هذا المكان هنا" />
          ) : (
            <div className="space-y-2">
              {bookings.items.map((booking) => (
                <div key={booking.id} className="list-row text-sm">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="font-semibold">{booking.user?.name ?? booking.user?.phone}</span>
                    <span className="text-muted">{formatDayAr(booking.startDate)}</span>
                    <span className="font-bold">{formatMoney(booking.totalPrice)}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>
      )}
    </PageShell>
  );
}
