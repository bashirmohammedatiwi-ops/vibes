import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import 'booking_providers.dart';
import 'review_sheet.dart';

/// ═══════════════════════════════════════════════════════════
/// حجوزاتي — تبويبات حالة + بطاقات بتفاصيل وإجراءات
/// ═══════════════════════════════════════════════════════════

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _tab = 0;

  static const _filters = [
    _StatusFilter.active,
    _StatusFilter.completed,
    _StatusFilter.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MaisonWash(
        child: SafeArea(
          child: Column(
            children: [
              const MaisonPageHeader(
                title: 'حجوزاتي',
                kicker: 'جدول مناسباتك',
                safe: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: MaisonSegmented(
                  labels: const ['النشطة', 'المكتملة', 'الملغاة'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(child: _BookingsList(filter: _filters[_tab])),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StatusFilter { active, completed, cancelled }

class _BookingsList extends ConsumerWidget {
  const _BookingsList({required this.filter});

  final _StatusFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authControllerProvider).loggedIn;
    final bookings = ref.watch(myBookingsProvider);
    if (!loggedIn) {
      return EmptyCanvas(
        icon: Icons.beach_access_rounded,
        title: 'حجوزاتك هنا',
        subtitle: 'ادخل لترى حجوزاتك، أو أكمل حجزاً جديداً',
        action: VibesButton(
          label: 'دخول',
          small: true,
          onPressed: () => context.push('/login'),
        ),
      );
    }

    return bookings.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(20),
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ShimmerBox(height: 130, radius: VibesRadius.lg),
          ),
        ),
      ),
      error: (e, _) => ErrorCanvas(
        message: maisonError(e),
        onRetry: () => ref.invalidate(myBookingsProvider),
      ),
      data: (list) {
        final filtered = list.where((b) {
          return switch (filter) {
            _StatusFilter.active =>
              b.status == BookingStatus.pending ||
                  b.status == BookingStatus.awaitingPayment ||
                  b.status == BookingStatus.confirmed,
            _StatusFilter.completed => b.status == BookingStatus.completed,
            _StatusFilter.cancelled =>
              b.status == BookingStatus.cancelled ||
                  b.status == BookingStatus.disputed,
          };
        }).toList();

        if (filtered.isEmpty) {
          return EmptyCanvas(
            icon: Icons.beach_access_rounded,
            title: 'لا حجوزات هنا',
            subtitle: switch (filter) {
              _StatusFilter.active => 'حجوزاتك النشطة ستظهر هنا',
              _StatusFilter.completed => 'حجوزاتك المكتملة ستظهر هنا',
              _StatusFilter.cancelled => 'لا حجوزات ملغاة',
            },
            action: filter == _StatusFilter.active
                ? VibesButton(
                    label: 'استكشف الأماكن',
                    small: true,
                    ghost: true,
                    onPressed: () => context.go('/home'),
                  )
                : null,
          );
        }

        return RefreshIndicator(
          color: Vibes.teal,
          onRefresh: () async => ref.invalidate(myBookingsProvider),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: filtered.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BookingCard(booking: filtered[i])
                  .animate(delay: Duration(milliseconds: i * 40))
                  .fadeIn(duration: VibesMotion.slow)
                  .slideY(begin: .03, end: 0, curve: VibesMotion.curve),
            ),
          ),
        );
      },
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _rated = false;

  (Color, String) get _statusStyle => switch (widget.booking.status) {
    BookingStatus.pending => (
      SemanticColors.warning,
      widget.booking.statusLabelAr,
    ),
    BookingStatus.awaitingPayment => (
      SemanticColors.info,
      widget.booking.statusLabelAr,
    ),
    BookingStatus.confirmed => (
      SemanticColors.success,
      widget.booking.statusLabelAr,
    ),
    BookingStatus.completed => (
      SemanticColors.success,
      widget.booking.statusLabelAr,
    ),
    BookingStatus.cancelled => (
      SemanticColors.danger,
      widget.booking.statusLabelAr,
    ),
    BookingStatus.disputed => (
      SemanticColors.danger,
      widget.booking.statusLabelAr,
    ),
  };

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}${d.year != DateTime.now().year ? '/${d.year}' : ''}';

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusStyle;

    return FolioPanel(
      railColor: color,
      shadows: Vibes.card,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/booking/${widget.booking.id}'),
          customBorder: Folio.shape,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipPath(
                      clipper: const ShapeBorderClipper(
                        shape: Folio.compactShape,
                      ),
                      child: SizedBox(
                        width: 96,
                        height: 72,
                        child: widget.booking.coverUrl != null
                            ? VibesNetImage(
                                url: widget.booking.coverUrl!,
                                width: 96,
                                height: 72,
                                fit: BoxFit.cover,
                              )
                            : ColoredBox(
                                color: color.withValues(alpha: .12),
                                child: Icon(
                                  Icons.home_work_rounded,
                                  color: color,
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
                            widget.booking.propertyName ?? 'مكان',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          StatusPill(label: label, color: color, compact: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _BookingMeta(
                      icon: Icons.calendar_today_rounded,
                      label:
                          '${_formatDate(widget.booking.startDate)} → ${_formatDate(widget.booking.endDate.subtract(const Duration(days: 1)))}',
                    ),
                    _BookingMeta(
                      icon: Icons.schedule_rounded,
                      label: widget.booking.shiftLabelAr,
                    ),
                    _BookingMeta(
                      icon: Icons.groups_outlined,
                      label: '${widget.booking.guests} ضيف',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.booking.discountAmount > 0) ...[
                      Text(
                        '${PriceText.format(widget.booking.totalPrice + widget.booking.discountAmount)} د.ع',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    PriceText(widget.booking.totalPrice, compact: true),
                    const Spacer(),
                    // الدفع
                    if (widget.booking.payment != null) ...[
                      StatusPill(
                        label: widget.booking.payment!.isPaid
                            ? 'مدفوع'
                            : 'بانتظار الدفع',
                        color: widget.booking.payment!.isPaid
                            ? SemanticColors.success
                            : SemanticColors.warning,
                        compact: true,
                      ),
                    ],
                  ],
                ),

                // إجراءات
                if (widget.booking.status == BookingStatus.awaitingPayment ||
                    widget.booking.status == BookingStatus.pending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: VibesButton(
                            label: 'تفاصيل',
                            ghost: true,
                            small: true,
                            onPressed: () =>
                                context.push('/booking/${widget.booking.id}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (widget.booking.status == BookingStatus.completed &&
                          (widget.booking.canReview || _rated)) ...[
                        if (_rated || !widget.booking.canReview)
                          StatusPill(
                            label: 'شكراً لتقييمك',
                            color: Vibes.success,
                            compact: true,
                          )
                        else
                          GestureDetector(
                            onTap: () async {
                              final done = await showReviewSheet(
                                context,
                                ref,
                                widget.booking,
                              );
                              if (done && mounted)
                                setState(() => _rated = true);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 17,
                                  color: Vibes.coral,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'قيّم تجربتك',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Vibes.coral,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const Spacer(),
                      if (widget.booking.conversationId != null)
                        TextButton(
                          onPressed: () => context.push(
                            '/chat/${widget.booking.conversationId}',
                          ),
                          child: const Text('محادثة'),
                        ),
                      if (widget.booking.invoiceNumber != null)
                        TextButton(
                          onPressed: () => context.push(
                            '/booking/${widget.booking.id}/invoice',
                          ),
                          child: const Text('فاتورة'),
                        ),
                      TextButton(
                        onPressed: () =>
                            context.push('/booking/${widget.booking.id}'),
                        child: const Text('التفاصيل'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingMeta extends StatelessWidget {
  const _BookingMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: VibesTheme.textTertiaryOf(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: VibesTheme.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
