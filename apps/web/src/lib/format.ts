import type { BookingMode, BookingStatus, Media, PropertyCard, PropertyType, ShiftType } from "./types";

export const num = (v: unknown): number => {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : 0;
};

const nf = new Intl.NumberFormat("en-US");

/** 250000 → "250,000" */
export const money = (v: unknown) => nf.format(Math.round(num(v)));

/** 250000 → "250 ألف" ، 1500000 → "1.5 مليون" */
export function moneyShort(v: unknown) {
  const n = num(v);
  if (n >= 1_000_000) {
    const m = n / 1_000_000;
    return `${m % 1 === 0 ? m : m.toFixed(1)} مليون`;
  }
  if (n >= 1000) return `${Math.round(n / 1000)} ألف`;
  return nf.format(n);
}

export const TYPE_LABEL: Record<PropertyType, string> = {
  FARM: "مزرعة",
  HALL: "قاعة",
  DECORATION: "تزيين",
};

export const TYPE_PLURAL: Record<PropertyType, string> = {
  FARM: "المزارع",
  HALL: "القاعات",
  DECORATION: "التزيين",
};

export const SHIFT_LABEL: Record<ShiftType, string> = {
  MORNING: "صباحي",
  EVENING: "مسائي",
  FULL: "يوم كامل",
};

export const STATUS: Record<BookingStatus, { label: string; tone: "warn" | "ok" | "bad" | "muted" | "info" }> = {
  PENDING: { label: "بانتظار الدفع", tone: "warn" },
  AWAITING_PAYMENT: { label: "قيد مراجعة الدفع", tone: "info" },
  CONFIRMED: { label: "مؤكد", tone: "ok" },
  COMPLETED: { label: "مكتمل", tone: "muted" },
  CANCELLED: { label: "ملغى", tone: "bad" },
  DISPUTED: { label: "نزاع", tone: "bad" },
};

export function modeOf(p: Pick<PropertyCard, "bookingMode" | "type">): BookingMode {
  return p.bookingMode ?? (p.type === "FARM" ? "HYBRID" : "FULL_DAY");
}

/** أقل سعر يبدأ منه المكان. */
export function fromPrice(p: Pick<PropertyCard, "pricePerDay" | "priceMorningShift" | "priceEveningShift">) {
  const list = [p.pricePerDay, p.priceMorningShift, p.priceEveningShift].map(num).filter((n) => n > 0);
  return list.length ? Math.min(...list) : num(p.pricePerDay);
}

const SIZES = [360, 480, 640, 800, 960, 1080, 1440];

/** نسخة مصغّرة من صورة الخادم: /media/w/<عرض>/<ملف> */
export function sized(url: string | null | undefined, width: number): string {
  if (!url) return "";
  const legacy = "http://187.127.88.146:6001";
  if (url.startsWith(legacy)) url = "https://vibesiraq.com" + url.slice(legacy.length);
  const m = url.match(/^(https?:\/\/[^/]+)?\/media\/([A-Za-z0-9_.-]+\.(?:jpe?g|png|webp))$/i);
  if (!m) return url;
  const w = SIZES.find((s) => s >= width) ?? SIZES[SIZES.length - 1];
  return `${m[1] ?? ""}/media/w/${w}/${m[2]}`;
}

export function cover(media?: Media[] | null): string {
  if (!media?.length) return "";
  const img = media.find((m) => m.isPrimary && m.type === "IMAGE") ?? media.find((m) => m.type === "IMAGE") ?? media[0];
  return img.type === "IMAGE" ? img.url : img.posterUrl || img.thumbnailUrl || "";
}

export function placeLine(p: Pick<PropertyCard, "city">) {
  const c = p.city;
  if (!c) return "";
  const prov = c.province?.nameAr;
  return prov && prov !== c.nameAr ? `${c.nameAr}، ${prov}` : c.nameAr;
}

const dayFmt = new Intl.DateTimeFormat("ar-IQ-u-nu-latn", { weekday: "long", day: "numeric", month: "long" });
const shortFmt = new Intl.DateTimeFormat("ar-IQ-u-nu-latn", { day: "numeric", month: "short", year: "numeric" });

/** "2026-10-25" أو ISO → تاريخ محلي بلا انزياح المنطقة الزمنية. */
export function dateOnly(v: string): Date {
  const [y, m, d] = v.slice(0, 10).split("-").map(Number);
  return new Date(y, m - 1, d);
}

export const fmtDay = (v: string) => dayFmt.format(dateOnly(v));
export const fmtDate = (v: string) => shortFmt.format(dateOnly(v));
export const fmtDateTime = (v: string) =>
  new Date(v).toLocaleString("ar-IQ-u-nu-latn", { dateStyle: "medium", timeStyle: "short" });

export function ymd(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function addDays(d: Date, n: number) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

/** "14:00" → "2:00 م" */
export function clock(t?: string | null) {
  if (!t) return "";
  const [h, m] = t.split(":").map(Number);
  const suffix = h < 12 ? "ص" : "م";
  const hh = h % 12 === 0 ? 12 : h % 12;
  return `${hh}:${String(m || 0).padStart(2, "0")} ${suffix}`;
}

export function relTime(v: string) {
  const diff = (Date.now() - new Date(v).getTime()) / 1000;
  if (diff < 60) return "الآن";
  if (diff < 3600) return `قبل ${Math.floor(diff / 60)} د`;
  if (diff < 86400) return `قبل ${Math.floor(diff / 3600)} س`;
  if (diff < 86400 * 7) return `قبل ${Math.floor(diff / 86400)} يوم`;
  return fmtDate(v);
}
