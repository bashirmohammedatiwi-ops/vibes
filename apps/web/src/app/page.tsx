import Link from "next/link";
import { Fragment } from "react";
import { ChevronLeft, Sparkles, Ticket } from "lucide-react";
import { serverGet } from "@/lib/server";
import type { Banner, Coupon, Paged, PropertyCard, Province, Spotlight } from "@/lib/types";
import { HeroSearch } from "@/components/hero-search";
import { Rail, SectionHead } from "@/components/section";
import { moneyShort, num, sized } from "@/lib/format";

export const revalidate = 60;

type HomeLayout = { header: { key: string; enabled: boolean }[]; body: { key: string; enabled: boolean }[] };
const DEFAULT_LAYOUT: HomeLayout = {
  header: ["banners", "destinations"].map((key) => ({ key, enabled: true })),
  body: ["editorsPicks", "spotlights", "newArrivals", "winterFarms", "allPlaces", "coupon", "topRated", "occasions"].map((key) => ({ key, enabled: true })),
};

const list = (q: string) => serverGet<Paged<PropertyCard>>(`/api/properties?page=1&${q}`, 60).then((r) => r?.items ?? []);

export default async function Home() {
  const [layout, banners, spotlights, provinces, featured, fresh, top, farms, halls, decor, winter, coupons] = await Promise.all([
    serverGet<HomeLayout>("/api/home/layout", 60).then((r) => r ?? DEFAULT_LAYOUT),
    serverGet<Banner[]>("/api/banners", 120).then((r) => r ?? []),
    serverGet<Spotlight[]>("/api/spotlights", 120).then((r) => r ?? []),
    serverGet<Province[]>("/api/provinces", 600).then((r) => r ?? []),
    list("featured=true&pageSize=8"),
    list("isNew=true&sort=newest&pageSize=8"),
    list("sort=rating&pageSize=8"),
    list("type=FARM&pageSize=8"),
    list("type=HALL&pageSize=8"),
    list("type=DECORATION&pageSize=8"),
    list("type=FARM&winter=true&pageSize=8"),
    serverGet<Coupon[]>("/api/coupons", 120).then((r) => r ?? []),
  ]);

  const sections: Record<string, React.ReactNode> = {
    banners: (
      <>
      {/* ═══ البانرات ═══ */}
      {banners.length > 0 && (
        <section className="container-x pt-8">
          <div className="no-scrollbar flex snap-x gap-4 overflow-x-auto">
            {banners.map((b) => {
              const inner = (
                <div className="relative aspect-[2.4/1] w-[88vw] max-w-[720px] shrink-0 snap-start overflow-hidden rounded-3xl bg-champagne md:w-[620px]">
                  <img src={sized(b.imageUrl, 1080)} alt={b.title ?? ""} className="h-full w-full object-cover" />
                  {(b.title || b.subtitle) && (
                    <div className="absolute inset-0 flex flex-col justify-end bg-gradient-to-t from-black/60 via-black/10 to-transparent p-5 text-white">
                      {b.title && <div className="text-lg font-black">{b.title}</div>}
                      {b.subtitle && <div className="text-sm text-white/80">{b.subtitle}</div>}
                    </div>
                  )}
                </div>
              );
              return b.linkUrl ? (
                <a key={b.id} href={bannerHref(b.linkUrl)}>
                  {inner}
                </a>
              ) : (
                <div key={b.id}>{inner}</div>
              );
            })}
          </div>
        </section>
      )}
      </>
    ),
    editorsPicks: (
      <>
      <Rail title="مختارات VIBES" subtitle="أماكن اخترناها لك بعناية" items={featured} href="/search?sort=featured" />
      </>
    ),
    spotlights: (
      <>
      {/* ═══ أماكن مميزة (صور كبيرة) ═══ */}
      {spotlights.length > 0 && (
        <section className="container-x py-7">
          <SectionHead title="أماكن تلفت النظر" />
          <div className="grid gap-4 md:grid-cols-2">
            {spotlights.slice(0, 4).map((s) => (
              <Link
                key={s.id}
                href={`/go/${s.propertyId}`}
                className="group relative block overflow-hidden rounded-3xl bg-champagne"
                style={{ height: Math.max(180, (s.height ?? 176) * 1.15) }}
              >
                <img src={sized(s.imageUrl, 960)} alt={s.title ?? ""} className="h-full w-full object-cover transition duration-700 group-hover:scale-105" />
                <div className="absolute inset-0 flex flex-col justify-end bg-gradient-to-t from-black/60 to-transparent p-5 text-white">
                  <div className="text-lg font-black">{s.title || s.property?.name}</div>
                  {s.title && s.property?.name && <div className="text-sm text-white/80">{s.property.name}</div>}
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}
      </>
    ),
    newArrivals: (
      <>
      <Rail title="وصل حديثاً" subtitle="أماكن جديدة انضمت إلى VIBES" items={fresh} href="/search?sort=newest" />
      </>
    ),
    winterFarms: (
      <>
      {/* ═══ المزارع الشتوية ═══ */}
      {winter.length > 0 && (
        <div className="bg-gradient-to-b from-sky-50 to-transparent">
          <Rail title="مزارع شتوية ❄️" subtitle="دافئة ومجهّزة للشتاء — بعضها بمسبح مغلق" items={winter} href="/search?type=FARM&winter=true" />
        </div>
      )}
      </>
    ),
    allPlaces: (
      <>
      <Rail title="المزارع" subtitle="ضيافة الأرض والشمس" items={farms} href="/search?type=FARM" />
      <Rail title="قاعات المناسبات" subtitle="ليلة العمر تستحق قاعة" items={halls} href="/search?type=HALL" />
      <Rail title="فرق التزيين" subtitle="تفاصيل تصنع الفرح" items={decor} href="/search?type=DECORATION" />
      </>
    ),
    coupon: (
      <>
      {/* ═══ الكوبونات ═══ */}
      {coupons.length > 0 && (
        <section className="container-x py-7">
          <SectionHead title="كوبونات خصم" subtitle="استخدمها عند الحجز" href="/offers" />
          <div className="no-scrollbar -mx-4 flex gap-3 overflow-x-auto px-4 md:mx-0 md:px-0">
            {coupons.slice(0, 6).map((c) => (
              <div key={c.code} className="flex w-72 shrink-0 items-center gap-3 rounded-2xl border border-dashed border-brass bg-brass-pale/40 p-4">
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-white">
                  <Ticket className="h-6 w-6 text-brass-deep" />
                </span>
                <div className="min-w-0">
                  <div className="num text-lg font-extrabold text-midnight" dir="ltr">
                    {c.code}
                  </div>
                  <div className="truncate text-xs font-semibold text-ink-2">
                    {c.discountType === "PERCENT" ? `خصم ${num(c.discountValue)}٪` : `خصم ${moneyShort(c.discountValue)} د.ع`}
                    {c.description ? ` — ${c.description}` : ""}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      </>
    ),
    topRated: (
      <>
      <Rail title="الأعلى تقييماً" subtitle="ما أحبه ضيوفنا أكثر" items={top} href="/search?sort=rating" />
      </>
    ),
    destinations: (
      <>
      {/* ═══ المحافظات ═══ */}
      {provinces.length > 0 && (
        <section className="container-x py-7">
          <SectionHead title="تصفّح حسب المحافظة" />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
            {provinces.map((p) => (
              <Link
                key={p.id}
                href={`/search?province=${p.slug}`}
                className="group relative flex h-28 items-end overflow-hidden rounded-2xl bg-midnight p-3 text-white"
              >
                {p.imageUrl && (
                  <img src={sized(p.imageUrl, 480)} alt="" className="absolute inset-0 h-full w-full object-cover opacity-70 transition group-hover:scale-105" />
                )}
                <span className="absolute inset-0 bg-gradient-to-t from-black/70 to-transparent" />
                <span className="relative text-sm font-black">{p.nameAr}</span>
              </Link>
            ))}
          </div>
        </section>
      )}
      </>
    ),
    occasions: (
      <>
      {/* ═══ نديم ═══ */}
      <section className="container-x py-8">
        <Link
          href="/nadeem"
          className="hero-grain flex flex-col items-start gap-4 overflow-hidden rounded-[2rem] p-7 text-white md:flex-row md:items-center md:justify-between md:p-10"
        >
          <div>
            <div className="mb-2 inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1 text-xs font-bold text-brass-light">
              <Sparkles className="h-3.5 w-3.5" /> نديم
            </div>
            <h2 className="text-2xl font-black md:text-3xl">محتار؟ دع نديم يخطط لمناسبتك</h2>
            <p className="mt-2 max-w-lg text-sm text-white/70">أجب عن أسئلة بسيطة ونقترح عليك أنسب الأماكن مرتّبة حسب التطابق.</p>
          </div>
          <span className="btn btn-gold h-12 px-7">ابدأ مع نديم</span>
        </Link>
      </section>
      </>
    ),
  };

  return (
    <>
      {/* ═══ الواجهة ═══ */}
      <section className="hero-grain relative overflow-hidden">
        <div className="container-x relative flex flex-col items-center py-14 text-center md:py-24">
          <span className="mb-4 inline-flex items-center gap-1.5 rounded-full border border-white/15 bg-white/10 px-4 py-1.5 text-xs font-bold text-brass-light">
            <Sparkles className="h-3.5 w-3.5" /> مزارع · قاعات · تزيين — في كل العراق
          </span>
          <h1 className="max-w-3xl text-3xl font-black leading-tight text-white md:text-5xl md:leading-[1.25]">
            مناسبتك تستحق <span className="text-brass-light">مكاناً يليق بها</span>
          </h1>
          <p className="mt-4 max-w-xl text-sm leading-7 text-white/70 md:text-base">
            قارن الأسعار، شاهد الأيام المتاحة، واحجز صباحي أو مسائي أو يوم كامل — بخطوات بسيطة.
          </p>
          <div className="mt-8 w-full flex justify-center">
            <HeroSearch provinces={provinces} />
          </div>
        </div>
      </section>

      {/* ═══ العوالم ═══ */}
      <section className="container-x -mt-2 grid grid-cols-3 gap-3 pt-8 md:gap-5">
        {(
          [
            ["FARM", "المزارع", "ضيافة الأرض والشمس", "from-[#e0b568] to-[#8d6324]"],
            ["HALL", "القاعات", "ليلة العمر تستحق قاعة", "from-[#315879] to-[#0f2138]"],
            ["DECORATION", "التزيين", "تفاصيل تصنع الفرح", "from-[#f58aa3] to-[#c93a5c]"],
          ] as const
        ).map(([key, label, sub, grad]) => (
          <Link
            key={key}
            href={`/search?type=${key}`}
            className={`group relative overflow-hidden rounded-3xl bg-gradient-to-br ${grad} p-4 text-white shadow-[var(--shadow-card)] transition hover:-translate-y-0.5 md:p-6`}
          >
            <div className="text-lg font-black md:text-2xl">{label}</div>
            <div className="mt-0.5 text-[11px] font-semibold text-white/80 md:text-sm">{sub}</div>
            <ChevronLeft className="absolute bottom-3 left-3 h-5 w-5 opacity-70 transition group-hover:-translate-x-1" />
          </Link>
        ))}
      </section>

      {/* الأقسام وترتيبها من لوحة التحكم (الصفحة الرئيسية) — مشتركة مع التطبيق */}
      {[...layout.header, ...layout.body]
        .filter((it) => it.enabled && it.key in sections)
        .map((it) => (
          <Fragment key={it.key}>{sections[it.key]}</Fragment>
        ))}
    </>
  );
}

/** روابط البانر: داخلية (/property/…، /search…) أو خارجية. */
function bannerHref(link: string) {
  const m = link.match(/\/property\/([\w-]+)/);
  if (m) return `/go/${m[1]}`;
  return link;
}

