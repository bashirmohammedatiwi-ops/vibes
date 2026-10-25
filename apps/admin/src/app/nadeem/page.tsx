"use client";

import { useEffect, useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Label, Select } from "@/components/ui/input";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { SimpleTabs } from "@/components/simple-tabs";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { api } from "@/lib/api";
import type { Paginated, Property } from "@/lib/types";
import { Grid, NumberField, Section, Switch, TextField, Toggle, TokenHint } from "@/components/nadeem/fields";
import { NadeemPreview } from "@/components/nadeem/preview";
import { NadeemStatsView } from "@/components/nadeem/stats";
import {
  ICON_EMOJI,
  ICON_LABEL,
  WORLD_COLOR,
  WORLD_LABEL,
  type NadeemAdminPayload,
  type NadeemConfig,
  type NadeemOccasion,
  type NadeemWorld,
} from "@/components/nadeem/types";

type Tab = "stats" | "general" | "occasions" | "steps" | "results" | "matching";

const WORLDS: NadeemWorld[] = ["FARM", "HALL", "DECORATION"];

export default function NadeemPage() {
  const { toast } = useToast();
  const [payload, setPayload] = useState<NadeemAdminPayload | null>(null);
  const [draft, setDraft] = useState<NadeemConfig | null>(null);
  const [tab, setTab] = useState<Tab>("stats");
  const [saving, setSaving] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);
  const [places, setPlaces] = useState<Property[]>([]);

  useEffect(() => {
    api<NadeemAdminPayload>("/api/admin/nadeem")
      .then((p) => {
        setPayload(p);
        setDraft(structuredClone(p.config));
      })
      .catch((err) => toast(err instanceof Error ? err.message : "تعذر التحميل", "error"));
    api<Paginated<Property>>("/api/admin/properties?status=APPROVED&pageSize=100")
      .then((r) => setPlaces(r.items))
      .catch(() => undefined);
  }, []);

  const dirty = useMemo(
    () => !!payload && !!draft && JSON.stringify(payload.config) !== JSON.stringify(draft),
    [payload, draft],
  );

  useEffect(() => {
    if (!dirty) return;
    const warn = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);

  function patch(fn: (c: NadeemConfig) => void) {
    setDraft((prev) => {
      if (!prev) return prev;
      const next = structuredClone(prev);
      fn(next);
      return next;
    });
  }

  async function save() {
    if (!draft) return;
    setSaving(true);
    try {
      const p = await api<NadeemAdminPayload>("/api/admin/nadeem", { method: "PUT", body: JSON.stringify(draft) });
      setPayload(p);
      setDraft(structuredClone(p.config));
      toast("حُفظت إعدادات نديم — تظهر في التطبيق خلال دقيقة");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  async function reset() {
    try {
      const p = await api<NadeemAdminPayload>("/api/admin/nadeem/reset", { method: "POST" });
      setPayload(p);
      setDraft(structuredClone(p.config));
      toast("أُعيد نديم إلى الإعدادات الأصلية");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذرت الإعادة", "error");
    } finally {
      setConfirmReset(false);
    }
  }

  if (!payload || !draft) {
    return (
      <PageShell>
        <PageHeader title="نديم" description="مخطّط المناسبات في تطبيق الزبون" />
        <SkeletonList count={5} />
      </PageShell>
    );
  }

  const c = draft;
  const editing = tab !== "stats";

  return (
    <PageShell>
      <PageHeader
        eyebrow="تطبيق الزبون"
        title="نديم"
        description="تحكم كامل بمخطّط المناسبات: ما يقوله، الأسئلة، المناسبات، طريقة اختيار الأماكن، والإحصاءات"
        action={
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant={c.enabled ? "success" : "warning"}>{c.enabled ? "يعمل في التطبيق" : "متوقف"}</Badge>
            {payload.customized && <Badge>معدّل</Badge>}
            <Button variant="ghost" size="sm" onClick={() => setConfirmReset(true)}>
              الإعدادات الأصلية
            </Button>
          </div>
        }
      />

      <SimpleTabs
        active={tab}
        onChange={(id) => setTab(id as Tab)}
        tabs={[
          { id: "stats", label: "الإحصاءات" },
          { id: "general", label: "عام" },
          { id: "occasions", label: "المناسبات", count: c.occasions.filter((o) => o.enabled).length },
          { id: "steps", label: "الأسئلة" },
          { id: "results", label: "الرسائل والنتائج" },
          { id: "matching", label: "المطابقة والأماكن" },
        ]}
      />

      <div className="mt-5">
        {tab === "stats" ? (
          <NadeemStatsView config={payload.config} />
        ) : (
          <div className="grid grid-cols-1 gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
            <div className="space-y-5 pb-24">
              {tab === "general" && <GeneralTab c={c} patch={patch} />}
              {tab === "occasions" && <OccasionsTab c={c} patch={patch} icons={payload.icons} />}
              {tab === "steps" && <StepsTab c={c} patch={patch} />}
              {tab === "results" && <ResultsTab c={c} patch={patch} />}
              {tab === "matching" && <MatchingTab c={c} patch={patch} places={places} defaults={payload.defaults} />}
            </div>
            <div className="hidden xl:block">
              <NadeemPreview config={c} />
            </div>
          </div>
        )}
      </div>

      {editing && (
        <div className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-surface/95 px-4 py-3 backdrop-blur lg:pr-[280px]">
          <div className="mx-auto flex max-w-6xl items-center justify-between gap-3">
            <span className="text-sm text-muted">
              {dirty ? "لديك تعديلات غير محفوظة" : "كل التعديلات محفوظة"}
              {payload.updatedAt && !dirty && (
                <span className="mr-2 text-xs">
                  · آخر حفظ {new Date(payload.updatedAt).toLocaleString("ar-IQ", { dateStyle: "short", timeStyle: "short" })}
                </span>
              )}
            </span>
            <div className="flex gap-2">
              <Button variant="ghost" disabled={!dirty || saving} onClick={() => setDraft(structuredClone(payload.config))}>
                تراجع
              </Button>
              <Button disabled={!dirty || saving} onClick={save}>
                {saving ? "جاري الحفظ…" : "حفظ ونشر"}
              </Button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={confirmReset}
        title="إعادة نديم للإعدادات الأصلية؟"
        message="ستُحذف كل التعديلات (النصوص، المناسبات، الأوزان، الأماكن المثبتة) ويعود نديم كما كان. الإحصاءات لا تتأثر."
        confirmLabel="إعادة"
        danger
        onConfirm={reset}
        onClose={() => setConfirmReset(false)}
      />
    </PageShell>
  );
}

type TabProps = { c: NadeemConfig; patch: (fn: (c: NadeemConfig) => void) => void };

// ═══════════════════ عام ═══════════════════

function GeneralTab({ c, patch }: TabProps) {
  return (
    <>
      <Section title="التشغيل والظهور" description="أوقف نديم مؤقتاً أو اخفه من أماكن ظهوره في التطبيق">
        <Toggle
          label="تشغيل نديم"
          hint="عند الإيقاف تظهر للزبون رسالة الاستراحة أدناه بدل المحادثة"
          checked={c.enabled}
          onChange={(v) => patch((d) => void (d.enabled = v))}
        />
        <Toggle
          label="زر نديم في الشريط السفلي"
          hint="الزر الأوسط في شريط التنقل بالتطبيق"
          checked={c.showInNav}
          onChange={(v) => patch((d) => void (d.showInNav = v))}
        />
        <Toggle
          label="اختصار نديم في الصفحة الرئيسية"
          hint="ضمن الاختصارات السريعة أعلى الرئيسية"
          checked={c.showOnHome}
          onChange={(v) => patch((d) => void (d.showOnHome = v))}
        />
      </Section>

      <Section title="الهوية" description="الاسم والوصف في رأس المحادثة">
        <Grid>
          <TextField label="الاسم" value={c.name} maxLength={30} onChange={(v) => patch((d) => void (d.name = v))} />
          <TextField
            label="الوصف تحت الاسم"
            value={c.subtitle}
            maxLength={80}
            onChange={(v) => patch((d) => void (d.subtitle = v))}
          />
          <TextField
            label="حالة الكتابة"
            value={c.typingLabel}
            maxLength={30}
            onChange={(v) => patch((d) => void (d.typingLabel = v))}
          />
          <NumberField
            label="سرعة الرد"
            suffix="مللي ثانية"
            hint="مدة ظهور «يكتب…» قبل كل رسالة (0 = فوري)"
            min={0}
            max={3000}
            value={c.typingDelayMs}
            onChange={(v) => patch((d) => void (d.typingDelayMs = v))}
          />
        </Grid>
      </Section>

      <Section
        title="رسائل الترحيب"
        description="أول ما يقوله نديم عند فتح المحادثة — حتى 6 رسائل"
        action={
          c.greeting.length < 6 ? (
            <Button size="sm" variant="ghost" onClick={() => patch((d) => void d.greeting.push(""))}>
              + رسالة
            </Button>
          ) : null
        }
      >
        {c.greeting.map((g, i) => (
          <div key={i} className="flex items-start gap-2">
            <span className="mt-2.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent-soft text-xs font-bold text-accent">
              {i + 1}
            </span>
            <Input value={g} maxLength={400} onChange={(e) => patch((d) => void (d.greeting[i] = e.target.value))} />
            <Button
              size="sm"
              variant="ghost"
              disabled={c.greeting.length <= 1}
              onClick={() => patch((d) => void d.greeting.splice(i, 1))}
              aria-label="حذف"
            >
              ✕
            </Button>
          </div>
        ))}
      </Section>

      <Section title="رسالة الإيقاف" description="تظهر حين يكون نديم متوقفاً">
        <TextField
          label="العنوان"
          value={c.disabledTitle}
          maxLength={80}
          onChange={(v) => patch((d) => void (d.disabledTitle = v))}
        />
        <TextField
          label="النص"
          multiline
          value={c.disabledMessage}
          onChange={(v) => patch((d) => void (d.disabledMessage = v))}
        />
      </Section>
    </>
  );
}

// ═══════════════════ المناسبات ═══════════════════

function OccasionsTab({ c, patch, icons }: TabProps & { icons: string[] }) {
  const [open, setOpen] = useState<number | null>(null);

  function move(i: number, dir: -1 | 1) {
    patch((d) => {
      const j = i + dir;
      if (j < 0 || j >= d.occasions.length) return;
      [d.occasions[i], d.occasions[j]] = [d.occasions[j], d.occasions[i]];
    });
    setOpen((o) => (o === i ? i + dir : o));
  }

  function add() {
    patch((d) =>
      void d.occasions.push({
        key: `custom${Date.now().toString(36)}`,
        enabled: true,
        label: "مناسبة جديدة",
        sub: "",
        icon: "party",
        world: "FARM",
        impliedType: "FARM",
        suggestDecor: false,
        reaction: "",
      }),
    );
    setOpen(c.occasions.length);
  }

  return (
    <>
      <Section title="السؤال الأول" description="أول سؤال بعد الترحيب">
        <TextField
          label="نص السؤال"
          value={c.occasionStep.question}
          onChange={(v) => patch((d) => void (d.occasionStep.question = v))}
        />
      </Section>

      <Section
        title="المناسبات"
        description="البطاقات التي يختار منها الزبون — رتّبها، عدّلها، أو أضف مناسبات جديدة (حتى 12)"
        action={
          c.occasions.length < 12 ? (
            <Button size="sm" onClick={add}>
              + مناسبة
            </Button>
          ) : null
        }
      >
        <div className="space-y-2">
          {c.occasions.map((o, i) => (
            <OccasionRow
              key={o.key}
              o={o}
              icons={icons}
              open={open === i}
              first={i === 0}
              last={i === c.occasions.length - 1}
              onToggleOpen={() => setOpen(open === i ? null : i)}
              onMove={(dir) => move(i, dir)}
              onRemove={() => {
                patch((d) => void d.occasions.splice(i, 1));
                setOpen(null);
              }}
              canRemove={c.occasions.length > 1}
              onChange={(fn) => patch((d) => fn(d.occasions[i]))}
            />
          ))}
        </div>
      </Section>
    </>
  );
}

function OccasionRow({
  o,
  icons,
  open,
  first,
  last,
  onToggleOpen,
  onMove,
  onRemove,
  canRemove,
  onChange,
}: {
  o: NadeemOccasion;
  icons: string[];
  open: boolean;
  first: boolean;
  last: boolean;
  onToggleOpen: () => void;
  onMove: (dir: -1 | 1) => void;
  onRemove: () => void;
  canRemove: boolean;
  onChange: (fn: (o: NadeemOccasion) => void) => void;
}) {
  return (
    <div className={`rounded-2xl border border-line ${o.enabled ? "bg-surface" : "bg-paper opacity-70"}`}>
      <div className="flex items-center gap-3 p-3">
        <span
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-xl"
          style={{ background: WORLD_COLOR[o.world].bg }}
        >
          {ICON_EMOJI[o.icon] ?? "✨"}
        </span>
        <button type="button" onClick={onToggleOpen} className="min-w-0 flex-1 text-right">
          <div className="font-bold text-ink">{o.label || "بدون اسم"}</div>
          <div className="truncate text-xs text-muted">
            {o.sub || "—"} · يقترح {o.impliedType ? WORLD_LABEL[o.impliedType] : "بلا افتراض"}
            {o.suggestDecor ? " + تزيين" : ""}
          </div>
        </button>
        <div className="flex items-center gap-1">
          <Button size="sm" variant="ghost" disabled={first} onClick={() => onMove(-1)} aria-label="للأعلى">
            ↑
          </Button>
          <Button size="sm" variant="ghost" disabled={last} onClick={() => onMove(1)} aria-label="للأسفل">
            ↓
          </Button>
          <Switch checked={o.enabled} onChange={(v) => onChange((x) => void (x.enabled = v))} />
          <Button size="sm" variant="ghost" onClick={onToggleOpen}>
            {open ? "إغلاق" : "تعديل"}
          </Button>
        </div>
      </div>
      {open && (
        <div className="space-y-4 border-t border-line p-4">
          <Grid>
            <TextField label="الاسم" value={o.label} maxLength={40} onChange={(v) => onChange((x) => void (x.label = v))} />
            <TextField
              label="الوصف الصغير"
              value={o.sub}
              maxLength={60}
              onChange={(v) => onChange((x) => void (x.sub = v))}
            />
          </Grid>
          <div>
            <Label>الأيقونة</Label>
            <div className="flex flex-wrap gap-1.5">
              {icons.map((ic) => (
                <button
                  key={ic}
                  type="button"
                  title={ICON_LABEL[ic] ?? ic}
                  onClick={() => onChange((x) => void (x.icon = ic))}
                  className={`flex h-10 w-10 items-center justify-center rounded-xl border text-lg transition ${
                    o.icon === ic ? "border-accent bg-accent-soft" : "border-line bg-paper hover:border-accent/50"
                  }`}
                >
                  {ICON_EMOJI[ic] ?? ic}
                </button>
              ))}
            </div>
          </div>
          <Grid>
            <div>
              <Label>لون البطاقة</Label>
              <Select value={o.world} onChange={(e) => onChange((x) => void (x.world = e.target.value as NadeemWorld))}>
                {WORLDS.map((w) => (
                  <option key={w} value={w}>
                    لون {WORLD_LABEL[w]}
                  </option>
                ))}
              </Select>
            </div>
            <div>
              <Label>النوع المقترح عند «اختر لي يا نديم»</Label>
              <Select
                value={o.impliedType ?? ""}
                onChange={(e) =>
                  onChange((x) => void (x.impliedType = e.target.value ? (e.target.value as NadeemWorld) : null))
                }
              >
                <option value="">بلا افتراض — كل الأنواع</option>
                {WORLDS.map((w) => (
                  <option key={w} value={w}>
                    {WORLD_LABEL[w]}
                  </option>
                ))}
              </Select>
            </div>
          </Grid>
          <TextField
            label="رد نديم بعد الاختيار"
            value={o.reaction}
            multiline
            onChange={(v) => onChange((x) => void (x.reaction = v))}
          />
          <Toggle
            label="اقتراح فرق تزيين مع النتائج"
            hint="يعرض نديم أفضل فرق التزيين تحت نتائج هذه المناسبة"
            checked={o.suggestDecor}
            onChange={(v) => onChange((x) => void (x.suggestDecor = v))}
          />
          <div className="flex items-center justify-between border-t border-line pt-3">
            <span dir="ltr" className="text-[11px] text-muted">
              key: {o.key}
            </span>
            <Button size="sm" variant="danger" disabled={!canRemove} onClick={onRemove}>
              حذف المناسبة
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════ الأسئلة ═══════════════════

function StepsTab({ c, patch }: TabProps) {
  return (
    <>
      <Section
        title="٢ · نوع المكان"
        description="مزرعة / قاعة / تزيين"
        muted={!c.typeStep.enabled}
        action={<Switch label="مفعّل" checked={c.typeStep.enabled} onChange={(v) => patch((d) => void (d.typeStep.enabled = v))} />}
      >
        <TextField label="السؤال" value={c.typeStep.question} onChange={(v) => patch((d) => void (d.typeStep.question = v))} />
        <Grid>
          <TextField
            label="الرد بعد اختيار نوع"
            value={c.typeStep.reaction}
            onChange={(v) => patch((d) => void (d.typeStep.reaction = v))}
          />
          <TextField
            label="الرد بعد «اختر لي»"
            value={c.typeStep.reactionAuto}
            onChange={(v) => patch((d) => void (d.typeStep.reactionAuto = v))}
          />
        </Grid>
        <div>
          <Label>الأنواع المعروضة</Label>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            {c.typeStep.types.map((t, i) => (
              <div key={t.key} className="flex items-center gap-2 rounded-xl border border-line p-2">
                <Switch
                  checked={t.enabled}
                  onChange={(v) =>
                    patch((d) => {
                      d.typeStep.types[i].enabled = v;
                      if (!d.typeStep.types.some((x) => x.enabled)) d.typeStep.types[i].enabled = true;
                    })
                  }
                />
                <Input
                  value={t.label}
                  maxLength={40}
                  onChange={(e) => patch((d) => void (d.typeStep.types[i].label = e.target.value))}
                />
              </div>
            ))}
          </div>
        </div>
        <Toggle
          label="خيار «اختر لي يا نديم»"
          hint="يترك الاختيار لنديم حسب المناسبة"
          checked={c.typeStep.allowAuto}
          onChange={(v) => patch((d) => void (d.typeStep.allowAuto = v))}
        />
        {c.typeStep.allowAuto && (
          <Grid>
            <TextField
              label="نص الزر"
              value={c.typeStep.autoLabel}
              onChange={(v) => patch((d) => void (d.typeStep.autoLabel = v))}
            />
            <TextField
              label="فقاعة إجابة الزبون"
              value={c.typeStep.autoAnswer}
              onChange={(v) => patch((d) => void (d.typeStep.autoAnswer = v))}
            />
          </Grid>
        )}
        <Toggle
          label="إظهار عدد الأماكن تحت كل نوع"
          checked={c.typeStep.showCounts}
          onChange={(v) => patch((d) => void (d.typeStep.showCounts = v))}
        />
      </Section>

      <Section
        title="٣ · المحافظة"
        muted={!c.provinceStep.enabled}
        action={
          <Switch label="مفعّل" checked={c.provinceStep.enabled} onChange={(v) => patch((d) => void (d.provinceStep.enabled = v))} />
        }
      >
        <TextField
          label="السؤال"
          value={c.provinceStep.question}
          onChange={(v) => patch((d) => void (d.provinceStep.question = v))}
        />
        <Grid>
          <TextField
            label="الرد عند اختيار محافظة"
            value={c.provinceStep.reactionOne}
            onChange={(v) => patch((d) => void (d.provinceStep.reactionOne = v))}
          />
          <TextField
            label="الرد عند «كل العراق»"
            value={c.provinceStep.reactionAll}
            onChange={(v) => patch((d) => void (d.provinceStep.reactionAll = v))}
          />
        </Grid>
        <TokenHint tokens={["{province}"]} />
        <TextField
          label="زر «أي مكان»"
          value={c.provinceStep.anyLabel}
          onChange={(v) => patch((d) => void (d.provinceStep.anyLabel = v))}
        />
        <Toggle
          label="إظهار عدد الأماكن بجانب كل محافظة"
          checked={c.provinceStep.showCounts}
          onChange={(v) => patch((d) => void (d.provinceStep.showCounts = v))}
        />
        <Toggle
          label="إخفاء المحافظات الخالية"
          hint="لا تظهر محافظة ليس فيها أماكن من النوع المختار"
          checked={c.provinceStep.hideEmpty}
          onChange={(v) => patch((d) => void (d.provinceStep.hideEmpty = v))}
        />
      </Section>

      <Section
        title="٤ · عدد الضيوف"
        muted={!c.guestsStep.enabled}
        action={<Switch label="مفعّل" checked={c.guestsStep.enabled} onChange={(v) => patch((d) => void (d.guestsStep.enabled = v))} />}
      >
        <Grid>
          <TextField label="السؤال" value={c.guestsStep.question} onChange={(v) => patch((d) => void (d.guestsStep.question = v))} />
          <TextField label="الرد" value={c.guestsStep.reaction} onChange={(v) => patch((d) => void (d.guestsStep.reaction = v))} />
        </Grid>
        <Grid cols={3}>
          <NumberField label="أقل عدد" value={c.guestsStep.min} min={1} onChange={(v) => patch((d) => void (d.guestsStep.min = v))} />
          <NumberField label="أكبر عدد" value={c.guestsStep.max} min={10} onChange={(v) => patch((d) => void (d.guestsStep.max = v))} />
          <NumberField
            label="القيمة الابتدائية"
            value={c.guestsStep.initial}
            onChange={(v) => patch((d) => void (d.guestsStep.initial = v))}
          />
        </Grid>
        <Grid>
          <TextField
            label="فقاعة إجابة الزبون"
            value={c.guestsStep.answer}
            onChange={(v) => patch((d) => void (d.guestsStep.answer = v))}
          />
          <TextField
            label="زر التأكيد"
            value={c.guestsStep.confirmLabel}
            onChange={(v) => patch((d) => void (d.guestsStep.confirmLabel = v))}
          />
        </Grid>
        <TokenHint tokens={["{n}"]} />
        <div>
          <div className="mb-2 flex items-center justify-between">
            <Label>أوصاف الحجم</Label>
            {c.guestsStep.scales.length < 10 && (
              <Button
                size="sm"
                variant="ghost"
                onClick={() => patch((d) => void d.guestsStep.scales.push({ upTo: 1000, label: "" }))}
              >
                + وصف
              </Button>
            )}
          </div>
          <div className="space-y-2">
            {c.guestsStep.scales.map((s, i) => (
              <div key={i} className="flex items-center gap-2">
                <span className="shrink-0 text-xs text-muted">حتى</span>
                <Input
                  type="number"
                  dir="ltr"
                  className="w-28"
                  value={s.upTo}
                  onChange={(e) => patch((d) => void (d.guestsStep.scales[i].upTo = Number(e.target.value)))}
                />
                <span className="shrink-0 text-xs text-muted">ضيف =</span>
                <Input
                  value={s.label}
                  maxLength={60}
                  onChange={(e) => patch((d) => void (d.guestsStep.scales[i].label = e.target.value))}
                />
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={c.guestsStep.scales.length <= 1}
                  onClick={() => patch((d) => void d.guestsStep.scales.splice(i, 1))}
                >
                  ✕
                </Button>
              </div>
            ))}
          </div>
        </div>
      </Section>

      <Section
        title="٥ · التوقيت"
        muted={!c.shiftStep.enabled}
        action={<Switch label="مفعّل" checked={c.shiftStep.enabled} onChange={(v) => patch((d) => void (d.shiftStep.enabled = v))} />}
      >
        <Grid>
          <TextField label="السؤال" value={c.shiftStep.question} onChange={(v) => patch((d) => void (d.shiftStep.question = v))} />
          <TextField label="الرد" value={c.shiftStep.reaction} onChange={(v) => patch((d) => void (d.shiftStep.reaction = v))} />
        </Grid>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {(
            [
              ["morning", "☀️ صباحي"],
              ["evening", "🌙 مسائي"],
              ["full", "🌗 يوم كامل"],
            ] as const
          ).map(([k, title]) => (
            <div key={k} className="space-y-2 rounded-xl border border-line p-3">
              <div className="flex items-center justify-between">
                <span className="text-sm font-bold text-ink">{title}</span>
                <Switch checked={c.shiftStep[k].enabled} onChange={(v) => patch((d) => void (d.shiftStep[k].enabled = v))} />
              </div>
              <Input
                value={c.shiftStep[k].title}
                maxLength={60}
                placeholder="العنوان"
                onChange={(e) => patch((d) => void (d.shiftStep[k].title = e.target.value))}
              />
              <Input
                value={c.shiftStep[k].sub}
                maxLength={80}
                placeholder="الوصف"
                onChange={(e) => patch((d) => void (d.shiftStep[k].sub = e.target.value))}
              />
            </div>
          ))}
        </div>
        <Toggle
          label="خيار «التوقيت مرن»"
          checked={c.shiftStep.flex.enabled}
          onChange={(v) => patch((d) => void (d.shiftStep.flex.enabled = v))}
        />
        {c.shiftStep.flex.enabled && (
          <Grid>
            <TextField label="نص الزر" value={c.shiftStep.flex.label} onChange={(v) => patch((d) => void (d.shiftStep.flex.label = v))} />
            <TextField
              label="فقاعة إجابة الزبون"
              value={c.shiftStep.flex.answer}
              onChange={(v) => patch((d) => void (d.shiftStep.flex.answer = v))}
            />
          </Grid>
        )}
      </Section>

      <Section
        title="٦ · الميزانية"
        muted={!c.budgetStep.enabled}
        action={<Switch label="مفعّل" checked={c.budgetStep.enabled} onChange={(v) => patch((d) => void (d.budgetStep.enabled = v))} />}
      >
        <TextField label="السؤال" value={c.budgetStep.question} onChange={(v) => patch((d) => void (d.budgetStep.question = v))} />
        <Grid>
          <TextField
            label="زر «مفتوحة»"
            value={c.budgetStep.openLabel}
            onChange={(v) => patch((d) => void (d.budgetStep.openLabel = v))}
          />
          <TextField
            label="فقاعة الميزانية المفتوحة"
            value={c.budgetStep.openAnswer}
            onChange={(v) => patch((d) => void (d.budgetStep.openAnswer = v))}
          />
          <TextField
            label="زر عرض النتائج"
            value={c.budgetStep.submitLabel}
            onChange={(v) => patch((d) => void (d.budgetStep.submitLabel = v))}
          />
          <TextField
            label="فقاعة إجابة الزبون"
            value={c.budgetStep.answer}
            onChange={(v) => patch((d) => void (d.budgetStep.answer = v))}
          />
        </Grid>
        <TokenHint tokens={["{amount}"]} />
        <NumberField
          label="موضع المؤشر الابتدائي"
          suffix="٪ من نطاق الأسعار"
          min={0}
          max={100}
          value={c.budgetStep.initialPercent}
          onChange={(v) => patch((d) => void (d.budgetStep.initialPercent = v))}
        />
      </Section>

      <Card className="text-sm text-muted">
        💡 الخطوة المعطّلة لا تُسأل، ونديم يتجاهلها في المطابقة. لو عطّلت كل الخطوات يعرض النتائج مباشرة بعد اختيار
        المناسبة.
      </Card>
    </>
  );
}

// ═══════════════════ الرسائل والنتائج ═══════════════════

function ResultsTab({ c, patch }: TabProps) {
  return (
    <>
      <Section title="أثناء البحث">
        <TextField label="رسالة قبل البحث" value={c.finish.intro} onChange={(v) => patch((d) => void (d.finish.intro = v))} />
        <TextField
          label="نص بطاقة التفكير"
          value={c.finish.thinking}
          onChange={(v) => patch((d) => void (d.finish.thinking = v))}
        />
        <Grid>
          <TextField label="رسالة الخطأ" multiline value={c.finish.error} onChange={(v) => patch((d) => void (d.finish.error = v))} />
          <TextField
            label="زر إعادة المحاولة"
            value={c.finish.retryLabel}
            onChange={(v) => patch((d) => void (d.finish.retryLabel = v))}
          />
        </Grid>
      </Section>

      <Section title="بطاقة الخطة" description="البطاقة الملوّنة أعلى النتائج">
        <Grid>
          <TextField label="العنوان" value={c.results.title} onChange={(v) => patch((d) => void (d.results.title = v))} />
          <TextField
            label="تلميح التعديل"
            value={c.results.editHint}
            onChange={(v) => patch((d) => void (d.results.editHint = v))}
          />
          <TextField
            label="شارة «نديم يختار»"
            value={c.results.autoTypeChip}
            onChange={(v) => patch((d) => void (d.results.autoTypeChip = v))}
          />
        </Grid>
        <TokenHint tokens={["{occasion}"]} />
      </Section>

      <Section title="رسائل النتائج">
        <TextField
          label="عند وجود تطابق كامل"
          value={c.results.precise}
          onChange={(v) => patch((d) => void (d.results.precise = v))}
        />
        <TextField
          label="عند تطابق جزئي"
          value={c.results.approximate}
          onChange={(v) => patch((d) => void (d.results.approximate = v))}
        />
        <TextField label="عند عدم وجود نتائج" value={c.results.empty} onChange={(v) => patch((d) => void (d.results.empty = v))} />
        <TextField
          label="مقدمة اقتراحات التزيين"
          value={c.results.decorIntro}
          onChange={(v) => patch((d) => void (d.results.decorIntro = v))}
        />
        <Grid>
          <TextField
            label="زر «من جديد»"
            value={c.results.restartLabel}
            onChange={(v) => patch((d) => void (d.results.restartLabel = v))}
          />
          <TextField
            label="زر «كل النتائج»"
            value={c.results.allResultsLabel}
            onChange={(v) => patch((d) => void (d.results.allResultsLabel = v))}
          />
        </Grid>
      </Section>

      <Section title="بطاقات الأماكن">
        <Toggle
          label="إظهار نسبة التطابق"
          hint="الحلقة الملونة بنسبة مئوية على كل بطاقة"
          checked={c.results.showMatchPercent}
          onChange={(v) => patch((d) => void (d.results.showMatchPercent = v))}
        />
        <Toggle
          label="إظهار أسباب الاختيار"
          hint="مثل: في بغداد · ضمن ميزانيتك · تقييم 4.8"
          checked={c.results.showReasons}
          onChange={(v) => patch((d) => void (d.results.showReasons = v))}
        />
      </Section>
    </>
  );
}

// ═══════════════════ المطابقة والأماكن ═══════════════════

const WEIGHTS: { key: keyof NadeemConfig["matching"]; label: string; hint: string }[] = [
  { key: "type", label: "نفس النوع", hint: "مزرعة/قاعة كما طلب" },
  { key: "typeMiss", label: "نوع مختلف", hint: "عادة سالب" },
  { key: "province", label: "نفس المحافظة", hint: "" },
  { key: "provinceMiss", label: "محافظة أخرى", hint: "عادة سالب" },
  { key: "capacity", label: "يتسع للضيوف", hint: "" },
  { key: "capacityMiss", label: "لا يتسع", hint: "عادة سالب" },
  { key: "budget", label: "ضمن الميزانية", hint: "" },
  { key: "budgetMiss", label: "فوق الميزانية", hint: "عادة سالب" },
  { key: "shiftPrice", label: "سعر للفترة المطلوبة", hint: "صباحي/مسائي" },
  { key: "shiftSupport", label: "يدعم الفترات", hint: "" },
  { key: "fullDay", label: "يوم كامل", hint: "للأماكن بنظام اليوم الكامل" },
  { key: "flex", label: "توقيت مرن", hint: "" },
  { key: "featured", label: "مكان مختار (مميز)", hint: "" },
  { key: "winter", label: "مزرعة شتوية", hint: "مفيد في موسم الشتاء" },
];

function MatchingTab({
  c,
  patch,
  places,
  defaults,
}: TabProps & { places: Property[]; defaults: NadeemConfig }) {
  const [pickPin, setPickPin] = useState("");
  const [pickEx, setPickEx] = useState("");
  const name = (id: string) => places.find((p) => p.id === id)?.name ?? "مكان غير معروف";

  return (
    <>
      <Section
        title="أوزان المطابقة"
        description="نقاط تُضاف أو تُطرح لكل مكان حسب إجابات الزبون — الأعلى نقاطاً يظهر أولاً"
        action={
          <Button size="sm" variant="ghost" onClick={() => patch((d) => void (d.matching = structuredClone(defaults.matching)))}>
            الأوزان الأصلية
          </Button>
        }
      >
        <div className="grid grid-cols-1 gap-x-4 gap-y-3 sm:grid-cols-2 lg:grid-cols-3">
          {WEIGHTS.map((w) => (
            <NumberField
              key={w.key}
              label={w.label}
              hint={`${w.hint ? `${w.hint} · ` : ""}الأصلي ${defaults.matching[w.key]}`}
              value={c.matching[w.key]}
              onChange={(v) => patch((d) => void (d.matching[w.key] = v))}
            />
          ))}
          <NumberField
            label="مضاعف التقييم"
            hint={`التقييم × هذا الرقم · الأصلي ${defaults.matching.ratingMultiplier}`}
            min={0}
            max={50}
            value={c.matching.ratingMultiplier}
            onChange={(v) => patch((d) => void (d.matching.ratingMultiplier = v))}
          />
        </div>
      </Section>

      <Section title="النتائج">
        <Grid cols={3}>
          <NumberField
            label="أقصى عدد نتائج"
            min={1}
            max={30}
            value={c.matching.maxResults}
            onChange={(v) => patch((d) => void (d.matching.maxResults = v))}
          />
          <NumberField
            label="أدنى نقاط للنتيجة القوية"
            hint="إن لم يصلها أي مكان تُعرض الأقرب"
            value={c.matching.minScore}
            onChange={(v) => patch((d) => void (d.matching.minScore = v))}
          />
          <NumberField
            label="عدد اقتراحات التزيين"
            min={0}
            max={20}
            value={c.matching.decorCount}
            onChange={(v) => patch((d) => void (d.matching.decorCount = v))}
          />
          <NumberField
            label="أدنى نسبة تطابق معروضة"
            suffix="٪"
            min={0}
            max={99}
            value={c.matching.minPercent}
            onChange={(v) => patch((d) => void (d.matching.minPercent = v))}
          />
          <NumberField
            label="أعلى نسبة تطابق معروضة"
            suffix="٪"
            min={1}
            max={100}
            value={c.matching.maxPercent}
            onChange={(v) => patch((d) => void (d.matching.maxPercent = v))}
          />
        </Grid>
      </Section>

      <Section title="أماكن مثبّتة" description="أماكن تحصل على نقاط إضافية فتظهر أعلى في نتائج نديم (إن كانت مناسبة للطلب)">
        <div className="flex gap-2">
          <Select value={pickPin} onChange={(e) => setPickPin(e.target.value)}>
            <option value="">اختر مكاناً…</option>
            {places
              .filter((p) => !c.pinned.some((x) => x.propertyId === p.id))
              .map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name} · {WORLD_LABEL[p.type] ?? p.type}
                </option>
              ))}
          </Select>
          <Button
            disabled={!pickPin}
            onClick={() => {
              patch((d) => void d.pinned.push({ propertyId: pickPin, bonus: 30 }));
              setPickPin("");
            }}
          >
            تثبيت
          </Button>
        </div>
        {c.pinned.length === 0 ? (
          <p className="text-sm text-muted">لا أماكن مثبّتة</p>
        ) : (
          <div className="space-y-2">
            {c.pinned.map((p, i) => (
              <div key={p.propertyId} className="flex items-center gap-3 rounded-xl border border-line p-2.5">
                <span className="min-w-0 flex-1 truncate font-semibold text-ink">📌 {name(p.propertyId)}</span>
                <span className="text-xs text-muted">نقاط إضافية</span>
                <Input
                  type="number"
                  dir="ltr"
                  className="w-24"
                  value={p.bonus}
                  onChange={(e) => patch((d) => void (d.pinned[i].bonus = Number(e.target.value)))}
                />
                <Button size="sm" variant="ghost" onClick={() => patch((d) => void d.pinned.splice(i, 1))}>
                  ✕
                </Button>
              </div>
            ))}
          </div>
        )}
      </Section>

      <Section title="أماكن مستبعدة" description="لا يقترحها نديم أبداً (تبقى ظاهرة في البحث العادي)">
        <div className="flex gap-2">
          <Select value={pickEx} onChange={(e) => setPickEx(e.target.value)}>
            <option value="">اختر مكاناً…</option>
            {places
              .filter((p) => !c.excluded.includes(p.id))
              .map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name} · {WORLD_LABEL[p.type] ?? p.type}
                </option>
              ))}
          </Select>
          <Button
            variant="danger"
            disabled={!pickEx}
            onClick={() => {
              patch((d) => void d.excluded.push(pickEx));
              setPickEx("");
            }}
          >
            استبعاد
          </Button>
        </div>
        {c.excluded.length === 0 ? (
          <p className="text-sm text-muted">لا أماكن مستبعدة</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {c.excluded.map((id, i) => (
              <span key={id} className="inline-flex items-center gap-1.5 rounded-full bg-red-50 px-3 py-1 text-sm font-semibold text-red-700">
                {name(id)}
                <button type="button" onClick={() => patch((d) => void d.excluded.splice(i, 1))} aria-label="إزالة">
                  ✕
                </button>
              </span>
            ))}
          </div>
        )}
      </Section>
    </>
  );
}
