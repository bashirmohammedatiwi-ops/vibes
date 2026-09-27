"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { PaginationBar } from "@/components/pagination-bar";
import { DataTable } from "@/components/ui/data-table";
import { ListRow } from "@/components/ui/list-row";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { relativeTimeAr } from "@/lib/dates";
import type { Paginated } from "@/lib/types";

type ConversationRow = {
  id: string;
  kind: string;
  updatedAt: string;
  _count?: { messages: number };
  messages?: Array<{ body: string; kind: string; createdAt: string }>;
  booking?: {
    id: string;
    status: string;
    property?: { name: string };
    user?: { name?: string | null; phone: string };
  } | null;
  participants?: Array<{ user: { name?: string | null; phone: string; role: string } }>;
};

type MessageRow = {
  id: string;
  body: string;
  kind: string;
  imageUrl?: string | null;
  createdAt: string;
  sender?: { name?: string | null; phone?: string; role?: string } | null;
};

export default function ConversationsPage() {
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const search = useSearchParams();
  const [data, setData] = useState<Paginated<ConversationRow> | null>(null);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState(search.get("q") ?? "");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);
  const [kind, setKind] = useState(search.get("kind") ?? "");
  const [openId, setOpenId] = useState<string | null>(search.get("open"));
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<ConversationRow>>(
          `/api/admin/conversations${buildQuery({ q: qDebounced, kind, page, pageSize: 15 })}`,
        ),
      );
    } finally {
      setLoading(false);
    }
  }, [qDebounced, kind, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  useEffect(() => {
    const fromUrl = search.get("open");
    if (fromUrl) setOpenId(fromUrl);
  }, [search]);

  useEffect(() => {
    if (!openId) return;
    setReply("");
    let cancelled = false;
    const loadMessages = () => {
      api<{ items: MessageRow[] }>(`/api/admin/conversations/${openId}/messages${buildQuery({ pageSize: 50 })}`)
        .then((res) => {
          if (!cancelled) setMessages([...res.items].reverse());
        })
        .catch(() => {
          if (!cancelled) setMessages([]);
        });
    };
    loadMessages();
    const timer = window.setInterval(loadMessages, 4000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [openId]);

  async function sendReply() {
    if (!openId || !reply.trim() || sending) return;
    setSending(true);
    try {
      await api(`/api/admin/conversations/${openId}/messages`, {
        method: "POST",
        body: JSON.stringify({ body: reply.trim() }),
      });
      setReply("");
      const res = await api<{ items: MessageRow[] }>(`/api/admin/conversations/${openId}/messages${buildQuery({ pageSize: 50 })}`);
      setMessages([...res.items].reverse());
      toast("تم إرسال الرد");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإرسال", "error");
    } finally {
      setSending(false);
    }
  }

  return (
    <PageShell>
      <PageHeader title="المحادثات" description="راقب تواصل العملاء مع الملاك ورسائل الدعم" eyebrow="تشغيل" />
      <HelpTip>المحادثة تُنشأ تلقائياً مع كل حجز. اضغط صفاً لقراءة الرسائل.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <FilterChips
            value={kind || "all"}
            onChange={(id) => { setPage(1); setKind(id === "all" ? "" : id); }}
            options={[
              { id: "all", label: "الكل" },
              { id: "BOOKING", label: "حجوزات" },
              { id: "SUPPORT", label: "دعم" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث بالعميل أو المكان..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Button variant="ghost" onClick={load}>تحديث</Button>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/conversations/export${buildQuery({ q: qDebounced, kind })}`, "conversations.csv")}
            >
              تصدير CSV
            </Button>
          </PageToolbar>
        </div>
        {loading ? (
          <SkeletonList />
        ) : !data?.items.length ? (
          <EmptyState title="لا محادثات بعد" description="ستظهر هنا محادثات الحجوزات والدعم" />
        ) : (
          <>
            <DataTable
              rows={data.items}
              rowKey={(row) => row.id}
              onRowClick={(row) => setOpenId(row.id)}
              columns={[
                {
                  key: "party",
                  header: "الأطراف",
                  cell: (row) => (
                    <div>
                      <div className="font-bold">{row.booking?.property?.name ?? (row.kind === "SUPPORT" ? "دعم VIBES" : "محادثة")}</div>
                      <div className="text-xs text-muted">{row.booking?.user?.name ?? row.booking?.user?.phone ?? row.participants?.map((p) => p.user.name ?? p.user.phone).join(" · ")}</div>
                    </div>
                  ),
                },
                {
                  key: "last",
                  header: "آخر رسالة",
                  cell: (row) => <span className="line-clamp-1 text-sm">{row.messages?.[0]?.body || "—"}</span>,
                },
                {
                  key: "count",
                  header: "الرسائل",
                  cell: (row) => row._count?.messages ?? 0,
                },
                {
                  key: "when",
                  header: "التحديث",
                  cell: (row) => relativeTimeAr(row.updatedAt),
                },
              ]}
            />
            <div className="space-y-2 p-3 md:hidden">
              {data.items.map((row) => (
                <ListRow
                  key={row.id}
                  title={row.booking?.property?.name ?? "محادثة"}
                  subtitle={row.messages?.[0]?.body}
                  onClick={() => setOpenId(row.id)}
                  badge={<span className="text-xs text-muted">{relativeTimeAr(row.updatedAt)}</span>}
                />
              ))}
            </div>
            <PaginationBar page={page} totalPages={data.totalPages} onPage={setPage} />
          </>
        )}
      </Card>

      <Modal open={!!openId} onClose={() => setOpenId(null)} title="سجل المحادثة">
        <div className="max-h-[60vh] space-y-3 overflow-y-auto">
          {messages.map((msg) => (
            <div key={msg.id} className="rounded-xl bg-canvas p-3 text-sm">
              <div className="mb-1 flex items-center justify-between text-xs text-muted">
                <span>{msg.kind === "SYSTEM" ? "النظام" : msg.sender?.name ?? msg.sender?.phone ?? "مستخدم"}</span>
                <span>{relativeTimeAr(msg.createdAt)}</span>
              </div>
              {msg.imageUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={msg.imageUrl} alt="" className="mb-2 max-h-40 rounded-lg" />
              ) : null}
              <p>{msg.body}</p>
            </div>
          ))}
        </div>
        <div className="mt-3 space-y-2">
          <Textarea
            placeholder="اكتب رداً كفريق VIBES..."
            value={reply}
            onChange={(e) => setReply(e.target.value)}
          />
          <div className="flex items-center justify-between gap-3">
            {openId && data?.items.find((r) => r.id === openId)?.booking?.id ? (
              <Link href={`/bookings/${data.items.find((r) => r.id === openId)?.booking?.id}`} className="text-sm text-accent underline">
                فتح الحجز
              </Link>
            ) : <span />}
            <Button disabled={sending || !reply.trim()} onClick={sendReply}>
              {sending ? "جارٍ الإرسال..." : "إرسال"}
            </Button>
          </div>
        </div>
      </Modal>
    </PageShell>
  );
}
