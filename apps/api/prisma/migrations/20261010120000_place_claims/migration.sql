ALTER TYPE "ConversationKind" ADD VALUE IF NOT EXISTS 'CLAIM';

CREATE TYPE "ClaimStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

DROP INDEX IF EXISTS "conversations_guest_user_id_property_id_key";

CREATE UNIQUE INDEX "conversations_guest_user_id_property_id_kind_key"
  ON "conversations"("guest_user_id", "property_id", "kind");

CREATE TABLE "place_claims" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "property_id" TEXT NOT NULL,
  "conversation_id" TEXT NOT NULL,
  "status" "ClaimStatus" NOT NULL DEFAULT 'PENDING',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "place_claims_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "place_claims_conversation_id_key" ON "place_claims"("conversation_id");
CREATE UNIQUE INDEX "place_claims_user_id_property_id_key" ON "place_claims"("user_id", "property_id");
CREATE INDEX "place_claims_status_created_at_idx" ON "place_claims"("status", "created_at");

ALTER TABLE "place_claims"
  ADD CONSTRAINT "place_claims_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "place_claims"
  ADD CONSTRAINT "place_claims_property_id_fkey"
  FOREIGN KEY ("property_id") REFERENCES "properties"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "place_claims"
  ADD CONSTRAINT "place_claims_conversation_id_fkey"
  FOREIGN KEY ("conversation_id") REFERENCES "conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;
