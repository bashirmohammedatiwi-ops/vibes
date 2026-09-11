-- Flexible pricing engine: per-day price rules, booking modes, custom shift times

-- CreateEnum
CREATE TYPE "BookingMode" AS ENUM ('FULL_DAY', 'SHIFTS', 'HYBRID');

-- CreateEnum
CREATE TYPE "PriceRuleType" AS ENUM ('WEEKDAY', 'DATE_RANGE');

-- AlterTable properties: booking mode + per-property shift times
ALTER TABLE "properties" ADD COLUMN "booking_mode" "BookingMode",
ADD COLUMN "morning_start" TEXT,
ADD COLUMN "morning_end" TEXT,
ADD COLUMN "evening_start" TEXT,
ADD COLUMN "evening_end" TEXT;

-- Seed booking modes from property type (farms hybrid, halls/decoration full day)
UPDATE "properties" SET "booking_mode" = 'HYBRID' WHERE "type" = 'FARM';
UPDATE "properties" SET "booking_mode" = 'FULL_DAY' WHERE "type" <> 'FARM';

-- CreateTable price_rules
CREATE TABLE "price_rules" (
    "id" TEXT NOT NULL,
    "property_id" TEXT NOT NULL,
    "name" TEXT NOT NULL DEFAULT '',
    "rule_type" "PriceRuleType" NOT NULL DEFAULT 'WEEKDAY',
    "days_of_week" INTEGER[],
    "start_date" DATE,
    "end_date" DATE,
    "full_day_price" DECIMAL(12,2),
    "morning_price" DECIMAL(12,2),
    "evening_price" DECIMAL(12,2),
    "morning_start" TEXT,
    "morning_end" TEXT,
    "evening_start" TEXT,
    "evening_end" TEXT,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "price_rules_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "price_rules_property_id_is_active_idx" ON "price_rules"("property_id", "is_active");

-- AddForeignKey
ALTER TABLE "price_rules" ADD CONSTRAINT "price_rules_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "properties"("id") ON DELETE CASCADE ON UPDATE CASCADE;
