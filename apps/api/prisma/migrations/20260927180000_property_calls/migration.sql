ALTER TYPE "MessageKind" ADD VALUE 'CALL';

CREATE TYPE "CallStatus" AS ENUM ('RINGING', 'ACTIVE', 'ENDED', 'MISSED');

ALTER TABLE "conversations" ADD COLUMN "property_id" TEXT;
ALTER TABLE "conversations" ADD COLUMN "guest_user_id" TEXT;

CREATE UNIQUE INDEX "conversations_guest_user_id_property_id_key" ON "conversations"("guest_user_id", "property_id");

ALTER TABLE "conversations" ADD CONSTRAINT "conversations_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "properties"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_guest_user_id_fkey" FOREIGN KEY ("guest_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "call_sessions" (
    "id" TEXT NOT NULL,
    "conversation_id" TEXT NOT NULL,
    "caller_id" TEXT NOT NULL,
    "callee_id" TEXT NOT NULL,
    "status" "CallStatus" NOT NULL DEFAULT 'RINGING',
    "room_name" TEXT NOT NULL,
    "started_at" TIMESTAMP(3),
    "ended_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "call_sessions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "call_sessions_conversation_id_created_at_idx" ON "call_sessions"("conversation_id", "created_at");
CREATE INDEX "call_sessions_callee_id_status_idx" ON "call_sessions"("callee_id", "status");

ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_caller_id_fkey" FOREIGN KEY ("caller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_callee_id_fkey" FOREIGN KEY ("callee_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
