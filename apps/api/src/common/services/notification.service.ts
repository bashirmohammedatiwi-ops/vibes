import { Injectable, Logger } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { SmsService } from './sms.service';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sms: SmsService,
  ) {}

  notify(params: {
    type: NotificationType;
    title: string;
    body?: string;
    linkUrl?: string;
    entityType?: string;
    entityId?: string;
  }) {
    return this.prisma.teamNotification.create({
      data: {
        type: params.type,
        title: params.title,
        body: params.body ?? '',
        linkUrl: params.linkUrl,
        entityType: params.entityType,
        entityId: params.entityId,
      },
    });
  }

  /**
   * Multi-channel fan-out for booking events: in-app team notification (always)
   * plus best-effort WhatsApp to the property owner when the channel toggle
   * (`notify_whatsapp_enabled` platform setting) is on.
   */
  async notifyBookingEvent(booking: {
    id: string;
    status?: string;
    propertyId: string;
    property?: { name?: string; provider?: { user?: { phone: string } | null } | null };
    user?: { name?: string | null; phone: string };
  }, event: 'created' | 'status') {
    const title =
      event === 'created'
        ? `حجز جديد — ${booking.property?.name ?? 'مكان'}`
        : `تحديث حجز — ${booking.property?.name ?? ''}`;
    const body =
      event === 'created'
        ? `من ${booking.user?.name ?? booking.user?.phone ?? 'عميل'}`
        : `الحالة: ${booking.status ?? ''}`;

    await this.notify({
      type: event === 'created' ? NotificationType.BOOKING_NEW : NotificationType.BOOKING_STATUS,
      title,
      body,
      linkUrl: `/bookings/${booking.id}`,
      entityType: 'booking',
      entityId: booking.id,
    });

    await this.dispatchToProviderPhone(
      booking.propertyId,
      `${title}\n${body}`,
    ).catch(() => undefined);
  }

  /** WhatsApp fan-out to a property owner — silently skipped when disabled. */
  private async dispatchToProviderPhone(propertyId: string, message: string) {
    const [enabled, property] = await Promise.all([
      this.prisma.platformSetting.findUnique({ where: { key: 'notify_whatsapp_enabled' } }),
      this.prisma.property.findUnique({
        where: { id: propertyId },
        select: { provider: { select: { user: { select: { phone: true } } } } },
      }),
    ]);
    if (enabled?.value !== 'true') return;
    const phone = property?.provider?.user?.phone;
    if (!phone) return;
    const result = await this.sms.sendWhatsappText(phone, message);
    if (!result.sent) {
      this.logger.debug(`WhatsApp notify skipped for property ${propertyId}`);
    }
  }

  bookingCreated(booking: { id: string; property?: { name: string }; user?: { name?: string | null; phone: string } }) {
    return this.notify({
      type: NotificationType.BOOKING_NEW,
      title: `حجز جديد — ${booking.property?.name ?? 'مكان'}`,
      body: `من ${booking.user?.name ?? booking.user?.phone ?? 'عميل'}`,
      linkUrl: `/bookings/${booking.id}`,
      entityType: 'booking',
      entityId: booking.id,
    });
  }

  bookingStatus(booking: { id: string; status: string; property?: { name: string } }) {
    return this.notify({
      type: NotificationType.BOOKING_STATUS,
      title: `تحديث حجز — ${booking.property?.name ?? ''}`,
      body: `الحالة: ${booking.status}`,
      linkUrl: `/bookings/${booking.id}`,
      entityType: 'booking',
      entityId: booking.id,
    });
  }

  paymentProof(payment: { id: string; booking?: { property?: { name: string } } }) {
    return this.notify({
      type: NotificationType.PAYMENT_PROOF,
      title: 'إثبات دفع جديد',
      body: payment.booking?.property?.name ?? '',
      linkUrl: '/payments?pending=1',
      entityType: 'payment',
      entityId: payment.id,
    });
  }

  disputeOpened(booking: { id: string; property?: { name: string }; disputeReason?: string | null }) {
    return this.notify({
      type: NotificationType.SYSTEM,
      title: `نزاع — ${booking.property?.name ?? 'حجز'}`,
      body: booking.disputeReason ?? 'تم فتح نزاع',
      linkUrl: `/bookings/${booking.id}`,
      entityType: 'booking',
      entityId: booking.id,
    });
  }

  reviewNew(review: { id: string; rating: number; property?: { id: string; name: string } }) {
    return this.notify({
      type: NotificationType.REVIEW_NEW,
      title: `تقييم جديد — ${review.property?.name ?? ''}`,
      body: `${review.rating} نجوم`,
      linkUrl: review.property?.id ? `/reviews?propertyId=${review.property.id}` : '/reviews',
      entityType: 'review',
      entityId: review.id,
    });
  }

  propertyPending(property: { id: string; name: string }) {
    return this.notify({
      type: NotificationType.PROPERTY_PENDING,
      title: `مكان جديد — ${property.name}`,
      body: 'بانتظار المراجعة',
      linkUrl: `/properties/${property.id}/edit`,
      entityType: 'property',
      entityId: property.id,
    });
  }

  providerRequest(provider: { id: string; businessName?: string | null; phone: string }) {
    return this.notify({
      type: NotificationType.SYSTEM,
      title: `طلب مزود — ${provider.businessName || provider.phone}`,
      body: 'بانتظار موافقة الفريق قبل الرفع من التطبيق',
      linkUrl: '/providers',
      entityType: 'provider',
      entityId: provider.id,
    });
  }
}
