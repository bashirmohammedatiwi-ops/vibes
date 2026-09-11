import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'booking_providers.dart';

/// ═══════════════════════════════════════════════════════════
/// حجوزاتي — تبويبات حالة + بطاقات بتفاصيل وإجراءات
/// ═══════════════════════════════════════════════════════════

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حجوزاتي'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'النشطة'),
              Tab(text: 'المكتملة'),
              Tab(text: 'الملغاة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingsList(filter: _StatusFilter.active),
            _BookingsList(filter: _StatusFilter.completed),
            _BookingsList(filter: _StatusFilter.cancelled),
          ],
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
    final bookings = ref.watch(myBookingsProvider);

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
        message: e.toString(),
        onRetry: () => ref.invalidate(myBookingsProvider),
      ),
      data: (list) {
        final filtered = list.where((b) {
          return switch (filter) {
            _StatusFilter.active => b.status == BookingStatus.pending ||
                b.status == BookingStatus.awaitingPayment ||
                b.status == BookingStatus.confirmed,
            _StatusFilter.completed => b.status == BookingStatus.completed,
            _StatusFilter.cancelled => b.status == BookingStatus.cancelled ||
                b.status == BookingStatus.disputed,
          };
        }).toList();

        if (filtered.isEmpty) {
          return EmptyCanvas(
            icon: Icons.calendar_month_outlined,
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

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          itemCount: filtered.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BookingCard(booking: filtered[i])
                .animate(delay: Duration(milliseconds: i * 40))
                .fadeIn(duration: VibesMotion.slow)
                .slideY(begin: .03, end: 0, curve: VibesMotion.curve),
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  (Color, String) get _statusStyle => switch (booking.status) {
        BookingStatus.pending => (SemanticColors.warning, booking.statusLabelAr),
        BookingStatus.awaitingPayment => (
            SemanticColors.info,
            booking.statusLabelAr
          ),
        BookingStatus.confirmed => (
            SemanticColors.success,
            booking.statusLabelAr
          ),
        BookingStatus.completed => (
            SemanticColors.success,
            booking.statusLabelAr
          ),
        BookingStatus.cancelled => (
            SemanticColors.danger,
            booking.statusLabelAr
          ),
        BookingStatus.disputed => (
            SemanticColors.danger,
            booking.statusLabelAr
          ),
      };

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}${d.year != DateTime.now().year ? '/${d.year}' : ''}';

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusStyle;

    return VibesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.propertyName ?? 'مكان',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              StatusPill(label: label, color: color, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13, color: VibesTheme.textTertiaryOf(context)),
              const SizedBox(width: 6),
              Text(
                '${_formatDate(booking.startDate)} → ${_formatDate(booking.endDate.subtract(const Duration(days: 1)))}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.schedule_rounded,
                  size: 13, color: VibesTheme.textTertiaryOf(context)),
              const SizedBox(width: 6),
              Text(
                booking.shiftLabelAr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.groups_outlined,
                  size: 13, color: VibesTheme.textTertiaryOf(context)),
              const SizedBox(width: 6),
              Text(
                '${booking.guests} ضيف',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textSecondaryOf(context),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (booking.discountAmount > 0) ...[
                Text(
                  '${PriceText.format(booking.totalPrice + booking.discountAmount)} د.ع',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VibesTheme.textTertiaryOf(context),
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
                const SizedBox(width: 6),
              ],
              PriceText(booking.totalPrice, compact: true),
              const Spacer(),
              // الدفع
              if (booking.payment != null) ...[
                StatusPill(
                  label: booking.payment!.isPaid ? 'مدفوع' : 'بانتظار الدفع',
                  color: booking.payment!.isPaid
                      ? SemanticColors.success
                      : SemanticColors.warning,
                  compact: true,
                ),
              ],
            ],
          ),

          // إجراءات
          if (booking.status == BookingStatus.awaitingPayment ||
              booking.status == BookingStatus.pending) ...[
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
                          context.push('/booking/${booking.id}'),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.push('/booking/${booking.id}'),
                child: const Text('التفاصيل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
