import { Injectable } from '@nestjs/common';
import {
  BookingStatus,
  ConversationKind,
  InvoiceStatus,
  MessageKind,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { formatInvoiceNumber, invoiceItems, parseInvoiceSeq } from '../../common/utils/marketplace.util';

@Injectable()
export class MarketplaceLifecycleService {
  constructor(private readonly prisma: PrismaService) {}

  async notifyUser(params: {
    userId: string;
    type: string;
    title: string;
    body?: string;
    linkUrl?: string;
    entityType?: string;
    entityId?: string;
  }) {
    return this.prisma.userNotification.create({
      data: {
        userId: params.userId,
        type: params.type,
        title: params.title,
        body: params.body ?? '',
        linkUrl: params.linkUrl,
        entityType: params.entityType,
        entityId: params.entityId,
      },
    });
  }

  async afterBookingCreated(bookingId: string) {
    const booking = await this.loadBooking(bookingId);
    if (!booking) return;
    await this.ensureConversation(bookingId);
    const place = booking.property.name;
    if (booking.userId) {
      await this.notifyUser({
        userId: booking.userId,
        type: 'BOOKING',
        title: 'تم استلام حجزك',
        body: `${place} — بانتظار التأكيد`,
        linkUrl: `/booking/${booking.id}`,
        entityType: 'booking',
        entityId: booking.id,
      });
    }
    const ownerId = booking.property.provider?.userId;
    if (ownerId) {
      await this.notifyUser({
        userId: ownerId,
        type: 'BOOKING',
        title: 'حجز جديد',
        body: `${booking.user?.name ?? booking.user?.phone ?? booking.guestName ?? 'ضيف'} طلب ${place}`,
        linkUrl: `/booking/${booking.id}`,
        entityType: 'booking',
        entityId: booking.id,
      });
    }
  }

  async afterBookingStatusChanged(bookingId: string, status: BookingStatus) {
    const booking = await this.loadBooking(bookingId);
    if (!booking) return;
    const place = booking.property.name;
    const copy = this.statusCopy(status, place);
    if (booking.userId) {
      await this.notifyUser({
        userId: booking.userId,
        type: 'BOOKING',
        title: copy.title,
        body: copy.body,
        linkUrl: `/booking/${booking.id}`,
        entityType: 'booking',
        entityId: booking.id,
      });
    }
    await this.postSystemMessage(bookingId, copy.body);
    if (status === BookingStatus.CONFIRMED || status === BookingStatus.COMPLETED) {
      await this.issueInvoice(bookingId, status === BookingStatus.CONFIRMED || status === BookingStatus.COMPLETED);
    }
  }

  async afterPaymentConfirmed(bookingId: string) {
    const booking = await this.loadBooking(bookingId);
    if (!booking) return;
    await this.issueInvoice(bookingId, true);
    if (booking.userId) {
      await this.notifyUser({
        userId: booking.userId,
        type: 'PAYMENT',
        title: 'تم تأكيد الدفع',
        body: `فاتورة ${booking.property.name} جاهزة`,
        linkUrl: `/booking/${booking.id}/invoice`,
        entityType: 'booking',
        entityId: booking.id,
      });
    }
    await this.postSystemMessage(bookingId, 'تم تأكيد الدفع وإصدار الفاتورة');
  }

  async afterPaymentRefunded(bookingId: string, note?: string) {
    await this.prisma.invoice.updateMany({
      where: { bookingId, status: { in: [InvoiceStatus.ISSUED, InvoiceStatus.PAID] } },
      data: { status: InvoiceStatus.REFUNDED },
    });
    const booking = await this.loadBooking(bookingId);
    if (!booking) return;
    if (booking.userId) {
      await this.notifyUser({
        userId: booking.userId,
        type: 'REFUND',
        title: 'تم استرداد المبلغ',
        body: note?.trim() || `استرداد حجز ${booking.property.name}`,
        linkUrl: `/booking/${booking.id}`,
        entityType: 'booking',
        entityId: booking.id,
      });
    }
    await this.postSystemMessage(bookingId, 'تم استرداد المبلغ وإلغاء الحجز');
  }

  async ensureConversation(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { property: { include: { provider: true } } },
    });
    if (!booking) return null;

    if (booking.userId) {
      const prior = await this.prisma.conversation.findFirst({
        where: { guestUserId: booking.userId, propertyId: booking.propertyId },
      });
      if (prior) {
        if (!prior.bookingId) {
          await this.prisma.conversation.update({
            where: { id: prior.id },
            data: { bookingId },
          });
          await this.prisma.message.create({
            data: {
              conversationId: prior.id,
              kind: MessageKind.SYSTEM,
              body: `تم إنشاء حجز ${booking.property.name}`,
            },
          });
        }
        return this.prisma.conversation.findUnique({ where: { id: prior.id } });
      }
    }

    const existing = await this.prisma.conversation.findUnique({ where: { bookingId } });
    if (existing) return existing;

    const participantIds = new Set<string>(booking.userId ? [booking.userId] : []);
    if (booking.property.provider?.userId) {
      participantIds.add(booking.property.provider.userId);
    } else if (booking.property.createdById) {
      participantIds.add(booking.property.createdById);
    }

    return this.prisma.conversation.create({
      data: {
        bookingId,
        propertyId: booking.propertyId,
        guestUserId: booking.userId,
        kind: ConversationKind.BOOKING,
        participants: {
          create: [...participantIds].map((userId) => ({ userId })),
        },
        messages: {
          create: {
            kind: MessageKind.SYSTEM,
            body: `بدأت محادثة حجز ${booking.property.name}`,
          },
        },
      },
    });
  }

  async issueInvoice(bookingId: string, markPaid = false) {
    const existing = await this.prisma.invoice.findUnique({ where: { bookingId } });
    if (existing) {
      if (markPaid && existing.status === InvoiceStatus.ISSUED) {
        return this.prisma.invoice.update({
          where: { id: existing.id },
          data: { status: InvoiceStatus.PAID, paidAt: new Date() },
        });
      }
      return existing;
    }

    const booking = await this.loadBooking(bookingId);
    if (!booking) return null;

    const subtotal = Number(booking.totalPrice) + Number(booking.discountAmount);
    const discount = Number(booking.discountAmount);
    const nights = Math.max(
      1,
      Math.ceil((booking.endDate.getTime() - booking.startDate.getTime()) / 86_400_000),
    );
    const paid =
      markPaid ||
      booking.payment?.status === PaymentStatus.PAID ||
      booking.status === BookingStatus.CONFIRMED ||
      booking.status === BookingStatus.COMPLETED;

    const year = new Date().getFullYear();
    const number = await this.nextInvoiceNumber(year);

    return this.prisma.invoice.create({
      data: {
        bookingId,
        number,
        status: paid ? InvoiceStatus.PAID : InvoiceStatus.ISSUED,
        subtotal,
        discount,
        total: Number(booking.totalPrice),
        items: invoiceItems({
          propertyName: booking.property.name,
          nights,
          subtotal,
          discount,
        }) as Prisma.InputJsonValue,
        paidAt: paid ? new Date() : null,
      },
    });
  }

  private async nextInvoiceNumber(year: number) {
    const last = await this.prisma.invoice.findFirst({
      where: { number: { startsWith: `VIB-${year}-` } },
      orderBy: { number: 'desc' },
      select: { number: true },
    });
    return formatInvoiceNumber(year, parseInvoiceSeq(last?.number ?? '', year) + 1);
  }

  private async postSystemMessage(bookingId: string, body: string) {
    const conversation = await this.ensureConversation(bookingId);
    if (!conversation) return;
    await this.prisma.message.create({
      data: {
        conversationId: conversation.id,
        kind: MessageKind.SYSTEM,
        body,
      },
    });
    await this.prisma.conversation.update({
      where: { id: conversation.id },
      data: { updatedAt: new Date() },
    });
  }

  private async loadBooking(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        payment: true,
        property: {
          select: {
            name: true,
            provider: { select: { userId: true } },
          },
        },
      },
    });
  }

  private statusCopy(status: BookingStatus, place: string) {
    switch (status) {
      case BookingStatus.CONFIRMED:
        return { title: 'تم تأكيد حجزك', body: `${place} جاهز في موعدك` };
      case BookingStatus.CANCELLED:
        return { title: 'أُلغي الحجز', body: `حجز ${place} لم يعد نشطاً` };
      case BookingStatus.COMPLETED:
        return { title: 'اكتمل حجزك', body: `نتمنى أن تكون استمتعت في ${place}` };
      case BookingStatus.DISPUTED:
        return { title: 'نزاع مفتوح', body: `فريق VIBES يتابع حجز ${place}` };
      case BookingStatus.AWAITING_PAYMENT:
        return { title: 'بانتظار الدفع', body: `أكمل التحويل لحجز ${place}` };
      default:
        return { title: 'تحديث الحجز', body: `حالة حجز ${place} تغيّرت` };
    }
  }
}
