import {
  daysUntil,
  escapeHtml,
  expectedRefundAmount,
  formatInvoiceNumber,
  invoiceItems,
  invoicePrintHtml,
  parseInvoiceSeq,
  refundPolicyRate,
} from './marketplace.util';

describe('marketplace.util', () => {
  const now = new Date('2026-09-13T12:00:00.000Z');

  it('يحسب الأيام حتى تاريخ البداية بالتقويم لا بالساعات', () => {
    expect(daysUntil(new Date(2026, 8, 20), now)).toBe(7);
    expect(daysUntil(new Date(2026, 8, 13), now)).toBe(0);
  });

  it('يطبق سياسة الاسترداد المتدرجة', () => {
    expect(refundPolicyRate(7)).toBe(1);
    expect(refundPolicyRate(3)).toBe(0.5);
    expect(refundPolicyRate(2)).toBe(0);
    expect(expectedRefundAmount(100_000, new Date('2026-09-20'), now)).toBe(100_000);
    expect(expectedRefundAmount(100_000, new Date('2026-09-16'), now)).toBe(50_000);
    expect(expectedRefundAmount(100_000, new Date('2026-09-14'), now)).toBe(0);
  });

  it('يرقّم الفواتير تسلسلياً', () => {
    expect(formatInvoiceNumber(2026, 1)).toBe('VIB-2026-00001');
    expect(parseInvoiceSeq('VIB-2026-00042', 2026)).toBe(42);
    expect(parseInvoiceSeq('VIB-2025-00042', 2026)).toBe(0);
  });

  it('يبني بنود الفاتورة مع الخصم', () => {
    const items = invoiceItems({ propertyName: 'مزرعة دجلة', nights: 2, subtotal: 200_000, discount: 20_000 });
    expect(items).toEqual([
      { label: 'إقامة — مزرعة دجلة (2 يوم)', amount: 200_000 },
      { label: 'خصم', amount: -20_000 },
    ]);
  });

  it('يبني HTML فاتورة للطباعة ويهرب HTML', () => {
    const html = invoicePrintHtml({
      number: 'VIB-2026-00001',
      status: 'PAID',
      subtotal: 200_000,
      discount: 20_000,
      total: 180_000,
      issuedAt: '2026-09-13',
      items: [{ label: 'إقامة <script>', amount: 200_000 }],
      booking: {
        property: { name: 'مزرعة دجلة' },
        user: { name: 'أحمد' },
        startDate: '2026-09-20',
        endDate: '2026-09-22',
        guests: 8,
      },
    });
    expect(html).toContain('VIB-2026-00001');
    expect(html).toContain('مدفوعة');
    expect(html).toContain('مزرعة دجلة');
    expect(html).not.toContain('<script>');
    expect(escapeHtml('<x>')).toBe('&lt;x&gt;');
  });
});
