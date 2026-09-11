"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { IconSettings } from "@/components/nav-icons";
import { PhoneActions } from "@/components/phone-actions";
import { SkeletonCard } from "@/components/ui/skeleton";
import { Alert } from "@/components/ui/alert";
import { api } from "@/lib/api";

type Settings = {
  supportPhone: string;
  paymentInstructions?: string;
};

export function PaymentInstructions() {
  const [settings, setSettings] = useState<Settings | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    api<Settings>("/api/admin/settings")
      .then(setSettings)
      .catch(() => setError("تعذر تحميل تعليمات الدفع"))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <SkeletonCard />;

  if (error || !settings) {
    return (
      <Alert variant="warning">
        {error ?? "تعذر تحميل الإعدادات"}.{" "}
        <Link href="/settings" className="font-semibold underline">افتح الإعدادات</Link>
      </Alert>
    );
  }

  const instructions = settings.paymentInstructions?.trim() ?? "";

  return (
    <Card className="payment-info-card">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2.5">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-accent text-white">
            <IconSettings className="h-4 w-4" />
          </span>
          <h2 className="font-bold text-ink">تعليمات التحويل للعميل</h2>
        </div>
        <div className="flex items-center gap-2">
          {settings.supportPhone && <PhoneActions phone={settings.supportPhone} compact />}
          <Link href="/settings" className="text-xs font-bold text-accent hover:underline">
            تعديل
          </Link>
        </div>
      </div>
      {instructions ? (
        <p className="whitespace-pre-wrap rounded-xl border border-line bg-paper/80 p-4 text-sm leading-7 text-muted">
          {instructions}
        </p>
      ) : (
        <p className="text-sm leading-7 text-muted">
          لم تُضبط تعليمات التحويل بعد.{" "}
          <Link href="/settings" className="font-semibold text-accent underline">
            أضف رقم الحساب أو زين كاش من الإعدادات
          </Link>{" "}
          ثم قارن إثبات العميل بها.
        </p>
      )}
    </Card>
  );
}
