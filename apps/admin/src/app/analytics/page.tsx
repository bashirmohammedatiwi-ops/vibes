"use client";

import { useEffect, useState } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ErrorBanner } from "@/components/ui/error-banner";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { BOOKING_STATUS_LABELS } from "@/lib/constants";
import { api, downloadCsv } from "@/lib/api";
import { formatMoney } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

type Analytics = {
  range: { from: string; to: string; days: number };
  revenue: number;
  discounts: number;
  prevRevenue: number;
  revenueChangePct: number | null;
  revenueTrend: Array<{ date: string; value: number }>;
  bookings: number;
  avgBookingValue: number;
  cancellationRatePct: number;
  avgLeadTimeDays: number;
  occupancyPct: number;
  approvedProperties: number;
  totalCustomers: number;
  newCustomers: number;
  bookingsByStatus: Array<{ status: string; count: number }>;
  topProviders: Array<{ name: string; revenue: number; bookings: number }>;
};

const RANGE_PRESETS = [
  { value: "7", label: "7 أيام" },
  { value: "30", label: "30 يوماً" },
  { value: "90", label: "90 يوماً" },
];

const PIE_COLORS = ["#6366f1", "#22c55e", "#f59e0b", "#ef4444", "#8b5cf6", "#14b8a6", "#64748b"];

function shortDate(iso: string) {
  return `${Number(iso.slice(5, 7))}/${Number(iso.slice(8, 10))}`;
}

function TrendBadge({ changePct }: { changePct: number | null }) {
  if (changePct == null) return <Badge variant="muted">بلا مقارنة</Badge>;
  const up = changePct >= 0;
  return (
    <Badge variant={up ? "success" : "danger"}>
      {up ? "▲" : "▼"} {Math.abs(changePct)}%
    </Badge>
  );
}

export default function AnalyticsPage() {
  const [days, setDays] = useState("30");
  const [data, setData] = useState<Analytics | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setData(null);
    setError(null);
    api<Analytics>(`/api/admin/reports/analytics?days=${days}`)
      .then(setData)
      .catch((err: Error) => setError(err.message));
  }, [days]);

  if (error) return <ErrorBanner message={error} onRetry={() => setDays(days)} />;
  if (!data) return <LoadingBlock />;

  const statusPie = data.bookingsByStatus.map((row) => ({
    name: BOOKING_STATUS_LABELS[row.status] ?? row.status,
    value: row.count,
  }));

  return (
    <PageShell>
      <PageHeader
        title="التحليلات"
        description="نظرة أعمق: الإيرادات، الإشغال، سلوك الحجز، وأفضل المزودين"
        eyebrow="VIBES Admin"
        action={
          <Button variant="ghost" size="sm" onClick={() => downloadCsv(`/api/admin/reports/bookings/export?from=${data.range.from}&to=${data.range.to}`, "bookings.csv")}>
            تصدير الحجوزات CSV
          </Button>
        }
      />

      <div className="flex gap-2">
        {RANGE_PRESETS.map((preset) => (
          <ToggleChip key={preset.value} active={days === preset.value} onClick={() => setDays(preset.value)}>
            {preset.label}
          </ToggleChip>
        ))}
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="p-4">
          <div className="flex items-center justify-between gap-2">
            <div className="text-xs text-muted">الإيرادات</div>
            <TrendBadge changePct={data.revenueChangePct} />
          </div>
          <div className="text-2xl font-bold">{formatMoney(data.revenue)}</div>
          <div className="text-[11px] text-muted">الفترة السابقة: {formatMoney(data.prevRevenue)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">الحجوزات المؤكدة</div>
          <div className="text-2xl font-bold">{data.bookings}</div>
          <div className="text-[11px] text-muted">متوسط القيمة {formatMoney(data.avgBookingValue)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">معدل الإشغال التقريبي</div>
          <div className="text-2xl font-bold">{data.occupancyPct}%</div>
          <div className="text-[11px] text-muted">{data.approvedProperties} مكاناً منشوراً</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">معدل الإلغاء</div>
          <div className="text-2xl font-bold">{data.cancellationRatePct}%</div>
          <div className="text-[11px] text-muted">مهلة الحجز المسبق {data.avgLeadTimeDays} يوم</div>
        </Card>
      </div>

      <Card className="p-4">
        <div className="section-header mb-4">
          <h2>اتجاه الإيرادات اليومية</h2>
          {data.discounts > 0 && <span className="text-xs text-muted">خصومات كوبونات: {formatMoney(data.discounts)}</span>}
        </div>
        <div className="h-64" dir="ltr">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data.revenueTrend}>
              <defs>
                <linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#6366f1" stopOpacity={0.35} />
                  <stop offset="100%" stopColor="#6366f1" stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(100,116,139,0.15)" />
              <XAxis dataKey="date" tickFormatter={shortDate} fontSize={11} tickLine={false} axisLine={false} interval="preserveStartEnd" />
              <YAxis fontSize={11} tickLine={false} axisLine={false} width={70} tickFormatter={(v: number) => `${Math.round(v / 1000)}k`} />
              <Tooltip
                formatter={(value: number) => formatMoney(value)}
                labelFormatter={(label: string) => label}
                contentStyle={{ borderRadius: 12, border: "1px solid rgba(100,116,139,0.2)", fontSize: 12 }}
              />
              <Area type="monotone" dataKey="value" stroke="#6366f1" strokeWidth={2} fill="url(#revenueFill)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="p-4">
          <h2 className="card-section-title">الحجوزات حسب الحالة</h2>
          {statusPie.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted">لا حجوزات في هذه الفترة</p>
          ) : (
            <div className="h-56" dir="ltr">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={statusPie} dataKey="value" nameKey="name" innerRadius={45} outerRadius={80} paddingAngle={3}>
                    {statusPie.map((entry, index) => (
                      <Cell key={entry.name} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(value: number) => `${value} حجزاً`} contentStyle={{ borderRadius: 12, fontSize: 12 }} />
                </PieChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>

        <Card className="p-4">
          <h2 className="card-section-title">أفضل المزودين (إيراداً)</h2>
          {!data.topProviders.length ? (
            <p className="py-8 text-center text-sm text-muted">لا بيانات مزودين في هذه الفترة</p>
          ) : (
            <div className="h-56" dir="ltr">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.topProviders} layout="vertical" margin={{ left: 8, right: 12 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(100,116,139,0.15)" horizontal={false} />
                  <XAxis type="number" fontSize={11} tickLine={false} axisLine={false} tickFormatter={(v: number) => `${Math.round(v / 1000)}k`} />
                  <YAxis type="category" dataKey="name" fontSize={11} tickLine={false} axisLine={false} width={110} />
                  <Tooltip formatter={(value: number) => formatMoney(value)} contentStyle={{ borderRadius: 12, fontSize: 12 }} />
                  <Bar dataKey="revenue" fill="#6366f1" radius={[0, 6, 6, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        <Card className="p-4">
          <div className="text-xs text-muted">عملاء جدد خلال الفترة</div>
          <div className="text-xl font-bold">{data.newCustomers}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">إجمالي العملاء</div>
          <div className="text-xl font-bold">{data.totalCustomers}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-muted">نطاق التقرير</div>
          <div className="text-sm font-bold" dir="ltr">{data.range.from} → {data.range.to}</div>
        </Card>
      </div>
    </PageShell>
  );
}
