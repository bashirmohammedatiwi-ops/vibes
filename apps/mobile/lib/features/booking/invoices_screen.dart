import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/invoice_print.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
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
    'PAID' => SemanticColors.success,
    'REFUNDED' => SemanticColors.danger,
    'VOID' => Vibes.inkTertiary,
    _ => SemanticColors.warning,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(_invoicesProvider);
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'الفواتير',
              kicker: 'سجلات الدفع',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: invoices.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 96, radius: VibesRadius.lg),
                    SizedBox(height: 10),
                    ShimmerBox(height: 96, radius: VibesRadius.lg),
                    SizedBox(height: 10),
                    ShimmerBox(height: 96, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(_invoicesProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.receipt_long_outlined,
                      title: 'لا فواتير بعد',
                      subtitle: 'تصدر الفاتورة تلقائياً بعد تأكيد الدفع',
                    );
                  }
                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async => ref.invalidate(_invoicesProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final row = list[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: row.bookingId == null
                                ? null
                                : () => context.push(
                                    '/booking/${row.bookingId}/invoice',
                                  ),
                            customBorder: Folio.shape,
                            child: FolioPanel(
                              railColor: _statusColor(row.status),
                              shadows: Vibes.card,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  10,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    const MaisonIconWell(
                                      icon: Icons.receipt_long_outlined,
                                      size: 44,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.number,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          Text(
                                            row.propertyName ?? 'حجز',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      VibesTheme.textTertiaryOf(
                                                        context,
                                                      ),
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          StatusPill(
                                            label: _statusAr(row.status),
                                            color: _statusColor(row.status),
                                            compact: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        PriceText(row.total, compact: true),
                                        IconButton(
                                          tooltip: 'طباعة',
                                          onPressed: () => printInvoiceHtml(
                                            context,
                                            ref.read(apiClientProvider),
                                            path:
                                                '/api/invoices/${row.id}/print',
                                            fallbackText: [
                                              'فاتورة VIBEES ${row.number}',
                                              row.propertyName ?? 'حجز',
                                              '${PriceText.format(row.total)} د.ع',
                                            ].join('\n'),
                                            subject: 'فاتورة ${row.number}',
                                          ),
                                          icon: const Icon(
                                            Icons.print_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
