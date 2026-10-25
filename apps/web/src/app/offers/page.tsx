"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Check, Copy, Ticket } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { Coupon, PriceOffer } from "@/lib/types";
import { fmtDate, fmtDay, money, moneyShort, num, SHIFT_LABEL, TYPE_LABEL } from "@/lib/format";
import { EmptyState, StatusBadge } from "@/components/require-auth";

export default function OffersPage() {
  const { user } = useAuth();
  const [coupons, setCoupons] = useState<Coupon[] | null>(null);
  const [offers, setOffers] = useState<PriceOffer[] | null>(null);
  const [copied, setCopied] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    api<Coupon[]>("/api/coupons", { auth: false }).then(setCoupons).catch(() => setCoupons([]));
  }, []);
  useEffect(() => {
    if (user) api<PriceOffer[]>("/api/offers").then(setOffers).catch(() => setOffers([]));
  }, [user]);

  async function respond(o: PriceOffer, accept: boolean) {
    setBusy(o.id);
    try {
      const r = await api<PriceOffer & { booking?: { id: string } }>(`/api/offers/${o.id}/respond`, { method: "POST", body: { accept } });
      if (accept && r.booking?.id) location.href = `/bookings/${r.booking.id}?new=1`;
      else setOffers((list) => list?.map((x) => (x.id === o.id ? { ...x, status: r.status } : x)) ?? null);
    } catch (e) {
      alert(e instanceof Error ? e.message : "تعذر الرد على العرض");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="container-x max-w-4xl py-8">
      <h1 className="text-2xl font-black md:text-3xl">العروض والكوبونات</h1>

      {user && offers && offers.length > 0 && (
        <section className="mt-6">
          <h2 className="mb-3 text-lg font-black">عروض أسعار خاصة لك</h2>
          <div className="space-y-3">
            {offers.map((o) => (
              <div key={o.id} className="card p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="font-black">{o.property?.name}</div>
                    <div className="text-xs text-ink-3">من {o.provider?.businessName ?? "صاحب المكان"}</div>
                    <div className="mt-2 text-sm font-semibold text-ink-2">
                      {fmtDay(o.startDate)}
                      {o.shift ? ` · ${SHIFT_LABEL[o.shift]}` : ""}
                    </div>
                    {o.message && <p className="mt-2 text-sm text-ink-2">«{o.message}»</p>}
                  </div>
                  <div className="text-left">
                    <div className="num text-2xl font-extrabold">{money(o.amount)} د.ع</div>
                    {o.expiresAt && o.status === "PENDING" && <div className="text-[11px] text-ink-3">ينتهي {fmtDate(o.expiresAt)}</div>}
                  </div>
                </div>
                {o.status === "PENDING" ? (
                  <div className="mt-4 flex gap-2">
                    <button disabled={busy === o.id} onClick={() => respond(o, true)} className="btn btn-gold h-11 flex-1">
                      قبول وحجز
                    </button>
                    <button disabled={busy === o.id} onClick={() => respond(o, false)} className="btn btn-ghost h-11 px-6">
                      رفض
                    </button>
                  </div>
                ) : (
                  <div className="mt-3">
                    <StatusBadge tone={o.status === "ACCEPTED" ? "ok" : o.status === "DECLINED" ? "bad" : "muted"}>
                      {o.status === "ACCEPTED" ? "مقبول" : o.status === "DECLINED" ? "مرفوض" : "منتهي"}
                    </StatusBadge>
                    {o.bookingId && (
                      <Link href={`/bookings/${o.bookingId}`} className="mr-3 text-sm font-bold text-brass-deep">
                        عرض الحجز
                      </Link>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        </section>
      )}

      <section className="mt-6">
        <h2 className="mb-3 text-lg font-black">كوبونات الخصم</h2>
        {coupons === null ? (
          <div className="grid gap-3 sm:grid-cols-2">
            {[0, 1].map((i) => (
              <div key={i} className="skeleton h-28 rounded-3xl" />
            ))}
          </div>
        ) : coupons.length === 0 ? (
          <EmptyState icon="🎟️" title="لا كوبونات حالياً" text="تابعنا — نضيف خصومات باستمرار." />
        ) : (
          <div className="grid gap-3 sm:grid-cols-2">
            {coupons.map((c) => (
              <div key={c.code} className="relative overflow-hidden rounded-3xl border border-dashed border-brass bg-gradient-to-l from-brass-pale/60 to-white p-5">
                <div className="flex items-start gap-3">
                  <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-white shadow-sm">
                    <Ticket className="h-6 w-6 text-brass-deep" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="text-xl font-black text-midnight">
                      {c.discountType === "PERCENT" ? `خصم ${num(c.discountValue)}٪` : `خصم ${moneyShort(c.discountValue)} د.ع`}
                    </div>
                    {c.description && <p className="mt-0.5 text-sm text-ink-2">{c.description}</p>}
                    <div className="mt-1 space-x-reverse text-[11px] font-semibold text-ink-3">
                      {num(c.minBookingTotal) > 0 && <span>للحجوزات من {moneyShort(c.minBookingTotal)} د.ع · </span>}
                      {c.appliesToTypes?.length ? <span>{c.appliesToTypes.map((t) => TYPE_LABEL[t]).join("، ")} · </span> : null}
                      {c.property && <span>{c.property.name} · </span>}
                      {c.expiresAt && <span>حتى {fmtDate(c.expiresAt)}</span>}
                    </div>
                  </div>
                </div>
                <button
                  onClick={() => {
                    navigator.clipboard?.writeText(c.code);
                    setCopied(c.code);
                    setTimeout(() => setCopied(null), 1500);
                  }}
                  className="mt-4 flex w-full items-center justify-between rounded-2xl bg-white px-4 py-2.5"
                >
                  <span className="num text-lg font-extrabold tracking-widest" dir="ltr">
                    {c.code}
                  </span>
                  <span className="flex items-center gap-1 text-xs font-bold text-brass-deep">
                    {copied === c.code ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                    {copied === c.code ? "نُسخ" : "نسخ"}
                  </span>
                </button>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
