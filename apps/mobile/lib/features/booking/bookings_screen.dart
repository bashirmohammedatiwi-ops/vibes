import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
import '../auth/auth_controller.dart';
import 'booking_actions.dart';
import 'booking_providers.dart';
import 'review_sheet.dart';

/// ═══════════════════════════════════════════════════════════
/// حجوزاتي — رأس بجوّ العالم وتبويبات بعدّادات، وبطاقات حجز
/// كتذاكر: كتلة تاريخ كبيرة بلون عالم المكان، الحالة، العدّ
/// التنازلي، والإجراء التالي الواضح (ادفع الآن / قيّم / التفاصيل).
/// ═══════════════════════════════════════════════════════════

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

enum _StatusFilter { active, completed, cancelled }

bool _matches(Booking b, _StatusFilter f) => switch (f) {
  _StatusFilter.active =>
    b.status == BookingStatus.pending ||
        b.status == BookingStatus.awaitingPayment ||
        b.status == BookingStatus.confirmed,
  _StatusFilter.completed => b.status == BookingStatus.completed,
  _StatusFilter.cancelled =>
    b.status == BookingStatus.cancelled || b.status == BookingStatus.disputed,
};

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // أحدث حالة دائماً عند فتح الصفحة (حجز جديد، تأكيد، إلغاء…)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(myBookingsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(myBookingsProvider).valueOrNull ?? const <Booking>[];
    final counts = [
      for (final f in _StatusFilter.values)
        list.where((b) => _matches(b, f)).length,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: context.world.canvas,
        body: Column(
          children: [
            WorldPageHeader(
              title: 'حجوزاتي',
              subtitle: counts[0] > 0
                  ? 'لديك ${counts[0]} حجز نشط'
                  : 'كل مناسباتك في مكان واحد',
              bottom: WorldPillTabs(
                labels: const ['النشطة', 'المكتملة', 'الملغاة'],
                index: _tab,
                counts: counts,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(child: _BookingsList(filter: _StatusFilter.values[_tab])),
          ],
        ),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  const _BookingsList({required this.filter});

  final _StatusFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authControllerProvider).loggedIn;
    if (!loggedIn) {
      return Center(
        child: WorldEmpty(
          icon: Icons.event_available_rounded,
          title: 'حجوزاتك هنا',
          subtitle: 'سجّل دخولك لترى حجوزاتك وتتابع الدفع والتأكيد',
          actionLabel: 'تسجيل الدخول',
          onAction: () => context.push('/login'),
        ),
      );
    }

    final bookings = ref.watch(myBookingsProvider);
    return bookings.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(20),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: WorldSkeleton(height: 150, radius: 22),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: WorldEmpty(
          icon: Icons.wifi_off_rounded,
          title: 'تعذّر التحميل',
          subtitle: maisonError(e),
          actionLabel: 'إعادة المحاولة',
          onAction: () => ref.invalidate(myBookingsProvider),
        ),
      ),
      data: (list) {
        final filtered = list.where((b) => _matches(b, filter)).toList();
        if (filtered.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: WorldEmpty(
                icon: switch (filter) {
                  _StatusFilter.active => Icons.celebration_outlined,
                  _StatusFilter.completed => Icons.history_rounded,
                  _StatusFilter.cancelled => Icons.event_busy_outlined,
                },
                title: switch (filter) {
                  _StatusFilter.active => 'لا حجوزات نشطة',
                  _StatusFilter.completed => 'لا حجوزات مكتملة بعد',
                  _StatusFilter.cancelled => 'لا حجوزات ملغاة',
                },
                subtitle: filter == _StatusFilter.active
                    ? 'مناسبتك القادمة تبدأ من هنا — اختر مكاناً واحجز بدقيقة'
                    : null,
                actionLabel: filter == _StatusFilter.active
                    ? 'استكشف الأماكن'
                    : null,
                onAction: filter == _StatusFilter.active
                    ? () => context.go('/home')
                    : null,
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: context.world.accent,
          onRefresh: () async => ref.invalidate(myBookingsProvider),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            itemCount: filtered.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BookingCard(booking: filtered[i])
                  .animate(delay: Duration(milliseconds: 40 * i.clamp(0, 8)))
                  .fadeIn(duration: 380.ms)
                  .slideY(begin: .05, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        );
      },
    );
  }
}

const _months = [
  'كانون٢',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين١',
  'تشرين٢',
  'كانون١',
];
const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

