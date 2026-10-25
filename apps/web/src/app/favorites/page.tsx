"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { PropertyDetail } from "@/lib/types";
import { useFavorites } from "@/lib/favorites";
import { PropertyCard } from "@/components/property-card";
import { EmptyState, PageSkeleton, RequireAuth } from "@/components/require-auth";

export default function FavoritesPage() {
  return (
    <RequireAuth title="سجّل الدخول لعرض المفضلة">
      <List />
    </RequireAuth>
  );
}

function List() {
  const [list, setList] = useState<PropertyDetail[] | null>(null);
  const { ids } = useFavorites();
  useEffect(() => {
    api<PropertyDetail[]>("/api/favorites").then(setList).catch(() => setList([]));
  }, []);
  if (!list) return <PageSkeleton />;
  const shown = list.filter((p) => ids.size === 0 || ids.has(p.id));
  return (
    <div className="container-x py-8">
      <h1 className="text-2xl font-black md:text-3xl">المفضلة</h1>
      {shown.length === 0 ? (
        <div className="mt-5">
          <EmptyState
            icon="❤️"
            title="لا أماكن في المفضلة"
            text="اضغط على القلب في أي مكان ليظهر هنا."
            action={
              <Link href="/search" className="btn btn-primary h-11 px-6">
                تصفّح الأماكن
              </Link>
            }
          />
        </div>
      ) : (
        <div className="mt-6 grid grid-cols-1 gap-x-5 gap-y-8 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {shown.map((p) => (
            <PropertyCard key={p.id} p={p} />
          ))}
        </div>
      )}
    </div>
  );
}
