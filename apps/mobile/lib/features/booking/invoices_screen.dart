import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/invoice_print.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
import '../../shared/widgets/vibes_widgets.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  String _statusAr(String status) => switch (status) {
    'PAID' => 'مدفوعة',
    'ISSUED' => 'صادرة',
    'REFUNDED' => 'مستردة',
    'VOID' => 'ملغاة',
    _ => status,
  };

  Color _statusColor(String status) => switch (status) {
    'PAID' => const Color(0xFF0E9F6E),
    'REFUNDED' => const Color(0xFFDC2626),
    'VOID' => Vibes.inkTertiary,
    _ => const Color(0xFFD97706),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(_invoicesProvider);
    final p = context.world;
    final paidTotal = (invoices.valueOrNull ?? const <_InvoiceRow>[])
        .where((r) => r.status == 'PAID')
        .fold<num>(0, (a, r) => a + r.total);
    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(
        children: [
          WorldPageHeader(
            title: 'الفواتير',
            subtitle: invoices.hasValue && invoices.value!.isNotEmpty
                ? '${invoices.value!.length} فاتورة · مدفوع ${formatIqdShort(paidTotal)} د.ع'
                : 'سجلات الدفع لحجوزاتك',
            showBack: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: invoices.when(
              loading: () => ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: const [
                  WorldSkeleton(height: 92, radius: 22),
                  SizedBox(height: 12),
                  WorldSkeleton(height: 92, radius: 22),
                  SizedBox(height: 12),
                  WorldSkeleton(height: 92, radius: 22),
                ],
              ),
              error: (e, _) => ErrorCanvas(
                message: maisonError(e),
                onRetry: () => ref.invalidate(_invoicesProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: WorldEmpty(
                      icon: Icons.receipt_long_rounded,
                      title: 'لا فواتير بعد',
                      subtitle: 'تصدر الفاتورة تلقائياً بعد تأكيد دفع حجزك',
                    ),
                  );
                }
                return RefreshIndicator(
                  color: p.accent,
                  onRefresh: () async => ref.invalidate(_invoicesProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final row = list[i];
                      final color = _statusColor(row.status);
                      return PressScale(
                        onTap: row.bookingId == null
                            ? null
                            : () => context.push(
                                '/booking/${row.bookingId}/invoice',
                              ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: p.accent.withValues(alpha: .10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .04),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: p.accentFaint,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: p.accentDeep,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.propertyName ?? 'حجز',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: Vibes.ink,
                                      ),
                                    ),
                                    Text(
                                      row.number,
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Vibes.inkTertiary,
                                        letterSpacing: .8,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    WorldStatusChip(
                                      label: _statusAr(row.status),
                                      color: color,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatIqdShort(row.total),
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Vibes.ink,
                                    ),
                                  ),
                                  Text(
                                    'د.ع',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: p.accentDeep,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  PressScale(
                                    onTap: () => printInvoiceHtml(
                                      context,
                                      ref.read(apiClientProvider),
                                      path: '/api/invoices/${row.id}/print',
                                      fallbackText: [
                                        'فاتورة VIBES ${row.number}',
                                        row.propertyName ?? 'حجز',
                                        '${PriceText.format(row.total)} د.ع',
                                      ].join('\n'),
                                      subject: 'فاتورة ${row.number}',
                                    ),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F5F7),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: const Icon(
                                        Icons.print_outlined,
                                        size: 18,
                                        color: Vibes.inkSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow {
  const _InvoiceRow({
    required this.id,
    required this.number,
    required this.total,
    this.bookingId,
    this.propertyName,
    this.status = 'ISSUED',
  });

  final String id;
  final String number;
  final num total;
  final String? bookingId;
  final String? propertyName;
  final String status;
}

final _invoicesProvider = FutureProvider<List<_InvoiceRow>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/invoices');
  return (data as List<dynamic>).whereType<Map<String, dynamic>>().map((j) {
    final booking = j['booking'];
    return _InvoiceRow(
      id: '${j['id'] ?? ''}',
      number: '${j['number'] ?? ''}',
      total: j['total'] is num
          ? j['total'] as num
          : num.tryParse('${j['total']}') ?? 0,
      bookingId: booking is Map<String, dynamic>
          ? booking['id'] as String?
          : j['bookingId'] as String?,
      propertyName:
          booking is Map<String, dynamic> &&
              booking['property'] is Map<String, dynamic>
          ? (booking['property'] as Map<String, dynamic>)['name'] as String?
          : null,
      status: '${j['status'] ?? 'ISSUED'}',
    );
  }).toList();
});
