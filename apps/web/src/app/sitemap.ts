import type { MetadataRoute } from "next";
import { serverGet } from "@/lib/server";
import { SITE_URL } from "@/lib/config";
import type { Paged, PropertyCard } from "@/lib/types";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const res = await serverGet<Paged<PropertyCard>>("/api/properties?page=1&pageSize=100", 3600);
  const now = new Date();
  const statics = ["", "/search", "/search?type=FARM", "/search?type=HALL", "/search?type=DECORATION", "/offers", "/nadeem"].map((p) => ({
    url: `${SITE_URL}${p}`,
    lastModified: now,
    changeFrequency: "daily" as const,
    priority: p === "" ? 1 : 0.8,
  }));
  return [
    ...statics,
    ...(res?.items ?? []).map((p) => ({
      url: `${SITE_URL}/p/${p.slug}`,
      lastModified: p.createdAt ? new Date(p.createdAt) : now,
      changeFrequency: "weekly" as const,
      priority: 0.9,
    })),
  ];
}
