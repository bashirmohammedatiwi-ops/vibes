"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { CalendarCheck, ChevronLeft, ChevronRight, Loader2, Minus, Moon, Plus, Sun, SunMoon, Ticket } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { Availability, DayPrice, PropertyDetail, ShiftType } from "@/lib/types";
import { addDays, clock, dateOnly, fmtDay, fromPrice, modeOf, money, moneyShort, num, SHIFT_LABEL, ymd } from "@/lib/format";

type Quote = { totalPrice: number; originalTotal: number; discount: number; nights: number; couponCode: string | null };

const MONTHS = 5;
const MAX_DAYS = 14;
const WEEK = ["أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];
const monthFmt = new Intl.DateTimeFormat("ar-IQ-u-nu-latn", { month: "long", year: "numeric" });

export function BookingPanel({ property: p }: { property: PropertyDetail }) {
  const router = useRouter();
  const { user } = useAuth();
  const mode = modeOf(p);
  const allowed: ShiftType[] = mode === "FULL_DAY" ? ["FULL"] : mode === "SHIFTS" ? ["MORNING", "EVENING"] : ["MORNING", "EVENING", "FULL"];

  const today = useMemo(() => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  }, []);
  const [shift, setShift] = useState<ShiftType>(allowed.includes("FULL") ? "FULL" : "MORNING");
  const [days, setDays] = useState<Map<string, DayPrice>>(new Map());
  const [closed, setClosed] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [month, setMonth] = useState(0);
  const [start, setStart] = useState<string | null>(null);
  const [end, setEnd] = useState<string | null>(null);
  const [guests, setGuests] = useState(Math.min(p.capacity || 50, 50) || 1);
  const [notes, setNotes] = useState("");
  const [couponInput, setCouponInput] = useState("");
  const [coupon, setCoupon] = useState<string | null>(null);
  const [quote, setQuote] = useState<Quote | null>(null);
  const [quoting, setQuoting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [booking, setBooking] = useState(false);

  // التوافر لخمسة أشهر بالتوازي
  useEffect(() => {
    const months = Array.from({ length: MONTHS }, (_, i) => {
      const d = new Date(today.getFullYear(), today.getMonth() + i, 1);
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    });
    Promise.all(months.map((m) => api<Availability>(`/api/properties/${p.id}/availability?month=${m}`, { auth: false }).catch(() => null)))
      .then((list) => {
        const map = new Map<string, DayPrice>();
        const off = new Set<string>();
        for (const a of list) {
          if (!a) continue;
          for (const d of a.dayPrices ?? []) map.set(d.date.slice(0, 10), d);
          for (const s of a.slots ?? []) if (!s.isAvailable) off.add(`${s.date.slice(0, 10)}:${s.shift}`);
        }
        setDays(map);
        setClosed(off);
      })
      .finally(() => setLoading(false));
  }, [p.id, today]);

  function isFree(date: string, s: ShiftType) {
    if (dateOnly(date) < today) return false;
    if (closed.has(`${date}:${s}`) || (s === "FULL" && (closed.has(`${date}:MORNING`) || closed.has(`${date}:EVENING`)))) return false;
    const d = days.get(date);
    if (!d) return true;
    if (d.bookableShifts) return d.bookableShifts.includes(s);
    if (d.isBlocked) return false;
    const taken = [...(d.bookedShifts ?? []), ...(d.blockedShifts ?? [])];
    if (s === "FULL") return taken.length === 0;
    return !taken.includes("FULL") && !taken.includes(s);
  }

  function priceOf(date: string, s: ShiftType) {
    const d = days.get(date);
    const fallback = s === "FULL" ? num(p.pricePerDay) : s === "MORNING" ? num(p.priceMorningShift) : num(p.priceEveningShift);
    if (!d) return fallback;
    const v = s === "FULL" ? d.prices.full : s === "MORNING" ? d.prices.morning : d.prices.evening;
    return num(v) || fallback;
  }

  /** حالة اليوم للفترة المختارة — للعرض فقط. */
  function dayState(date: string): "past" | "free" | "partial" | "busy" {
    if (dateOnly(date) < today) return "past";
    if (isFree(date, shift)) return "free";
    if (shift === "FULL" && allowed.some((s) => s !== "FULL" && isFree(date, s))) return "partial";
    if (shift !== "FULL" && allowed.some((s) => s !== shift && s !== "FULL" && isFree(date, s))) return "partial";
    return "busy";
  }

  function pick(date: string) {
    setError(null);
    if (!isFree(date, shift)) {
      const alt = allowed.filter((s) => s !== shift && isFree(date, s));
      setError(
        alt.length
          ? `${fmtDay(date)} غير متاح ${shift === "FULL" ? "ليوم كامل" : `للفترة ${SHIFT_LABEL[shift]}`} — متاح: ${alt.map((s) => SHIFT_LABEL[s]).join(" أو ")}`
          : `${fmtDay(date)} محجوز بالكامل`,
      );
      return;
    }
    // يوم كامل: نطاق أيام متتالية
    if (shift === "FULL" && start && end === start && date > start) {
      let cur = addDays(dateOnly(start), 1);
      let n = 1;
      while (ymd(cur) <= date) {
        if (!isFree(ymd(cur), "FULL")) {
          setError(`${fmtDay(ymd(cur))} محجوز — اختر أياماً متتالية متاحة`);
          return;
        }
        cur = addDays(cur, 1);
        if (++n > MAX_DAYS) {
          setError(`أقصى مدة ${MAX_DAYS} يوماً`);
          return;
        }
      }
      setEnd(date);
      return;
    }
    setStart(date);
    setEnd(date);
  }

  // التسعير من السيرفر
  useEffect(() => {
    if (!start || !end) {
      setQuote(null);
      return;
    }
    let live = true;
    setQuoting(true);
    api<Quote>("/api/bookings/quote", {
      method: "POST",
      body: {
        propertyId: p.id,
        startDate: start,
        endDate: ymd(addDays(dateOnly(end), 1)),
        shift,
        guests,
        ...(coupon ? { couponCode: coupon } : {}),
      },
    })
      .then((q) => live && setQuote(q))
      .catch((e) => {
        if (!live) return;
        setQuote(null);
        if (coupon) {
          setCoupon(null);
          setError(e instanceof Error ? e.message : "الكوبون غير صالح");
        }
      })
      .finally(() => live && setQuoting(false));
    return () => {
      live = false;
    };
  }, [start, end, shift, coupon, guests, p.id]);

  async function book() {
    if (!start || !end) return;
    if (!user) {
      router.push(`/login?next=${encodeURIComponent(location.pathname)}`);
      return;
    }
    setBooking(true);
    setError(null);
    try {
      const b = await api<{ id: string }>("/api/bookings", {
        method: "POST",
        body: {
          propertyId: p.id,
          startDate: start,
          endDate: ymd(addDays(dateOnly(end), 1)),
          shift,
          guests,
          notes: notes.trim() || undefined,
          ...(coupon ? { couponCode: coupon } : {}),
        },
      });
      router.push(`/bookings/${b.id}?new=1`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "تعذر إتمام الحجز");
      setBooking(false);
    }
  }

  const first = new Date(today.getFullYear(), today.getMonth() + month, 1);
  const lead = first.getDay();
  const count = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
  const cells: (string | null)[] = [...Array(lead).fill(null), ...Array.from({ length: count }, (_, i) => ymd(new Date(first.getFullYear(), first.getMonth(), i + 1)))];
  // يوم المغادرة: بعد المسائي أو اليوم الكامل
  const departure = end && shift !== "MORNING" ? ymd(addDays(dateOnly(end), 1)) : null;
  const nights = start && end ? Math.round((dateOnly(end).getTime() - dateOnly(start).getTime()) / 86400000) + 1 : 0;
  const shiftTime =
    shift === "MORNING"
      ? `${clock(p.morningStart || "08:00")} – ${clock(p.morningEnd || "14:00")}`
      : shift === "EVENING"
        ? `${clock(p.eveningStart || "16:00")} – ${clock(p.eveningEnd || "22:00")}`
        : null;

  return (
    <>
      <div id="book" className="card scroll-mt-24 overflow-hidden shadow-[var(--shadow-card)]">
        <div className="border-b border-line p-5">
          <div className="flex items-baseline gap-1">
            <span className="text-xs font-bold text-ink-3">يبدأ من</span>
            <span className="num text-2xl font-extrabold">{money(fromPrice(p))}</span>
            <span className="text-sm font-bold text-ink-3">د.ع</span>
          </div>
        </div>

        <div className="space-y-5 p-5">
          {/* الفترة */}
          {allowed.length > 1 && (
            <div>
              <div className="mb-2 text-sm font-black">اختر الفترة</div>
              <div className={`grid gap-2 ${allowed.length === 3 ? "grid-cols-3" : "grid-cols-2"}`}>
                {allowed.map((s) => {
                  const Icon = s === "MORNING" ? Sun : s === "EVENING" ? Moon : SunMoon;
                  const on = s === shift;
                  return (
                    <button
                      key={s}
                      onClick={() => {
                        setShift(s);
                        setError(null);
                        if (start && !isFree(start, s)) {
                          setStart(null);
                          setEnd(null);
                        } else if (s !== "FULL") setEnd(start);
                      }}
                      className={`rounded-2xl border-2 px-2 py-2.5 text-center transition ${
                        on ? "border-[var(--w-accent)] bg-[var(--w-tint)]" : "border-line bg-white hover:border-line-strong"
                      }`}
                    >
                      <Icon className={`mx-auto h-5 w-5 ${on ? "text-[var(--w-deep)]" : "text-ink-3"}`} />
                      <div className="mt-1 text-sm font-black">{SHIFT_LABEL[s]}</div>
                      <div className="num text-[10px] font-semibold text-ink-3">
                        {s === "MORNING"
                          ? `${clock(p.morningStart || "08:00")}–${clock(p.morningEnd || "14:00")}`
                          : s === "EVENING"
                            ? `${clock(p.eveningStart || "16:00")}–${clock(p.eveningEnd || "22:00")}`
                            : "اليوم كله"}
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* التقويم */}
          <div>
            <div className="mb-2 flex items-center justify-between">
              <button
                onClick={() => setMonth((m) => Math.max(0, m - 1))}
                disabled={month === 0}
                className="rounded-full p-1.5 hover:bg-cream disabled:opacity-30"
                aria-label="الشهر السابق"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
              <div className="text-sm font-black">{monthFmt.format(first)}</div>
              <button
                onClick={() => setMonth((m) => Math.min(MONTHS - 1, m + 1))}
                disabled={month === MONTHS - 1}
                className="rounded-full p-1.5 hover:bg-cream disabled:opacity-30"
                aria-label="الشهر التالي"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>
            </div>
            <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-bold text-ink-3">
              {WEEK.map((w) => (
                <div key={w} className="py-1">
                  {w}
                </div>
              ))}
            </div>
            <div className={`grid grid-cols-7 gap-1 ${loading ? "opacity-50" : ""}`}>
              {cells.map((d, i) => {
                if (!d) return <div key={`e${i}`} />;
                const st = dayState(d);
                const inRange = start && end && d >= start && d <= end;
                const isEdge = d === start || d === end;
                const isDeparture = !!departure && d === departure && !isEdge;
                return (
                  <button
                    key={d}
                    disabled={st === "past"}
                    onClick={() => pick(d)}
                    className={`flex h-11 items-center justify-center rounded-xl border text-[15px] font-bold transition ${
                      isEdge
                        ? "border-green-600 bg-green-600 text-white shadow-md"
                        : isDeparture
                          ? "flex-col border-2 border-green-600 bg-white text-green-700"
                          : inRange
                          ? "border-green-300 bg-green-100 text-green-800"
                          : st === "free"
                            ? "border-green-300 bg-green-50 text-green-700 hover:bg-green-100"
                            : st === "past"
                              ? "border-transparent text-line-strong"
                              : "border-red-200 bg-red-50 text-red-600"
                    }`}
                  >
                    <span className="num">{Number(d.slice(8))}</span>
                    {isDeparture && <span className="text-[9px] leading-none font-black">مغادرة</span>}
                  </button>
                );
              })}
            </div>
            <div className="mt-3 flex justify-center gap-6 text-sm font-bold text-ink">
              <Legend className="border border-green-500 bg-green-50" label="متاح" />
              <Legend className="border border-red-400 bg-red-50" label="غير متاح" />
            </div>
            {shift === "FULL" && <p className="mt-2 text-[11px] text-ink-3">لحجز عدة أيام: اختر يوم البداية ثم يوم النهاية.</p>}
          </div>

          {/* الضيوف */}
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm font-black">عدد الضيوف</div>
              {p.capacity > 0 && <div className="text-[11px] text-ink-3">السعة القصوى {p.capacity}</div>}
            </div>
            <div className="flex items-center gap-2">
              <button onClick={() => setGuests((g) => Math.max(1, g - (g > 50 ? 10 : 5)))} className="flex h-9 w-9 items-center justify-center rounded-full border border-line hover:bg-cream" aria-label="أقل">
                <Minus className="h-4 w-4" />
              </button>
              <input
                className="num w-16 rounded-xl border border-line py-1.5 text-center font-bold outline-none"
                value={guests}
                onChange={(e) => setGuests(Math.max(1, Number(e.target.value.replace(/\D/g, "")) || 1))}
                inputMode="numeric"
              />
              <button onClick={() => setGuests((g) => g + (g >= 50 ? 10 : 5))} className="flex h-9 w-9 items-center justify-center rounded-full border border-line hover:bg-cream" aria-label="أكثر">
                <Plus className="h-4 w-4" />
              </button>
            </div>
          </div>
          {p.capacity > 0 && guests > p.capacity && (
            <p className="-mt-3 text-xs font-semibold text-warning">العدد أكبر من سعة المكان ({p.capacity})</p>
          )}

          {/* الكوبون */}
          <div>
            {coupon ? (
              <div className="flex items-center justify-between rounded-2xl border border-dashed border-success bg-success-pale/50 px-4 py-2.5 text-sm">
                <span className="flex items-center gap-2 font-bold text-success">
                  <Ticket className="h-4 w-4" />
                  <span className="num" dir="ltr">{coupon}</span> مُطبّق
                </span>
                <button onClick={() => setCoupon(null)} className="text-xs font-bold text-ink-3 hover:text-danger">
                  إزالة
                </button>
              </div>
            ) : (
              <form
                className="flex gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (!couponInput.trim()) return;
                  if (!start) {
                    setError("اختر اليوم أولاً ثم طبّق الكوبون");
                    return;
                  }
                  setError(null);
                  setCoupon(couponInput.trim().toUpperCase());
                }}
              >
                <input className="field num h-11 !py-0 text-sm" dir="ltr" placeholder="كود الخصم" value={couponInput} onChange={(e) => setCouponInput(e.target.value)} />
                <button className="btn btn-ghost h-11 px-4 text-sm">تطبيق</button>
              </form>
            )}
          </div>

          <textarea className="field min-h-[70px] text-sm" placeholder="ملاحظات لصاحب المكان (اختياري)" value={notes} onChange={(e) => setNotes(e.target.value)} />

          {/* الملخص */}
          {start && end && (
            <div className="space-y-2 rounded-2xl bg-cream p-4 text-sm">
              <Row label="التاريخ" value={start === end ? fmtDay(start) : `${fmtDay(start)} ← ${fmtDay(end)}`} />
              <Row label="الفترة" value={`${SHIFT_LABEL[shift]}${shiftTime ? ` · ${shiftTime}` : ""}`} />
              {nights > 1 && <Row label="عدد الأيام" value={`${nights}`} />}
              {departure && <Row label="المغادرة" value={fmtDay(departure)} />}
              {quoting ? (
                <div className="flex items-center gap-2 text-ink-3">
                  <Loader2 className="h-4 w-4 animate-spin" /> يحسب السعر…
                </div>
              ) : quote ? (
                <>
                  {num(quote.discount) > 0 && (
                    <>
                      <Row label="السعر الأصلي" value={`${money(quote.originalTotal)} د.ع`} muted />
                      <Row label="الخصم" value={`− ${money(quote.discount)} د.ع`} good />
                    </>
                  )}
                  <div className="flex items-center justify-between border-t border-line pt-2">
                    <span className="font-black">الإجمالي</span>
                    <span className="num text-lg font-extrabold">{money(quote.totalPrice)} د.ع</span>
                  </div>
                </>
              ) : null}
            </div>
          )}

          {error && <p className="rounded-xl bg-danger-pale px-3 py-2 text-sm font-semibold text-danger">{error}</p>}

          <button onClick={book} disabled={!start || booking || quoting} className="btn btn-world h-13 w-full py-3.5 text-base">
            {booking ? (
              <>
                <Loader2 className="h-5 w-5 animate-spin" /> جاري الحجز…
              </>
            ) : !start ? (
              "اختر يوماً متاحاً"
            ) : (
              <>
                <CalendarCheck className="h-5 w-5" /> {user ? "احجز الآن" : "سجّل الدخول للحجز"}
              </>
            )}
          </button>
          <p className="text-center text-[11px] leading-5 text-ink-3">لن يُؤكَّد الحجز إلا بعد الدفع — ستظهر لك طريقة الدفع بعد الحجز.</p>
        </div>
      </div>

      {/* شريط الحجز على الجوال */}
      <div className="fixed inset-x-3 bottom-[5.25rem] z-30 flex items-center justify-between gap-3 rounded-2xl border border-line bg-white p-3 shadow-[var(--shadow-card)] lg:hidden">
        <div>
          <div className="text-[11px] font-bold text-ink-3">{quote ? "الإجمالي" : "يبدأ من"}</div>
          <div className="num text-lg font-extrabold">
            {money(quote ? quote.totalPrice : fromPrice(p))} <span className="text-xs text-ink-3">د.ع</span>
          </div>
        </div>
        <a href="#book" className="btn btn-world h-11 px-6 text-sm">
          {start ? "أكمل الحجز" : "اختر الموعد"}
        </a>
      </div>
    </>
  );
}

function Row({ label, value, muted, good }: { label: string; value: string; muted?: boolean; good?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-ink-2">{label}</span>
      <span className={`text-left font-bold ${muted ? "text-ink-3 line-through" : good ? "text-success" : ""}`}>{value}</span>
    </div>
  );
}

function Legend({ className, label }: { className: string; label: string }) {
  return (
    <span className="flex items-center gap-1.5">
      <i className={`inline-block h-3 w-3 rounded ${className}`} /> {label}
    </span>
  );
}
