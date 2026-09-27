import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { BookingStatus, OfferStatus, PaymentStatus, UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CommerceService } from './commerce.service';

describe('CommerceService', () => {
  const user = { id: 'u1', phone: '9647700000000', role: UserRole.CUSTOMER } as AuthUser;
  let prisma: Record<string, any>;
  let lifecycle: {
    afterBookingCreated: jest.Mock;
    notifyUser: jest.Mock;
    afterBookingStatusChanged: jest.Mock;
  };
  let service: CommerceService;

  beforeEach(() => {
    prisma = {
      booking: { findUnique: jest.fn(), update: jest.fn() },
      cancellationRequest: { findFirst: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
      refundRequest: { create: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
      priceOffer: { findUnique: jest.fn(), update: jest.fn() },
      $transaction: jest.fn(),
    };
    lifecycle = {
      afterBookingCreated: jest.fn(),
      notifyUser: jest.fn(),
      afterBookingStatusChanged: jest.fn(),
    };
    service = new CommerceService(prisma as never, lifecycle as never);
  });

  it('يرفض طلب الإلغاء قبل تأكيد الحجز', async () => {
    prisma.booking.findUnique.mockResolvedValue({
      id: 'b1',
      userId: 'u1',
      status: BookingStatus.PENDING,
    });
    await expect(service.requestCancellation(user, 'b1', '')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('ينشئ طلب إلغاء واسترداد وفق سياسة المبلغ', async () => {
    prisma.booking.findUnique.mockResolvedValue({
      id: 'b1',
      userId: 'u1',
      status: BookingStatus.CONFIRMED,
      totalPrice: 100_000,
      startDate: new Date('2026-09-20T00:00:00.000Z'),
      payment: { id: 'pay1', status: PaymentStatus.PAID },
      property: { name: 'مزرعة دجلة', provider: { userId: 'owner1' } },
    });
    prisma.cancellationRequest.findFirst.mockResolvedValue(null);
    prisma.cancellationRequest.create.mockResolvedValue({ id: 'c1' });
    prisma.refundRequest.create.mockResolvedValue({ id: 'r1' });

    const result = await service.requestCancellation(user, 'b1', 'سفر');
    expect(result).toEqual({ id: 'c1' });
    expect(prisma.cancellationRequest.create).toHaveBeenCalled();
    expect(prisma.refundRequest.create).toHaveBeenCalled();
    expect(lifecycle.notifyUser).toHaveBeenCalled();
  });

  it('يرفض قبول عرض منتهٍ', async () => {
    prisma.priceOffer.findUnique.mockResolvedValue({
      id: 'o1',
      customerId: 'u1',
      status: OfferStatus.PENDING,
      expiresAt: new Date('2020-01-01'),
      property: {},
      provider: {},
    });
    prisma.priceOffer.update.mockResolvedValue({});
    await expect(service.respondOffer(user, 'o1', true)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('يرفض قبول عرض لغير صاحبه', async () => {
    prisma.priceOffer.findUnique.mockResolvedValue({
      id: 'o1',
      customerId: 'other',
      status: OfferStatus.PENDING,
      expiresAt: null,
      property: {},
      provider: {},
    });
    await expect(service.respondOffer(user, 'o1', true)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('قبول العرض ينشئ حجزاً داخل معاملة واحدة', async () => {
    prisma.priceOffer.findUnique
      .mockResolvedValueOnce({
        id: 'o1',
        customerId: 'u1',
        status: OfferStatus.PENDING,
        expiresAt: null,
        propertyId: 'p1',
        startDate: new Date('2026-09-20'),
        endDate: new Date('2026-09-21'),
        shift: 'FULL',
        amount: 150_000,
        message: '',
        property: {},
        provider: {},
      })
      .mockResolvedValueOnce({ id: 'o1', status: OfferStatus.ACCEPTED, booking: { id: 'b9' } });
    prisma.$transaction.mockImplementation(async (fn: (tx: unknown) => Promise<unknown>) =>
      fn({
        booking: { create: jest.fn().mockResolvedValue({ id: 'b9' }) },
        priceOffer: { update: jest.fn() },
      }),
    );

    const result = await service.respondOffer(user, 'o1', true) as { booking?: { id: string } };
    expect(lifecycle.afterBookingCreated).toHaveBeenCalledWith('b9');
    expect(result.booking).toEqual({ id: 'b9' });
  });

  it('يرفض فاتورة غير موجودة', async () => {
    prisma.invoice = { findUnique: jest.fn().mockResolvedValue(null) };
    await expect(service.invoiceById(user, 'missing')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('يمنع مراجعة إلغاء لمكان لا يخص المالك', async () => {
    const owner = { id: 'owner1', phone: '9647700000001', role: UserRole.PROVIDER } as AuthUser;
    prisma.cancellationRequest.findUnique.mockResolvedValue({
      id: 'c1',
      status: 'PENDING',
      bookingId: 'b1',
      userId: 'u1',
      booking: { property: { provider: { userId: 'someone-else' } } },
    });
    await expect(
      service.reviewOwnedCancellation(owner, 'c1', { approve: true }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('موافقة المالك تلغي الحجز دون استرداد مالي تلقائي', async () => {
    const owner = { id: 'owner1', phone: '9647700000001', role: UserRole.PROVIDER } as AuthUser;
    prisma.cancellationRequest.findUnique.mockResolvedValue({
      id: 'c1',
      status: 'PENDING',
      bookingId: 'b1',
      userId: 'u1',
      booking: { property: { provider: { userId: 'owner1' } } },
    });
    prisma.refundRequest.findFirst.mockResolvedValue({ id: 'r1' });
    prisma.$transaction.mockImplementation(async (fn: (tx: typeof prisma) => Promise<unknown>) => fn(prisma));
    prisma.cancellationRequest.update.mockResolvedValue({});
    prisma.booking.update.mockResolvedValue({});

    const result = await service.reviewOwnedCancellation(owner, 'c1', { approve: true });
    expect(result).toEqual({ ok: true, refundPending: true });
    expect(prisma.booking.update).toHaveBeenCalled();
    expect(prisma.refundRequest.update).not.toHaveBeenCalled();
    expect(lifecycle.afterBookingStatusChanged).toHaveBeenCalledWith('b1', BookingStatus.CANCELLED);
  });
});
