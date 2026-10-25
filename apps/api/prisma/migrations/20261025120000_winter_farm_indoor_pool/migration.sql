-- مزرعة شتوية + مسبح مغلق
ALTER TABLE "properties" ADD COLUMN "is_winter" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "properties" ADD COLUMN "has_indoor_pool" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX "properties_is_winter_idx" ON "properties"("is_winter");
CREATE INDEX "properties_has_indoor_pool_idx" ON "properties"("has_indoor_pool");
