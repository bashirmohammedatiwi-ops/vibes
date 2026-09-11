function digitsOnly(phone: string) {
  return phone.replace(/\D/g, "");
}

/** يقبل 07XXXXXXXXX أو 7XXXXXXXXX أو +964 ويحوّله إلى 9647... */
export function normalizeIraqiPhone(raw: string) {
  let d = digitsOnly(raw);
  if (d.startsWith("00")) d = d.slice(2);
  if (d.startsWith("0") && d.length >= 10) d = `964${d.slice(1)}`;
  else if (d.startsWith("7") && d.length === 10) d = `964${d}`;
  return d;
}

export function toTelHref(phone: string) {
  const digits = digitsOnly(phone);
  if (!digits) return "";
  if (digits.startsWith("964")) return `tel:+${digits}`;
  if (digits.startsWith("0")) return `tel:+964${digits.slice(1)}`;
  return `tel:+${digits}`;
}

export function toWhatsAppHref(phone: string) {
  const digits = digitsOnly(phone);
  if (!digits) return "";
  const intl = digits.startsWith("964") ? digits : digits.startsWith("0") ? `964${digits.slice(1)}` : digits;
  return `https://wa.me/${intl}`;
}

type Props = {
  phone?: string | null;
  compact?: boolean;
};

export function PhoneActions({ phone, compact }: Props) {
  if (!phone) return null;
  const tel = toTelHref(phone);
  const wa = toWhatsAppHref(phone);
  if (!tel) return null;

  const cls = compact
    ? "rounded-lg border border-line bg-paper px-2 py-1 text-[11px] font-semibold text-accent hover:bg-accent-soft"
    : "rounded-xl border border-line bg-paper px-2.5 py-1.5 text-xs font-semibold text-accent hover:bg-accent-soft";

  return (
    <span className="inline-flex flex-wrap items-center gap-1" onClick={(e) => e.stopPropagation()}>
      <a href={tel} className={cls}>اتصال</a>
      <a href={wa} target="_blank" rel="noopener noreferrer" className={cls}>واتساب</a>
    </span>
  );
}
