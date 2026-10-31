import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/world_ui.dart';
import '../../core/theme/world_theme.dart';
import 'provider_ui.dart';

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
        title: 'رفض الطلب'.tr,
        message: 'اكتب للضيف سبب الرفض'.tr,
        hint: 'سبب الرفض'.tr,
        confirmLabel: 'رفض'.tr,
      );
      if (note == null) return;
      if (note.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('أضف سبب الرفض'.tr)));
        }
        return;
      }
    } else {
      final ok = await showMaisonConfirm(
        context: context,
        title: 'الموافقة على الإلغاء'.tr,
        message:
            'سيُلغى الحجز فوراً. إن وُجد دفع مؤكد يبقى الاسترداد المالي لمراجعة فريق أجواء.'.tr,
        confirmLabel: 'موافقة'.tr,
        cancelLabel: 'تراجع'.tr,
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
                ? 'أُلغي الحجز — الاسترداد إن وُجد يراجعه الفريق'.tr
                : 'رُفض طلب الإلغاء'.tr,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(bookingRequestsProvider);
    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'طلبات الإلغاء'.tr,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: requests.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    WorldSkeleton(height: 110, radius: 20),
                    SizedBox(height: 10),
                    WorldSkeleton(height: 110, radius: 20),
                    SizedBox(height: 10),
                    WorldSkeleton(height: 110, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(bookingRequestsProvider),
                ),
                data: (value) {
                  final items = [
                    ...value.cancellations.map(
                      (row) => (kind: 'إلغاء', row: row), // i18n-ok
                    ),
                    ...value.refunds.map(
                      (row) => (kind: 'استرداد', row: row), // i18n-ok
                    ),
                  ];
                  if (items.isEmpty) {
                    return WorldEmpty(
                      icon: Icons.assignment_outlined,
                      title: 'لا طلبات معلّقة'.tr,
                      subtitle:
                          'ستظهر هنا طلبات إلغاء واسترداد حجوزات ممتلكاتك'.tr,
                    );
                  }
                  return RefreshIndicator(
                    color: ownerNavy,
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
                            ? '${booking['property'] is Map ? booking['property']['name'] : 'مكان'.tr}' // i18n-ok
                            : 'مكان'.tr;
                        final guest = user is Map
                            ? (user['name'] ?? user['phone'] ?? 'ضيف'.tr)
                            : 'ضيف'.tr;
                        final status = '${item.row['status'] ?? ''}';
                        final bookingId = booking is Map
                            ? booking['id'] as String?
                            : null;
                        final requestId = item.row['id'] as String?;
                        final isCancel = item.kind == 'إلغاء'; // i18n-ok
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
                                          isCancel
                                              ? '{place} · إلغاء'.trArgs({
                                                  'place': place,
                                                })
                                              : '{place} · استرداد'.trArgs({
                                                  'place': place,
                                                }),
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
                                      child: Text('موافقة'.tr),
                                    ),
                                    TextButton(
                                      onPressed: () => _review(
                                        context,
                                        ref,
                                        requestId,
                                        approve: false,
                                      ),
                                      child: Text('رفض'.tr),
                                    ),
                                  ],
                                ),
                              ] else if (!isCancel && pending) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'الاسترداد المالي يراجعه فريق أجواء'.tr,
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
    'PENDING' => 'معلّق'.tr,
    'APPROVED' => 'مقبول'.tr,
    'REJECTED' => 'مرفوض'.tr,
    _ => status,
  };
}
