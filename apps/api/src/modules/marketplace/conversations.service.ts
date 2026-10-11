import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ConversationKind,
  ConversationPriority,
  ConversationStatus,
  MessageKind,
  Prisma,
  UserRole,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';
import { ChatEventsService } from './chat-events.service';

const STAFF_ROLES = [UserRole.ADMIN, UserRole.STAFF] as const;

export const isStaffUser = (user: AuthUser) =>
  (STAFF_ROLES as readonly string[]).includes(user.role);

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycle: MarketplaceLifecycleService,
    private readonly events: ChatEventsService,
  ) {}

  async list(user: AuthUser) {
    const staff = isStaffUser(user);
    const rows = await this.prisma.conversation.findMany({
      where: staff ? undefined : { participants: { some: { userId: user.id } } },
      include: {
        booking: {
          select: {
            id: true,
            status: true,
            startDate: true,
            property: {
              select: {
                id: true,
                name: true,
                pricePerDay: true,
                city: { select: { nameAr: true } },
              },
            },
          },
        },
        property: {
          select: {
            id: true,
            name: true,
            pricePerDay: true,
            city: { select: { nameAr: true } },
          },
        },
        participants: {
          include: { user: { select: { id: true, name: true, phone: true, role: true } } },
        },
        assignedTo: { select: { id: true, name: true, phone: true, role: true } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { updatedAt: 'desc' },
      take: 100,
    });

    const unreadMap = await this.unreadByConversation(user.id);
    return rows.map((row) => ({
      id: row.id,
      kind: row.kind,
      status: row.status,
      priority: row.priority,
      staffNote: row.staffNote || undefined,
      booking: row.booking,
      property: row.property ?? row.booking?.property ?? null,
      participants: row.participants.map((p) => p.user),
      assignedTo: row.assignedTo,
      lastMessage: row.messages[0] ?? null,
      unread: unreadMap.get(row.id) ?? 0,
      updatedAt: row.updatedAt,
    }));
  }

  async getOne(user: AuthUser, id: string) {
    const conversation = await this.assertAccess(user, id);
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId: id, userId: user.id },
      data: { lastReadAt: new Date() },
    });
    return conversation;
  }

  async messages(
    user: AuthUser,
    id: string,
    query: { before?: string; after?: string; pageSize?: string },
  ) {
    await this.assertAccess(user, id);
    const take = Math.min(100, Math.max(1, Number(query.pageSize) || 50));
    const after = query.after ? new Date(query.after) : null;
    const before = query.before ? new Date(query.before) : null;
    const rows = await this.prisma.message.findMany({
      where: {
        conversationId: id,
        ...(after && !Number.isNaN(after.getTime()) ? { createdAt: { gt: after } } : {}),
        ...(before && !after && !Number.isNaN(before.getTime())
          ? { createdAt: { lt: before } }
          : {}),
      },
      include: { sender: { select: { id: true, name: true, phone: true, role: true } } },
      orderBy: { createdAt: after ? 'asc' : 'desc' },
      take,
    });
    if (!after && !before) {
      await this.prisma.conversationParticipant.updateMany({
        where: { conversationId: id, userId: user.id },
        data: { lastReadAt: new Date() },
      });
    }
    return after ? rows : rows.reverse();
  }

  async send(
    user: AuthUser,
    id: string,
    dto: { body?: string; imageUrl?: string },
  ) {
    await this.assertAccess(user, id);
    const body = dto.body?.trim() ?? '';
    if (!body && !dto.imageUrl) {
      throw new BadRequestException('أضف نصاً أو صورة');
    }
    if (body.length > 4000) {
      throw new BadRequestException('الرسالة أطول من المسموح');
    }

    const message = await this.prisma.message.create({
      data: {
        conversationId: id,
        senderId: user.id,
        kind: dto.imageUrl ? MessageKind.IMAGE : MessageKind.TEXT,
        body,
        imageUrl: dto.imageUrl,
      },
      include: { sender: { select: { id: true, name: true, phone: true, role: true } } },
    });

    // بث فوري للمستمعين قبل أي عمل جانبي (إشعارات/تحديث حالة)
    this.events.emit(id, message);

    const staff = isStaffUser(user);
    void this.afterMessageSent(user.id, id, body, staff).catch(() => undefined);

    return message;
  }

  /** تحديث الحالة + إشعارات — خارج مسار الرد حتى لا يتأخر الإرسال */
  private async afterMessageSent(
    senderId: string,
    conversationId: string,
    body: string,
    staff: boolean,
  ) {
    const current = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      select: { firstResponseAt: true },
    });
    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: {
        updatedAt: new Date(),
        status: staff ? ConversationStatus.PENDING : ConversationStatus.OPEN,
        ...(staff && !current?.firstResponseAt ? { firstResponseAt: new Date() } : {}),
      },
    });

    const others = await this.prisma.conversationParticipant.findMany({
      where: { conversationId, userId: { not: senderId } },
      select: { userId: true },
    });
    await Promise.all(
      others.map((p) =>
        this.lifecycle.notifyUser({
          userId: p.userId,
          type: 'MESSAGE',
          title: 'رسالة جديدة',
          body: body || 'صورة',
          linkUrl: `/chat/${conversationId}`,
          entityType: 'conversation',
          entityId: conversationId,
        }),
      ),
    );
  }

  /// لوحة فريق الدعم — تصفية بالحالة والإسناد والنوع والبحث
  async listForStaff(query: {
    status?: string;
    assignedToId?: string;
    kind?: string;
    priority?: string;
    q?: string;
    page?: number;
    pageSize?: number;
  }) {
    const page = Math.max(1, Number(query.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(query.pageSize) || 20));
    const statusValues = ['OPEN', 'PENDING', 'RESOLVED', 'CLOSED'];
    const priorityValues = ['LOW', 'NORMAL', 'URGENT'];

    const where: Prisma.ConversationWhereInput = {
      ...(query.status && statusValues.includes(query.status)
        ? { status: query.status as ConversationStatus }
        : { status: { not: ConversationStatus.CLOSED } }),
      ...(query.assignedToId === 'me'
        ? {}
        : query.assignedToId
          ? { assignedToId: query.assignedToId }
          : {}),
      ...(query.kind && ['BOOKING', 'SUPPORT'].includes(query.kind)
        ? { kind: query.kind as ConversationKind }
        : {}),
      ...(query.priority && priorityValues.includes(query.priority)
        ? { priority: query.priority as ConversationPriority }
        : {}),
      ...(query.q
        ? {
            OR: [
              { property: { name: { contains: query.q, mode: 'insensitive' } } },
              { booking: { property: { name: { contains: query.q, mode: 'insensitive' } } } },
              {
                participants: {
                  some: {
                    user: {
                      OR: [
                        { name: { contains: query.q, mode: 'insensitive' } },
                        { phone: { contains: query.q } },
                      ],
                    },
                  },
                },
              },
              { messages: { some: { body: { contains: query.q, mode: 'insensitive' } } } },
            ],
          }
        : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.conversation.findMany({
        where,
        include: {
          booking: {
            select: {
              id: true,
              status: true,
              startDate: true,
              property: { select: { id: true, name: true } },
              user: { select: { name: true, phone: true } },
            },
          },
          property: { select: { id: true, name: true } },
          participants: {
            include: { user: { select: { id: true, name: true, phone: true, role: true } } },
          },
          assignedTo: { select: { id: true, name: true } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
          _count: { select: { messages: true } },
        },
        orderBy: [
          { priority: 'desc' },
          { updatedAt: 'desc' },
        ],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.conversation.count({ where }),
    ]);

    return {
      items: rows.map((row) => ({
        id: row.id,
        kind: row.kind,
        status: row.status,
        priority: row.priority,
        staffNote: row.staffNote,
        booking: row.booking,
        property: row.property ?? row.booking?.property ?? null,
        participants: row.participants.map((p) => p.user),
        assignedTo: row.assignedTo,
        lastMessage: row.messages[0] ?? null,
        messageCount: row._count.messages,
        updatedAt: row.updatedAt,
      })),
      total,
      page,
      pageSize,
    };
  }

  /// تحديث حالة/إسناد/أولوية/ملاحظة — لفريق الدعم فقط
  async updateOps(
    staff: AuthUser,
    id: string,
    dto: {
      status?: ConversationStatus;
      assignedToId?: string | null;
      priority?: ConversationPriority;
      staffNote?: string;
    },
  ) {
    if (!isStaffUser(staff)) throw new ForbiddenException('خاص بفريق الدعم');
    await this.assertAccess(staff, id);

    if (dto.assignedToId) {
      const assignee = await this.prisma.user.findUnique({
        where: { id: dto.assignedToId },
        select: { id: true, role: true },
      });
      if (!assignee || !(STAFF_ROLES as readonly string[]).includes(assignee.role)) {
        throw new BadRequestException('المسنِد له يجب أن يكون من الفريق');
      }
    }

    const updated = await this.prisma.conversation.update({
      where: { id },
      data: {
        ...(dto.status ? { status: dto.status } : {}),
        ...(dto.priority ? { priority: dto.priority } : {}),
        ...(dto.assignedToId !== undefined ? { assignedToId: dto.assignedToId } : {}),
        ...(dto.staffNote !== undefined ? { staffNote: dto.staffNote } : {}),
      },
      include: {
        assignedTo: { select: { id: true, name: true } },
      },
    });

    // إسناد أول موظف يردّ تلقائياً إن لم يُسند من قبل
    if (isStaffUser(staff) && !dto.assignedToId) {
      await this.prisma.conversation.updateMany({
        where: { id, assignedToId: null },
        data: { assignedToId: staff.id },
      });
    }

    return updated;
  }

  /// يسند المحادثة تلقائياً لأول موظف يفتحها — لعرض «متابَعة بواسطتي»
  async claim(staff: AuthUser, id: string) {
    if (!isStaffUser(staff)) throw new ForbiddenException('خاص بفريق الدعم');
    await this.assertAccess(staff, id);
    const updated = await this.prisma.conversation.update({
      where: { id },
      data: { assignedToId: staff.id },
      include: { assignedTo: { select: { id: true, name: true } } },
    });
    return updated;
  }

  async openForBooking(user: AuthUser, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { property: { include: { provider: true } } },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    const owner = booking.property.provider?.userId === user.id;
    if (!staff && booking.userId !== user.id && !owner) {
      throw new ForbiddenException('غير مسموح');
    }
    const conversation = await this.lifecycle.ensureConversation(bookingId);
    if (!conversation) throw new NotFoundException('تعذر فتح المحادثة');
    return this.getOne(user, conversation.id);
  }

  async openForProperty(user: AuthUser, propertyId: string) {
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: { provider: true, city: { select: { nameAr: true } } },
    });
    if (!property) throw new NotFoundException('المكان غير موجود');
    const staffId = property.provider?.userId ?? property.createdById;
    if (!staffId) throw new BadRequestException('لا يوجد موظف لهذا المكان');
    if (staffId === user.id) throw new BadRequestException('لا يمكنك مراسلة نفسك');

    const existing = await this.prisma.conversation.findFirst({
      where: { guestUserId: user.id, propertyId, kind: ConversationKind.BOOKING },
    });
    if (existing) {
      await this.prisma.conversationParticipant.upsert({
        where: { conversationId_userId: { conversationId: existing.id, userId: staffId } },
        update: {},
        create: { conversationId: existing.id, userId: staffId },
      });
      return this.getOne(user, existing.id);
    }

    const created = await this.prisma.conversation.create({
      data: {
        kind: ConversationKind.BOOKING,
        guestUserId: user.id,
        propertyId,
        participants: { create: [{ userId: user.id }, { userId: staffId }] },
        messages: {
          create: {
            kind: MessageKind.SYSTEM,
            body: `سؤال عن ${property.name}`,
          },
        },
      },
    });
    await this.lifecycle.notifyUser({
      userId: staffId,
      type: 'MESSAGE',
      title: `سؤال عن ${property.name}`,
      body: 'زبون يريد التواصل',
      linkUrl: `/chat/${created.id}`,
      entityType: 'conversation',
      entityId: created.id,
    });
    return this.getOne(user, created.id);
  }

  async openSupport(user: AuthUser) {
    const existing = await this.prisma.conversation.findFirst({
      where: {
        kind: ConversationKind.SUPPORT,
        bookingId: null,
        participants: { some: { userId: user.id } },
      },
    });
    if (existing) return this.getOne(user, existing.id);

    const created = await this.prisma.conversation.create({
      data: {
        kind: ConversationKind.SUPPORT,
        participants: { create: { userId: user.id } },
        messages: {
          create: {
            kind: MessageKind.SYSTEM,
            body: 'مرحباً — فريق VIBES سيرد عليك هنا',
          },
        },
      },
    });
    return this.getOne(user, created.id);
  }

  async openSupportForCustomer(staff: AuthUser, userId: string) {
    const isStaff = staff.role === UserRole.ADMIN || staff.role === UserRole.STAFF;
    if (!isStaff) throw new ForbiddenException('غير مسموح');
    if (staff.id === userId) {
      throw new BadRequestException('لا يمكن فتح محادثة دعم مع نفسك');
    }

    const customer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!customer) throw new NotFoundException('المستخدم غير موجود');

    const existing = await this.prisma.conversation.findFirst({
      where: {
        kind: ConversationKind.SUPPORT,
        bookingId: null,
        participants: { some: { userId } },
      },
    });
    if (existing) {
      await this.prisma.conversationParticipant.upsert({
        where: { conversationId_userId: { conversationId: existing.id, userId: staff.id } },
        update: {},
        create: { conversationId: existing.id, userId: staff.id },
      });
      return this.getOne(staff, existing.id);
    }

    const created = await this.prisma.conversation.create({
      data: {
        kind: ConversationKind.SUPPORT,
        participants: { create: [{ userId }, { userId: staff.id }] },
        messages: {
          create: {
            kind: MessageKind.SYSTEM,
            body: 'فتح فريق VIBES محادثة دعم معك',
          },
        },
      },
    });
    await this.lifecycle.notifyUser({
      userId,
      type: 'MESSAGE',
      title: 'رسالة من الدعم',
      body: 'فريق VIBES يريد التواصل معك',
      linkUrl: `/chat/${created.id}`,
      entityType: 'conversation',
      entityId: created.id,
    });
    return this.getOne(staff, created.id);
  }

  async unreadCount(user: AuthUser) {
    const unreadMap = await this.unreadByConversation(user.id);
    let unread = 0;
    for (const value of unreadMap.values()) unread += value;
    return { unread };
  }

  async markAllRead(user: AuthUser) {
    await this.prisma.conversationParticipant.updateMany({
      where: { userId: user.id },
      data: { lastReadAt: new Date() },
    });
    return { ok: true };
  }

  private async unreadByConversation(userId: string) {
    const rows = await this.prisma.$queryRaw<Array<{ conversation_id: string; unread: number }>>(
      Prisma.sql`
        SELECT m.conversation_id, COUNT(*)::int AS unread
        FROM messages m
        INNER JOIN conversation_participants p
          ON p.conversation_id = m.conversation_id AND p.user_id = ${userId}
        WHERE m.kind <> 'SYSTEM'
          AND (m.sender_id IS NULL OR m.sender_id <> ${userId})
          AND m.created_at > COALESCE(p.last_read_at, TIMESTAMPTZ '1970-01-01Z')
        GROUP BY m.conversation_id
      `,
    );
    return new Map(rows.map((row) => [row.conversation_id, Number(row.unread)]));
  }

  async ensureAccess(user: AuthUser, id: string) {
    return this.assertAccess(user, id);
  }

  private async assertAccess(user: AuthUser, id: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id },
      include: {
        booking: {
          select: {
            id: true,
            status: true,
            userId: true,
            property: { select: { id: true, name: true, provider: { select: { userId: true } } } },
          },
        },
        property: {
          select: { id: true, name: true, city: { select: { nameAr: true } }, pricePerDay: true },
        },
        participants: {
          include: { user: { select: { id: true, name: true, phone: true, role: true } } },
        },
      },
    });
    if (!conversation) throw new NotFoundException('المحادثة غير موجودة');
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    const member = conversation.participants.some((p) => p.userId === user.id);
    if (!staff && !member) throw new ForbiddenException('غير مسموح');

    if (staff && !member) {
      await this.prisma.conversationParticipant.upsert({
        where: { conversationId_userId: { conversationId: id, userId: user.id } },
        update: {},
        create: { conversationId: id, userId: user.id },
      });
    }
    return conversation;
  }
}
