"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { Input, Label } from "@/components/ui/input";
import { SkeletonCard } from "@/components/ui/skeleton";
import { StatStrip } from "@/components/ui/stat-strip";
import { PageHeader } from "@/components/page-header";
import { PageShell, ContentPanel, ContentToolbar } from "@/components/page-shell";
import { IconChart, IconWallet } from "@/components/nav-icons";
import { BOOKING_STATUS_LABELS, PROPERTY_TYPE_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { localIsoDate, formatMoney } from "@/lib/dates";

type ReportSummary = {
  bookings: number;
  revenue: number | string;
  propertiesByType: { type: string; count: number }[];
  bookingsByType: { type: string; count: number }[];
  bookingsByProvince: { name: string; count: number }[];
  bookingsByStatus: { status: string; count: number }[];
  topProperties: { id: string; name: string; type: string; bookings: number; revenue: number | string }[];
};

function isoDate(d: Date) {
  return localIsoDate(d);
}

function presetRange(key: string): { from: string; to: string } {
  const today = new Date();
  const to = isoDate(today);
  if (key === "7d") {
    const from = new Date(today);
    from.setDate(from.getDate() - 7);
    return { from: isoDate(from), to };
  }
  if (key === "30d") {
    const from = new Date(today);
    from.setDate(from.getDate() - 30);
    return { from: isoDate(from), to };
  }
  if (key === "month") {
    const from = new Date(today.getFullYear(), today.getMonth(), 1);
    return { from: isoDate(from), to };
  }
  if (key === "year") {
    const from = new Date(today.getFullYear(), 0, 1);
    return { from: isoDate(from), to };
  }
  return { from: "", to: "" };
}

function ReportBar({ label, count, max, accent }: { label: string; count: number; max: number; accent?: boolean }) {
  const pct = max > 0 ? (count / max) * 100 : 0;
  return (
    <div>
      <div className="mb-1 flex justify-between text-sm">
        <span className="font-medium">{label}</span>
        <Badge>{count}</Badge>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-accent-soft">
        <div className={`h-full rounded-full transition-all ${accent ? "bg-accent" : "bg-gold-light"}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const { exportCsv, exporting } = useCsvExport();
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [preset, setPreset] = useState("all");
  const [summary, setSummary] = useState<ReportSummary | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    api<ReportSummary>(`/api/admin/reports/summary${buildQuery({ from, to })}`)
      .then(setSummary)
      .catch(() => setSummary(null))
      .finally(() => setLoading(false));
  }, [from, to]);

  const presets = [
    { id: "7d", label: "آخر 7 أيام" },
    { id: "30d", label: "آخر 30 يوم" },
    { id: "month", label: "هذا الشهر" },
    { id: "year", label: "هذه السنة" },
    { id: "all", label: "الكل" },
  ];

  return (
    <PageShell>
      <PageHeader
        title="التقارير"
        description="ملخص الأداء وتصدير البيانات"
        eyebrow="VIBES Admin"
        action={
          <div className="flex flex-wrap gap-2">
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/reports/payments/export${buildQuery({ from, to })}`, "payments.csv")}>
              مدفوعات CSV
            </Button>
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/reports/bookings/export${buildQuery({ from, to })}`, "bookings.csv")}>
              حجوزات CSV
            </Button>
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/activities/export${buildQuery({ from, to })}`, "activity.csv")}>
              نشاط الفريق CSV
            </Button>
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv("/api/admin/reports/properties/export", "properties.csv")}>
              أماكن CSV
            </Button>
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv("/api/admin/reports/users/export", "users.csv")}>
              مستخدمون CSV
            </Button>
          </div>
        }
      />

      <div className="page-quick-links">
        <Link href="/payments?pending=1" className="page-quick-link">
          <span className="page-quick-link-label">دفعات معلّقة</span>
          <span className="page-quick-link-action">مراجعة الدفع ←</span>
        </Link>
        <Link href="/properties?status=PENDING" className="page-quick-link">
          <span className="page-quick-link-label">أماكن بانتظار المراجعة</span>
          <span className="page-quick-link-action">طابور المراجعة ←</span>
        </Link>
        <Link href="/activity" className="page-quick-link">
          <span className="page-quick-link-label">سجل النشاط</span>
          <span className="page-quick-link-action">عرض السجل ←</span>
        </Link>
      </div>

      <HelpTip>اختر فترة زمنية ثم حمّل ملف CSV للمحاسبة أو المراجعة</HelpTip>

      <ContentPanel flush={false}>
        <FilterChips
          value={preset}
          onChange={(id) => {
            setPreset(id);
            const range = presetRange(id);
            setFrom(range.from);
            setTo(range.to);
          }}
          options={presets}
        />
        <div className="mt-4 flex flex-wrap gap-4">
          <div>
            <Label>من</Label>
            <Input type="date" value={from} onChange={(e) => { setFrom(e.target.value); setPreset("custom"); }} className="mt-1" />
          </div>
          <div>
            <Label>إلى</Label>
            <Input type="date" value={to} onChange={(e) => { setTo(e.target.value); setPreset("custom"); }} className="mt-1" />
          </div>
        </div>
      </ContentPanel>

      {loading ? (
        <div className="grid gap-4 sm:grid-cols-2">
          <SkeletonCard />
          <SkeletonCard />
        </div>
      ) : (
        <StatStrip
          stats={[
            { label: "عدد الحجوزات", value: summary?.bookings ?? "—", icon: <IconChart className="h-5 w-5" /> },
            { label: "الإيرادات", value: summary ? formatMoney(summary.revenue) : "—", accent: true, icon: <IconWallet className="h-5 w-5" /> },
          ]}
        />
      )}

      <div className="page-reports-grid">
        <Card className="page-report-card">
          <h2 className="page-report-title">الحجوزات حسب الحالة</h2>
          <div className="space-y-3">
            {(summary?.bookingsByStatus ?? []).map((row) => {
              const max = Math.max(...(summary?.bookingsByStatus ?? []).map((r) => r.count), 1);
              return (
                <ReportBar key={row.status} label={BOOKING_STATUS_LABELS[row.status] ?? row.status} count={row.count} max={max} />
              );
            })}
            {!summary?.bookingsByStatus?.length && !loading && (
              <p className="text-sm text-muted">لا بيانات في هذه الفترة</p>
            )}
          </div>
        </Card>
        <Card className="page-report-card">
          <h2 className="page-report-title">الحجوزات حسب المحافظة</h2>
          <div className="space-y-3">
            {(summary?.bookingsByProvince ?? []).slice(0, 12).map((row) => {
              const max = Math.max(...(summary?.bookingsByProvince ?? []).slice(0, 12).map((r) => r.count), 1);
              return <ReportBar key={row.name} label={row.name} count={row.count} max={max} accent />;
            })}
          </div>
        </Card>
        <Card className="page-report-card">
          <h2 className="page-report-title">الأماكن حسب النوع (إجمالي)</h2>
          <div className="space-y-3">
            {(summary?.propertiesByType ?? []).map((row) => {
              const max = Math.max(...(summary?.propertiesByType ?? []).map((r) => r.count), 1);
              return (
                <ReportBar
                  key={row.type}
                  label={PROPERTY_TYPE_LABELS[row.type as keyof typeof PROPERTY_TYPE_LABELS] ?? row.type}
                  count={row.count}
                  max={max}
                />
              );
            })}
          </div>
        </Card>
        <Card className="page-report-card">
          <h2 className="page-report-title">الحجوزات حسب نوع المكان</h2>
          <div className="space-y-3">
            {(summary?.bookingsByType ?? []).map((row) => {
              const max = Math.max(...(summary?.bookingsByType ?? []).map((r) => r.count), 1);
              return (
                <ReportBar
                  key={row.type}
                  label={PROPERTY_TYPE_LABELS[row.type as keyof typeof PROPERTY_TYPE_LABELS] ?? row.type}
                  count={row.count}
                  max={max}
                  accent
                />
              );
            })}
          </div>
        </Card>
        <Card className="page-report-card md:col-span-2">
          <h2 className="page-report-title">أفضل الأماكن (إيرادات الفترة)</h2>
          <div className="space-y-3">
            {(summary?.topProperties ?? []).map((row) => {
              const max = Math.max(...(summary?.topProperties ?? []).map((r) => Number(r.revenue)), 1);
              return (
                <div key={row.id}>
                  <div className="mb-1 flex justify-between text-sm">
                    <Link href={`/properties/${row.id}/edit`} className="font-medium hover:text-accent">{row.name}</Link>
                    <span className="font-bold">{formatMoney(row.revenue)} · {row.bookings} حجز</span>
                  </div>
                  <div className="h-1.5 overflow-hidden rounded-full bg-accent-soft">
                    <div className="h-full rounded-full bg-accent" style={{ width: `${(Number(row.revenue) / max) * 100}%` }} />
                  </div>
                </div>
              );
            })}
            {!summary?.topProperties?.length && <p className="text-sm text-muted">لا بيانات في هذه الفترة</p>}
          </div>
        </Card>
      </div>
    </PageShell>
  );
}
