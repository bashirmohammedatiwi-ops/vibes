"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { CalendarDays, ChevronLeft } from "lucide-react";
import { api } from "@/lib/api";
import type { Booking } from "@/lib/types";
import { cover, fmtDay, money, SHIFT_LABEL, sized, STATUS, TYPE_LABEL } from "@/lib/format";
import { EmptyState, PageSkeleton, RequireAuth, StatusBadge } from "@/components/require-auth";

export default function BookingsPage() {
  return (
    <RequireAuth title="سجّل الدخول لعرض حجوزاتك">
      <BookingsList />
    </RequireAuth>
  );
}

function BookingsList() {
  const [list, setList] = useState<Booking[] | null>(null);
  const [tab, setTab] = useState<"up" | "past">("up");

  useEffect(() => {
    api<Booking[]>("/api/bookings?scope=mine").then(setList).catch(() => setList([]));
  }, []);

  if (!list) return <PageSkeleton />;
  const today = new Date().toISOString().slice(0, 10);
  const upcoming = list.filter((b) => b.endDate.slice(0, 10) >= today && !["CANCELLED", "COMPLETED"].includes(b.status));
  const past = list.filter((b) => !upcoming.includes(b));
  const shown = tab === "up" ? upcoming : past;

  return (
    <div className="container-x max-w-4xl py-8">
      <h1 className="text-2xl font-black md:text-3xl">حجوزاتي</h1>
      <div className="mt-5 flex gap-2">
        <button onClick={() => setTab("up")} className={`chip ${tab === "up" ? "chip-on" : ""}`}>
          القادمة ({upcoming.length})
        </button>
        <button onClick={() => setTab("past")} className={`chip ${tab === "past" ? "chip-on" : ""}`}>
          السابقة والملغاة ({past.length})
        </button>
      </div>
      <div className="mt-5 space-y-3">
        {shown.length === 0 ? (
          <EmptyState
            icon="📅"
            title={tab === "up" ? "لا حجوزات قادمة" : "لا حجوزات سابقة"}
            text="ابحث عن مزرعة أو قاعة واحجز موعدك بخطوات بسيطة."
            action={
              <Link href="/search" className="btn btn-primary h-11 px-6">
                تصفّح الأماكن
              </Link>
            }
          />
        ) : (
          shown.map((b) => {
            const st = STATUS[b.status];
            const img = cover(b.property?.media);
            return (
              <Link key={b.id} href={`/bookings/${b.id}`} className="card flex items-center gap-4 p-3 transition hover:shadow-[var(--shadow-soft)]">
                <div className="h-20 w-24 shrink-0 overflow-hidden rounded-2xl bg-champagne">
                  {img && <img src={sized(img, 360)} alt="" className="h-full w-full object-cover" />}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <StatusBadge tone={st.tone}>{st.label}</StatusBadge>
                    {b.property && <span className="text-[11px] font-bold text-ink-3">{TYPE_LABEL[b.property.type]}</span>}
                  </div>
                  <div className="mt-1 truncate font-black">{b.property?.name ?? "مكان"}</div>
                  <div className="mt-0.5 flex flex-wrap items-center gap-x-3 text-xs font-semibold text-ink-2">
                    <span className="flex items-center gap-1">
                      <CalendarDays className="h-3.5 w-3.5" />
                      {fmtDay(b.startDate)}
                    </span>
                    {b.shift && <span>{SHIFT_LABEL[b.shift]}</span>}
                    <span className="num">{money(b.totalPrice)} د.ع</span>
                  </div>
                </div>
                <ChevronLeft className="h-5 w-5 shrink-0 text-ink-3" />
              </Link>
            );
          })
        )}
      </div>
    </div>
  );
}
