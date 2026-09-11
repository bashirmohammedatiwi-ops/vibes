"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { RatingStars } from "@/components/ui/detail-card";
import { PROPERTY_STATUS_LABELS, PROPERTY_TYPE_LABELS, STATUS_VARIANT } from "@/lib/constants";
import { relativeTimeAr } from "@/lib/dates";
import type { PropertyDetail } from "@/lib/types";

type Props = {
  property: PropertyDetail;
  publicWebUrl?: string;
  children?: React.ReactNode;
};

export function PropertyHeader({ property, publicWebUrl, children }: Props) {
  const primary = property.media?.find((m) => m.isPrimary) ?? property.media?.[0];
  const previewUrl = property.slug && publicWebUrl
    ? `${publicWebUrl.replace(/\/$/, "")}/places/${property.slug}`
    : null;

  return (
    <div className="property-command-header sticky top-[4.25rem] z-20 mb-2 space-y-4 p-4 sm:p-5">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
        <div className="property-thumb relative h-28 w-full shrink-0 sm:h-32 sm:w-44">
          {primary ? (
            primary.type === "VIDEO" ? (
              <video src={primary.url} className="h-full w-full object-cover" muted />
            ) : (
              <img src={primary.url} alt={primary.altText ?? property.name} className="h-full w-full object-cover" />
            )
          ) : (
            <div className="flex h-full items-center justify-center text-xs text-muted">لا صور</div>
          )}
          {property.featured && (
            <span className="absolute start-2 top-2 rounded-lg bg-accent px-2 py-0.5 text-[10px] font-bold text-white">
              مميز
            </span>
          )}
        </div>

        <div className="min-w-0 flex-1 space-y-3">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="text-xl font-bold text-ink sm:text-2xl">{property.name}</h1>
                <Badge variant={STATUS_VARIANT[property.status]}>{PROPERTY_STATUS_LABELS[property.status]}</Badge>
                <Badge variant="muted">{PROPERTY_TYPE_LABELS[property.type]}</Badge>
                {property.providerId && <Badge variant="warning">من المزود</Badge>}
              </div>
              <p className="mt-1 text-sm text-muted">
                {property.city?.nameAr ?? "—"}
                {property.city?.province?.nameAr ? ` · ${property.city.province.nameAr}` : ""}
                {" · "}
                {Number(property.pricePerDay).toLocaleString("ar-IQ")} د.ع/يوم
              </p>
              {property.publishedAt && (
                <p className="mt-0.5 text-xs text-muted">
                  نُشر {relativeTimeAr(property.publishedAt)}
                </p>
              )}
            </div>
            <div className="flex flex-wrap gap-2">
              {previewUrl && (
                <a href={previewUrl} target="_blank" rel="noopener noreferrer">
                  <Button variant="ghost" size="sm">معاينة الموقع ↗</Button>
                </a>
              )}
              <Link href={`/bookings?propertyId=${property.id}`}>
                <Button variant="ghost" size="sm">الحجوزات</Button>
              </Link>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <StatChip label="مشاهدات" value={property.viewCount ?? 0} />
            <StatChip
              label="التقييم"
              value={
                property.ratingAvg != null ? (
                  <span className="inline-flex items-center gap-1">
                    {property.ratingAvg.toFixed(1)}
                    <RatingStars rating={property.ratingAvg} />
                  </span>
                ) : (
                  "—"
                )
              }
            />
            <StatChip label="حجوزات" value={property._count?.bookings ?? 0} />
            <StatChip label="تقييمات" value={property._count?.reviews ?? property.ratingCount ?? 0} />
            <StatChip label="صور" value={property.media?.length ?? 0} />
          </div>
        </div>
      </div>

      {children && (
        <div className="flex flex-col gap-2 border-t border-line pt-4 sm:flex-row sm:flex-wrap">
          {children}
        </div>
      )}
    </div>
  );
}

function StatChip({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-line bg-surface px-3 py-2 text-center min-w-[4.5rem]">
      <div className="text-sm font-bold text-ink">{value}</div>
      <div className="text-[10px] font-semibold text-muted">{label}</div>
    </div>
  );
}
