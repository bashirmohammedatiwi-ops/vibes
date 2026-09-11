"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/empty-state";
import { ErrorBanner } from "@/components/ui/error-banner";
import { SparkChart } from "@/components/ui/spark-chart";
import { BOOKING_STATUS_LABELS, PROPERTY_TYPE_LABELS } from "@/lib/constants";
import { api } from "@/lib/api";
import { formatDayAr, formatMoney } from "@/lib/dates";
import type { PropertyType } from "@/lib/types";

type Overview = {
  propertyCount: number;
  activeBookings: number;
  pendingBookings: number;
  monthRevenue: number | string;
  monthBookings: number;
  upcoming: Array<{
    id: string;
    startDate: string;
    endDate: string;
    status: string;
    user?: { name?: string | null; phone: string };
    property?: { name: string };
  }>;
};

type ProviderProperty = {
  id: string;
  name: string;
  type: PropertyType;
  status: string;
  ratingAvg?: number | string | null;
  viewCount?: number;
  city?: { nameAr: string };
  media?: Array<{ url: string }>;
  _count?: { bookings: number; reviews: number };
};

type RevenueRow = { month: string; revenue: number; bookings: number };

export default function ProviderPortalPage() {
  const [overview, setOverview] = useState<Overview | null>(null);
  const [properties, setProperties] = useState<ProviderProperty[]>([]);
  const [revenue, setRevenue] = useState<RevenueRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      api<Overview>("/api/provider/overview"),
      api<ProviderProperty[]>("/api/provider/properties"),
      api<RevenueRow[]>("/api/provider/revenue?months=6"),
    ])
      .then(([o, p, r]) => {
        setOverview(o);
        setProperties(p);
        setRevenue(r);
      })
      .catch((err: Error) => setError(err.message));
  }, []);

  if (error) return <ErrorBanner message={error} onRetry={() => window.location.reload()} />;
  if (!overview) return <LoadingBlock />;

  const monthLabel = new Date().toLocaleDateString("ar-IQ", { month: "long", year: "numeric" });

  return (
    <PageShell>
      <PageHeader
        title="بوابة المالك"
        description="تابع حجوزات وأرباح ممتلكاتك — وحدّث الأسعار والتوفر بنفسك"
        eyebrow="VIBES للمزودين"
      />

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="p-4">
          <div className="text-xs text-muted">ممتلكاتي</div>
          <div className="text-2xl font-bold">{overview.propertyCount}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">حجوزات نشطة</div>
          <div className="text-2xl font-bold">{overview.activeBookings}</div>
          {overview.pendingBookings > 0 && (
            <Badge variant="warning" >{overview.pendingBookings} بانتظار التأكيد</Badge>
          )}
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">أرباح {monthLabel}</div>
          <div className="text-2xl font-bold">{formatMoney(overview.monthRevenue)}</div>
          <div className="text-xs text-muted">{overview.monthBookings} حجزاً</div>
        </Card>
        <Card className="p-4">
          <div className="mb-1 text-xs text-muted">آخر 6 أشهر</div>
          {revenue.length > 0 ? (
            <SparkChart data={revenue.map((r) => ({ label: r.month, value: r.revenue }))} />
          ) : (
            <div className="text-sm text-muted">لا بيانات بعد</div>
          )}
        </Card>
      </div>

      <section>
        <div className="section-header mb-3">
          <h2>ممتلكاتي</h2>
        </div>
        {!properties.length ? (
          <EmptyState
            title="لا ممتلكات بعد"
            description="أضف ممتلكاتك من تطبيق VIBES ثم أدر أسعارها وتوفرها من هنا"
          />
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {properties.map((property) => (
              <Link key={property.id} href={`/provider/properties/${property.id}`} className="location-card block transition hover:shadow-md">
                <div className="flex items-start justify-between gap-2">
                  <div className="font-bold text-ink">{property.name}</div>
                  <Badge variant={property.status === "APPROVED" ? "success" : "muted"}>
                    {property.status === "APPROVED" ? "منشور" : "غير منشور"}
                  </Badge>
                </div>
                <div className="mt-1 text-xs text-muted">
                  {PROPERTY_TYPE_LABELS[property.type]} · {property.city?.nameAr ?? "—"} · {property._count?.bookings ?? 0} حجزاً
                </div>
                <div className="mt-3 flex justify-end">
                  <Button size="sm" variant="ghost">إدارة الأسعار والتوفر ←</Button>
                </div>
              </Link>
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="section-header mb-3">
          <h2>حجوزات قادمة</h2>
          <Link href="/provider/bookings" className="text-sm font-semibold text-accent hover:underline">كل الحجوزات ←</Link>
        </div>
        {!overview.upcoming.length ? (
          <Card className="py-6 text-center text-sm text-muted">لا حجوزات قادمة حالياً</Card>
        ) : (
          <div className="space-y-2">
            {overview.upcoming.map((booking) => (
              <Card key={booking.id} className="flex flex-wrap items-center justify-between gap-2 p-3.5 text-sm">
                <div>
                  <span className="font-bold">{booking.user?.name ?? booking.user?.phone}</span>
                  <span className="text-muted"> · {booking.property?.name}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-muted">{formatDayAr(booking.startDate)}</span>
                  <Badge variant={booking.status === "CONFIRMED" ? "success" : "warning"}>
                    {BOOKING_STATUS_LABELS[booking.status] ?? booking.status}
                  </Badge>
                </div>
              </Card>
            ))}
          </div>
        )}
      </section>
    </PageShell>
  );
}
