import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              title: 'العروض الخاصة',
              kicker: 'مختارات الموسم',
              onBack: () => context.pop(),
              trailing: isProvider
                  ? IconButton(
                      tooltip: 'عرض جديد',
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
                      title: isProvider ? 'لا عروض مرسلة' : 'لا عروض حالياً',
                      subtitle: isProvider
                          ? 'أرسل سعراً خاصاً لعميل وتاريخ محدد'
                          : 'عندما يرسل المالك سعراً خاصاً سيظهر هنا',
                      action: isProvider
                          ? VibesButton(
                              label: 'إنشاء عرض',
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
                                    o.propertyName ?? 'عرض سعر',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                StatusPill(
                                  label: pending
                                      ? 'بانتظار الرد'
                                      : o.status == 'ACCEPTED'
                                      ? 'مقبول'
                                      : 'منتهٍ',
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
                                '${o.startDate!.day}/${o.startDate!.month} → ${o.endDate!.subtract(const Duration(days: 1)).day}/${o.endDate!.subtract(const Duration(days: 1)).month}',
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
                                      label: 'قبول العرض',
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
                                            context.push('/booking/$bookingId');
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تم قبول العرض وإنشاء الحجز',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(maisonError(e))),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  VibesButton(
                                    label: 'رفض',
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
                                label: 'فتح الحجز',
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
                                  pending ? 'بانتظار رد العميل' : o.status,
                                  style: Theme.of(context).textTheme.labelSmall,
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
      const SnackBar(content: Text('أضف مكاناً أولاً ثم أرسل عرضاً')),
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
                    'عرض سعر خاص',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'المكان',
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
                    label: 'هاتف العميل',
                    controller: phone,
                    hint: '07XX XXX XXXX',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  MaisonField(
                    label: 'المبلغ د.ع',
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
                          child: Text('من ${_fmt(start)}'),
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
                          child: Text('إلى ${_fmt(end)}'),
                        ),
                      ),
                    ],
                  ),
                  MaisonField(
                    label: 'رسالة اختيارية',
                    controller: message,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  VibesButton(
                    label: 'إرسال العرض',
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
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text(maisonError(e))));
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
      ).showSnackBar(const SnackBar(content: Text('تم إرسال العرض')));
    }
  }
}

String _fmt(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
