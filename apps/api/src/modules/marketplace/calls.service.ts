import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CallStatus, MessageKind, UserRole } from '@prisma/client';
import { AccessToken } from 'livekit-server-sdk';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { ChatEventsService } from './chat-events.service';
import { ConversationsService } from './conversations.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';

@Injectable()
export class CallsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly conversations: ConversationsService,
    private readonly lifecycle: MarketplaceLifecycleService,
    private readonly events: ChatEventsService,
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
    if (!callee) throw new BadRequestException('لا يوجد طرف آخر في المحادثة');

    const call = await this.prisma.callSession.create({
      data: {
        conversationId,
        callerId: user.id,
        calleeId: callee.userId,
        roomName: '',
        status: CallStatus.RINGING,
      },
    });
    const roomName = `call_${call.id}`;
    await this.prisma.callSession.update({ where: { id: call.id }, data: { roomName } });

    const place = conversation.property?.name ?? conversation.booking?.property?.name ?? 'المكان';
    await this.lifecycle.notifyUser({
      userId: callee.userId,
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
      peerName: callee.user.name ?? 'الموظف',
    };
  }

  async join(user: AuthUser, callId: string) {
    const call = await this.load(callId);
    this.assertParty(user, call);
    if (call.status === CallStatus.ENDED || call.status === CallStatus.MISSED) {
      throw new BadRequestException('انتهت المكالمة');
    }
    if (call.status === CallStatus.RINGING) {
      await this.prisma.callSession.update({
        where: { id: call.id },
        data: { status: CallStatus.ACTIVE, startedAt: new Date() },
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
    return { ok: true, body };
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

  private assertParty(user: AuthUser, call: { callerId: string; calleeId: string }) {
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
    const access = new AccessToken(key, secret, { identity, ttl: '10m' });
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
