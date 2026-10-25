export type PropertyType = "FARM" | "HALL" | "DECORATION";
export type ShiftType = "MORNING" | "EVENING" | "FULL";
export type BookingMode = "FULL_DAY" | "SHIFTS" | "HYBRID";

export type Media = {
  id: string;
  url: string;
  type: "IMAGE" | "VIDEO" | "REEL" | "PANORAMA";
  posterUrl?: string | null;
  thumbnailUrl?: string | null;
  hlsUrl?: string | null;
  isPrimary?: boolean;
  caption?: string | null;
  altText?: string | null;
};

export type City = {
  id: string;
  nameAr: string;
  slug?: string;
  province?: { id: string; nameAr: string; slug: string; imageUrl?: string | null };
};

export type PropertyCard = {
  id: string;
  name: string;
  slug: string;
  type: PropertyType;
  featured: boolean;
  isNew: boolean;
  isWinter?: boolean;
  hasIndoorPool?: boolean;
  capacity: number;
  pricePerDay: number | string;
  priceMorningShift?: number | string | null;
  priceEveningShift?: number | string | null;
  ratingAvg: number | string;
  ratingCount: number;
  latitude?: number | string | null;
  longitude?: number | string | null;
  bookingMode?: BookingMode | null;
  city?: City | null;
  media?: Media[];
  provider?: { id: string; businessName?: string | null; user?: { name?: string | null } } | null;
  createdAt?: string;
};

export type Amenity = { id: string; nameAr: string; icon?: string | null; category?: string | null };

export type PropertyDetail = PropertyCard & {
  nameEn?: string | null;
  description?: string | null;
  address?: string | null;
  weekendPrice?: number | string | null;
  morningStart?: string | null;
  morningEnd?: string | null;
  eveningStart?: string | null;
  eveningEnd?: string | null;
  phone?: string | null;
  whatsapp?: string | null;
  rules?: string | null;
  amenities?: string[] | null;
  tags?: string[] | null;
  amenityLinks?: { value?: string | null; amenity: Amenity }[];
  provider?: {
    id: string;
    businessName?: string | null;
    verified?: boolean;
    user?: { name?: string | null; phone?: string | null };
    _count?: { followers?: number };
  } | null;
  reviews?: Review[];
  _count?: { reviews?: number };
};

export type Review = {
  id: string;
  rating: number;
  comment?: string | null;
  createdAt: string;
  user?: { name?: string | null } | null;
};

export type DayPrice = {
  date: string;
  prices: { full: number; morning: number; evening: number };
  isBooked: boolean;
  isBlocked: boolean;
  bookedShifts: ShiftType[];
  blockedShifts: ShiftType[];
  bookableShifts?: ShiftType[];
};

export type Availability = {
  propertyType: PropertyType;
  bookingMode: BookingMode;
  shiftTimes?: Record<string, string>;
  slots: { date: string; shift: ShiftType; isAvailable: boolean }[];
  dayPrices: DayPrice[];
};

export type Province = {
  id: string;
  nameAr: string;
  slug: string;
  imageUrl?: string | null;
  cities: { id: string; nameAr: string; slug: string }[];
};

export type Banner = { id: string; title?: string | null; subtitle?: string | null; imageUrl: string; linkUrl?: string | null };
export type Spotlight = {
  id: string;
  title?: string | null;
  imageUrl: string;
  height?: number;
  propertyId: string;
  property?: { id: string; name: string; type: PropertyType } | null;
};

export type Coupon = {
  code: string;
  description?: string | null;
  discountType: "PERCENT" | "FIXED";
  discountValue: number | string;
  minBookingTotal?: number | string | null;
  expiresAt?: string | null;
  appliesToTypes?: PropertyType[];
  property?: { id: string; name: string } | null;
};

export type User = {
  id: string;
  phone: string;
  name?: string | null;
  role: string;
  avatar?: string | null;
};

export type BookingStatus = "PENDING" | "AWAITING_PAYMENT" | "CONFIRMED" | "CANCELLED" | "COMPLETED" | "DISPUTED";

export type Booking = {
  id: string;
  propertyId: string;
  startDate: string;
  endDate: string;
  shift?: ShiftType | null;
  guests?: number | null;
  status: BookingStatus;
  totalPrice: number | string;
  discountAmount?: number | string | null;
  notes?: string | null;
  createdAt: string;
  property?: PropertyDetail;
  payment?: {
    id: string;
    method: string;
    amount: number | string;
    proofUrl?: string | null;
    status: "PENDING" | "PAID" | "FAILED" | "REFUNDED";
    adminNote?: string | null;
  } | null;
  conversation?: { id: string } | null;
  invoice?: { id: string; number: string; status: string } | null;
  cancellationRequests?: { id: string; status: string; expectedRefund?: number | string | null; reason?: string | null }[];
  canReview?: boolean;
};

export type Settings = {
  appName: string;
  supportPhone: string;
  paymentInstructions: string;
  cancellationPolicy: string;
  minBookingNoticeDays: string;
  maintenanceMode: boolean;
  maintenanceMessage: string;
  paymentGateways?: { zainCash?: boolean; qiCard?: boolean; manualProof?: boolean };
  morningShiftStart?: string;
  morningShiftEnd?: string;
  eveningShiftStart?: string;
  eveningShiftEnd?: string;
};

export type Notification = {
  id: string;
  type: string;
  title: string;
  body?: string | null;
  linkUrl?: string | null;
  entityType?: string | null;
  entityId?: string | null;
  isRead: boolean;
  createdAt: string;
};

export type Message = {
  id: string;
  conversationId: string;
  senderId?: string | null;
  kind: "TEXT" | "IMAGE" | "SYSTEM" | "CALL";
  body?: string | null;
  imageUrl?: string | null;
  createdAt: string;
  sender?: { id: string; name?: string | null; role?: string } | null;
};

export type Conversation = {
  id: string;
  kind: "BOOKING" | "SUPPORT" | "CLAIM" | string;
  status?: string;
  booking?: { id: string; status: string; startDate: string; property?: { id: string; name: string } } | null;
  property?: { id: string; name: string } | null;
  participants?: { id: string; name?: string | null; role?: string }[];
  lastMessage?: Message | null;
  unread?: number;
  updatedAt: string;
};

export type PriceOffer = {
  id: string;
  propertyId: string;
  startDate: string;
  endDate: string;
  shift?: ShiftType | null;
  amount: number | string;
  message?: string | null;
  status: "PENDING" | "ACCEPTED" | "DECLINED" | "EXPIRED";
  expiresAt?: string | null;
  bookingId?: string | null;
  property?: { id: string; name: string };
  provider?: { businessName?: string | null };
};

export type Paged<T> = { items: T[]; total: number; page: number; pageSize: number; totalPages: number };
