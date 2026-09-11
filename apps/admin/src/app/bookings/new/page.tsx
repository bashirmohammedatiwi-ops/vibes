"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Alert } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Label, Select, Textarea } from "@/components/ui/input";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell, ContentPanel } from "@/components/page-shell";
import { normalizeIraqiPhone } from "@/components/phone-actions";
import { useToast } from "@/components/ui/toast";
import { FARM_SHIFTS, PROPERTY_TYPE_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { api } from "@/lib/api";
import { formatMoney } from "@/lib/dates";
import type { Paginated, Property } from "@/lib/types";

export default function NewBookingPage() {
  const router = useRouter();
  const { toast } = useToast();
  const [properties, setProperties] = useState<Property[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [propertyId, setPropertyId] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [shift, setShift] = useState("FULL");
  const [guests, setGuests] = useState("2");
  const [customerPhone, setCustomerPhone] = useState("");
  const [customerName, setCustomerName] = useState("");
  const [notes, setNotes] = useState("");
  const [confirmImmediately, setConfirmImmediately] = useState(true);
  const [couponCode, setCouponCode] = useState("");
  const [quote, setQuote] = useState<{
    available: boolean;
    totalPrice: number | string;
    originalTotal?: number | string;
    discount?: number | string;
    couponCode?: string | null;
    nights: number;
    capacity: number;
  } | null>(null);
  const [quoting, setQuoting] = useState(false);
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const phone = params.get("phone");
    const name = params.get("name");
    if (phone) setCustomerPhone(phone);
    if (name) setCustomerName(name);
  }, []);

  const selected = useMemo(() => properties.find((p) => p.id === propertyId), [properties, propertyId]);
  const usesShifts = selected?.type === "FARM";

  useEffect(() => {
    api<Paginated<Property>>("/api/admin/properties?status=APPROVED&pageSize=200")
      .then((res) => setProperties(res.items))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!propertyId || !startDate || !endDate) {
      setQuote(null);
      return;
    }
    setQuoting(true);
    const timer = setTimeout(() => {
      api<{ available: boolean; totalPrice: number | string; originalTotal?: number | string; discount?: number | string; couponCode?: string | null; nights: number; capacity: number }>("/api/admin/bookings/quote", {
        method: "POST",
        body: JSON.stringify({ propertyId, startDate, endDate, shift: usesShifts ? shift : "FULL", couponCode: couponCode.trim() || undefined }),
      })
        .then(setQuote)
        .catch(() => setQuote(null))
        .finally(() => setQuoting(false));
    }, 300);
    return () => clearTimeout(timer);
  }, [propertyId, startDate, endDate, shift, usesShifts, couponCode]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const phone = normalizeIraqiPhone(customerPhone.trim());
    if (phone.length < 12) {
      setError("أدخل رقم هاتف عراقي صحيح");
      return;
    }
    if (!propertyId || !startDate || !endDate) {
      setError("أكمل جميع الحقول المطلوبة");
      return;
    }

    if (quote && !quote.available) {
      setError("التواريخ المختارة غير متاحة");
      return;
    }

    setLoading(true);
    try {
      const booking = await api<{ id: string }>("/api/admin/bookings", {
        method: "POST",
        body: JSON.stringify({
          propertyId,
          startDate,
          endDate,
          shift: usesShifts ? shift : "FULL",
          guests: Number(guests) || 1,
          customerPhone: phone,
          customerName: customerName.trim() || undefined,
          notes: notes.trim() || undefined,
          couponCode: couponCode.trim() || undefined,
          confirmImmediately,
        }),
      });
      toast("تم إنشاء الحجز");
      router.push(`/bookings/${booking.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إنشاء الحجز");
    } finally {
      setLoading(false);
    }
  }

  return (
    <PageShell>
      <PageHeader
        title="حجز يدوي"
        description="إنشاء حجز للعميل عبر الهاتف أو الزيارة المباشرة"
        eyebrow="الحجوزات"
        action={
          <Link href="/bookings">
            <Button variant="ghost" size="sm">← الحجوزات</Button>
          </Link>
        }
      />

      <HelpTip>
        يُنشأ حساب للعميل تلقائياً إذا لم يكن مسجّلاً. فعّل «تأكيد فوري» للحجوزات المدفوعة نقداً أو بالتحويل.
      </HelpTip>

      {error && <Alert variant="danger">{error}</Alert>}

      <form onSubmit={submit}>
        <ContentPanel className="space-y-6 p-5 sm:p-6">
          <section className="grid gap-4 md:grid-cols-2">
            <div className="md:col-span-2">
              <Label htmlFor="property">المكان *</Label>
              <Select id="property" value={propertyId} onChange={(e) => setPropertyId(e.target.value)} required>
                <option value="">اختر مكاناً منشوراً...</option>
                {properties.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name} · {PROPERTY_TYPE_LABELS[p.type]} · {p.city?.nameAr}
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <Label htmlFor="start">تاريخ البداية *</Label>
              <Input id="start" type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} required />
            </div>
            <div>
              <Label htmlFor="end">تاريخ النهاية *</Label>
              <Input id="end" type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} required />
            </div>

            {usesShifts && (
              <div>
                <Label htmlFor="shift">الشفت</Label>
                <Select id="shift" value={shift} onChange={(e) => setShift(e.target.value)}>
                  {FARM_SHIFTS.map((s) => (
                    <option key={s} value={s}>{SHIFT_TYPE_LABELS[s]}</option>
                  ))}
                </Select>
              </div>
            )}

            <div>
              <Label htmlFor="guests">عدد الضيوف</Label>
              <Input id="guests" type="number" min={1} value={guests} onChange={(e) => setGuests(e.target.value)} />
            </div>

            <div>
              <Label htmlFor="coupon">رمز الخصم (اختياري)</Label>
              <Input
                id="coupon"
                dir="ltr"
                value={couponCode}
                onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                placeholder="SUMMER25"
              />
              {couponCode.trim() && quote && Number(quote.discount) > 0 && (
                <p className="mt-1 text-xs font-semibold text-success">✓ رمز صالح — خصم {formatMoney(quote.discount ?? 0)}</p>
              )}
              {couponCode.trim() && quote && Number(quote.discount ?? 0) === 0 && (
                <p className="mt-1 text-xs text-danger">الرمز غير مطبق — تحقق من صحته</p>
              )}
            </div>

            {selected && (
              <div className={`rounded-xl border px-4 py-3 text-sm md:col-span-2 ${quote && !quote.available ? "border-danger/30 bg-danger-soft" : "border-line bg-surface"}`}>
                <div className="font-bold">{selected.name}</div>
                <div className="mt-1 text-muted">
                  السعة: {selected.capacity} · {selected.city?.nameAr ?? "—"}
                </div>
                {quoting && <div className="mt-2 text-xs text-muted">جاري حساب السعر...</div>}
                {quote && (
                  <div className="mt-2 flex flex-wrap items-center gap-3">
                    {Number(quote.discount) > 0 && (
                      <>
                        <span className="text-muted line-through">{formatMoney(quote.originalTotal ?? 0)}</span>
                        <Badge variant="success">خصم {formatMoney(quote.discount ?? 0)}</Badge>
                      </>
                    )}
                    <span className="font-bold">{formatMoney(quote.totalPrice)}</span>
                    <span className="text-muted">{quote.nights} ليلة</span>
                    <Badge variant={quote.available ? "success" : "danger"}>{quote.available ? "متاح" : "غير متاح"}</Badge>
                    {Number(guests) > quote.capacity && (
                      <span className="text-xs text-danger">عدد الضيوف يتجاوز السعة ({quote.capacity})</span>
                    )}
                  </div>
                )}
              </div>
            )}
          </section>

          <section className="grid gap-4 border-t border-line pt-6 md:grid-cols-2">
            <div>
              <Label htmlFor="phone">هاتف العميل *</Label>
              <Input
                id="phone"
                dir="ltr"
                placeholder="07XXXXXXXX"
                value={customerPhone}
                onChange={(e) => setCustomerPhone(e.target.value)}
                required
              />
            </div>
            <div>
              <Label htmlFor="name">اسم العميل</Label>
              <Input id="name" value={customerName} onChange={(e) => setCustomerName(e.target.value)} placeholder="اختياري" />
            </div>
            <div className="md:col-span-2">
              <Label htmlFor="notes">ملاحظات</Label>
              <Textarea id="notes" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="ملاحظات للفريق..." />
            </div>
            <label className="flex cursor-pointer items-center gap-3 rounded-xl border border-line bg-surface px-4 py-3 text-sm md:col-span-2">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-line accent-brand"
                checked={confirmImmediately}
                onChange={(e) => setConfirmImmediately(e.target.checked)}
              />
              <span>
                <strong>تأكيد فوري</strong> — يُسجّل الحجز مؤكداً والدفع مدفوع (للطلبات الهاتفية المدفوعة)
              </span>
            </label>
          </section>

          <div className="flex flex-wrap gap-3 border-t border-line pt-4">
            <Button type="submit" disabled={loading}>
              {loading ? "جاري الإنشاء..." : "إنشاء الحجز"}
            </Button>
            <Link href="/bookings">
              <Button type="button" variant="ghost">إلغاء</Button>
            </Link>
          </div>
        </ContentPanel>
      </form>
    </PageShell>
  );
}
