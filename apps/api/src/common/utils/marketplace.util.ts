/** سياسة الاسترداد: ≥7 أيام كامل، 3–6 أيام نصف، أقل من 3 لا استرداد. */
export function daysUntil(start: Date, now = new Date()): number {
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  const target = Date.UTC(start.getFullYear(), start.getMonth(), start.getDate());
  return Math.round((target - today) / 86_400_000);
}

export function refundPolicyRate(daysUntilStart: number): number {
  if (daysUntilStart >= 7) return 1;
  if (daysUntilStart >= 3) return 0.5;
  return 0;
}

export function expectedRefundAmount(total: number, startDate: Date, now = new Date()): number {
  const rate = refundPolicyRate(daysUntil(startDate, now));
  return Math.round(Number(total) * rate);
}

export function formatInvoiceNumber(year: number, seq: number): string {
  return `VIB-${year}-${String(seq).padStart(5, '0')}`;
}

export function parseInvoiceSeq(number: string, year: number): number {
  const prefix = `VIB-${year}-`;
  if (!number.startsWith(prefix)) return 0;
  return Number(number.slice(prefix.length)) || 0;
}

export function invoiceItems(params: {
  propertyName: string;
  nights: number;
  subtotal: number;
  discount: number;
}): Array<{ label: string; amount: number }> {
  const items = [{ label: `إقامة — ${params.propertyName} (${params.nights} يوم)`, amount: params.subtotal }];
  if (params.discount > 0) {
    items.push({ label: 'خصم', amount: -params.discount });
  }
  return items;
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const INVOICE_STATUS_AR: Record<string, string> = {
  ISSUED: 'صادرة',
  PAID: 'مدفوعة',
  VOID: 'ملغاة',
  REFUNDED: 'مستردة',
};

export type InvoicePrintInput = {
  number: string;
  status: string;
  subtotal: number | string;
  discount: number | string;
  total: number | string;
  issuedAt: Date | string;
  items?: unknown;
  booking?: {
    startDate?: Date | string;
    endDate?: Date | string;
    guests?: number;
    user?: { name?: string | null; phone?: string } | null;
    property?: { name?: string | null };
  } | null;
};

function moneyIq(value: number | string): string {
  return Math.round(Number(value) || 0).toLocaleString('ar-IQ');
}

function dayIq(value?: Date | string): string {
  if (!value) return '—';
  const date = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('ar-IQ');
}

/** فاتورة HTML جاهزة للطباعة أو الحفظ كـ PDF من المتصفح. */
export function invoicePrintHtml(invoice: InvoicePrintInput): string {
  const items = Array.isArray(invoice.items)
    ? (invoice.items as Array<{ label?: string; amount?: number | string }>)
    : [];
  const rows = items
    .map(
      (item) => `<tr>
        <td>${escapeHtml(String(item.label ?? ''))}</td>
        <td class="amt">${moneyIq(item.amount ?? 0)} د.ع</td>
      </tr>`,
    )
    .join('');
  const place = invoice.booking?.property?.name ?? 'مكان VIBES';
  const guest = invoice.booking?.user?.name || invoice.booking?.user?.phone || 'ضيف';
  const status = INVOICE_STATUS_AR[invoice.status] ?? invoice.status;

  return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(invoice.number)}</title>
  <style>
    body { font-family: "IBM Plex Sans Arabic", Tahoma, sans-serif; margin: 32px; color: #1a1a1a; }
    h1 { margin: 0 0 4px; font-size: 22px; }
    .muted { color: #666; font-size: 13px; }
    table { width: 100%; border-collapse: collapse; margin-top: 24px; }
    th, td { text-align: right; padding: 8px 0; border-bottom: 1px solid #eee; }
    .amt { font-variant-numeric: tabular-nums; white-space: nowrap; }
    .total { font-weight: 800; font-size: 18px; }
    @media print { body { margin: 12mm; } }
  </style>
</head>
<body>
  <h1>فاتورة VIBES</h1>
  <div class="muted">${escapeHtml(invoice.number)} · ${escapeHtml(status)} · ${dayIq(invoice.issuedAt)}</div>
  <p>المكان: <strong>${escapeHtml(place)}</strong><br/>
  الضيف: ${escapeHtml(guest)}<br/>
  التاريخ: ${dayIq(invoice.booking?.startDate)} — ${dayIq(invoice.booking?.endDate)}
  ${invoice.booking?.guests ? ` · ${invoice.booking.guests} ضيف` : ''}</p>
  <table>
    <thead><tr><th>البند</th><th>المبلغ</th></tr></thead>
    <tbody>${rows}</tbody>
    <tfoot>
      <tr><td>المجموع قبل الخصم</td><td class="amt">${moneyIq(invoice.subtotal)} د.ع</td></tr>
      <tr><td>الخصم</td><td class="amt">${moneyIq(invoice.discount)} د.ع</td></tr>
      <tr><td class="total">الإجمالي</td><td class="amt total">${moneyIq(invoice.total)} د.ع</td></tr>
    </tfoot>
  </table>
  <p class="muted">وثيقة إلكترونية — يمكن حفظها كملف PDF من خيار الطباعة في المتصفح.</p>
</body>
</html>`;
}
