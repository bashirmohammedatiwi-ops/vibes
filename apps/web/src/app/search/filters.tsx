"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { Search, Snowflake, Waves, X } from "lucide-react";
import type { Province } from "@/lib/types";

export function SearchFilters({ provinces }: { provinces: Province[] }) {
  const router = useRouter();
  const pathname = usePathname();
  const sp = useSearchParams();
  const [q, setQ] = useState(sp.get("q") ?? "");

  useEffect(() => setQ(sp.get("q") ?? ""), [sp]);

  function set(patch: Record<string, string | null>) {
    const next = new URLSearchParams(sp.toString());
    for (const [k, v] of Object.entries(patch)) {
      if (v === null || v === "") next.delete(k);
      else next.set(k, v);
    }
    if (patch.type !== undefined && patch.type !== "FARM") {
      next.delete("winter");
      next.delete("indoorPool");
    }
    router.push(`${pathname}?${next}`, { scroll: false });
  }

  const type = sp.get("type") ?? "";
  const winter = sp.get("winter") === "true";
  const pool = sp.get("indoorPool") === "true";
  const active = ["q", "province", "guests", "maxPrice", "winter", "indoorPool", "sort"].some((k) => sp.get(k));

  return (
    <div className="space-y-3">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          set({ q: q.trim() || null });
        }}
        className="flex items-center gap-2 rounded-2xl border border-line bg-white px-4 shadow-[var(--shadow-soft)]"
      >
        <Search className="h-4 w-4 text-ink-3" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="ابحث باسم المكان أو المنطقة…"
          className="h-12 flex-1 bg-transparent text-sm font-semibold outline-none"
        />
        {q && (
          <button type="button" onClick={() => set({ q: null })} aria-label="مسح">
            <X className="h-4 w-4 text-ink-3" />
          </button>
        )}
      </form>

      <div className="no-scrollbar -mx-4 flex items-center gap-2 overflow-x-auto px-4 pb-1">
        {[
          ["", "الكل"],
          ["FARM", "مزارع"],
          ["HALL", "قاعات"],
          ["DECORATION", "تزيين"],
        ].map(([k, l]) => (
          <button key={k} onClick={() => set({ type: k || null })} className={`chip ${type === k ? "chip-on" : ""}`}>
            {l}
          </button>
        ))}
        <span className="mx-1 h-6 w-px shrink-0 bg-line" />
        {(type === "" || type === "FARM") && (
          <>
            <button
              onClick={() => set({ winter: winter ? null : "true", type: winter ? type || null : "FARM" })}
              className={`chip ${winter ? "!border-sky-600 !bg-sky-600 !text-white" : ""}`}
            >
              <Snowflake className="h-3.5 w-3.5" /> مزارع شتوية
            </button>
            <button
              onClick={() => set({ indoorPool: pool ? null : "true", type: pool ? type || null : "FARM" })}
              className={`chip ${pool ? "!border-teal-600 !bg-teal-600 !text-white" : ""}`}
            >
              <Waves className="h-3.5 w-3.5" /> مسبح مغلق
            </button>
          </>
        )}
        <select
          value={sp.get("province") ?? ""}
          onChange={(e) => set({ province: e.target.value })}
          className="chip cursor-pointer outline-none"
        >
          <option value="">كل المحافظات</option>
          {provinces.map((p) => (
            <option key={p.id} value={p.slug}>
              {p.nameAr}
            </option>
          ))}
        </select>
        <select value={sp.get("guests") ?? ""} onChange={(e) => set({ guests: e.target.value })} className="chip cursor-pointer outline-none">
          <option value="">عدد الضيوف</option>
          {[20, 50, 100, 200, 300, 500, 800].map((n) => (
            <option key={n} value={n}>
              {n}+ ضيف
            </option>
          ))}
        </select>
        <select value={sp.get("maxPrice") ?? ""} onChange={(e) => set({ maxPrice: e.target.value })} className="chip cursor-pointer outline-none">
          <option value="">أي سعر</option>
          {[100000, 200000, 300000, 500000, 750000, 1000000, 2000000].map((n) => (
            <option key={n} value={n}>
              حتى {n >= 1_000_000 ? `${n / 1_000_000} مليون` : `${n / 1000} ألف`}
            </option>
          ))}
        </select>
        <select value={sp.get("sort") ?? ""} onChange={(e) => set({ sort: e.target.value })} className="chip cursor-pointer outline-none">
          <option value="">الترتيب: المقترح</option>
          <option value="rating">الأعلى تقييماً</option>
          <option value="price">الأرخص أولاً</option>
          <option value="price_desc">الأغلى أولاً</option>
          <option value="newest">الأحدث</option>
        </select>
        {active && (
          <button onClick={() => router.push(type ? `${pathname}?type=${type}` : pathname)} className="chip !text-danger">
            <X className="h-3.5 w-3.5" /> مسح الفلاتر
          </button>
        )}
      </div>
    </div>
  );
}
