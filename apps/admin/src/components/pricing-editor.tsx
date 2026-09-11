"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Alert } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Input, Label, Select } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { useToast } from "@/components/ui/toast";
import { api } from "@/lib/api";
import { localIsoDate, formatMoney } from "@/lib/dates";
import {
  BOOKING_MODE_LABELS,
  WEEKDAY_LABELS,
  type BookingMode,
  type PriceRule,
  type PriceRuleType,
  type PricingPreview,
  type PropertyType,
} from "@/lib/types";

const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

type RuleForm = {
  name: string;
  ruleType: PriceRuleType;
  daysOfWeek: number[];
  startDate: string;
  endDate: string;
  fullDayPrice: string;
  morningPrice: string;
  eveningPrice: string;
  morningStart: string;
  morningEnd: string;
  eveningStart: string;
  eveningEnd: string;
  priority: string;
  isActive: boolean;
};

const EMPTY_RULE: RuleForm = {
  name: "",
  ruleType: "WEEKDAY",
  daysOfWeek: [],
  startDate: "",
  endDate: "",
  fullDayPrice: "",
  morningPrice: "",
  eveningPrice: "",
  morningStart: "",
  morningEnd: "",
  eveningStart: "",
  eveningEnd: "",
  priority: "0",
  isActive: true,
};

type ShiftConfigForm = {
  bookingMode: BookingMode;
  morningStart: string;
  morningEnd: string;
  eveningStart: string;
  eveningEnd: string;
};

const MODE_BY_TYPE: Record<PropertyType, BookingMode> = {
  FARM: "HYBRID",
  HALL: "FULL_DAY",
  DECORATION: "FULL_DAY",
};

