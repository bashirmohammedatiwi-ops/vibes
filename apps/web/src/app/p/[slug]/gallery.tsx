"use client";

import { useEffect, useState } from "react";
import { ChevronLeft, ChevronRight, Grid3x3, Play, X } from "lucide-react";
import type { Media } from "@/lib/types";
import { sized } from "@/lib/format";

export function Gallery({ media, name }: { media: Media[]; name: string }) {
  const items = media.filter((m) => m.url);
  const [open, setOpen] = useState<number | null>(null);

  useEffect(() => {
    if (open === null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(null);
      if (e.key === "ArrowLeft") setOpen((i) => (i === null ? i : (i + 1) % items.length));
      if (e.key === "ArrowRight") setOpen((i) => (i === null ? i : (i - 1 + items.length) % items.length));
    };
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = "";
      window.removeEventListener("keydown", onKey);
    };
  }, [open, items.length]);

  if (!items.length) {
    return <div className="flex aspect-[2.2/1] items-center justify-center rounded-3xl bg-[var(--w-tint)] text-5xl text-[var(--w-accent)]">✦</div>;
  }

  const thumb = (m: Media, w: number) => (m.type === "IMAGE" ? sized(m.url, w) : m.posterUrl || m.thumbnailUrl || "");

  return (
    <>
      {/* جوال: تمرير أفقي */}
      <div className="no-scrollbar -mx-4 flex snap-x snap-mandatory overflow-x-auto md:hidden">
        {items.map((m, i) => (
          <button key={m.id} onClick={() => setOpen(i)} className="relative aspect-[4/3] w-full shrink-0 snap-center bg-champagne">
            <img src={thumb(m, 800)} alt={`${name} — ${i + 1}`} className="h-full w-full object-cover" loading={i ? "lazy" : "eager"} />
            {m.type !== "IMAGE" && <PlayBadge />}
            <span className="num absolute bottom-3 left-3 rounded-full bg-black/55 px-2.5 py-1 text-xs font-bold text-white">
              {i + 1}/{items.length}
            </span>
          </button>
        ))}
      </div>
      {/* شاشة كبيرة: شبكة */}
      <div className="relative hidden h-[460px] grid-cols-4 grid-rows-2 gap-2 overflow-hidden rounded-3xl md:grid">
        {items.slice(0, 5).map((m, i) => (
          <button
            key={m.id}
            onClick={() => setOpen(i)}
            className={`group relative overflow-hidden bg-champagne ${i === 0 ? "col-span-2 row-span-2" : ""} ${items.length === 1 ? "col-span-4" : ""}`}
          >
            <img src={thumb(m, i === 0 ? 1440 : 640)} alt={`${name} — ${i + 1}`} className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]" />
            {m.type !== "IMAGE" && <PlayBadge />}
          </button>
        ))}
        {items.length > 5 && (
          <button onClick={() => setOpen(0)} className="btn btn-ghost absolute bottom-4 left-4 h-10 px-4 text-sm shadow">
            <Grid3x3 className="h-4 w-4" /> كل الصور ({items.length})
          </button>
        )}
      </div>

      {open !== null && (
        <div className="fixed inset-0 z-[60] flex flex-col bg-black/95" onClick={() => setOpen(null)}>
          <div className="flex items-center justify-between p-4 text-white">
            <span className="num text-sm">
              {open + 1} / {items.length}
            </span>
            <button aria-label="إغلاق" className="rounded-full bg-white/10 p-2">
              <X className="h-5 w-5" />
            </button>
          </div>
          <div className="relative flex flex-1 items-center justify-center px-2 pb-6" onClick={(e) => e.stopPropagation()}>
            {items[open].type === "IMAGE" ? (
              <img src={sized(items[open].url, 1440)} alt="" className="max-h-full max-w-full rounded-xl object-contain" />
            ) : (
              <video src={items[open].url} poster={items[open].posterUrl ?? undefined} controls autoPlay playsInline className="max-h-full max-w-full rounded-xl" />
            )}
            {items.length > 1 && (
              <>
                <button
                  onClick={() => setOpen((open - 1 + items.length) % items.length)}
                  className="absolute right-3 rounded-full bg-white/15 p-3 text-white hover:bg-white/25"
                  aria-label="السابق"
                >
                  <ChevronRight className="h-6 w-6" />
                </button>
                <button
                  onClick={() => setOpen((open + 1) % items.length)}
                  className="absolute left-3 rounded-full bg-white/15 p-3 text-white hover:bg-white/25"
                  aria-label="التالي"
                >
                  <ChevronLeft className="h-6 w-6" />
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </>
  );
}

function PlayBadge() {
  return (
    <span className="absolute inset-0 flex items-center justify-center">
      <span className="flex h-14 w-14 items-center justify-center rounded-full bg-black/45 text-white backdrop-blur">
        <Play className="h-6 w-6 fill-white" />
      </span>
    </span>
  );
}
