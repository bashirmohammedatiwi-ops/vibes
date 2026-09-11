"use client";

import dynamic from "next/dynamic";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Input, Select } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { LoadingBlock } from "@/components/page-header";
import { PROPERTY_STATUS_LABELS, PROPERTY_TYPE_LABELS } from "@/lib/constants";
import { api } from "@/lib/api";

const PropertiesMap = dynamic(() => import("@/components/properties-map").then((m) => m.PropertiesMap), {
  ssr: false,
  loading: () => <div className="h-[480px] animate-pulse rounded-2xl bg-surface" />,
});

type GeoProperty = {
  id: string;
  name: string;
  slug: string;
  type: string;
  status: string;
  latitude: number | string;
  longitude: number | string;
  city?: { nameAr: string };
};

export default function MapPage() {
  const [items, setItems] = useState<GeoProperty[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);

  useEffect(() => {
    api<GeoProperty[]>("/api/admin/properties/geo")
      .then(setItems)
      .catch(() => undefined)
      .finally(() => setLoading(false));
  }, []);

  const filtered = useMemo(() => {
    return items.filter((p) => {
      if (status && p.status !== status) return false;
      if (q) {
        const term = q.toLowerCase();
        const hay = `${p.name} ${p.city?.nameAr ?? ""}`.toLowerCase();
        if (!hay.includes(term)) return false;
      }
      return true;
    });
  }, [items, q, status]);

  const selected = filtered.find((p) => p.id === selectedId) ?? filtered[0] ?? null;

  if (loading) return <LoadingBlock />;

  return (
    <PageShell>
      <PageHeader
        title="خريطة الأماكن"
        description="عرض جغرافي لجميع الأماكن مع إمكانية التصفية والانتقال للتعديل"
        eyebrow="المحتوى"
      />

      <div className="map-toolbar">
        <Input placeholder="بحث..." value={q} onChange={(e) => setQ(e.target.value)} />
        <Select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">كل الحالات</option>
          {Object.entries(PROPERTY_STATUS_LABELS).map(([k, v]) => (
            <option key={k} value={k}>{v}</option>
          ))}
        </Select>
        <div className="map-stat-pill">
          {filtered.length} مكان على الخريطة
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <PropertiesMap
          properties={filtered.map((p) => ({
            id: p.id,
            name: p.name,
            lat: Number(p.latitude),
            lng: Number(p.longitude),
            status: p.status,
          }))}
          selectedId={selected?.id}
          onSelect={setSelectedId}
        />

        <div className="map-sidebar soft-scroll space-y-2">
          {filtered.map((p) => (
            <button
              key={p.id}
              type="button"
              onClick={() => setSelectedId(p.id)}
              className={`map-sidebar-item ${selected?.id === p.id ? "map-sidebar-item-active" : ""}`}
            >
              <div className="font-semibold">{p.name}</div>
              <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted">
                <span>{PROPERTY_TYPE_LABELS[p.type as keyof typeof PROPERTY_TYPE_LABELS]}</span>
                <Badge>{PROPERTY_STATUS_LABELS[p.status as keyof typeof PROPERTY_STATUS_LABELS]}</Badge>
                <span>{p.city?.nameAr}</span>
              </div>
              <Link
                href={`/properties/${p.id}/edit`}
                className="mt-2 inline-block text-xs font-bold text-accent hover:underline"
                onClick={(e) => e.stopPropagation()}
              >
                تعديل المكان →
              </Link>
            </button>
          ))}
          {!filtered.length && <p className="py-8 text-center text-sm text-muted">لا نتائج</p>}
        </div>
      </div>
    </PageShell>
  );
}
