-- Amenity catalog by property type: replaces the freeform amenities JSON

-- CreateTable amenities
CREATE TABLE "amenities" (
    "id" TEXT NOT NULL,
    "name_ar" TEXT NOT NULL,
    "name_en" TEXT NOT NULL DEFAULT '',
    "slug" TEXT NOT NULL,
    "icon" TEXT NOT NULL DEFAULT '',
    "category" TEXT NOT NULL DEFAULT 'general',
    "applies_to" "PropertyType"[],
    "is_system" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "amenities_pkey" PRIMARY KEY ("id")
);

-- CreateTable property_amenities
CREATE TABLE "property_amenities" (
    "property_id" TEXT NOT NULL,
    "amenity_id" TEXT NOT NULL,
    "value" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "property_amenities_pkey" PRIMARY KEY ("property_id","amenity_id")
);

-- CreateIndex
CREATE INDEX "property_amenities_amenity_id_idx" ON "property_amenities"("amenity_id");

-- AddForeignKey
ALTER TABLE "property_amenities" ADD CONSTRAINT "property_amenities_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "properties"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "property_amenities" ADD CONSTRAINT "property_amenities_amenity_id_fkey" FOREIGN KEY ("amenity_id") REFERENCES "amenities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: one amenity row per distinct legacy JSON value
INSERT INTO "amenities" ("id", "name_ar", "name_en", "slug", "icon", "category", "applies_to", "is_system", "sort_order", "is_active", "created_at", "updated_at")
SELECT
    'am-' || md5(t.val),
    t.val,
    '',
    'legacy-' || md5(t.val),
    '',
    'general',
    ARRAY[]::"PropertyType"[],
    false,
    0,
    true,
    NOW(),
    NOW()
FROM (
    SELECT DISTINCT jsonb_array_elements_text("amenities") AS val
    FROM "properties"
    WHERE jsonb_array_length("amenities") > 0
) t;

-- Backfill: link properties to amenities preserving original order
INSERT INTO "property_amenities" ("property_id", "amenity_id", "sort_order")
SELECT
    p."id",
    a."id",
    (j.ord - 1)::int
FROM "properties" p
CROSS JOIN LATERAL jsonb_array_elements_text(p."amenities") WITH ORDINALITY AS j(val, ord)
JOIN "amenities" a ON a."name_ar" = j.val;
