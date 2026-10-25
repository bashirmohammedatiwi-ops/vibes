import Link from "next/link";
import { MapPin, Snowflake, Star, Users, Waves } from "lucide-react";
import type { PropertyCard as P } from "@/lib/types";
import { cover, fromPrice, modeOf, moneyShort, num, placeLine, sized, TYPE_LABEL } from "@/lib/format";
import { FavButton } from "./fav-button";

export function Pill({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center gap-1 rounded-full bg-white/95 px-2.5 py-1 text-[11px] font-black text-ink shadow-sm ${className}`}>
      {children}
    </span>
  );
}

export function PropertyCard({ p, priority = false }: { p: P; priority?: boolean }) {
  const img = cover(p.media);
  const rating = num(p.ratingAvg);
  const price = fromPrice(p);
  const mode = modeOf(p);
  return (
    <Link href={`/p/${p.slug}`} className="group block" data-world={p.type}>
      <div className="relative aspect-[4/3] overflow-hidden rounded-[1.4rem] bg-champagne">
        {img ? (
          <img
            src={sized(img, 640)}
            alt={p.name}
            loading={priority ? "eager" : "lazy"}
            className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.04]"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-4xl text-[var(--w-accent)]">✦</div>
        )}
        <div className="absolute inset-x-0 top-0 flex items-start justify-between p-3">
          <div className="flex flex-col items-start gap-1.5">
            {p.isNew && <Pill className="text-success">جديد</Pill>}
            {p.isWinter && (
              <Pill className="text-sky-700">
                <Snowflake className="h-3 w-3" /> شتوية
              </Pill>
            )}
            {p.hasIndoorPool && (
              <Pill className="text-teal-700">
                <Waves className="h-3 w-3" /> مسبح مغلق
              </Pill>
            )}
          </div>
          <FavButton id={p.id} />
        </div>
        {p.ratingCount > 0 && (
          <div className="absolute bottom-3 right-3">
            <Pill>
              <Star className="h-3 w-3 fill-brass text-brass" />
              <span className="num">{rating.toFixed(1)}</span>
              <span className="num text-ink-3">({p.ratingCount})</span>
            </Pill>
          </div>
        )}
      </div>
      <div className="px-1 pt-3">
        <div className="flex items-center gap-1.5 text-[11px] font-black text-[var(--w-deep)]">
          <span>{TYPE_LABEL[p.type]}</span>
          {mode !== "FULL_DAY" && <span className="text-ink-3">· صباحي ومسائي</span>}
        </div>
        <h3 className="mt-0.5 truncate text-[15px] font-black text-ink">{p.name}</h3>
        <div className="mt-0.5 flex items-center gap-3 text-xs font-semibold text-ink-2">
          {placeLine(p) && (
            <span className="flex min-w-0 items-center gap-1 truncate">
              <MapPin className="h-3.5 w-3.5 shrink-0 text-ink-3" />
              {placeLine(p)}
            </span>
          )}
          {p.capacity > 0 && (
            <span className="flex shrink-0 items-center gap-1">
              <Users className="h-3.5 w-3.5 text-ink-3" />
              <span className="num">{p.capacity}</span>
            </span>
          )}
        </div>
        <div className="mt-1.5 flex items-baseline gap-1">
          <span className="text-[11px] font-bold text-ink-3">من</span>
          <span className="num text-[16px] font-extrabold text-ink">{moneyShort(price)}</span>
          <span className="text-[11px] font-bold text-ink-3">د.ع</span>
        </div>
      </div>
    </Link>
  );
}

export function CardSkeleton() {
  return (
    <div>
      <div className="skeleton aspect-[4/3] rounded-[1.4rem]" />
      <div className="skeleton mt-3 h-4 w-2/3 rounded" />
      <div className="skeleton mt-2 h-3 w-1/2 rounded" />
    </div>
  );
}
