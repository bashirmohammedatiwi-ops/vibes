-- Media v2: video processing metadata (dimensions, aspect ratio, poster, renditions, progress)

-- AlterTable media
ALTER TABLE "media" ADD COLUMN "poster_url" TEXT,
ADD COLUMN "width" INTEGER,
ADD COLUMN "height" INTEGER,
ADD COLUMN "aspect_ratio" TEXT,
ADD COLUMN "renditions" JSONB,
ADD COLUMN "processing_progress" INTEGER,
ADD COLUMN "processing_error" TEXT;

-- CreateIndex
CREATE INDEX "media_status_idx" ON "media"("status");
