"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { HelpTip } from "@/components/help-tip";
import { Input, Label, Textarea } from "@/components/ui/input";
import { DetailCard } from "@/components/ui/detail-card";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PhoneActions } from "@/components/phone-actions";
import { useToast } from "@/components/ui/toast";
import { api, isAdmin } from "@/lib/api";

type Settings = {
  appName: string;
  apiUrl: string;
  publicWebUrl: string;
  otpProvider: string;
  mediaPublicUrl: string;
  supportPhone: string;
  paymentInstructions?: string;
  morningShiftStart?: string;
  morningShiftEnd?: string;
  eveningShiftStart?: string;
  eveningShiftEnd?: string;
  fullShiftStart?: string;
  fullShiftEnd?: string;
  paymentGateways?: { zainCash: boolean; qiCard: boolean; manualProof: boolean };
  paymentGatewaysConfigured?: { zainCash: boolean; qiCard: boolean; manualProof: boolean };
  features?: { smsOtp: boolean; jobsQueue: boolean; globalSearch: boolean; farmShifts?: boolean };
  commissionPercent?: string;
  cancellationPolicy?: string;
  minBookingNoticeDays?: string;
  maintenanceMode?: boolean;
  whatsappConfigured?: boolean;
  notifyWhatsappEnabled?: boolean;
  maintenanceMessage?: string;
};

function SettingToggle({
  label,
  hint,
  checked,
  disabled,
  onChange,
}: {
  label: string;
  hint?: string;
  checked: boolean;
  disabled?: boolean;
  onChange: (next: boolean) => void;
}) {
  return (
    <label className={`field-checkbox ${disabled ? "opacity-60" : ""}`}>
      <input
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span className="min-w-0 flex-1">
        <span className="block font-semibold text-ink">{label}</span>
        {hint && <span className="mt-0.5 block text-xs text-muted">{hint}</span>}
      </span>
    </label>
  );
}

function CopyRow({ label, value, extra }: { label: string; value: string; extra?: React.ReactNode }) {
  const { toast } = useToast();
  return (
    <div className="copy-row">
      <span className="text-muted">{label}</span>
      <div className="flex flex-wrap items-center gap-2">
        <span dir="ltr" className="max-w-[240px] truncate font-semibold text-ink">{value}</span>
        {extra}
        <button
          type="button"
          className="rounded-lg border border-line bg-surface px-2 py-0.5 text-xs font-semibold text-muted transition hover:bg-accent-soft hover:text-accent"
          onClick={() => {
            navigator.clipboard.writeText(value);
            toast("تم النسخ");
          }}
        >
          نسخ
        </button>
      </div>
    </div>
  );
}

