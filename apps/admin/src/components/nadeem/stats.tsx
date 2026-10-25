"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { StatStrip } from "@/components/ui/stat-strip";
import { SkeletonList } from "@/components/ui/skeleton";
import { EmptyState } from "@/components/empty-state";
import { api } from "@/lib/api";
import {
  SHIFT_LABEL,
  WORLD_LABEL,
  type NadeemConfig,
  type NadeemSessionRow,
  type NadeemStats,
} from "./types";

const fmt = (n: number) => new Intl.NumberFormat("ar-IQ").format(n);
const money = (n: number) =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(n % 1_000_000 ? 1 : 0)} مليون` : `${Math.round(n / 1000)} ألف`;

function Bars({ items, label }: { items: { key: string; count: number }[]; label: (k: string) => string }) {
  const max = Math.max(1, ...items.map((i) => i.count));
  const total = items.reduce((s, i) => s + i.count, 0) || 1;
  if (!items.length) return <p className="py-6 text-center text-sm text-muted">لا بيانات بعد</p>;
  return (
    <div className="space-y-2.5">
      {items.map((i) => (
        <div key={i.key}>
          <div className="mb-1 flex items-center justify-between text-sm">
            <span className="font-semibold text-ink">{label(i.key)}</span>
            <span className="text-xs font-bold text-muted">
              {fmt(i.count)} · {Math.round((i.count / total) * 100)}٪
            </span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-line/60">
            <div className="h-full rounded-full bg-accent" style={{ width: `${(i.count / max) * 100}%` }} />
          </div>
        </div>
      ))}
    </div>
  );
}

function Daily({ data }: { data: NadeemStats["daily"] }) {
  const max = Math.max(1, ...data.map((d) => d.sessions));
  return (
    <div>
      <div className="flex h-40 items-end gap-[3px]" dir="ltr">
        {data.map((d) => (
          <div key={d.date} className="group relative flex h-full flex-1 flex-col justify-end">
            <div
              className="rounded-t bg-accent/25"
              style={{ height: `${Math.max(2, (d.sessions / max) * 100)}%` }}
              title={`${d.date}: ${d.sessions} خطة · ${d.clicks} نقرة`}
            >
              <div
                className="w-full rounded-t bg-accent"
                style={{ height: d.sessions ? `${(d.clicks / d.sessions) * 100}%` : 0 }}
              />
            </div>
          </div>
        ))}
      </div>
      <div className="mt-2 flex justify-between text-[11px] text-muted" dir="ltr">
        <span>{data[0]?.date.slice(5)}</span>
        <span>{data[data.length - 1]?.date.slice(5)}</span>
      </div>
      <div className="mt-2 flex gap-4 text-xs text-muted">
        <span className="inline-flex items-center gap-1.5">
          <i className="inline-block h-2.5 w-2.5 rounded bg-accent/25" /> خطط مكتملة
        </span>
        <span className="inline-flex items-center gap-1.5">
          <i className="inline-block h-2.5 w-2.5 rounded bg-accent" /> فتح مكاناً من النتائج
        </span>
      </div>
    </div>
  );
}

export function NadeemStatsView({ config }: { config: NadeemConfig }) {
  const [days, setDays] = useState(30);
  const [stats, setStats] = useState<NadeemStats | null>(null);
  const [sessions, setSessions] = useState<{ items: NadeemSessionRow[]; total: number; page: number } | null>(null);
  const [page, setPage] = useState(1);

  useEffect(() => {
    setStats(null);
    api<NadeemStats>(`/api/admin/nadeem/stats?days=${days}`).then(setStats).catch(() => undefined);
  }, [days]);

  useEffect(() => {
    api<{ items: NadeemSessionRow[]; total: number; page: number }>(`/api/admin/nadeem/sessions?page=${page}&pageSize=20`)
      .then(setSessions)
      .catch(() => undefined);
  }, [page]);

  const occ = (k: string) => config.occasions.find((o) => o.key === k)?.label ?? (k === "—" ? "غير محدد" : k);

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-2">
        {[7, 30, 90].map((d) => (
          <Button key={d} size="sm" variant={days === d ? "primary" : "ghost"} onClick={() => setDays(d)}>
            آخر {d} يوم
          </Button>
        ))}
      </div>

      {!stats ? (
        <SkeletonList count={4} />
      ) : (
        <>
          <StatStrip
            stats={[
              { label: "خطط مكتملة", value: fmt(stats.total), hint: `${fmt(stats.allTime)} منذ البداية`, accent: true },
              { label: "نسبة فتح النتائج", value: `${stats.clickRate}٪`, hint: `${fmt(stats.clicked)} زبون فتح مكاناً` },
              { label: "تطابق كامل", value: `${stats.preciseRate}٪`, hint: "وجد نديم ما طُلب بالضبط" },
              {
                label: "بلا نتائج",
                value: fmt(stats.emptyResults),
                hint: "خطط لم يجد لها أي مكان",
                alert: stats.emptyResults > 0,
              },
              { label: "متوسط الضيوف", value: stats.avgGuests ? fmt(stats.avgGuests) : "—" },
              { label: "متوسط الميزانية", value: stats.avgBudget ? `${money(stats.avgBudget)} د.ع` : "—" },
            ]}
          />

          <Card>
            <h3 className="mb-4 text-base font-bold text-ink">الاستخدام اليومي</h3>
            <Daily data={stats.daily} />
          </Card>

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
            <Card>
              <h3 className="mb-4 text-base font-bold text-ink">المناسبات</h3>
              <Bars items={stats.byOccasion} label={occ} />
            </Card>
            <Card>
              <h3 className="mb-4 text-base font-bold text-ink">نوع المكان المطلوب</h3>
              <Bars items={stats.byType} label={(k) => WORLD_LABEL[k] ?? k} />
            </Card>
            <Card>
              <h3 className="mb-4 text-base font-bold text-ink">المحافظات</h3>
              <Bars items={stats.byProvince} label={(k) => k} />
            </Card>
            <Card>
              <h3 className="mb-4 text-base font-bold text-ink">التوقيت المفضّل</h3>
              <Bars items={stats.byShift} label={(k) => SHIFT_LABEL[k] ?? (k === "—" ? "لم يُسأل" : k)} />
            </Card>
            <Card>
              <h3 className="mb-4 text-base font-bold text-ink">الأكثر اقتراحاً (أول ٣ نتائج)</h3>
              <PlaceList items={stats.topRecommended} />
            </Card>
            <Card>
              <h3 className="mb-4 text-base font-bold text-ink">الأكثر فتحاً من نديم</h3>
              <PlaceList items={stats.topClicked} />
            </Card>
          </div>
        </>
      )}

      <Card padded={false}>
        <div className="flex items-center justify-between p-5 pb-3">
          <h3 className="text-base font-bold text-ink">آخر الخطط</h3>
          {sessions && <span className="text-xs text-muted">{fmt(sessions.total)} خطة</span>}
        </div>
        {!sessions ? (
          <div className="p-5">
            <SkeletonList count={5} />
          </div>
        ) : sessions.items.length === 0 ? (
          <EmptyState title="لا خطط بعد" description="ستظهر هنا كل خطة يكملها زبون مع نديم" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[860px] text-sm">
              <thead>
                <tr className="border-y border-line text-right text-xs text-muted">
                  <th className="px-4 py-2.5 font-semibold">الوقت</th>
                  <th className="px-4 py-2.5 font-semibold">الزبون</th>
                  <th className="px-4 py-2.5 font-semibold">المناسبة</th>
                  <th className="px-4 py-2.5 font-semibold">الطلب</th>
                  <th className="px-4 py-2.5 font-semibold">النتائج</th>
                  <th className="px-4 py-2.5 font-semibold">فتح</th>
                </tr>
              </thead>
              <tbody>
                {sessions.items.map((s) => (
                  <tr key={s.id} className="border-b border-line/60 align-top">
                    <td className="whitespace-nowrap px-4 py-3 text-xs text-muted">
                      {new Date(s.createdAt).toLocaleString("ar-IQ", { dateStyle: "short", timeStyle: "short" })}
                    </td>
                    <td className="px-4 py-3">
                      {s.user ? (
                        <Link href={`/users/${s.user.id}`} className="font-semibold text-accent hover:underline">
                          {s.user.name || s.user.phone}
                        </Link>
                      ) : (
                        <span className="text-muted">زائر</span>
                      )}
                    </td>
                    <td className="px-4 py-3 font-semibold text-ink">{s.occasion ? occ(s.occasion) : "—"}</td>
                    <td className="px-4 py-3 text-xs leading-6 text-muted">
                      {[
                        s.autoType ? "نديم يختار" : s.propertyType ? WORLD_LABEL[s.propertyType] : null,
                        s.province ?? "كل العراق",
                        s.guests ? `${s.guests} ضيف` : null,
                        s.shift ? SHIFT_LABEL[s.shift] : null,
                        s.budgetOpen ? "ميزانية مفتوحة" : s.maxBudget ? `حتى ${money(s.maxBudget)}` : null,
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                    </td>
                    <td className="px-4 py-3 text-xs">
                      <span className={`font-bold ${s.resultCount ? "text-ink" : "text-red-600"}`}>
                        {s.resultCount} {s.precise ? "· دقيق" : ""}
                      </span>
                      {s.topResults.length > 0 && (
                        <div className="mt-1 text-muted">{s.topResults.map((r) => r.name).join("، ")}</div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs">
                      {s.clickedName ? (
                        <span className="font-semibold text-emerald-700">{s.clickedName}</span>
                      ) : (
                        <span className="text-muted">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {sessions && sessions.total > 20 && (
          <div className="flex items-center justify-center gap-2 p-4">
            <Button size="sm" variant="ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              السابق
            </Button>
            <span className="text-xs text-muted">
              صفحة {page} من {Math.ceil(sessions.total / 20)}
            </span>
            <Button
              size="sm"
              variant="ghost"
              disabled={page >= Math.ceil(sessions.total / 20)}
              onClick={() => setPage((p) => p + 1)}
            >
              التالي
            </Button>
          </div>
        )}
      </Card>
    </div>
  );
}

function PlaceList({ items }: { items: { id: string; name: string; type: string | null; count: number }[] }) {
  if (!items.length) return <p className="py-6 text-center text-sm text-muted">لا بيانات بعد</p>;
  return (
    <ol className="space-y-2">
      {items.map((p, i) => (
        <li key={p.id} className="flex items-center gap-3 rounded-xl bg-paper px-3 py-2">
          <span className="flex h-6 w-6 items-center justify-center rounded-full bg-accent-soft text-xs font-bold text-accent">
            {i + 1}
          </span>
          <Link href={`/properties/${p.id}`} className="min-w-0 flex-1 truncate font-semibold text-ink hover:text-accent">
            {p.name}
          </Link>
          {p.type && <span className="text-xs text-muted">{WORLD_LABEL[p.type]}</span>}
          <span className="text-xs font-bold text-ink">{fmt(p.count)}</span>
        </li>
      ))}
    </ol>
  );
}
