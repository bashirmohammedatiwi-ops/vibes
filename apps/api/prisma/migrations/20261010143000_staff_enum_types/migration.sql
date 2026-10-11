CREATE TYPE "StaffPresenceState" AS ENUM ('AVAILABLE', 'RINGING', 'IN_CALL', 'WRAP_UP', 'AWAY', 'OFFLINE');
CREATE TYPE "CallQueueState" AS ENUM ('WAITING', 'OFFERED', 'ANSWERED', 'ABANDONED');
CREATE TYPE "CallDeclineReason" AS ENUM ('NO_ANSWER', 'DECLINED', 'AGENT_DROPPED');

ALTER TABLE "staff_presence" ALTER COLUMN "state" DROP DEFAULT;
ALTER TABLE "staff_presence"
  ALTER COLUMN "state" TYPE "StaffPresenceState"
  USING "state"::"StaffPresenceState";
ALTER TABLE "staff_presence" ALTER COLUMN "state" SET DEFAULT 'OFFLINE';

ALTER TABLE "call_queue_items" ALTER COLUMN "state" DROP DEFAULT;
ALTER TABLE "call_queue_items"
  ALTER COLUMN "state" TYPE "CallQueueState"
  USING "state"::"CallQueueState";
ALTER TABLE "call_queue_items" ALTER COLUMN "state" SET DEFAULT 'WAITING';

ALTER TABLE "call_sessions"
  ALTER COLUMN "decline_reason" TYPE "CallDeclineReason"
  USING "decline_reason"::"CallDeclineReason";
