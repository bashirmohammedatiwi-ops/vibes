import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  BookingStatus,
  OfferStatus,
  PaymentMethod,
  PaymentStatus,
  RequestStatus,
  ShiftType,
  UserRole,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { expectedRefundAmount, invoicePrintHtml } from '../../common/utils/marketplace.util';
import { PrismaService } from '../../prisma/prisma.service';
import { MarketplaceLifecycleService } from './marketplace-lifecycle.service';

@Injectable()
export class CommerceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycle: MarketplaceLifecycleService,
  ) {}

  async myInvoices(user: AuthUser) {
    return this.prisma.invoice.findMany({
      where: {
        booking: user.role === UserRole.PROVIDER
          ? { property: { provider: { userId: user.id } } }
          : { userId: user.id },
      },
      include: {
        booking: {
          select: {
            id: true,
            status: true,
            startDate: true,
            endDate: true,
            totalPrice: true,
            property: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { issuedAt: 'desc' },
      take: 100,
    });
  }

  async invoiceByBooking(user: AuthUser, bookingId: string) {
    await this.assertBookingAccess(user, bookingId);
    let invoice = await this.prisma.invoice.findUnique({
      where: { bookingId },
      include: {
        booking: {
          include: {
            user: { select: { name: true, phone: true } },
            payment: true,
            property: { select: { id: true, name: true } },
          },
        },
      },
    });
    if (!invoice) {
      await this.lifecycle.issueInvoice(bookingId, false);
      invoice = await this.prisma.invoice.findUnique({
        where: { bookingId },
        include: {
          booking: {
            include: {
              user: { select: { name: true, phone: true } },
              payment: true,
              property: { select: { id: true, name: true } },
            },
          },
        },
      });
    }
    if (!invoice) throw new NotFoundException('الفاتورة غير موجودة');
    return invoice;
  }

  async invoiceById(user: AuthUser, id: string) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { id },
      include: {
        booking: {
          include: {
            user: { select: { name: true, phone: true } },
            payment: true,
            property: { select: { id: true, name: true, provider: { select: { userId: true } } } },
          },
        },
      },
    });
    if (!invoice) throw new NotFoundException('الفاتورة غير موجودة');
    await this.assertBookingAccess(user, invoice.bookingId, invoice.booking);
    return invoice;
  }

  async invoicePrint(user: AuthUser, id: string) {
    const invoice = await this.invoiceById(user, id);
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

  async invoicePrintByBooking(user: AuthUser, bookingId: string) {
    const invoice = await this.invoiceByBooking(user, bookingId);
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

  async requestCancellation(user: AuthUser, bookingId: string, reason: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true, property: { select: { name: true, provider: { select: { userId: true } } } } },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    if (booking.userId !== user.id) throw new ForbiddenException('غير مسموح');
    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new BadRequestException('طلب الإلغاء بعد التأكيد فقط — استخدم الإلغاء المباشر قبل التأكيد');
    }

    const open = await this.prisma.cancellationRequest.findFirst({
      where: { bookingId, status: RequestStatus.PENDING },
    });
    if (open) return open;

    const expected = expectedRefundAmount(Number(booking.totalPrice), booking.startDate);
    const request = await this.prisma.cancellationRequest.create({
      data: {
        bookingId,
        userId: user.id,
        reason: reason.trim(),
        expectedRefund: expected,
      },
    });

    if (booking.payment?.status === PaymentStatus.PAID) {
      await this.prisma.refundRequest.create({
        data: {
          bookingId,
          paymentId: booking.payment.id,
          userId: user.id,
          reason: reason.trim() || 'إلغاء بعد التأكيد',
          amount: expected,
        },
      });
    }

    const ownerId = booking.property.provider?.userId;
    if (ownerId) {
      await this.lifecycle.notifyUser({
        userId: ownerId,
        type: 'REFUND',
        title: 'طلب إلغاء حجز',
        body: `${booking.property.name} — ${expected.toLocaleString('ar-IQ')} د.ع`,
        linkUrl: `/booking/${bookingId}`,
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return request;
  }

  async requestRefund(user: AuthUser, bookingId: string, reason: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true, property: { select: { name: true } } },
    });
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    if (booking.userId !== user.id) throw new ForbiddenException('غير مسموح');
    if (booking.payment?.status !== PaymentStatus.PAID) {
      throw new BadRequestException('لا توجد دفعة مؤكدة لاستردادها');
    }
    const open = await this.prisma.refundRequest.findFirst({
      where: { bookingId, status: RequestStatus.PENDING },
    });
    if (open) return open;

    const amount = expectedRefundAmount(Number(booking.totalPrice), booking.startDate);
    return this.prisma.refundRequest.create({
      data: {
        bookingId,
        paymentId: booking.payment.id,
        userId: user.id,
        reason: reason.trim(),
        amount,
      },
    });
  }

  async myRequests(user: AuthUser) {
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    const provider = user.role === UserRole.PROVIDER;
    const cancelWhere = staff
      ? {}
      : provider
        ? { booking: { property: { provider: { userId: user.id } } } }
        : { userId: user.id };
    const refundWhere = staff
      ? {}
      : provider
        ? { booking: { property: { provider: { userId: user.id } } } }
        : { userId: user.id };

    const [cancellations, refunds] = await Promise.all([
      this.prisma.cancellationRequest.findMany({
        where: cancelWhere,
        include: {
          booking: { select: { id: true, status: true, property: { select: { name: true } } } },
          user: { select: { id: true, name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.refundRequest.findMany({
        where: refundWhere,
        include: {
          booking: { select: { id: true, status: true, property: { select: { name: true } } } },
          user: { select: { id: true, name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);
    return { cancellations, refunds };
  }

  async reviewOwnedCancellation(
    user: AuthUser,
    id: string,
    dto: { approve: boolean; note?: string },
  ) {
    const request = await this.prisma.cancellationRequest.findUnique({
      where: { id },
      include: {
        booking: {
          include: {
            payment: true,
            property: { include: { provider: { select: { userId: true } } } },
          },
        },
      },
    });
    if (!request) throw new NotFoundException('طلب الإلغاء غير موجود');
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    const owner = request.booking.property.provider?.userId === user.id;
    if (!owner && !staff) throw new ForbiddenException('غير مسموح');
    if (request.status !== RequestStatus.PENDING) {
      throw new BadRequestException('تمت مراجعة هذا الطلب');
    }
    if (!dto.approve && !dto.note?.trim()) {
      throw new BadRequestException('أضف سبب الرفض');
    }

    const refund = await this.prisma.refundRequest.findFirst({
      where: { bookingId: request.bookingId, status: RequestStatus.PENDING },
    });

    await this.prisma.$transaction(async (tx) => {
      await tx.cancellationRequest.update({
        where: { id },
        data: {
          status: dto.approve ? RequestStatus.APPROVED : RequestStatus.REJECTED,
          adminNote: dto.note?.trim(),
          reviewedById: user.id,
          reviewedAt: new Date(),
        },
      });
      if (!dto.approve && refund) {
        await tx.refundRequest.update({
          where: { id: refund.id },
          data: {
            status: RequestStatus.REJECTED,
            adminNote: dto.note?.trim(),
            reviewedById: user.id,
            reviewedAt: new Date(),
          },
        });
      }
      if (dto.approve) {
        await tx.booking.update({
          where: { id: request.bookingId },
          data: { status: BookingStatus.CANCELLED },
        });
      }
    });

    if (dto.approve) {
      await this.lifecycle.afterBookingStatusChanged(request.bookingId, BookingStatus.CANCELLED);
    } else {
      await this.lifecycle.notifyUser({
        userId: request.userId,
        type: 'BOOKING',
        title: 'رُفض طلب الإلغاء',
        body: dto.note?.trim() || 'راجع تفاصيل الحجز مع المالك',
        linkUrl: `/booking/${request.bookingId}`,
        entityType: 'booking',
        entityId: request.bookingId,
      });
    }

    return { ok: true, refundPending: dto.approve && !!refund };
  }

  async createOffer(
    user: AuthUser,
    dto: {
      propertyId: string;
      customerPhone: string;
      startDate: string;
      endDate: string;
      amount: number;
      shift?: ShiftType;
      message?: string;
      expiresAt?: string;
    },
  ) {
    const provider = await this.prisma.provider.findUnique({ where: { userId: user.id } });
    if (!provider) throw new ForbiddenException('حساب مزود غير موجود');

    const property = await this.prisma.property.findUnique({ where: { id: dto.propertyId } });
    if (!property || property.providerId !== provider.id) {
      throw new ForbiddenException('المكان لا يخصك');
    }

    const customer = await this.prisma.user.findUnique({ where: { phone: dto.customerPhone } });
    if (!customer) throw new NotFoundException('العميل غير موجود — يجب أن يملك حساباً بنفس الرقم');

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('تواريخ غير صالحة');
    }
    if (!(dto.amount > 0)) throw new BadRequestException('المبلغ غير صالح');

    const offer = await this.prisma.priceOffer.create({
      data: {
        providerId: provider.id,
        propertyId: property.id,
        customerId: customer.id,
        createdById: user.id,
        startDate: start,
        endDate: end,
        shift: dto.shift ?? ShiftType.FULL,
        amount: dto.amount,
        message: dto.message?.trim() ?? '',
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
      },
      include: {
        property: { select: { id: true, name: true } },
        customer: { select: { id: true, name: true, phone: true } },
      },
    });

    await this.lifecycle.notifyUser({
      userId: customer.id,
      type: 'OFFER',
      title: 'عرض سعر خاص',
      body: `${property.name} — ${dto.amount.toLocaleString('ar-IQ')} د.ع`,
      linkUrl: `/offers`,
      entityType: 'offer',
      entityId: offer.id,
    });

    return offer;
  }

  async myOffers(user: AuthUser) {
    if (user.role === UserRole.PROVIDER) {
      return this.prisma.priceOffer.findMany({
        where: { provider: { userId: user.id } },
        include: {
          property: { select: { id: true, name: true } },
          customer: { select: { id: true, name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });
    }
    return this.prisma.priceOffer.findMany({
      where: { customerId: user.id },
      include: {
        property: { select: { id: true, name: true } },
        provider: { select: { businessName: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async respondOffer(user: AuthUser, id: string, accept: boolean) {
    const offer = await this.prisma.priceOffer.findUnique({
      where: { id },
      include: { property: true, provider: true },
    });
    if (!offer) throw new NotFoundException('العرض غير موجود');
    if (offer.customerId !== user.id) throw new ForbiddenException('غير مسموح');
    if (offer.status !== OfferStatus.PENDING) {
      throw new BadRequestException('هذا العرض لم يعد متاحاً');
    }
    if (offer.expiresAt && offer.expiresAt < new Date()) {
      await this.prisma.priceOffer.update({
        where: { id },
        data: { status: OfferStatus.EXPIRED },
      });
      throw new BadRequestException('انتهت صلاحية العرض');
    }

    if (!accept) {
      return this.prisma.priceOffer.update({
        where: { id },
        data: { status: OfferStatus.DECLINED },
      });
    }

    const booking = await this.prisma.$transaction(async (tx) => {
      const created = await tx.booking.create({
        data: {
          userId: user.id,
          propertyId: offer.propertyId,
          startDate: offer.startDate,
          endDate: offer.endDate,
          shift: offer.shift,
          guests: 1,
          notes: offer.message || 'حجز من عرض سعر خاص',
          status: BookingStatus.PENDING,
          totalPrice: offer.amount,
          discountAmount: 0,
          payment: {
            create: {
              method: PaymentMethod.MANUAL,
              amount: offer.amount,
              status: PaymentStatus.PENDING,
            },
          },
        },
      });
      await tx.priceOffer.update({
        where: { id },
        data: { status: OfferStatus.ACCEPTED, bookingId: created.id },
      });
      return created;
    });

    await this.lifecycle.afterBookingCreated(booking.id);
    return this.prisma.priceOffer.findUnique({
      where: { id },
      include: { booking: true, property: { select: { id: true, name: true } } },
    });
  }

  private async assertBookingAccess(
    user: AuthUser,
    bookingId: string,
    loaded?: { userId?: string | null; property?: { provider?: { userId: string } | null } | null },
  ) {
    const staff = user.role === UserRole.ADMIN || user.role === UserRole.STAFF;
    if (staff) return;
    const booking =
      loaded ??
      (await this.prisma.booking.findUnique({
        where: { id: bookingId },
        include: { property: { include: { provider: true } } },
      }));
    if (!booking) throw new NotFoundException('الحجز غير موجود');
    const owner = booking.property?.provider?.userId === user.id;
    if (booking.userId !== user.id && !owner) throw new ForbiddenException('غير مسموح');
  }
}
