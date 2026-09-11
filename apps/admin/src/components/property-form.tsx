"use client";

import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Alert } from "@/components/ui/alert";
import { DetailCard } from "@/components/ui/detail-card";
import { ToggleChip } from "@/components/ui/toggle-chip";
import { Input, Label, Select, Textarea } from "@/components/ui/input";
import { PROPERTY_STATUS_LABELS, PROPERTY_TYPE_LABELS } from "@/lib/constants";
import { api } from "@/lib/api";
import { MapPicker } from "@/components/map-picker";
import { AmenityPicker } from "@/components/amenity-picker";
import { normalizeIraqiPhone } from "@/components/phone-actions";
import type { Property, PropertyFormData, PropertyStatus, PropertyType, Province } from "@/lib/types";

const PROVINCE_CENTER: Record<string, [string, string]> = {
  بغداد: ["33.3152", "44.3661"],
  البصرة: ["30.5081", "47.7835"],
  أربيل: ["36.1911", "44.0092"],
  الموصل: ["36.3489", "43.1577"],
  النجف: ["32.0280", "44.3326"],
  كربلاء: ["32.6160", "44.0249"],
  السليمانية: ["35.5610", "45.4306"],
  كركوك: ["35.4681", "44.3922"],
  الأنبار: ["33.4206", "43.3078"],
  ديالى: ["33.7463", "44.6223"],
  واسط: ["32.5147", "45.8190"],
  ميسان: ["31.8356", "47.1448"],
  ذي_قار: ["31.0575", "46.2573"],
  القادسية: ["31.9892", "44.9249"],
  المثنى: ["31.3092", "45.2806"],
  بابل: ["32.4681", "44.4247"],
  صلاح_الدين: ["34.5990", "43.6780"],
  دهوك: ["36.8671", "42.9884"],
  حلبجة: ["35.1778", "45.9861"],
};

function provinceCenter(name?: string): [string, string] {
  if (!name) return ["33.3152", "44.3661"];
  const key = name.replace(/\s+/g, "_");
  return PROVINCE_CENTER[name] ?? PROVINCE_CENTER[key] ?? ["33.3152", "44.3661"];
}

const emptyForm = (): PropertyFormData => ({
  type: "FARM",
  name: "",
  slug: "",
  description: "",
  cityId: "",
  address: "",
  latitude: "33.3152",
  longitude: "44.3661",
  capacity: "50",
  pricePerDay: "",
  weekendPrice: "",
  priceMorningShift: "",
  priceEveningShift: "",
  phone: "",
  whatsapp: "",
  featured: false,
  status: "DRAFT",
  amenityIds: [],
  tags: "",
  rules: "",
  internalNotes: "",
  nameEn: "",
  descriptionEn: "",
  metaTitle: "",
  metaDescription: "",
  providerId: "",
});

function fromProperty(p: Property): PropertyFormData {
  return {
    type: p.type,
    name: p.name,
    slug: p.slug ?? "",
    description: p.description ?? "",
    cityId: p.cityId,
    address: p.address ?? "",
    latitude: String(p.latitude),
    longitude: String(p.longitude),
    capacity: String(p.capacity),
    pricePerDay: String(p.pricePerDay),
    weekendPrice: p.weekendPrice != null ? String(p.weekendPrice) : "",
    priceMorningShift: p.priceMorningShift != null ? String(p.priceMorningShift) : "",
    priceEveningShift: p.priceEveningShift != null ? String(p.priceEveningShift) : "",
    phone: p.phone ?? "",
    whatsapp: p.whatsapp ?? "",
    featured: p.featured,
    status: p.status,
    amenityIds: (p.amenityLinks ?? []).map((link) => link.amenityId),
    tags: (p.tags ?? []).join("، "),
    rules: p.rules ?? "",
    internalNotes: p.internalNotes ?? "",
    nameEn: p.nameEn ?? "",
    descriptionEn: p.descriptionEn ?? "",
    metaTitle: p.metaTitle ?? "",
    metaDescription: p.metaDescription ?? "",
    providerId: p.providerId ?? "",
  };
}

function splitList(value: string) {
  return value.split(/[,،]/).map((s) => s.trim()).filter(Boolean);
}

