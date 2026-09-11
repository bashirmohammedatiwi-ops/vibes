"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DetailCard, InfoRow } from "@/components/ui/detail-card";
import { ErrorBanner } from "@/components/ui/error-banner";
import { Input, Label, Textarea } from "@/components/ui/input";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { HelpTip } from "@/components/help-tip";
import { ImagePreview } from "@/components/image-preview";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PaymentInstructions } from "@/components/payment-instructions";
import { PhoneActions } from "@/components/phone-actions";
import { useToast } from "@/components/ui/toast";
import {
  BOOKING_STATUS_LABELS,
  PAYMENT_METHOD_LABELS,
  PAYMENT_STATUS_LABELS,
  SHIFT_TYPE_LABELS,
} from "@/lib/constants";
import { api, isAdmin } from "@/lib/api";
import { formatDayAr, formatMoney, relativeTimeAr } from "@/lib/dates";
import type { PaymentDetail } from "@/lib/types";

const STATUS_VARIANT: Record<string, "success" | "warning" | "danger" | "muted"> = {
  PAID: "success",
  PENDING: "warning",
  FAILED: "danger",
  REFUNDED: "muted",
};

export default function PaymentDetailPage() {
  const params = useParams<{ id: string }>();
  const { toast } = useToast();
  const [payment, setPayment] = useState<PaymentDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [adminNote, setAdminNote] = useState("");
  const [transactionRef, setTransactionRef] = useState("");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [refundOpen, setRefundOpen] = useState(false);
  const [admin, setAdmin] = useState(false);

  const load = useCallback(async () => {
    const data = await api<PaymentDetail>(`/api/admin/payments/${params.id}`);
    setPayment(data);
    setAdminNote(data.adminNote ?? "");
    setTransactionRef(data.transactionRef ?? "");
  }, [params.id]);

  useEffect(() => {
    setAdmin(isAdmin());
    load()
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, [load]);

  async function review(status: "PAID" | "FAILED") {
    if (status === "FAILED" && !adminNote.trim()) {
      toast("أضف ملاحظة قبل الرفض", "error");
      return;
    }
    setBusy(true);
    try {
      await api(`/api/admin/payments/${params.id}/review`, {
        method: "PATCH",
        body: JSON.stringify({
          status,
          adminNote: adminNote.trim() || undefined,
          transactionRef: transactionRef.trim() || undefined,
        }),
      });
      toast(status === "PAID" ? "تم تأكيد الدفع — الحجز مؤكد" : "تم رفض الدفعة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    } finally {
      setBusy(false);
    }
  }

  async function refund() {
    setBusy(true);
    try {
      await api(`/api/admin/payments/${params.id}/refund`, {
        method: "POST",
        body: JSON.stringify({ adminNote: adminNote.trim() }),
      });
      toast("تم الاسترداد وإلغاء الحجز");
      setRefundOpen(false);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الاسترداد", "error");
    } finally {
      setBusy(false);
    }
  }

  if (error) {
    return (
      <ErrorBanner
        message={error}
        onRetry={() => {
          setError(null);
          setLoading(true);
          load()
            .catch((err: Error) => setError(err.message))
            .finally(() => setLoading(false));
        }}
        backHref="/payments"
        backLabel="العودة للمدفوعات"
      />
    );
  }
  if (loading || !payment) return <LoadingBlock />;

  const booking = payment.booking;
  const isPending = payment.status === "PENDING";

  return (
    <PageShell className="page-shell-narrow">
      <PageHeader
        title={booking?.property?.name ?? "دفعة"}
        description={`${formatMoney(payment.amount)} · ${PAYMENT_METHOD_LABELS[payment.method] ?? payment.method}`}
        eyebrow="VIBES Admin"
        back={{ href: "/payments", label: "العودة للمدفوعات" }}
        onRefresh={() => void load()}
        action={
          <Badge variant={STATUS_VARIANT[payment.status] ?? "muted"}>
            {PAYMENT_STATUS_LABELS[payment.status] ?? payment.status}
          </Badge>
        }
      />

      {isPending && payment.proofUrl && (
        <HelpTip>افتح إثبات التحويل، قارن المبلغ والحساب، ثم اضغط «تأكيد الدفع».</HelpTip>
      )}
      {isPending && !payment.proofUrl && (
        <HelpTip variant="warning">لا يوجد إثبات تحويل — ارفعه من صفحة الحجز أو تواصل مع العميل.</HelpTip>
      )}
      {payment.status === "REFUNDED" && (
        <HelpTip variant="warning">تم استرداد هذه الدفعة وإلغاء الحجز المرتبط.</HelpTip>
      )}

      <DetailCard title="تفاصيل الدفعة">
        <InfoRow label="المبلغ" value={formatMoney(payment.amount)} />
        <InfoRow label="طريقة الدفع" value={PAYMENT_METHOD_LABELS[payment.method] ?? payment.method} />
        <InfoRow label="الحالة">
          <Badge variant={STATUS_VARIANT[payment.status] ?? "muted"}>
            {PAYMENT_STATUS_LABELS[payment.status] ?? payment.status}
          </Badge>
        </InfoRow>
        <InfoRow label="رقم العملية" value={payment.transactionRef ?? "—"} />
        <InfoRow label="أُنشئت" value={relativeTimeAr(payment.createdAt)} />
        {payment.reviewedAt && <InfoRow label="روجعت" value={relativeTimeAr(payment.reviewedAt)} />}
        {payment.reviewedBy && (
          <InfoRow label="بواسطة" value={payment.reviewedBy.name ?? payment.reviewedBy.phone} />
        )}
        {payment.adminNote && <InfoRow label="ملاحظة الفريق" value={payment.adminNote} />}
        <InfoRow label="إثبات التحويل">
          {payment.proofUrl ? (
            <button type="button" className="font-semibold text-accent underline" onClick={() => setPreviewUrl(payment.proofUrl!)}>
              عرض الإثبات
            </button>
          ) : (
            "لم يُرفع"
          )}
        </InfoRow>
      </DetailCard>

      {booking && (
        <DetailCard
          title="الحجز المرتبط"
          action={
            <Link href={`/bookings/${booking.id}`} className="text-sm font-bold text-accent hover:underline">
              فتح الحجز ←
            </Link>
          }
        >
          <InfoRow label="حالة الحجز">
            <Badge variant={booking.status === "CONFIRMED" || booking.status === "COMPLETED" ? "success" : "warning"}>
              {BOOKING_STATUS_LABELS[booking.status] ?? booking.status}
            </Badge>
          </InfoRow>
          <InfoRow
            label="التواريخ"
            value={`${formatDayAr(booking.startDate)} → ${formatDayAr(booking.endDate)}${
              booking.shift && booking.shift !== "FULL" ? ` · ${SHIFT_TYPE_LABELS[booking.shift]}` : ""
            }`}
          />
          <InfoRow label="عدد الضيوف" value={booking.guests} />
          <InfoRow label="إجمالي الحجز" value={formatMoney(booking.totalPrice)} />
          <InfoRow label="العميل">
            {booking.user?.id ? (
              <Link href={`/users/${booking.user.id}`} className="text-accent underline">
                {booking.user.name ?? booking.user.phone}
              </Link>
            ) : (
              booking.user?.name ?? "—"
            )}
          </InfoRow>
          <InfoRow label="الهاتف">
            <span className="flex items-center gap-2">
              <span dir="ltr">{booking.user?.phone}</span>
              <PhoneActions phone={booking.user?.phone} />
            </span>
          </InfoRow>
        </DetailCard>
      )}

      {payment.method === "MANUAL" && <PaymentInstructions />}

      <DetailCard title="مراجعة الدفعة">
        <div className="space-y-4">
          <div>
            <Label htmlFor="transactionRef">رقم العملية / المرجع</Label>
            <Input
              id="transactionRef"
              dir="ltr"
              value={transactionRef}
              onChange={(e) => setTransactionRef(e.target.value)}
              placeholder="اختياري — من إشعار التحويل"
            />
          </div>
          <div>
            <Label htmlFor="adminNote">ملاحظة الفريق</Label>
            <Textarea
              id="adminNote"
              value={adminNote}
              onChange={(e) => setAdminNote(e.target.value)}
              placeholder="مطلوبة عند الرفض أو الاسترداد"
              rows={3}
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <Button disabled={busy || payment.status === "PAID"} onClick={() => review("PAID")}>
              تأكيد الدفع
            </Button>
            <Button variant="danger" disabled={busy || payment.status === "FAILED"} onClick={() => review("FAILED")}>
              رفض الدفعة
            </Button>
            {admin && payment.status === "PAID" && (
              <Button
                variant="ghost"
                disabled={busy}
                onClick={() => {
                  if (!adminNote.trim()) {
                    toast("أضف سبب الاسترداد في الملاحظة أولاً", "error");
                    return;
                  }
                  setRefundOpen(true);
                }}
              >
                استرداد المبلغ
              </Button>
            )}
          </div>
          {!admin && payment.status === "PAID" && (
            <p className="text-xs text-muted">الاسترداد متاح للمدير فقط.</p>
          )}
        </div>
      </DetailCard>

      <ImagePreview url={previewUrl} title="إثبات التحويل" onClose={() => setPreviewUrl(null)} />

      <ConfirmDialog
        open={refundOpen}
        title="استرداد الدفعة"
        message={`سيتم تعليم الدفعة كمستردة وإلغاء الحجز. المبلغ: ${formatMoney(payment.amount)}`}
        confirmLabel="نعم، استرد"
        danger
        onConfirm={refund}
        onClose={() => setRefundOpen(false)}
      />
    </PageShell>
  );
}
