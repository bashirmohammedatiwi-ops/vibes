-- Fixups for the v0.4 migrations: align scalar-list columns with the Prisma
-- schema (NOT NULL + default) and add the missing unique index on amenities.slug.

UPDATE "amenities" SET "applies_to" = '{}' WHERE "applies_to" IS NULL;
ALTER TABLE "amenities" ALTER COLUMN "applies_to" SET NOT NULL;
ALTER TABLE "amenities" ALTER COLUMN "applies_to" SET DEFAULT '{}';

UPDATE "price_rules" SET "days_of_week" = '{}' WHERE "days_of_week" IS NULL;
ALTER TABLE "price_rules" ALTER COLUMN "days_of_week" SET NOT NULL;
ALTER TABLE "price_rules" ALTER COLUMN "days_of_week" SET DEFAULT '{}';

UPDATE "coupons" SET "applies_to_types" = '{}' WHERE "applies_to_types" IS NULL;
ALTER TABLE "coupons" ALTER COLUMN "applies_to_types" SET NOT NULL;
ALTER TABLE "coupons" ALTER COLUMN "applies_to_types" SET DEFAULT '{}';

-- Unique index required by Amenity upserts (ON CONFLICT "slug")
CREATE UNIQUE INDEX "amenities_slug_key" ON "amenities"("slug");
