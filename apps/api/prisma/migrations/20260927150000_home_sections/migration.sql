ALTER TABLE "properties" ADD COLUMN "is_new" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX "properties_is_new_idx" ON "properties"("is_new");

CREATE TABLE "home_spotlights" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL DEFAULT '',
    "image_url" TEXT NOT NULL,
    "property_id" TEXT NOT NULL,
    "height" INTEGER NOT NULL DEFAULT 176,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "home_spotlights_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "home_spotlights_is_active_sort_order_idx" ON "home_spotlights"("is_active", "sort_order");
CREATE INDEX "home_spotlights_property_id_idx" ON "home_spotlights"("property_id");

ALTER TABLE "home_spotlights" ADD CONSTRAINT "home_spotlights_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "properties"("id") ON DELETE CASCADE ON UPDATE CASCADE;
