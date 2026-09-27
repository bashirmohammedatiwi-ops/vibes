export type ShiftType = "MORNING" | "EVENING" | "FULL";

export type ShiftTimes = {
  morningShiftStart: string;
  morningShiftEnd: string;
  eveningShiftStart: string;
  eveningShiftEnd: string;
  fullShiftStart: string;
  fullShiftEnd: string;
};

export type PropertyType = "FARM" | "HALL" | "DECORATION";
export type PropertyStatus = "DRAFT" | "PENDING" | "APPROVED" | "REJECTED" | "SUSPENDED";
export type BookingMode = "FULL_DAY" | "SHIFTS" | "HYBRID";
export type PriceRuleType = "WEEKDAY" | "DATE_RANGE";

export type Amenity = {
  id: string;
  nameAr: string;
  nameEn: string;
  slug: string;
  icon: string;
  category: string;
  appliesTo: PropertyType[];
  isSystem: boolean;
  sortOrder: number;
  isActive: boolean;
  _count?: { properties: number };
};

export type PropertyAmenityLink = {
  amenityId: string;
  amenity: Amenity;
  value?: string | null;
  sortOrder: number;
};

export type PriceRule = {
  id: string;
  propertyId: string;
  name: string;
  ruleType: PriceRuleType;
  daysOfWeek: number[];
  startDate?: string | null;
  endDate?: string | null;
  fullDayPrice?: number | string | null;
  morningPrice?: number | string | null;
  eveningPrice?: number | string | null;
  morningStart?: string | null;
  morningEnd?: string | null;
  eveningStart?: string | null;
  eveningEnd?: string | null;
  priority: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

export type PricingPreviewDay = {
  date: string;
  dayOfWeek: number;
  prices: { full: number; morning: number; evening: number };
  times: ShiftTimes;
  ruleId?: string | null;
  ruleName?: string | null;
  bookedShifts: ShiftType[];
  blockedShifts: ShiftType[];
  mode: BookingMode;
};

export type PricingPreview = {
  propertyId: string;
  bookingMode: BookingMode;
  shiftTimes: ShiftTimes;
  days: PricingPreviewDay[];
};

export const BOOKING_MODE_LABELS: Record<BookingMode, string> = {
  FULL_DAY: "حجز يوم كامل",
  SHIFTS: "حجز بالشفتات فقط",
  HYBRID: "شفتات أو يوم كامل",
};

export const WEEKDAY_LABELS = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];

export type Province = {
  id: string;
  nameAr: string;
  slug: string;
  cities: City[];
};

export type City = {
  id: string;
  nameAr: string;
  slug: string;
  provinceId: string;
};

export type MediaStatus = "UPLOADING" | "PROCESSING" | "READY" | "FAILED" | "REJECTED";
export type TargetRatio = "auto" | "16:9" | "9:16" | "1:1" | "4:3";

export const RATIO_OPTIONS: Array<{ value: TargetRatio; label: string; hint: string }> = [
  { value: "auto", label: "تلقائي", hint: "تحتفظ بالنسبة الأصلية" },
  { value: "1:1", label: "مربع 1:1", hint: "مثالي للشبكات" },
  { value: "16:9", label: "أفقي 16:9", hint: "غلاف وعروض" },
  { value: "9:16", label: "عمودي 9:16", hint: "ريلز وقصص" },
  { value: "4:3", label: "كلاسيكي 4:3", hint: "تناسب الشاشات القديمة" },
];

export type MediaRendition = {
  label: string;
  url: string;
  width: number;
  height: number;
  bytes: number;
};

export type MediaItem = {
  id: string;
  url: string;
  type: string;
  status?: MediaStatus;
  isPrimary: boolean;
  sortOrder: number;
  caption?: string | null;
  altText?: string | null;
  posterUrl?: string | null;
  thumbnailUrl?: string | null;
  width?: number | null;
  height?: number | null;
  aspectRatio?: string | null;
  durationSec?: number | null;
  processingProgress?: number | null;
  processingError?: string | null;
  renditions?: MediaRendition[] | null;
  mimeType?: string | null;
};

export type Property = {
  id: string;
  name: string;
  slug: string;
  type: PropertyType;
  status: PropertyStatus;
  description?: string;
  nameEn?: string;
  descriptionEn?: string;
  metaTitle?: string;
  metaDescription?: string;
  cityId: string;
  address?: string | null;
  latitude: number;
  longitude: number;
  capacity: number;
  bookingMode?: BookingMode | null;
  morningStart?: string | null;
  morningEnd?: string | null;
  eveningStart?: string | null;
  eveningEnd?: string | null;
  pricePerDay: number | string;
  weekendPrice?: number | string | null;
  priceMorningShift?: number | string | null;
  priceEveningShift?: number | string | null;
  phone?: string | null;
  whatsapp?: string | null;
  featured: boolean;
  isNew?: boolean;
  amenities: string[];
  tags: string[];
  rules?: string | null;
  internalNotes?: string | null;
  rejectionReason?: string | null;
  viewCount?: number;
  ratingAvg?: number | null;
  ratingCount?: number;
  publishedAt?: string | null;
  providerId?: string | null;
  city?: City & { province?: { nameAr: string; slug: string } };
  media?: MediaItem[];
  amenityLinks?: PropertyAmenityLink[];
  priceRules?: PriceRule[];
  _count?: { bookings: number; reviews: number };
};

export type Paginated<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

