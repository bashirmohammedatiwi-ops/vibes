import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { BadgeCheck, CalendarClock, Clock, MapPin, Moon, Snowflake, Star, Sun, Users, Waves } from "lucide-react";
import { serverGet } from "@/lib/server";
import type { PropertyCard, PropertyDetail, Review } from "@/lib/types";
import { SITE_URL } from "@/lib/config";
import { clock, cover, fmtDate, modeOf, money, num, placeLine, sized, TYPE_LABEL } from "@/lib/format";
import { Gallery } from "./gallery";
import { BookingPanel } from "./booking-panel";
import { ContactOwner } from "./contact-owner";
import { Rail } from "@/components/section";
import { FavButton } from "@/components/fav-button";
import { ShareButton } from "./share-button";

type Params = { params: Promise<{ slug: string }> };

const load = (slug: string) => serverGet<PropertyDetail>(`/api/properties/slug/${encodeURIComponent(slug)}`, 60);

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  const p = await load(slug);
  if (!p) return { title: "المكان غير موجود" };
  const img = cover(p.media);
  const desc = (p.description || `${TYPE_LABEL[p.type]} في ${placeLine(p)} — احجز عبر VIBES`).slice(0, 160);
  return {
    title: `${p.name} — ${TYPE_LABEL[p.type]} في ${p.city?.nameAr ?? "العراق"}`,
    description: desc,
    alternates: { canonical: `${SITE_URL}/p/${p.slug}` },
    openGraph: { title: p.name, description: desc, images: img ? [sized(img, 1080)] : [], url: `${SITE_URL}/p/${p.slug}` },
  };
}

