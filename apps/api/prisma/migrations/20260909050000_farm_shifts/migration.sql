-- CreateEnum
CREATE TYPE "ShiftType" AS ENUM ('MORNING', 'EVENING', 'FULL');

-- AlterTable properties
ALTER TABLE "properties" ADD COLUMN "price_morning_shift" DECIMAL(12,2),
ADD COLUMN "price_evening_shift" DECIMAL(12,2);

-- AlterTable availability_slots
ALTER TABLE "availability_slots" ADD COLUMN "shift" "ShiftType" NOT NULL DEFAULT 'FULL';

ALTER TABLE "availability_slots" DROP CONSTRAINT IF EXISTS "availability_slots_property_id_date_key";

CREATE UNIQUE INDEX "availability_slots_property_id_date_shift_key" ON "availability_slots"("property_id", "date", "shift");

-- AlterTable bookings
ALTER TABLE "bookings" ADD COLUMN "shift" "ShiftType" NOT NULL DEFAULT 'FULL';

-- Default shift times
INSERT INTO "platform_settings" ("key", "value", "updated_at") VALUES
  ('morningShiftStart', '08:00', NOW()),
  ('morningShiftEnd', '14:00', NOW()),
  ('eveningShiftStart', '16:00', NOW()),
  ('eveningShiftEnd', '22:00', NOW()),
  ('fullShiftStart', '08:00', NOW()),
  ('fullShiftEnd', '22:00', NOW())
ON CONFLICT ("key") DO NOTHING;
