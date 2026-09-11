import type { PropertyStatus, PropertyType } from "./types";

export const PROPERTY_TYPE_LABELS: Record<PropertyType, string> = {
  FARM: "مزرعة",
  HALL: "قاعة أفراح",
  DECORATION: "ديكور",
};

export const PROPERTY_STATUS_LABELS: Record<PropertyStatus, string> = {
  DRAFT: "مسودة",
  PENDING: "بانتظار المراجعة",
  APPROVED: "منشور",
  REJECTED: "مرفوض",
  SUSPENDED: "موقوف",
};

export const STATUS_VARIANT: Record<PropertyStatus, "default" | "success" | "warning" | "danger" | "muted"> = {
  DRAFT: "muted",
  PENDING: "warning",
  APPROVED: "success",
  REJECTED: "danger",
  SUSPENDED: "danger",
};

export const SHIFT_TYPE_LABELS: Record<string, string> = {
  MORNING: "شفت صباحي",
  EVENING: "شفت مسائي",
  FULL: "يوم كامل",
};

export const SHIFT_SHORT_LABELS: Record<string, string> = {
  MORNING: "صباح",
  EVENING: "مساء",
  FULL: "كامل",
};

export const FARM_SHIFTS = ["MORNING", "EVENING", "FULL"] as const;

export const BOOKING_STATUS_LABELS: Record<string, string> = {
  PENDING: "قيد الانتظار",
  AWAITING_PAYMENT: "بانتظار الدفع",
  CONFIRMED: "مؤكد",
  COMPLETED: "مكتمل",
  CANCELLED: "ملغى",
  DISPUTED: "نزاع",
};

export const ACTIVITY_LABELS: Record<string, string> = {
  "property.create": "إنشاء مكان",
  "property.update": "تحديث مكان",
  "property.delete": "حذف مكان",
  "property.publish": "نشر مكان",
  "property.suspend": "إيقاف مكان",
  "property.reject": "رفض مكان",
  "property.duplicate": "نسخ مكان",
  "property.bulk": "إجراء جماعي",
  "media.upload": "رفع صورة",
  "media.delete": "حذف صورة",
  "media.reorder": "إعادة ترتيب الصور",
  "booking.create": "إنشاء حجز",
  "booking.reschedule": "إعادة جدولة",
  "booking.status": "تحديث حجز",
  "booking.note": "ملاحظة حجز",
  "booking.note.edit": "تعديل ملاحظة",
  "booking.note.delete": "حذف ملاحظة",
  "booking.dispute": "فتح نزاع",
  "booking.dispute.resolve": "حل نزاع",
  "user.create": "إنشاء مستخدم",
  "user.update": "تحديث مستخدم",
  "user.deactivate": "تعطيل مستخدم",
  "user.delete": "حذف مستخدم",
  "review.show": "إظهار تقييم",
  "review.hide": "إخفاء تقييم",
  "review.delete": "حذف تقييم",
  "payment.status": "تحديث دفعة",
  "payment.review": "مراجعة دفعة",
  "payment.proof": "رفع إثبات دفع",
  "payment.refund": "استرداد دفعة",
  "banner.create": "إنشاء بانر",
  "banner.update": "تحديث بانر",
  "banner.delete": "حذف بانر",
  "location.province": "إضافة محافظة",
  "location.province.create": "إضافة محافظة",
  "location.city": "إضافة مدينة",
  "location.city.create": "إضافة مدينة",
  "location.city.delete": "حذف مدينة",
  "location.province.update": "تعديل محافظة",
  "location.province.delete": "حذف محافظة",
  "location.city.update": "تعديل مدينة",
  "provider.verify": "توثيق مزود",
  "provider.reject": "رفض مزود",
  "provider.revoke": "إلغاء توثيق",
  "settings.update": "تحديث الإعدادات",
  "media.set_primary": "تعيين غلاف",
  "seed.complete": "تهيئة النظام",
};

export const USER_ROLE_LABELS: Record<string, string> = {
  CUSTOMER: "عميل",
  PROVIDER: "مزود",
  STAFF: "فريق",
  ADMIN: "مدير",
};

export const PAYMENT_STATUS_LABELS: Record<string, string> = {
  PENDING: "قيد الانتظار",
  PAID: "مدفوع",
  FAILED: "فشل",
  REFUNDED: "مسترد",
};

export const PAYMENT_METHOD_LABELS: Record<string, string> = {
  MANUAL: "تحويل يدوي",
  ZAIN_CASH: "زين كاش",
  QI_CARD: "Qi Card",
};

export const BULK_ACTION_LABELS: Record<string, string> = {
  publish: "نشر",
  suspend: "إيقاف",
  feature: "تمييز",
  unfeature: "إلغاء التمييز",
  delete: "حذف",
};

export const NOTIFICATION_TYPE_LABELS: Record<string, string> = {
  BOOKING_NEW: "حجز جديد",
  BOOKING_STATUS: "تحديث حجز",
  PAYMENT_PROOF: "إثبات دفع",
  PAYMENT_REVIEW: "مراجعة دفعة",
  PROPERTY_PENDING: "مكان جديد",
  PROPERTY_APPROVED: "مكان منشور",
  PROPERTY_REJECTED: "رفض مكان",
  REVIEW_NEW: "تقييم جديد",
  PROVIDER_REQUEST: "طلب مزود",
  DISPUTE: "نزاع",
  SYSTEM: "نظام",
};

export const KYC_STATUS_LABELS: Record<string, string> = {
  UNVERIFIED: "غير موثّق",
  PENDING: "قيد المراجعة",
  VERIFIED: "موثّق",
  REJECTED: "مرفوض",
};

export const ENTITY_TYPE_LABELS: Record<string, string> = {
  property: "مكان",
  booking: "حجز",
  user: "مستخدم",
  payment: "دفعة",
  review: "تقييم",
  banner: "بانر",
  media: "صورة",
  location: "موقع",
  provider: "مزود",
  settings: "إعدادات",
};

export function activityEntityHref(entityType: string, entityId?: string | null) {
  if (!entityId) return null;
  if (entityType === "booking") return `/bookings/${entityId}`;
  if (entityType === "property") return `/properties/${entityId}/edit`;
  if (entityType === "user") return `/users/${entityId}`;
  if (entityType === "payment") return `/payments/${entityId}`;
  if (entityType === "review") return `/reviews`;
  if (entityType === "banner") return `/banners`;
  if (entityType === "location") return `/locations`;
  if (entityType === "provider") return `/providers/${entityId}`;
  if (entityType === "settings") return `/settings`;
  return null;
}