function toPayload(form: PropertyFormData, isEdit: boolean) {
  return {
    type: form.type,
    name: form.name.trim(),
    slug: isEdit && form.slug.trim() ? form.slug.trim() : undefined,
    description: form.description.trim(),
    cityId: form.cityId,
    address: form.address.trim() || undefined,
    latitude: Number(form.latitude),
    longitude: Number(form.longitude),
    capacity: Number(form.capacity) || 0,
    pricePerDay: Number(form.pricePerDay),
    weekendPrice: form.weekendPrice ? Number(form.weekendPrice) : undefined,
    priceMorningShift: form.priceMorningShift ? Number(form.priceMorningShift) : undefined,
    priceEveningShift: form.priceEveningShift ? Number(form.priceEveningShift) : undefined,
    phone: form.phone.trim() || undefined,
    whatsapp: form.whatsapp.trim() || undefined,
    featured: form.featured,
    status: isEdit ? form.status : "DRAFT",
    amenityIds: form.amenityIds,
    tags: splitList(form.tags),
    rules: form.rules.trim() || undefined,
    internalNotes: form.internalNotes.trim() || undefined,
    nameEn: form.nameEn.trim() || undefined,
    descriptionEn: form.descriptionEn.trim() || undefined,
    metaTitle: form.metaTitle.trim() || undefined,
    metaDescription: form.metaDescription.trim() || undefined,
    providerId: form.providerId || undefined,
  };
}

type Props = {
  initial?: Property;
  onSaved: (property: Property) => void;
  submitLabel?: string;
};

