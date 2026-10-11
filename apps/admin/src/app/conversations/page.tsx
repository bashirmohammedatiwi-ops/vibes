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

type StaffMember = { id: string; name: string | null; phone: string; role: string };

type ConversationRow = {
  id: string;
  kind: string;
  status: string;
  priority: string;
  staffNote: string;
  updatedAt: string;
  assignedTo?: { id: string; name: string | null } | null;
  _count?: { messages: number };
  messages?: Array<{ body: string; kind: string; createdAt: string }>;
  booking?: {
    id: string;
    status: string;
    property?: { name: string };
    user?: { name?: string | null; phone: string };
  } | null;
  property?: { name: string } | null;
  guest?: { id?: string; name?: string | null; phone: string } | null;
  participants?: Array<{ user: { id?: string; name?: string | null; phone: string; role: string } }>;
};

type MessageRow = {
  id: string;
  body: string;
  kind: string;
  imageUrl?: string | null;
  createdAt: string;
  sender?: { name?: string | null; phone?: string; role?: string } | null;
};

type CallRow = {
  id: string;
  status: string;
  createdAt: string;
  startedAt: string | null;
  endedAt: string | null;
  caller: { name: string | null; phone: string };
  callee: { name: string | null; phone: string };
};

const STATUS_LABEL: Record<string, string> = {
  OPEN: "بانتظار الرد",
  PENDING: "بانتظار العميل",
  RESOLVED: "محلولة",
  CLOSED: "مغلقة",
};

const STATUS_CLASS: Record<string, string> = {
  OPEN: "bg-[#C2402F]/10 text-[#C2402F] border-[#C2402F]/30",
  PENDING: "bg-accent/10 text-accent border-accent/30",
  RESOLVED: "bg-[#2E7D5B]/10 text-[#2E7D5B] border-[#2E7D5B]/30",
  CLOSED: "bg-black/5 text-muted border-line",
};

const PRIORITY_LABEL: Record<string, string> = {
  LOW: "منخفضة",
  NORMAL: "عادية",
  URGENT: "عاجلة",
};

