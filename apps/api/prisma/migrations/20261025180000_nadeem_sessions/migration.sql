-- CreateTable
CREATE TABLE "nadeem_sessions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT,
    "occasion" TEXT,
    "property_type" TEXT,
    "auto_type" BOOLEAN NOT NULL DEFAULT false,
    "province" TEXT,
    "guests" INTEGER,
    "shift" TEXT,
    "max_budget" INTEGER,
    "budget_open" BOOLEAN NOT NULL DEFAULT false,
    "result_ids" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "result_count" INTEGER NOT NULL DEFAULT 0,
    "precise" BOOLEAN NOT NULL DEFAULT false,
    "clicked_property_id" TEXT,
    "clicked_at" TIMESTAMP(3),
    "platform" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nadeem_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "nadeem_sessions_created_at_idx" ON "nadeem_sessions"("created_at");

-- CreateIndex
CREATE INDEX "nadeem_sessions_occasion_idx" ON "nadeem_sessions"("occasion");
