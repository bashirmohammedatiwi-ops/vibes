"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useCallback, useEffect, useMemo, useState } from "react";
import { AdminOnly } from "@/components/admin-only";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { HelpTip } from "@/components/help-tip";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Label } from "@/components/ui/input";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { StatStrip } from "@/components/ui/stat-strip";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { useToast } from "@/components/ui/toast";
import { api } from "@/lib/api";

type StaffRow = {
  id: string;
  displayName: string;
  isActive: boolean;
  permissions: string[];
  lastSeenAt: string | null;
  user: { id: string; phone: string; name: string | null };
  presence: { state: string } | null;
};

type Group = { key: string; label: string; codes: string[] };

type Meta = {
  permissions: string[];
  labels: Record<string, string>;
  templates: Record<string, string[]>;
  groups?: Group[];
};

type Live = { waiting: number; answeredToday: number; missedToday: number; avgPacketLoss: number | null };

type Draft = {
  id: string | null;
  name: string;
  phone: string;
  pin: string;
  isActive: boolean;
  permissions: string[];
};

const TEMPLATE_LABELS: Record<string, { label: string; hint: string }> = {
  line: { label: "موظف خط", hint: "مكالمات ومحادثات وعرض الحجوزات" },
  bookings: { label: "الحجوزات", hint: "تأكيد وإلغاء واعتماد الدفع" },
  ops: { label: "العمليات", hint: "الحجوزات والمال والطلبات والتقارير" },
  content: { label: "المحتوى", hint: "الأماكن والبانرات والكوبونات والمرافق" },
  supervisor: { label: "مشرف", hint: "كل العمل اليومي مع الإسناد والمراقبة" },
  full: { label: "صلاحيات كاملة", hint: "كل ما في لوحة التحكم عدا إدارة الموظفين" },
};

const PRESENCE: Record<string, { label: string; variant: "success" | "warning" | "muted" | "default" }> = {
  AVAILABLE: { label: "متاح", variant: "success" },
  ON_CALL: { label: "في مكالمة", variant: "default" },
  AWAY: { label: "بعيد", variant: "warning" },
  OFFLINE: { label: "غير متصل", variant: "muted" },
};

function lastSeen(value: string | null) {
  if (!value) return "لم يسجّل دخولاً بعد";
  const min = Math.round((Date.now() - new Date(value).getTime()) / 60000);
  if (min < 1) return "نشط الآن";
  if (min < 60) return `آخر ظهور قبل ${min} د`;
  const h = Math.round(min / 60);
  if (h < 24) return `آخر ظهور قبل ${h} س`;
  return `آخر ظهور ${new Date(value).toLocaleDateString("ar-IQ", { day: "numeric", month: "short" })}`;
}

