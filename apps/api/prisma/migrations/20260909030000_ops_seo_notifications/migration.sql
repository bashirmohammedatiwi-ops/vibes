-- AlterTable Property SEO
ALTER TABLE "properties" ADD COLUMN "name_en" TEXT NOT NULL DEFAULT '';
ALTER TABLE "properties" ADD COLUMN "description_en" TEXT NOT NULL DEFAULT '';
ALTER TABLE "properties" ADD COLUMN "meta_title" TEXT NOT NULL DEFAULT '';
ALTER TABLE "properties" ADD COLUMN "meta_description" TEXT NOT NULL DEFAULT '';

-- AlterTable Booking disputes
ALTER TABLE "bookings" ADD COLUMN "dispute_reason" TEXT;
ALTER TABLE "bookings" ADD COLUMN "dispute_note" TEXT;

-- AlterTable Payment review
ALTER TABLE "payments" ADD COLUMN "admin_note" TEXT;
ALTER TABLE "payments" ADD COLUMN "transaction_ref" TEXT;
ALTER TABLE "payments" ADD COLUMN "reviewed_at" TIMESTAMP(3);
ALTER TABLE "payments" ADD COLUMN "reviewed_by_id" TEXT;

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('BOOKING_NEW', 'BOOKING_STATUS', 'PAYMENT_PROOF', 'PAYMENT_RECEIVED', 'REVIEW_NEW', 'PROPERTY_PENDING', 'SYSTEM');

-- CreateTable
CREATE TABLE "team_notifications" (
    "id" TEXT NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL DEFAULT '',
    "link_url" TEXT,
    "entity_type" TEXT,
    "entity_id" TEXT,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "team_notifications_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "booking_notes" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "author_id" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "is_internal" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "booking_notes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "team_notifications_is_read_created_at_idx" ON "team_notifications"("is_read", "created_at");
CREATE INDEX "booking_notes_booking_id_created_at_idx" ON "booking_notes"("booking_id", "created_at");

-- AddForeignKey
ALTER TABLE "booking_notes" ADD CONSTRAINT "booking_notes_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "booking_notes" ADD CONSTRAINT "booking_notes_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
