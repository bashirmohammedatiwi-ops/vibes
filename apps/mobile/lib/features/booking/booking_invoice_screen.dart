import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
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

    final palette = WorldPalette.forType(booking.valueOrNull?.propertyType);
    return AnimatedTheme(
      data: applyWorld(Theme.of(context), palette),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    PressScale(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: Vibes.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الفاتورة',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Vibes.ink,
                        ),
                      ),
                    ),
                    if (number != null)
                      Text(
                        number,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Vibes.inkTertiary,
                        ),
                      ),
                  ],
                ),
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
            'إقامة — ${booking.propertyName ?? 'مكان VIBES'} (${booking.nights} يوم)',
        amount: _subtotal,
      ),
      if (_discount > 0) (label: 'خصم', amount: -_discount),
    ];
  }

  String get shareText {
    return [
      'فاتورة حجز VIBES',
      'رقم الفاتورة: $number',
      'المكان: ${booking.propertyName ?? 'مكان VIBES'}',
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
    final p = context.world;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
      children: [
        // ── الورقة ──
        ClipPath(
          clipper: const _ZigzagBottom(),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // رأس بلون العالم
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(gradient: p.nightfall),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const VibesLogo.mark(size: 30, color: Colors.white),
                          const SizedBox(width: 10),
                          const Text(
                            'VIBES',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          WorldStatusChip(
                            label: _paid ? 'مدفوعة' : 'غير مدفوعة',
                            color: _paid
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'فاتورة إلكترونية',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        number,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white.withValues(alpha: .75),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Label('تفاصيل الحجز'),
                      _InvoiceRow(
                        label: 'المكان',
                        value: booking.propertyName ?? 'مكان VIBES',
                      ),
                      _InvoiceRow(
                        label: 'تاريخ الوصول',
                        value: _date(booking.startDate),
                      ),
                      _InvoiceRow(
                        label: 'تاريخ النهاية',
                        value: _date(
                          booking.endDate.subtract(const Duration(days: 1)),
                        ),
                      ),
                      _InvoiceRow(label: 'الفترة', value: booking.shiftLabelAr),
                      _InvoiceRow(
                        label: 'الضيوف',
                        value: '${booking.guests} ضيف',
                        last: true,
                      ),
                      const SizedBox(height: 18),
                      _Label('الملخص المالي'),
                      for (final item in _items)
                        _MoneyRow(
                          label: item.label,
                          amount: item.amount,
                          color: item.amount < 0
                              ? const Color(0xFF0E9F6E)
                              : null,
                        ),
                      const SizedBox(height: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: p.accentFaint,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    'الإجمالي',
                                    style: TextStyle(
                                      fontFamily: VibesFont.ui,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Vibes.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatIqdShort(_total),
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Vibes.ink,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'د.ع',
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: p.accentDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_paid)
                            PositionedDirectional(
                              start: 70,
                              top: -26,
                              child: Transform.rotate(
                                angle: -.22,
                                child: const _PaidStamp(),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        WorldButton(
          label: 'مشاركة الفاتورة',
          icon: Icons.ios_share_rounded,
          onTap: () => Share.share(shareText),
        ),
        const SizedBox(height: 10),
        WorldGhostButton(
          label: 'طباعة أو حفظ PDF',
          icon: Icons.picture_as_pdf_outlined,
          onTap: _print,
        ),
        const SizedBox(height: 12),
        Text(
          'احفظ الفاتورة كملف PDF من خيار الطباعة. يُعتمد إثبات الدفع النهائي بعد مراجعة العملية.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Vibes.inkTertiary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: context.world.accentDeep,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

/// ختم «مدفوعة» مائل بإطار مزدوج.
class _PaidStamp extends StatelessWidget {
  const _PaidStamp();

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF0E9F6E);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: .8), width: 1.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .85),
          border: Border.all(color: c.withValues(alpha: .8), width: 1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          'مدفوعة',
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: c,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// حافة سفلية مسنّنة كإيصال مطبوع.
class _ZigzagBottom extends CustomClipper<Path> {
  const _ZigzagBottom();

  @override
  Path getClip(Size size) {
    const tooth = 9.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    var x = size.width;
    var down = true;
    while (x > 0) {
      x -= tooth;
      path.lineTo(
        x.clamp(0, size.width),
        down ? size.height : size.height - tooth,
      );
      down = !down;
    }
    path
      ..lineTo(0, size.height - tooth)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_ZigzagBottom old) => false;
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
            : Border(
                bottom: BorderSide(
                  color: context.world.accent.withValues(alpha: .10),
                ),
              ),
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
