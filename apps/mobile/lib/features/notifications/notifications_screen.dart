import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';

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

  Color _typeColor(String type) => switch (type) {
    'PAYMENT' || 'REFUND' => Vibes.success,
    'MESSAGE' => Vibes.coral,
    'OFFER' => const Color(0xFFD97706),
    'INVOICE' => Vibes.info,
    'SOCIAL' => Vibes.mapple,
    _ => const Color(0xFF6B7280),
  };

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
              trailing: PressScale(
                onTap: () async {
                  await ref
                      .read(apiClientProvider)
                      .patch('/api/notifications/read');
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(notificationsUnreadProvider);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.world.accentFaint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: context.world.accentDeep,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'قراءة الكل',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: context.world.accentDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: notes.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    WorldSkeleton(height: 82, radius: 20),
                    SizedBox(height: 10),
                    WorldSkeleton(height: 82, radius: 20),
                    SizedBox(height: 10),
                    WorldSkeleton(height: 82, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: WorldEmpty(
                        icon: Icons.notifications_none_rounded,
                        title: 'لا إشعارات بعد',
                        subtitle:
                            'ستصلك هنا تحديثات حجوزاتك ورسائلك والعروض الجديدة',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: context.world.accent,
                    onRefresh: () async =>
                        ref.invalidate(notificationsProvider),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final n = list[i];
                        // فاصل يوم عند بداية كل يوم جديد
                        final prev = i > 0 ? list[i - 1] : null;
                        final newDay =
                            prev == null ||
                            prev.createdAt?.year != n.createdAt?.year ||
                            prev.createdAt?.month != n.createdAt?.month ||
                            prev.createdAt?.day != n.createdAt?.day;
                        final card = SurfaceListCard(
                          accent: n.isRead ? null : context.world.accent,
                          highlighted: !n.isRead,
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
                          child: Row(
                            children: [
                              MaisonIconWell(
                                icon: _icon(n.type),
                                color: n.isRead
                                    ? VibesTheme.textTertiaryOf(context)
                                    : _typeColor(n.type),
                                background: n.isRead
                                    ? const Color(0xFFF4F5F7)
                                    : _typeColor(n.type).withValues(alpha: .10),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              color: VibesTheme.textTertiaryOf(
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
                                            color: VibesTheme.textTertiaryOf(
                                              context,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: context.world.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                        if (!newDay)
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: card,
                          );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (i > 0) const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      gradient: context.world.fill,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dayLabel(n.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: VibesTheme.textSecondaryOf(
                                            context,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            card,
                          ],
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

  String _dayLabel(DateTime? at) {
    final now = DateTime.now();
    if (at == null) return '';
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return 'اليوم';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (at.year == yesterday.year &&
        at.month == yesterday.month &&
        at.day == yesterday.day) {
      return 'أمس';
    }
    return '${at.day}/${at.month}${at.year != now.year ? '/${at.year}' : ''}';
  }
}
