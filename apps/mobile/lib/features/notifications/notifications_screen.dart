import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _relative(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    return 'قبل ${diff.inDays} يوم';
  }

  IconData _icon(String type) => switch (type) {
    'PAYMENT' => Icons.payments_outlined,
    'MESSAGE' => Icons.chat_bubble_outline_rounded,
    'OFFER' => Icons.local_offer_outlined,
    'INVOICE' => Icons.receipt_long_outlined,
    'REFUND' => Icons.replay_rounded,
    'SOCIAL' => Icons.auto_awesome_outlined,
    _ => Icons.notifications_none_rounded,
  };

  void _open(BuildContext context, AppNotification item) {
    final raw = item.linkUrl;
    if (raw == null || raw.isEmpty) return;
    final link = _normalizeLink(raw);
    if (link.isEmpty) return;
    context.push(link);
  }

  String _normalizeLink(String link) {
    if (link.startsWith('/bookings/')) {
      return link.replaceFirst('/bookings/', '/booking/');
    }
    if (link.startsWith('/provider/') &&
        !link.startsWith('/provider/bookings') &&
        !link.startsWith('/provider/calendar') &&
        !link.startsWith('/provider/properties') &&
        !link.startsWith('/provider/earnings') &&
        !link.startsWith('/provider/requests') &&
        link != '/provider') {
      return link.replaceFirst('/provider/', '/providers/');
    }
    if (RegExp(r'^/offers/').hasMatch(link)) return '/offers';
    if (RegExp(r'^/experiences/').hasMatch(link)) return '/experiences';
    if (link.startsWith('/coupons')) return '/coupons';
    if (link.startsWith('/following')) return '/following';
    if (link.startsWith('/booking') ||
        link.startsWith('/chat') ||
        link.startsWith('/offers') ||
        link.startsWith('/property') ||
        link.startsWith('/experiences') ||
        link.startsWith('/invoices') ||
        link.startsWith('/providers') ||
        link.startsWith('/provider') ||
        link.startsWith('/collections') ||
        link.startsWith('/explore')) {
      return link;
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notificationsProvider);

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'الإشعارات',
              kicker: 'آخر المستجدات',
              onBack: () => context.pop(),
              trailing: TextButton(
                onPressed: () async {
                  await ref
                      .read(apiClientProvider)
                      .patch('/api/notifications/read');
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(notificationsUnreadProvider);
                },
                child: const Text('قراءة الكل'),
              ),
            ),
            Expanded(
              child: notes.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 82, radius: VibesRadius.md),
                    SizedBox(height: 10),
                    ShimmerBox(height: 82, radius: VibesRadius.md),
                    SizedBox(height: 10),
                    ShimmerBox(height: 82, radius: VibesRadius.md),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.notifications_none_rounded,
                      title: 'لا إشعارات',
                      subtitle: 'ستصلك هنا تحديثات الحجوزات والرسائل والعروض',
                    );
                  }
                  return RefreshIndicator(
                    color: Vibes.teal,
                    onRefresh: () async =>
                        ref.invalidate(notificationsProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = list[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              if (!n.isRead) {
                                await ref
                                    .read(apiClientProvider)
                                    .patch('/api/notifications/${n.id}/read');
                                ref.invalidate(notificationsProvider);
                                ref.invalidate(notificationsUnreadProvider);
                              }
                              if (context.mounted) _open(context, n);
                            },
                            customBorder: Folio.shape,
                            child: FolioPanel(
                              railColor: n.isRead ? null : Vibes.teal,
                              shadows: Vibes.card,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Row(
                                  children: [
                                    MaisonIconWell(
                                      icon: _icon(n.type),
                                      color: n.isRead
                                          ? Vibes.inkSecondary
                                          : Vibes.coral,
                                      background: Vibes.surface,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: n.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w900,
                                                ),
                                          ),
                                          if (n.body.isNotEmpty)
                                            Text(
                                              n.body,
                                              maxLines: 2,
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
                                          Text(
                                            _relative(n.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color:
                                                      VibesTheme.textTertiaryOf(
                                                        context,
                                                      ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!n.isRead)
                                      const ColoredBox(
                                        color: Vibes.teal,
                                        child: SizedBox(width: 7, height: 7),
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
