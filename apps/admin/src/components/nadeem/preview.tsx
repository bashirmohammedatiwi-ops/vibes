"use client";

import { useState } from "react";
import { ICON_EMOJI, WORLD_COLOR, type NadeemConfig } from "./types";

type Step = "occasion" | "type" | "province" | "guests" | "shift" | "budget" | "results" | "off";

const STEPS: { id: Step; label: string }[] = [
  { id: "occasion", label: "البداية" },
  { id: "type", label: "النوع" },
  { id: "province", label: "المحافظة" },
  { id: "guests", label: "الضيوف" },
  { id: "shift", label: "التوقيت" },
  { id: "budget", label: "الميزانية" },
  { id: "results", label: "النتائج" },
  { id: "off", label: "متوقف" },
];

function Bubble({ text, mine }: { text: string; mine?: boolean }) {
  if (!text.trim()) return null;
  return (
    <div className={`flex ${mine ? "justify-start" : "justify-end"} mb-1.5`} dir="ltr">
      <div
        dir="rtl"
        className={`max-w-[78%] px-3 py-2 text-[12.5px] leading-5 ${
          mine
            ? "rounded-2xl rounded-bl-md bg-gradient-to-br from-violet-500 to-violet-700 font-bold text-white"
            : "rounded-2xl rounded-br-md border border-gray-100 bg-white font-semibold text-gray-800"
        }`}
      >
        {text}
      </div>
    </div>
  );
}