export default function SettingsPage() {
  const { toast } = useToast();
  const [settings, setSettings] = useState<Settings | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showTech, setShowTech] = useState(false);
  const [supportPhone, setSupportPhone] = useState("");
  const [paymentInstructions, setPaymentInstructions] = useState("");
  const [morningShiftStart, setMorningShiftStart] = useState("08:00");
  const [morningShiftEnd, setMorningShiftEnd] = useState("14:00");
  const [eveningShiftStart, setEveningShiftStart] = useState("16:00");
  const [eveningShiftEnd, setEveningShiftEnd] = useState("22:00");
  const [fullShiftStart, setFullShiftStart] = useState("08:00");
  const [fullShiftEnd, setFullShiftEnd] = useState("22:00");
  const [commissionPercent, setCommissionPercent] = useState("0");
  const [cancellationPolicy, setCancellationPolicy] = useState("");
  const [minBookingNoticeDays, setMinBookingNoticeDays] = useState("1");
  const [zainCashEnabled, setZainCashEnabled] = useState(false);
  const [qiCardEnabled, setQiCardEnabled] = useState(false);
  const [manualProofEnabled, setManualProofEnabled] = useState(true);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [maintenanceMessage, setMaintenanceMessage] = useState("");
  const [notifyWhatsappEnabled, setNotifyWhatsappEnabled] = useState(false);
  const [admin, setAdmin] = useState(false);

  useEffect(() => {
    setAdmin(isAdmin());
    api<Settings>("/api/admin/settings")
      .then((data) => {
        setSettings(data);
        setSupportPhone(data.supportPhone ?? "");
        setPaymentInstructions(data.paymentInstructions ?? "");
        setMorningShiftStart(data.morningShiftStart ?? "08:00");
        setMorningShiftEnd(data.morningShiftEnd ?? "14:00");
        setEveningShiftStart(data.eveningShiftStart ?? "16:00");
        setEveningShiftEnd(data.eveningShiftEnd ?? "22:00");
        setFullShiftStart(data.fullShiftStart ?? "08:00");
        setFullShiftEnd(data.fullShiftEnd ?? "22:00");
        setCommissionPercent(data.commissionPercent ?? "0");
        setCancellationPolicy(data.cancellationPolicy ?? "");
        setMinBookingNoticeDays(data.minBookingNoticeDays ?? "1");
        setZainCashEnabled(data.paymentGateways?.zainCash ?? false);
        setQiCardEnabled(data.paymentGateways?.qiCard ?? false);
        setManualProofEnabled(data.paymentGateways?.manualProof ?? true);
        setMaintenanceMode(data.maintenanceMode ?? false);
        setMaintenanceMessage(data.maintenanceMessage ?? "");
        setNotifyWhatsappEnabled((data as { notifyWhatsappEnabled?: boolean }).notifyWhatsappEnabled ?? false);
      })
      .catch(() => undefined)
      .finally(() => setLoading(false));
  }, []);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const updated = await api<Settings>("/api/admin/settings", {
        method: "PATCH",
        body: JSON.stringify({
          supportPhone: supportPhone.trim(),
          paymentInstructions: paymentInstructions.trim(),
          morningShiftStart: morningShiftStart.trim(),
          morningShiftEnd: morningShiftEnd.trim(),
          eveningShiftStart: eveningShiftStart.trim(),
          eveningShiftEnd: eveningShiftEnd.trim(),
          fullShiftStart: fullShiftStart.trim(),
          fullShiftEnd: fullShiftEnd.trim(),
          commissionPercent: commissionPercent.trim(),
          cancellationPolicy: cancellationPolicy.trim(),
          minBookingNoticeDays: minBookingNoticeDays.trim(),
          zainCashEnabled,
          qiCardEnabled,
          manualProofEnabled,
          maintenanceMode,
          maintenanceMessage: maintenanceMessage.trim(),
          notifyWhatsappEnabled,
        }),
      });
      setSettings(updated);
      toast("تم حفظ الإعدادات");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ — قد تحتاج صلاحية مدير", "error");
    } finally {
      setSaving(false);
    }
  }

  return (
    <PageShell>
      <PageHeader title="الإعدادات" description="هاتف الدعم، التحويل اليدوي، وأوقات شفتات المزارع" eyebrow="VIBES Admin" />

      {admin ? (
        <HelpTip>هذه الأرقام والتعليمات تظهر للعملاء عند الدفع اليدوي.</HelpTip>
      ) : (
        <HelpTip>عرض فقط — تعديل هاتف الدعم وتعليمات التحويل متاح للمدير.</HelpTip>
      )}

      {loading && <LoadingBlock />}

      {settings && (
        <div className="detail-stack">
          <DetailCard title="التواصل والدفع">
            <form onSubmit={save} className="space-y-4">
              <div>
                <Label htmlFor="supportPhone">هاتف الدعم</Label>
                <Input
                  id="supportPhone"
                  dir="ltr"
                  value={supportPhone}
                  onChange={(e) => setSupportPhone(e.target.value)}
                  disabled={!admin}
                  required
                />
              </div>
              <div>
                <Label htmlFor="paymentInstructions">تعليمات التحويل اليدوي</Label>
                <Textarea
                  id="paymentInstructions"
                  value={paymentInstructions}
                  onChange={(e) => setPaymentInstructions(e.target.value)}
                  disabled={!admin}
                  placeholder={"مثال:\nزين كاش: 0780xxxxxxx\nاسم الحساب: فيبز\nرقم الحساب: ..."}
                />
              </div>
              <div className="settings-divider">
                <h3 className="settings-section-title">سياسات المنصة</h3>
                <div className="mb-4 grid gap-4 sm:grid-cols-2">
                  <div>
                    <Label htmlFor="commissionPercent">عمولة المنصة (%)</Label>
                    <Input id="commissionPercent" dir="ltr" value={commissionPercent} onChange={(e) => setCommissionPercent(e.target.value)} disabled={!admin} />
                  </div>
                  <div>
                    <Label htmlFor="minBookingNoticeDays">أقل مهلة حجز (أيام)</Label>
                    <Input id="minBookingNoticeDays" dir="ltr" type="number" min={0} value={minBookingNoticeDays} onChange={(e) => setMinBookingNoticeDays(e.target.value)} disabled={!admin} />
                  </div>
                  <div className="sm:col-span-2">
                    <Label htmlFor="cancellationPolicy">سياسة الإلغاء</Label>
                    <Textarea id="cancellationPolicy" value={cancellationPolicy} onChange={(e) => setCancellationPolicy(e.target.value)} disabled={!admin} placeholder="نص يظهر للعملاء..." />
                  </div>
                </div>
                <h3 className="settings-section-title">أوقات شفتات المزارع</h3>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <Label htmlFor="morningShiftStart">بداية الشفت الصباحي</Label>
                    <Input id="morningShiftStart" dir="ltr" value={morningShiftStart} onChange={(e) => setMorningShiftStart(e.target.value)} disabled={!admin} />
                  </div>
                  <div>
                    <Label htmlFor="morningShiftEnd">نهاية الشفت الصباحي</Label>
                    <Input id="morningShiftEnd" dir="ltr" value={morningShiftEnd} onChange={(e) => setMorningShiftEnd(e.target.value)} disabled={!admin} />
                  </div>
                  <div>
                    <Label htmlFor="eveningShiftStart">بداية الشفت المسائي</Label>
                    <Input id="eveningShiftStart" dir="ltr" value={eveningShiftStart} onChange={(e) => setEveningShiftStart(e.target.value)} disabled={!admin} />
                  </div>
                  <div>
                    <Label htmlFor="eveningShiftEnd">نهاية الشفت المسائي</Label>
                    <Input id="eveningShiftEnd" dir="ltr" value={eveningShiftEnd} onChange={(e) => setEveningShiftEnd(e.target.value)} disabled={!admin} />
                  </div>
                  <div>
                    <Label htmlFor="fullShiftStart">بداية اليوم الكامل</Label>
                    <Input id="fullShiftStart" dir="ltr" value={fullShiftStart} onChange={(e) => setFullShiftStart(e.target.value)} disabled={!admin} />
                  </div>
                  <div>
                    <Label htmlFor="fullShiftEnd">نهاية اليوم الكامل</Label>
                    <Input id="fullShiftEnd" dir="ltr" value={fullShiftEnd} onChange={(e) => setFullShiftEnd(e.target.value)} disabled={!admin} />
                  </div>
                </div>
              </div>

              <div className="settings-divider">
                <h3 className="settings-section-title">طرق الدفع المتاحة للعملاء</h3>
                <div className="grid gap-3">
                  <SettingToggle
                    label="تحويل يدوي + إثبات"
                    hint="العميل يحوّل ويرفع صورة الإثبات ليراجعها الفريق"
                    checked={manualProofEnabled}
                    disabled={!admin}
                    onChange={setManualProofEnabled}
                  />
                  <SettingToggle
                    label="زين كاش (بوابة إلكترونية)"
                    hint={
                      settings.paymentGatewaysConfigured?.zainCash
                        ? "البوابة مضبوطة — يمكن تشغيلها للعملاء"
                        : "غير مضبوطة: أضف ZAIN_CASH_MERCHANT_ID في متغيرات البيئة أولاً"
                    }
                    checked={zainCashEnabled}
                    disabled={!admin}
                    onChange={setZainCashEnabled}
                  />
                  <SettingToggle
                    label="Qi Card (بوابة إلكترونية)"
                    hint={
                      settings.paymentGatewaysConfigured?.qiCard
                        ? "البوابة مضبوطة — يمكن تشغيلها للعملاء"
                        : "غير مضبوطة: أضف QI_CARD_TERMINAL_ID في متغيرات البيئة أولاً"
                    }
                    checked={qiCardEnabled}
                    disabled={!admin}
                    onChange={setQiCardEnabled}
                  />
                </div>
                <Link href="/integrations" className="mt-3 inline-block text-sm font-bold text-accent hover:underline">
                  عرض حالة التكاملات ←
                </Link>
              </div>

              <div className="settings-divider">
                <h3 className="settings-section-title">الإشعارات</h3>
                <SettingToggle
                  label="إشعار واتساب لملاك الأماكن"
                  hint={settings.whatsappConfigured ? "يُرسل واتساب للمالك عند حجز جديد أو تغيّر حالة" : "يتطلب تهيئة WhatsApp API في التكاملات أولاً"}
                  checked={notifyWhatsappEnabled}
                  disabled={!admin || !settings.whatsappConfigured}
                  onChange={setNotifyWhatsappEnabled}
                />
              </div>

              <div className="settings-divider">
                <h3 className="settings-section-title">وضع الصيانة</h3>
                <SettingToggle
                  label="إيقاف الحجز مؤقتاً"
                  hint="يظهر للعملاء في التطبيق أن الحجز متوقف مؤقتاً"
                  checked={maintenanceMode}
                  disabled={!admin}
                  onChange={setMaintenanceMode}
                />
                {maintenanceMode && (
                  <div className="mt-3">
                    <Label htmlFor="maintenanceMessage">الرسالة المعروضة للعملاء</Label>
                    <Textarea
                      id="maintenanceMessage"
                      value={maintenanceMessage}
                      onChange={(e) => setMaintenanceMessage(e.target.value)}
                      disabled={!admin}
                      placeholder="مثال: نعمل على تحديث النظام — سيعود الحجز قريباً"
                      rows={2}
                    />
                  </div>
                )}
              </div>

              {admin && (
                <Button type="submit" disabled={saving}>{saving ? "جاري الحفظ..." : "حفظ"}</Button>
              )}
            </form>
          </DetailCard>

          <DetailCard title="عام">
            <CopyRow label="اسم التطبيق" value={settings.appName} />
            <CopyRow label="هاتف الدعم" value={settings.supportPhone} extra={<PhoneActions phone={settings.supportPhone} compact />} />
            <CopyRow label="الموقع العام" value={settings.publicWebUrl} />
          </DetailCard>

          <button
            type="button"
            className="inline-flex items-center gap-2 rounded-xl border border-line bg-paper px-4 py-2 text-sm font-semibold text-accent transition hover:bg-accent-soft"
            onClick={() => setShowTech((v) => !v)}
          >
            {showTech ? "إخفاء المعلومات التقنية" : "عرض معلومات تقنية (للمطورين)"}
          </button>

          {showTech && (
            <DetailCard title="تقني">
              <CopyRow label="رابط API" value={settings.apiUrl} />
              <CopyRow label="رابط الوسائط" value={settings.mediaPublicUrl} />
              <CopyRow label="نظام OTP" value={settings.otpProvider} />
            </DetailCard>
          )}
        </div>
      )}
    </PageShell>
  );
}