export function PricingEditor({
  propertyId,
  propertyType,
  initialRules,
  initialMode,
  initialTimes,
  onChange,
  apiBase = "/api/admin/properties",
}: {
  propertyId: string;
  propertyType: PropertyType;
  initialRules: PriceRule[];
  initialMode?: BookingMode | null;
  initialTimes?: { morningStart?: string | null; morningEnd?: string | null; eveningStart?: string | null; eveningEnd?: string | null };
  onChange?: (rules: PriceRule[]) => void;
  /** Swap to /api/provider/properties for the owner portal (ownership-scoped). */
  apiBase?: string;
}) {
  const { toast } = useToast();
  const [rules, setRules] = useState<PriceRule[]>(initialRules);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<RuleForm>(EMPTY_RULE);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const [shiftConfig, setShiftConfig] = useState<ShiftConfigForm>({
    bookingMode: initialMode ?? MODE_BY_TYPE[propertyType],
    morningStart: initialTimes?.morningStart || "08:00",
    morningEnd: initialTimes?.morningEnd || "14:00",
    eveningStart: initialTimes?.eveningStart || "16:00",
    eveningEnd: initialTimes?.eveningEnd || "22:00",
  });
  const [savingShiftConfig, setSavingShiftConfig] = useState(false);

  const [preview, setPreview] = useState<PricingPreview | null>(null);

  const loadRules = useCallback(async () => {
    const data = await api<PriceRule[]>(`${apiBase}/${propertyId}/pricing-rules`);
    setRules(data);
    onChange?.(data);
    return data;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [propertyId]);

  const loadPreview = useCallback(async () => {
    const from = localIsoDate(new Date());
    const to = new Date();
    to.setDate(to.getDate() + 34);
    const data = await api<PricingPreview>(
      `${apiBase}/${propertyId}/pricing-preview?from=${from}&to=${localIsoDate(to)}`,
    );
    setPreview(data);
  }, [propertyId]);

  useEffect(() => {
    loadPreview().catch(() => undefined);
  }, [loadPreview, rules]);

  function openCreate(type: PriceRuleType) {
    setEditingId(null);
    setForm({ ...EMPTY_RULE, ruleType: type });
    setModalOpen(true);
  }

  function openEdit(rule: PriceRule) {
    setEditingId(rule.id);
    setForm({
      name: rule.name,
      ruleType: rule.ruleType,
      daysOfWeek: rule.daysOfWeek,
      startDate: rule.startDate ? rule.startDate.slice(0, 10) : "",
      endDate: rule.endDate ? rule.endDate.slice(0, 10) : "",
      fullDayPrice: rule.fullDayPrice != null ? String(rule.fullDayPrice) : "",
      morningPrice: rule.morningPrice != null ? String(rule.morningPrice) : "",
      eveningPrice: rule.eveningPrice != null ? String(rule.eveningPrice) : "",
      morningStart: rule.morningStart ?? "",
      morningEnd: rule.morningEnd ?? "",
      eveningStart: rule.eveningStart ?? "",
      eveningEnd: rule.eveningEnd ?? "",
      priority: String(rule.priority ?? 0),
      isActive: rule.isActive,
    });
    setModalOpen(true);
  }

  function toggleDay(day: number) {
    setForm((f) => ({
      ...f,
      daysOfWeek: f.daysOfWeek.includes(day)
        ? f.daysOfWeek.filter((d) => d !== day)
        : [...f.daysOfWeek, day],
    }));
  }

  function validate(form: RuleForm): string | null {
    if (form.ruleType === "WEEKDAY" && !form.daysOfWeek.length) return "اختر يوماً واحداً على الأقل";
    if (form.ruleType === "DATE_RANGE") {
      if (!form.startDate || !form.endDate) return "حدد تاريخي البداية والنهاية";
      if (form.startDate > form.endDate) return "البداية بعد النهاية";
    }
    for (const key of ["fullDayPrice", "morningPrice", "eveningPrice"] as const) {
      if (form[key] && Number(form[key]) < 0) return "الأسعار لا يمكن أن تكون سالبة";
    }
    for (const key of ["morningStart", "morningEnd", "eveningStart", "eveningEnd"] as const) {
      if (form[key] && !TIME_PATTERN.test(form[key])) return "صيغة الوقت يجب أن تكون HH:mm";
    }
    return null;
  }

  async function saveRule(e: React.FormEvent) {
    e.preventDefault();
    const problem = validate(form);
    if (problem) {
      toast(problem, "error");
      return;
    }
    setSaving(true);
    try {
      const body = JSON.stringify({
        name: form.name.trim(),
        ruleType: form.ruleType,
        daysOfWeek: form.ruleType === "WEEKDAY" ? [...form.daysOfWeek].sort() : [],
        startDate: form.ruleType === "DATE_RANGE" ? form.startDate : undefined,
        endDate: form.ruleType === "DATE_RANGE" ? form.endDate : undefined,
        fullDayPrice: form.fullDayPrice ? Number(form.fullDayPrice) : undefined,
        morningPrice: form.morningPrice ? Number(form.morningPrice) : undefined,
        eveningPrice: form.eveningPrice ? Number(form.eveningPrice) : undefined,
        morningStart: form.morningStart || undefined,
        morningEnd: form.morningEnd || undefined,
        eveningStart: form.eveningStart || undefined,
        eveningEnd: form.eveningEnd || undefined,
        priority: Number(form.priority) || 0,
        isActive: form.isActive,
      });
      if (editingId) {
        await api(`${apiBase}/${propertyId}/pricing-rules/${editingId}`, { method: "PATCH", body });
        toast("تم تحديث القاعدة");
      } else {
        await api(`${apiBase}/${propertyId}/pricing-rules`, { method: "POST", body });
        toast("تمت إضافة القاعدة — استخدم المعاينة الحية للتأكد");
      }
      setModalOpen(false);
      await loadRules();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  async function toggleRule(rule: PriceRule) {
    try {
      await api(`${apiBase}/${propertyId}/pricing-rules/${rule.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: !rule.isActive }),
      });
      await loadRules();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function confirmDelete() {
    if (!deleteId) return;
    try {
      await api(`${apiBase}/${propertyId}/pricing-rules/${deleteId}`, { method: "DELETE" });
      toast("تم حذف القاعدة");
      setDeleteId(null);
      await loadRules();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
      setDeleteId(null);
    }
  }

  async function saveShiftConfig() {
    setSavingShiftConfig(true);
    try {
      await api(`${apiBase}/${propertyId}`, {
        method: "PATCH",
        body: JSON.stringify({
          bookingMode: shiftConfig.bookingMode,
          morningStart: shiftConfig.morningStart,
          morningEnd: shiftConfig.morningEnd,
          eveningStart: shiftConfig.eveningStart,
          eveningEnd: shiftConfig.eveningEnd,
        }),
      });
      toast("تم حفظ وضع الحجز وأوقات الشفتات");
      await loadPreview();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    } finally {
      setSavingShiftConfig(false);
    }
  }

  const weekdayRules = useMemo(() => rules.filter((r) => r.ruleType === "WEEKDAY"), [rules]);
  const seasonRules = useMemo(() => rules.filter((r) => r.ruleType === "DATE_RANGE"), [rules]);

  return (
    <div className="space-y-6">
      {/* Booking mode + custom shift times */}
      <section className="rounded-xl border border-line p-4">
        <h3 className="card-section-title">وضع الحجز وأوقات الشفتات</h3>
        <p className="mb-3 text-sm text-muted">
          أوقات مخصصة لهذا المكان وحده — قد تختلف عن باقي الأماكن (مثال: رمضان يبدأ المسائي 19:00)
        </p>
        <div className="grid gap-4 md:grid-cols-2">
          <div>
            <Label>طريقة الحجز المسموحة</Label>
            <Select
              value={shiftConfig.bookingMode}
              onChange={(e) => setShiftConfig((c) => ({ ...c, bookingMode: e.target.value as BookingMode }))}
            >
              {(Object.keys(BOOKING_MODE_LABELS) as BookingMode[]).map((mode) => (
                <option key={mode} value={mode}>{BOOKING_MODE_LABELS[mode]}</option>
              ))}
            </Select>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>الصباحي — من</Label>
              <Input type="time" value={shiftConfig.morningStart} onChange={(e) => setShiftConfig((c) => ({ ...c, morningStart: e.target.value }))} />
            </div>
            <div>
              <Label>إلى</Label>
              <Input type="time" value={shiftConfig.morningEnd} onChange={(e) => setShiftConfig((c) => ({ ...c, morningEnd: e.target.value }))} />
            </div>
            <div>
              <Label>المسائي — من</Label>
              <Input type="time" value={shiftConfig.eveningStart} onChange={(e) => setShiftConfig((c) => ({ ...c, eveningStart: e.target.value }))} />
            </div>
            <div>
              <Label>إلى</Label>
              <Input type="time" value={shiftConfig.eveningEnd} onChange={(e) => setShiftConfig((c) => ({ ...c, eveningEnd: e.target.value }))} />
            </div>
          </div>
        </div>
        <div className="mt-3 flex justify-end">
          <Button size="sm" onClick={saveShiftConfig} disabled={savingShiftConfig}>حفظ الأوقات</Button>
        </div>
      </section>

      {/* Rules */}
      <section className="rounded-xl border border-line p-4">
        <div className="section-header mb-1">
          <h3 className="card-section-title mb-0">قواعد الأسعار</h3>
          <div className="flex gap-2">
            <Button size="sm" variant="ghost" onClick={() => openCreate("WEEKDAY")}>+ مجموعة أيام</Button>
            <Button size="sm" variant="ghost" onClick={() => openCreate("DATE_RANGE")}>+ فترة/موسم</Button>
          </div>
        </div>
        <p className="mb-3 text-sm text-muted">
          «مجموعة أيام» تسعّر أيام أسبوع متكررة (مثال: الخميس والجمعة)، و«فترة» تسعّر موسماً محدداً (أعياد، رمضان).
          عند التقاطع تفوز الفترة الأعلى أولوية، والفترات تتفوق على الأسبوعية عند التساوي.
        </p>

        {!rules.length && (
          <Alert variant="info">
            لا قواعد بعد — الأسعار الافتراضية من تبويب «التفاصيل» تُطبق على كل الأيام. أضف قاعدة لتخصيص أيام أو مواسم بعينها.
          </Alert>
        )}

        <div className="space-y-3">
          {seasonRules.map((rule) => (
            <RuleRow key={rule.id} rule={rule} onEdit={openEdit} onToggle={toggleRule} onDelete={setDeleteId} />
          ))}
          {weekdayRules.map((rule) => (
            <RuleRow key={rule.id} rule={rule} onEdit={openEdit} onToggle={toggleRule} onDelete={setDeleteId} />
          ))}
        </div>
      </section>

      {/* Live preview */}
      <section className="rounded-xl border border-line p-4">
        <h3 className="card-section-title">معاينة حية (35 يوماً)</h3>
        <p className="mb-3 text-sm text-muted">سعر اليوم الكامل لكل يوم كما سيراه العميل — القواعد المطبقة محدّدة بإطار</p>
        {preview ? (
          <>
            <div className="grid grid-cols-7 gap-1.5 text-center">
              {WEEKDAY_LABELS.map((day) => (
                <div key={day} className="text-[10px] font-bold text-muted">{day}</div>
              ))}
              {preview.days.map((day) => {
                const hasRule = !!day.ruleId;
                const booked = day.bookedShifts.length > 0;
                return (
                  <div
                    key={day.date}
                    title={`${day.date} — ${day.ruleName ?? "السعر الافتراضي"}${day.times.eveningShiftStart !== preview.shiftTimes.eveningShiftStart ? ` · مسائي ${day.times.eveningShiftStart}` : ""}`}
                    className={`rounded-lg border p-1.5 text-center text-[11px] leading-tight ${
                      booked
                        ? "border-danger/30 bg-danger-soft text-danger"
                        : hasRule
                          ? "border-accent bg-accent-soft text-accent"
                          : "border-line text-muted"
                    }`}
                  >
                    <div className="font-bold">{Number(day.date.slice(8, 10))}</div>
                    <div className="mt-0.5 truncate" dir="ltr">{formatMoney(day.prices.full)}</div>
                  </div>
                );
              })}
            </div>
            <div className="mt-3 flex flex-wrap gap-3 text-[11px] text-muted">
              <span className="flex items-center gap-1.5"><span className="h-3 w-3 rounded border border-accent bg-accent-soft" /> بقاعدة سعر</span>
              <span className="flex items-center gap-1.5"><span className="h-3 w-3 rounded border border-line" /> السعر الافتراضي</span>
              <span className="flex items-center gap-1.5"><span className="h-3 w-3 rounded border border-danger/30 bg-danger-soft" /> محجوز</span>
              <span>وقت الشفت المسائي الحالي: {preview.shiftTimes.eveningShiftStart} – {preview.shiftTimes.eveningShiftEnd}</span>
            </div>
          </>
        ) : (
          <p className="text-sm text-muted">جاري تحميل المعاينة...</p>
        )}
      </section>

      {/* Rule editor modal */}
      <Modal
        open={modalOpen}
        title={editingId ? "تعديل القاعدة" : form.ruleType === "WEEKDAY" ? "قاعدة مجموعة أيام" : "قاعدة فترة/موسم"}
        onClose={() => setModalOpen(false)}
      >
        <form onSubmit={saveRule} className="space-y-4">
          <div>
            <Label>اسم وصفي (اختياري)</Label>
            <Input
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              placeholder={form.ruleType === "WEEKDAY" ? "مثال: أسعار نهاية الأسبوع" : "مثال: أسعار عيد الفطر"}
            />
          </div>

          {form.ruleType === "WEEKDAY" ? (
            <div>
              <Label>أيام الأسبوع</Label>
              <div className="flex flex-wrap gap-1.5">
                {WEEKDAY_LABELS.map((label, day) => (
                  <ToggleChip key={day} active={form.daysOfWeek.includes(day)} onClick={() => toggleDay(day)}>
                    {label}
                  </ToggleChip>
                ))}
              </div>
              <div className="mt-2 flex gap-2">
                <button type="button" className="text-xs font-semibold text-accent underline" onClick={() => setForm((f) => ({ ...f, daysOfWeek: [4, 5] }))}>
                  الخميس + الجمعة
                </button>
                <button type="button" className="text-xs font-semibold text-accent underline" onClick={() => setForm((f) => ({ ...f, daysOfWeek: [5, 6] }))}>
                  الجمعة + السبت
                </button>
                <button type="button" className="text-xs font-semibold text-muted underline" onClick={() => setForm((f) => ({ ...f, daysOfWeek: [0, 1, 2, 3, 4, 5, 6] }))}>
                  كل الأيام
                </button>
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>من تاريخ</Label>
                <Input type="date" value={form.startDate} onChange={(e) => setForm((f) => ({ ...f, startDate: e.target.value }))} />
              </div>
              <div>
                <Label>إلى تاريخ (شامل)</Label>
                <Input type="date" value={form.endDate} onChange={(e) => setForm((f) => ({ ...f, endDate: e.target.value }))} />
              </div>
            </div>
          )}

          <div className="grid grid-cols-3 gap-3">
            <div>
              <Label>اليوم الكامل</Label>
              <Input type="number" min={0} value={form.fullDayPrice} onChange={(e) => setForm((f) => ({ ...f, fullDayPrice: e.target.value }))} placeholder="افتراضي" />
            </div>
            <div>
              <Label>الصباحي</Label>
              <Input type="number" min={0} value={form.morningPrice} onChange={(e) => setForm((f) => ({ ...f, morningPrice: e.target.value }))} placeholder="افتراضي" />
            </div>
            <div>
              <Label>المسائي</Label>
              <Input type="number" min={0} value={form.eveningPrice} onChange={(e) => setForm((f) => ({ ...f, eveningPrice: e.target.value }))} placeholder="افتراضي" />
            </div>
          </div>
          <p className="text-[11px] text-muted">اترك سعراً فارغاً ليرث الافتراضي — الشفتات بدون سعر تحسب 50% من سعر يوم القاعدة.</p>

          <details className="rounded-lg border border-line p-3">
            <summary className="cursor-pointer text-sm font-semibold text-muted">أوقات شفت بديلة لهذه القاعدة (مثال رمضان)</summary>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <div>
                <Label>الصباحي من</Label>
                <Input type="time" value={form.morningStart} onChange={(e) => setForm((f) => ({ ...f, morningStart: e.target.value }))} />
              </div>
              <div>
                <Label>إلى</Label>
                <Input type="time" value={form.morningEnd} onChange={(e) => setForm((f) => ({ ...f, morningEnd: e.target.value }))} />
              </div>
              <div>
                <Label>المسائي من</Label>
                <Input type="time" value={form.eveningStart} onChange={(e) => setForm((f) => ({ ...f, eveningStart: e.target.value }))} />
              </div>
              <div>
                <Label>إلى</Label>
                <Input type="time" value={form.eveningEnd} onChange={(e) => setForm((f) => ({ ...f, eveningEnd: e.target.value }))} />
              </div>
            </div>
          </details>

          <div className="grid grid-cols-2 items-end gap-3">
            <div>
              <Label>الأولوية (الأعلى يفوز)</Label>
              <Input type="number" value={form.priority} onChange={(e) => setForm((f) => ({ ...f, priority: e.target.value }))} />
            </div>
            <label className="flex cursor-pointer items-center gap-2 text-sm text-ink">
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm((f) => ({ ...f, isActive: e.target.checked }))}
                className="h-4 w-4 accent-indigo-600"
              />
              مفعّلة
            </label>
          </div>

          <div className="flex justify-end gap-2 pt-1">
            <Button type="button" variant="ghost" onClick={() => setModalOpen(false)}>إلغاء</Button>
            <Button type="submit" disabled={saving}>{editingId ? "حفظ" : "إضافة القاعدة"}</Button>
          </div>
        </form>
      </Modal>

      <ConfirmDialog
        open={!!deleteId}
        title="حذف القاعدة"
        message="سيعود اليوم المتأثر بالقاعدة إلى السعر الافتراضي. متابعة؟"
        confirmLabel="حذف"
        danger
        onConfirm={confirmDelete}
        onClose={() => setDeleteId(null)}
      />
    </div>
  );
}

function RuleRow({
  rule,
  onEdit,
  onToggle,
  onDelete,
}: {
  rule: PriceRule;
  onEdit: (rule: PriceRule) => void;
  onToggle: (rule: PriceRule) => void;
  onDelete: (id: string) => void;
}) {
  const prices = [
    rule.fullDayPrice != null && `كامل ${formatMoney(rule.fullDayPrice)}`,
    rule.morningPrice != null && `صباحي ${formatMoney(rule.morningPrice)}`,
    rule.eveningPrice != null && `مسائي ${formatMoney(rule.eveningPrice)}`,
  ].filter(Boolean) as string[];

  return (
    <div className={`list-row ${rule.isActive ? "" : "opacity-55"}`}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Badge variant={rule.ruleType === "DATE_RANGE" ? "warning" : "default"}>
            {rule.ruleType === "DATE_RANGE" ? "فترة" : "أيام أسبوع"}
          </Badge>
          <span className="font-semibold text-ink">{rule.name || (rule.ruleType === "DATE_RANGE" ? "فترة بدون اسم" : "مجموعة أيام")}</span>
          {!rule.isActive && <Badge variant="muted">معطّلة</Badge>}
          {rule.priority > 0 && <Badge variant="muted">أولوية {rule.priority}</Badge>}
        </div>
        <div className="flex gap-2 text-xs font-semibold">
          <button type="button" className="text-accent underline" onClick={() => onEdit(rule)}>تعديل</button>
          <button type="button" className="text-muted underline" onClick={() => onToggle(rule)}>{rule.isActive ? "تعطيل" : "تفعيل"}</button>
          <button type="button" className="text-danger underline" onClick={() => onDelete(rule.id)}>حذف</button>
        </div>
      </div>
      <p className="mt-1.5 text-xs text-muted">
        {rule.ruleType === "DATE_RANGE"
          ? `${rule.startDate?.slice(0, 10)} → ${rule.endDate?.slice(0, 10)} (شاملة)`
          : rule.daysOfWeek.map((d) => WEEKDAY_LABELS[d]).join(" · ")}
        {prices.length > 0 && ` — ${prices.join(" · ")}`}
        {rule.eveningStart && ` — مسائي يبدأ ${rule.eveningStart}`}
      </p>
    </div>
  );
}
