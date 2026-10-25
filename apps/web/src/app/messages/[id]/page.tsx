"use client";

import Link from "next/link";
import { use, useEffect, useRef, useState } from "react";
import { ArrowRight, Headphones, ImagePlus, Loader2, Send } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { Message } from "@/lib/types";
import { RequireAuth } from "@/components/require-auth";

type Detail = {
  id: string;
  kind: string;
  booking?: { id: string; status: string; property?: { id: string; name: string } } | null;
  property?: { id: string; name: string } | null;
};

export default function ChatPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  return (
    <RequireAuth>
      <Chat id={id} />
    </RequireAuth>
  );
}

const timeFmt = new Intl.DateTimeFormat("ar-IQ-u-nu-latn", { hour: "numeric", minute: "2-digit" });

function Chat({ id }: { id: string }) {
  const { user } = useAuth();
  const [detail, setDetail] = useState<Detail | null>(null);
  const [msgs, setMsgs] = useState<Message[]>([]);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const bottom = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const lastRef = useRef<string | null>(null);

  useEffect(() => {
    api<Detail>(`/api/conversations/${id}`).then(setDetail).catch((e) => setErr(e instanceof Error ? e.message : "تعذر فتح المحادثة"));
    api<Message[]>(`/api/conversations/${id}/messages?pageSize=100`).then((m) => {
      setMsgs(m);
      lastRef.current = m.at(-1)?.createdAt ?? null;
    });
  }, [id]);

  // سحب الرسائل الجديدة كل 3 ثوانٍ
  useEffect(() => {
    const t = setInterval(async () => {
      const after = lastRef.current;
      try {
        const fresh = await api<Message[]>(`/api/conversations/${id}/messages${after ? `?after=${encodeURIComponent(after)}` : ""}`);
        if (fresh.length) {
          setMsgs((cur) => {
            const seen = new Set(cur.map((m) => m.id));
            const add = fresh.filter((m) => !seen.has(m.id));
            return add.length ? [...cur, ...add] : cur;
          });
          lastRef.current = fresh.at(-1)!.createdAt;
        }
      } catch {}
    }, 3000);
    return () => clearInterval(t);
  }, [id]);

  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: "smooth" });
  }, [msgs.length]);

  function push(m: Message) {
    setMsgs((cur) => (cur.some((x) => x.id === m.id) ? cur : [...cur, m]));
    lastRef.current = m.createdAt;
  }

  async function send(e?: React.FormEvent) {
    e?.preventDefault();
    const body = text.trim();
    if (!body || sending) return;
    setSending(true);
    try {
      push(await api<Message>(`/api/conversations/${id}/messages`, { method: "POST", body: { body } }));
      setText("");
    } catch (e) {
      setErr(e instanceof Error ? e.message : "تعذر الإرسال");
    } finally {
      setSending(false);
    }
  }

  async function sendImage(f: File) {
    const fd = new FormData();
    fd.append("file", f);
    setSending(true);
    try {
      push(await api<Message>(`/api/conversations/${id}/messages/image`, { method: "POST", body: fd }));
    } catch (e) {
      setErr(e instanceof Error ? e.message : "تعذر إرسال الصورة");
    } finally {
      setSending(false);
    }
  }

  const title = detail?.kind === "SUPPORT" ? "دعم VIBES" : detail?.booking?.property?.name ?? detail?.property?.name ?? "محادثة";

  return (
    <div className="container-x flex h-[calc(100dvh-4rem)] max-w-3xl flex-col py-3 md:h-[calc(100dvh-5rem)]">
      <div className="flex items-center gap-3 border-b border-line pb-3">
        <Link href="/messages" className="rounded-full p-2 hover:bg-cream" aria-label="رجوع">
          <ArrowRight className="h-5 w-5" />
        </Link>
        <span className="flex h-10 w-10 items-center justify-center rounded-2xl bg-midnight text-brass-light">
          {detail?.kind === "SUPPORT" ? <Headphones className="h-5 w-5" /> : title.charAt(0)}
        </span>
        <div className="min-w-0 flex-1">
          <div className="truncate font-black">{title}</div>
          {detail?.booking && (
            <Link href={`/bookings/${detail.booking.id}`} className="text-xs font-bold text-brass-deep hover:underline">
              عرض الحجز
            </Link>
          )}
        </div>
      </div>

      <div className="no-scrollbar flex-1 space-y-2 overflow-y-auto py-4">
        {msgs.map((m) => {
          if (m.kind === "SYSTEM" || m.kind === "CALL")
            return (
              <div key={m.id} className="mx-auto w-fit max-w-[85%] rounded-full bg-soft px-3 py-1 text-center text-[11px] font-semibold text-ink-2">
                {m.body}
              </div>
            );
          const mine = m.senderId === user?.id;
          return (
            <div key={m.id} className={`flex ${mine ? "justify-start" : "justify-end"}`}>
              <div
                className={`max-w-[78%] rounded-3xl px-4 py-2.5 text-sm leading-6 ${
                  mine ? "rounded-br-md bg-midnight text-white" : "rounded-bl-md border border-line bg-white"
                }`}
              >
                {!mine && m.sender?.name && <div className="mb-0.5 text-[11px] font-black text-brass-deep">{m.sender.name}</div>}
                {m.imageUrl && (
                  <a href={m.imageUrl} target="_blank" rel="noreferrer">
                    <img src={m.imageUrl} alt="" className="mb-1 max-h-72 rounded-2xl object-cover" />
                  </a>
                )}
                {m.body && <div className="whitespace-pre-wrap break-words">{m.body}</div>}
                <div className={`mt-0.5 text-[10px] ${mine ? "text-white/60" : "text-ink-3"}`}>{timeFmt.format(new Date(m.createdAt))}</div>
              </div>
            </div>
          );
        })}
        <div ref={bottom} />
      </div>

      {err && <p className="mb-2 rounded-xl bg-danger-pale px-3 py-2 text-xs font-semibold text-danger">{err}</p>}
      <form onSubmit={send} className="flex items-end gap-2 border-t border-line pt-3">
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) sendImage(f);
            e.target.value = "";
          }}
        />
        <button type="button" onClick={() => fileRef.current?.click()} className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-line hover:bg-cream" aria-label="إرسال صورة">
          <ImagePlus className="h-5 w-5 text-ink-2" />
        </button>
        <textarea
          rows={1}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              send();
            }
          }}
          placeholder="اكتب رسالتك…"
          className="field max-h-32 min-h-12 flex-1 resize-none"
        />
        <button disabled={!text.trim() || sending} className="btn btn-primary h-12 w-12 shrink-0 !p-0" aria-label="إرسال">
          {sending ? <Loader2 className="h-5 w-5 animate-spin" /> : <Send className="h-5 w-5 -scale-x-100" />}
        </button>
      </form>
    </div>
  );
}