export default function StaffPage() {
  const { toast } = useToast();
  const [rows, setRows] = useState<StaffRow[] | null>(null);
  const [meta, setMeta] = useState<Meta | null>(null);
  const [live, setLive] = useState<Live | null>(null);
  const [q, setQ] = useState("");
  const [showInactive, setShowInactive] = useState(true);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [toggleTarget, setToggleTarget] = useState<StaffRow | null>(null);

  const load = useCallback(async () => {
    const [list, m, board] = await Promise.all([
      api<StaffRow[]>("/api/admin/staff"),
      api<Meta>("/api/admin/staff/meta"),
      api<Live>("/api/admin/staff/live").catch(() => null),
    ]);
    setRows(list);
    setMeta(m);
    setLive(board);
  }, []);

  useEffect(() => {
    load().catch((e) => toast(e instanceof Error ? e.message : "تعذّر التحميل", "error"));
    const timer = setInterval(() => {
      api<Live>("/api/admin/staff/live").then(setLive).catch(() => undefined);
    }, 6000);
    return () => clearInterval(timer);
  }, [load, toast]);

  const groups = useMemo<Group[]>(() => {
    if (!meta) return [];
    if (meta.groups?.length) {
      const grouped = new Set(meta.groups.flatMap((g) => g.codes));
      const rest = meta.permissions.filter((c) => !grouped.has(c));
      return rest.length ? [...meta.groups, { key: "other", label: "أخرى", codes: rest }] : meta.groups;
    }
    return [{ key: "all", label: "الصلاحيات", codes: meta.permissions }];
  }, [meta]);

  const filtered = useMemo(() => {
    const term = q.trim().toLowerCase();
    return (rows ?? []).filter((r) => {
      if (!showInactive && !r.isActive) return false;
      if (!term) return true;
      return `${r.displayName} ${r.user.phone} ${r.user.name ?? ""}`.toLowerCase().includes(term);
    });
  }, [rows, q, showInactive]);

  const counts = useMemo(() => {
    const list = rows ?? [];
    return {
      total: list.length,
      active: list.filter((r) => r.isActive).length,
      online: list.filter((r) => r.isActive && r.presence && r.presence.state !== "OFFLINE").length,
    };
  }, [rows]);

  const label = useCallback((code: string) => meta?.labels[code] ?? code, [meta]);

  function openCreate() {
    setDraft({ id: null, name: "", phone: "", pin: "", isActive: true, permissions: [...(meta?.templates.line ?? [])] });
  }

  function openEdit(row: StaffRow) {
    setDraft({
      id: row.id,
      name: row.displayName,
      phone: row.user.phone,
      pin: "",
      isActive: row.isActive,
      permissions: [...row.permissions],
    });
  }

  async function save() {
    if (!draft) return;
    if (!draft.name.trim()) return toast("اكتب اسم الموظف", "error");
    if (!draft.id && !draft.phone.trim()) return toast("اكتب رقم الهاتف", "error");
    if ((!draft.id || draft.pin) && !/^\d{4,6}$/.test(draft.pin)) return toast("الرمز السري من 4 إلى 6 أرقام", "error");
    if (!draft.permissions.length) return toast("اختر صلاحية واحدة على الأقل", "error");
    setSaving(true);
    try {
      if (draft.id) {
        await api(`/api/admin/staff/${draft.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            name: draft.name.trim(),
            permissions: draft.permissions,
            isActive: draft.isActive,
            ...(draft.pin ? { pin: draft.pin } : {}),
          }),
        });
        toast("تم حفظ التعديلات — تسري فوراً على تطبيق الموظف");
      } else {
        await api("/api/admin/staff", {
          method: "POST",
          body: JSON.stringify({
            phone: draft.phone.trim(),
            name: draft.name.trim(),
            pin: draft.pin,
            permissions: draft.permissions,
            isActive: draft.isActive,
          }),
        });
        toast("تم إنشاء حساب الموظف");
      }
      setDraft(null);
      await load();
    } catch (e) {
      toast(e instanceof Error ? e.message : "تعذّر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  async function confirmToggle() {
    if (!toggleTarget) return;
    try {
      await api(`/api/admin/staff/${toggleTarget.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: !toggleTarget.isActive }),
      });
      toast(toggleTarget.isActive ? "تم إيقاف الحساب وتسجيل خروجه" : "تم تفعيل الحساب");
      await load();
    } catch (e) {
      toast(e instanceof Error ? e.message : "تعذّر التحديث", "error");
    } finally {
      setToggleTarget(null);
    }
  }

  if (!rows || !meta) return <LoadingBlock />;

  return (
    <AdminOnly>
      <PageShell>
        <PageHeader
          title="الموظفون والصلاحيات"
          description="أنشئ حسابات تطبيق الموظفين وحدد بدقة ما يستطيع كل موظف رؤيته وفعله — التعديل يسري فوراً"
          eyebrow="VIBES Admin"
          action={<Button onClick={openCreate}>+ موظف جديد</Button>}
        />

        <StatStrip
          stats={[
            { label: "الموظفون", value: counts.total, hint: `${counts.active} مفعّل` },
            { label: "متصلون الآن", value: counts.online, accent: counts.online > 0 },
            { label: "مكالمات بالانتظار", value: live?.waiting ?? "—", alert: (live?.waiting ?? 0) > 0 },
            { label: "مُجابة اليوم", value: live?.answeredToday ?? "—" },
            { label: "فائتة اليوم", value: live?.missedToday ?? "—", alert: (live?.missedToday ?? 0) > 0 },
          ]}
        />

        <HelpTip>
          يدخل الموظف تطبيق الموظفين برقم هاتفه والرمز السري، ويرى فقط الأقسام التي تسمح بها صلاحياته. كل إجراء
          يُتحقق منه على الخادم أيضاً.
        </HelpTip>

        <PageToolbar>
          <Input className="max-w-xs flex-1" placeholder="بحث بالاسم أو الهاتف..." value={q} onChange={(e) => setQ(e.target.value)} />
          <ToggleChip active={showInactive} onClick={() => setShowInactive((v) => !v)}>إظهار الموقوفين</ToggleChip>
        </PageToolbar>

        {!filtered.length ? (
          <Card className="py-12 text-center">
            <p className="text-sm text-muted">لا موظفين مطابقين — أنشئ أول حساب للفريق</p>
          </Card>
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {filtered.map((row) => {
              const presence = PRESENCE[row.presence?.state ?? "OFFLINE"] ?? PRESENCE.OFFLINE;
              const pct = Math.round((row.permissions.length / Math.max(1, meta.permissions.length)) * 100);
              return (
                <Card key={row.id} className={`p-4 transition ${row.isActive ? "" : "opacity-60"}`}>
                  <div className="flex items-start gap-3">
                    <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-accent-soft text-lg font-black text-accent">
                      {row.displayName.trim().charAt(0) || "؟"}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="truncate font-bold text-ink">{row.displayName}</span>
                        {row.isActive ? <Badge variant={presence.variant}>{presence.label}</Badge> : <Badge variant="danger">موقوف</Badge>}
                      </div>
                      <div className="mt-0.5 text-xs text-muted" dir="ltr" style={{ textAlign: "right" }}>
                        {row.user.phone}
                      </div>
                      <div className="mt-0.5 text-xs text-muted">{lastSeen(row.lastSeenAt)}</div>
                    </div>
                  </div>

                  <div className="mt-3">
                    <div className="mb-1 flex items-center justify-between text-xs">
                      <span className="font-semibold text-ink">{row.permissions.length} صلاحية</span>
                      <span className="text-muted">{pct}%</span>
                    </div>
                    <div className="h-1.5 overflow-hidden rounded-full bg-line">
                      <div className="h-full rounded-full bg-accent" style={{ width: `${pct}%` }} />
                    </div>
                    <div className="mt-2 flex flex-wrap gap-1">
                      {groups
                        .filter((g) => g.codes.some((c) => row.permissions.includes(c)))
                        .map((g) => (
                          <span key={g.key} className="rounded-md bg-accent-soft px-2 py-0.5 text-[11px] font-semibold text-accent">
                            {g.label} {g.codes.filter((c) => row.permissions.includes(c)).length}/{g.codes.length}
                          </span>
                        ))}
                    </div>
                  </div>

                  <div className="mt-3 flex flex-wrap gap-2">
                    <Button size="sm" onClick={() => openEdit(row)}>تعديل الصلاحيات</Button>
                    <Button size="sm" variant={row.isActive ? "ghost" : "accent"} onClick={() => setToggleTarget(row)}>
                      {row.isActive ? "إيقاف" : "تفعيل"}
                    </Button>
                  </div>
                </Card>
              );
            })}
          </div>
        )}

        <StaffEditor
          draft={draft}
          groups={groups}
          templates={meta.templates}
          label={label}
          saving={saving}
          onChange={setDraft}
          onClose={() => setDraft(null)}
          onSave={save}
        />

        <ConfirmDialog
          open={!!toggleTarget}
          title={toggleTarget?.isActive ? "إيقاف حساب الموظف؟" : "تفعيل حساب الموظف؟"}
          message={
            toggleTarget?.isActive
              ? `سيُسجَّل خروج ${toggleTarget?.displayName ?? ""} من التطبيق فوراً ولن يستطيع الدخول حتى تعيد تفعيله.`
              : `سيتمكن ${toggleTarget?.displayName ?? ""} من الدخول بصلاحياته الحالية.`
          }
          confirmLabel={toggleTarget?.isActive ? "إيقاف" : "تفعيل"}
          danger={!!toggleTarget?.isActive}
          onConfirm={confirmToggle}
          onClose={() => setToggleTarget(null)}
        />
      </PageShell>
    </AdminOnly>
  );
}

