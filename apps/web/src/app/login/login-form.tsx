"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { ArrowRight, Lock, Phone } from "lucide-react";
import { api } from "@/lib/api";
import { normalizePhone, useAuth } from "@/lib/auth";

type Phase = "phone" | "unlock" | "create" | "confirm";

export function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") || "/";
  const { login, user, ready } = useAuth();
  const [phase, setPhase] = useState<Phase>("phone");
  const [phone, setPhone] = useState("");
  const [pin, setPin] = useState("");
  const [draft, setDraft] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const pinRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (ready && user && phase === "phone") router.replace(next);
  }, [ready, user]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (phase !== "phone") pinRef.current?.focus();
  }, [phase]);

  async function continuePhone(e: React.FormEvent) {
    e.preventDefault();
    const p = normalizePhone(phone);
    if (!/^964\d{10}$/.test(p)) {
      setError("أدخل رقم هاتف عراقي صحيح، مثل 07XXXXXXXXX");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await api<{ hasPin: boolean }>("/api/auth/pin/lookup", { method: "POST", body: { phone: p }, auth: false });
      setPhase(res.hasPin ? "unlock" : "create");
      setPin("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر المتابعة");
    } finally {
      setLoading(false);
    }
  }

  async function submitPin(value: string) {
    if (value.length !== 6 || loading) return;
    if (phase === "create") {
      setDraft(value);
      setPin("");
      setPhase("confirm");
      setError(null);
      return;
    }
    if (phase === "confirm" && value !== draft) {
      setError("الرقمان غير متطابقين — أعد الاختيار");
      setPhase("create");
      setDraft("");
      setPin("");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      await login(normalizePhone(phone), value);
      if (phase === "confirm" && name.trim()) {
        await api("/api/users/me", { method: "PATCH", body: { name: name.trim() } }).catch(() => undefined);
      }
      router.replace(next);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر الدخول");
      setPin("");
      setLoading(false);
    }
  }

  const title = {
    phone: "أهلاً بك في VIBES",
    unlock: "أدخل رمزك السري",
    create: "اختر رمزاً سرياً",
    confirm: "أكّد الرمز السري",
  }[phase];
  const sub = {
    phone: "سجّل دخولك برقم هاتفك لتحجز وتتابع حجوزاتك",
    unlock: "الرمز المكوّن من 6 أرقام الذي تستخدمه في التطبيق",
    create: "6 أرقام تستخدمها للدخول من التطبيق والموقع",
    confirm: "أعد كتابة الرمز نفسه للتأكيد",
  }[phase];

  return (
    <div className="card w-full max-w-md p-7 shadow-[var(--shadow-card)] animate-fade-up">
      <div className="mb-6 flex flex-col items-center text-center">
        <span className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-midnight">
          {phase === "phone" ? <Phone className="h-6 w-6 text-brass-light" /> : <Lock className="h-6 w-6 text-brass-light" />}
        </span>
        <h1 className="text-2xl font-black">{title}</h1>
        <p className="mt-1.5 text-sm text-ink-2">{sub}</p>
      </div>

      {phase === "phone" ? (
        <form onSubmit={continuePhone} className="space-y-4">
          <label className="block">
            <span className="mb-1.5 block text-sm font-bold">رقم الهاتف</span>
            <div className="flex items-center gap-2">
              <span className="num rounded-2xl border border-line bg-cream px-3 py-3 text-sm font-bold text-ink-2" dir="ltr">
                +964
              </span>
              <input
                className="field num text-left"
                dir="ltr"
                inputMode="tel"
                autoComplete="tel"
                placeholder="07XX XXX XXXX"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                autoFocus
              />
            </div>
          </label>
          {error && <p className="rounded-xl bg-danger-pale px-3 py-2 text-sm font-semibold text-danger">{error}</p>}
          <button className="btn btn-primary h-12 w-full" disabled={loading}>
            {loading ? "لحظة…" : "متابعة"}
          </button>
        </form>
      ) : (
        <div className="space-y-4">
          <button
            type="button"
            onClick={() => {
              setPhase("phone");
              setError(null);
              setPin("");
            }}
            className="mx-auto flex items-center gap-1 text-sm font-bold text-ink-2 hover:text-ink"
          >
            <ArrowRight className="h-4 w-4" />
            <span className="num" dir="ltr">
              {phone}
            </span>
          </button>
          {phase === "confirm" && (
            <input className="field" placeholder="اسمك (اختياري)" value={name} onChange={(e) => setName(e.target.value)} />
          )}
          <PinBoxes
            inputRef={pinRef}
            value={pin}
            onChange={(v) => {
              setPin(v);
              if (v.length === 6) submitPin(v);
            }}
          />
          {error && <p className="rounded-xl bg-danger-pale px-3 py-2 text-center text-sm font-semibold text-danger">{error}</p>}
          <button className="btn btn-primary h-12 w-full" disabled={loading || pin.length !== 6} onClick={() => submitPin(pin)}>
            {loading ? "جاري الدخول…" : phase === "create" ? "التالي" : "دخول"}
          </button>
          {phase === "unlock" && (
            <p className="text-center text-xs text-ink-3">نسيت الرمز؟ تواصل مع الدعم لإعادة تعيينه.</p>
          )}
        </div>
      )}
    </div>
  );
}

function PinBoxes({
  value,
  onChange,
  inputRef,
}: {
  value: string;
  onChange: (v: string) => void;
  inputRef: React.RefObject<HTMLInputElement | null>;
}) {
  return (
    <div className="relative" onClick={() => inputRef.current?.focus()}>
      <input
        ref={inputRef}
        className="absolute inset-0 opacity-0"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={6}
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, "").slice(0, 6))}
        aria-label="الرمز السري"
      />
      <div className="flex justify-center gap-2" dir="ltr">
        {Array.from({ length: 6 }).map((_, i) => (
          <span
            key={i}
            className={`flex h-14 w-12 items-center justify-center rounded-2xl border-2 text-2xl font-black transition ${
              i === value.length ? "border-brass bg-brass-pale/40" : value[i] ? "border-midnight bg-white" : "border-line bg-cream"
            }`}
          >
            {value[i] ? "•" : ""}
          </span>
        ))}
      </div>
    </div>
  );
}
