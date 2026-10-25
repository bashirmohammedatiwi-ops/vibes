"use client";

import Link from "next/link";
import { use, useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { CalendarDays, CheckCircle2, Clock, CreditCard, FileText, Loader2, MapPin, MessageCircle, Navigation, Star, Upload, Users, XCircle } from "lucide-react";
import { api } from "@/lib/api";
import type { Booking, Settings } from "@/lib/types";
import { clock, cover, fmtDateTime, fmtDay, money, num, placeLine, SHIFT_LABEL, sized, STATUS } from "@/lib/format";
import { PageSkeleton, RequireAuth, StatusBadge } from "@/components/require-auth";

export default function BookingPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  return (
    <RequireAuth title="سجّل الدخول لعرض الحجز">
      <BookingDetail id={id} />
    </RequireAuth>
  );
}

function BookingDetail({ id }: { id: string }) {
  const sp = useSearchParams();
  const [b, setB] = useState<Booking | null>(null);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const load = () =>
    api<Booking>(`/api/bookings/${id}`)
      .then(setB)
      .catch((e) => setErr(e instanceof Error ? e.message : "تعذر تحميل الحجز"));

  useEffect(() => {
    load();
    api<Settings>("/api/settings", { auth: false }).then(setSettings).catch(() => undefined);
  }, [id]); // eslint-disable-line react-hooks/exhaustive-deps

  if (err) return <div className="container-x py-16 text-center text-danger">{err}</div>;
  if (!b) return <PageSkeleton />;

  const p = b.property;
  const st = STATUS[b.status];
  const payable = b.status === "PENDING" || b.status === "AWAITING_PAYMENT";
  const img = cover(p?.media);
  const lat = num(p?.latitude);
  const lng = num(p?.longitude);
  const shiftTime =
    b.shift === "MORNING"
      ? `${clock(p?.morningStart || "08:00")} – ${clock(p?.morningEnd || "14:00")}`
      : b.shift === "EVENING"
        ? `${clock(p?.eveningStart || "16:00")} – ${clock(p?.eveningEnd || "22:00")}`
        : "";
  const endInclusive = (() => {
    const d = new Date(b.endDate.slice(0, 10));
    d.setDate(d.getDate() - 1);
    return d.toISOString().slice(0, 10);
  })();

  async function run(key: string, fn: () => Promise<unknown>, ok?: string) {
    setBusy(key);
    setMsg(null);
    try {
      await fn();
      if (ok) setMsg(ok);
      await load();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "تعذر تنفيذ الطلب");
    } finally {
      setBusy(null);
    }
  }

  async function uploadProof(file: File) {
    const fd = new FormData();
    fd.append("file", file);
    await run("proof", () => api(`/api/bookings/${b!.id}/payment-proof`, { method: "POST", body: fd }), "وصل الإيصال — سنراجع الدفع ونؤكد حجزك قريباً");
  }

  async function openChat() {
    setBusy("chat");
    try {
      const cid = b!.conversation?.id ?? (await api<{ id: string }>("/api/conversations/booking", { method: "POST", body: { bookingId: b!.id } })).id;
      location.href = `/messages/${cid}`;
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "تعذر فتح المحادثة");
      setBusy(null);
    }
  }

  async function openInvoice() {
    setBusy("invoice");
    try {
      const html = await api<string>(`/api/invoices/by-booking/${b!.id}/print`);
      const w = window.open("", "_blank");
      if (w) {
        w.document.open();
        w.document.write(typeof html === "string" ? html : String(html));
        w.document.close();
      }
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "تعذر فتح الفاتورة");
    } finally {
      setBusy(null);
    }
  }

  async function pay(method: "ZAIN_CASH" | "QI_CARD") {
    setBusy(method);
    try {
      const r = await api<{ redirectUrl?: string; message?: string }>(`/api/payments/booking/${b!.id}/initiate`, { method: "POST", body: { method } });
      if (r.redirectUrl) location.href = r.redirectUrl;
      else setMsg(r.message ?? "تعذر بدء الدفع");
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "تعذر بدء الدفع");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="container-x max-w-4xl py-8" data-world={p?.type ?? "FARM"}>
      <Link href="/bookings" className="text-sm font-bold text-ink-3 hover:text-ink">
        → حجوزاتي
      </Link>

      {sp.get("new") && (
        <div className="mt-4 flex items-start gap-3 rounded-3xl bg-success-pale p-5 animate-fade-up">
          <CheckCircle2 className="mt-0.5 h-6 w-6 shrink-0 text-success" />
          <div>
            <div className="font-black text-success">تم إرسال طلب الحجز</div>
            <p className="mt-0.5 text-sm text-ink-2">الموعد محجوز لك مؤقتاً — أكمل الدفع وأرسل الإيصال ليتأكد الحجز.</p>
          </div>
        </div>
      )}

      <div className="card mt-4 overflow-hidden">
        <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center">
          <div className="h-28 w-full shrink-0 overflow-hidden rounded-2xl bg-champagne sm:w-40">
            {img && <img src={sized(img, 480)} alt="" className="h-full w-full object-cover" />}
          </div>
          <div className="min-w-0 flex-1">
            <StatusBadge tone={st.tone}>{st.label}</StatusBadge>
            <h1 className="mt-1.5 text-xl font-black md:text-2xl">
              {p ? (
                <Link href={`/p/${p.slug}`} className="hover:text-[var(--w-deep)]">
                  {p.name}
                </Link>
              ) : (
                "حجز"
              )}
            </h1>
            {p && placeLine(p) && (
              <div className="mt-1 flex items-center gap-1 text-sm text-ink-2">
                <MapPin className="h-4 w-4 text-ink-3" /> {placeLine(p)}
              </div>
            )}
            <div className="num mt-1 text-[11px] text-ink-3" dir="ltr">
              #{b.id.slice(0, 8).toUpperCase()}
            </div>
          </div>
        </div>
        <div className="grid gap-px border-t border-line bg-line sm:grid-cols-3">
          <Info icon={<CalendarDays className="h-4 w-4" />} label="التاريخ" value={b.startDate.slice(0, 10) === endInclusive ? fmtDay(b.startDate) : `${fmtDay(b.startDate)} ← ${fmtDay(endInclusive)}`} />
          <Info icon={<Clock className="h-4 w-4" />} label="الفترة" value={`${b.shift ? SHIFT_LABEL[b.shift] : "يوم كامل"}${shiftTime ? ` · ${shiftTime}` : ""}`} />
          <Info icon={<Users className="h-4 w-4" />} label="الضيوف" value={b.guests ? `${b.guests} ضيف` : "—"} />
        </div>
        <div className="flex items-center justify-between border-t border-line p-5">
          <div>
            <div className="text-xs font-bold text-ink-3">الإجمالي</div>
            {num(b.discountAmount) > 0 && <div className="text-xs font-bold text-success">وفّرت {money(b.discountAmount)} د.ع</div>}
          </div>
          <div className="num text-2xl font-extrabold">{money(b.totalPrice)} د.ع</div>
        </div>
        {b.notes && <div className="border-t border-line px-5 py-3 text-sm text-ink-2">ملاحظاتك: {b.notes}</div>}
      </div>

      {msg && <div className="mt-4 rounded-2xl bg-sapphire-pale px-4 py-3 text-sm font-semibold text-sapphire">{msg}</div>}

      {/* الدفع */}
      {payable && (
        <section className="card mt-4 p-5">
          <h2 className="flex items-center gap-2 text-lg font-black">
            <CreditCard className="h-5 w-5 text-[var(--w-deep)]" /> الدفع
          </h2>
          {b.status === "AWAITING_PAYMENT" || b.payment?.proofUrl ? (
            <div className="mt-3 rounded-2xl bg-sapphire-pale/60 p-4 text-sm">
              <div className="font-black text-sapphire">استلمنا إيصال الدفع</div>
              <p className="mt-1 text-ink-2">نراجع التحويل الآن، وسيتأكد حجزك ونرسل لك إشعاراً.</p>
              {b.payment?.proofUrl && (
                <a href={b.payment.proofUrl} target="_blank" rel="noreferrer" className="mt-2 inline-block font-bold text-sapphire underline">
                  عرض الإيصال
                </a>
              )}
            </div>
          ) : null}
          {settings?.paymentInstructions && (
            <div className="mt-3 whitespace-pre-line rounded-2xl border border-dashed border-line-strong bg-cream p-4 text-sm leading-7">
              {settings.paymentInstructions}
            </div>
          )}
          <div className="mt-4 flex flex-wrap gap-2">
            <input
              ref={fileRef}
              type="file"
              accept="image/*,application/pdf"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) uploadProof(f);
                e.target.value = "";
              }}
            />
            <button onClick={() => fileRef.current?.click()} disabled={busy === "proof"} className="btn btn-world h-11 px-5 text-sm">
              {busy === "proof" ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
              {b.payment?.proofUrl ? "إرسال إيصال آخر" : "أرفق إيصال التحويل"}
            </button>
            {settings?.paymentGateways?.zainCash && (
              <button onClick={() => pay("ZAIN_CASH")} disabled={!!busy} className="btn btn-ghost h-11 px-5 text-sm">
                {busy === "ZAIN_CASH" && <Loader2 className="h-4 w-4 animate-spin" />} ادفع بزين كاش
              </button>
            )}
            {settings?.paymentGateways?.qiCard && (
              <button onClick={() => pay("QI_CARD")} disabled={!!busy} className="btn btn-ghost h-11 px-5 text-sm">
                {busy === "QI_CARD" && <Loader2 className="h-4 w-4 animate-spin" />} ادفع بكي كارد
              </button>
            )}
          </div>
        </section>
      )}

      {b.payment?.status === "PAID" && (
        <div className="mt-4 flex items-center gap-2 rounded-2xl bg-success-pale px-4 py-3 text-sm font-bold text-success">
          <CheckCircle2 className="h-5 w-5" /> تم الدفع — حجزك مؤكد
        </div>
      )}

      {/* الإجراءات */}
      <section className="mt-4 grid gap-2 sm:grid-cols-2">
        <ActionButton onClick={openChat} busy={busy === "chat"} icon={<MessageCircle className="h-4 w-4" />} label="محادثة الحجز" />
        {lat && lng ? (
          <a className="btn btn-ghost h-12" target="_blank" rel="noreferrer" href={`https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`}>
            <Navigation className="h-4 w-4" /> الاتجاهات إلى المكان
          </a>
        ) : null}
        {(b.invoice || b.status === "CONFIRMED" || b.status === "COMPLETED") && (
          <ActionButton onClick={openInvoice} busy={busy === "invoice"} icon={<FileText className="h-4 w-4" />} label="الفاتورة" />
        )}
        {payable && (
          <ActionButton
            danger
            busy={busy === "cancel"}
            icon={<XCircle className="h-4 w-4" />}
            label="إلغاء الحجز"
            onClick={() => {
              if (confirm("هل تريد إلغاء هذا الحجز؟")) run("cancel", () => api(`/api/bookings/${b.id}/cancel`, { method: "POST" }), "أُلغي الحجز");
            }}
          />
        )}
        {b.status === "CONFIRMED" && !b.cancellationRequests?.some((c) => c.status === "PENDING") && (
          <ActionButton
            danger
            busy={busy === "cancelreq"}
            icon={<XCircle className="h-4 w-4" />}
            label="طلب إلغاء"
            onClick={() => {
              const reason = prompt("سبب الإلغاء (اختياري)") ?? undefined;
              run("cancelreq", () => api("/api/cancellations", { method: "POST", body: { bookingId: b.id, reason } }), "أُرسل طلب الإلغاء — سنراجعه ونتواصل معك");
            }}
          />
        )}
      </section>
      {b.cancellationRequests?.[0] && (
        <p className="mt-3 rounded-2xl bg-warning-pale px-4 py-3 text-sm text-warning">
          طلب إلغاء: {b.cancellationRequests[0].status === "PENDING" ? "قيد المراجعة" : b.cancellationRequests[0].status}
          {num(b.cancellationRequests[0].expectedRefund) > 0 && ` · المبلغ المتوقع استرداده ${money(b.cancellationRequests[0].expectedRefund)} د.ع`}
        </p>
      )}

      {b.canReview && <ReviewForm propertyId={b.propertyId} />}

      <p className="mt-6 text-center text-xs text-ink-3">أُنشئ الحجز {fmtDateTime(b.createdAt)}</p>
    </div>
  );
}

