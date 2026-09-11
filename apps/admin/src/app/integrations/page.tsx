"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { HelpTip } from "@/components/help-tip";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { api } from "@/lib/api";

type Gateways = { zainCash: boolean; qiCard: boolean; manualProof: boolean };

type Settings = {
  otpProvider?: string;
  paymentGateways?: Gateways;
  paymentGatewaysConfigured?: Gateways;
  features?: Record<string, boolean>;
  mediaPublicUrl?: string;
  apiUrl?: string;
  publicWebUrl?: string;
  maintenanceMode?: boolean;
  whatsappConfigured?: boolean;
};

const OTP_PROVIDER_LABELS: Record<string, string> = {
  development: "تطوير (رمز ثابت)",
  console: "سجلات الخادم فقط",
  webhook: "Webhook خارجي",
  whatsapp: "واتساب (WhatsApp Cloud API)",
};

export default function IntegrationsPage() {
  const [settings, setSettings] = useState<Settings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api<Settings>("/api/admin/settings")
      .then(setSettings)
      .catch(() => undefined)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <LoadingBlock />;

  const gateways = [
    {
      key: "manualProof",
      label: "إثبات تحويل يدوي",
      enabled: settings?.paymentGateways?.manualProof ?? true,
      configured: true,
      note: "لا يحتاج ضبط خارجي",
    },
    {
      key: "zainCash",
      label: "Zain Cash",
      enabled: settings?.paymentGateways?.zainCash ?? false,
      configured: settings?.paymentGatewaysConfigured?.zainCash ?? false,
      note: "يتطلب ZAIN_CASH_MERCHANT_ID و ZAIN_CASH_SECRET للتحقق من الـ webhook",
    },
    {
      key: "qiCard",
      label: "Qi Card",
      enabled: settings?.paymentGateways?.qiCard ?? false,
      configured: settings?.paymentGatewaysConfigured?.qiCard ?? false,
      note: "يتطلب QI_CARD_TERMINAL_ID و QI_CARD_SECRET للتحقق من الـ webhook",
    },
  ];

  return (
    <PageShell>
      <PageHeader
        title="التكاملات"
        description="حالة بوابات الدفع والخدمات الخارجية"
        eyebrow="VIBES Admin"
        action={
          <Link href="/settings">
            <Button variant="ghost" size="sm">← الإعدادات</Button>
          </Link>
        }
      />

      <HelpTip>
        «مضبوط» يعني أن مفاتيح البوابة موجودة على الخادم، و«مفعّل» يعني أنها معروضة للعملاء —
        وهذا تتحكم به من{" "}
        <Link href="/settings" className="font-semibold underline">الإعدادات</Link>.
      </HelpTip>

      {settings?.maintenanceMode && (
        <HelpTip variant="warning">وضع الصيانة مفعّل حالياً — الحجز متوقف للعملاء.</HelpTip>
      )}

      <div className="grid gap-4 md:grid-cols-2">
        <Card className="space-y-4">
          <h2 className="card-section-title">بوابات الدفع</h2>
          {gateways.map((g) => (
            <div key={g.key} className="flex items-start justify-between gap-3 rounded-xl border border-line px-4 py-3">
              <div className="min-w-0">
                <div className="font-semibold">{g.label}</div>
                <div className="mt-0.5 text-xs leading-5 text-muted">{g.note}</div>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1">
                <Badge variant={g.enabled ? "success" : "muted"}>{g.enabled ? "مفعّل" : "غير مفعّل"}</Badge>
                <Badge variant={g.configured ? "default" : "warning"}>
                  {g.configured ? "مضبوط" : "غير مضبوط"}
                </Badge>
              </div>
            </div>
          ))}
          <div className="rounded-xl border border-line bg-surface px-4 py-3 text-xs leading-6 text-muted">
            عنوان استلام تأكيد الدفع (webhook):
            <div dir="ltr" className="mt-1 font-semibold text-ink">
              {settings?.apiUrl ?? ""}/api/payments/callback/zain-cash
            </div>
            <div dir="ltr" className="font-semibold text-ink">
              {settings?.apiUrl ?? ""}/api/payments/callback/qi-card
            </div>
          </div>
        </Card>

        <Card className="space-y-4">
          <h2 className="card-section-title">الخدمات</h2>
          <div className="space-y-3 text-sm">
            <div className="flex items-start justify-between gap-2">
              <span className="text-muted">رمز التحقق (OTP)</span>
              <div className="flex flex-col items-end gap-1">
                <Badge>{OTP_PROVIDER_LABELS[settings?.otpProvider ?? "development"] ?? settings?.otpProvider}</Badge>
                {settings?.otpProvider === "whatsapp" && (
                  <Badge variant={settings?.whatsappConfigured ? "default" : "warning"}>
                    {settings?.whatsappConfigured ? "مضبوط" : "غير مضبوط — أضف WHATSAPP_ACCESS_TOKEN"}
                  </Badge>
                )}
              </div>
            </div>
            <div className="flex justify-between gap-2">
              <span className="text-muted">البحث العام</span>
              <Badge variant={settings?.features?.globalSearch ? "success" : "muted"}>
                {settings?.features?.globalSearch ? "مفعّل" : "معطّل"}
              </Badge>
            </div>
            <div className="flex justify-between gap-2">
              <span className="text-muted">شفتات المزارع</span>
              <Badge variant={settings?.features?.farmShifts ? "success" : "muted"}>
                {settings?.features?.farmShifts ? "مفعّل" : "معطّل"}
              </Badge>
            </div>
            <div className="flex justify-between gap-2">
              <span className="text-muted">API</span>
              <span dir="ltr" className="text-xs">{settings?.apiUrl}</span>
            </div>
            <div className="flex justify-between gap-2">
              <span className="text-muted">الموقع العام</span>
              <span dir="ltr" className="text-xs">{settings?.publicWebUrl}</span>
            </div>
            <div className="flex justify-between gap-2">
              <span className="text-muted">الوسائط</span>
              <span dir="ltr" className="text-xs">{settings?.mediaPublicUrl}</span>
            </div>
          </div>
        </Card>
      </div>
    </PageShell>
  );
}
