import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';

class ProviderRequestsScreen extends ConsumerWidget {
  const ProviderRequestsScreen({super.key});

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required bool approve,
  }) async {
    String? note;
    if (!approve) {
      note = await showMaisonPrompt(
        context: context,
        title: 'رفض الطلب',
        message: 'اكتب للضيف سبب الرفض',
        hint: 'سبب الرفض',
        confirmLabel: 'رفض',
      );
      if (note == null) return;
      if (note.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('أضف سبب الرفض')));
        }
        return;
      }
    } else {
      final ok = await showMaisonConfirm(
        context: context,
        title: 'الموافقة على الإلغاء',
        message:
            'سيُلغى الحجز فوراً. إن وُجد دفع مؤكد يبقى الاسترداد المالي لمراجعة فريق VIBEES.',
        confirmLabel: 'موافقة',
        cancelLabel: 'تراجع',
      );
      if (!ok) return;
    }

    try {
      await ref
          .read(apiClientProvider)
          .patch(
            '/api/cancellations/$id',
            body: {
              'approve': approve,
              if (note != null && note.isNotEmpty) 'note': note,
            },
          );
      ref.invalidate(bookingRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'أُلغي الحجز — الاسترداد إن وُجد يراجعه الفريق'
                : 'رُفض طلب الإلغاء',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(bookingRequestsProvider);
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'طلبات الإلغاء',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: requests.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 110, radius: VibesRadius.lg),
                    SizedBox(height: 10),
                    ShimmerBox(height: 110, radius: VibesRadius.lg),
                    SizedBox(height: 10),
                    ShimmerBox(height: 110, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(bookingRequestsProvider),
                ),
                data: (value) {
                  final items = [
                    ...value.cancellations.map(
                      (row) => (kind: 'إلغاء', row: row),
                    ),
                    ...value.refunds.map((row) => (kind: 'استرداد', row: row)),
                  ];
                  if (items.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.assignment_outlined,
                      title: 'لا طلبات معلّقة',
                      subtitle:
                          'ستظهر هنا طلبات إلغاء واسترداد حجوزات ممتلكاتك',
                    );
                  }
                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async =>
                        ref.invalidate(bookingRequestsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final booking = item.row['booking'];
                        final user = item.row['user'];
                        final place = booking is Map
                            ? '${booking['property'] is Map ? booking['property']['name'] : 'مكان'}'
                            : 'مكان';
                        final guest = user is Map
                            ? (user['name'] ?? user['phone'] ?? 'ضيف')
                            : 'ضيف';
                        final status = '${item.row['status'] ?? ''}';
                        final bookingId = booking is Map
                            ? booking['id'] as String?
                            : null;
                        final requestId = item.row['id'] as String?;
                        final isCancel = item.kind == 'إلغاء';
                        final pending = status == 'PENDING';
                        return VibesCard(
                          onTap: bookingId == null
                              ? null
                              : () => context.push('/booking/$bookingId'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$place · ${item.kind}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        Text(
                                          '$guest',
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
                                        if (item.row['reason'] != null &&
                                            '${item.row['reason']}'.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              '${item.row['reason']}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: _statusAr(status),
                                    color: status == 'PENDING'
                                        ? SemanticColors.warning
                                        : status == 'APPROVED'
                                        ? SemanticColors.success
                                        : SemanticColors.danger,
                                    compact: true,
                                  ),
                                ],
                              ),
                              if (isCancel && pending && requestId != null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _review(
                                        context,
                                        ref,
                                        requestId,
                                        approve: true,
                                      ),
                                      child: const Text('موافقة'),
                                    ),
                                    TextButton(
                                      onPressed: () => _review(
                                        context,
                                        ref,
                                        requestId,
                                        approve: false,
                                      ),
                                      child: const Text('رفض'),
                                    ),
                                  ],
                                ),
                              ] else if (!isCancel && pending) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'الاسترداد المالي يراجعه فريق VIBEES',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ],
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

  String _statusAr(String status) => switch (status) {
    'PENDING' => 'معلّق',
    'APPROVED' => 'مقبول',
    'REJECTED' => 'مرفوض',
    _ => status,
  };
}
