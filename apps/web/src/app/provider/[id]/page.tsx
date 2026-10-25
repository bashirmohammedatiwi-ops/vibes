import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { BadgeCheck } from "lucide-react";
import { serverGet } from "@/lib/server";
import type { PropertyDetail } from "@/lib/types";
import { PropertyCard } from "@/components/property-card";
import { FollowButton } from "./follow-button";

type Profile = {
  id: string;
  businessName?: string | null;
  verified?: boolean;
  user?: { name?: string | null };
  properties: PropertyDetail[];
  _count?: { followers?: number; properties?: number };
};

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const p = await serverGet<Profile>(`/api/providers/${id}/profile`, 300);
  return { title: p ? (p.businessName || p.user?.name || "صاحب مكان") : "غير موجود" };
}

export default async function ProviderPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const p = await serverGet<Profile>(`/api/providers/${id}/profile`, 120);
  if (!p) notFound();
  const name = p.businessName || p.user?.name || "صاحب مكان";
  return (
    <div className="container-x py-8">
      <div className="hero-grain flex flex-wrap items-center gap-5 rounded-[2rem] p-6 text-white md:p-8">
        <span className="flex h-20 w-20 items-center justify-center rounded-3xl bg-white/10 text-3xl font-black text-brass-light">{name.charAt(0)}</span>
        <div className="min-w-0 flex-1">
          <h1 className="flex items-center gap-2 text-2xl font-black md:text-3xl">
            {name}
            {p.verified && <BadgeCheck className="h-6 w-6 text-sky-300" />}
          </h1>
          <div className="mt-1 text-sm text-white/70">
            <span className="num">{p._count?.properties ?? p.properties.length}</span> مكان ·{" "}
            <span className="num">{p._count?.followers ?? 0}</span> متابع
          </div>
        </div>
        <FollowButton providerId={p.id} />
      </div>
      <div className="mt-8 grid grid-cols-1 gap-x-5 gap-y-8 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {p.properties.map((x) => (
          <PropertyCard key={x.id} p={x} />
        ))}
      </div>
    </div>
  );
}