export function NadeemPreview({ config: c }: { config: NadeemConfig }) {
  const [step, setStep] = useState<Step>("occasion");
  const first = c.occasions.find((o) => o.enabled) ?? c.occasions[0];
  const show = c.enabled ? step : "off";

  const picker = () => {
    switch (show) {
      case "occasion":
        return (
          <div className="grid grid-cols-3 gap-1.5">
            {c.occasions
              .filter((o) => o.enabled)
              .map((o) => (
                <div
                  key={o.key}
                  className="flex flex-col items-center rounded-xl py-2"
                  style={{ background: WORLD_COLOR[o.world].bg }}
                >
                  <span className="text-lg">{ICON_EMOJI[o.icon] ?? "✨"}</span>
                  <span className="text-[11px] font-black text-gray-900">{o.label}</span>
                  <span className="text-[9px] font-bold text-gray-500">{o.sub}</span>
                </div>
              ))}
          </div>
        );
      case "type":
        return (
          <div className="space-y-1.5">
            <div className="flex gap-1.5">
              {c.typeStep.types
                .filter((t) => t.enabled)
                .map((t) => (
                  <div
                    key={t.key}
                    className="flex-1 rounded-xl py-3 text-center text-[12px] font-black"
                    style={{ background: WORLD_COLOR[t.key].bg, color: WORLD_COLOR[t.key].fg }}
                  >
                    {t.label}
                    {c.typeStep.showCounts && <div className="text-[9px] font-bold text-gray-500">12 مكان</div>}
                  </div>
                ))}
            </div>
            {c.typeStep.allowAuto && (
              <div className="rounded-xl bg-violet-50 py-2 text-center text-[11px] font-bold text-violet-700">
                ✨ {c.typeStep.autoLabel}
              </div>
            )}
          </div>
        );
      case "province":
        return (
          <div className="space-y-1.5">
            <div className="flex flex-wrap gap-1">
              {["بغداد", "البصرة", "أربيل", "النجف"].map((p, i) => (
                <span key={p} className="rounded-lg bg-gray-100 px-2 py-1 text-[11px] font-bold text-gray-800">
                  📍 {p}
                  {c.provinceStep.showCounts && <span className="mr-1 text-violet-600">{9 - i * 2}</span>}
                </span>
              ))}
            </div>
            <div className="rounded-xl bg-violet-50 py-2 text-center text-[11px] font-bold text-violet-700">
              🌍 {c.provinceStep.anyLabel}
            </div>
          </div>
        );
      case "guests": {
        const n = c.guestsStep.initial;
        const scale = c.guestsStep.scales.find((s) => n <= s.upTo)?.label ?? "";
        return (
          <div className="text-center">
            <div className="font-mono text-3xl font-extrabold text-gray-900">{n}</div>
            <div className="text-[11px] font-bold text-violet-700">ضيف · {scale}</div>
            <div className="my-2 h-1.5 rounded-full bg-violet-200">
              <div className="h-full w-1/3 rounded-full bg-violet-600" />
            </div>
            <div className="text-[9px] text-gray-400" dir="ltr">
              {c.guestsStep.min} — {c.guestsStep.max}
            </div>
            <div className="mt-1 rounded-xl bg-violet-600 py-2 text-[11px] font-bold text-white">
              {c.guestsStep.confirmLabel.replace("{n}", String(n))}
            </div>
          </div>
        );
      }
      case "shift": {
        const slots = (["morning", "evening", "full"] as const).filter((k) => c.shiftStep[k].enabled);
        const bg = { morning: "#FFE7A8", evening: "#2A3560", full: "#7C6BC4" };
        return (
          <div className="space-y-1.5">
            <div className="flex gap-1.5">
              {slots.map((k) => (
                <div
                  key={k}
                  className="flex-1 rounded-xl p-2"
                  style={{ background: bg[k], color: k === "morning" ? "#111" : "#fff" }}
                >
                  <div className="text-[12px] font-black">{c.shiftStep[k].title}</div>
                  <div className="text-[9px] font-bold opacity-75">{c.shiftStep[k].sub}</div>
                </div>
              ))}
            </div>
            {c.shiftStep.flex.enabled && (
              <div className="rounded-xl bg-violet-50 py-2 text-center text-[11px] font-bold text-violet-700">
                🕒 {c.shiftStep.flex.label}
              </div>
            )}
          </div>
        );
      }
      case "budget":
        return (
          <div>
            <div className="flex h-10 items-end gap-0.5" dir="ltr">
              {[3, 5, 8, 6, 9, 7, 4, 3, 2, 2, 1, 1].map((h, i) => (
                <div
                  key={i}
                  className={`flex-1 rounded-t ${i / 12 <= c.budgetStep.initialPercent / 100 ? "bg-violet-500" : "bg-gray-200"}`}
                  style={{ height: `${h * 10}%` }}
                />
              ))}
            </div>
            <div className="mt-2 flex gap-1.5">
              <div className="flex-1 rounded-xl border border-violet-200 py-2 text-center text-[11px] font-bold text-violet-700">
                {c.budgetStep.openLabel}
              </div>
              <div className="flex-[2] rounded-xl bg-violet-600 py-2 text-center text-[11px] font-bold text-white">
                {c.budgetStep.submitLabel}
              </div>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  const thread = () => {
    if (show === "off")
      return (
        <div className="flex h-full flex-col items-center justify-center px-6 text-center">
          <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-full bg-violet-100 text-2xl">💤</div>
          <div className="text-sm font-black text-gray-900">{c.disabledTitle}</div>
          <div className="mt-1 text-[11px] leading-5 text-gray-500">{c.disabledMessage}</div>
        </div>
      );
    const question = {
      occasion: c.occasionStep.question,
      type: c.typeStep.question,
      province: c.provinceStep.question,
      guests: c.guestsStep.question,
      shift: c.shiftStep.question,
      budget: c.budgetStep.question,
      results: "",
    }[show];
    if (show === "results") {
      return (
        <>
          <Bubble text={c.finish.intro} />
          <div className="mb-2 rounded-2xl bg-gradient-to-br from-violet-500 to-violet-800 p-3 text-white">
            <div className="text-sm font-black">{c.results.title.replace("{occasion}", first?.label ?? "")}</div>
            <div className="mt-1.5 flex flex-wrap gap-1">
              {[first?.label, c.results.autoTypeChip, "بغداد", "150 ضيف"].map((t) => (
                <span key={t} className="rounded-full bg-white/15 px-2 py-0.5 text-[10px] font-bold">
                  {t}
                </span>
              ))}
            </div>
            <div className="mt-1 text-[9px] opacity-70">{c.results.editHint}</div>
          </div>
          <Bubble text={c.results.precise} />
          <div className="mb-2 flex gap-2 overflow-hidden">
            {[0, 1].map((i) => (
              <div key={i} className="w-40 shrink-0 overflow-hidden rounded-2xl border border-gray-100 bg-white">
                <div className="relative h-20 bg-gradient-to-br from-emerald-200 to-emerald-400">
                  {c.results.showMatchPercent && (
                    <span className="absolute left-2 top-2 rounded-full bg-white px-1.5 text-[10px] font-black text-emerald-700">
                      {c.matching.maxPercent - i * 7}٪
                    </span>
                  )}
                </div>
                <div className="p-2">
                  <div className="text-[11px] font-black">مزرعة {i ? "الريف" : "النخيل"}</div>
                  {c.results.showReasons && (
                    <div className="mt-1 flex gap-1">
                      <span className="rounded bg-emerald-50 px-1 text-[9px] font-bold text-emerald-700">في بغداد</span>
                      <span className="rounded bg-emerald-50 px-1 text-[9px] font-bold text-emerald-700">ضمن ميزانيتك</span>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
          {first?.suggestDecor && c.matching.decorCount > 0 && <Bubble text={c.results.decorIntro} />}
          <div className="flex gap-1.5">
            <div className="flex-1 rounded-xl border border-violet-200 py-2 text-center text-[11px] font-bold text-violet-700">
              {c.results.restartLabel}
            </div>
            <div className="flex-1 rounded-xl bg-violet-600 py-2 text-center text-[11px] font-bold text-white">
              {c.results.allResultsLabel}
            </div>
          </div>
        </>
      );
    }
    return (
      <>
        {c.greeting.map((g, i) => (
          <Bubble key={i} text={g} />
        ))}
        {show !== "occasion" && first && (
          <>
            <Bubble text={c.occasionStep.question} />
            <Bubble text={first.label} mine />
            <Bubble text={first.reaction} />
          </>
        )}
        <Bubble text={question} />
      </>
    );
  };

  return (
    <div className="sticky top-24">
      <div className="mb-3 flex flex-wrap gap-1">
        {STEPS.map((s) => (
          <button
            key={s.id}
            type="button"
            onClick={() => setStep(s.id)}
            className={`rounded-full px-2.5 py-1 text-[11px] font-bold transition ${
              step === s.id ? "bg-accent text-white" : "bg-paper text-muted hover:text-accent"
            }`}
          >
            {s.label}
          </button>
        ))}
      </div>
      <div className="mx-auto w-[300px] rounded-[42px] border-[10px] border-gray-900 bg-gray-900 shadow-2xl">
        <div className="flex h-[580px] flex-col overflow-hidden rounded-[32px] bg-[#F7F5FF]" dir="rtl">
          <div className="flex items-center gap-2 bg-white px-3 pb-2 pt-6 shadow-sm">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-violet-500 to-violet-700 text-xs font-black text-white">
              V
            </div>
            <div className="min-w-0 flex-1">
              <div className="text-[13px] font-black text-gray-900">{c.name}</div>
              <div className="truncate text-[10px] font-bold text-gray-400">{c.subtitle}</div>
            </div>
          </div>
          <div className="flex-1 overflow-y-auto p-3">{thread()}</div>
          {picker() && <div className="rounded-t-3xl bg-white p-3 shadow-[0_-6px_20px_rgba(0,0,0,.06)]">{picker()}</div>}
        </div>
      </div>
      <p className="mt-3 text-center text-xs text-muted">معاينة تقريبية — تتحدث مع كل تعديل قبل الحفظ</p>
    </div>
  );
}
