-- AlterEnum
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'STAFF';
ALTER TYPE "PropertyType" ADD VALUE IF NOT EXISTS 'DECORATION';

-- AlterTable properties
ALTER TABLE "properties" ALTER COLUMN "provider_id" DROP NOT NULL;

ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "created_by_id" TEXT;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "slug" TEXT;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "weekend_price" DECIMAL(12,2);
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "phone" TEXT;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "whatsapp" TEXT;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "featured" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "tags" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "rules" TEXT NOT NULL DEFAULT '';
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "internal_notes" TEXT NOT NULL DEFAULT '';
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "view_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "rating_avg" DECIMAL(3,2) NOT NULL DEFAULT 0;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "rating_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "properties" ADD COLUMN IF NOT EXISTS "published_at" TIMESTAMP(3);

UPDATE "properties" SET "slug" = LOWER(REPLACE(REPLACE("id"::text, '-', ''), ' ', '')) WHERE "slug" IS NULL;
ALTER TABLE "properties" ALTER COLUMN "slug" SET NOT NULL;

ALTER TABLE "properties" ALTER COLUMN "status" SET DEFAULT 'DRAFT';

CREATE UNIQUE INDEX IF NOT EXISTS "properties_slug_key" ON "properties"("slug");
CREATE INDEX IF NOT EXISTS "properties_featured_idx" ON "properties"("featured");
CREATE INDEX IF NOT EXISTS "properties_status_featured_idx" ON "properties"("status", "featured");

ALTER TABLE "properties" DROP CONSTRAINT IF EXISTS "properties_provider_id_fkey";
ALTER TABLE "properties" ADD CONSTRAINT "properties_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "providers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "properties" ADD CONSTRAINT "properties_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AlterTable media
ALTER TABLE "media" ADD COLUMN IF NOT EXISTS "caption" TEXT NOT NULL DEFAULT '';
ALTER TABLE "media" ADD COLUMN IF NOT EXISTS "alt_text" TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS "media_property_id_sort_order_idx" ON "media"("property_id", "sort_order");

-- CreateTable admin_activities
CREATE TABLE IF NOT EXISTS "admin_activities" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "admin_activities_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "admin_activities_user_id_idx" ON "admin_activities"("user_id");
CREATE INDEX IF NOT EXISTS "admin_activities_entity_type_entity_id_idx" ON "admin_activities"("entity_type", "entity_id");

ALTER TABLE "admin_activities" DROP CONSTRAINT IF EXISTS "admin_activities_user_id_fkey";
ALTER TABLE "admin_activities" ADD CONSTRAINT "admin_activities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX IF NOT EXISTS "bookings_status_idx" ON "bookings"("status");
