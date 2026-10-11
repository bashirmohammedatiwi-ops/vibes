-- AlterTable
ALTER TABLE "call_sessions" ALTER COLUMN "callee_id" DROP NOT NULL;
ALTER TABLE "call_sessions" ADD COLUMN "queue_attempt" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "call_sessions" ADD COLUMN "offered_at" TIMESTAMP(3);
ALTER TABLE "call_sessions" ADD COLUMN "decline_reason" TEXT;
ALTER TABLE "call_sessions" ADD COLUMN "rtt_ms" INTEGER;
ALTER TABLE "call_sessions" ADD COLUMN "packet_loss_pct" DOUBLE PRECISION;
ALTER TABLE "call_sessions" ADD COLUMN "reconnects" INTEGER NOT NULL DEFAULT 0;

CREATE INDEX "call_sessions_status_created_at_idx" ON "call_sessions"("status", "created_at");

-- CreateTable
CREATE TABLE "staff_profiles" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "display_name" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "permissions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "max_concurrent_calls" INTEGER NOT NULL DEFAULT 1,
    "last_seen_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "staff_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "staff_profiles_user_id_key" ON "staff_profiles"("user_id");

CREATE TABLE "staff_presence" (
    "user_id" TEXT NOT NULL,
    "state" TEXT NOT NULL DEFAULT 'OFFLINE',
    "active_call_id" TEXT,
    "device_id" TEXT,
    "last_offered_at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "staff_presence_pkey" PRIMARY KEY ("user_id")
);

CREATE INDEX "staff_presence_state_last_offered_at_idx" ON "staff_presence"("state", "last_offered_at");

CREATE TABLE "call_queue_items" (
    "id" TEXT NOT NULL,
    "call_id" TEXT NOT NULL,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "reserved_agent_id" TEXT,
    "state" TEXT NOT NULL DEFAULT 'WAITING',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "call_queue_items_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "call_queue_items_call_id_key" ON "call_queue_items"("call_id");
CREATE INDEX "call_queue_items_state_priority_created_at_idx" ON "call_queue_items"("state", "priority", "created_at");

CREATE TABLE "call_agent_offers" (
    "id" TEXT NOT NULL,
    "call_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "call_agent_offers_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "call_agent_offers_call_id_agent_id_created_at_idx" ON "call_agent_offers"("call_id", "agent_id", "created_at");

ALTER TABLE "staff_profiles" ADD CONSTRAINT "staff_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "staff_presence" ADD CONSTRAINT "staff_presence_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_queue_items" ADD CONSTRAINT "call_queue_items_call_id_fkey" FOREIGN KEY ("call_id") REFERENCES "call_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_agent_offers" ADD CONSTRAINT "call_agent_offers_call_id_fkey" FOREIGN KEY ("call_id") REFERENCES "call_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
