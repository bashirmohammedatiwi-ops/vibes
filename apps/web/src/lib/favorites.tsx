"use client";

import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { api } from "./api";
import { useAuth } from "./auth";
import type { PropertyDetail } from "./types";

type Fav = { ids: Set<string>; toggle: (id: string) => Promise<void> };
const Ctx = createContext<Fav>({ ids: new Set(), toggle: async () => {} });

export function FavoritesProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const router = useRouter();
  const [ids, setIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (!user) {
      setIds(new Set());
      return;
    }
    api<PropertyDetail[]>("/api/favorites")
      .then((list) => setIds(new Set(list.map((p) => p.id))))
      .catch(() => undefined);
  }, [user]);

  const toggle = useCallback(
    async (id: string) => {
      if (!user) {
        router.push(`/login?next=${encodeURIComponent(location.pathname + location.search)}`);
        return;
      }
      const had = ids.has(id);
      setIds((s) => {
        const n = new Set(s);
        if (had) n.delete(id);
        else n.add(id);
        return n;
      });
      try {
        if (had) await api(`/api/favorites/${id}`, { method: "DELETE" });
        else await api("/api/favorites", { method: "POST", body: { propertyId: id } });
      } catch {
        setIds((s) => {
          const n = new Set(s);
          if (had) n.add(id);
          else n.delete(id);
          return n;
        });
      }
    },
    [ids, user, router],
  );

  return <Ctx.Provider value={{ ids, toggle }}>{children}</Ctx.Provider>;
}

export const useFavorites = () => useContext(Ctx);
