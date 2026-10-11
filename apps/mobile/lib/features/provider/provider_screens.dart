import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
import '../chat/call_screen.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import 'provider_actions.dart';
import 'provider_data.dart';
import 'provider_scope.dart';
import 'provider_ui.dart';
import '../property/shift_calendar_ui.dart';

/// ═══════════════════════════════════════════════════════════
/// نافذة المزوّد — الشاشات
/// ═══════════════════════════════════════════════════════════

// ── 1) الرئيسية ──

const _p = WorldPalette.owner;
const _hInk = Color(0xFF0F1B2D);
const _hInk2 = Color(0xFF5B6576);
const _hLine = Color(0xFFEDEEF1);

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'صباح الخير';
  if (h < 18) return 'نهارك سعيد';
  return 'مساء الخير';
}

class ProviderHomeScreen extends ConsumerWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(providerOverviewProvider);
    final user = ref.watch(authControllerProvider).user;
    final revenue = ref.watch(providerRevenueProvider(6)).valueOrNull;
    final series = revenue == null
        ? const <num>[]
        : ([...revenue]..sort((a, b) => a.month.compareTo(b.month)))
              .map((r) => r.revenue)
              .toList();
    final unread = ref.watch(conversationsUnreadProvider).valueOrNull;

    return Scaffold(
      backgroundColor: _p.canvas,
      body: overview.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 20,
            20,
            32,
          ),
          children: const [
            WorldSkeleton(height: 44, radius: 14),
            SizedBox(height: 18),
            WorldSkeleton(height: 210, radius: 26),
            SizedBox(height: 14),
            WorldSkeleton(height: 96, radius: 20),
            SizedBox(height: 10),
            WorldSkeleton(height: 96, radius: 20),
          ],
        ),
        error: (e, _) => ErrorCanvas(
          message: maisonError(e),
          onRetry: () => ref.invalidate(providerOverviewProvider),
        ),
        data: (o) {
          final now = DateTime.now();
          final todayArrivals = o.upcoming
              .where((b) => ownerIsSameDay(b.startDate, now))
              .toList();
          final laterArrivals = o.upcoming
              .where((b) => !ownerIsSameDay(b.startDate, now))
              .toList();
          final offers = ref.watch(offersProvider).valueOrNull ?? const [];
          final pendingOffers = offers
              .where((item) => item.status == 'PENDING')
              .length;
          final req = ref.watch(bookingRequestsProvider).valueOrNull;
          final pendingRequests = req == null
              ? 0
              : [
                  ...req.cancellations,
                  ...req.refunds,
                ].where((row) => row['status'] == 'PENDING').length;

          void openPending() {
            ref.read(providerBookingsStatusFilterProvider.notifier).state =
                'PENDING';
            context.go('/provider/bookings');
          }

          return RefreshIndicator(
            color: _p.accentDeep,
            onRefresh: () async {
              ref.invalidate(providerOverviewProvider);
              ref.invalidate(providerRevenueProvider(6));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.paddingOf(context).top + 12,
                18,
                28,
              ),
              children: [
                _OwnerTopBar(name: user?.name?.trim(), unread: unread ?? 0),
                const SizedBox(height: 18),
                OwnerRevenueHero(
                      revenue: o.monthRevenue,
                      bookingsCount: o.monthBookings,
                      series: series,
                      onTap: () => context.push('/provider/earnings'),
                    )
                    .animate()
                    .fadeIn(duration: 380.ms)
                    .slideY(begin: .04, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                // ── مركز المهام ──
                if (o.pendingBookings > 0 ||
                    pendingRequests > 0 ||
                    pendingOffers > 0) ...[
                  _ActionCenter(
                    pendingBookings: o.pendingBookings,
                    pendingRequests: pendingRequests,
                    pendingOffers: pendingOffers,
                    onBookings: openPending,
                    onRequests: () => context.push('/provider/requests'),
                    onOffers: () => context.push('/offers'),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    OwnerQuickAction(
                      icon: Icons.calendar_month_rounded,
                      label: 'التقويم',
                      onTap: () => context.go('/provider/calendar'),
                    ),
                    const SizedBox(width: 6),
                    OwnerQuickAction(
                      icon: Icons.edit_calendar_rounded,
                      label: 'حجز خارجي',
                      onTap: () {
                        ref
                                .read(
                                  providerCalendarOpenExternalProvider.notifier,
                                )
                                .state =
                            true;
                        context.go('/provider/calendar');
                      },
                    ),
                    const SizedBox(width: 6),
                    OwnerQuickAction(
                      icon: Icons.sell_rounded,
                      label: 'الأسعار',
                      onTap: () => context.go('/provider/properties'),
                    ),
                    const SizedBox(width: 6),
                    OwnerQuickAction(
                      icon: Icons.forum_rounded,
                      label: 'الرسائل',
                      badge: unread,
                      onTap: () => context.push('/conversations'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OwnerMetricTile(
                        icon: Icons.hourglass_top_rounded,
                        label: 'بانتظار ردّك',
                        value: '${o.pendingBookings}',
                        highlight: o.pendingBookings > 0,
                        onTap: openPending,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OwnerMetricTile(
                        icon: Icons.event_available_rounded,
                        label: 'حجوزات نشطة',
                        value: '${o.activeBookings}',
                        onTap: () => context.go('/provider/bookings'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OwnerMetricTile(
                        icon: Icons.villa_rounded,
                        label: 'أماكنك',
                        value: '${o.propertyCount}',
                        onTap: () => context.go('/provider/properties'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OwnerMetricTile(
                        icon: Icons.favorite_rounded,
                        label: 'متابعون',
                        value: '${o.followersCount}',
                      ),
                    ),
                  ],
                ),
                if (o.tomorrowBookings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OwnerTomorrowBanner(
                    bookings: o.tomorrowBookings,
                    onTap: () => context.go('/provider/calendar'),
                  ),
                ],
                const SizedBox(height: 24),
                OwnerSectionTitle(
                  'برنامج اليوم',
                  subtitle: todayArrivals.isEmpty
                      ? 'لا وصول مسجّل اليوم'
                      : '${todayArrivals.length} ${todayArrivals.length == 1 ? 'وصول' : 'وصولات'} اليوم',
                ),
                if (todayArrivals.isEmpty)
                  const _QuietDay()
                else
                  for (var i = 0; i < todayArrivals.length; i++)
                    _TimelineTile(
                      booking: todayArrivals[i],
                      first: i == 0,
                      last: i == todayArrivals.length - 1,
                      onTap: () => context.push(
                        '/provider/bookings/${todayArrivals[i].id}',
                      ),
                    ),
                const SizedBox(height: 22),
                _OccupancyCard(coverage: o.coverage),
                if (laterArrivals.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  OwnerSectionTitle(
                    'القادمون',
                    subtitle: 'خلال الأيام القريبة',
                    trailing: GestureDetector(
                      onTap: () => context.go('/provider/bookings'),
                      child: Text(
                        'الكل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _p.accentDeep,
                        ),
                      ),
                    ),
                  ),
                  for (final (i, b) in laterArrivals.take(5).indexed)
                    _UpcomingTile(
                          booking: b,
                          onTap: () =>
                              context.push('/provider/bookings/${b.id}'),
                        )
                        .animate(delay: (60 * i).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: -.03, end: 0),
                ],
                const SizedBox(height: 24),
                const OwnerSectionTitle('الإدارة'),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _hLine),
                  ),
                  child: Column(
                    children: [
                      OwnerMenuTile(
                        icon: Icons.insights_rounded,
                        label: 'الأرباح والتقارير',
                        onTap: () => context.push('/provider/earnings'),
                      ),
                      const _MenuDivider(),
                      OwnerMenuTile(
                        icon: Icons.local_offer_rounded,
                        label: 'العروض السعرية',
                        trailing: _CountMark(pendingOffers),
                        onTap: () => context.push('/offers'),
                      ),
                      const _MenuDivider(),
                      OwnerMenuTile(
                        icon: Icons.assignment_return_rounded,
                        label: 'طلبات الإلغاء والاسترداد',
                        trailing: _CountMark(pendingRequests),
                        onTap: () => context.push('/provider/requests'),
                      ),
                      const _MenuDivider(),
                      OwnerMenuTile(
                        icon: Icons.receipt_long_rounded,
                        label: 'الفواتير',
                        onTap: () => context.push('/invoices'),
                      ),
                      const _MenuDivider(),
                      OwnerMenuTile(
                        icon: Icons.support_agent_rounded,
                        label: 'الدعم',
                        onTap: () => context.push('/support'),
                      ),
                      const _MenuDivider(),
                      OwnerMenuTile(
                        icon: Icons.manage_accounts_rounded,
                        label: 'حساب المالك',
                        onTap: () => context.push('/provider/account'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton.icon(
                    onPressed: () => providerLogout(context, ref),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(foregroundColor: _hInk2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OwnerTopBar extends StatelessWidget {
  const _OwnerTopBar({required this.name, required this.unread});

  final String? name;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.isNotEmpty;
    return Row(
      children: [
        PressScale(
          onTap: () => context.push('/provider/account'),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [_p.nightHigh, _p.night],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _p.accentLight, width: 1.6),
            ),
            child: hasName
                ? Text(
                    name!.characters.first,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _p.accentLight,
                      height: 1.2,
                    ),
                  )
                : const VibesLogo.mark(size: 24, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ownerFormatDayLong(DateTime.now()),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _p.accentDeep,
                ),
              ),
              Text(
                hasName ? '${_greeting()}، $name' : _greeting(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _hInk,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        _RoundIcon(
          icon: Icons.notifications_none_rounded,
          onTap: () => context.push('/notifications'),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _hLine),
          boxShadow: [
            BoxShadow(
              color: _p.night.withValues(alpha: .05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: _hInk, size: 22),
      ),
    );
  }
}

/// مركز المهام — كل ما ينتظر قراراً منك في بطاقة واحدة.
class _ActionCenter extends StatelessWidget {
  const _ActionCenter({
    required this.pendingBookings,
    required this.pendingRequests,
    required this.pendingOffers,
    required this.onBookings,
    required this.onRequests,
    required this.onOffers,
  });

  final int pendingBookings;
  final int pendingRequests;
  final int pendingOffers;
  final VoidCallback onBookings;
  final VoidCallback onRequests;
  final VoidCallback onOffers;

  @override
  Widget build(BuildContext context) {
    final total = pendingBookings + pendingRequests + pendingOffers;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _p.accent.withValues(alpha: .4), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _p.glow.withValues(alpha: .14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: _p.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, color: _p.onAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  total == 1
                      ? 'أمر واحد ينتظر قرارك'
                      : '$total أمور تنتظر قرارك',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _hInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pendingBookings > 0)
            _TaskRow(
              icon: Icons.event_note_rounded,
              label: 'حجوزات جديدة للتأكيد',
              count: pendingBookings,
              onTap: onBookings,
            ),
          if (pendingRequests > 0)
            _TaskRow(
              icon: Icons.assignment_return_rounded,
              label: 'طلبات إلغاء أو استرداد',
              count: pendingRequests,
              onTap: onRequests,
            ),
          if (pendingOffers > 0)
            _TaskRow(
              icon: Icons.local_offer_rounded,
              label: 'عروض سعرية بانتظار الرد',
              count: pendingOffers,
              onTap: onOffers,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms, delay: 80.ms);
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 19, color: _p.accentDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _hInk,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _p.night,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _p.accentLight,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded, size: 20, color: _hInk2),
          ],
        ),
      ),
    );
  }
}

class _QuietDay extends StatelessWidget {
  const _QuietDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hLine),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _p.accentFaint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wb_sunny_rounded, color: _p.accentDeep, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'يوم هادئ — استغله لتحديث الصور والأسعار أو تسجيل حجوزاتك الخارجية.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _hInk2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shiftLabel(ShiftType s) => switch (s) {
  ShiftType.morning => 'صباحي',
  ShiftType.evening => 'مسائي',
  ShiftType.full => 'يوم كامل',
};

/// خط زمني لوصول اليوم.
class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.booking,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final Booking booking;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = placeShiftColor(booking.shift);
    final guest = booking.guestName ?? booking.userName ?? 'ضيف';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: first ? Colors.transparent : _hLine,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3.5),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? Colors.transparent : _hLine,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: PressScale(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _hLine),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guest,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: _hInk,
                              ),
                            ),
                            Text(
                              '${booking.propertyName ?? 'مكان'} · ${booking.guests} ضيف',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _hInk2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          booking.isExternal
                              ? '${_shiftLabel(booking.shift)} · خارجي'
                              : _shiftLabel(booking.shift),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      if (_phoneOf(booking) != null) ...[
                        const SizedBox(width: 6),
                        _CallButton(phone: _phoneOf(booking)!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _phoneOf(Booking b) {
  final v = (b.guestPhone ?? b.userPhone)?.trim();
  return v == null || v.isEmpty ? null : v;
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: _p.night, shape: BoxShape.circle),
        child: Icon(Icons.call_rounded, size: 17, color: _p.accentLight),
      ),
    );
  }
}

/// الإشغال — حلقة نسبة الأيام المحجوزة خلال الثلاثين يوماً القادمة.
class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.coverage});

  final ProviderCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final c = coverage;
    final booked = c.platformDays + c.externalDays;
    final total = c.totalSlots <= 0 ? 1 : c.totalSlots;
    final ratio = (booked / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _hLine),
        boxShadow: [
          BoxShadow(
            color: _p.night.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CustomPaint(
                    painter: _RingPainter(v),
                    child: Center(
                      child: Text(
                        '${(v * 100).round()}٪',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _hInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإشغال — ٣٠ يوماً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: _hInk,
                      ),
                    ),
                    Text(
                      c.propertyCount == 0
                          ? 'اربط مكانك مع الدعم لتبدأ'
                          : c.openDays > 0
                          ? '${c.openDays} يوماً ما زال متاحاً للضيوف'
                          : 'تقويمك ممتلئ بالكامل',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _hInk2,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OwnerCoverageStack(
            platformDays: c.platformDays,
            externalDays: c.externalDays,
            closedDays: c.closedDays,
            openDays: c.openDays,
            totalSlots: c.totalSlots,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _p.accentFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: _p.accentDeep,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'سجّل حجوزاتك خارج التطبيق ليختفي اليوم عن الضيوف.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _hInk2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/provider/calendar'),
                  child: Text(
                    'سجّل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: _p.accentDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5);
    canvas.drawArc(
      rect,
      0,
      6.2832,
      false,
      Paint()
        ..color = const Color(0xFFEFF1F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * value,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: [_p.accentLight, _p.accentDeep],
          transform: const GradientRotation(-1.5708),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 64, color: _hLine);
}

class _CountMark extends StatelessWidget {
  const _CountMark(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(
        Icons.chevron_left_rounded,
        color: _p.accentDeep.withValues(alpha: .6),
        size: 22,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: _p.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: _p.onAccent,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.booking, this.onTap});

  final Booking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final d = booking.startDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hLine),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_p.nightHigh, _p.night],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${d.day}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      months[d.month - 1],
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _p.accentLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.guestName ?? booking.userName ?? 'ضيف',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: _hInk,
                      ),
                    ),
                    Text(
                      '${ownerRelativeBookingDay(d)} · ${booking.propertyName ?? 'مكان'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _hInk2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PlaceShiftBadge(
                      shift: booking.shift,
                      compact: true,
                      external: booking.isExternal,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  if (booking.totalPrice > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      formatIqdShort(booking.totalPrice),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _hInk,
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
  ShiftType? _shift;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preset = ref.read(providerBookingsStatusFilterProvider);
      if (preset != null) {
        setState(() => _status = preset);
        ref.read(providerBookingsStatusFilterProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ProviderBookingsQuery get _query =>
      ProviderBookingsQuery(status: _status, origin: _origin);

  List<Booking> _filterItems(List<Booking> items) {
    var out = items;
    if (_shift != null) {
      out = out.where((b) => b.shift == _shift).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return out;
    return out.where((b) {
      final hay = [
        b.propertyName,
        b.userName,
        b.userPhone,
        b.guestName,
        b.guestPhone,
        b.shiftLabelAr,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  static const _filters = [
    (null, 'الكل'),
    ('PENDING', 'بانتظار التأكيد'),
    ('CONFIRMED', 'مؤكدة'),
    ('COMPLETED', 'مكتملة'),
    ('CANCELLED', 'ملغاة'),
  ];

  static const _origins = [
    (null, 'كل المصادر'),
    ('PLATFORM', 'تطبيق VIBES'),
    ('EXTERNAL', 'خارجي'),
  ];

  Future<bool> _confirmCancel(Booking booking) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          18 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: SemanticColors.danger.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: SemanticColors.danger,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              booking.status == BookingStatus.pending && !booking.isExternal
                  ? 'رفض هذا الحجز؟'
                  : 'إلغاء هذا الحجز؟',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _hInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${booking.guestName ?? booking.userName ?? 'ضيف'} · ${booking.propertyName ?? ''} · ${ownerFormatDayLong(booking.startDate)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _hInk2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: SemanticColors.danger,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'نعم، تابع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: _hInk),
              child: const Text(
                'تراجع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _act(Booking booking, String status) async {
    if (status == 'CANCELLED' && !await _confirmCancel(booking)) return;
    HapticFeedback.mediumImpact();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(providerBookingsProvider(_query));

    return Scaffold(
      backgroundColor: _p.canvas,
      body: OwnerPortalCanvas(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'حجوزات ممتلكاتي',
              safe: true,
              trailing: bookings.maybeWhen(
                data: (page) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${page.total}',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ownerNavy,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: OwnerSearchField(
                controller: _search,
                hint: 'بحث باسم الضيف أو المكان أو الهاتف',
                onChanged: (_) => setState(() {}),
              ),
            ),
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
            OwnerShiftFilterBar(
              selected: _shift,
              onSelected: (s) => setState(() => _shift = s),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: bookings.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: const [
                    WorldSkeleton(height: 140, radius: 22),
                    SizedBox(height: 12),
                    WorldSkeleton(height: 140, radius: 22),
                    SizedBox(height: 12),
                    WorldSkeleton(height: 140, radius: 22),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () =>
                      ref.invalidate(providerBookingsProvider(_query)),
                ),
                data: (page) {
                  final items = _filterItems(page.items);
                  if (page.items.isEmpty) {
                    return const WorldEmpty(
                      icon: Icons.calendar_month_rounded,
                      title: 'لا حجوزات',
                      subtitle:
                          'حجوزات التطبيق والخارجية تظهر هنا. سجّل الخارجي من التقويم ليُغلق اليوم عن الضيوف',
                    );
                  }
                  if (items.isEmpty) {
                    return const WorldEmpty(
                      icon: Icons.search_off_rounded,
                      title: 'لا نتائج',
                      subtitle: 'جرّب كلمات أخرى أو غيّر الفلتر',
                    );
                  }

                  return RefreshIndicator(
                    color: ownerNavy,
                    onRefresh: () async =>
                        ref.invalidate(providerBookingsProvider(_query)),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _ProviderBookingCard(
                        booking: items[i],
                        onTap: () =>
                            context.push('/provider/bookings/${items[i].id}'),
                        onConfirm: () => _act(items[i], 'CONFIRMED'),
                        onCancel: () => _act(items[i], 'CANCELLED'),
                        onChat: () => _openChat(items[i]),
                        onCall: () =>
                            startCall(ref, context, bookingId: items[i].id),
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
    this.onTap,
  });

  final Booking booking;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final VoidCallback? onTap;

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '964${digits.substring(1)}';
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final b = booking;
    final phone = _phoneOf(b);
    final guest = b.guestName ?? b.userName ?? 'ضيف';
    final pending = b.status == BookingStatus.pending && !b.isExternal;
    final cancelled = b.status == BookingStatus.cancelled;
    final statusColor = switch (b.status) {
      BookingStatus.confirmed => SemanticColors.success,
      BookingStatus.completed => SemanticColors.success,
      BookingStatus.cancelled => SemanticColors.danger,
      _ => SemanticColors.warning,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressScale(
        onTap: onTap,
        child: Opacity(
          opacity: cancelled ? .62 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: pending ? _p.accent.withValues(alpha: .5) : _hLine,
                width: pending ? 1.3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _p.night.withValues(alpha: .05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: ownerNavyFill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${b.startDate.day}',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            months[b.startDate.month - 1],
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: ownerGoldLight,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 18,
                            height: 3,
                            decoration: BoxDecoration(
                              color: placeShiftColor(b.shift),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guest,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _hInk,
                            ),
                          ),
                          Text(
                            '${b.propertyName ?? 'مكان'} · ${ownerRelativeBookingDay(b.startDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _hInk2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              PlaceShiftBadge(
                                shift: b.shift,
                                compact: true,
                                external: b.isExternal,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.group_rounded,
                                size: 14,
                                color: _hInk2.withValues(alpha: .8),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${b.guests}',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _hInk2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusPill(
                          label: b.statusLabelAr,
                          color: statusColor,
                          compact: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatIqdShort(b.totalPrice),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _hInk,
                          ),
                        ),
                        const Text(
                          'د.ع',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _hInk2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: _hLine),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (phone != null) ...[
                      _ContactDot(
                        icon: Icons.call_rounded,
                        tooltip: 'اتصال',
                        onTap: () => _call(phone),
                      ),
                      const SizedBox(width: 8),
                      _ContactDot(
                        icon: Icons.chat_rounded,
                        tooltip: 'واتساب',
                        color: const Color(0xFF25D366),
                        onTap: () => _whatsapp(phone),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!b.isExternal) ...[
                      _ContactDot(
                        icon: Icons.forum_rounded,
                        tooltip: 'رسالة',
                        onTap: onChat,
                      ),
                      const SizedBox(width: 8),
                      _ContactDot(
                        icon: Icons.videocam_rounded,
                        tooltip: 'مكالمة',
                        onTap: onCall,
                      ),
                    ],
                    const Spacer(),
                    if (pending) ...[
                      _PillAction(label: 'رفض', onTap: onCancel),
                      const SizedBox(width: 8),
                      _PillAction(
                        label: 'تأكيد',
                        primary: true,
                        onTap: onConfirm,
                      ),
                    ] else if (b.isExternal && !cancelled)
                      _PillAction(label: 'إلغاء', onTap: onCancel)
                    else
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: _hInk2,
                        size: 22,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactDot extends StatelessWidget {
  const _ContactDot({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (color ?? _p.accentDeep).withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color ?? _p.accentDeep),
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary ? ownerNavyFill : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: primary ? null : Border.all(color: _hLine, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: primary ? ownerGoldLight : _hInk,
          ),
        ),
      ),
    );
  }
}
