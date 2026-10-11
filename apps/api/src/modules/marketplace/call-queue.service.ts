import { Injectable } from '@nestjs/common';
import {
  CallQueueState,
  CallStatus,
  ConversationPriority,
  MessageKind,
  Prisma,
  StaffPresenceState,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ChatEventsService } from './chat-events.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';

const OFFER_MS = 20_000;
const TOTAL_WAIT_MS = 90_000;
const COOLDOWN_MS = 60_000;
const HEARTBEAT_MS = 45_000;
const MAX_ATTEMPTS = 3;

@Injectable()
export class CallQueueService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: ChatEventsService,
    private readonly lifecycle: MarketplaceLifecycleService,
  ) {}

  async enqueue(callId: string, conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      select: { priority: true },
    });
    await this.prisma.callQueueItem.create({
      data: {
        callId,
        priority: conversation?.priority === ConversationPriority.URGENT ? 1 : 0,
        state: CallQueueState.WAITING,
      },
    });
    await this.dispatch();
  }

  /** يعيد توزيع العروض المنتهية والمكالمات التي تجاوزت 90 ثانية. */
  async tick() {
    await this.sweepStalePresence();
    const now = Date.now();
    const offered = await this.prisma.callQueueItem.findMany({
      where: { state: CallQueueState.OFFERED },
      include: { call: true },
      take: 50,
    });
    for (const item of offered) {
      const age = now - item.call.createdAt.getTime();
      if (age >= TOTAL_WAIT_MS) {
        await this.abandon(item.callId, 'لم يُرد الفريق');
        continue;
      }
      const offeredAt = item.call.offeredAt?.getTime() ?? item.updatedAt.getTime();
      if (now - offeredAt >= OFFER_MS) {
        await this.releaseOffer(item.callId, item.reservedAgentId, 'NO_ANSWER');
      }
    }

    const waiting = await this.prisma.callQueueItem.findMany({
      where: { state: CallQueueState.WAITING },
      include: { call: true },
      take: 50,
    });
    for (const item of waiting) {
      if (now - item.call.createdAt.getTime() >= TOTAL_WAIT_MS) {
        await this.abandon(item.callId, 'لم يُرد الفريق');
      }
    }
    await this.dispatch();
  }

  private async sweepStalePresence() {
    const cutoff = new Date(Date.now() - HEARTBEAT_MS);
    const stale = await this.prisma.staffPresence.findMany({
      where: {
        state: { not: StaffPresenceState.OFFLINE },
        user: { staffProfile: { lastSeenAt: { lt: cutoff } } },
      },
    });
    for (const row of stale) {
      if (row.state === StaffPresenceState.IN_CALL && row.activeCallId) {
        await this.prisma.callSession.updateMany({
          where: { id: row.activeCallId, status: CallStatus.ACTIVE },
          data: { status: CallStatus.ENDED, endedAt: new Date() },
        });
      }
      if (row.state === StaffPresenceState.RINGING && row.activeCallId) {
        await this.releaseOffer(row.activeCallId, row.userId, 'AGENT_DROPPED');
      }
      await this.prisma.staffPresence.update({
        where: { userId: row.userId },
        data: { state: StaffPresenceState.OFFLINE, activeCallId: null },
      });
    }
  }

  async dispatch() {
    for (let n = 0; n < 8; n++) {
      const placed = await this.prisma.$transaction(async (tx) => this.offerNext(tx));
      if (!placed) break;
    }
  }

  private async offerNext(tx: Prisma.TransactionClient) {
    const item = await tx.callQueueItem.findFirst({
      where: { state: { in: [CallQueueState.WAITING, CallQueueState.OFFERED] }, reservedAgentId: null },
      orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
      include: { call: { include: { conversation: true } } },
    });
    if (!item || item.call.status !== CallStatus.RINGING) return false;
    if (item.call.queueAttempt >= MAX_ATTEMPTS) {
      const cooled = await tx.callAgentOffer.findMany({
        where: { callId: item.callId, createdAt: { gt: new Date(Date.now() - COOLDOWN_MS) } },
        select: { agentId: true },
      });
      const blocked = cooled.map((row) => row.agentId);
      const agent = await this.pickAgent(tx, item.call.conversation.assignedToId, blocked);
      if (!agent) return false;
      await this.assign(tx, item, agent.id);
      return true;
    }
    const agent = await this.pickAgent(tx, item.call.conversation.assignedToId, []);
    if (!agent) return false;
    await this.assign(tx, item, agent.id);
    return true;
  }

  private async pickAgent(tx: Prisma.TransactionClient, preferredId: string | null, exclude: string[]) {
    const fresh = new Date(Date.now() - HEARTBEAT_MS);
    const blocked = exclude.length ? exclude : ['00000000-0000-0000-0000-000000000000'];
    const rows = await tx.$queryRaw<Array<{ user_id: string }>>`
      SELECT p.user_id
      FROM staff_presence p
      JOIN staff_profiles s ON s.user_id = p.user_id
      JOIN users u ON u.id = p.user_id
      WHERE p.state = 'AVAILABLE'
        AND p.active_call_id IS NULL
        AND s.is_active = true
        AND u.is_active = true
        AND 'calls.answer' = ANY(s.permissions)
        AND (s.last_seen_at IS NULL OR s.last_seen_at > ${fresh})
        AND NOT (p.user_id = ANY(${blocked}))
        ORDER BY p.last_offered_at ASC NULLS FIRST
      FOR UPDATE OF p SKIP LOCKED
      LIMIT 8
    `;
    if (!rows.length) return null;
    const preferred = preferredId ? rows.find((row) => row.user_id === preferredId) : undefined;
    return { id: (preferred ?? rows[0]).user_id };
  }

  private async assign(
    tx: Prisma.TransactionClient,
    item: { callId: string; call: { conversationId: string; callerId: string; queueAttempt: number } },
    agentId: string,
  ) {
    const now = new Date();
    await tx.callSession.update({
      where: { id: item.callId },
      data: {
        calleeId: agentId,
        offeredAt: now,
        queueAttempt: { increment: 1 },
        declineReason: null,
      },
    });
    await tx.callQueueItem.update({
      where: { callId: item.callId },
      data: { state: CallQueueState.OFFERED, reservedAgentId: agentId },
    });
    await tx.staffPresence.update({
      where: { userId: agentId },
      data: { state: StaffPresenceState.RINGING, activeCallId: item.callId, lastOfferedAt: now },
    });
    await tx.callAgentOffer.create({ data: { callId: item.callId, agentId } });
    const place = 'مكالمة';
    void this.lifecycle.notifyUser({
      userId: agentId,
      type: 'MESSAGE',
      title: 'مكالمة واردة',
      body: place,
      linkUrl: `/staff/call/${item.callId}`,
      entityType: 'call',
      entityId: item.callId,
    });
    this.events.emit(item.call.conversationId, { type: 'call-offered', callId: item.callId, agentId });
  }

  async releaseOffer(callId: string, agentId: string | null, reason: 'NO_ANSWER' | 'DECLINED' | 'AGENT_DROPPED') {
    await this.prisma.$transaction(async (tx) => {
      const call = await tx.callSession.findUnique({ where: { id: callId } });
      if (!call || call.status !== CallStatus.RINGING) return;
      await tx.callSession.update({
        where: { id: callId },
        data: { calleeId: null, declineReason: reason },
      });
      await tx.callQueueItem.updateMany({
        where: { callId, state: CallQueueState.OFFERED },
        data: { state: CallQueueState.WAITING, reservedAgentId: null },
      });
      if (agentId) {
        await tx.staffPresence.updateMany({
          where: { userId: agentId, activeCallId: callId, state: StaffPresenceState.RINGING },
          data: { state: StaffPresenceState.AVAILABLE, activeCallId: null },
        });
      }
    });
    await this.dispatch();
  }

  async markAnswered(callId: string, agentId: string) {
    await this.prisma.callQueueItem.updateMany({
      where: { callId },
      data: { state: CallQueueState.ANSWERED, reservedAgentId: agentId },
    });
    await this.prisma.staffPresence.updateMany({
      where: { userId: agentId },
      data: { state: StaffPresenceState.IN_CALL, activeCallId: callId },
    });
  }

  async finishCall(callId: string, agentId: string | null) {
    await this.prisma.callQueueItem.updateMany({
      where: { callId, state: { not: CallQueueState.ABANDONED } },
      data: { state: CallQueueState.ANSWERED },
    });
    if (!agentId) return;
    await this.prisma.staffPresence.updateMany({
      where: { userId: agentId, activeCallId: callId },
      data: { state: StaffPresenceState.WRAP_UP, activeCallId: null },
    });
    setTimeout(() => {
      void this.prisma.staffPresence.updateMany({
        where: { userId: agentId, state: StaffPresenceState.WRAP_UP },
        data: { state: StaffPresenceState.AVAILABLE },
      }).then(() => this.dispatch());
    }, 20_000);
  }

  async abandon(callId: string, body: string) {
    const call = await this.prisma.callSession.findUnique({ where: { id: callId } });
    if (!call || call.status !== CallStatus.RINGING) return;
    await this.prisma.callSession.update({
      where: { id: callId },
      data: { status: CallStatus.MISSED, endedAt: new Date(), calleeId: null },
    });
    await this.prisma.callQueueItem.updateMany({
      where: { callId },
      data: { state: CallQueueState.ABANDONED, reservedAgentId: null },
    });
    if (call.calleeId) {
      await this.prisma.staffPresence.updateMany({
        where: { userId: call.calleeId, activeCallId: callId },
        data: { state: StaffPresenceState.AVAILABLE, activeCallId: null },
      });
    }
    const message = await this.prisma.message.create({
      data: {
        conversationId: call.conversationId,
        senderId: call.callerId,
        kind: MessageKind.CALL,
        body,
      },
    });
    this.events.emit(call.conversationId, message);
    this.events.emit(call.conversationId, { type: 'call-ended', callId, status: CallStatus.MISSED });
  }

  isStaff(role: UserRole) {
    return role === UserRole.STAFF || role === UserRole.ADMIN;
  }
}
