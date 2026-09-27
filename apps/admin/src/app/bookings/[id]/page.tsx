"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DetailCard, InfoRow } from "@/components/ui/detail-card";
import { ErrorBanner } from "@/components/ui/error-banner";
import { Input, Label, Select, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { HelpTip } from "@/components/help-tip";
import { ImagePreview } from "@/components/image-preview";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PhoneActions } from "@/components/phone-actions";
import { PaymentInstructions } from "@/components/payment-instructions";
import { SimpleUpload } from "@/components/simple-upload";
import { useToast } from "@/components/ui/toast";
import { BOOKING_ORIGIN_LABELS, BOOKING_STATUS_LABELS, PAYMENT_METHOD_LABELS, PAYMENT_STATUS_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { api, uploadFiles } from "@/lib/api";
import { formatDayAr } from "@/lib/dates";
import type { Booking, BookingNote } from "@/lib/types";

export default function BookingDetailPage() {
  const params = useParams<{ id: string }>();
  const { toast } = useToast();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [notes, setNotes] = useState<BookingNote[]>([]);
  const [noteText, setNoteText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [disputeOpen, setDisputeOpen] = useState(false);
  const [disputeReason, setDisputeReason] = useState("");
  const [disputeNote, setDisputeNote] = useState("");
  const [statusNote, setStatusNote] = useState("");
  const [uploadingProof, setUploadingProof] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [resolveNote, setResolveNote] = useState("");
  const [rescheduleOpen, setRescheduleOpen] = useState(false);
  const [resStart, setResStart] = useState("");
  const [resEnd, setResEnd] = useState("");
  const [resShift, setResShift] = useState("FULL");
  const [resNote, setResNote] = useState("");
  const [editNoteId, setEditNoteId] = useState<string | null>(null);
  const [editNoteText, setEditNoteText] = useState("");
  const [deleteNoteId, setDeleteNoteId] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [data, noteList] = await Promise.all([
      api<Booking>(`/api/admin/bookings/${params.id}`),
      api<BookingNote[]>(`/api/admin/bookings/${params.id}/notes`),
    ]);
    setBooking(data);
    setNotes(noteList);
  }, [params.id]);

  useEffect(() => {
    load()
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, [load]);

  async function updateStatus(status: string) {
    try {
      await api(`/api/admin/bookings/${params.id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ status, adminNote: statusNote || undefined }),
      });
      toast(`تم تحديث الحالة إلى ${BOOKING_STATUS_LABELS[status] ?? status}`);
      setStatusNote("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function addNote() {
    if (!noteText.trim()) return;
    try {
      await api(`/api/admin/bookings/${params.id}/notes`, {
        method: "POST",
        body: JSON.stringify({ content: noteText, isInternal: true }),
      });
      setNoteText("");
      toast("تمت إضافة الملاحظة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإضافة", "error");
    }
  }

  async function saveNoteEdit() {
    if (!editNoteId || !editNoteText.trim()) return;
    try {
      await api(`/api/admin/bookings/${params.id}/notes/${editNoteId}`, {
        method: "PATCH",
        body: JSON.stringify({ content: editNoteText.trim() }),
      });
      setEditNoteId(null);
      setEditNoteText("");
      toast("تم تعديل الملاحظة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التعديل", "error");
    }
  }

  async function deleteNote() {
    if (!deleteNoteId) return;
    try {
      await api(`/api/admin/bookings/${params.id}/notes/${deleteNoteId}`, { method: "DELETE" });
      setDeleteNoteId(null);
      toast("تم حذف الملاحظة");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
    }
  }

  async function submitDispute() {
    if (!disputeReason.trim()) return;
    try {
      await api(`/api/admin/bookings/${params.id}/dispute`, {
        method: "POST",
        body: JSON.stringify({ reason: disputeReason, note: disputeNote || undefined }),
      });
      setDisputeOpen(false);
      setDisputeReason("");
      setDisputeNote("");
      toast("تم فتح النزاع");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر فتح النزاع", "error");
    }
  }

  async function resolveDispute(status: string) {
    try {
      await api(`/api/admin/bookings/${params.id}/dispute/resolve`, {
        method: "POST",
        body: JSON.stringify({ status, note: resolveNote || undefined }),
      });
      toast(`تم حل النزاع — ${BOOKING_STATUS_LABELS[status] ?? status}`);
      setResolveNote("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر حل النزاع", "error");
    }
  }

  async function uploadProof(files: FileList | null) {
    if (!files?.length) return;
    setUploadingProof(true);
    try {
      await uploadFiles(`/api/admin/bookings/${params.id}/payment/proof`, "file", [files[0]]);
      toast("تم رفع إثبات الدفع");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "فشل الرفع", "error");
    } finally {
      setUploadingProof(false);
    }
  }

  async function reschedule() {
    if (!resStart || !resEnd) return;
    try {
      await api(`/api/admin/bookings/${params.id}/dates`, {
        method: "PATCH",
        body: JSON.stringify({
          startDate: resStart,
          endDate: resEnd,
          shift: resShift,
          adminNote: resNote.trim() || undefined,
        }),
      });
      toast("تمت إعادة الجدولة");
      setRescheduleOpen(false);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر إعادة الجدولة", "error");
    }
  }

  async function confirmPayment() {
    if (!booking?.payment?.id) return;
    try {
      await api(`/api/admin/payments/${booking.payment.id}/review`, {
        method: "PATCH",
        body: JSON.stringify({ status: "PAID" }),
      });
      toast("تم تأكيد الدفع — الحجز مؤكد");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر تأكيد الدفع", "error");
    }
  }

  if (error) {
    return (
      <ErrorBanner
        message={error}
        onRetry={() => { setError(null); setLoading(true); load().catch((err: Error) => setError(err.message)).finally(() => setLoading(false)); }}
        backHref="/bookings"
        backLabel="العودة للحجوزات"
      />
    );
  }
  if (loading || !booking) return <LoadingBlock />;

  const statusVariant =
    booking.status === "DISPUTED" ? "danger" : booking.status === "CONFIRMED" || booking.status === "COMPLETED" ? "success" : booking.status === "CANCELLED" ? "muted" : "warning";

  return (
    <PageShell className="page-shell-narrow">
      <PageHeader
        title={booking.property?.name ?? "حجز"}
        description={`${formatDayAr(booking.startDate)} → ${formatDayAr(booking.endDate)} · ${booking.guests} ضيف${booking.shift && booking.shift !== "FULL" ? ` · ${SHIFT_TYPE_LABELS[booking.shift]}` : ""}`}
        eyebrow="VIBES Admin"
        back={{ href: "/bookings", label: "العودة للحجوزات" }}
        action={
          <span className="flex flex-wrap items-center gap-2">
            {booking.origin === "EXTERNAL" && <Badge variant="muted">{BOOKING_ORIGIN_LABELS.EXTERNAL}</Badge>}
            <Badge variant={statusVariant}>{BOOKING_STATUS_LABELS[booking.status] ?? booking.status}</Badge>
          </span>
        }
      />

      {booking.status === "DISPUTED" && (booking.disputeReason || booking.disputeNote) && (
        <DetailCard title="تفاصيل النزاع" className="border-danger/20 bg-danger-soft">
          {booking.disputeReason && <p className="text-sm text-danger"><strong>السبب:</strong> {booking.disputeReason}</p>}
          {booking.disputeNote && <p className="mt-1 text-sm text-danger"><strong>ملاحظة:</strong> {booking.disputeNote}</p>}
        </DetailCard>
      )}

      {booking.status === "PENDING" && (
        <HelpTip>الخطوة التالية: راجع التفاصيل ثم اضغط «تأكيد الحجز» أو ألغِ إذا لزم.</HelpTip>
      )}
      {booking.status === "AWAITING_PAYMENT" && (
        <HelpTip variant="warning">بانتظار إثبات التحويل — ارفعه أدناه أو أكّد الدفع بعد المراجعة.</HelpTip>
      )}
      {booking.status === "DISPUTED" && (
        <HelpTip variant="warning">هذا الحجز في نزاع — اختر تأكيد أو إلغاء لحله.</HelpTip>
      )}

      <DetailCard title="تفاصيل الحجز">
        <InfoRow label="المصدر" value={BOOKING_ORIGIN_LABELS[booking.origin ?? "PLATFORM"] ?? booking.origin ?? "تطبيق VIBES"} />
        <InfoRow label="العميل">
          {booking.user?.id ? (
            <Link href={`/users/${booking.user.id}`} className="text-accent underline">{booking.user?.name ?? booking.user?.phone ?? booking.guestName}</Link>
          ) : (
            <span>{booking.guestName ?? booking.user?.name ?? "ضيف خارجي"}</span>
          )}
        </InfoRow>
        <InfoRow label="الهاتف">
          <span className="flex items-center gap-2">
            <span dir="ltr">{booking.user?.phone ?? booking.guestPhone}</span>
            <PhoneActions phone={booking.user?.phone ?? booking.guestPhone} />
          </span>
        </InfoRow>
        <InfoRow label="التواريخ" value={`${formatDayAr(booking.startDate)} → ${formatDayAr(booking.endDate)}${booking.shift && booking.shift !== "FULL" ? ` · ${SHIFT_TYPE_LABELS[booking.shift]}` : ""}`} />
        <InfoRow label="عدد الضيوف" value={booking.guests} />
        <InfoRow
          label="المبلغ"
          value={
            Number(booking.discountAmount) > 0 ? (
              <span className="flex flex-wrap items-center gap-2">
                <span className="text-muted line-through">{Number(booking.totalPrice).toLocaleString("ar-IQ") + Number(booking.discountAmount).toLocaleString("ar-IQ")} د.ع</span>
                <span className="font-bold text-success">خصم {Number(booking.discountAmount).toLocaleString("ar-IQ")} د.ع</span>
                <span className="font-bold">{Number(booking.totalPrice).toLocaleString("ar-IQ")} د.ع</span>
              </span>
            ) : (
              `${Number(booking.totalPrice).toLocaleString("ar-IQ")} د.ع`
            )
          }
        />
        {booking.payment?.id && (
          <InfoRow label="الدفعة">
            <Link href={`/payments?q=${booking.user?.phone ?? ""}`} className="text-accent underline">مراجعة في المدفوعات</Link>
          </InfoRow>
        )}
        <InfoRow label="التشغيل">
          <span className="flex flex-wrap gap-3">
            <Link href={`/conversations?q=${encodeURIComponent(booking.user?.phone ?? "")}`} className="text-accent underline">المحادثات</Link>
            <Link href={`/invoices?q=${encodeURIComponent(booking.user?.phone ?? "")}`} className="text-accent underline">الفواتير</Link>
            <Link href={`/refunds?q=${encodeURIComponent(booking.user?.phone ?? "")}`} className="text-accent underline">الاسترداد</Link>
            <Link href="/offers" className="text-accent underline">العروض</Link>
          </span>
        </InfoRow>
        {booking.notes && (
          <div className="pt-3">
            <div className="text-sm text-muted">ملاحظات العميل</div>
            <p className="mt-1 text-sm leading-7">{booking.notes}</p>
          </div>
        )}
        <Button
          variant="ghost"
          size="sm"
          className="mt-3 px-0"
          onClick={async () => {
            const text = [
              booking.property?.name,
              booking.user?.name ?? booking.user?.phone,
              booking.user?.phone,
              `${formatDayAr(booking.startDate)} → ${formatDayAr(booking.endDate)}`,
              `${booking.guests} ضيف`,
              `${Number(booking.totalPrice).toLocaleString("ar-IQ")} د.ع`,
              BOOKING_STATUS_LABELS[booking.status] ?? booking.status,
            ].filter(Boolean).join("\n");
            await navigator.clipboard.writeText(text);
            toast("تم نسخ ملخص الحجز");
          }}
        >
          نسخ ملخص الحجز
        </Button>
      </DetailCard>

      {booking.payment?.status === "PENDING" && <PaymentInstructions />}

      {booking.payment && (
        <DetailCard title="الدفع">
          <InfoRow label="الحالة" value={PAYMENT_STATUS_LABELS[booking.payment.status] ?? booking.payment.status} />
          <InfoRow label="طريقة الدفع" value={PAYMENT_METHOD_LABELS[booking.payment.method] ?? booking.payment.method} />
          {booking.payment.proofUrl && (
            <Button variant="ghost" size="sm" className="mt-2 px-0 text-accent underline" onClick={() => setPreviewUrl(booking.payment!.proofUrl!)}>
              معاينة إثبات الدفع
            </Button>
          )}
          {booking.payment.status === "PENDING" && (
            <div className="mt-4">
              {!booking.payment.proofUrl ? (
                <SimpleUpload
                  onFiles={(files) => uploadProof(files)}
                  accept="image/*,.pdf"
                  uploading={uploadingProof}
                  label="ارفع إثبات الدفع هنا"
                  hint="صورة التحويل أو PDF"
                />
              ) : (
                <div className="mt-3 flex flex-wrap gap-2">
                  <Button onClick={confirmPayment}>تأكيد الدفع والحجز</Button>
                  <Link href="/payments?pending=1">
                    <Button variant="ghost">كل الإثباتات</Button>
                  </Link>
                </div>
              )}
            </div>
          )}
        </DetailCard>
      )}

      <ImagePreview url={previewUrl} title="إثبات الدفع" onClose={() => setPreviewUrl(null)} />

      <DetailCard title="سجل الفريق">
        <div className="mb-4 space-y-2">
          {notes.map((n) => (
            <div key={n.id} className="rounded-xl border border-line bg-surface px-3 py-2.5 text-sm">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="text-xs text-muted">
                  {n.author?.name ?? n.author?.phone} · {new Date(n.createdAt).toLocaleString("ar-IQ")}
                </span>
                {editNoteId !== n.id && (
                  <span className="flex gap-2">
                    <button
                      type="button"
                      className="text-xs font-semibold text-accent underline"
                      onClick={() => { setEditNoteId(n.id); setEditNoteText(n.content); }}
                    >
                      تعديل
                    </button>
                    <button
                      type="button"
                      className="text-xs font-semibold text-danger underline"
                      onClick={() => setDeleteNoteId(n.id)}
                    >
                      حذف
                    </button>
                  </span>
                )}
              </div>
              {editNoteId === n.id ? (
                <div className="mt-2 space-y-2">
                  <Textarea value={editNoteText} onChange={(e) => setEditNoteText(e.target.value)} rows={3} />
                  <div className="flex gap-2">
                    <Button className="px-2 py-1 text-xs" onClick={saveNoteEdit}>حفظ</Button>
                    <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setEditNoteId(null)}>إلغاء</Button>
                  </div>
                </div>
              ) : (
                <p className="mt-1 leading-6">{n.content}</p>
              )}
            </div>
          ))}
          {!notes.length && <p className="text-sm text-muted">لا توجد ملاحظات</p>}
        </div>
        <Textarea value={noteText} onChange={(e) => setNoteText(e.target.value)} placeholder="أضف ملاحظة للفريق..." />
        <Button className="mt-2" onClick={addNote}>إضافة ملاحظة</Button>
      </DetailCard>

      <div className="mobile-action-dock">
      <DetailCard title="ماذا تريد أن تفعل؟">
        <p className="mb-3 text-sm text-muted">اختر الإجراء المناسب لهذا الحجز</p>
        <Input className="mb-3" placeholder="ملاحظة اختيارية مع تغيير الحالة..." value={statusNote} onChange={(e) => setStatusNote(e.target.value)} />
        <div className="flex flex-wrap gap-2">
          {booking.status === "PENDING" && (
            <>
              <Button onClick={() => updateStatus("CONFIRMED")}>تأكيد الحجز</Button>
              <Button variant="ghost" onClick={() => updateStatus("AWAITING_PAYMENT")}>انتظار الدفع</Button>
              <Button variant="danger" onClick={() => setCancelOpen(true)}>إلغاء الحجز</Button>
            </>
          )}
          {booking.status === "AWAITING_PAYMENT" && (
            <>
              <Button onClick={() => updateStatus("CONFIRMED")}>تأكيد بعد استلام الدفع</Button>
              <Button variant="danger" onClick={() => setCancelOpen(true)}>إلغاء الحجز</Button>
            </>
          )}
          {booking.status === "CONFIRMED" && <Button onClick={() => updateStatus("COMPLETED")}>تمت الزيارة — إغلاق الحجز</Button>}
          {booking.status === "DISPUTED" && (
            <>
              <Input className="mb-2 w-full" placeholder="ملاحظة حل النزاع (اختياري)..." value={resolveNote} onChange={(e) => setResolveNote(e.target.value)} />
              <div className="flex flex-wrap gap-2">
                <Button onClick={() => resolveDispute("CONFIRMED")}>حل النزاع — تأكيد</Button>
                <Button onClick={() => resolveDispute("COMPLETED")}>حل النزاع — إكمال</Button>
                <Button variant="danger" onClick={() => resolveDispute("CANCELLED")}>حل النزاع — إلغاء</Button>
              </div>
            </>
          )}
          {booking.status !== "DISPUTED" && booking.status !== "CANCELLED" && (
            <Button variant="ghost" onClick={() => setDisputeOpen(true)}>فتح نزاع</Button>
          )}
          {booking.property?.id && (
            <Link href={`/properties/${booking.property.id}/edit`}>
              <Button variant="ghost">عرض المكان</Button>
            </Link>
          )}
          {!["CANCELLED", "COMPLETED"].includes(booking.status) && (
            <Button
              variant="ghost"
              onClick={() => {
                setResStart(booking.startDate.slice(0, 10));
                setResEnd(booking.endDate.slice(0, 10));
                setResShift(booking.shift ?? "FULL");
                setRescheduleOpen(true);
              }}
            >
              إعادة جدولة
            </Button>
          )}
        </div>
      </DetailCard>
      </div>

      <ConfirmDialog
        open={!!deleteNoteId}
        title="حذف الملاحظة"
        message="حذف هذه الملاحظة من سجل الفريق؟"
        confirmLabel="حذف"
        danger
        onConfirm={deleteNote}
        onClose={() => setDeleteNoteId(null)}
      />

      <ConfirmDialog
        open={cancelOpen}
        title="إلغاء الحجز"
        message="إلغاء هذا الحجز؟ سيظهر للعميل كملغى. الإلغاء لا يسترد المبلغ تلقائياً — سجّل الاسترداد من صفحة الدفعات إن لزم."
        confirmLabel="نعم، ألغِ"
        danger
        onConfirm={async () => {
          await updateStatus("CANCELLED");
          setCancelOpen(false);
        }}
        onClose={() => setCancelOpen(false)}
      />

      <Modal open={rescheduleOpen} title="إعادة جدولة الحجز" onClose={() => setRescheduleOpen(false)}>
        <div className="space-y-3">
          <div>
            <Label htmlFor="resStart">تاريخ البداية</Label>
            <Input id="resStart" type="date" value={resStart} onChange={(e) => setResStart(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="resEnd">تاريخ النهاية</Label>
            <Input id="resEnd" type="date" value={resEnd} onChange={(e) => setResEnd(e.target.value)} />
          </div>
          {booking.property?.type === "FARM" && (
            <div>
              <Label htmlFor="resShift">الشفت</Label>
              <Select id="resShift" value={resShift} onChange={(e) => setResShift(e.target.value)}>
                {Object.entries(SHIFT_TYPE_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>{v}</option>
                ))}
              </Select>
            </div>
          )}
          <Textarea placeholder="ملاحظة للفريق..." value={resNote} onChange={(e) => setResNote(e.target.value)} />
          <div className="flex gap-2">
            <Button onClick={reschedule}>حفظ التواريخ</Button>
            <Button variant="ghost" onClick={() => setRescheduleOpen(false)}>إلغاء</Button>
          </div>
        </div>
      </Modal>

      <Modal open={disputeOpen} title="فتح نزاع" onClose={() => setDisputeOpen(false)}>
        <div className="space-y-3">
          <div>
            <Label htmlFor="disputeReason">سبب النزاع *</Label>
            <Input id="disputeReason" value={disputeReason} onChange={(e) => setDisputeReason(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="disputeNote">ملاحظة إضافية</Label>
            <Textarea id="disputeNote" value={disputeNote} onChange={(e) => setDisputeNote(e.target.value)} />
          </div>
          <div className="flex gap-2">
            <Button onClick={submitDispute}>فتح النزاع</Button>
            <Button variant="ghost" onClick={() => setDisputeOpen(false)}>إلغاء</Button>
          </div>
        </div>
      </Modal>
    </PageShell>
  );
}