class _BookingCard extends ConsumerStatefulWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _rated = false;

  Booking get b => widget.booking;

  Color get _statusColor => switch (b.status) {
    BookingStatus.pending => Vibes.warning,
    BookingStatus.awaitingPayment => Brand.sapphireLight,
    BookingStatus.confirmed => Vibes.success,
    BookingStatus.completed => Vibes.success,
    BookingStatus.cancelled => Vibes.danger,
    BookingStatus.disputed => Vibes.danger,
  };

  String? get _countdown {
    if (b.status == BookingStatus.cancelled ||
        b.status == BookingStatus.completed)
      return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      b.startDate.year,
      b.startDate.month,
      b.startDate.day,
    );
    final days = start.difference(today).inDays;
    if (days < 0) return null;
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غداً';
    if (days == 2) return 'بعد يومين';
    if (days <= 10) return 'بعد $days أيام';
    return 'بعد $days يوماً';
  }

  @override
  Widget build(BuildContext context) {
    final p = WorldPalette.forType(b.propertyType);
    final d = b.startDate;
    final payNow =
        b.status == BookingStatus.awaitingPayment ||
        (b.payment != null &&
            !b.payment!.isPaid &&
            b.status == BookingStatus.pending);
    final canRate =
        b.status == BookingStatus.completed && b.canReview && !_rated;
    final countdown = _countdown;

    return PressScale(
      onTap: () => context.push('/booking/${b.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.accent.withValues(alpha: .14)),
          boxShadow: [
            BoxShadow(
              color: p.glow.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── كتلة التاريخ بلون عالم المكان ──
                  Container(
                    width: 84,
                    decoration: BoxDecoration(gradient: p.nightfall),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdays[d.weekday - 1],
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: .7),
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          _months[d.month - 1],
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: p.accentLight,
                          ),
                        ),
                        if (b.nights > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${b.nights} أيام',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: .7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ── التفاصيل ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b.propertyName ?? 'مكان',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Vibes.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: b.coverUrl != null
                                      ? VibesNetImage(
                                          url: b.coverUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : ColoredBox(color: p.accentSoft),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              WorldStatusChip(
                                label: b.statusLabelAr,
                                color: _statusColor,
                              ),
                              if (countdown != null)
                                WorldStatusChip(
                                  label: countdown,
                                  color: p.accentDeep,
                                  icon: Icons.schedule_rounded,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.wb_twilight_rounded,
                                size: 14,
                                color: p.accentDeep,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                b.shiftLabelAr,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Vibes.inkSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.groups_outlined,
                                size: 14,
                                color: Vibes.inkTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${b.guests}',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Vibes.inkSecondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${formatIqdShort(b.totalPrice)} د.ع',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: p.accentDeep,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── الإجراء التالي ──
            if (payNow ||
                canRate ||
                b.conversationId != null ||
                b.invoiceNumber != null ||
                canCancelDirectly(b) ||
                canRequestRefund(b) ||
                refundRequestPending(b))
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: p.accent.withValues(alpha: .1)),
                  ),
                ),
                child: Row(
                  children: [
                    if (payNow)
                      Expanded(
                        child: WorldButton(
                          label: 'أكمل الدفع',
                          icon: Icons.lock_outline_rounded,
                          height: 44,
                          palette: p,
                          onTap: () => context.push('/booking/${b.id}'),
                        ),
                      )
                    else if (canRate)
                      Expanded(
                        child: WorldButton(
                          label: 'قيّم تجربتك',
                          icon: Icons.star_rounded,
                          height: 44,
                          palette: p,
                          onTap: () async {
                            final done = await showReviewSheet(context, ref, b);
                            if (done && mounted) setState(() => _rated = true);
                          },
                        ),
                      )
                    else
                      const Spacer(),
                    if (b.conversationId != null) ...[
                      const SizedBox(width: 8),
                      _MiniAction(
                        icon: Icons.forum_outlined,
                        color: p.accentDeep,
                        onTap: () => context.push('/chat/${b.conversationId}'),
                      ),
                    ],
                    if (b.invoiceNumber != null) ...[
                      const SizedBox(width: 8),
                      _MiniAction(
                        icon: Icons.receipt_long_outlined,
                        color: p.accentDeep,
                        onTap: () => context.push('/booking/${b.id}/invoice'),
                      ),
                    ],
                    if (canCancelDirectly(b)) ...[
                      const SizedBox(width: 8),
                      _CancelPill(
                        label: 'إلغاء',
                        onTap: () => cancelBookingFlow(context, ref, b),
                      ),
                    ] else if (refundRequestPending(b)) ...[
                      const SizedBox(width: 8),
                      const _CancelPill(label: 'الإلغاء قيد المراجعة'),
                    ] else if (canRequestRefund(b)) ...[
                      const SizedBox(width: 8),
                      _CancelPill(
                        label: 'طلب إلغاء',
                        onTap: () => requestRefundFlow(context, ref, b),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// زر إلغاء هادئ بالأحمر — بلا [onTap] يصبح شارة حالة فقط.
class _CancelPill extends StatelessWidget {
  const _CancelPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    const amber = Color(0xFFB45309);
    final c = onTap == null ? amber : red;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: .22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              onTap == null
                  ? Icons.hourglass_top_rounded
                  : Icons.event_busy_rounded,
              size: 16,
              color: c,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
