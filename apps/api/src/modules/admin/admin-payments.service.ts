import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, PaymentMethod, PaymentStatus, Prisma, NotificationType } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { NotificationService } from '../../common/services/notification.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';
import { MarketplaceLifecycleService } from '../marketplace/marketplace-lifecycle.service';

function proofPublicUrl(filename: string) {
  const base = (process.env.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media').replace(/\/$/, '');
  return `${base}/proofs/${filename}`;
}

@Injectable()
export class AdminPaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
    private readonly activity: ActivityLogService,
    private readonly notifications: NotificationService,
    private readonly lifecycle: MarketplaceLifecycleService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.PaymentWhereInput = {};
    if (query.status) where.status = query.status as PaymentStatus;
    if (query.method) where.method = query.method as PaymentMethod;
    if (query.hasProof === 'true') where.proofUrl = { not: null };
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(`${query.to}T23:59:59.999Z`);
    }
    if (query.q) {
      where.OR = [
        { transactionRef: { contains: query.q, mode: 'insensitive' } },
        { booking: { user: { phone: { contains: query.q } } } },
        { booking: { user: { name: { contains: query.q, mode: 'insensitive' } } } },
        { booking: { property: { name: { contains: query.q, mode: 'insensitive' } } } },
      ];
    }

    const [items, total, pendingProof] = await Promise.all([
      this.prisma.payment.findMany({
        where,
        include: {
          booking: {
            include: {
              user: { select: { name: true, phone: true } },
              property: { select: { name: true, slug: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.payment.count({ where }),
      this.prisma.payment.count({
        where: { status: PaymentStatus.PENDING, proofUrl: { not: null } },
      }),
    ]);

    return { ...this.pagination.wrap(items, total, page, pageSize), pendingProof };
  }

  async updateStatus(user: AuthUser, id: string, status: PaymentStatus) {
    return this.review(user, id, { status });
  }

  async review(
    user: AuthUser,
    id: string,
    data: { status: PaymentStatus; adminNote?: string; transactionRef?: string },
  ) {
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: { booking: { include: { property: true } } },
    });
    if (!payment) throw new NotFoundException('الدفعة غير موجودة');
    if (
      (data.status === PaymentStatus.FAILED || data.status === PaymentStatus.REFUNDED) &&
      !data.adminNote?.trim()
    ) {
      throw new BadRequestException('أضف ملاحظة قبل الرفض أو الاسترداد');
    }

    const updated = await this.prisma.payment.update({
      where: { id },
      data: {
        status: data.status,
        adminNote: data.adminNote,
        transactionRef: data.transactionRef,
        reviewedAt: new Date(),
        reviewedById: user.id,
      },
      include: {
        booking: {
          include: {
            user: { select: { name: true, phone: true } },
            property: { select: { name: true } },
          },
        },
      },
    });

    if (data.status === PaymentStatus.PAID && payment.booking) {
      await this.prisma.booking.update({
        where: { id: payment.bookingId },
        data: { status: BookingStatus.CONFIRMED },
      });
      await this.notifications.notify({
        type: NotificationType.PAYMENT_RECEIVED,
        title: `دفعة مؤكدة — ${payment.booking.property?.name ?? ''}`,
        body: `${Number(payment.amount).toLocaleString('ar-IQ')} د.ع`,
        linkUrl: `/bookings/${payment.bookingId}`,
        entityType: 'payment',
        entityId: id,
      });
      await this.lifecycle.afterPaymentConfirmed(payment.bookingId);
    }

    await this.activity.log({
      userId: user.id,
      action: 'payment.review',
      entityType: 'payment',
      entityId: id,
      metadata: { status: data.status },
    });

    return updated;
  }

  /** Refund marks the payment REFUNDED and releases the booking by cancelling it. */
  async refund(user: AuthUser, id: string, adminNote: string) {
    if (!adminNote?.trim()) throw new BadRequestException('أضف سبب الاسترداد');

    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: { booking: { include: { property: { select: { name: true } } } } },
    });
    if (!payment) throw new NotFoundException('الدفعة غير موجودة');
    if (payment.status === PaymentStatus.REFUNDED) {
      throw new BadRequestException('تم الاسترداد مسبقاً');
    }
    if (payment.status !== PaymentStatus.PAID) {
      throw new BadRequestException('لا يمكن استرداد دفعة غير مدفوعة');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const next = await tx.payment.update({
        where: { id },
        data: {
          status: PaymentStatus.REFUNDED,
          adminNote: adminNote.trim(),
          reviewedAt: new Date(),
          reviewedById: user.id,
        },
        include: {
          booking: {
            include: {
              user: { select: { name: true, phone: true } },
              property: { select: { name: true, slug: true } },
            },
          },
        },
      });

      if (payment.booking && payment.booking.status !== BookingStatus.CANCELLED) {
        await tx.booking.update({
          where: { id: payment.bookingId },
          data: { status: BookingStatus.CANCELLED },
        });
      }

      return next;
    });

    await this.notifications.notify({
      type: NotificationType.SYSTEM,
      title: `استرداد دفعة — ${payment.booking?.property?.name ?? ''}`,
      body: `${Number(payment.amount).toLocaleString('ar-IQ')} د.ع — ${adminNote.trim()}`,
      linkUrl: `/bookings/${payment.bookingId}`,
      entityType: 'payment',
      entityId: id,
    });

    await this.activity.log({
      userId: user.id,
      action: 'payment.refund',
      entityType: 'payment',
      entityId: id,
      metadata: { reason: adminNote.trim() },
    });

    await this.lifecycle.afterPaymentRefunded(payment.bookingId, adminNote);

    return updated;
  }

  async getOne(id: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: {
        booking: {
          include: {
            user: { select: { id: true, name: true, phone: true } },
            property: { select: { id: true, name: true, slug: true, type: true } },
          },
        },
      },
    });
    if (!payment) throw new NotFoundException('الدفعة غير موجودة');

    // reviewedById is a plain column, so the reviewer is resolved separately.
    const reviewedBy = payment.reviewedById
      ? await this.prisma.user.findUnique({
          where: { id: payment.reviewedById },
          select: { id: true, name: true, phone: true },
        })
      : null;

    return { ...payment, reviewedBy };
  }

  async bulkReview(user: AuthUser, ids: string[], status: PaymentStatus, adminNote?: string) {
    const results = [];
    for (const id of ids) {
      try {
        await this.review(user, id, { status, adminNote });
        results.push({ id, ok: true });
      } catch (err) {
        results.push({ id, ok: false, error: err instanceof Error ? err.message : 'failed' });
      }
    }
    return { updated: results.filter((r) => r.ok).length, failed: results.filter((r) => !r.ok).length, results };
  }

  async uploadProof(user: AuthUser, bookingId: string, file: Express.Multer.File) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true, property: { select: { name: true } }, user: { select: { name: true, phone: true } } },
    });
    if (!booking?.payment) throw new NotFoundException('الحجز أو الدفعة غير موجودة');

    const proofUrl = proofPublicUrl(file.filename);
    const updated = await this.prisma.payment.update({
      where: { id: booking.payment.id },
      data: { proofUrl, status: PaymentStatus.PENDING },
      include: {
        booking: {
          include: {
            user: { select: { name: true, phone: true } },
            property: { select: { name: true, slug: true } },
          },
        },
      },
    });

    if (booking.status === BookingStatus.PENDING) {
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.AWAITING_PAYMENT },
      });
    }

    await this.notifications.paymentProof({ id: booking.payment.id, booking });
    await this.activity.log({
      userId: user.id,
      action: 'payment.proof',
      entityType: 'payment',
      entityId: booking.payment.id,
      metadata: { bookingId },
    });

    return updated;
  }
}
