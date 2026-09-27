import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  BookingStatus,
  InvoiceStatus,
  PaymentStatus,
  Prisma,
  RequestStatus,
  SocialPostStatus,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';
import { invoicePrintHtml } from '../../common/utils/marketplace.util';
import { MarketplaceLifecycleService } from '../marketplace/marketplace-lifecycle.service';
import { ConversationsService } from '../marketplace/conversations.service';

@Injectable()
export class AdminOpsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly activity: ActivityLogService,
    private readonly lifecycle: MarketplaceLifecycleService,
    private readonly chat: ConversationsService,
  ) {}

  async conversations(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.ConversationWhereInput = {};
    if (query.kind) where.kind = query.kind as never;
    if (query.q) {
      where.OR = [
        { booking: { property: { name: { contains: query.q, mode: 'insensitive' } } } },
        { booking: { user: { phone: { contains: query.q } } } },
        { booking: { user: { name: { contains: query.q, mode: 'insensitive' } } } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.conversation.findMany({
        where,
        include: {
          booking: {
            select: {
              id: true,
              status: true,
              property: { select: { name: true } },
              user: { select: { name: true, phone: true } },
            },
          },
          participants: { include: { user: { select: { name: true, phone: true, role: true } } } },
          _count: { select: { messages: true } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
        orderBy: { updatedAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.conversation.count({ where }),
    ]);
    return this.pagination.wrap(items, total, page, pageSize);
  }

  async conversationMessages(id: string, query: Record<string, string | undefined>) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id },
      include: {
        booking: { select: { id: true, property: { select: { name: true } } } },
      },
    });
    if (!conversation) throw new NotFoundException('المحادثة غير موجودة');
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const [items, total] = await Promise.all([
      this.prisma.message.findMany({
        where: { conversationId: id },
        include: { sender: { select: { name: true, phone: true, role: true } } },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.message.count({ where: { conversationId: id } }),
    ]);
    return { conversation, ...this.pagination.wrap(items, total, page, pageSize) };
  }

  async invoices(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.InvoiceWhereInput = {};
    if (query.status) where.status = query.status as InvoiceStatus;
    if (query.q) {
      where.OR = [
        { number: { contains: query.q, mode: 'insensitive' } },
        { booking: { property: { name: { contains: query.q, mode: 'insensitive' } } } },
        { booking: { user: { phone: { contains: query.q } } } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.invoice.findMany({
        where,
        include: {
          booking: {
            select: {
              id: true,
              status: true,
              user: { select: { name: true, phone: true } },
              property: { select: { name: true } },
            },
          },
        },
        orderBy: { issuedAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.invoice.count({ where }),
    ]);
    return this.pagination.wrap(items, total, page, pageSize);
  }

  async invoiceById(id: string) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { id },
      include: {
        booking: {
          include: {
            user: { select: { name: true, phone: true } },
            property: { select: { name: true } },
          },
        },
      },
    });
    if (!invoice) throw new NotFoundException('الفاتورة غير موجودة');
    return invoice;
  }

  async invoicePrint(id: string) {
    const invoice = await this.invoiceById(id);
    return invoicePrintHtml({
      number: invoice.number,
      status: invoice.status,
      subtotal: Number(invoice.subtotal),
      discount: Number(invoice.discount),
      total: Number(invoice.total),
      issuedAt: invoice.issuedAt,
      items: invoice.items,
      booking: invoice.booking,
    });
  }

  async refunds(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const status = query.status as RequestStatus | undefined;
    const where: Prisma.RefundRequestWhereInput = {};
    if (status) where.status = status;
    if (query.q) {
      where.OR = [
        { reason: { contains: query.q, mode: 'insensitive' } },
        { booking: { property: { name: { contains: query.q, mode: 'insensitive' } } } },
        { booking: { user: { phone: { contains: query.q } } } },
      ];
    }
    const [refunds, cancellations, total] = await Promise.all([
      this.prisma.refundRequest.findMany({
        where,
        include: {
          user: { select: { name: true, phone: true } },
          booking: {
            select: {
              id: true,
              status: true,
              totalPrice: true,
              startDate: true,
              property: { select: { name: true } },
              payment: { select: { id: true, status: true, amount: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.cancellationRequest.findMany({
        where: status ? { status } : undefined,
        include: {
          user: { select: { name: true, phone: true } },
          booking: {
            select: {
              id: true,
              status: true,
              totalPrice: true,
              startDate: true,
              property: { select: { name: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.refundRequest.count({ where }),
    ]);
    return {
      ...this.pagination.wrap(refunds, total, page, pageSize),
      cancellations,
    };
  }

  async reviewRefund(
    user: AuthUser,
    id: string,
    dto: { approve: boolean; adminNote?: string },
  ) {
    const request = await this.prisma.refundRequest.findUnique({
      where: { id },
      include: { booking: { include: { payment: true } } },
    });
    if (!request) throw new NotFoundException('طلب الاسترداد غير موجود');
    if (request.status !== RequestStatus.PENDING) {
      throw new BadRequestException('تمت مراجعة هذا الطلب');
    }
    if (!dto.approve && !dto.adminNote?.trim()) {
      throw new BadRequestException('أضف سبب الرفض');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const next = await tx.refundRequest.update({
        where: { id },
        data: {
          status: dto.approve ? RequestStatus.APPROVED : RequestStatus.REJECTED,
          adminNote: dto.adminNote?.trim(),
          reviewedById: user.id,
          reviewedAt: new Date(),
        },
      });
      await tx.cancellationRequest.updateMany({
        where: { bookingId: request.bookingId, status: RequestStatus.PENDING },
        data: {
          status: dto.approve ? RequestStatus.APPROVED : RequestStatus.REJECTED,
          adminNote: dto.adminNote?.trim(),
          reviewedById: user.id,
          reviewedAt: new Date(),
        },
      });
      if (dto.approve) {
        await tx.booking.update({
          where: { id: request.bookingId },
          data: { status: BookingStatus.CANCELLED },
        });
        if (request.booking.payment?.status === PaymentStatus.PAID) {
          await tx.payment.update({
            where: { id: request.booking.payment.id },
            data: {
              status: PaymentStatus.REFUNDED,
              adminNote: dto.adminNote?.trim() || 'استرداد من طلب العميل',
              reviewedAt: new Date(),
              reviewedById: user.id,
            },
          });
        }
      }
      return next;
    });

    if (dto.approve) {
      await this.lifecycle.afterPaymentRefunded(request.bookingId, dto.adminNote);
    } else {
      await this.lifecycle.notifyUser({
        userId: request.userId,
        type: 'REFUND',
        title: 'رُفض طلب الاسترداد',
        body: dto.adminNote?.trim() || 'راجع تفاصيل الحجز',
        linkUrl: `/booking/${request.bookingId}`,
        entityType: 'booking',
        entityId: request.bookingId,
      });
    }

    await this.activity.log({
      userId: user.id,
      action: dto.approve ? 'refund.approve' : 'refund.reject',
      entityType: 'refund',
      entityId: id,
    });
    return updated;
  }

  async reviewCancellation(
    user: AuthUser,
    id: string,
    dto: { approve: boolean; adminNote?: string },
  ) {
    const request = await this.prisma.cancellationRequest.findUnique({
      where: { id },
      include: { booking: { include: { payment: true } } },
    });
    if (!request) throw new NotFoundException('طلب الإلغاء غير موجود');
    if (request.status !== RequestStatus.PENDING) {
      throw new BadRequestException('تمت مراجعة هذا الطلب');
    }
    const refund = await this.prisma.refundRequest.findFirst({
      where: { bookingId: request.bookingId, status: RequestStatus.PENDING },
    });
    if (refund) {
      return this.reviewRefund(user, refund.id, dto);
    }
    await this.prisma.cancellationRequest.update({
      where: { id },
      data: {
        status: dto.approve ? RequestStatus.APPROVED : RequestStatus.REJECTED,
        adminNote: dto.adminNote?.trim(),
        reviewedById: user.id,
        reviewedAt: new Date(),
      },
    });
    if (dto.approve) {
      await this.prisma.booking.update({
        where: { id: request.bookingId },
        data: { status: BookingStatus.CANCELLED },
      });
      await this.lifecycle.afterBookingStatusChanged(request.bookingId, BookingStatus.CANCELLED);
    }
    return { ok: true };
  }

  async collections(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.CollectionWhereInput = {};
    if (query.visibility) where.visibility = query.visibility as never;
    if (query.q) {
      where.OR = [
        { name: { contains: query.q, mode: 'insensitive' } },
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.collection.findMany({
        where,
        include: {
          user: { select: { name: true, phone: true } },
          _count: { select: { items: true } },
        },
        orderBy: { updatedAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.collection.count({ where }),
    ]);
    return this.pagination.wrap(items, total, page, pageSize);
  }

  async collectionById(id: string) {
    const collection = await this.prisma.collection.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        items: {
          include: {
            property: {
              select: {
                id: true,
                name: true,
                type: true,
                city: { select: { nameAr: true } },
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!collection) throw new NotFoundException('القائمة غير موجودة');
    return collection;
  }

  async social(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.SocialPostWhereInput = {};
    if (query.status) where.status = query.status as SocialPostStatus;
    if (query.q) {
      where.OR = [
        { caption: { contains: query.q, mode: 'insensitive' } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
        { property: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.socialPost.findMany({
        where,
        include: {
          user: { select: { name: true, phone: true } },
          property: { select: { name: true } },
          _count: { select: { reports: true, likes: true, comments: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.socialPost.count({ where }),
    ]);
    return this.pagination.wrap(items, total, page, pageSize);
  }

  async socialById(id: string) {
    const post = await this.prisma.socialPost.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        property: { select: { id: true, name: true } },
        comments: {
          include: { user: { select: { name: true, phone: true } } },
          orderBy: { createdAt: 'desc' },
          take: 40,
        },
        reports: {
          include: { user: { select: { name: true, phone: true } } },
          orderBy: { createdAt: 'desc' },
          take: 40,
        },
        _count: { select: { reports: true, likes: true, comments: true } },
      },
    });
    if (!post) throw new NotFoundException('المنشور غير موجود');
    return post;
  }

  async moderatePost(user: AuthUser, id: string, status: SocialPostStatus) {
    const post = await this.prisma.socialPost.update({
      where: { id },
      data: { status },
    });
    await this.activity.log({
      userId: user.id,
      action: 'social.moderate',
      entityType: 'social',
      entityId: id,
      metadata: { status },
    });
    return post;
  }

  async offers(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.PriceOfferWhereInput = {};
    if (query.status) where.status = query.status as never;
    if (query.q) {
      where.OR = [
        { customer: { phone: { contains: query.q } } },
        { property: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.priceOffer.findMany({
        where,
        include: {
          property: { select: { name: true } },
          customer: { select: { name: true, phone: true } },
          provider: { select: { businessName: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.priceOffer.count({ where }),
    ]);
    return this.pagination.wrap(items, total, page, pageSize);
  }

  async replyToConversation(user: AuthUser, id: string, body: string) {
    return this.chat.send(user, id, { body });
  }

  async openSupportForCustomer(user: AuthUser, userId: string) {
    return this.chat.openSupportForCustomer(user, userId);
  }

  private csv(header: string[], rows: Array<Array<unknown>>) {
    const cell = (value: unknown) => {
      const text = String(value ?? '');
      return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
    };
    return [header.map(cell).join(','), ...rows.map((row) => row.map(cell).join(','))].join('\n');
  }

  async exportConversationsCsv(query: Record<string, string | undefined>) {
    const data = await this.conversations({ ...query, page: '1', pageSize: '2000' });
    return this.csv(
      ['id', 'kind', 'property', 'customer', 'last_message', 'messages', 'updated_at'],
      data.items.map((row) => [
        row.id,
        row.kind,
        row.booking?.property?.name,
        row.booking?.user?.phone ??
          row.participants.map((p: { user: { phone: string } }) => p.user.phone).join(' | '),
        row.messages[0]?.body,
        row._count.messages,
        row.updatedAt.toISOString(),
      ]),
    );
  }

  async exportInvoicesCsv(query: Record<string, string | undefined>) {
    const data = await this.invoices({ ...query, page: '1', pageSize: '5000' });
    return this.csv(
      ['number', 'status', 'total', 'property', 'customer', 'phone', 'issued_at'],
      data.items.map((row) => [
        row.number,
        row.status,
        Number(row.total),
        row.booking?.property?.name,
        row.booking?.user?.name,
        row.booking?.user?.phone,
        row.issuedAt.toISOString(),
      ]),
    );
  }

  async exportRefundsCsv(query: Record<string, string | undefined>) {
    const data = await this.refunds({ ...query, page: '1', pageSize: '5000' });
    return this.csv(
      ['id', 'kind', 'status', 'amount', 'reason', 'property', 'phone', 'created_at'],
      [
        ...data.items.map((row) => [
          row.id,
          'refund',
          row.status,
          Number(row.amount),
          row.reason,
          row.booking?.property?.name,
          row.user?.phone,
          row.createdAt.toISOString(),
        ]),
        ...(data.cancellations ?? []).map((row) => [
          row.id,
          'cancellation',
          row.status,
          Number(row.expectedRefund),
          row.reason,
          row.booking?.property?.name,
          row.user?.phone,
          row.createdAt.toISOString(),
        ]),
      ],
    );
  }

  async exportCollectionsCsv(query: Record<string, string | undefined>) {
    const data = await this.collections({ ...query, page: '1', pageSize: '5000' });
    return this.csv(
      ['id', 'name', 'visibility', 'items', 'owner', 'phone', 'updated_at'],
      data.items.map((row) => [
        row.id,
        row.name,
        row.visibility,
        row._count.items,
        row.user?.name,
        row.user?.phone,
        row.updatedAt.toISOString(),
      ]),
    );
  }

  async exportSocialCsv(query: Record<string, string | undefined>) {
    const data = await this.social({ ...query, page: '1', pageSize: '5000' });
    return this.csv(
      ['id', 'status', 'caption', 'property', 'author', 'likes', 'comments', 'reports', 'created_at'],
      data.items.map((row) => [
        row.id,
        row.status,
        row.caption,
        row.property?.name,
        row.user?.phone,
        row.likesCount,
        row.commentsCount,
        row._count.reports,
        row.createdAt.toISOString(),
      ]),
    );
  }

  async exportOffersCsv(query: Record<string, string | undefined>) {
    const data = await this.offers({ ...query, page: '1', pageSize: '5000' });
    return this.csv(
      ['id', 'status', 'amount', 'property', 'customer', 'provider', 'created_at'],
      data.items.map((row) => [
        row.id,
        row.status,
        Number(row.amount),
        row.property?.name,
        row.customer?.phone,
        row.provider?.businessName,
        row.createdAt.toISOString(),
      ]),
    );
  }
}
