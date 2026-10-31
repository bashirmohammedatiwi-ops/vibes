import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import '../booking/booking_providers.dart';
import '../provider/provider_data.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key, this.highlightId});

  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    final isProvider = ref.watch(authControllerProvider).isProvider;
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'العروض الخاصة'.tr,
              kicker: 'مختارات الموسم'.tr,
              onBack: () => context.pop(),
              trailing: isProvider
                  ? IconButton(
                      tooltip: 'عرض جديد'.tr,
                      onPressed: () => _createOffer(context, ref),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : null,
            ),
            Expanded(
              child: offers.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 176, radius: VibesRadius.md),
                    SizedBox(height: 10),
                    ShimmerBox(height: 176, radius: VibesRadius.md),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(offersProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyCanvas(
                      icon: Icons.local_offer_outlined,
                      title: isProvider
                          ? 'لا عروض مرسلة'.tr
                          : 'لا عروض حالياً'.tr,
                      subtitle: isProvider
                          ? 'أرسل سعراً خاصاً لعميل وتاريخ محدد'.tr
                          : 'عندما يرسل المالك سعراً خاصاً سيظهر هنا'.tr,
                      action: isProvider
                          ? VibesButton(
                              label: 'إنشاء عرض'.tr,
                              small: true,
                              expanded: false,
                              onPressed: () => _createOffer(context, ref),
                            )
                          : null,
                    );
                  }
                  final rows = [...list];
                  final hid = highlightId;
                  if (hid != null && hid.isNotEmpty) {
                    rows.sort((a, b) {
                      if (a.id == hid) return -1;
                      if (b.id == hid) return 1;
                      return 0;
                    });
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final o = rows[i];
                      final pending = o.status == 'PENDING';
                      final statusColor = pending
                          ? Vibes.teal
                          : o.status == 'ACCEPTED'
                          ? SemanticColors.success
                          : Vibes.inkTertiary;
                      return FolioPanel(
                        railColor: statusColor,
                        borderColor: highlightId == o.id
                            ? Vibes.teal.withValues(alpha: .55)
                            : null,
                        shadows: Vibes.card,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      o.propertyName ?? 'عرض سعر'.tr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  StatusPill(
                                    label: pending
                                        ? 'بانتظار الرد'.tr
                                        : o.status == 'ACCEPTED'
                                        ? 'مقبول'.tr
                                        : 'منتهٍ'.tr,
                                    color: statusColor,
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              PriceText(o.amount, compact: true),
                              if (o.startDate != null && o.endDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_short(o.startDate!)} → ${_short(o.endDate!.subtract(const Duration(days: 1)))}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                              if (o.message.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(o.message),
                              ],
                              if (!isProvider && pending) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: VibesButton(
                                        label: 'قبول العرض'.tr,
                                        onPressed: () async {
                                          try {
                                            final data = await ref
                                                .read(apiClientProvider)
                                                .post(
                                                  '/api/offers/${o.id}/respond',
                                                  body: {'accept': true},
                                                );
                                            ref.invalidate(offersProvider);
                                            ref.invalidate(myBookingsProvider);
                                            final booking = data is Map
                                                ? data['booking']
                                                : null;
                                            final bookingId = booking is Map
                                                ? booking['id'] as String?
                                                : null;
                                            if (!context.mounted) return;
                                            if (bookingId != null) {
                                              context.push(
                                                '/booking/$bookingId',
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'تم قبول العرض وإنشاء الحجز' // i18n-ok
                                                        .tr,
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(maisonError(e)),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    VibesButton(
                                      label: 'رفض'.tr,
                                      small: true,
                                      ghost: true,
                                      expanded: false,
                                      onPressed: () async {
                                        await ref
                                            .read(apiClientProvider)
                                            .post(
                                              '/api/offers/${o.id}/respond',
                                              body: {'accept': false},
                                            );
                                        ref.invalidate(offersProvider);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              if (o.bookingId != null) ...[
                                const SizedBox(height: 8),
                                VibesButton(
                                  label: 'فتح الحجز'.tr,
                                  small: true,
                                  ghost: true,
                                  expanded: false,
                                  onPressed: () =>
                                      context.push('/booking/${o.bookingId}'),
                                ),
                              ],
                              if (isProvider)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    pending ? 'بانتظار رد العميل'.tr : o.status,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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

Future<void> _createOffer(BuildContext context, WidgetRef ref) async {
  final properties =
      ref.read(providerPropertiesProvider).valueOrNull ?? const [];
  if (properties.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('أضف مكاناً أولاً ثم أرسل عرضاً'.tr)),
    );
    return;
  }

  final phone = TextEditingController();
  final amount = TextEditingController();
  final message = TextEditingController();
  String propertyId = properties.first.id;
  DateTime start = DateTime.now().add(const Duration(days: 7));
  DateTime end = start.add(const Duration(days: 1));

  final created = await showModalBottomSheet<bool>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MaisonSheetHandle(),
                  Text(
                    'عرض سعر خاص'.tr,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'المكان'.tr,
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: Vibes.inkSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in properties)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: MaisonChip(
                              label: p.name,
                              active: propertyId == p.id,
                              onTap: () => setLocal(() => propertyId = p.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  MaisonField(
                    label: 'هاتف العميل'.tr,
                    controller: phone,
                    hint: '07XX XXX XXXX',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  MaisonField(
                    label: 'المبلغ د.ع'.tr,
                    controller: amount,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: start,
                            );
                            if (picked != null) setLocal(() => start = picked);
                          },
                          child: Text(
                            'من {date}'.trArgs({'date': _fmt(start)}),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              firstDate: start,
                              lastDate: DateTime.now().add(
                                const Duration(days: 400),
                              ),
                              initialDate: end,
                            );
                            if (picked != null) setLocal(() => end = picked);
                          },
                          child: Text('إلى {date}'.trArgs({'date': _fmt(end)})),
                        ),
                      ),
                    ],
                  ),
                  MaisonField(
                    label: 'رسالة اختيارية'.tr,
                    controller: message,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  VibesButton(
                    label: 'إرسال العرض'.tr,
                    onPressed: () async {
                      var normalized = phone.text.trim().replaceAll(' ', '');
                      if (normalized.startsWith('07') &&
                          normalized.length == 11) {
                        normalized = '964${normalized.substring(1)}';
                      }
                      try {
                        await ref
                            .read(apiClientProvider)
                            .post(
                              '/api/offers',
                              body: {
                                'propertyId': propertyId,
                                'customerPhone': normalized,
                                'startDate': start.toUtc().toIso8601String(),
                                'endDate': end.toUtc().toIso8601String(),
                                'amount': num.parse(amount.text.trim()),
                                'message': message.text.trim(),
                              },
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(maisonError(e))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  phone.dispose();
  amount.dispose();
  message.dispose();
  if (created == true) {
    ref.invalidate(offersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم إرسال العرض'.tr)));
    }
  }
}

String _fmt(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

const _enMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// تاريخ قصير: «4/11» بالعربية و«Nov 4» بالإنجليزية.
String _short(DateTime d) =>
    I18n.isEn ? '${_enMonths[d.month - 1]} ${d.day}' : '${d.day}/${d.month}';
