-- CreateEnum
CREATE TYPE "ConversationStatus" AS ENUM ('OPEN', 'PENDING', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "ConversationPriority" AS ENUM ('LOW', 'NORMAL', 'URGENT');

-- AlterTable
ALTER TABLE "conversations" ADD COLUMN     "status"            "ConversationStatus" NOT NULL DEFAULT 'OPEN',
ADD COLUMN     "priority"          "ConversationPriority" NOT NULL DEFAULT 'NORMAL',
ADD COLUMN     "assigned_to_id"    TEXT,
ADD COLUMN     "staff_note"        TEXT NOT NULL DEFAULT '',
ADD COLUMN     "first_response_at" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "conversations_status_idx" ON "conversations"("status");
CREATE INDEX "conversations_assigned_to_id_idx" ON "conversations"("assigned_to_id");

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_assigned_to_id_fkey" FOREIGN KEY ("assigned_to_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
