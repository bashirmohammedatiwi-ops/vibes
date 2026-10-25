import Link from "next/link";
import { ChevronLeft } from "lucide-react";
import type { PropertyCard as P } from "@/lib/types";
import { PropertyCard } from "./property-card";

export function SectionHead({ title, subtitle, href }: { title: string; subtitle?: string; href?: string }) {
  return (
    <div className="mb-5 flex items-end justify-between gap-4">
      <div>
        <h2 className="text-xl font-black text-ink md:text-2xl">{title}</h2>
        {subtitle && <p className="mt-1 text-sm text-ink-2">{subtitle}</p>}
      </div>
      {href && (
        <Link href={href} className="flex shrink-0 items-center gap-0.5 text-sm font-bold text-brass-deep hover:text-midnight">
          الكل
          <ChevronLeft className="h-4 w-4" />
        </Link>
      )}
    </div>
  );
}

/** شريط أفقي على الجوال، شبكة على الشاشات الكبيرة. */
export function Rail({ items, title, subtitle, href }: { items: P[]; title: string; subtitle?: string; href?: string }) {
  if (!items.length) return null;
  return (
    <section className="container-x py-7">
      <SectionHead title={title} subtitle={subtitle} href={href} />
      <div className="no-scrollbar -mx-4 flex snap-x gap-4 overflow-x-auto px-4 md:mx-0 md:grid md:grid-cols-3 md:gap-6 md:overflow-visible md:px-0 lg:grid-cols-4">
        {items.slice(0, 8).map((p, i) => (
          <div key={p.id} className="w-[72%] shrink-0 snap-start sm:w-[45%] md:w-auto">
            <PropertyCard p={p} priority={i < 2} />
          </div>
        ))}
      </div>
    </section>
  );
}
