import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../chat/call_screen.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/atelier_widgets.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import 'provider_actions.dart';
import 'provider_data.dart';

/// ═══════════════════════════════════════════════════════════
/// نافذة المزوّد — الشاشات
/// ═══════════════════════════════════════════════════════════

// ── 1) الرئيسية ──

class ProviderHomeScreen extends ConsumerWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(providerOverviewProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: MaisonWash(
        child: overview.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
            children: const [
              ShimmerBox(height: 28, radius: 8),
              SizedBox(height: 18),
              ShimmerBox(height: 132, radius: VibesRadius.xl),
              SizedBox(height: 14),
              ShimmerBox(height: 88, radius: VibesRadius.lg),
              SizedBox(height: 10),
              ShimmerBox(height: 88, radius: VibesRadius.lg),
            ],
          ),
          error: (e, _) => ErrorCanvas(
            message: maisonError(e),
            onRetry: () => ref.invalidate(providerOverviewProvider),
          ),
          data: (o) => ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              MaisonPageHeader(
                title: user?.name?.trim().isNotEmpty == true
                    ? 'أهلاً ${user!.name}'
                    : 'بوابة المالك',
                kicker: 'بوابة المالك',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              FolioPanel(
                color: VibesDark.canvas,
                borderColor: Vibes.teal.withValues(alpha: .28),
                shadows: Vibes.floating,
                railColor: Vibes.teal,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [VibesDark.surface, VibesDark.canvas],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أرباح هذا الشهر',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Vibes.tealBright.withValues(alpha: .9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PriceText(o.monthRevenue, onDark: true),
                          const Spacer(),
                          Text(
                            '${o.monthBookings} حجزاً',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: VibesDark.inkSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: .04, end: 0),
              const SizedBox(height: 14),
              FolioPanel(
                shadows: Vibes.card,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      _LedgerFigure(
                        label: 'ممتلكات',
                        value: '${o.propertyCount}',
                      ),
                      _LedgerRule(),
                      _LedgerFigure(
                        label: 'نشطة',
                        value: '${o.activeBookings}',
                      ),
                      _LedgerRule(),
                      _LedgerFigure(
                        label: 'بانتظارك',
                        value: '${o.pendingBookings}',
                        accent: o.pendingBookings > 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${o.followersCount} متابع · ${o.pendingOffers} عرض معلّق',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: VibesTheme.textTertiaryOf(context),
                ),
              ),
              const SizedBox(height: 18),
              MaisonMenuGroup(
                children: [
                  MaisonMenuRow(
                    icon: Icons.trending_up_rounded,
                    label: 'الأرباح',
                    onTap: () => context.push('/provider/earnings'),
                  ),
                  MaisonMenuRow(
                    icon: Icons.forum_outlined,
                    label: 'الوارد',
                    trailing: _CountMark(
                      ref.watch(conversationsUnreadProvider).valueOrNull ?? 0,
                    ),
                    onTap: () => context.push('/conversations'),
                  ),
                  MaisonMenuRow(
                    icon: Icons.local_offer_outlined,
                    label: 'العروض',
                    trailing: _CountMark(() {
                      final offers = ref.watch(offersProvider).valueOrNull ?? [];
                      return offers.where((item) => item.status == 'PENDING').length;
                    }()),
                    onTap: () => context.push('/offers'),
                  ),
                  MaisonMenuRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'الفواتير',
                    onTap: () => context.push('/invoices'),
                  ),
                  MaisonMenuRow(
                    icon: Icons.assignment_outlined,
                    label: 'طلبات الإلغاء',
                    trailing: _CountMark(() {
                      final req = ref.watch(bookingRequestsProvider).valueOrNull;
                      if (req == null) return 0;
                      return [
                        ...req.cancellations,
                        ...req.refunds,
                      ].where((row) => row['status'] == 'PENDING').length;
                    }()),
                    onTap: () => context.push('/provider/requests'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _CoverageCard(coverage: o.coverage),
              const SizedBox(height: 26),
              if (o.upcoming.isNotEmpty) ...[
                const AtelierSection(
                  'الوصولات القادمة',
                  subtitle: 'استعد لضيوفك',
                ),
                for (final b in o.upcoming.take(5))
                  _UpcomingTile(
                    booking: b,
                  ).animate(delay: Duration(milliseconds: 300)).fadeIn(),
              ],
              const SizedBox(height: 28),
              VibesButton(
                label: 'تسجيل الخروج',
                ghost: true,
                onPressed: () => providerLogout(context, ref),
              ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.coverage});

  final ProviderCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final open = coverage.openDays;
    final hasGap = open > 0 && coverage.propertyCount > 0;
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: hasGap
          ? Vibes.teal.withValues(alpha: .45)
          : VibesTheme.hairlineOf(context),
      railColor: hasGap ? Vibes.teal : Vibes.coral,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasGap
                  ? '$open يوماً سيظهر متاحاً للضيوف'
                  : coverage.propertyCount == 0
                  ? 'أضف مكانك ثم سجّل الحجوزات الخارجية'
                  : 'تقويم الثلاثين يوماً مكتمل',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'كل حجز خارج المزرعة أو القاعة إذا لم يُسجَّل يبقى اليوم مفتوحاً على VIBEES. سجّله هنا ليختفي عن الضيوف.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CoverageStat(
                  label: 'تطبيق',
                  value: '${coverage.platformDays}',
                ),
                const SizedBox(width: 8),
                _CoverageStat(
                  label: 'خارجي',
                  value: '${coverage.externalDays}',
                ),
                const SizedBox(width: 8),
                _CoverageStat(label: 'مغلق', value: '${coverage.closedDays}'),
              ],
            ),
            const SizedBox(height: 12),
            VibesButton(
              label: 'سجّل حجزاً خارجياً',
              small: true,
              onPressed: () => context.go('/provider/calendar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageStat extends StatelessWidget {
  const _CoverageStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FolioPanel(
        color: VibesTheme.surfaceHighOf(context),
        borderColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: VibesTheme.textTertiaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerFigure extends StatelessWidget {
  const _LedgerFigure({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent ? Vibes.coral : VibesTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: VibesTheme.textTertiaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: VerticalDivider(width: 1, color: VibesTheme.hairlineOf(context)),
    );
  }
}

class _CountMark extends StatelessWidget {
  const _CountMark(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(
        Icons.chevron_left_rounded,
        color: VibesTheme.textTertiaryOf(context),
        size: 20,
      );
    }
    return FolioPanel(
      color: Vibes.coral,
      borderColor: Colors.transparent,
      radius: Folio.compact,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FolioPanel(
        color: VibesTheme.surfaceOf(context),
        shadows: Vibes.card,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              FolioPanel(
                color: VibesTheme.surfaceHighOf(context),
                borderColor: VibesTheme.hairlineOf(context),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Text(
                      '${booking.startDate.day}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: VibesTheme.brandOf(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.propertyName ?? 'مكان',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: VibesTheme.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      '${booking.userName ?? 'ضيف'} · ${booking.shiftLabelAr}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VibesTheme.textTertiaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: booking.statusLabelAr,
                color: switch (booking.status) {
                  BookingStatus.confirmed => SemanticColors.success,
                  BookingStatus.completed => SemanticColors.success,
                  BookingStatus.cancelled => SemanticColors.danger,
                  _ => SemanticColors.warning,
                },
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2) الحجوزات ──

class ProviderBookingsScreen extends ConsumerStatefulWidget {
  const ProviderBookingsScreen({super.key});

  @override
  ConsumerState<ProviderBookingsScreen> createState() =>
      _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState
    extends ConsumerState<ProviderBookingsScreen> {
  String? _status;
  String? _origin;

  ProviderBookingsQuery get _query =>
      ProviderBookingsQuery(status: _status, origin: _origin);

  static const _filters = [
    (null, 'الكل'),
    ('PENDING', 'بانتظار التأكيد'),
    ('CONFIRMED', 'مؤكدة'),
    ('CANCELLED', 'ملغاة'),
  ];

  static const _origins = [
    (null, 'كل المصادر'),
    ('PLATFORM', 'تطبيق VIBEES'),
    ('EXTERNAL', 'خارجي'),
  ];

  Future<void> _act(Booking booking, String status) async {
    try {
      final client = ref.read(apiClientProvider);
      if (booking.isExternal && status == 'CANCELLED') {
        await cancelExternalBooking(client, booking.id);
      } else {
        await updateBookingStatus(client, booking.id, status);
      }
      ref.invalidate(providerBookingsProvider(_query));
      ref.invalidate(providerOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'CONFIRMED' ? 'تم تأكيد الحجز' : 'تم إلغاء الحجز',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(maisonError(e))));
      }
    }
  }

  Future<void> _openChat(Booking booking) async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .post('/api/conversations/booking', body: {'bookingId': booking.id});
      final id = (data as Map<String, dynamic>)['id'] as String?;
      if (!mounted || id == null) return;
      context.push('/chat/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(providerBookingsProvider(_query));

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            const MaisonPageHeader(title: 'حجوزات ممتلكاتي', safe: true),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _filters.map((f) {
                  final active = _status == f.$1;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: MaisonChip(
                      label: f.$2,
                      active: active,
                      onTap: () => setState(() => _status = f.$1),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: _origins.map((f) {
                  final active = _origin == f.$1;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: MaisonChip(
                      label: f.$2,
                      active: active,
                      onTap: () => setState(() => _origin = f.$1),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: bookings.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: const [
                    ShimmerBox(height: 148, radius: VibesRadius.lg),
                    SizedBox(height: 12),
                    ShimmerBox(height: 148, radius: VibesRadius.lg),
                    SizedBox(height: 12),
                    ShimmerBox(height: 148, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () =>
                      ref.invalidate(providerBookingsProvider(_query)),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.calendar_month_outlined,
                      title: 'لا حجوزات',
                      subtitle:
                          'حجوزات التطبيق والخارجية تظهر هنا. سجّل الخارجي من التقويم ليُغلق اليوم عن الضيوف',
                    );
                  }

                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async =>
                        ref.invalidate(providerBookingsProvider(_query)),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: page.items.length,
                      itemBuilder: (context, i) => _ProviderBookingCard(
                        booking: page.items[i],
                        onConfirm: () => _act(page.items[i], 'CONFIRMED'),
                        onCancel: () => _act(page.items[i], 'CANCELLED'),
                        onChat: () => _openChat(page.items[i]),
                        onCall: () => startCall(
                          ref,
                          context,
                          bookingId: page.items[i].id,
                        ),
                      ).animate(delay: Duration(milliseconds: i * 35)).fadeIn(),
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

class _ProviderBookingCard extends StatelessWidget {
  const _ProviderBookingCard({
    required this.booking,
    required this.onConfirm,
    required this.onCancel,
    required this.onChat,
    required this.onCall,
  });

  final Booking booking;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onChat;
  final VoidCallback onCall;

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    final uri = Uri.parse(
      'https://wa.me/${phone.replaceFirst(RegExp(r'^\+'), '')}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FolioPanel(
        color: VibesTheme.surfaceOf(context),
        shadows: Vibes.card,
        railColor: booking.isExternal ? Vibes.teal : Vibes.coral,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FolioPanel(
                    color: VibesTheme.surfaceHighOf(context),
                    borderColor: VibesTheme.hairlineOf(context),
                    radius: Folio.compact,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Text(
                          '${booking.startDate.day}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.propertyName ?? 'مكان',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${booking.userName ?? 'زائر'} · ${booking.shiftLabelAr}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: VibesTheme.textTertiaryOf(context),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${PriceText.format(booking.totalPrice)} د.ع',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Vibes.coral,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (booking.isExternal) ...[
                        const StatusPill(
                          label: 'خارجي',
                          color: Vibes.teal,
                          compact: true,
                        ),
                        const SizedBox(height: 6),
                      ],
                      StatusPill(
                        label: booking.statusLabelAr,
                        color: switch (booking.status) {
                          BookingStatus.confirmed => SemanticColors.success,
                          BookingStatus.completed => SemanticColors.success,
                          BookingStatus.cancelled => SemanticColors.danger,
                          _ => SemanticColors.warning,
                        },
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (booking.userPhone != null) ...[
                    _QuietAction(
                      icon: Icons.call_outlined,
                      label: 'اتصال',
                      onTap: () => _call(booking.userPhone!),
                    ),
                    const SizedBox(width: 14),
                    _QuietAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'واتساب',
                      onTap: () => _whatsapp(booking.userPhone!),
                    ),
                    const SizedBox(width: 14),
                  ],
                  if (!booking.isExternal)
                    _QuietAction(
                      icon: Icons.forum_outlined,
                      label: 'رسالة',
                      onTap: onChat,
                    ),
                    const SizedBox(width: 14),
                    _QuietAction(
                      icon: Icons.call_outlined,
                      label: 'اتصل داخل التطبيق',
                      onTap: onCall,
                    ),
                  const Spacer(),
                  // الإجراءات
                  if (booking.status == BookingStatus.pending &&
                      !booking.isExternal) ...[
                    SizedBox(
                      height: 44,
                      child: VibesButton(
                        label: 'تأكيد',
                        small: true,
                        expanded: false,
                        onPressed: onConfirm,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: VibesButton(
                        label: 'إلغاء',
                        small: true,
                        ghost: true,
                        expanded: false,
                        onPressed: onCancel,
                      ),
                    ),
                  ],
                  if (booking.isExternal &&
                      booking.status != BookingStatus.cancelled) ...[
                    SizedBox(
                      height: 44,
                      child: VibesButton(
                        label: 'إلغاء الخارجي',
                        small: true,
                        ghost: true,
                        expanded: false,
                        onPressed: onCancel,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Vibes.coral),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Vibes.coral,
            ),
          ),
        ],
      ),
    );
  }
}
