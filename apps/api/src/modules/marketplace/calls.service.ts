import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CallQueueState, CallStatus, MessageKind, StaffPresenceState, UserRole } from '@prisma/client';
import { AccessToken } from 'livekit-server-sdk';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { ChatEventsService } from './chat-events.service';
import { ConversationsService } from './conversations.service';
import { CallQueueService } from './call-queue.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';

@Injectable()
export class CallsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly conversations: ConversationsService,
    private readonly lifecycle: MarketplaceLifecycleService,
    private readonly events: ChatEventsService,
    private readonly queue: CallQueueService,
  ) {}

  async start(user: AuthUser, input: { propertyId?: string; conversationId?: string; bookingId?: string }) {
    const conversationId = await this.resolveConversation(user, input);
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        property: { select: { name: true } },
        booking: { select: { property: { select: { name: true } } } },
        participants: { select: { userId: true, user: { select: { name: true } } } },
      },
    });
    if (!conversation) throw new NotFoundException('المحادثة غير موجودة');
    const callee = conversation.participants.find((p) => p.userId !== user.id);
    const staffCaller = this.queue.isStaff(user.role);
    if (staffCaller && !callee) throw new BadRequestException('لا يوجد طرف آخر في المحادثة');

    const existing = await this.prisma.callSession.findFirst({
      where: {
        conversationId,
        callerId: user.id,
        status: { in: [CallStatus.RINGING, CallStatus.ACTIVE] },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (existing && !staffCaller) {
      return this.publicCall(existing.id, user.id, 'caller');
    }

    const call = await this.prisma.callSession.create({
      data: {
        conversationId,
        callerId: user.id,
        calleeId: staffCaller ? callee!.userId : null,
        roomName: '',
        status: CallStatus.RINGING,
      },
    });
    const roomName = `call_${call.id}`;
    await this.prisma.callSession.update({ where: { id: call.id }, data: { roomName } });

    const place = conversation.property?.name ?? conversation.booking?.property?.name ?? 'المكان';
    if (!staffCaller) {
      await this.queue.enqueue(call.id, conversationId);
      return {
        callId: call.id,
        conversationId,
        room: roomName,
        place,
        peerName: 'الدعم',
        role: 'caller',
        queue: 'WAITING',
      };
    }
    await this.lifecycle.notifyUser({
      userId: callee!.userId,
      type: 'MESSAGE',
      title: `اتصال بخصوص ${place}`,
      body: 'مكالمة واردة داخل التطبيق',
      linkUrl: `/chat/${conversationId}?call=${call.id}`,
      entityType: 'call',
      entityId: call.id,
    });

    const access = await this.token(user.id, roomName);
    return {
      callId: call.id,
      conversationId,
      room: roomName,
      ...access,
      place,
      peerName: callee!.user.name ?? 'الموظف',
      role: 'caller',
    };
  }

  async join(user: AuthUser, callId: string) {
    const call = await this.load(callId);
    this.assertParty(user, call);
    if (call.status === CallStatus.ENDED || call.status === CallStatus.MISSED) {
      throw new BadRequestException('انتهت المكالمة');
    }
    if (call.status === CallStatus.RINGING && user.id !== call.calleeId) {
      const queued = await this.prisma.callQueueItem.findUnique({ where: { callId: call.id } });
      return {
        callId: call.id,
        conversationId: call.conversationId,
        room: call.roomName,
        queue: queued?.state ?? 'WAITING',
        role: 'caller',
        place: 'مكالمة',
        peerName: 'الدعم',
      };
    }
    if (call.status === CallStatus.RINGING && call.calleeId && user.id === call.calleeId) {
      await this.prisma.callSession.update({
        where: { id: call.id },
        data: { status: CallStatus.ACTIVE, startedAt: new Date() },
      });
      await this.queue.markAnswered(call.id, user.id);
      // أبلغ المتصل أن الطرف الآخر أجاب — عبر قناة المحادثة الحية
      this.events.emit(call.conversationId, {
        type: 'call-answered',
        callId: call.id,
        by: user.id,
      });
    }
    const access = await this.token(user.id, call.roomName);
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: call.conversationId },
      include: {
        property: { select: { name: true } },
        booking: { select: { property: { select: { name: true } } } },
        participants: { include: { user: { select: { id: true, name: true } } } },
      },
    });
    const peer = conversation?.participants.find((p) => p.userId !== user.id);
    return {
      callId: call.id,
      conversationId: call.conversationId,
      room: call.roomName,
      ...access,
      place: conversation?.property?.name ?? conversation?.booking?.property?.name ?? 'مكالمة',
      peerName: peer?.user.name ?? '',
    };
  }

  async end(user: AuthUser, callId: string) {
    const call = await this.load(callId);
    this.assertParty(user, call);
    if (call.status === CallStatus.ENDED || call.status === CallStatus.MISSED) {
      return { ok: true };
    }
    const endedAt = new Date();
    const missed = call.status === CallStatus.RINGING;
    await this.prisma.callSession.update({
      where: { id: call.id },
      data: {
        status: missed ? CallStatus.MISSED : CallStatus.ENDED,
        endedAt,
        startedAt: call.startedAt,
      },
    });
    const seconds = call.startedAt
      ? Math.max(1, Math.round((endedAt.getTime() - call.startedAt.getTime()) / 1000))
      : 0;
    const body = missed ? 'مكالمة لم يُرد عليها' : `مكالمة، ${this.formatDuration(seconds)}`;
    const message = await this.prisma.message.create({
      data: {
        conversationId: call.conversationId,
        senderId: user.id,
        kind: MessageKind.CALL,
        body,
      },
      include: { sender: { select: { id: true, name: true, phone: true, role: true } } },
    });
    await this.prisma.conversation.update({
      where: { id: call.conversationId },
      data: { updatedAt: new Date() },
    });
    this.events.emit(call.conversationId, message);
    this.events.emit(call.conversationId, {
      type: 'call-ended',
      callId: call.id,
      status: missed ? CallStatus.MISSED : CallStatus.ENDED,
    });
    if (missed) {
      await this.prisma.callQueueItem.updateMany({
        where: { callId: call.id },
        data: { state: CallQueueState.ABANDONED, reservedAgentId: null },
      });
      if (call.calleeId) {
        await this.prisma.staffPresence.updateMany({
          where: { userId: call.calleeId, activeCallId: call.id },
          data: { state: StaffPresenceState.AVAILABLE, activeCallId: null },
        });
      }
      await this.queue.dispatch();
    } else {
      await this.queue.finishCall(call.id, call.calleeId);
    }
    return { ok: true, body };
  }

  /// رفض المكالمة من الطرف المتلقّي — يسجّلها فائتة فوراً
  async decline(user: AuthUser, callId: string) {
    const call = await this.load(callId);
    this.assertParty(user, call);
    if (call.status !== CallStatus.RINGING) {
      return { ok: true, status: call.status };
    }
    const queued = await this.prisma.callQueueItem.findUnique({ where: { callId: call.id } });
    if (queued && user.id === call.calleeId && user.id !== call.callerId) {
      await this.queue.releaseOffer(call.id, user.id, 'DECLINED');
      return { ok: true, status: CallStatus.RINGING, requeued: true };
    }
    await this.prisma.callSession.update({
      where: { id: call.id },
      data: { status: CallStatus.MISSED, endedAt: new Date() },
    });
    const message = await this.prisma.message.create({
      data: {
        conversationId: call.conversationId,
        senderId: user.id,
        kind: MessageKind.CALL,
        body: 'مكالمة مرفوضة',
      },
      include: { sender: { select: { id: true, name: true, phone: true, role: true } } },
    });
    this.events.emit(call.conversationId, message);
    this.events.emit(call.conversationId, {
      type: 'call-declined',
      callId: call.id,
      status: CallStatus.MISSED,
    });
    return { ok: true, status: CallStatus.MISSED };
  }

  /// مكالمة ترن الآن للمستخدم — لطبقة الرنين في التطبيق
  async incomingRinging(user: AuthUser) {
    await this.expireStaleRinging();
    const rows = await this.prisma.callSession.findMany({
      where: { calleeId: user.id, status: CallStatus.RINGING },
      orderBy: { createdAt: 'desc' },
      take: 1,
    });
    const call = rows[0];
    if (!call) return { call: null };

    const conversation = await this.prisma.conversation.findUnique({
      where: { id: call.conversationId },
      include: {
        property: { select: { id: true, name: true } },
        booking: { select: { property: { select: { id: true, name: true } } } },
        participants: { include: { user: { select: { id: true, name: true } } } },
      },
    });
    const caller = conversation?.participants.find(
      (p) => p.userId === call.callerId,
    );
    return {
      call: {
        id: call.id,
        createdAt: call.createdAt,
        expiresInSeconds: Math.max(
          0,
          Math.round(
            (call.createdAt.getTime() + this.ringingTimeoutMs() - Date.now()) / 1000,
          ),
        ),
        conversationId: call.conversationId,
        place:
          conversation?.property?.name ??
          conversation?.booking?.property?.name ??
          'مكالمة',
        callerName: caller?.user.name ?? 'VIBES',
      },
    };
  }

  /// سجل مكالمات محادثة — لعرضه في التطبيق ولوحة الفريق
  async history(user: AuthUser, conversationId: string) {
    await this.conversations.ensureAccess(user, conversationId);
    return this.prisma.callSession.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: {
        id: true,
        status: true,
        createdAt: true,
        startedAt: true,
        endedAt: true,
        caller: { select: { id: true, name: true } },
        callee: { select: { id: true, name: true } },
      },
    });
  }

  /// يُنهي مكالمات الرنين المتجاوزة مهلتها — يُستدعى دورياً وعند القراءة
  async expireStaleRinging() {
    await this.queue.tick();
    const cutoff = new Date(Date.now() - this.ringingTimeoutMs());
    const stale = await this.prisma.callSession.findMany({
      where: {
        status: CallStatus.RINGING,
        createdAt: { lt: cutoff },
        queue: { is: null },
      },
      take: 100,
    });
    for (const call of stale) {
      await this.prisma.callSession.update({
        where: { id: call.id },
        data: { status: CallStatus.MISSED, endedAt: new Date() },
      });
      const message = await this.prisma.message.create({
        data: {
          conversationId: call.conversationId,
          senderId: call.callerId,
          kind: MessageKind.CALL,
          body: 'مكالمة لم يُرد عليها',
        },
      });
      this.events.emit(call.conversationId, message);
      this.events.emit(call.conversationId, {
        type: 'call-ended',
        callId: call.id,
        status: CallStatus.MISSED,
      });
    }
    return stale.length;
  }

  private ringingTimeoutMs() {
    const seconds = Number(process.env.CALL_RINGING_TIMEOUT_SECONDS ?? 45);
    return (seconds > 0 ? seconds : 45) * 1000;
  }

  private async resolveConversation(
    user: AuthUser,
    input: { propertyId?: string; conversationId?: string; bookingId?: string },
  ) {
    if (input.conversationId) {
      await this.conversations.ensureAccess(user, input.conversationId);
      return input.conversationId;
    }
    if (input.bookingId) {
      const opened = await this.conversations.openForBooking(user, input.bookingId);
      return opened.id;
    }
    if (input.propertyId) {
      const opened = await this.conversations.openForProperty(user, input.propertyId);
      return opened.id;
    }
    throw new BadRequestException('حدد المكان أو المحادثة');
  }

  private async load(id: string) {
    const call = await this.prisma.callSession.findUnique({ where: { id } });
    if (!call) throw new NotFoundException('المكالمة غير موجودة');
    return call;
  }

  async snapshot(user: AuthUser, callId: string) {
    const call = await this.load(callId);
    this.assertParty(user, call);
    const queued = await this.prisma.callQueueItem.findUnique({ where: { callId } });
    const base = {
      callId: call.id,
      conversationId: call.conversationId,
      status: call.status,
      queue: queued?.state ?? null,
      room: call.roomName,
    };
    if (call.status !== CallStatus.ACTIVE) return base;
    const access = await this.token(user.id, call.roomName);
    return { ...base, ...access };
  }

  async reportQuality(
    user: AuthUser,
    callId: string,
    input: { rttMs?: number; packetLossPct?: number; reconnects?: number },
  ) {
    const call = await this.load(callId);
    this.assertParty(user, call);
    await this.prisma.callSession.update({
      where: { id: callId },
      data: {
        rttMs: input.rttMs,
        packetLossPct: input.packetLossPct,
        reconnects: input.reconnects,
      },
    });
    return { ok: true };
  }

  private async publicCall(callId: string, userId: string, role: string) {
    const call = await this.load(callId);
    const queued = await this.prisma.callQueueItem.findUnique({ where: { callId } });
    return {
      callId: call.id,
      conversationId: call.conversationId,
      room: call.roomName,
      place: 'مكالمة',
      peerName: 'الدعم',
      role,
      queue: queued?.state ?? null,
      status: call.status,
    };
  }

  private assertParty(user: AuthUser, call: { callerId: string; calleeId: string | null }) {
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    if (!staff && user.id !== call.callerId && user.id !== call.calleeId) {
      throw new ForbiddenException('غير مسموح');
    }
  }

  private async token(identity: string, room: string) {
    const key = process.env.LIVEKIT_API_KEY;
    const secret = process.env.LIVEKIT_API_SECRET;
    const url = process.env.LIVEKIT_URL;
    if (!key || !secret || !url) {
      throw new ServiceUnavailableException('المكالمة غير متاحة الآن');
    }
    const access = new AccessToken(key, secret, { identity, ttl: '12m' });
    access.addGrant({
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
      canPublishData: false,
    });
    return { token: await access.toJwt(), url };
  }

  private formatDuration(totalSeconds: number) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    if (minutes <= 0) return `${seconds} ث`;
    return `${minutes} د`;
  }
}