export type DashboardStats = {
  users: number;
  properties: number;
  bookings: number;
  pendingProperties: number;
  draftProperties: number;
  featuredProperties: number;
  confirmedBookings: number;
  monthlyBookings: number;
  totalRevenue: number | string;
  propertiesByType: { type: PropertyType; count: number }[];
  propertiesByProvince: { name: string; count: number }[];
  monthlyRevenue: { month: string; revenue: number; bookings: number }[];
  unreadNotifications?: number;
  pendingPaymentProofs?: number;
  disputedBookings?: number;
  todayCheckIns?: number;
  pendingProviders?: number;
  pendingProviderProperties?: number;
  pendingRefunds?: number;
  pendingCancellations?: number;
  pendingOffers?: number;
  pendingSocialReports?: number;
  pendingSupport?: number;
  recentBookings: Array<{
    id: string;
    status: string;
    totalPrice: number | string;
    createdAt: string;
    user?: { name?: string | null; phone: string };
    property?: { name: string; type: PropertyType };
  }>;
  recentActivities: Array<{
    id: string;
    action: string;
    entityType: string;
    entityId: string;
    createdAt: string;
    user?: { name?: string | null; phone: string };
  }>;
};

export type PropertyFormData = {
  type: PropertyType;
  name: string;
  slug: string;
  description: string;
  cityId: string;
  address: string;
  latitude: string;
  longitude: string;
  capacity: string;
  pricePerDay: string;
  weekendPrice: string;
  priceMorningShift: string;
  priceEveningShift: string;
  phone: string;
  whatsapp: string;
  featured: boolean;
  status: PropertyStatus;
  amenityIds: string[];
  tags: string;
  rules: string;
  internalNotes: string;
  nameEn: string;
  descriptionEn: string;
  metaTitle: string;
  metaDescription: string;
  providerId: string;
};

export type AvailabilitySlot = {
  id: string;
  date: string;
  shift: ShiftType;
  isAvailable: boolean;
  priceOverride?: number | string | null;
};

export type Booking = {
  id: string;
  status: string;
  origin?: "PLATFORM" | "EXTERNAL";
  guestName?: string | null;
  guestPhone?: string | null;
  totalPrice: number | string;
  discountAmount?: number | string;
  couponId?: string | null;
  startDate: string;
  endDate: string;
  shift: ShiftType;
  guests: number;
  notes?: string | null;
  disputeReason?: string | null;
  disputeNote?: string | null;
  createdAt: string;
  user?: { id?: string; name?: string | null; phone: string };
  property?: { id?: string; name: string; type?: PropertyType; slug?: string; city?: { nameAr: string } };
  payment?: { id: string; status: string; method: string; amount: number | string; proofUrl?: string | null };
};

export type UserRecord = {
  id: string;
  phone: string;
  name?: string | null;
  role: string;
  isActive: boolean;
  createdAt: string;
  _count?: { bookings: number; reviews: number };
};

export type ReviewRecord = {
  id: string;
  rating: number;
  comment: string;
  isVisible: boolean;
  adminNote?: string | null;
  createdAt: string;
  user?: { name?: string | null; phone: string };
  property?: { id: string; name: string; slug: string };
};

export type ActivityRecord = {
  id: string;
  action: string;
  entityType: string;
  entityId?: string | null;
  metadata?: Record<string, unknown> | null;
  createdAt: string;
  user?: { id?: string; name?: string | null; phone: string };
};

export type HomeSpotlight = {
  id: string;
  title: string;
  imageUrl: string;
  propertyId: string;
  height: number;
  sortOrder: number;
  isActive: boolean;
  property?: { id: string; name: string; type: string; slug?: string };
};

export type Banner = {
  id: string;
  title: string;
  subtitle: string;
  imageUrl: string;
  linkUrl?: string | null;
  sortOrder: number;
  isActive: boolean;
};

export type PaymentRecord = {
  id: string;
  status: string;
  method: string;
  amount: number | string;
  proofUrl?: string | null;
  adminNote?: string | null;
  transactionRef?: string | null;
  reviewedAt?: string | null;
  createdAt: string;
  booking?: {
    id: string;
    user?: { name?: string | null; phone: string };
    property?: { name: string };
  };
};

export type PaymentDetail = Omit<PaymentRecord, "booking"> & {
  updatedAt?: string;
  reviewedBy?: { id: string; name?: string | null; phone: string } | null;
  booking?: {
    id: string;
    status: string;
    startDate: string;
    endDate: string;
    shift: ShiftType;
    guests: number;
    totalPrice: number | string;
    user?: { id: string; name?: string | null; phone: string };
    property?: { id: string; name: string; slug: string; type: PropertyType };
  };
};

export type PropertyReview = {
  id: string;
  rating: number;
  comment: string;
  isVisible: boolean;
  createdAt: string;
  user?: { name?: string | null; phone: string };
};

export type PropertyDetail = Property & {
  reviews?: PropertyReview[];
  createdBy?: { id: string; name?: string | null; phone: string };
  provider?: { id?: string; businessName?: string | null; user?: { name?: string | null; phone: string } };
};

export type TeamNotification = {
  id: string;
  type: string;
  title: string;
  body: string;
  linkUrl?: string | null;
  isRead: boolean;
  createdAt: string;
};

export type BookingNote = {
  id: string;
  content: string;
  isInternal: boolean;
  createdAt: string;
  author?: { name?: string | null; phone: string };
};