export default async function PropertyPage({ params }: Params) {
  const { slug } = await params;
  const p = await load(slug);
  if (!p) notFound();
  const [similar, reviews] = await Promise.all([
    serverGet<PropertyCard[]>(`/api/properties/${p.id}/similar`, 300).then((r) => r ?? []),
    serverGet<Review[]>(`/api/properties/${p.id}/reviews`, 120).then((r) => r ?? p.reviews ?? []),
  ]);
  const mode = modeOf(p);
  const rating = num(p.ratingAvg);
  const amenities = p.amenityLinks?.length
    ? p.amenityLinks.map((a) => ({ name: a.amenity.nameAr, value: a.value }))
    : (p.amenities ?? []).map((n) => ({ name: n, value: null }));
  const times = {
    morning: `${clock(p.morningStart || "08:00")} – ${clock(p.morningEnd || "14:00")}`,
    evening: `${clock(p.eveningStart || "16:00")} – ${clock(p.eveningEnd || "22:00")}`,
  };
  const lat = num(p.latitude);
  const lng = num(p.longitude);
  const visibleReviews = reviews.filter((r) => r.comment || r.rating);

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": p.type === "HALL" ? "EventVenue" : "LodgingBusiness",
    name: p.name,
    description: p.description ?? undefined,
    image: p.media?.filter((m) => m.type === "IMAGE").slice(0, 5).map((m) => m.url),
    address: { "@type": "PostalAddress", addressLocality: p.city?.nameAr, addressRegion: p.city?.province?.nameAr, addressCountry: "IQ" },
    geo: lat && lng ? { "@type": "GeoCoordinates", latitude: lat, longitude: lng } : undefined,
    aggregateRating: p.ratingCount > 0 ? { "@type": "AggregateRating", ratingValue: rating.toFixed(1), reviewCount: p.ratingCount } : undefined,
    priceRange: `${money(p.pricePerDay)} IQD`,
    url: `${SITE_URL}/p/${p.slug}`,
  };

  return (
    <div data-world={p.type} className="pb-20 lg:pb-0">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <div className="container-x pt-4 md:pt-8">
        <nav className="mb-3 flex items-center gap-1.5 text-xs font-semibold text-ink-3">
          <Link href="/" className="hover:text-ink">الرئيسية</Link>
          <span>/</span>
          <Link href={`/search?type=${p.type}`} className="hover:text-ink">{TYPE_LABEL[p.type]}</Link>
          {p.city?.province && (
            <>
              <span>/</span>
              <Link href={`/search?type=${p.type}&province=${p.city.province.slug}`} className="hover:text-ink">
                {p.city.province.nameAr}
              </Link>
            </>
          )}
        </nav>
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="mb-2 flex flex-wrap gap-1.5">
              <Tag className="bg-[var(--w-tint)] text-[var(--w-deep)]">{TYPE_LABEL[p.type]}</Tag>
              {p.featured && <Tag className="bg-brass-pale text-brass-deep">مختار من VIBES</Tag>}
              {p.isNew && <Tag className="bg-success-pale text-success">وصل حديثاً</Tag>}
              {p.isWinter && (
                <Tag className="bg-sky-50 text-sky-700">
                  <Snowflake className="h-3 w-3" /> مزرعة شتوية
                </Tag>
              )}
              {p.hasIndoorPool && (
                <Tag className="bg-teal-50 text-teal-700">
                  <Waves className="h-3 w-3" /> مسبح مغلق
                </Tag>
              )}
              {mode !== "FULL_DAY" && (
                <Tag className="bg-soft text-ink-2">
                  <Clock className="h-3 w-3" /> صباحي ومسائي
                </Tag>
              )}
            </div>
            <h1 className="text-2xl font-black leading-tight md:text-4xl">{p.name}</h1>
            <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm font-semibold text-ink-2">
              {p.ratingCount > 0 && (
                <a href="#reviews" className="flex items-center gap-1">
                  <Star className="h-4 w-4 fill-brass text-brass" />
                  <span className="num font-bold text-ink">{rating.toFixed(1)}</span>
                  <span className="num">({p.ratingCount} تقييم)</span>
                </a>
              )}
              {placeLine(p) && (
                <a href="#location" className="flex items-center gap-1">
                  <MapPin className="h-4 w-4 text-ink-3" />
                  {placeLine(p)}
                </a>
              )}
              {p.capacity > 0 && (
                <span className="flex items-center gap-1">
                  <Users className="h-4 w-4 text-ink-3" />
                  يتسع لـ <span className="num">{p.capacity}</span> ضيف
                </span>
              )}
            </div>
          </div>
          <div className="flex gap-2">
            <ShareButton title={p.name} />
            <FavButton id={p.id} className="!h-10 !w-10 border border-line" />
          </div>
        </div>
        <Gallery media={p.media ?? []} name={p.name} />
      </div>

      <div className="container-x grid gap-10 py-8 lg:grid-cols-[minmax(0,1fr)_400px]">
        <div className="min-w-0 space-y-10">
          {/* الأسعار */}
          <section>
            <h2 className="mb-4 text-xl font-black">الأسعار والأوقات</h2>
            <div className="grid gap-3 sm:grid-cols-3">
              {mode !== "SHIFTS" && (
                <PriceTile icon={<CalendarClock className="h-5 w-5" />} label="يوم كامل" price={p.pricePerDay} sub={mode === "FULL_DAY" ? "طوال اليوم" : `${clock(p.morningStart || "08:00")} – ${clock(p.eveningEnd || "22:00")}`} />
              )}
              {mode !== "FULL_DAY" && num(p.priceMorningShift) > 0 && (
                <PriceTile icon={<Sun className="h-5 w-5" />} label="فترة صباحية" price={p.priceMorningShift} sub={times.morning} />
              )}
              {mode !== "FULL_DAY" && num(p.priceEveningShift) > 0 && (
                <PriceTile icon={<Moon className="h-5 w-5" />} label="فترة مسائية" price={p.priceEveningShift} sub={times.evening} />
              )}
            </div>
            {num(p.weekendPrice) > 0 && (
              <p className="mt-3 text-sm text-ink-2">
                سعر عطلة نهاية الأسبوع: <span className="num font-bold text-ink">{money(p.weekendPrice)}</span> د.ع
              </p>
            )}
            <p className="mt-2 text-xs text-ink-3">الأسعار قد تختلف في بعض الأيام — السعر الدقيق لكل يوم يظهر في التقويم.</p>
          </section>

          {p.description && (
            <section>
              <h2 className="mb-3 text-xl font-black">عن المكان</h2>
              <p className="whitespace-pre-line leading-8 text-ink-2">{p.description}</p>
            </section>
          )}

          {amenities.length > 0 && (
            <section>
              <h2 className="mb-4 text-xl font-black">المزايا والخدمات</h2>
              <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
                {amenities.map((a, i) => (
                  <div key={i} className="flex items-center gap-2 rounded-2xl border border-line bg-white px-3.5 py-3 text-sm font-semibold">
                    <span className="h-2 w-2 shrink-0 rounded-full bg-[var(--w-accent)]" />
                    <span className="min-w-0 truncate">
                      {a.name}
                      {a.value ? <span className="text-ink-3"> · {a.value}</span> : null}
                    </span>
                  </div>
                ))}
              </div>
            </section>
          )}

          {p.rules && (
            <section>
              <h2 className="mb-3 text-xl font-black">قواعد المكان</h2>
              <p className="whitespace-pre-line rounded-2xl bg-cream p-4 text-sm leading-7 text-ink-2">{p.rules}</p>
            </section>
          )}

          {/* الموقع */}
          <section id="location" className="scroll-mt-24">
            <h2 className="mb-3 text-xl font-black">الموقع</h2>
            {p.address && <p className="mb-3 text-sm text-ink-2">{p.address}</p>}
            {lat && lng ? (
              <div className="overflow-hidden rounded-3xl border border-line">
                <iframe
                  title="الخريطة"
                  className="h-72 w-full"
                  loading="lazy"
                  src={`https://www.openstreetmap.org/export/embed.html?bbox=${lng - 0.02}%2C${lat - 0.012}%2C${lng + 0.02}%2C${lat + 0.012}&layer=mapnik&marker=${lat}%2C${lng}`}
                />
                <div className="flex flex-wrap gap-2 bg-white p-3">
                  <a className="btn btn-ghost h-10 px-4 text-sm" target="_blank" rel="noreferrer" href={`https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`}>
                    الاتجاهات في Google Maps
                  </a>
                  <a className="btn btn-ghost h-10 px-4 text-sm" target="_blank" rel="noreferrer" href={`https://waze.com/ul?ll=${lat},${lng}&navigate=yes`}>
                    Waze
                  </a>
                </div>
              </div>
            ) : (
              <p className="text-sm text-ink-3">{placeLine(p) || "الموقع يُرسل بعد الحجز"}</p>
            )}
          </section>

          {/* التقييمات */}
          <section id="reviews" className="scroll-mt-24">
            <h2 className="mb-4 flex items-center gap-2 text-xl font-black">
              التقييمات
              {p.ratingCount > 0 && (
                <span className="flex items-center gap-1 text-base">
                  <Star className="h-5 w-5 fill-brass text-brass" />
                  <span className="num">{rating.toFixed(1)}</span>
                  <span className="num text-sm text-ink-3">({p.ratingCount})</span>
                </span>
              )}
            </h2>
            {visibleReviews.length === 0 ? (
              <p className="rounded-2xl bg-cream p-5 text-sm text-ink-2">لا توجد تقييمات بعد — كن أول من يقيّم هذا المكان بعد حجزك.</p>
            ) : (
              <div className="grid gap-3 md:grid-cols-2">
                {visibleReviews.slice(0, 10).map((r) => (
                  <div key={r.id} className="card p-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="flex h-9 w-9 items-center justify-center rounded-full bg-midnight text-sm font-black text-brass-light">
                          {(r.user?.name || "ض").charAt(0)}
                        </span>
                        <div>
                          <div className="text-sm font-black">{r.user?.name || "ضيف VIBES"}</div>
                          <div className="text-[11px] text-ink-3">{fmtDate(r.createdAt)}</div>
                        </div>
                      </div>
                      <div className="flex" dir="ltr">
                        {Array.from({ length: 5 }).map((_, i) => (
                          <Star key={i} className={`h-3.5 w-3.5 ${i < r.rating ? "fill-brass text-brass" : "text-line-strong"}`} />
                        ))}
                      </div>
                    </div>
                    {r.comment && <p className="mt-3 text-sm leading-7 text-ink-2">{r.comment}</p>}
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* المزوّد */}
          {p.provider && (
            <section className="card flex flex-wrap items-center gap-4 p-5">
              <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-[var(--w-tint)] text-xl font-black text-[var(--w-deep)]">
                {(p.provider.businessName || p.provider.user?.name || "V").charAt(0)}
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1 font-black">
                  {p.provider.businessName || p.provider.user?.name}
                  {p.provider.verified && <BadgeCheck className="h-4 w-4 text-sky-600" />}
                </div>
                <div className="text-xs text-ink-3">
                  صاحب المكان
                  {p.provider._count?.followers ? ` · ${p.provider._count.followers} متابع` : ""}
                </div>
              </div>
              <Link href={`/provider/${p.provider.id}`} className="btn btn-ghost h-10 px-4 text-sm">
                كل أماكنه
              </Link>
              <ContactOwner propertyId={p.id} />
            </section>
          )}
        </div>

        <aside className="lg:sticky lg:top-24 lg:self-start">
          <BookingPanel property={p} />
        </aside>
      </div>

      <Rail title="أماكن مشابهة" items={similar.filter((s) => s.id !== p.id)} />
    </div>
  );
}

function Tag({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-black ${className}`}>{children}</span>;
}

function PriceTile({ icon, label, price, sub }: { icon: React.ReactNode; label: string; price: unknown; sub: string }) {
  return (
    <div className="rounded-2xl border border-line bg-white p-4">
      <div className="flex items-center gap-2 text-sm font-black text-[var(--w-deep)]">
        {icon}
        {label}
      </div>
      <div className="mt-2 flex items-baseline gap-1">
        <span className="num text-xl font-extrabold">{money(price)}</span>
        <span className="text-xs font-bold text-ink-3">د.ع</span>
      </div>
      <div className="mt-0.5 text-xs text-ink-3">{sub}</div>
    </div>
  );
}
