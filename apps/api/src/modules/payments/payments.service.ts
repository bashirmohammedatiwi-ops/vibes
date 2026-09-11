import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import {
  BookingStatus,
  NotificationType,
  PaymentMethod,
  PaymentStatus,
  UserRole,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { NotificationService } from '../../common/services/notification.service';
import { PrismaService } from '../../prisma/prisma.service';
import { GatewayProvider, PaymentGatewayService } from './payment-gateway.service';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: PaymentGatewayService,
    private readonly notifications: NotificationService,
  ) {}

  async initiateGateway(user: AuthUser, bookingId: string, method: PaymentMethod) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');

    const isStaff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    if (booking.userId !== user.id && !isStaff) {
      throw new ForbiddenException('غير مصرح');
    }

    if (!booking.payment) throw new NotFoundException('لا توجد دفعة مرتبطة');
    if (booking.payment.status === PaymentStatus.PAID) {
      throw new BadRequestException('تم الدفع مسبقاً');
    }

    const result = this.gateway.initiate(method, Number(booking.payment.amount), bookingId);

    await this.prisma.payment.update({
      where: { id: booking.payment.id },
      data: {
        method,
        transactionRef: result.reference,
        status: PaymentStatus.PENDING,
      },
    });

    await this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: BookingStatus.AWAITING_PAYMENT },
    });

    return result;
  }

  /**
   * Gateway webhook entry point. Idempotent: a reference already marked PAID is
   * acknowledged without touching the booking again.
   */
  async handleCallback(
    provider: GatewayProvider,
    payload: Record<string, unknown>,
    options: { rawBody: string; signature?: string },
  ) {
    const event = this.gateway.parseCallback(provider, payload, options);

    const payment = await this.prisma.payment.findFirst({
      where: { transactionRef: event.reference },
      include: { booking: { include: { property: { select: { name: true } } } } },
    });
    if (!payment) throw new NotFoundException('لا توجد دفعة بهذا المرجع');

    if (payment.status === PaymentStatus.PAID) {
      return { ok: true, status: payment.status, alreadyProcessed: true };
    }

    if (event.amount != null && Math.round(event.amount) !== Math.round(Number(payment.amount))) {
      throw new BadRequestException('المبلغ لا يطابق قيمة الدفعة');
    }

    if (!event.paid && !event.failed) {
      return { ok: true, status: payment.status, ignored: event.rawStatus };
    }

    const nextStatus = event.paid ? PaymentStatus.PAID : PaymentStatus.FAILED;

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: nextStatus,
        method: event.method,
        adminNote: `بوابة ${provider}: ${event.rawStatus}`,
        reviewedAt: new Date(),
      },
    });

    if (event.paid) {
      await this.prisma.booking.update({
        where: { id: payment.bookingId },
        data: { status: BookingStatus.CONFIRMED },
      });
      await this.notifications.notify({
        type: NotificationType.PAYMENT_RECEIVED,
        title: `دفعة إلكترونية مؤكدة — ${payment.booking?.property?.name ?? ''}`,
        body: `${Number(payment.amount).toLocaleString('ar-IQ')} د.ع عبر ${provider}`,
        linkUrl: `/bookings/${payment.bookingId}`,
        entityType: 'payment',
        entityId: payment.id,
      });
    } else {
      await this.notifications.notify({
        type: NotificationType.SYSTEM,
        title: `فشل دفع إلكتروني — ${payment.booking?.property?.name ?? ''}`,
        body: `الحالة: ${event.rawStatus}`,
        linkUrl: `/bookings/${payment.bookingId}`,
        entityType: 'payment',
        entityId: payment.id,
      });
    }

    return { ok: true, status: nextStatus };
  }
}
