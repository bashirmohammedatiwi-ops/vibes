"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Input } from "@/components/ui/input";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { api } from "@/lib/api";
import type { Amenity, PropertyType } from "@/lib/types";

type Props = {
  propertyType: PropertyType;
  /** Selected amenity ids (controlled). */
  value: string[];
  onChange: (ids: string[]) => void;
  /** Legacy fallback: names from the old JSON column to pre-select on first load. */
  initialNames?: string[];
};

/**
 * Catalog-driven amenity picker: groups amenities by category and only shows
 * entries that apply to the selected property type (empty appliesTo = all).
 */
export function AmenityPicker({ propertyType, value, onChange, initialNames }: Props) {
  const [catalog, setCatalog] = useState<Amenity[] | null>(null);
  const [query, setQuery] = useState("");
  const seedRef = useRef<null | string[]>(initialNames?.length ? initialNames : null);

  useEffect(() => {
    api<Amenity[]>("/api/admin/amenities?activeOnly=true")
      .then((list) => setCatalog(list))
      .catch(() => setCatalog([]));
  }, []);

  // One-time migration: turn legacy JSON names into catalog ids.
  useEffect(() => {
    if (!catalog || !seedRef.current?.length) return;
    const names = seedRef.current;
    seedRef.current = null;
    const matched = catalog.filter((a) => names.includes(a.nameAr)).map((a) => a.id);
    if (matched.length) {
      onChange(Array.from(new Set([...value, ...matched])));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [catalog]);

  const grouped = useMemo(() => {
    if (!catalog) return [];
    const q = query.trim().toLowerCase();
    const applicable = catalog.filter(
      (a) => !a.appliesTo.length || a.appliesTo.includes(propertyType),
    );
    const filtered = q
      ? applicable.filter((a) => a.nameAr.toLowerCase().includes(q) || a.nameEn.toLowerCase().includes(q))
      : applicable;
    const map = new Map<string, Amenity[]>();
    for (const amenity of filtered) {
      const key = amenity.category || "عام";
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(amenity);
    }
    return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0], "ar"));
  }, [catalog, propertyType, query]);

  function toggle(id: string) {
    onChange(value.includes(id) ? value.filter((v) => v !== id) : [...value, id]);
  }

  if (!catalog) return <p className="text-sm text-muted">جاري تحميل المزايا...</p>;

  return (
    <div className="space-y-3">
      <Input
        className="max-w-xs"
        placeholder="بحث في المزايا..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      {grouped.length === 0 && (
        <p className="text-sm text-muted">
          لا مزايا مطابقة — يمكن للمدير إضافة مزايا جديدة من صفحة «المزايا».
        </p>
      )}
      {grouped.map(([category, items]) => (
        <div key={category}>
          <div className="mb-1.5 text-[11px] font-bold text-muted">{category}</div>
          <div className="flex flex-wrap gap-2">
            {items.map((amenity) => (
              <ToggleChip
                key={amenity.id}
                active={value.includes(amenity.id)}
                onClick={() => toggle(amenity.id)}
              >
                <span aria-hidden className="ml-1">{amenity.icon || "🏷️"}</span>
                {amenity.nameAr}
              </ToggleChip>
            ))}
          </div>
        </div>
      ))}
      <p className="text-[11px] text-muted">اخترت {value.length} ميزة</p>
    </div>
  );
}
