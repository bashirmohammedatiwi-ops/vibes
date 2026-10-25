import { Prisma } from '@prisma/client';

/**
 * Media fields safe for public responses. Leaves out uploader, processing
 * internals and `fileSizeBytes` (a BigInt, which JSON.stringify can't cache).
 */
export const publicMediaSelect = {
  id: true,
  propertyId: true,
  type: true,
  status: true,
  url: true,
  thumbnailUrl: true,
  hlsUrl: true,
  posterUrl: true,
  width: true,
  height: true,
  aspectRatio: true,
  renditions: true,
  caption: true,
  altText: true,
  durationSec: true,
  mimeType: true,
  sortOrder: true,
  isPrimary: true,
  createdAt: true,
} satisfies Prisma.MediaSelect;

/** Review fields safe for public responses (no `adminNote` / `userId`). */
export const publicReviewSelect = {
  id: true,
  propertyId: true,
  rating: true,
  comment: true,
  isVisible: true,
  createdAt: true,
  user: { select: { name: true } },
} satisfies Prisma.ReviewSelect;

/**
 * Property scalars safe for public responses — an allowlist so new internal
 * columns don't leak. Omits `internalNotes`, `rejectionReason`, `createdById`.
 */
export const publicPropertyScalars = {
  id: true,
  providerId: true,
  type: true,
  slug: true,
  name: true,
  nameEn: true,
  description: true,
  descriptionEn: true,
  metaTitle: true,
  metaDescription: true,
  cityId: true,
  address: true,
  latitude: true,
  longitude: true,
  capacity: true,
  bookingMode: true,
  morningStart: true,
  morningEnd: true,
  eveningStart: true,
  eveningEnd: true,
  pricePerDay: true,
  weekendPrice: true,
  priceMorningShift: true,
  priceEveningShift: true,
  phone: true,
  whatsapp: true,
  featured: true,
  isNew: true,
  isWinter: true,
  hasIndoorPool: true,
  amenities: true,
  tags: true,
  rules: true,
  status: true,
  viewCount: true,
  ratingAvg: true,
  ratingCount: true,
  publishedAt: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.PropertySelect;