export default function ConversationsPage() {
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const search = useSearchParams();
  const [data, setData] = useState<Paginated<ConversationRow> | null>(null);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState(search.get("q") ?? "");
  const qDebounced = useDebouncedValue(q);
  const [page, setPage] = useState(1);
  const [kind, setKind] = useState(search.get("kind") ?? "");
  const [status, setStatus] = useState(search.get("status") ?? "OPEN");
  const [openId, setOpenId] = useState<string | null>(search.get("open"));
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [calls, setCalls] = useState<CallRow[]>([]);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);
  const [note, setNote] = useState("");
  const [tab, setTab] = useState<"messages" | "calls" | "ops">("messages");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(
        await api<Paginated<ConversationRow>>(
          `/api/admin/conversations${buildQuery({ q: qDebounced, kind, status, page, pageSize: 15 })}`,
        ),
      );
    } finally {
      setLoading(false);
    }
  }, [qDebounced, kind, status, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  useEffect(() => {
    api<StaffMember[]>("/api/admin/conversations/staff")
      .then(setStaff)
      .catch(() => setStaff([]));
  }, []);

  useEffect(() => {
    const fromUrl = search.get("open");
    if (fromUrl) setOpenId(fromUrl);
  }, [search]);

  const openRow = data?.items.find((r) => r.id === openId) ?? null;

  useEffect(() => {
    if (!openId) return;
    setReply("");
    setNote(openRow?.staffNote ?? "");
    setTab("messages");
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
    api<CallRow[]>(`/api/admin/conversations/${openId}/calls`)
      .then((res) => { if (!cancelled) setCalls(res); })
      .catch(() => { if (!cancelled) setCalls([]); });
    const timer = window.setInterval(loadMessages, 4000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
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

  async function patchOps(payload: Record<string, unknown>) {
    if (!openId) return;
    try {
      await api(`/api/admin/conversations/${openId}/ops`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      toast("تم التحديث");
      load().catch(() => undefined);
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  return (
    <PageShell>
      <PageHeader title="محادثات الدعم" description="ردّ على عملائك، أسند الزملاء، وتابع سجل المكالمات — نفس نقاط النهاية التي سيستخدمها تطبيق الموظفين" eyebrow="تشغيل" />
      <HelpTip>الرسالة من العميل تفتح المحادثة تلقائياً، وردّك يعلّقها حتى يردّ العميل من جديد.</HelpTip>
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4">
          <FilterChips
            value={status || "all"}
            onChange={(id) => { setPage(1); setStatus(id === "all" ? "" : id); }}
            options={[
              { id: "OPEN", label: "بانتظار الرد" },
              { id: "PENDING", label: "بانتظار العميل" },
              { id: "RESOLVED", label: "محلولة" },
              { id: "CLOSED", label: "مغلقة" },
              { id: "all", label: "الكل" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث بالعميل أو المكان أو نص الرسالة..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <FilterChips
              value={kind || "all"}
              onChange={(id) => { setPage(1); setKind(id === "all" ? "" : id); }}
              options={[
                { id: "all", label: "كل الأنواع" },
                { id: "BOOKING", label: "حجوزات" },
                { id: "SUPPORT", label: "دعم" },
                { id: "CLAIM", label: "ربط مكان" },
              ]}
            />
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
          <EmptyState title="لا محادثات هنا" description="جرّب حالة أخرى أو مسح البحث" />
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
                      <div className="font-bold">{row.booking?.property?.name ?? row.property?.name ?? (row.kind === "CLAIM" ? "طلب ربط مكان" : row.kind === "SUPPORT" ? "دعم VIBES" : "محادثة")}</div>
                      <div className="text-xs text-muted">{row.booking?.user?.name ?? row.booking?.user?.phone ?? row.participants?.map((p) => p.user.name ?? p.user.phone).join(" · ")}</div>
                    </div>
                  ),
                },
                {
                  key: "status",
                  header: "الحالة",
                  cell: (row) => (
                    <div className="flex flex-col items-start gap-1">
                      <span className={`rounded-md border px-2 py-0.5 text-xs font-bold ${STATUS_CLASS[row.status] ?? STATUS_CLASS.CLOSED}`}>
                        {STATUS_LABEL[row.status] ?? row.status}
                      </span>
                      {row.priority === "URGENT" ? (
                        <span className="text-xs font-bold text-[#C2402F]">عاجلة</span>
                      ) : null}
                    </div>
                  ),
                },
                {
                  key: "assigned",
                  header: "المسؤول",
                  cell: (row) => row.assignedTo?.name ?? <span className="text-muted">غير مسند</span>,
                },
                {
                  key: "last",
                  header: "آخر رسالة",
                  cell: (row) => (
                    <span className="line-clamp-1 text-sm">
                      {row.messages?.[0]?.kind === "CALL" ? "📞 " : ""}
                      {row.messages?.[0]?.body || "—"}
                    </span>
                  ),
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

      <Modal open={!!openId} onClose={() => setOpenId(null)} title="كونسول المحادثة">
        {openRow ? (
          <div className="mb-3 flex flex-wrap items-center gap-2">
            <span className={`rounded-md border px-2 py-0.5 text-xs font-bold ${STATUS_CLASS[openRow.status] ?? STATUS_CLASS.CLOSED}`}>
              {STATUS_LABEL[openRow.status] ?? openRow.status}
            </span>
            {openRow.assignedTo ? (
              <span className="text-xs text-muted">المسؤول: {openRow.assignedTo.name}</span>
            ) : (
              <span className="text-xs text-muted">غير مسندة</span>
            )}
            <div className="ms-auto flex gap-2">
              {openRow.status !== "RESOLVED" ? (
                <Button variant="ghost" onClick={() => patchOps({ status: "RESOLVED" })}>وسمها محلولة</Button>
              ) : (
                <Button variant="ghost" onClick={() => patchOps({ status: "OPEN" })}>إعادة فتح</Button>
              )}
              <Button variant="ghost" onClick={() => patchOps({ priority: openRow.priority === "URGENT" ? "NORMAL" : "URGENT" })}>
                {openRow.priority === "URGENT" ? "خفض الاستعجال" : "وسمها عاجلة"}
              </Button>
            </div>
          </div>
        ) : null}

        <LinkPlaceBox
          kind={openRow?.kind}
          userId={
            openRow?.guest?.id ??
            openRow?.participants?.find((p) => p.user.role !== "ADMIN" && p.user.role !== "STAFF")?.user.id
          }
          userLabel={
            openRow?.guest?.name ??
            openRow?.guest?.phone ??
            openRow?.participants?.find((p) => p.user.role !== "ADMIN" && p.user.role !== "STAFF")?.user.name ??
            openRow?.participants?.find((p) => p.user.role !== "ADMIN" && p.user.role !== "STAFF")?.user.phone
          }
          userPhone={
            openRow?.guest?.phone ??
            openRow?.participants?.find((p) => p.user.role !== "ADMIN" && p.user.role !== "STAFF")?.user.phone
          }
          conversationId={openId}
          onLinked={() => load().catch(() => undefined)}
        />

        <div className="mb-3 flex gap-2 border-b border-line pb-2">
          {(["messages", "calls", "ops"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`rounded-lg px-3 py-1 text-sm font-bold ${tab === t ? "bg-accent text-accent-foreground" : "text-muted hover:bg-canvas"}`}
            >
              {t === "messages" ? "الرسائل" : t === "calls" ? `المكالمات (${calls.length})` : "الإدارة"}
            </button>
          ))}
        </div>

        {tab === "messages" ? (
          <>
            <div className="max-h-[46vh] space-y-3 overflow-y-auto">
              {messages.map((msg) => (
                <div key={msg.id} className={`rounded-xl p-3 text-sm ${msg.sender?.role === "ADMIN" || msg.sender?.role === "STAFF" ? "border border-accent/40 bg-accent/10 ms-8" : "bg-canvas me-8"}`}>
                  <div className="mb-1 flex items-center justify-between text-xs text-muted">
                    <span>{msg.kind === "SYSTEM" ? "النظام" : msg.kind === "CALL" ? "📞 مكالمة" : msg.sender?.name ?? msg.sender?.phone ?? "مستخدم"}</span>
                    <span>{relativeTimeAr(msg.createdAt)}</span>
                  </div>
                  {msg.imageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={msg.imageUrl} alt="" className="mb-2 max-h-40 rounded-lg" loading="lazy" decoding="async" />
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
                {openId && openRow?.booking?.id ? (
                  <Link href={`/bookings/${openRow.booking.id}`} className="text-sm text-accent underline">
                    فتح الحجز
                  </Link>
                ) : <span />}
                <Button disabled={sending || !reply.trim()} onClick={sendReply}>
                  {sending ? "جارٍ الإرسال..." : "إرسال الرد"}
                </Button>
              </div>
            </div>
          </>
        ) : tab === "calls" ? (
          <div className="max-h-[52vh] space-y-2 overflow-y-auto">
            {calls.length === 0 ? (
              <EmptyState title="لا مكالمات في هذه المحادثة" description="تظهر هنا مكالمات VIBES الصوتية بسجلها الكامل" />
            ) : (
              calls.map((call) => (
                <div key={call.id} className="flex items-center justify-between rounded-xl bg-canvas p-3 text-sm">
                  <div>
                    <div className="font-bold">{call.caller.name ?? call.caller.phone} → {call.callee.name ?? call.callee.phone}</div>
                    <div className="text-xs text-muted">{relativeTimeAr(call.createdAt)}</div>
                  </div>
                  <span
                    className={`rounded-md border px-2 py-0.5 text-xs font-bold ${
                      call.status === "ENDED"
                        ? "border-[#2E7D5B]/30 bg-[#2E7D5B]/10 text-[#2E7D5B]"
                        : call.status === "MISSED"
                          ? "border-[#C2402F]/30 bg-[#C2402F]/10 text-[#C2402F]"
                          : "border-accent/30 bg-accent/10 text-accent"
                    }`}
                  >
                    {call.status === "ENDED" ? "مكتملة" : call.status === "MISSED" ? "فائتة" : call.status === "ACTIVE" ? "جارية" : "ترنّ"}
                  </span>
                </div>
              ))
            )}
          </div>
        ) : (
          <div className="max-h-[52vh] space-y-4 overflow-y-auto">
            <div>
              <div className="mb-2 text-sm font-bold">الإسناد</div>
              <div className="flex flex-wrap gap-2">
                <Button variant="ghost" onClick={() => patchOps({ assignedToId: null })}>إلغاء الإسناد</Button>
                {staff.map((member) => (
                  <Button
                    key={member.id}
                    variant={openRow?.assignedTo?.id === member.id ? "accent" : "ghost"}
                    onClick={() => patchOps({ assignedToId: member.id })}
                  >
                    {member.name ?? member.phone}
                  </Button>
                ))}
              </div>
            </div>
            <div>
              <div className="mb-2 text-sm font-bold">ملاحظة داخلية (لا يراها العميل)</div>
              <Textarea
                placeholder="ملخص الحالة وما اتُّفق عليه..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
              />
              <div className="mt-2 flex justify-end">
                <Button disabled={note === (openRow?.staffNote ?? "")} onClick={() => patchOps({ staffNote: note })}>
                  حفظ الملاحظة
                </Button>
              </div>
            </div>
            <div className="flex gap-2">
              <Button variant="ghost" onClick={() => patchOps({ status: "CLOSED" })}>أرشفة المحادثة</Button>
              <Button variant="ghost" onClick={() => patchOps({ status: "OPEN" })}>إعادة فتح</Button>
            </div>
          </div>
        )}
      </Modal>
    </PageShell>
  );
}

type PropertySearchHit = {
  id: string;
  name: string;
  type?: string;
  city?: { nameAr?: string };
  provider?: {
    businessName?: string | null;
    user?: { name?: string | null; phone?: string };
  } | null;
};

function LinkPlaceBox({
  kind,
  userId,
  userLabel,
  userPhone,
  conversationId,
  onLinked,
}: {
  kind?: string;
  userId?: string;
  userLabel?: string | null;
  userPhone?: string | null;
  conversationId: string | null;
  onLinked?: () => void;
}) {
  const { toast } = useToast();
  const [q, setQ] = useState("");
  const debounced = useDebouncedValue(q);
  const [hits, setHits] = useState<PropertySearchHit[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [linked, setLinked] = useState<string | null>(null);

  useEffect(() => {
    setLinked(null);
  }, [conversationId, userId]);

  useEffect(() => {
    if (debounced.trim().length < 2) {
      setHits([]);
      return;
    }
    api<Paginated<PropertySearchHit>>(
      `/api/admin/properties${buildQuery({ q: debounced.trim(), pageSize: 8 })}`,
    )
      .then((data) => setHits(data.items ?? []))
      .catch(() => setHits([]));
  }, [debounced]);

  if (kind !== "CLAIM" && kind !== "SUPPORT" && !userId) return null;

  async function linkProperty(place: PropertySearchHit, force = false) {
    if (!userId) {
      toast("تعذر تحديد حساب العميل من هذه المحادثة", "error");
      return;
    }
    const owner = place.provider?.user?.phone ?? place.provider?.businessName;
    if (owner && !force) {
      const ok = window.confirm(
        `«${place.name}» مربوط حالياً بـ ${owner}. هل تريد نقل الملكية إلى ${userLabel ?? userPhone ?? "هذا الحساب"}؟`,
      );
      if (!ok) return;
    }
    setBusy(place.id);
    try {
      await api("/api/admin/providers/link", {
        method: "POST",
        body: JSON.stringify({
          userId,
          propertyId: place.id,
          conversationId,
        }),
      });
      setLinked(place.name);
      toast(`تم ربط «${place.name}» — سيظهر للمالك في بوابة المزود`);
      setQ("");
      setHits([]);
      onLinked?.();
    } catch (error) {
      toast(error instanceof Error ? error.message : "تعذر الربط", "error");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="mb-3 rounded-2xl border border-accent/25 bg-gradient-to-b from-accent/5 to-canvas p-4">
      <div className="mb-1 flex flex-wrap items-center gap-2">
        <span className="text-sm font-black text-ink">ربط مكان بالمالك</span>
        {kind === "CLAIM" ? (
          <span className="rounded-md border border-accent/30 bg-white px-2 py-0.5 text-[10px] font-bold text-accent">
            طلب ربط
          </span>
        ) : null}
      </div>
      {userId ? (
        <p className="mb-3 text-xs text-muted">
          الحساب: <span className="font-bold text-ink">{userLabel ?? "—"}</span>
          {userPhone ? <span className="ms-1 font-mono" dir="ltr">({userPhone})</span> : null}
        </p>
      ) : (
        <p className="mb-3 text-xs text-danger">لم يُحدد حساب العميل — افتح محادثة CLAIM أو SUPPORT مع ضيف مسجّل.</p>
      )}
      {linked ? (
        <div className="rounded-xl border border-[#2E7D5B]/30 bg-[#2E7D5B]/10 px-3 py-2 text-sm font-bold text-[#2E7D5B]">
          تم الربط: {linked}
        </div>
      ) : (
        <>
          <Input
            placeholder="ابحث باسم المزرعة أو القاعة أو المدينة..."
            value={q}
            onChange={(e) => setQ(e.target.value)}
            disabled={!userId}
          />
          <p className="mt-1 text-[10px] text-muted">يُفعّل دور المزود، يربط المكان، ويرسل رسالة نظام في المحادثة.</p>
          <div className="mt-2 max-h-48 space-y-1 overflow-y-auto">
            {debounced.trim().length >= 2 && hits.length === 0 ? (
              <p className="text-xs text-muted">لا نتائج — جرّب اسم أقصر أو مدينة أخرى.</p>
            ) : null}
            {hits.map((place) => {
              const taken = !!place.provider;
              return (
                <div
                  key={place.id}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-line bg-white px-3 py-2"
                >
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-bold">{place.name}</div>
                    <div className="text-[11px] text-muted">
                      {place.city?.nameAr ? `${place.city.nameAr} · ` : ""}
                      {taken
                        ? `مربوط: ${place.provider?.businessName || place.provider?.user?.phone || "مزود"}`
                        : "غير مربوط — جاهز للربط"}
                    </div>
                  </div>
                  <div className="flex shrink-0 gap-1">
                    <Link href={`/properties/${place.id}`} className="text-xs font-bold text-accent underline">
                      عرض
                    </Link>
                    <Button
                      className="px-2 py-1 text-xs"
                      variant={taken ? "ghost" : "accent"}
                      disabled={!userId || busy === place.id}
                      onClick={() => linkProperty(place)}
                    >
                      {busy === place.id ? "…" : taken ? "نقل الربط" : "ربط"}
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