function Info({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="bg-white p-4">
      <div className="flex items-center gap-1.5 text-xs font-bold text-ink-3">
        {icon} {label}
      </div>
      <div className="mt-1 text-sm font-black">{value}</div>
    </div>
  );
}

function ActionButton({ onClick, busy, icon, label, danger }: { onClick: () => void; busy?: boolean; icon: React.ReactNode; label: string; danger?: boolean }) {
  return (
    <button onClick={onClick} disabled={busy} className={`btn btn-ghost h-12 ${danger ? "!text-danger" : ""}`}>
      {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : icon}
      {label}
    </button>
  );
}

function ReviewForm({ propertyId }: { propertyId: string }) {
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");
  const [state, setState] = useState<"idle" | "busy" | "done">("idle");
  const [err, setErr] = useState<string | null>(null);
  if (state === "done")
    return <div className="mt-4 rounded-2xl bg-success-pale p-4 text-center text-sm font-bold text-success">شكراً لتقييمك ✨</div>;
  return (
    <section className="card mt-4 p-5">
      <h2 className="text-lg font-black">قيّم تجربتك</h2>
      <div className="mt-3 flex gap-1" dir="ltr">
        {[1, 2, 3, 4, 5].map((n) => (
          <button key={n} onClick={() => setRating(n)} aria-label={`${n} نجوم`}>
            <Star className={`h-8 w-8 ${n <= rating ? "fill-brass text-brass" : "text-line-strong"}`} />
          </button>
        ))}
      </div>
      <textarea className="field mt-3 min-h-[90px] text-sm" placeholder="اكتب رأيك (اختياري)" value={comment} onChange={(e) => setComment(e.target.value)} />
      {err && <p className="mt-2 text-sm text-danger">{err}</p>}
      <button
        disabled={!rating || state === "busy"}
        onClick={async () => {
          setState("busy");
          try {
            await api("/api/reviews", { method: "POST", body: { propertyId, rating, comment: comment.trim() || undefined } });
            setState("done");
          } catch (e) {
            setErr(e instanceof Error ? e.message : "تعذر إرسال التقييم");
            setState("idle");
          }
        }}
        className="btn btn-primary mt-3 h-11 px-6"
      >
        إرسال التقييم
      </button>
    </section>
  );
}
