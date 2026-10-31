import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  BookingStatus,
  CallQueueState,
  ConversationPriority,
  PaymentStatus,
  PropertyStatus,
  RequestStatus,
  StaffPresenceState,
  UserRole,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { hashPin } from '../auth/pin-hash';
import { PrismaService } from '../../prisma/prisma.service';
import { CallQueueService } from '../marketplace/call-queue.service';
import { ConversationsService } from '../marketplace/conversations.service';
import {
  expandStaffPermissions,
  isStaffPermission,
  STAFF_PERMISSION_LABELS,
  STAFF_PERMISSIONS,
  STAFF_TEMPLATES,
  STAFF_PERMISSION_GROUPS,
  StaffPermission,
} from './staff.permissions';

@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly queue: CallQueueService,
    private readonly conversations: ConversationsService,
  ) {}

  templates() {
    return {
      permissions: STAFF_PERMISSIONS,
      labels: STAFF_PERMISSION_LABELS,
      templates: STAFF_TEMPLATES,
      groups: STAFF_PERMISSION_GROUPS,
    };
  }

  async listForAdmin() {
    const rows = await this.prisma.staffProfile.findMany({
      include: {
        user: { select: { id: true, phone: true, name: true, role: true, isActive: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    const presence = await this.prisma.staffPresence.findMany();
    const byUser = new Map(presence.map((row) => [row.userId, row]));
    return rows.map((row) => ({
      ...row,
      presence: byUser.get(row.userId) ?? null,
    }));
  }

  async createStaff(input: {
    phone: string;
    name: string;
    pin: string;
    permissions: string[];
    isActive?: boolean;
  }) {
    const permissions = this.cleanPermissions(input.permissions);
    if (!/^\d{4,6}$/.test(input.pin)) throw new BadRequestException('الرمز من 4 إلى 6 أرقام');
    const phone = input.phone.trim();
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing && existing.role !== UserRole.STAFF && existing.role !== UserRole.CUSTOMER) {
      throw new BadRequestException('هذا الهاتف مرتبط بحساب آخر');
    }
    const user = existing
      ? await this.prisma.user.update({
          where: { id: existing.id },
          data: {
            role: UserRole.STAFF,
            name: input.name,
            pinHash: hashPin(input.pin),
            isActive: input.isActive ?? true,
          },
        })
      : await this.prisma.user.create({
          data: {
            phone,
            name: input.name,
            role: UserRole.STAFF,
            pinHash: hashPin(input.pin),
            isActive: input.isActive ?? true,
          },
        });
    const profile = await this.prisma.staffProfile.upsert({
      where: { userId: user.id },
      update: {
        displayName: input.name,
        permissions,
        isActive: input.isActive ?? true,
      },
      create: {
        userId: user.id,
        displayName: input.name,
        permissions,
        isActive: input.isActive ?? true,
      },
    });
    await this.prisma.staffPresence.upsert({
      where: { userId: user.id },
      update: {},
      create: { userId: user.id, state: StaffPresenceState.OFFLINE },
    });
    return profile;
  }

  async updateStaff(
    id: string,
    input: { name?: string; permissions?: string[]; isActive?: boolean; pin?: string },
  ) {
    const profile = await this.prisma.staffProfile.findUnique({ where: { id } });
    if (!profile) throw new NotFoundException('الموظف غير موجود');
    const permissions = input.permissions ? this.cleanPermissions(input.permissions) : undefined;
    const updated = await this.prisma.staffProfile.update({
      where: { id },
      data: {
        displayName: input.name,
        permissions,
        isActive: input.isActive,
      },
    });
    await this.prisma.user.update({
      where: { id: profile.userId },
      data: {
        name: input.name,
        isActive: input.isActive,
        pinHash: input.pin ? hashPin(input.pin) : undefined,
      },
    });
    if (input.isActive === false) {
      await this.prisma.staffPresence.updateMany({
        where: { userId: profile.userId },
        data: { state: StaffPresenceState.OFFLINE, activeCallId: null },
      });
      await this.prisma.refreshToken.deleteMany({ where: { userId: profile.userId } });
      await this.prisma.callQueueItem.updateMany({
        where: { reservedAgentId: profile.userId, state: CallQueueState.OFFERED },
        data: { state: CallQueueState.WAITING, reservedAgentId: null },
      });
    }
    return updated;
  }

  async me(user: AuthUser) {
    this.assertOffice(user);
    if (user.role === UserRole.ADMIN) {
      return {
        id: user.id,
        role: user.role,
        permissions: [...STAFF_PERMISSIONS],
        displayName: 'مدير',
        isActive: true,
        presenceState: StaffPresenceState.AVAILABLE,
        catalog: { labels: STAFF_PERMISSION_LABELS, groups: STAFF_PERMISSION_GROUPS },
      };
    }
    const profile = await this.prisma.staffProfile.findUnique({
      where: { userId: user.id },
      include: { user: { select: { name: true, phone: true } } },
    });
    if (!profile?.isActive) throw new ForbiddenException('الحساب موقوف');
    const presence = await this.prisma.staffPresence.findUnique({ where: { userId: user.id } });
    return {
      id: user.id,
      role: user.role,
      permissions: expandStaffPermissions(profile.permissions),
      displayName: profile.displayName,
      phone: profile.user.phone,
      isActive: profile.isActive,
      presenceState: presence?.state ?? StaffPresenceState.OFFLINE,
      catalog: { labels: STAFF_PERMISSION_LABELS, groups: STAFF_PERMISSION_GROUPS },
    };
  }

  async setPresence(user: AuthUser, state: 'AVAILABLE' | 'AWAY', deviceId?: string) {
    await this.me(user);
    if (state === 'AVAILABLE') await this.require(user, 'calls.answer');
    const now = new Date();
    await this.prisma.staffProfile.updateMany({
      where: { userId: user.id },
      data: { lastSeenAt: now },
    });
    return this.prisma.staffPresence.upsert({
      where: { userId: user.id },
      update: {
        state: state === 'AVAILABLE' ? StaffPresenceState.AVAILABLE : StaffPresenceState.AWAY,
        deviceId,
        activeCallId: null,
      },
      create: {
        userId: user.id,
        state: state === 'AVAILABLE' ? StaffPresenceState.AVAILABLE : StaffPresenceState.AWAY,
        deviceId,
      },
    });
  }

  async heartbeat(user: AuthUser, deviceId?: string) {
    await this.me(user);
    const now = new Date();
    await this.prisma.staffProfile.updateMany({
      where: { userId: user.id },
      data: { lastSeenAt: now },
    });
    const current = await this.prisma.staffPresence.findUnique({ where: { userId: user.id } });
    if (current?.deviceId && deviceId && current.deviceId !== deviceId) {
      return { ok: true, takenOver: true, state: current.state };
    }
    if (current) {
      await this.prisma.staffPresence.update({
        where: { userId: user.id },
        data: { deviceId: deviceId ?? current.deviceId },
      });
    }
    return { ok: true, state: current?.state ?? StaffPresenceState.OFFLINE };
  }

  async ringing(user: AuthUser) {
    await this.require(user, 'calls.answer');
    const presence = await this.prisma.staffPresence.findUnique({ where: { userId: user.id } });
    if (!presence?.activeCallId || presence.state !== StaffPresenceState.RINGING) {
      return { call: null };
    }
    const call = await this.prisma.callSession.findUnique({
      where: { id: presence.activeCallId },
      include: {
        caller: { select: { name: true, phone: true } },
        conversation: {
          include: {
            property: { select: { name: true } },
            booking: { select: { id: true, status: true, property: { select: { name: true } } } },
          },
        },
      },
    });
    if (!call || call.status !== 'RINGING') return { call: null };
    return {
      call: {
        id: call.id,
        conversationId: call.conversationId,
        callerId: call.callerId,
        callerName: call.caller.name ?? 'زبون',
        callerPhone: call.caller.phone,
        place: call.conversation.property?.name ?? call.conversation.booking?.property?.name ?? 'دعم',
        bookingId: call.conversation.booking?.id ?? null,
        bookingStatus: call.conversation.booking?.status ?? null,
      },
    };
  }

  async queueSummary(user: AuthUser) {
    if (user.role !== UserRole.ADMIN) {
      const profile = await this.prisma.staffProfile.findUnique({ where: { userId: user.id } });
      const ok = profile?.permissions.includes('calls.answer') || profile?.permissions.includes('calls.monitor');
      if (!ok) throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
    const waiting = await this.prisma.callQueueItem.count({
      where: { state: { in: [CallQueueState.WAITING, CallQueueState.OFFERED] } },
    });
    return { waiting };
  }

  /** طابور الانتظار مع بيانات المتصل */
  async queueWaiting(user: AuthUser) {
    if (user.role !== UserRole.ADMIN) {
      const profile = await this.prisma.staffProfile.findUnique({ where: { userId: user.id } });
      const ok = profile?.permissions.includes('calls.answer') || profile?.permissions.includes('calls.monitor');
      if (!ok) throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
    const items = await this.prisma.callQueueItem.findMany({
      where: { state: { in: [CallQueueState.WAITING, CallQueueState.OFFERED] } },
      orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
      take: 25,
      include: {
        call: {
          include: {
            caller: { select: { id: true, name: true, phone: true } },
            conversation: {
              include: {
                property: { select: { name: true } },
                booking: { select: { property: { select: { name: true } } } },
              },
            },
          },
        },
      },
    });
    return {
      items: items.map((row) => ({
        id: row.id,
        callId: row.callId,
        state: row.state,
        priority: row.priority,
        waitedSeconds: Math.max(0, Math.round((Date.now() - row.createdAt.getTime()) / 1000)),
        callerId: row.call.callerId,
        callerName: row.call.caller.name ?? 'زبون',
        callerPhone: row.call.caller.phone,
        conversationId: row.call.conversationId,
        place:
          row.call.conversation.property?.name ??
          row.call.conversation.booking?.property?.name ??
          'دعم',
      })),
    };
  }

  /** آخر المكالمات للموظف / المشرف */
  async recentCalls(user: AuthUser) {
    const canMonitor = await this.hasPermission(user, 'calls.monitor');
    const canAnswer = await this.hasPermission(user, 'calls.answer');
    if (!canMonitor && !canAnswer) throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    const where = canMonitor
      ? {}
      : { OR: [{ calleeId: user.id }, { callerId: user.id }] };
    const rows = await this.prisma.callSession.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 20,
      select: {
        id: true,
        status: true,
        createdAt: true,
        startedAt: true,
        endedAt: true,
        conversationId: true,
        packetLossPct: true,
        rttMs: true,
        caller: { select: { id: true, name: true, phone: true } },
        callee: { select: { id: true, name: true, phone: true } },
        conversation: {
          select: {
            property: { select: { name: true } },
            booking: { select: { property: { select: { name: true } } } },
          },
        },
      },
    });
    return {
      items: rows.map((c) => ({
        id: c.id,
        status: c.status,
        createdAt: c.createdAt,
        startedAt: c.startedAt,
        endedAt: c.endedAt,
        conversationId: c.conversationId,
        packetLossPct: c.packetLossPct,
        rttMs: c.rttMs,
        durationSeconds:
          c.startedAt && c.endedAt
            ? Math.max(0, Math.round((c.endedAt.getTime() - c.startedAt.getTime()) / 1000))
            : null,
        caller: c.caller,
        callee: c.callee,
        place: c.conversation.property?.name ?? c.conversation.booking?.property?.name ?? 'مكالمة',
      })),
    };
  }

  async supervisorForStaff(user: AuthUser) {
    await this.require(user, 'calls.monitor');
    return this.supervisorBoard();
  }

  async supervisorBoard() {
    const presence = await this.prisma.staffPresence.findMany({
      include: { user: { select: { name: true, phone: true } } },
    });
    const waiting = await this.prisma.callQueueItem.count({
      where: { state: { in: [CallQueueState.WAITING, CallQueueState.OFFERED] } },
    });
    const since = new Date();
    since.setHours(0, 0, 0, 0);
    const [answered, missed, quality] = await Promise.all([
      this.prisma.callSession.count({
        where: { status: 'ENDED', startedAt: { gte: since } },
      }),
      this.prisma.callSession.count({
        where: { status: 'MISSED', createdAt: { gte: since } },
      }),
      this.prisma.callSession.aggregate({
        where: { endedAt: { gte: since }, packetLossPct: { not: null } },
        _avg: { packetLossPct: true },
      }),
    ]);
    return {
      agents: presence,
      waiting,
      answeredToday: answered,
      missedToday: missed,
      avgPacketLoss: quality._avg.packetLossPct,
    };
  }

  async inbox(user: AuthUser) {
    await this.require(user, 'inbox.read');
    return this.prisma.conversation.findMany({
      where: {
        OR: [{ assignedToId: user.id }, { assignedToId: null }],
      },
      orderBy: [{ priority: 'desc' }, { updatedAt: 'desc' }],
      take: 40,
      include: {
        guest: { select: { name: true, phone: true } },
        property: { select: { name: true } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1, select: { body: true, createdAt: true } },
      },
    });
  }

  async reply(user: AuthUser, conversationId: string, body: string) {
    await this.require(user, 'inbox.reply');
    return this.conversations.send(user, conversationId, { body });
  }

  /** قائمة جهات اتصال — محادثة واحدة لكل زبون (مثل واتساب) */
  async chatContacts(user: AuthUser) {
    await this.require(user, 'inbox.read');
    const rows = await this.conversations.list(user);
    type Bucket = {
      user: { id: string; name: string | null; phone: string | null };
      conversations: Array<{
        id: string;
        kind: string;
        status: string;
        priority: string;
        property: unknown;
        unread: number;
        updatedAt: string;
      }>;
      unread: number;
      lastMessage: { body: string; createdAt: string; kind?: string } | null;
      lastAt: number;
      primaryConversationId: string;
      propertyName: string | null;
    };
    const byGuest = new Map<string, Bucket>();
    for (const row of rows) {
      const guest =
        row.participants.find((p) => p.role === UserRole.CUSTOMER) ??
        row.participants.find((p) => p.id !== user.id && p.role !== UserRole.STAFF && p.role !== UserRole.ADMIN);
      if (!guest) continue;
      let bucket = byGuest.get(guest.id);
      if (!bucket) {
        bucket = {
          user: { id: guest.id, name: guest.name, phone: guest.phone },
          conversations: [],
          unread: 0,
          lastMessage: null,
          lastAt: 0,
          primaryConversationId: row.id,
          propertyName: null,
        };
        byGuest.set(guest.id, bucket);
      }
      const property = row.property as { name?: string } | null;
      bucket.conversations.push({
        id: row.id,
        kind: row.kind,
        status: row.status,
        priority: row.priority,
        property: row.property,
        unread: row.unread,
        updatedAt: row.updatedAt instanceof Date ? row.updatedAt.toISOString() : String(row.updatedAt),
      });
      bucket.unread += row.unread;
      const rowTime = new Date(row.updatedAt).getTime();
      if (rowTime >= bucket.lastAt) {
        bucket.lastAt = rowTime;
        bucket.lastMessage = row.lastMessage
          ? {
              body: row.lastMessage.body,
              createdAt:
                row.lastMessage.createdAt instanceof Date
                  ? row.lastMessage.createdAt.toISOString()
                  : String(row.lastMessage.createdAt),
              kind: row.lastMessage.kind,
            }
          : null;
        bucket.primaryConversationId = row.id;
        bucket.propertyName = property?.name ?? null;
      }
    }
    const items = Array.from(byGuest.values())
      .sort((a, b) => b.lastAt - a.lastAt)
      .map((b) => ({
        user: b.user,
        primaryConversationId: b.primaryConversationId,
        propertyName: b.propertyName,
        unread: b.unread,
        lastMessage: b.lastMessage,
        lastAt: b.lastAt ? new Date(b.lastAt).toISOString() : null,
        conversationCount: b.conversations.length,
        conversations: b.conversations,
      }));
    return { items };
  }

  async customerProfile(user: AuthUser, userId: string) {
    await this.require(user, 'users.read');
    const customer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, phone: true, createdAt: true },
    });
    if (!customer) throw new NotFoundException('الزبون غير موجود');
    const [bookings, conversations, spend] = await Promise.all([
      this.prisma.booking.findMany({
        where: { userId },
        take: 12,
        orderBy: { createdAt: 'desc' },
        include: {
          property: { select: { name: true } },
          payment: { select: { id: true, status: true, amount: true, proofUrl: true } },
        },
      }),
      this.prisma.conversation.findMany({
        where: {
          OR: [{ guestUserId: userId }, { participants: { some: { userId } } }],
        },
        take: 15,
        orderBy: { updatedAt: 'desc' },
        include: {
          property: { select: { name: true } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
      }),
      this.prisma.booking.aggregate({
        where: { userId, status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] } },
        _sum: { totalPrice: true },
        _count: true,
      }),
    ]);
    return {
      user: customer,
      bookings,
      conversations,
      stats: {
        bookingCount: spend._count,
        totalSpend: spend._sum.totalPrice,
      },
    };
  }

  async openCustomerChat(user: AuthUser, userId: string) {
    await this.require(user, 'inbox.read');
    return this.conversations.openSupportForCustomer(user, userId);
  }

  /** سجل رسائل موحّد لكل زبون عبر كل محادثاته */
  async customerThread(user: AuthUser, userId: string, after?: string) {
    await this.require(user, 'inbox.read');
    const afterDate = after ? new Date(after) : null;
    const incremental = Boolean(afterDate && !Number.isNaN(afterDate.getTime()));

    if (!incremental) {
      try {
        await this.conversations.openSupportForCustomer(user, userId);
      } catch {
        /* قد تكون مفتوحة */
      }
    }

    const customer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, phone: true },
    });
    if (!customer) throw new NotFoundException('الزبون غير موجود');

    const conversations = await this.prisma.conversation.findMany({
      where: {
        OR: [{ guestUserId: userId }, { participants: { some: { userId } } }],
      },
      select: {
        id: true,
        kind: true,
        property: { select: { name: true } },
        booking: { select: { property: { select: { name: true } } } },
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });
    const convIds = conversations.map((c) => c.id);
    const labelByConv = new Map(
      conversations.map((c) => [
        c.id,
        c.property?.name ?? c.booking?.property?.name ?? (c.kind === 'SUPPORT' ? 'دعم أجواء' : 'محادثة'),
      ]),
    );
    const primaryConversationId =
      conversations.find((c) => c.kind === 'SUPPORT')?.id ?? conversations[0]?.id ?? null;

    const messages =
      convIds.length === 0
        ? []
        : await this.prisma.message.findMany({
            where: {
              conversationId: { in: convIds },
              ...(incremental ? { createdAt: { gt: afterDate! } } : {}),
            },
            orderBy: { createdAt: 'asc' },
            take: incremental ? 100 : 250,
            include: { sender: { select: { id: true, name: true, phone: true, role: true } } },
          });

    // مسار التحديث اللحظي: رسائل فقط — بدون حجوزات/إحصاءات/ops
    if (incremental) {
      return {
        user: customer,
        primaryConversationId,
        messages: messages.map((m) => ({
          id: m.id,
          conversationId: m.conversationId,
          threadLabel: labelByConv.get(m.conversationId) ?? '',
          kind: m.kind,
          body: m.body,
          imageUrl: m.imageUrl,
          createdAt: m.createdAt,
          senderId: m.senderId,
          sender: m.sender,
        })),
      };
    }

    const [bookings, spend] = await Promise.all([
      this.prisma.booking.findMany({
        where: { userId },
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: {
          property: { select: { name: true } },
          payment: { select: { status: true } },
        },
      }),
      this.prisma.booking.aggregate({
        where: { userId, status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] } },
        _sum: { totalPrice: true },
        _count: true,
      }),
    ]);

    if (convIds.length > 0) {
      await this.prisma.conversationParticipant.updateMany({
        where: { userId: user.id, conversationId: { in: convIds } },
        data: { lastReadAt: new Date() },
      });
    }

    let ops: {
      conversationId: string | null;
      staffNote: string | null;
      priority: ConversationPriority | null;
      assignedToId: string | null;
      status: string | null;
    } = {
      conversationId: primaryConversationId,
      staffNote: null,
      priority: null,
      assignedToId: null,
      status: null,
    };
    if (primaryConversationId) {
      const primary = await this.prisma.conversation.findUnique({
        where: { id: primaryConversationId },
        select: {
          id: true,
          staffNote: true,
          priority: true,
          assignedToId: true,
          status: true,
        },
      });
      if (primary) {
        ops = {
          conversationId: primary.id,
          staffNote: primary.staffNote,
          priority: primary.priority,
          assignedToId: primary.assignedToId,
          status: primary.status,
        };
      }
    }

    return {
      user: customer,
      primaryConversationId,
      ops,
      messages: messages.map((m) => ({
        id: m.id,
        conversationId: m.conversationId,
        threadLabel: labelByConv.get(m.conversationId) ?? '',
        kind: m.kind,
        body: m.body,
        imageUrl: m.imageUrl,
        createdAt: m.createdAt,
        senderId: m.senderId,
        sender: m.sender,
      })),
      bookings,
      stats: {
        bookingCount: spend._count,
        totalSpend: spend._sum.totalPrice,
      },
    };
  }

  async note(user: AuthUser, conversationId: string, staffNote: string, followUp?: boolean) {
    await this.require(user, 'inbox.note');
    return this.prisma.conversation.update({
      where: { id: conversationId },
      data: {
        staffNote,
        priority: followUp ? ConversationPriority.URGENT : undefined,
      },
    });
  }

  async bookings(user: AuthUser, status?: string, q?: string) {
    await this.require(user, 'bookings.read');
    const query = q?.trim();
    return this.prisma.booking.findMany({
      where: {
        ...(status ? { status: status as BookingStatus } : {}),
        ...(query
          ? {
              OR: [
                { guestName: { contains: query, mode: 'insensitive' } },
                { guestPhone: { contains: query } },
                { property: { name: { contains: query, mode: 'insensitive' } } },
                { user: { phone: { contains: query } } },
                { user: { name: { contains: query, mode: 'insensitive' } } },
              ],
            }
          : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 80,
      include: {
        property: { select: { id: true, name: true, type: true } },
        user: { select: { id: true, name: true, phone: true } },
        payment: { select: { id: true, status: true, amount: true, proofUrl: true, method: true } },
      },
    });
  }

  async bookingDetail(user: AuthUser, id: string) {
    await this.require(user, 'bookings.read');
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        property: {
          select: {
            id: true,
            name: true,
            type: true,
            phone: true,
            city: { select: { nameAr: true } },
          },
        },
        user: { select: { id: true, name: true, phone: true } },
        payment: true,
        bookingNotes: {
          orderBy: { createdAt: 'desc' },
          take: 20,
          include: { author: { select: { name: true } } },
        },
        cancellationRequests: { orderBy: { createdAt: 'desc' }, take: 5 },
        refundRequests: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    return booking;
  }

  async addBookingNote(user: AuthUser, id: string, content: string) {
    await this.require(user, 'bookings.write');
    const booking = await this.prisma.booking.findUnique({ where: { id }, select: { id: true } });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    return this.prisma.bookingNote.create({
      data: {
        bookingId: id,
        authorId: user.id,
        content: content.trim() || 'ملاحظة',
        isInternal: true,
      },
    });
  }

  async confirmBooking(user: AuthUser, id: string) {
    await this.require(user, 'bookings.confirm');
    const result = await this.prisma.booking.updateMany({
      where: { id, status: BookingStatus.PENDING },
      data: { status: BookingStatus.CONFIRMED },
    });
    if (!result.count) throw new BadRequestException('عُولج بالفعل');
    return { ok: true };
  }

  async cancelBooking(user: AuthUser, id: string, reason: string) {
    await this.require(user, 'bookings.cancel');
    const result = await this.prisma.booking.updateMany({
      where: {
        id,
        status: { in: [BookingStatus.PENDING, BookingStatus.AWAITING_PAYMENT, BookingStatus.CONFIRMED] },
      },
      data: { status: BookingStatus.CANCELLED },
    });
    if (!result.count) throw new BadRequestException('عُولج بالفعل');
    await this.prisma.bookingNote.create({
      data: { bookingId: id, authorId: user.id, content: reason || 'إلغاء من مكتب الموظفين' },
    }).catch(() => undefined);
    return { ok: true };
  }

  async verifyPayment(user: AuthUser, id: string) {
    await this.require(user, 'payments.verify');
    const result = await this.prisma.payment.updateMany({
      where: { id, status: PaymentStatus.PENDING },
      data: {
        status: PaymentStatus.PAID,
        reviewedAt: new Date(),
        reviewedById: user.id,
      },
    });
    if (!result.count) throw new BadRequestException('عُولج بالفعل');
    return { ok: true };
  }

  async requests(user: AuthUser) {
    const canCancel = await this.hasPermission(user, 'cancellations.review');
    const canRefund = await this.hasPermission(user, 'refunds.review');
    if (!canCancel && !canRefund) {
      throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
    const bookingSelect = {
      id: true,
      status: true,
      startDate: true,
      property: { select: { name: true } },
      user: { select: { id: true, name: true, phone: true } },
    };
    const userSelect = { select: { id: true, name: true, phone: true } };
    const [cancellations, refunds] = await Promise.all([
      canCancel
        ? this.prisma.cancellationRequest.findMany({
            where: { status: RequestStatus.PENDING },
            take: 30,
            orderBy: { createdAt: 'desc' },
            include: { booking: { select: bookingSelect }, user: userSelect },
          })
        : Promise.resolve([]),
      canRefund
        ? this.prisma.refundRequest.findMany({
            where: { status: RequestStatus.PENDING },
            take: 30,
            orderBy: { createdAt: 'desc' },
            include: {
              booking: { select: bookingSelect },
              user: userSelect,
              payment: { select: { id: true, status: true } },
            },
          })
        : Promise.resolve([]),
    ]);
    return { cancellations, refunds };
  }

  async dashboard(user: AuthUser) {
    await this.me(user);
    const out: Record<string, number> = {
      waiting: 0,
      pendingBookings: 0,
      awaitingPayment: 0,
      openRequests: 0,
      unreadMessages: 0,
      pendingProperties: 0,
      pendingProviders: 0,
      pendingPayments: 0,
      todayBookings: 0,
    };
    try {
      const q = await this.queueSummary(user);
      out.waiting = q.waiting;
    } catch {
      /* no queue permission */
    }
    try {
      await this.require(user, 'bookings.read');
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      const [pending, awaiting, todayCount] = await Promise.all([
        this.prisma.booking.count({ where: { status: BookingStatus.PENDING } }),
        this.prisma.booking.count({ where: { status: BookingStatus.AWAITING_PAYMENT } }),
        this.prisma.booking.count({
          where: { startDate: { gte: today, lt: tomorrow } },
        }),
      ]);
      out.pendingBookings = pending;
      out.awaitingPayment = awaiting;
      out.todayBookings = todayCount;
    } catch {
      /* skip */
    }
    let open = 0;
    try {
      await this.require(user, 'cancellations.review');
      open += await this.prisma.cancellationRequest.count({ where: { status: RequestStatus.PENDING } });
    } catch {
      /* skip */
    }
    try {
      await this.require(user, 'refunds.review');
      open += await this.prisma.refundRequest.count({ where: { status: RequestStatus.PENDING } });
    } catch {
      /* skip */
    }
    out.openRequests = open;
    try {
      await this.require(user, 'inbox.read');
      const unread = await this.conversations.unreadCount(user);
      out.unreadMessages = unread.unread;
    } catch {
      /* skip */
    }
    try {
      await this.require(user, 'properties.read');
      out.pendingProperties = await this.prisma.property.count({
        where: { status: PropertyStatus.PENDING },
      });
    } catch {
      /* skip */
    }
    try {
      if (await this.hasPermission(user, 'providers.read') || await this.hasPermission(user, 'providers.link')) {
        out.pendingProviders = await this.prisma.provider.count({
          where: { kycStatus: { in: ['PENDING', 'UNVERIFIED'] }, verified: false },
        });
      }
    } catch {
      /* skip */
    }
    try {
      if (await this.hasPermission(user, 'payments.read') || await this.hasPermission(user, 'payments.verify')) {
        out.pendingPayments = await this.prisma.payment.count({
          where: { status: PaymentStatus.PENDING },
        });
      }
    } catch {
      /* skip */
    }
    return out;
  }

  async listProperties(user: AuthUser, status?: string, q?: string) {
    await this.require(user, 'properties.read');
    const query = q?.trim();
    return this.prisma.property.findMany({
      where: {
        ...(status ? { status: status as PropertyStatus } : {}),
        ...(query
          ? {
              OR: [
                { name: { contains: query, mode: 'insensitive' } },
                { phone: { contains: query } },
                { slug: { contains: query, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: { updatedAt: 'desc' },
      take: 60,
      select: {
        id: true,
        name: true,
        type: true,
        status: true,
        pricePerDay: true,
        featured: true,
        phone: true,
        ratingAvg: true,
        ratingCount: true,
        city: { select: { nameAr: true } },
        provider: { select: { id: true, businessName: true, verified: true } },
        media: {
          where: { isPrimary: true },
          take: 1,
          select: { url: true, thumbnailUrl: true },
        },
      },
    });
  }

  async propertyDetail(user: AuthUser, id: string) {
    await this.require(user, 'properties.read');
    const property = await this.prisma.property.findUnique({
      where: { id },
      include: {
        city: { include: { province: { select: { nameAr: true } } } },
        provider: {
          select: {
            id: true,
            businessName: true,
            verified: true,
            kycStatus: true,
            user: { select: { id: true, name: true, phone: true } },
          },
        },
        media: {
          orderBy: { sortOrder: 'asc' },
          take: 12,
          select: { id: true, url: true, thumbnailUrl: true, type: true, isPrimary: true },
        },
        _count: { select: { bookings: true, reviews: true } },
      },
    });
    if (!property) throw new NotFoundException('المكان غير موجود');
    return property;
  }

  async setPropertyStatus(user: AuthUser, id: string, status: string, reason?: string) {
    await this.require(user, 'properties.moderate');
    const allowed: PropertyStatus[] = [
      PropertyStatus.APPROVED,
      PropertyStatus.REJECTED,
      PropertyStatus.SUSPENDED,
      PropertyStatus.PENDING,
    ];
    if (!allowed.includes(status as PropertyStatus)) {
      throw new BadRequestException('حالة غير صالحة');
    }
    const result = await this.prisma.property.updateMany({
      where: { id },
      data: {
        status: status as PropertyStatus,
        rejectionReason: reason ?? null,
        publishedAt: status === PropertyStatus.APPROVED ? new Date() : undefined,
      },
    });
    if (!result.count) throw new NotFoundException('المكان غير موجود');
    await this.prisma.adminActivity.create({
      data: {
        userId: user.id,
        action: `property.${status.toLowerCase()}`,
        entityType: 'property',
        entityId: id,
        metadata: { reason: reason ?? '' },
      },
    }).catch(() => undefined);
    return { ok: true };
  }

  async listPayments(user: AuthUser, status?: string) {
    if (!(await this.hasPermission(user, 'payments.read')) && !(await this.hasPermission(user, 'payments.verify'))) {
      throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
    return this.prisma.payment.findMany({
      where: status ? { status: status as PaymentStatus } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 60,
      include: {
        booking: {
          select: {
            id: true,
            status: true,
            startDate: true,
            totalPrice: true,
            property: { select: { name: true } },
            user: { select: { id: true, name: true, phone: true } },
            guestName: true,
            guestPhone: true,
          },
        },
      },
    });
  }

  async paymentDetail(user: AuthUser, id: string) {
    if (!(await this.hasPermission(user, 'payments.read')) && !(await this.hasPermission(user, 'payments.verify'))) {
      throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: {
        booking: {
          include: {
            property: { select: { id: true, name: true } },
            user: { select: { id: true, name: true, phone: true } },
          },
        },
      },
    });
    if (!payment) throw new NotFoundException('الدفعة غير موجودة');
    return payment;
  }

  async rejectPayment(user: AuthUser, id: string, note?: string) {
    await this.require(user, 'payments.verify');
    const result = await this.prisma.payment.updateMany({
      where: { id, status: PaymentStatus.PENDING },
      data: {
        status: PaymentStatus.FAILED,
        adminNote: note ?? 'مرفوض من المكتب',
        reviewedAt: new Date(),
        reviewedById: user.id,
      },
    });
    if (!result.count) throw new BadRequestException('عُولج بالفعل');
    return { ok: true };
  }

  async listProviders(user: AuthUser, q?: string) {
    if (!(await this.hasPermission(user, 'providers.read')) && !(await this.hasPermission(user, 'providers.link'))) {
      throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
    const query = q?.trim();
    return this.prisma.provider.findMany({
      where: query
        ? {
            OR: [
              { businessName: { contains: query, mode: 'insensitive' } },
              { user: { phone: { contains: query } } },
              { user: { name: { contains: query, mode: 'insensitive' } } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
      take: 60,
      include: {
        user: { select: { id: true, name: true, phone: true } },
        _count: { select: { properties: true } },
      },
    });
  }

  async setProviderVerified(user: AuthUser, id: string, verified: boolean, reason?: string) {
    await this.require(user, 'providers.link');
    const result = await this.prisma.provider.updateMany({
      where: { id },
      data: {
        verified,
        kycStatus: verified ? 'VERIFIED' : 'REJECTED',
        rejectionReason: verified ? null : reason ?? 'مرفوض من المكتب',
      },
    });
    if (!result.count) throw new NotFoundException('المزود غير موجود');
    return { ok: true };
  }

  async searchUsers(user: AuthUser, q?: string) {
    await this.require(user, 'users.read');
    const query = q?.trim();
    if (!query || query.length < 2) return [];
    return this.prisma.user.findMany({
      where: {
        role: UserRole.CUSTOMER,
        OR: [
          { phone: { contains: query } },
          { name: { contains: query, mode: 'insensitive' } },
        ],
      },
      take: 30,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        phone: true,
        isActive: true,
        createdAt: true,
        _count: { select: { bookings: true } },
      },
    });
  }

  async opsOverview(user: AuthUser) {
    const dash = await this.dashboard(user);
    const modules = [
      { id: 'bookings', label: 'الحجوزات', permission: 'bookings.read', count: dash.pendingBookings + dash.awaitingPayment },
      { id: 'payments', label: 'المدفوعات', permission: 'payments.read', alt: 'payments.verify', count: dash.pendingPayments },
      { id: 'properties', label: 'الأماكن', permission: 'properties.read', count: dash.pendingProperties },
      { id: 'providers', label: 'المزودون', permission: 'providers.read', alt: 'providers.link', count: dash.pendingProviders },
      { id: 'customers', label: 'الزبائن', permission: 'users.read', count: 0 },
      { id: 'requests', label: 'الطلبات', permission: 'cancellations.review', alt: 'refunds.review', count: dash.openRequests },
      { id: 'content', label: 'المحتوى', permission: 'content.moderate', count: 0 },
      { id: 'coupons', label: 'الكوبونات', permission: 'coupons.read', alt: 'coupons.write', count: 0 },
      { id: 'invoices', label: 'الفواتير', permission: 'invoices.read', count: 0 },
      { id: 'reports', label: 'التقارير', permission: 'reports.read', count: 0 },
    ] as const;

    const visible = [];
    for (const mod of modules) {
      const ok =
        (await this.hasPermission(user, mod.permission as StaffPermission)) ||
        ('alt' in mod && mod.alt
          ? await this.hasPermission(user, mod.alt as StaffPermission)
          : false);
      if (ok) visible.push({ id: mod.id, label: mod.label, count: mod.count });
    }
    return { stats: dash, modules: visible };
  }

  async listBanners(user: AuthUser) {
    await this.require(user, 'content.moderate');
    return this.prisma.banner.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      take: 50,
    });
  }

  async setBannerActive(user: AuthUser, id: string, isActive: boolean) {
    await this.require(user, 'content.moderate');
    const result = await this.prisma.banner.updateMany({
      where: { id },
      data: { isActive },
    });
    if (!result.count) throw new NotFoundException('البانر غير موجود');
    return { ok: true };
  }

  async listReviews(user: AuthUser, hiddenOnly?: boolean) {
    await this.require(user, 'content.moderate');
    return this.prisma.review.findMany({
      where: hiddenOnly ? { isVisible: false } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 60,
      include: {
        property: { select: { id: true, name: true } },
        user: { select: { id: true, name: true, phone: true } },
      },
    });
  }

  async setReviewVisible(user: AuthUser, id: string, isVisible: boolean, adminNote?: string) {
    await this.require(user, 'content.moderate');
    const result = await this.prisma.review.updateMany({
      where: { id },
      data: { isVisible, adminNote: adminNote ?? undefined },
    });
    if (!result.count) throw new NotFoundException('التقييم غير موجود');
    return { ok: true };
  }

  async listSpotlights(user: AuthUser) {
    await this.require(user, 'content.moderate');
    return this.prisma.homeSpotlight.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      take: 40,
      include: { property: { select: { id: true, name: true } } },
    });
  }

  async setSpotlightActive(user: AuthUser, id: string, isActive: boolean) {
    await this.require(user, 'content.moderate');
    const result = await this.prisma.homeSpotlight.updateMany({
      where: { id },
      data: { isActive },
    });
    if (!result.count) throw new NotFoundException('العنصر غير موجود');
    return { ok: true };
  }

  async listCoupons(user: AuthUser) {
    await this.require(user, 'coupons.read');
    return this.prisma.coupon.findMany({
      orderBy: { createdAt: 'desc' },
      take: 60,
      select: {
        id: true,
        code: true,
        description: true,
        discountType: true,
        discountValue: true,
        usedCount: true,
        maxUses: true,
        isActive: true,
        startsAt: true,
        expiresAt: true,
      },
    });
  }

  async setCouponActive(user: AuthUser, id: string, isActive: boolean) {
    await this.require(user, 'coupons.write');
    const result = await this.prisma.coupon.updateMany({
      where: { id },
      data: { isActive },
    });
    if (!result.count) throw new NotFoundException('الكوبون غير موجود');
    return { ok: true };
  }

  async listInvoices(user: AuthUser, status?: string) {
    await this.require(user, 'invoices.read');
    return this.prisma.invoice.findMany({
      where: status ? { status: status as never } : undefined,
      orderBy: { issuedAt: 'desc' },
      take: 60,
      include: {
        booking: {
          select: {
            id: true,
            status: true,
            property: { select: { name: true } },
            user: { select: { name: true, phone: true } },
            guestName: true,
            guestPhone: true,
          },
        },
      },
    });
  }

  async listNotifications(user: AuthUser) {
    await this.require(user, 'reports.read');
    return this.prisma.teamNotification.findMany({
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
  }

  async markNotificationRead(user: AuthUser, id: string) {
    await this.require(user, 'reports.read');
    await this.prisma.teamNotification.updateMany({
      where: { id },
      data: { isRead: true },
    });
    return { ok: true };
  }

  async reviewCancellation(user: AuthUser, id: string, approve: boolean, note?: string) {
    await this.require(user, 'cancellations.review');
    const result = await this.prisma.cancellationRequest.updateMany({
      where: { id, status: RequestStatus.PENDING },
      data: { status: approve ? RequestStatus.APPROVED : RequestStatus.REJECTED, adminNote: note ?? '' },
    });
    if (!result.count) throw new BadRequestException('عُولج بالفعل');
    return { ok: true };
  }

  async reviewRefund(user: AuthUser, id: string, approve: boolean, note?: string) {
    await this.require(user, 'refunds.review');
    const result = await this.prisma.refundRequest.updateMany({
      where: { id, status: RequestStatus.PENDING },
      data: { status: approve ? RequestStatus.APPROVED : RequestStatus.REJECTED, adminNote: note ?? '' },
    });
    if (!result.count) throw new BadRequestException('عُولج بالفعل');
    return { ok: true };
  }

  async findCustomer(user: AuthUser, phone: string) {
    await this.require(user, 'users.read');
    const found = await this.prisma.user.findFirst({
      where: { phone: { contains: phone } },
      select: { id: true, name: true, phone: true },
    });
    if (!found) return { user: null, bookings: [] };
    const bookings = await this.prisma.booking.findMany({
      where: { userId: found.id },
      orderBy: { createdAt: 'desc' },
      take: 3,
      include: { property: { select: { name: true } } },
    });
    return { user: found, bookings };
  }

  private assertOffice(user: AuthUser) {
    if (user.role !== UserRole.STAFF && user.role !== UserRole.ADMIN) {
      throw new ForbiddenException('هذا التطبيق للموظفين');
    }
  }

  private async hasPermission(user: AuthUser, permission: StaffPermission) {
    this.assertOffice(user);
    if (user.role === UserRole.ADMIN) return true;
    const profile = await this.prisma.staffProfile.findUnique({ where: { userId: user.id } });
    return Boolean(profile?.isActive && expandStaffPermissions(profile.permissions).includes(permission));
  }

  private async require(user: AuthUser, permission: StaffPermission) {
    if (!(await this.hasPermission(user, permission))) {
      throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    }
  }

  private cleanPermissions(values: string[]) {
    const unique = [...new Set(values.filter(isStaffPermission))];
    // إضافة/تعديل الأماكن تفترض القدرة على عرضها
    if (unique.includes('properties.write') && !unique.includes('properties.read')) {
      unique.push('properties.read');
    }
    if (!unique.length) throw new BadRequestException('اختر صلاحية واحدة على الأقل');
    return unique;
  }
}
