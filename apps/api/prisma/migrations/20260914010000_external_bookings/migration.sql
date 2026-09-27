CREATE TYPE "BookingOrigin" AS ENUM ('PLATFORM', 'EXTERNAL');

ALTER TABLE "bookings"
  ALTER COLUMN "user_id" DROP NOT NULL,
  ADD COLUMN "origin" "BookingOrigin" NOT NULL DEFAULT 'PLATFORM',
  ADD COLUMN "guest_name" TEXT,
  ADD COLUMN "guest_phone" TEXT;

ALTER TABLE "providers"
  ADD COLUMN "request_note" TEXT NOT NULL DEFAULT '',
  ADD COLUMN "place_types" TEXT NOT NULL DEFAULT '';

CREATE INDEX "bookings_origin_idx" ON "bookings"("origin");
