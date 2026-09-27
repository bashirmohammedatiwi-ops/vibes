import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/invoice_print.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'booking_providers.dart';

final _invoiceProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  bookingId,
) async {
  try {
    final data = await ref
        .watch(apiClientProvider)
        .get('/api/invoices/by-booking/$bookingId');
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  return null;
});

class BookingInvoiceScreen extends ConsumerWidget {
  const BookingInvoiceScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingDetailProvider(bookingId));
    final invoice = ref.watch(_invoiceProvider(bookingId));
    final number = invoice.valueOrNull?['number'] as String?;

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: number ?? 'فاتورة الحجز',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: booking.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: const [
                    ShimmerBox(height: 160, radius: VibesRadius.xl),
                    SizedBox(height: 18),
                    ShimmerBox(height: 180, radius: VibesRadius.lg),
                    SizedBox(height: 18),
                    ShimmerBox(height: 140, radius: VibesRadius.lg),
                  ],
                ),
                error: (error, _) => ErrorCanvas(
                  message: maisonError(error),
                  onRetry: () =>
                      ref.invalidate(bookingDetailProvider(bookingId)),
                ),
                data: (value) => invoice.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: const [
                      ShimmerBox(height: 160, radius: VibesRadius.xl),
                      SizedBox(height: 18),
                      ShimmerBox(height: 180, radius: VibesRadius.lg),
                    ],
                  ),
                  error: (error, _) => _InvoiceContent(
                    booking: value,
                    invoice: null,
                    onPrint: () => printInvoiceHtml(
                      context,
                      ref.read(apiClientProvider),
                      path: '/api/invoices/by-booking/$bookingId/print',
                      fallbackText: _InvoiceContent(booking: value).shareText,
                    ),
                  ),
                  data: (row) => _InvoiceContent(
                    booking: value,
                    invoice: row,
                    onPrint: () => printInvoiceHtml(
                      context,
                      ref.read(apiClientProvider),
                      path: '/api/invoices/by-booking/$bookingId/print',
                      fallbackText: _InvoiceContent(
                        booking: value,
                        invoice: row,
                      ).shareText,
                      subject:
                          'فاتورة ${_InvoiceContent(booking: value, invoice: row).number}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceContent extends StatelessWidget {
  const _InvoiceContent({required this.booking, this.invoice, this.onPrint});

  final Booking booking;
  final Map<String, dynamic>? invoice;
  final Future<void> Function()? onPrint;

  String get number {
    final fromApi = invoice?['number'] as String?;
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    final year = (booking.createdAt ?? booking.startDate).year;
    final short = booking.id.replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'VIB-$year-$short';
  }

  num get _subtotal {
    final value = invoice?['subtotal'];
    if (value is num) return value;
    return booking.totalPrice + booking.discountAmount;
  }

  num get _discount {
    final value = invoice?['discount'];
    if (value is num) return value;
    return booking.discountAmount;
  }

  num get _total {
    final value = invoice?['total'];
    if (value is num) return value;
    return booking.totalPrice;
  }

  bool get _paid {
    final status = invoice?['status'] as String?;
    if (status == 'PAID') return true;
    if (status == 'REFUNDED' || status == 'VOID') return false;
    return booking.payment?.isPaid == true;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  List<({String label, num amount})> get _items {
    final raw = invoice?['items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (item) => (
              label: '${item['label'] ?? ''}',
              amount: item['amount'] is num
                  ? item['amount'] as num
                  : num.tryParse('${item['amount']}') ?? 0,
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList();
    }
    return [
      (
        label:
            'إقامة — ${booking.propertyName ?? 'مكان VIBEES'} (${booking.nights} يوم)',
        amount: _subtotal,
      ),
      if (_discount > 0) (label: 'خصم', amount: -_discount),
    ];
  }

  String get shareText {
    return [
      'فاتورة حجز VIBEES',
      'رقم الفاتورة: $number',
      'المكان: ${booking.propertyName ?? 'مكان VIBEES'}',
      'التاريخ: ${_date(booking.startDate)}',
      'المدة: ${booking.nights} ${booking.nights == 1 ? 'يوم' : 'أيام'}',
      ..._items.map(
        (item) => '${item.label}: ${PriceText.format(item.amount)} د.ع',
      ),
      'الإجمالي: ${PriceText.format(_total)} د.ع',
      'حالة الدفع: ${_paid ? 'مدفوعة' : 'بانتظار الدفع'}',
    ].join('\n');
  }

  Future<void> _print() async {
    if (onPrint != null) {
      await onPrint!();
      return;
    }
    await Share.share(shareText, subject: 'فاتورة $number');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        FolioPanel(
          color: VibesDark.canvas,
          borderColor: Colors.transparent,
          shadows: Vibes.floating,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CrestSeal(size: 28, color: Vibes.tealBright),
                    const SizedBox(width: 10),
                    Text(
                      'VIBEES',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    StatusPill(
                      label: _paid ? 'مدفوعة' : 'غير مدفوعة',
                      color: _paid ? Vibes.tealBright : Vibes.honey,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'فاتورة إلكترونية',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  number,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeader('تفاصيل الحجز'),
        VibesCard(
          child: Column(
            children: [
              _InvoiceRow(
                label: 'المكان',
                value: booking.propertyName ?? 'مكان VIBEES',
              ),
              _InvoiceRow(
                label: 'تاريخ الوصول',
                value: _date(booking.startDate),
              ),
              _InvoiceRow(
                label: 'تاريخ النهاية',
                value: _date(booking.endDate.subtract(const Duration(days: 1))),
              ),
              _InvoiceRow(label: 'الفترة', value: booking.shiftLabelAr),
              _InvoiceRow(
                label: 'الضيوف',
                value: '${booking.guests} ضيف',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader('الملخص المالي'),
        VibesCard(
          child: Column(
            children: [
              for (final item in _items)
                _MoneyRow(
                  label: item.label,
                  amount: item.amount,
                  color: item.amount < 0 ? SemanticColors.success : null,
                ),
              Divider(color: VibesTheme.hairlineOf(context), height: 24),
              Row(
                children: [
                  Text(
                    'الإجمالي',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  PriceText(_total),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        VibesButton(
          label: 'مشاركة الفاتورة',
          icon: Icons.ios_share_outlined,
          onPressed: () => Share.share(shareText),
        ),
        const SizedBox(height: 10),
        VibesButton(
          label: 'طباعة أو حفظ PDF',
          ghost: true,
          icon: Icons.picture_as_pdf_outlined,
          onPressed: _print,
        ),
        const SizedBox(height: 10),
        Text(
          'احفظ الفاتورة كملف PDF من خيار الطباعة في المتصفح. يعتمد إثبات الدفع النهائي بعد مراجعة العملية.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: VibesTheme.textTertiaryOf(context),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: VibesTheme.hairlineOf(context))),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VibesTheme.textTertiaryOf(context),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.amount, this.color});

  final String label;
  final num amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final negative = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VibesTheme.textSecondaryOf(context),
              ),
            ),
          ),
          Text(
            '${negative ? '− ' : ''}${PriceText.format(amount.abs())} د.ع',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? VibesTheme.textPrimaryOf(context),
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
