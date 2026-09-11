"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { BrandLogo } from "@/components/brand-logo";
import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/input";
import { HelpTip } from "@/components/help-tip";
import { Alert } from "@/components/ui/alert";
import { StepIndicator } from "@/components/ui/step-indicator";
import { normalizeIraqiPhone } from "@/components/phone-actions";
import { IconCalendar, IconBuilding, IconChart } from "@/components/nav-icons";
import { api, setSession } from "@/lib/api";

const FEATURES = [
  { icon: IconCalendar, color: "sky", text: "إدارة الحجوزات والمدفوعات" },
  { icon: IconBuilding, color: "teal", text: "نشر الأماكن ومراجعة المزودين" },
  { icon: IconChart, color: "violet", text: "تقارير وإحصائيات فورية" },
];

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [step, setStep] = useState<"phone" | "code">("phone");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showDev, setShowDev] = useState(false);
  const submitting = useRef(false);
  const codeRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (step === "code") setTimeout(() => codeRef.current?.focus(), 50);
  }, [step]);

  function normalizedPhone() {
    return normalizeIraqiPhone(phone.trim());
  }

  async function sendCode(event?: React.FormEvent) {
    event?.preventDefault();
    const nextPhone = normalizedPhone();
    if (nextPhone.length < 12) {
      setError("أدخل رقم هاتف عراقي صحيح");
      return;
    }
    setPhone(nextPhone);
    setLoading(true);
    setError(null);
    try {
      await api("/api/auth/otp/send", { method: "POST", body: JSON.stringify({ phone: nextPhone }) });
      setStep("code");
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إرسال الرمز");
    } finally {
      setLoading(false);
    }
  }

  async function verify(event?: React.FormEvent) {
    event?.preventDefault();
    if (submitting.current) return;
    submitting.current = true;
    setLoading(true);
    setError(null);
    try {
      const result = await api<{ accessToken: string; refreshToken: string; user: { role: string } }>("/api/auth/otp/verify", {
        method: "POST",
        body: JSON.stringify({ phone: normalizedPhone(), code: code.trim() }),
      });
      if (!["ADMIN", "STAFF", "PROVIDER"].includes(result.user.role)) {
        throw new Error("هذا الحساب لا يملك صلاحية دخول لوحة VIBES");
      }
      setSession(result.accessToken, result.refreshToken, result.user.role);
      const next = typeof window !== "undefined" ? new URLSearchParams(window.location.search).get("next") : null;
      const fallback = result.user.role === "PROVIDER" ? "/provider" : "/";
      router.replace(next && next.startsWith("/") && !next.startsWith("/login") ? next : fallback);
    } catch (err) {
      setError(err instanceof Error ? err.message : "رمز غير صحيح");
      submitting.current = false;
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (step === "code" && code.replace(/\D/g, "").length === 6 && !loading) {
      void verify();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code, step]);

  return (
    <div className="login-page app-canvas login-layout">
      <div className="absolute left-4 top-4 z-10 lg:left-6 lg:top-6">
        <ThemeToggle />
      </div>
      <aside className="login-aside">
        <div>
          <BrandLogo size="lg" variant="light" />
          <h1 className="login-aside-title mt-10">لوحة تشغيل VIBES</h1>
          <p className="login-aside-desc">
            كل ما يحتاجه فريقك لإدارة الأماكن، الحجوزات، والمدفوعات — في مكان واحد.
          </p>
          <div className="login-aside-features">
            {FEATURES.map((f) => {
              const Icon = f.icon;
              return (
                <div key={f.text} className="login-feature">
                  <span className={`login-feature-icon icon-chip icon-chip-${f.color}`} aria-hidden>
                    <Icon className="h-4 w-4" />
                  </span>
                  {f.text}
                </div>
              );
            })}
          </div>
        </div>
        <p className="text-xs text-muted">© VIBES — للفريق وأصحاب الأماكن</p>
      </aside>

      <main className="login-main">
        <div className="w-full max-w-[400px] animate-fade-up">
          <div className="mb-8 flex justify-center lg:hidden">
            <BrandLogo size="lg" variant="light" />
          </div>

          <div className="login-card">
            <div className="login-card-accent" aria-hidden />
            <div className="p-7 sm:p-8">
              <StepIndicator steps={["الهاتف", "الرمز"]} current={step === "phone" ? 0 : 1} />

              <div className="mb-7 text-center">
                <h2 className="login-title">تسجيل الدخول</h2>
                <p className="login-subtitle">فريق VIBES أو مالك مكان — برمز OTP</p>
              </div>

              {step === "phone" ? (
                <form className="space-y-4" onSubmit={sendCode}>
                  <div>
                    <Label htmlFor="phone">رقم الهاتف</Label>
                    <Input
                      id="phone"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      dir="ltr"
                      inputMode="tel"
                      placeholder="07XXXXXXXXX"
                      required
                    />
                    <p className="mt-1.5 text-xs text-muted">يمكنك كتابته بـ 07 أو 964</p>
                  </div>
                  {error && <Alert variant="danger">{error}</Alert>}
                  <Button type="submit" disabled={loading} className="w-full">
                    {loading ? "جاري الإرسال..." : "إرسال رمز التحقق"}
                  </Button>
                </form>
              ) : (
                <form className="space-y-4" onSubmit={verify}>
                  <HelpTip>
                    تم إرسال رمز إلى <span dir="ltr">{normalizedPhone()}</span>
                  </HelpTip>
                  <div>
                    <Label htmlFor="code">رمز التحقق</Label>
                    <Input
                      ref={codeRef}
                      id="code"
                      value={code}
                      onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                      dir="ltr"
                      inputMode="numeric"
                      autoComplete="one-time-code"
                      placeholder="6 أرقام"
                      className="text-center text-lg tracking-[0.3em]"
                      required
                    />
                  </div>
                  {error && <Alert variant="danger">{error}</Alert>}
                  <Button type="submit" disabled={loading || code.length < 6} className="w-full">
                    {loading ? "جاري الدخول..." : "دخول"}
                  </Button>
                  <div className="flex justify-between text-sm">
                    <button
                      type="button"
                      className="text-muted underline"
                      onClick={() => {
                        setStep("phone");
                        setCode("");
                        setError(null);
                        submitting.current = false;
                      }}
                    >
                      تغيير الرقم
                    </button>
                    <button type="button" className="font-semibold text-accent" disabled={loading} onClick={() => sendCode()}>
                      إعادة إرسال الرمز
                    </button>
                  </div>
                </form>
              )}

              <button
                type="button"
                className="mt-8 w-full text-xs text-muted-light"
                onClick={() => setShowDev((v) => !v)}
              >
                {showDev ? "إخفاء" : "بيئة التطوير؟"}
              </button>
              {showDev && (
                <div className="mt-2 rounded-xl bg-brand-soft p-3 text-xs text-muted" dir="ltr">
                  Admin: 9647700000000 · Staff: 9647700000002 · OTP: 123456
                </div>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
