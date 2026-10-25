"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { MapPin, Search, Users } from "lucide-react";
import type { PropertyType, Province } from "@/lib/types";

const TYPES: { key: PropertyType | ""; label: string }[] = [
  { key: "", label: "الكل" },
  { key: "FARM", label: "مزارع" },
  { key: "HALL", label: "قاعات" },
  { key: "DECORATION", label: "تزيين" },
];

export function HeroSearch({ provinces }: { provinces: Province[] }) {
  const router = useRouter();
  const [type, setType] = useState<PropertyType | "">("");
  const [province, setProvince] = useState("");
  const [guests, setGuests] = useState("");
  const [q, setQ] = useState("");

  function go(e: React.FormEvent) {
    e.preventDefault();
    const sp = new URLSearchParams();
    if (type) sp.set("type", type);
    if (province) sp.set("province", province);
    if (guests) sp.set("guests", guests);
    if (q.trim()) sp.set("q", q.trim());
    router.push(`/search?${sp}`);
  }

  return (
    <form onSubmit={go} className="w-full max-w-4xl rounded-[1.75rem] bg-white p-2.5 shadow-[0_30px_60px_-20px_rgb(0_0_0/0.45)]">
      <div className="flex gap-1 px-1 pb-2.5 pt-1">
        {TYPES.map((t) => (
          <button
            type="button"
            key={t.key}
            onClick={() => setType(t.key)}
            className={`rounded-full px-4 py-1.5 text-sm font-black transition ${
              type === t.key ? "bg-midnight text-white" : "text-ink-2 hover:bg-cream"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>
      <div className="grid gap-2 md:grid-cols-[1.3fr_1fr_0.8fr_auto]">
        <label className="flex items-center gap-2 rounded-2xl bg-cream px-4">
          <Search className="h-4 w-4 shrink-0 text-ink-3" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="اسم المكان أو المنطقة"
            className="h-12 w-full bg-transparent text-sm font-semibold outline-none placeholder:text-ink-3"
          />
        </label>
        <label className="flex items-center gap-2 rounded-2xl bg-cream px-4">
          <MapPin className="h-4 w-4 shrink-0 text-ink-3" />
          <select
            value={province}
            onChange={(e) => setProvince(e.target.value)}
            className="h-12 w-full bg-transparent text-sm font-semibold outline-none"
          >
            <option value="">كل المحافظات</option>
            {provinces.map((p) => (
              <option key={p.id} value={p.slug}>
                {p.nameAr}
              </option>
            ))}
          </select>
        </label>
        <label className="flex items-center gap-2 rounded-2xl bg-cream px-4">
          <Users className="h-4 w-4 shrink-0 text-ink-3" />
          <input
            value={guests}
            onChange={(e) => setGuests(e.target.value.replace(/\D/g, ""))}
            inputMode="numeric"
            placeholder="عدد الضيوف"
            className="h-12 w-full bg-transparent text-sm font-semibold outline-none placeholder:text-ink-3"
          />
        </label>
        <button className="btn btn-gold h-12 px-8 text-[15px]">ابحث</button>
      </div>
    </form>
  );
}
