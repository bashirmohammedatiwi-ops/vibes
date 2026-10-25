"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Headphones, Loader2 } from "lucide-react";
import { api } from "@/lib/api";
import type { Conversation } from "@/lib/types";
import { relTime } from "@/lib/format";
import { EmptyState, PageSkeleton, RequireAuth } from "@/components/require-auth";

export default function MessagesPage() {
  return (
    <RequireAuth title="سجّل الدخول لعرض رسائلك">
      <Inbox />
    </RequireAuth>
  );
}

function conversationTitle(c: Conversation) {
  if (c.kind === "SUPPORT") return "دعم VIBES";
  return c.booking?.property?.name ?? c.property?.name ?? "محادثة";
}

function Inbox() {
  const router = useRouter();
  const [list, setList] = useState<Conversation[] | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const load = () => api<Conversation[]>("/api/conversations").then(setList).catch(() => setList([]));
    load();
    const t = setInterval(load, 15000);
    return () => clearInterval(t);
  }, []);

  async function support() {
    setBusy(true);
    try {
      const c = await api<{ id: string }>("/api/conversations/support", { method: "POST" });
      router.push(`/messages/${c.id}`);
    } catch {
      setBusy(false);
    }
  }

  if (!list) return <PageSkeleton />;
  return (
    <div className="container-x max-w-3xl py-8">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-2xl font-black md:text-3xl">الرسائل</h1>
        <button onClick={support} disabled={busy} className="btn btn-primary h-10 px-4 text-sm">
          {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Headphones className="h-4 w-4" />} تواصل مع الدعم
        </button>
      </div>
      <div className="mt-5 space-y-2">
        {list.length === 0 ? (
          <EmptyState icon="💬" title="لا محادثات بعد" text="محادثات حجوزاتك وأسئلتك لأصحاب الأماكن تظهر هنا." />
        ) : (
          list.map((c) => (
            <Link key={c.id} href={`/messages/${c.id}`} className="card flex items-center gap-3 p-4 transition hover:shadow-[var(--shadow-soft)]">
              <span
                className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl text-lg font-black ${
                  c.kind === "SUPPORT" ? "bg-midnight text-brass-light" : "bg-brass-pale text-brass-deep"
                }`}
              >
                {c.kind === "SUPPORT" ? <Headphones className="h-5 w-5" /> : conversationTitle(c).charAt(0)}
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate font-black">{conversationTitle(c)}</span>
                  <span className="shrink-0 text-[11px] text-ink-3">{relTime(c.lastMessage?.createdAt ?? c.updatedAt)}</span>
                </div>
                <div className="mt-0.5 flex items-center justify-between gap-2">
                  <span className="truncate text-sm text-ink-2">
                    {c.lastMessage ? (c.lastMessage.kind === "IMAGE" ? "📷 صورة" : c.lastMessage.body) : "ابدأ المحادثة"}
                  </span>
                  {!!c.unread && (
                    <span className="num flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-rose px-1.5 text-[10px] font-bold text-white">
                      {c.unread}
                    </span>
                  )}
                </div>
              </div>
            </Link>
          ))
        )}
      </div>
    </div>
  );
}
