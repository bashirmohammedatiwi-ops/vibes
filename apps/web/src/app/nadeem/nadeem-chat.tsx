"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { RotateCcw, Sparkles } from "lucide-react";
import { api } from "@/lib/api";
import type { Paged, PropertyCard as P, PropertyType, Province } from "@/lib/types";
import { fromPrice, moneyShort, num, TYPE_LABEL } from "@/lib/format";
import { PropertyCard } from "@/components/property-card";

/* ── إعدادات نديم (من لوحة التحكم) ── */
type Occasion = {
  key: string;
  enabled: boolean;
  label: string;
  sub: string;
  icon: string;
  world: PropertyType;
  impliedType: PropertyType | null;
  suggestDecor: boolean;
  reaction: string;
};
type Slot = { enabled: boolean; title: string; sub: string };
export type NadeemConfig = {
  enabled: boolean;
  name: string;
  subtitle: string;
  disabledTitle: string;
  disabledMessage: string;
  greeting: string[];
  typingDelayMs: number;
  occasionStep: { question: string };
  typeStep: { enabled: boolean; question: string; reaction: string; reactionAuto: string; allowAuto: boolean; autoLabel: string; autoAnswer: string; types: { key: PropertyType; enabled: boolean; label: string }[] };
  provinceStep: { enabled: boolean; question: string; reactionAll: string; reactionOne: string; anyLabel: string };
  guestsStep: { enabled: boolean; question: string; reaction: string; min: number; max: number; initial: number; answer: string; confirmLabel: string; scales: { upTo: number; label: string }[] };
  shiftStep: { enabled: boolean; question: string; reaction: string; morning: Slot; evening: Slot; full: Slot; flex: { enabled: boolean; label: string; answer: string } };
  budgetStep: { enabled: boolean; question: string; openLabel: string; openAnswer: string; submitLabel: string; answer: string; initialPercent: number };
  finish: { intro: string; thinking: string; error: string; retryLabel: string };
  results: { title: string; precise: string; approximate: string; empty: string; decorIntro: string; restartLabel: string; allResultsLabel: string; showReasons: boolean; showMatchPercent: boolean };
  occasions: Occasion[];
  matching: Record<string, number>;
  pinned: { propertyId: string; bonus: number }[];
  excluded: string[];
};

const ICON: Record<string, string> = {
  diamond: "💍", heart: "💞", cake: "🎂", family: "👨‍👩‍👧", work: "💼", sparkle: "✨", party: "🎉", graduation: "🎓",
  baby: "👶", music: "🎵", star: "⭐", gift: "🎁", moon: "🌙", sun: "☀️", pool: "🏊", food: "🍽️",
};

type Shift = "MORNING" | "EVENING" | "FULL" | "FLEX";
type Step = "occasion" | "type" | "province" | "guests" | "shift" | "budget";
type Answers = {
  occasion?: Occasion;
  type?: PropertyType | null;
  auto?: boolean;
  province?: Province | null;
  guests?: number;
  shift?: Shift;
  budget?: number | null;
};
type Msg = { who: "nadeem" | "me"; text: string };
type Scored = { p: P; score: number; reasons: string[]; precise: boolean };

const fill = (t: string, v: Record<string, string>) => Object.entries(v).reduce((s, [k, x]) => s.replaceAll(`{${k}}`, x), t);