function StaffEditor({
  draft,
  groups,
  templates,
  label,
  saving,
  onChange,
  onClose,
  onSave,
}: {
  draft: Draft | null;
  groups: Group[];
  templates: Record<string, string[]>;
  label: (code: string) => string;
  saving: boolean;
  onChange: (d: Draft) => void;
  onClose: () => void;
  onSave: () => void;
}) {
  const open = !!draft;
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    if (open) window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  function set<K extends keyof Draft>(key: K, value: Draft[K]) {
    if (draft) onChange({ ...draft, [key]: value });
  }

  function toggle(code: string) {
    if (!draft) return;
    const has = draft.permissions.includes(code);
    set("permissions", has ? draft.permissions.filter((c) => c !== code) : [...draft.permissions, code]);
  }

  function toggleGroup(codes: string[]) {
    if (!draft) return;
    const all = codes.every((c) => draft.permissions.includes(c));
    set(
      "permissions",
      all ? draft.permissions.filter((c) => !codes.includes(c)) : Array.from(new Set([...draft.permissions, ...codes])),
    );
  }

  const activeTemplate = draft
    ? Object.entries(templates).find(
        ([, codes]) => codes.length === draft.permissions.length && codes.every((c) => draft.permissions.includes(c)),
      )?.[0]
    : undefined;

  return (
    <AnimatePresence>
      {draft && (
        <motion.div
          className="modal-overlay fixed inset-0 z-[100] flex items-end justify-center p-0 sm:items-center sm:p-4"
          onClick={onClose}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.18 }}
        >
          <motion.div
            className="card-premium flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden"
            onClick={(e) => e.stopPropagation()}
            initial={{ opacity: 0, y: 24, scale: 0.985 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 12, scale: 0.985 }}
            transition={{ duration: 0.24, ease: [0.19, 1, 0.22, 1] }}
          >
            <div className="flex items-center justify-between gap-3 border-b border-line px-5 py-4">
              <div>
                <h2 className="text-lg font-bold text-ink">{draft.id ? `تعديل: ${draft.name || "موظف"}` : "موظف جديد"}</h2>
                <p className="text-xs text-muted">{draft.permissions.length} صلاحية محددة</p>
              </div>
              <button
                type="button"
                className="rounded-lg border border-line px-3 py-1 text-sm font-medium text-muted transition hover:bg-accent-soft hover:text-accent"
                onClick={onClose}
              >
                إغلاق
              </button>
            </div>

            <div className="flex-1 space-y-6 overflow-y-auto px-5 py-5">
              <section className="grid gap-3 sm:grid-cols-3">
                <div>
                  <Label>الاسم *</Label>
                  <Input value={draft.name} onChange={(e) => set("name", e.target.value)} placeholder="اسم الموظف" />
                </div>
                <div>
                  <Label>الهاتف {draft.id ? "" : "*"}</Label>
                  <Input
                    dir="ltr"
                    value={draft.phone}
                    disabled={!!draft.id}
                    onChange={(e) => set("phone", e.target.value)}
                    placeholder="9647XXXXXXXXX"
                  />
                </div>
                <div>
                  <Label>{draft.id ? "رمز سري جديد (اختياري)" : "الرمز السري *"}</Label>
                  <Input
                    dir="ltr"
                    inputMode="numeric"
                    maxLength={6}
                    value={draft.pin}
                    onChange={(e) => set("pin", e.target.value.replace(/\D/g, ""))}
                    placeholder="4–6 أرقام"
                  />
                </div>
              </section>

              <label className="flex cursor-pointer items-center justify-between rounded-xl border border-line px-4 py-3">
                <div>
                  <div className="text-sm font-semibold text-ink">الحساب مفعّل</div>
                  <div className="text-xs text-muted">عند الإيقاف يُسجَّل خروجه فوراً</div>
                </div>
                <input type="checkbox" className="h-5 w-5" checked={draft.isActive} onChange={(e) => set("isActive", e.target.checked)} />
              </label>

              <section>
                <div className="mb-2 text-sm font-bold text-ink">قوالب جاهزة</div>
                <div className="grid gap-2 sm:grid-cols-3">
                  {Object.entries(templates).map(([key, codes]) => {
                    const t = TEMPLATE_LABELS[key] ?? { label: key, hint: "" };
                    const on = activeTemplate === key;
                    return (
                      <button
                        key={key}
                        type="button"
                        onClick={() => set("permissions", [...codes])}
                        className={`rounded-xl border px-3 py-2 text-right transition ${
                          on ? "border-accent bg-accent-soft" : "border-line hover:bg-accent-soft/50"
                        }`}
                      >
                        <div className="flex items-center justify-between text-sm font-bold text-ink">
                          {t.label}
                          <span className="text-xs font-semibold text-muted">{codes.length}</span>
                        </div>
                        <div className="mt-0.5 text-[11px] text-muted">{t.hint}</div>
                      </button>
                    );
                  })}
                </div>
                <p className="mt-2 text-xs text-muted">اختر قالباً ثم عدّل الصلاحيات أدناه كما تشاء.</p>
              </section>

              <section className="space-y-3">
                {groups.map((g) => {
                  const on = g.codes.filter((c) => draft.permissions.includes(c)).length;
                  const all = on === g.codes.length;
                  return (
                    <div key={g.key} className="rounded-xl border border-line">
                      <div className="flex items-center justify-between gap-2 border-b border-line px-4 py-2.5">
                        <div className="text-sm font-bold text-ink">
                          {g.label}{" "}
                          <span className="text-xs font-semibold text-muted">
                            {on}/{g.codes.length}
                          </span>
                        </div>
                        <button type="button" className="text-xs font-semibold text-accent underline" onClick={() => toggleGroup(g.codes)}>
                          {all ? "إلغاء الكل" : "تحديد الكل"}
                        </button>
                      </div>
                      <div className="grid gap-1 p-2 sm:grid-cols-2">
                        {g.codes.map((code) => {
                          const checked = draft.permissions.includes(code);
                          return (
                            <label
                              key={code}
                              className={`flex cursor-pointer items-center gap-2 rounded-lg px-2.5 py-2 text-sm transition ${
                                checked ? "bg-accent-soft text-ink" : "text-muted hover:bg-accent-soft/50"
                              }`}
                            >
                              <input type="checkbox" checked={checked} onChange={() => toggle(code)} />
                              <span className="font-semibold">{label(code)}</span>
                            </label>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </section>
            </div>

            <div className="flex items-center justify-between gap-3 border-t border-line px-5 py-3">
              <span className="hidden text-xs text-muted sm:inline">التعديلات تسري فوراً على تطبيق الموظف</span>
              <div className="flex gap-2">
                <Button variant="ghost" onClick={onClose}>
                  إلغاء
                </Button>
                <Button onClick={onSave} disabled={saving}>
                  {saving ? "جارٍ الحفظ..." : draft.id ? "حفظ التعديلات" : "إنشاء الحساب"}
                </Button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
