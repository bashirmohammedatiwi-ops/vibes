import type { Metadata } from "next";
import { serverGet } from "@/lib/server";
import type { Paged, PropertyCard as P, PropertyType, Province } from "@/lib/types";
import { fromPrice, TYPE_PLURAL } from "@/lib/format";
import { PropertyCard } from "@/components/property-card";
import { SearchFilters } from "./filters";

type SP = Record<string, string | undefined>;

export async function generateMetadata({ searchParams }: { searchParams: Promise<SP> }): Promise<Metadata> {
  const sp = await searchParams;
  const t = sp.type as PropertyType | undefined;
  const base = t ? TYPE_PLURAL[t] : "كل الأماكن";
  return {
    title: sp.winter === "true" ? "المزارع الشتوية" : `${base} للحجز`,
    description: `تصفّح ${base} في العراق مع الأسعار والأيام المتاحة واحجز مباشرة عبر VIBES.`,
  };
}

export default async function SearchPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams;
  const qs = new URLSearchParams({ page: "1", pageSize: "100" });
  for (const k of ["type", "province", "q", "winter", "indoorPool"] as const) {
    if (sp[k]) qs.set(k, sp[k]!);
  }
  if (sp.sort && sp.sort !== "featured" && sp.sort !== "price_desc") qs.set("sort", sp.sort);
  if (sp.sort === "price_desc") qs.set("sort", "price");

  const [res, provinces] = await Promise.all([
    serverGet<Paged<P>>(`/api/properties?${qs}`, 30),
    serverGet<Province[]>("/api/provinces", 600),
  ]);

  let items = res?.items ?? [];
  const guests = Number(sp.guests) || 0;
  const maxPrice = Number(sp.maxPrice) || 0;
  if (guests) items = items.filter((p) => p.capacity >= guests);
  if (maxPrice) items = items.filter((p) => fromPrice(p) <= maxPrice);
  if (sp.sort === "price") items = [...items].sort((a, b) => fromPrice(a) - fromPrice(b));
  if (sp.sort === "price_desc") items = [...items].sort((a, b) => fromPrice(b) - fromPrice(a));

  const t = sp.type as PropertyType | undefined;
  const title = sp.winter === "true" ? "المزارع الشتوية" : t ? TYPE_PLURAL[t] : "كل الأماكن";

  return (
    <div className="container-x py-6 md:py-10" data-world={t ?? "FARM"}>
      <div className="mb-5">
        <h1 className="text-2xl font-black md:text-3xl">{title}</h1>
        <p className="mt-1 text-sm text-ink-2">
          <span className="num font-bold">{items.length}</span> مكان {sp.q ? `يطابق «${sp.q}»` : "متاح للحجز"}
        </p>
      </div>
      <SearchFilters provinces={provinces ?? []} />
      {items.length === 0 ? (
        <div className="card mt-8 flex flex-col items-center px-6 py-16 text-center">
          <div className="text-4xl">🔍</div>
          <h2 className="mt-3 text-lg font-black">لا توجد أماكن تطابق بحثك</h2>
          <p className="mt-1 text-sm text-ink-2">جرّب إزالة بعض الفلاتر أو اختيار محافظة أخرى.</p>
        </div>
      ) : (
        <div className="mt-6 grid grid-cols-1 gap-x-5 gap-y-8 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {items.map((p, i) => (
            <PropertyCard key={p.id} p={p} priority={i < 4} />
          ))}
        </div>
      )}
    </div>
  );
}