export function PropertyForm({ initial, onSaved, submitLabel = "حفظ" }: Props) {
  const isEdit = !!initial;
  const [form, setForm] = useState<PropertyFormData>(initial ? fromProperty(initial) : emptyForm());
  const [provinces, setProvinces] = useState<Province[]>([]);
  const [providers, setProviders] = useState<Array<{
    id: string;
    businessName?: string;
    verified?: boolean;
    kycStatus?: string;
    user?: { name?: string; phone: string };
  }>>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showMore, setShowMore] = useState(false);
  const snapshot = useMemo(() => JSON.stringify(initial ? fromProperty(initial) : emptyForm()), [initial]);
  const dirty = JSON.stringify(form) !== snapshot;
  useEffect(() => {
    api<Province[]>("/api/provinces").then(setProvinces).catch(() => undefined);
    api<Array<{
      id: string;
      businessName?: string;
      verified?: boolean;
      kycStatus?: string;
      user?: { name?: string; phone: string };
    }>>("/api/providers")
      .then((list) =>
        setProviders(
          list.filter(
            (p) => p.verified || p.kycStatus === "VERIFIED" || p.id === initial?.providerId,
          ),
        ),
      )
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    if (initial) setForm(fromProperty(initial));
  }, [initial]);

  useEffect(() => {
    function onBeforeUnload(e: BeforeUnloadEvent) {
      if (!dirty) return;
      e.preventDefault();
      e.returnValue = "";
    }
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirty]);

  function update<K extends keyof PropertyFormData>(key: K, value: PropertyFormData[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!form.name.trim() || !form.cityId || !form.pricePerDay) {
      setError("أكمل الاسم والمدينة والسعر قبل الحفظ");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const payload = toPayload(form, isEdit);
      const result = initial
        ? await api<Property>(`/api/admin/properties/${initial.id}`, { method: "PATCH", body: JSON.stringify(payload) })
        : await api<Property>("/api/admin/properties", { method: "POST", body: JSON.stringify(payload) });
      onSaved(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر الحفظ");
    } finally {
      setLoading(false);
    }
  }

  const cities = provinces.flatMap((p) => p.cities.map((c) => ({ ...c, provinceName: p.nameAr })));

  const requiredFilled = [form.name.trim(), form.cityId, form.pricePerDay].filter(Boolean).length;
  const progressPct = Math.round((requiredFilled / 3) * 100);

  return (
    <form onSubmit={onSubmit} className="space-y-6">
      {!isEdit && (
        <div>
          <div className="mb-2 flex items-center justify-between text-xs font-semibold">
            <span className="text-muted">اكتمال البيانات الأساسية</span>
            <span className={progressPct === 100 ? "text-success" : "text-accent"}>{progressPct}%</span>
          </div>
          <div className="form-progress">
            <div className="form-progress-bar" style={{ width: `${progressPct}%` }} />
          </div>
        </div>
      )}

      {error && <Alert variant="danger">{error}</Alert>}

      {!isEdit && (
        <Alert variant="info">املأ الحقول المطلوبة ثم احفظ — بعدها سترفع الصور وتنشر المكان.</Alert>
      )}

      <DetailCard title="المعلومات الأساسية">
      <section className="grid gap-4 md:grid-cols-2">
        <div className="md:col-span-2">
          <Label htmlFor="name">اسم المكان *</Label>
          <Input id="name" value={form.name} onChange={(e) => update("name", e.target.value)} required placeholder="مثال: مزرعة النخيل" />
        </div>
        <div>
          <Label htmlFor="type">نوع المكان *</Label>
          <Select id="type" value={form.type} onChange={(e) => update("type", e.target.value as PropertyType)}>
            {(Object.keys(PROPERTY_TYPE_LABELS) as PropertyType[]).map((t) => (
              <option key={t} value={t}>{PROPERTY_TYPE_LABELS[t]}</option>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="cityId">المدينة *</Label>
          <Select
            id="cityId"
            value={form.cityId}
            onChange={(e) => {
              const id = e.target.value;
              const city = cities.find((c) => c.id === id);
              const [lat, lng] = provinceCenter(city?.provinceName);
              const keepCustom = isEdit && form.latitude !== "33.3152";
              setForm((prev) => ({
                ...prev,
                cityId: id,
                latitude: keepCustom ? prev.latitude : lat,
                longitude: keepCustom ? prev.longitude : lng,
              }));
            }}
            required
          >
            <option value="">— اختر المدينة —</option>
            {cities.map((c) => (
              <option key={c.id} value={c.id}>{c.provinceName} — {c.nameAr}</option>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="pricePerDay">السعر لليوم (د.ع) *</Label>
          <Input id="pricePerDay" type="number" min={0} value={form.pricePerDay} onChange={(e) => update("pricePerDay", e.target.value)} required placeholder="500000" />
        </div>
        <div>
          <Label htmlFor="weekendPrice">سعر نهاية الأسبوع</Label>
          <Input id="weekendPrice" type="number" min={0} value={form.weekendPrice} onChange={(e) => update("weekendPrice", e.target.value)} placeholder="اختياري — إن اختلف" />
        </div>
        {form.type === "FARM" && (
          <>
            <div>
              <Label htmlFor="priceMorningShift">سعر الشفت الصباحي</Label>
              <Input id="priceMorningShift" type="number" min={0} value={form.priceMorningShift} onChange={(e) => update("priceMorningShift", e.target.value)} placeholder="اختياري" />
            </div>
            <div>
              <Label htmlFor="priceEveningShift">سعر الشفت المسائي</Label>
              <Input id="priceEveningShift" type="number" min={0} value={form.priceEveningShift} onChange={(e) => update("priceEveningShift", e.target.value)} placeholder="اختياري" />
            </div>
          </>
        )}
        <div className="md:col-span-2">
          <Label htmlFor="description">وصف قصير</Label>
          <Textarea id="description" value={form.description} onChange={(e) => update("description", e.target.value)} placeholder="ماذا يميز المكان؟" rows={3} />
        </div>
        <div>
          <Label htmlFor="phone">هاتف التواصل</Label>
          <Input
            id="phone"
            value={form.phone}
            onChange={(e) => update("phone", e.target.value)}
            onBlur={() => form.phone && update("phone", normalizeIraqiPhone(form.phone))}
            dir="ltr"
            placeholder="07XXXXXXXXX"
          />
        </div>
        <div>
          <div className="mb-1 flex items-center justify-between">
            <Label htmlFor="whatsapp">واتساب</Label>
            {form.phone && form.whatsapp !== form.phone && (
              <button type="button" className="text-xs text-accent underline" onClick={() => update("whatsapp", form.phone)}>
                نفس رقم الهاتف
              </button>
            )}
          </div>
          <Input
            id="whatsapp"
            value={form.whatsapp}
            onChange={(e) => update("whatsapp", e.target.value)}
            onBlur={() => form.whatsapp && update("whatsapp", normalizeIraqiPhone(form.whatsapp))}
            dir="ltr"
            placeholder="07XXXXXXXXX"
          />
        </div>
        <div className="md:col-span-2">
          <Label htmlFor="address">العنوان أو المنطقة</Label>
          <Input id="address" value={form.address} onChange={(e) => update("address", e.target.value)} placeholder="مثال: كركوك — طريق بغداد" />
        </div>
        <div>
          <Label htmlFor="capacity">عدد الضيوف التقريبي</Label>
          <Input id="capacity" type="number" min={0} value={form.capacity} onChange={(e) => update("capacity", e.target.value)} />
        </div>
        {isEdit && (
          <div>
            <Label htmlFor="status">حالة النشر</Label>
            <Select id="status" value={form.status} onChange={(e) => update("status", e.target.value as PropertyStatus)}>
              {(Object.keys(PROPERTY_STATUS_LABELS) as PropertyStatus[]).map((s) => (
                <option key={s} value={s}>{PROPERTY_STATUS_LABELS[s]}</option>
              ))}
            </Select>
          </div>
        )}
      </section>
      </DetailCard>

      <DetailCard title="المرافق">
      <section>
        <Label>مزايا مقسّمة حسب النوع — اضغط للاختيار</Label>
        <div className="mt-3">
          <AmenityPicker
            propertyType={form.type}
            value={form.amenityIds}
            onChange={(ids) => update("amenityIds", ids)}
            initialNames={initial?.amenities}
          />
        </div>
      </section>
      </DetailCard>

      <Button type="button" variant="ghost" size="sm" onClick={() => setShowMore((v) => !v)}>
        {showMore ? "إخفاء التفاصيل الإضافية" : "تفاصيل إضافية (SEO، مزود، قواعد، موقع)"}
      </Button>

      {showMore && (
        <>
        <DetailCard title="SEO ومحركات البحث">
        <section className="grid gap-4 md:grid-cols-2">
          <div className="md:col-span-2">
            <Label htmlFor="slug">الرابط (slug)</Label>
            <Input id="slug" dir="ltr" value={form.slug} onChange={(e) => update("slug", e.target.value)} placeholder="farm-kirkuk-01" />
          </div>
          <div>
            <Label htmlFor="nameEn">الاسم بالإنجليزية</Label>
            <Input id="nameEn" value={form.nameEn} onChange={(e) => update("nameEn", e.target.value)} />
          </div>
          <div>
            <Label htmlFor="metaTitle">عنوان SEO</Label>
            <Input id="metaTitle" value={form.metaTitle} onChange={(e) => update("metaTitle", e.target.value)} placeholder="يُستخدم في Google" />
          </div>
          <div className="md:col-span-2">
            <Label htmlFor="descriptionEn">الوصف بالإنجليزية</Label>
            <Textarea id="descriptionEn" value={form.descriptionEn} onChange={(e) => update("descriptionEn", e.target.value)} rows={2} />
          </div>
          <div className="md:col-span-2">
            <Label htmlFor="metaDescription">وصف SEO</Label>
            <Textarea id="metaDescription" value={form.metaDescription} onChange={(e) => update("metaDescription", e.target.value)} rows={2} placeholder="160 حرفاً تقريباً" />
          </div>
        </section>
        </DetailCard>
        <DetailCard title="تفاصيل إضافية">
        <section className="grid gap-4 md:grid-cols-2">
          <div className="md:col-span-2">
            <Label htmlFor="providerId">صاحب المكان (اختياري)</Label>
            <Select id="providerId" value={form.providerId} onChange={(e) => update("providerId", e.target.value)}>
              <option value="">أضافه الفريق — بدون مزود</option>
              {providers.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.businessName ?? p.user?.name ?? p.user?.phone ?? p.id}
                </option>
              ))}
            </Select>
          </div>
          <div className="md:col-span-2">
            <Label htmlFor="rules">قواعد المكان</Label>
            <Textarea id="rules" value={form.rules} onChange={(e) => update("rules", e.target.value)} placeholder="مثال: ممنوع التدخين..." />
          </div>
          <div className="md:col-span-2">
            <Label htmlFor="internalNotes">ملاحظة للفريق فقط</Label>
            <Textarea id="internalNotes" value={form.internalNotes} onChange={(e) => update("internalNotes", e.target.value)} placeholder="لن يراها العملاء" />
          </div>
          <div className="md:col-span-2">
            <Label htmlFor="tags">وسوم</Label>
            <Input id="tags" value={form.tags} onChange={(e) => update("tags", e.target.value)} placeholder="عائلي، VIP" />
          </div>
          <label className="field-checkbox md:col-span-2">
            <input
              type="checkbox"
              className="h-4 w-4 rounded border-line accent-brand"
              checked={form.featured}
              onChange={(e) => update("featured", e.target.checked)}
            />
            <span>إظهار هذا المكان في الصفحة الرئيسية للتطبيق</span>
          </label>
          <div className="md:col-span-2">
            <Label>الموقع على الخريطة</Label>
            <p className="mb-2 text-xs text-muted">انقر على الخريطة أو اسحب الدبوس لتحديد الإحداثيات</p>
            <MapPicker
              latitude={Number(form.latitude) || 33.3152}
              longitude={Number(form.longitude) || 44.3661}
              onChange={(lat, lng) => {
                setForm((prev) => ({ ...prev, latitude: String(lat), longitude: String(lng) }));
              }}
            />
          </div>
          <div>
            <Label htmlFor="latitude">خط العرض</Label>
            <Input id="latitude" dir="ltr" value={form.latitude} onChange={(e) => update("latitude", e.target.value)} />
          </div>
          <div>
            <Label htmlFor="longitude">خط الطول</Label>
            <Input id="longitude" dir="ltr" value={form.longitude} onChange={(e) => update("longitude", e.target.value)} />
          </div>
        </section>
        </DetailCard>
        </>
      )}

      <div className="form-sticky-footer">
        <Button type="submit" disabled={loading}>
          {loading ? "جاري الحفظ..." : submitLabel}
        </Button>
        {dirty && <span className="text-xs text-muted">هناك تعديلات غير محفوظة</span>}
      </div>
    </form>
  );
}