export function NadeemChat({ config: c, provinces }: { config: NadeemConfig; provinces: Province[] }) {
  const flow = useMemo<Step[]>(
    () => [
      "occasion",
      ...(c.typeStep.enabled ? (["type"] as const) : []),
      ...(c.provinceStep.enabled ? (["province"] as const) : []),
      ...(c.guestsStep.enabled ? (["guests"] as const) : []),
      ...(c.shiftStep.enabled ? (["shift"] as const) : []),
      ...(c.budgetStep.enabled ? (["budget"] as const) : []),
    ],
    [c],
  );
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [typing, setTyping] = useState(false);
  const [step, setStep] = useState<Step | null>(null);
  const [answers, setAnswers] = useState<Answers>({});
  const [results, setResults] = useState<Scored[] | null>(null);
  const [decor, setDecor] = useState<P[]>([]);
  const [all, setAll] = useState<P[]>([]);
  const [thinking, setThinking] = useState(false);
  const [error, setError] = useState(false);
  const session = useRef(0);
  const bottom = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api<Paged<P>>("/api/properties?page=1&pageSize=100", { auth: false }).then((r) => setAll(r.items)).catch(() => undefined);
  }, []);

  const wait = (ms: number) => new Promise((r) => setTimeout(r, (ms * c.typingDelayMs) / 650));

  async function say(text: string, s: number, ms = 650) {
    if (!text || s !== session.current) return;
    setTyping(true);
    await wait(ms);
    if (s !== session.current) return;
    setTyping(false);
    setMsgs((m) => [...m, { who: "nadeem", text }]);
  }

  const question = (st: Step) =>
    ({
      occasion: c.occasionStep.question,
      type: c.typeStep.question,
      province: c.provinceStep.question,
      guests: c.guestsStep.question,
      shift: c.shiftStep.question,
      budget: c.budgetStep.question,
    })[st];

  async function start() {
    const s = ++session.current;
    setMsgs([]);
    setAnswers({});
    setResults(null);
    setDecor([]);
    setError(false);
    setStep(null);
    for (let i = 0; i < c.greeting.length; i++) await say(c.greeting[i], s, i ? 900 : 500);
    await say(question("occasion"), s);
    if (s === session.current) setStep("occasion");
  }

  useEffect(() => {
    if (c.enabled) start();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [msgs.length, typing, step, results, thinking]);

  async function answer(st: Step, label: string, patch: Answers, reaction: string) {
    const s = session.current;
    const next = { ...answers, ...patch };
    setAnswers(next);
    setStep(null);
    setMsgs((m) => [...m, { who: "me", text: label }]);
    if (reaction) await say(reaction, s, 520);
    const i = flow.indexOf(st);
    if (i < flow.length - 1) {
      await say(question(flow[i + 1]), s);
      if (s === session.current) setStep(flow[i + 1]);
    } else {
      await finish(next, s);
    }
  }

  const implied = (a: Answers): PropertyType | null => (a.type ? a.type : a.auto || !c.typeStep.enabled ? a.occasion?.impliedType ?? null : null);

  async function finish(a: Answers, s: number) {
    await say(c.finish.intro, s, 500);
    setThinking(true);
    setError(false);
    try {
      const type = implied(a);
      const qs = new URLSearchParams({ page: "1", pageSize: "100", sort: "rating" });
      if (type) qs.set("type", type);
      const [pool] = await Promise.all([
        api<Paged<P>>(`/api/properties?${qs}`, { auth: false }).then((r) => r.items),
        new Promise((r) => setTimeout(r, 1200)),
      ]);
      const m = c.matching;
      const excluded = new Set(c.excluded);
      const pins = new Map(c.pinned.map((x) => [x.propertyId, x.bonus]));
      const scored = pool
        .filter((p) => !excluded.has(p.id))
        .map((p): Scored => {
          let sc = 0;
          const reasons: string[] = [];
          if (type) sc += p.type === type ? m.type : m.typeMiss;
          const prov = a.province?.nameAr;
          if (prov) {
            const ok = p.city?.province?.nameAr === prov;
            sc += ok ? m.province : m.provinceMiss;
            if (ok) reasons.push(`في ${prov}`);
          }
          if (a.guests) {
            const ok = p.capacity >= a.guests;
            sc += ok ? m.capacity : m.capacityMiss;
            if (ok) reasons.push(`يتسع لـ ${p.capacity}`);
          }
          if (a.budget) {
            const ok = fromPrice(p) <= a.budget;
            sc += ok ? m.budget : m.budgetMiss;
            if (ok) reasons.push("ضمن ميزانيتك");
          }
          if (a.shift === "MORNING" || a.shift === "EVENING") {
            if (num(a.shift === "MORNING" ? p.priceMorningShift : p.priceEveningShift) > 0) sc += m.shiftPrice;
            if (p.bookingMode !== "FULL_DAY") sc += m.shiftSupport;
          } else if (a.shift === "FULL") {
            if (p.bookingMode === "FULL_DAY") sc += m.fullDay;
          } else if (a.shift === "FLEX") sc += m.flex;
          sc += Math.round(num(p.ratingAvg) * m.ratingMultiplier);
          if (p.featured) {
            sc += m.featured;
            reasons.push("مختار");
          }
          if (p.isWinter) sc += m.winter ?? 0;
          sc += pins.get(p.id) ?? 0;
          if (p.ratingCount > 0 && num(p.ratingAvg) >= 4.5) reasons.unshift(`تقييم ${num(p.ratingAvg).toFixed(1)}`);
          const precise =
            (!a.type || p.type === a.type) &&
            (!a.province || p.city?.province?.nameAr === a.province.nameAr) &&
            (!a.guests || p.capacity >= a.guests);
          return { p, score: sc, reasons: reasons.slice(0, 3), precise };
        })
        .sort((x, y) => y.score - x.score);
      const strong = scored.filter((x) => x.score >= m.minScore);
      const top = (strong.length ? strong : scored).slice(0, m.maxResults);
      let dec: P[] = [];
      if (a.occasion?.suggestDecor && m.decorCount > 0 && type !== "DECORATION") {
        const dq = new URLSearchParams({ page: "1", pageSize: "20", type: "DECORATION", sort: "rating" });
        if (a.province) dq.set("province", a.province.slug);
        dec = (await api<Paged<P>>(`/api/properties?${dq}`, { auth: false }).catch(() => ({ items: [] as P[] }))).items
          .filter((p) => !excluded.has(p.id))
          .slice(0, m.decorCount);
      }
      if (s !== session.current) return;
      setResults(top);
      setDecor(dec);
      api("/api/nadeem/sessions", {
        method: "POST",
        body: {
          occasion: a.occasion?.key,
          propertyType: a.type ?? null,
          autoType: !a.type,
          province: a.province?.nameAr ?? null,
          guests: a.guests ?? null,
          shift: a.shift ? { MORNING: "morning", EVENING: "evening", FULL: "full", FLEX: "flex" }[a.shift] : null,
          maxBudget: a.budget ?? null,
          budgetOpen: a.budget === null,
          resultIds: top.map((x) => x.p.id),
          precise: !!top[0]?.precise,
          platform: "web",
        },
      }).catch(() => undefined);
    } catch {
      setError(true);
    } finally {
      setThinking(false);
    }
  }

  const percent = (score: number) => {
    const lo = c.matching.minPercent, hi = c.matching.maxPercent;
    return Math.round(Math.min(hi, Math.max(lo, lo + ((Math.min(110, Math.max(-20, score)) + 20) / 130) * (hi - lo))));
  };

  if (!c.enabled)
    return (
      <div className="card mx-auto max-w-lg p-10 text-center">
        <div className="text-4xl">💤</div>
        <h1 className="mt-3 text-xl font-black">{c.disabledTitle}</h1>
        <p className="mt-2 text-sm text-ink-2">{c.disabledMessage}</p>
        <Link href="/search" className="btn btn-primary mt-6 h-11 px-6">
          ابحث عن مكان
        </Link>
      </div>
    );

  const typeCounts = (t: PropertyType) => all.filter((p) => p.type === t).length;

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-4 flex items-center gap-3">
        <span className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-brass-light to-brass-deep">
          <Sparkles className="h-6 w-6 text-midnight" />
        </span>
        <div className="flex-1">
          <h1 className="text-xl font-black">{c.name}</h1>
          <p className="text-xs font-semibold text-ink-3">{typing || thinking ? "يكتب…" : c.subtitle}</p>
        </div>
        <button onClick={start} className="flex items-center gap-1 rounded-full border border-line px-3 py-1.5 text-xs font-bold hover:bg-cream">
          <RotateCcw className="h-3.5 w-3.5" /> من جديد
        </button>
      </div>

      <div className="space-y-2.5 rounded-[2rem] bg-cream p-4 md:p-6">
        {msgs.map((m, i) => (
          <div key={i} className={`flex ${m.who === "me" ? "justify-end" : "justify-start"} animate-fade-up`}>
            <div
              className={`max-w-[80%] px-4 py-2.5 text-[15px] leading-7 ${
                m.who === "me"
                  ? "rounded-3xl rounded-bl-md bg-midnight font-bold text-white"
                  : "rounded-3xl rounded-br-md border border-line bg-white font-semibold"
              }`}
            >
              {m.text}
            </div>
          </div>
        ))}
        {typing && (
          <div className="flex">
            <div className="flex gap-1 rounded-3xl rounded-br-md border border-line bg-white px-4 py-3.5">
              {[0, 1, 2].map((i) => (
                <span key={i} className="h-2 w-2 animate-bounce rounded-full bg-brass" style={{ animationDelay: `${i * 0.15}s` }} />
              ))}
            </div>
          </div>
        )}
        {thinking && <div className="py-6 text-center text-sm font-bold text-brass-deep">{c.finish.thinking}</div>}
        {error && (
          <div className="rounded-2xl bg-danger-pale p-4 text-sm text-danger">
            {c.finish.error}
            <button onClick={() => finish(answers, session.current)} className="mr-2 font-black underline">
              {c.finish.retryLabel}
            </button>
          </div>
        )}

        {/* أدوات الإجابة */}
        {step === "occasion" && (
          <div className="grid grid-cols-2 gap-2 pt-2 sm:grid-cols-3">
            {c.occasions
              .filter((o) => o.enabled)
              .map((o) => (
                <button
                  key={o.key}
                  data-world={o.world}
                  onClick={() => answer("occasion", o.label, { occasion: o }, o.reaction)}
                  className="rounded-2xl border border-line bg-white p-3 text-center transition hover:-translate-y-0.5 hover:border-[var(--w-accent)]"
                >
                  <div className="text-2xl">{ICON[o.icon] ?? "✨"}</div>
                  <div className="mt-1 font-black">{o.label}</div>
                  <div className="text-[11px] text-ink-3">{o.sub}</div>
                </button>
              ))}
          </div>
        )}
        {step === "type" && (
          <div className="space-y-2 pt-2">
            <div className="grid grid-cols-3 gap-2">
              {c.typeStep.types
                .filter((t) => t.enabled)
                .map((t) => (
                  <button
                    key={t.key}
                    data-world={t.key}
                    onClick={() => answer("type", t.label, { type: t.key, auto: false }, c.typeStep.reaction)}
                    className="rounded-2xl border border-line bg-[var(--w-tint)] p-4 text-center font-black transition hover:border-[var(--w-accent)]"
                  >
                    {t.label}
                    <div className="num text-[11px] font-semibold text-ink-3">{typeCounts(t.key)} مكان</div>
                  </button>
                ))}
            </div>
            {c.typeStep.allowAuto && (
              <button
                onClick={() => answer("type", c.typeStep.autoAnswer, { type: null, auto: true }, c.typeStep.reactionAuto)}
                className="w-full rounded-2xl bg-brass-pale py-3 text-sm font-black text-brass-deep"
              >
                ✨ {c.typeStep.autoLabel}
              </button>
            )}
          </div>
        )}
        {step === "province" && (
          <div className="space-y-2 pt-2">
            <div className="flex flex-wrap gap-2">
              {provinces.map((p) => (
                <button
                  key={p.id}
                  onClick={() => answer("province", p.nameAr, { province: p }, fill(c.provinceStep.reactionOne, { province: p.nameAr }))}
                  className="chip"
                >
                  📍 {p.nameAr}
                </button>
              ))}
            </div>
            <button
              onClick={() => answer("province", c.provinceStep.anyLabel, { province: null }, c.provinceStep.reactionAll)}
              className="w-full rounded-2xl bg-brass-pale py-3 text-sm font-black text-brass-deep"
            >
              🌍 {c.provinceStep.anyLabel}
            </button>
          </div>
        )}
        {step === "guests" && <GuestsPicker c={c} onDone={(n) => answer("guests", fill(c.guestsStep.answer, { n: String(n) }), { guests: n }, c.guestsStep.reaction)} />}
        {step === "shift" && (
          <div className="space-y-2 pt-2">
            <div className="grid grid-cols-3 gap-2">
              {(
                [
                  ["MORNING", c.shiftStep.morning, "from-amber-100 to-amber-300 text-ink"],
                  ["EVENING", c.shiftStep.evening, "from-[#3b4a7a] to-[#151b33] text-white"],
                  ["FULL", c.shiftStep.full, "from-amber-200 via-violet-500 to-[#151b33] text-white"],
                ] as const
              )
                .filter(([, s]) => s.enabled)
                .map(([k, s, g]) => (
                  <button key={k} onClick={() => answer("shift", s.title, { shift: k }, c.shiftStep.reaction)} className={`rounded-2xl bg-gradient-to-b ${g} p-4 text-right`}>
                    <div className="font-black">{s.title}</div>
                    <div className="text-[11px] opacity-80">{s.sub}</div>
                  </button>
                ))}
            </div>
            {c.shiftStep.flex.enabled && (
              <button
                onClick={() => answer("shift", c.shiftStep.flex.answer, { shift: "FLEX" }, c.shiftStep.reaction)}
                className="w-full rounded-2xl bg-brass-pale py-3 text-sm font-black text-brass-deep"
              >
                🕒 {c.shiftStep.flex.label}
              </button>
            )}
          </div>
        )}
        {step === "budget" && (
          <BudgetPicker
            c={c}
            prices={all.filter((p) => !implied(answers) || p.type === implied(answers)).map(fromPrice).filter((v) => v > 0)}
            onDone={(v) =>
              answer("budget", v === null ? c.budgetStep.openAnswer : fill(c.budgetStep.answer, { amount: moneyShort(v) }), { budget: v }, "")
            }
          />
        )}

        {results && (
          <div className="space-y-4 pt-2">
            <div className="rounded-3xl bg-gradient-to-br from-sapphire-light to-midnight p-5 text-white">
              <div className="text-lg font-black">{fill(c.results.title, { occasion: answers.occasion?.label ?? "مناسبتك" })}</div>
              <div className="mt-2 flex flex-wrap gap-1.5 text-xs font-bold">
                {answers.occasion && <Chip>{answers.occasion.label}</Chip>}
                <Chip>{answers.type ? TYPE_LABEL[answers.type] : "نديم يختار"}</Chip>
                {c.provinceStep.enabled && <Chip>{answers.province?.nameAr ?? "كل العراق"}</Chip>}
                {answers.guests && <Chip>{answers.guests} ضيف</Chip>}
                {c.budgetStep.enabled && <Chip>{answers.budget ? `حتى ${moneyShort(answers.budget)}` : c.budgetStep.openLabel}</Chip>}
              </div>
            </div>
            <div className="w-fit max-w-[85%] rounded-3xl rounded-br-md border border-line bg-white px-4 py-2.5 font-semibold">
              {results.length === 0 ? c.results.empty : results[0].precise ? c.results.precise : c.results.approximate}
            </div>
            <div className="grid gap-5 sm:grid-cols-2">
              {results.map((r, i) => (
                <div key={r.p.id} className="relative rounded-3xl bg-white p-3">
                  {c.results.showMatchPercent && (
                    <span className="num absolute left-5 top-5 z-10 rounded-full bg-midnight px-2.5 py-1 text-xs font-black text-brass-light">
                      {percent(r.score)}٪ {i === 0 ? "· الأفضل" : ""}
                    </span>
                  )}
                  <PropertyCard p={r.p} />
                  {c.results.showReasons && r.reasons.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1 px-1">
                      {r.reasons.map((x) => (
                        <span key={x} className="rounded-full bg-success-pale px-2 py-0.5 text-[11px] font-bold text-success">
                          ✓ {x}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
            {decor.length > 0 && (
              <>
                <div className="w-fit max-w-[85%] rounded-3xl rounded-br-md border border-line bg-white px-4 py-2.5 font-semibold">{c.results.decorIntro}</div>
                <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
                  {decor.map((p) => (
                    <PropertyCard key={p.id} p={p} />
                  ))}
                </div>
              </>
            )}
            <div className="flex gap-2">
              <button onClick={start} className="btn btn-ghost h-12 flex-1">
                {c.results.restartLabel}
              </button>
              <Link
                href={`/search?${new URLSearchParams({
                  ...(implied(answers) ? { type: implied(answers)! } : {}),
                  ...(answers.province ? { province: answers.province.slug } : {}),
                  ...(answers.guests ? { guests: String(answers.guests) } : {}),
                })}`}
                className="btn btn-primary h-12 flex-1"
              >
                {c.results.allResultsLabel}
              </Link>
            </div>
          </div>
        )}
        <div ref={bottom} />
      </div>
    </div>
  );
}

function Chip({ children }: { children: React.ReactNode }) {
  return <span className="rounded-full border border-white/25 bg-white/15 px-2.5 py-1">{children}</span>;
}

function GuestsPicker({ c, onDone }: { c: NadeemConfig; onDone: (n: number) => void }) {
  const { min, max } = c.guestsStep;
  const [n, setN] = useState(Math.min(max, Math.max(min, c.guestsStep.initial)));
  const scale = c.guestsStep.scales.find((s) => n <= s.upTo)?.label ?? c.guestsStep.scales.at(-1)?.label ?? "";
  return (
    <div className="rounded-3xl bg-white p-5 text-center">
      <div className="num text-5xl font-extrabold">{n}</div>
      <div className="text-sm font-bold text-brass-deep">ضيف · {scale}</div>
      <input
        type="range"
        min={min}
        max={max}
        step={n < 100 ? 5 : n < 300 ? 10 : 50}
        value={n}
        onChange={(e) => setN(Number(e.target.value))}
        className="mt-4 w-full accent-[#c89844]"
        dir="ltr"
      />
      <button onClick={() => onDone(n)} className="btn btn-primary mt-4 h-12 w-full">
        {fill(c.guestsStep.confirmLabel, { n: String(n) })}
      </button>
    </div>
  );
}

function BudgetPicker({ c, prices, onDone }: { c: NadeemConfig; prices: number[]; onDone: (v: number | null) => void }) {
  const sorted = prices.length ? [...prices].sort((a, b) => a - b) : [50000, 2000000];
  const lo = Math.floor((sorted[0] * 0.8) / 10000) * 10000;
  const hi = Math.ceil((sorted.at(-1)! * 1.05) / 10000) * 10000;
  const [t, setT] = useState(c.budgetStep.initialPercent / 100);
  const value = Math.round((lo + (hi - lo) * t) / 10000) * 10000;
  const within = sorted.filter((v) => v <= value).length;
  return (
    <div className="rounded-3xl bg-white p-5">
      <div className="flex items-end justify-between">
        <div>
          <span className="text-sm font-bold text-ink-2">حتى </span>
          <span className="num text-3xl font-extrabold">{moneyShort(value)}</span>
          <span className="text-sm font-bold text-ink-3"> د.ع</span>
        </div>
        <span className="rounded-full bg-brass-pale px-3 py-1 text-xs font-black text-brass-deep">{within} مكان ضمنها</span>
      </div>
      <input type="range" min={0} max={1} step={0.01} value={t} onChange={(e) => setT(Number(e.target.value))} className="mt-4 w-full accent-[#c89844]" dir="ltr" />
      <div className="mt-4 flex gap-2">
        <button onClick={() => onDone(null)} className="btn btn-ghost h-12 flex-1">
          {c.budgetStep.openLabel}
        </button>
        <button onClick={() => onDone(value)} className="btn btn-gold h-12 flex-[2]">
          {c.budgetStep.submitLabel}
        </button>
      </div>
    </div>
  );
}
