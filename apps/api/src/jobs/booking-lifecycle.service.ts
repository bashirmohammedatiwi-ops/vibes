import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { BookingStatus, PaymentStatus } from '@prisma/client';
import { NotificationService } from '../common/services/notification.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Automates booking state transitions that would otherwise require manual
 * admin cleanup: cancelling stale unpaid holds and closing out past stays.
 */
@Injectable()
export class BookingLifecycleService {
  private readonly logger = new Logger(BookingLifecycleService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
  ) {}

  private autoCancelHours() {
    return Number(process.env.BOOKING_AUTO_CANCEL_HOURS ?? 24);
  }

  @Cron('*/15 * * * *')
  async cancelStalePendingBookings() {
    const hours = this.autoCancelHours();
    if (!hours || hours <= 0) return;

    const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000);
    const stale = await this.prisma.booking.findMany({
      where: {
        status: { in: [BookingStatus.PENDING, BookingStatus.AWAITING_PAYMENT] },
        createdAt: { lt: cutoff },
      },
      select: { id: true, property: { select: { name: true } } },
      take: 200,
    });
    if (!stale.length) return;

    await this.prisma.$transaction([
      this.prisma.booking.updateMany({
        where: { id: { in: stale.map((b) => b.id) } },
        data: { status: BookingStatus.CANCELLED },
      }),
      this.prisma.payment.updateMany({
        where: { bookingId: { in: stale.map((b) => b.id) }, status: PaymentStatus.PENDING },
        data: { status: PaymentStatus.FAILED },
      }),
    ]);

    for (const booking of stale) {
      await this.notifications
        .bookingStatus({ id: booking.id, status: BookingStatus.CANCELLED, property: booking.property })
        .catch(() => undefined);
    }

    this.logger.log(`Auto-cancelled ${stale.length} stale booking(s) past ${hours}h unpaid`);
  }

  @Cron(CronExpression.EVERY_HOUR)
  async completePastBookings() {
    const now = new Date();
    const result = await this.prisma.booking.updateMany({
      where: { status: BookingStatus.CONFIRMED, endDate: { lt: now } },
      data: { status: BookingStatus.COMPLETED },
    });
    if (result.count > 0) {
      this.logger.log(`Marked ${result.count} past booking(s) as completed`);
    }
  }
}
