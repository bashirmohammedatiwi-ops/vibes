/** Local calendar date (Iraq timezone), avoiding UTC off-by-one. */
export function localIsoDate(date: Date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function parseLocalDate(iso: string) {
  const [y, m, d] = iso.slice(0, 10).split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

export function formatDayAr(iso: string) {
  return new Intl.DateTimeFormat("ar-IQ", {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(parseLocalDate(iso));
}

export function relativeTimeAr(iso: string) {
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60_000);
  if (Number.isNaN(mins)) return "";
  if (mins < 1) return "الآن";
  if (mins < 60) return `منذ ${mins} دقيقة`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `منذ ${hours} ساعة`;
  const days = Math.round(hours / 24);
  if (days === 1) return "أمس";
  if (days < 30) return `منذ ${days} يوم`;
  return new Intl.DateTimeFormat("ar-IQ", { dateStyle: "medium" }).format(new Date(iso));
}

export function formatShortDayAr(iso: string) {
  return new Intl.DateTimeFormat("ar-IQ", { day: "numeric", month: "short" }).format(parseLocalDate(iso));
}

export function formatMoney(value: number | string) {
  const n = Number(value);
  if (Number.isNaN(n)) return "—";
  return new Intl.NumberFormat("ar-IQ").format(n) + " د.ع";
}

export function formatMonthShort(ym: string) {
  const [y, m] = ym.split("-").map(Number);
  if (!y || !m) return ym;
  return new Intl.DateTimeFormat("ar-IQ", { month: "short" }).format(new Date(y, m - 1, 1));
}
