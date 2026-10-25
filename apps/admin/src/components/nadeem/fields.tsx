"use client";

import type { ReactNode } from "react";
import { Card } from "@/components/ui/card";
import { Input, Label, Textarea } from "@/components/ui/input";

export function Section({
  title,
  description,
  action,
  children,
  muted,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  children: ReactNode;
  muted?: boolean;
}) {
  return (
    <Card className={muted ? "opacity-70" : ""}>
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-base font-bold text-ink">{title}</h3>
          {description && <p className="mt-0.5 text-xs leading-5 text-muted">{description}</p>}
        </div>
        {action}
      </div>
      <div className="space-y-4">{children}</div>
    </Card>
  );
}

export function TextField({
  label,
  value,
  onChange,
  hint,
  multiline,
  placeholder,
  maxLength = 300,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
  multiline?: boolean;
  placeholder?: string;
  maxLength?: number;
}) {
  return (
    <div>
      <Label>{label}</Label>
      {multiline ? (
        <Textarea
          className="min-h-[72px]"
          value={value}
          maxLength={maxLength}
          placeholder={placeholder}
          onChange={(e) => onChange(e.target.value)}
        />
      ) : (
        <Input value={value} maxLength={maxLength} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
      )}
      {hint && <p className="mt-1 text-xs text-muted">{hint}</p>}
    </div>
  );
}

export function NumberField({
  label,
  value,
  onChange,
  hint,
  min,
  max,
  suffix,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  hint?: string;
  min?: number;
  max?: number;
  suffix?: string;
}) {
  return (
    <div>
      <Label>{label}</Label>
      <div className="flex items-center gap-2">
        <Input
          type="number"
          dir="ltr"
          value={Number.isFinite(value) ? value : 0}
          min={min}
          max={max}
          onChange={(e) => onChange(Number(e.target.value))}
        />
        {suffix && <span className="shrink-0 text-xs font-semibold text-muted">{suffix}</span>}
      </div>
      {hint && <p className="mt-1 text-xs text-muted">{hint}</p>}
    </div>
  );
}

export function Toggle({
  label,
  hint,
  checked,
  onChange,
}: {
  label: string;
  hint?: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="field-checkbox">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span className="min-w-0 flex-1">
        <span className="block font-semibold text-ink">{label}</span>
        {hint && <span className="mt-0.5 block text-xs text-muted">{hint}</span>}
      </span>
    </label>
  );
}

/** مفتاح تشغيل صغير لرأس البطاقة. */
export function Switch({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className="inline-flex items-center gap-2 text-xs font-semibold text-muted"
    >
      {label && <span>{label}</span>}
      <span
        className={`relative inline-block h-6 w-11 rounded-full transition ${checked ? "bg-accent" : "bg-line"}`}
      >
        <span
          className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${
            checked ? "right-0.5" : "right-[22px]"
          }`}
        />
      </span>
    </button>
  );
}

export function Grid({ children, cols = 2 }: { children: ReactNode; cols?: 2 | 3 | 4 }) {
  const c = { 2: "sm:grid-cols-2", 3: "sm:grid-cols-3", 4: "sm:grid-cols-2 lg:grid-cols-4" }[cols];
  return <div className={`grid grid-cols-1 gap-4 ${c}`}>{children}</div>;
}

export function TokenHint({ tokens }: { tokens: string[] }) {
  return (
    <p className="text-xs text-muted">
      متغيرات متاحة:{" "}
      {tokens.map((t) => (
        <code key={t} dir="ltr" className="mx-0.5 rounded bg-accent-soft px-1.5 py-0.5 text-[11px] font-bold text-accent">
          {t}
        </code>
      ))}
    </p>
  );
}
