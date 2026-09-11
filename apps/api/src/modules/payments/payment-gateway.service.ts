import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentMethod } from '@prisma/client';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { v4 as uuid } from 'uuid';

export type GatewayProvider = 'zain-cash' | 'qi-card';

export type GatewayCallback = {
  method: PaymentMethod;
  reference: string;
  paid: boolean;
  failed: boolean;
  transactionId?: string;
  amount?: number;
  rawStatus: string;
};

const PAID_STATUSES = ['success', 'paid', 'completed', 'approved'];
const FAILED_STATUSES = ['failed', 'declined', 'cancelled', 'canceled', 'expired', 'error'];

@Injectable()
export class PaymentGatewayService {
  constructor(private readonly config: ConfigService) {}

  methodFor(provider: GatewayProvider) {
    return provider === 'zain-cash' ? PaymentMethod.ZAIN_CASH : PaymentMethod.QI_CARD;
  }

  /**
   * Gateways post back an HMAC-SHA256 of the raw body. When no secret is configured
   * the callback is accepted unsigned so sandbox flows stay testable.
   */
  private assertSignature(provider: GatewayProvider, rawBody: string, signature?: string) {
    const secret = this.config.get<string>(
      provider === 'zain-cash' ? 'ZAIN_CASH_SECRET' : 'QI_CARD_SECRET',
    );
    if (!secret) return;

    if (!signature) throw new UnauthorizedException('توقيع البوابة مفقود');

    const expected = createHmac('sha256', secret).update(rawBody).digest('hex');
    const given = signature.replace(/^sha256=/, '').trim();
    if (
      given.length !== expected.length ||
      !timingSafeEqual(Buffer.from(given, 'utf8'), Buffer.from(expected, 'utf8'))
    ) {
      throw new UnauthorizedException('توقيع البوابة غير صحيح');
    }
  }

  parseCallback(
    provider: GatewayProvider,
    payload: Record<string, unknown>,
    options: { rawBody: string; signature?: string },
  ): GatewayCallback {
    this.assertSignature(provider, options.rawBody, options.signature);

    const reference = String(payload.ref ?? payload.reference ?? payload.orderId ?? '').trim();
    if (!reference) throw new BadRequestException('مرجع العملية مفقود');

    const rawStatus = String(payload.status ?? payload.state ?? payload.result ?? '')
      .trim()
      .toLowerCase();
    if (!rawStatus) throw new BadRequestException('حالة العملية مفقودة');

    const amountRaw = payload.amount ?? payload.total;
    const amount = amountRaw != null && amountRaw !== '' ? Number(amountRaw) : undefined;

    return {
      method: this.methodFor(provider),
      reference,
      paid: PAID_STATUSES.includes(rawStatus),
      failed: FAILED_STATUSES.includes(rawStatus),
      transactionId: payload.transactionId ? String(payload.transactionId) : undefined,
      amount: Number.isFinite(amount) ? amount : undefined,
      rawStatus,
    };
  }

  private callbackUrl(provider: GatewayProvider) {
    const base = (
      this.config.get<string>('API_PUBLIC_URL') ??
      this.config.get<string>('MEDIA_PUBLIC_URL')?.replace(/\/media\/?$/, '') ??
      'http://localhost:3000'
    ).replace(/\/$/, '');
    return `${base}/api/payments/callback/${provider}`;
  }

  initiate(method: PaymentMethod, amount: number, bookingId: string) {
    const reference = `VIBES-${bookingId.slice(0, 8)}-${uuid().slice(0, 8)}`;

    if (method === PaymentMethod.ZAIN_CASH) {
      const merchantId = this.config.get<string>('ZAIN_CASH_MERCHANT_ID');
      if (!merchantId) {
        return {
          method,
          reference,
          sandbox: true,
          redirectUrl: `${this.config.get('PUBLIC_WEB_URL', 'https://vibes.iq')}/payments/zain-cash?ref=${reference}&amount=${amount}`,
          message: 'وضع تجريبي — اربط ZAIN_CASH_MERCHANT_ID للإنتاج',
        };
      }
      return {
        method,
        reference,
        redirectUrl: `https://api.zaincash.iq/transaction/pay?ref=${reference}`,
        callbackUrl: this.callbackUrl('zain-cash'),
      };
    }

    if (method === PaymentMethod.QI_CARD) {
      const terminalId = this.config.get<string>('QI_CARD_TERMINAL_ID');
      if (!terminalId) {
        return {
          method,
          reference,
          sandbox: true,
          redirectUrl: `${this.config.get('PUBLIC_WEB_URL', 'https://vibes.iq')}/payments/qi-card?ref=${reference}&amount=${amount}`,
          message: 'وضع تجريبي — اربط QI_CARD_TERMINAL_ID للإنتاج',
        };
      }
      return {
        method,
        reference,
        redirectUrl: `https://pay.qi.iq/checkout?terminal=${terminalId}&ref=${reference}`,
        callbackUrl: this.callbackUrl('qi-card'),
      };
    }

    throw new BadRequestException('طريقة الدفع غير مدعومة للبوابة الإلكترونية');
  }
}
