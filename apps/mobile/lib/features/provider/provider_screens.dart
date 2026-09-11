import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: overview.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(providerOverviewProvider),
        ),
        data: (o) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
          children: [
            // ترويسة
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بوابة المالك',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: InkColors.textTertiary,
                                ),
                      ),
                      Text(
                        'مساء الخير 👑',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: InkColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/provider/earnings'),
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GoldColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: GoldColors.gold, size: 20),
                  ),
                ),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 24),

            // بطاقة الإيراد البطلة — تدرج ذهبي داكن
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VibesRadius.xl),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF26221A), Color(0xFF15130E)],
                ),
                border: Border.all(color: GoldColors.gold.withValues(alpha: .25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أرباح هذا الشهر',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: GoldColors.gold.withValues(alpha: .85),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PriceText(o.monthRevenue),
                      const Spacer(),
                      Text(
                        '${o.monthBookings} حجزاً',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: InkColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: .04, end: 0),
            const SizedBox(height: 14),

            // صفوف KPI
            Row(
              children: [
                Expanded(
                  child: _KpiTile(
                    label: 'ممتلكاتي',
                    value: '${o.propertyCount}',
                    icon: Icons.home_work_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiTile(
                    label: 'نشطة',
                    value: '${o.activeBookings}',
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiTile(
                    label: 'بانتظارك',
                    value: '${o.pendingBookings}',
                    icon: Icons.hourglass_top_rounded,
                    alert: o.pendingBookings > 0,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 26),

            // الوصولات القادمة
            if (o.upcoming.isNotEmpty) ...[
              const SectionHeader('الوصولات القادمة'),
              for (final b in o.upcoming.take(5))
                _UpcomingTile(booking: b)
                    .animate(delay: Duration(milliseconds: 300))
                    .fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    this.alert = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(VibesRadius.lg),
        border: Border.all(
          color: alert
              ? GoldColors.gold.withValues(alpha: .4)
              : InkColors.hairline,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: alert ? GoldColors.gold : InkColors.textTertiary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: InkColors.textPrimary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: InkColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(VibesRadius.lg),
        border: Border.all(color: InkColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: GoldColors.goldSoft,
              borderRadius: BorderRadius.circular(VibesRadius.md),
            ),
            child: Text(
              '${booking.startDate.day}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: GoldColors.gold,
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
                        color: InkColors.textPrimary,
                      ),
                ),
                Text(
                  '${booking.userName ?? 'ضيف'} · ${booking.shiftLabelAr}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: InkColors.textTertiary,
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

  static const _filters = [
    (null, 'الكل'),
    ('PENDING', 'بانتظار التأكيد'),
    ('CONFIRMED', 'مؤكدة'),
    ('CANCELLED', 'ملغاة'),
  ];

  Future<void> _act(Booking booking, String status) async {
    try {
      final client = ref.read(apiClientProvider);
      await updateBookingStatus(client, booking.id, status);
      ref.invalidate(providerBookingsProvider(_status));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(providerBookingsProvider(_status));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('حجوزات ممتلكاتي'),
      ),
      body: Column(
        children: [
          // الفلاتر
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _filters.map((f) {
                final active = _status == f.$1;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _status = f.$1),
                    child: AnimatedContainer(
                      duration: VibesMotion.fast,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: active ? GoldColors.gradient : null,
                        color: active ? null : InkColors.surface,
                        borderRadius: BorderRadius.circular(VibesRadius.pill),
                        border: active ? null : Border.all(color: InkColors.hairline),
                      ),
                      child: Text(
                        f.$2,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? GoldColors.onGold
                                      : InkColors.textSecondary,
                                ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: bookings.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: GoldColors.gold),
              ),
              error: (e, _) => ErrorCanvas(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(providerBookingsProvider(_status)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyCanvas(
                    icon: Icons.calendar_month_outlined,
                    title: 'لا حجوزات',
                    subtitle: 'ستظهر حجوزات ممتلكاتك هنا',
                  );
                }

                return RefreshIndicator(
                  color: GoldColors.gold,
                  onRefresh: () async =>
                      ref.invalidate(providerBookingsProvider(_status)),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: page.items.length,
                    itemBuilder: (context, i) => _ProviderBookingCard(
                      booking: page.items[i],
                      onConfirm: () => _act(page.items[i], 'CONFIRMED'),
                      onCancel: () => _act(page.items[i], 'CANCELLED'),
                    ).animate(delay: Duration(milliseconds: i * 35)).fadeIn(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderBookingCard extends StatelessWidget {
  const _ProviderBookingCard({
    required this.booking,
    required this.onConfirm,
    required this.onCancel,
  });

  final Booking booking;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(VibesRadius.lg),
        border: Border.all(color: InkColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.propertyName ?? 'مكان',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: InkColors.textPrimary,
                      ),
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
          const SizedBox(height: 8),
          Text(
            'الضيف: ${booking.userName ?? 'زائر'} · ${booking.shiftLabelAr} · ${booking.guests} ضيف',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: InkColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.startDate.day}/${booking.startDate.month} → ${booking.endDate.day}/${booking.endDate.month} · ${PriceText.format(booking.totalPrice)} د.ع',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: InkColors.textTertiary,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // تواصل
              IconButton(
                onPressed: booking.userPhone != null
                    ? () => _call(booking.userPhone!)
                    : null,
                icon: Icon(Icons.call_outlined,
                    size: 19, color: InkColors.textSecondary),
                style: IconButton.styleFrom(
                  backgroundColor: InkColors.surfaceHigh,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: booking.userPhone != null
                    ? () => _whatsapp(booking.userPhone!)
                    : null,
                icon: Icon(Icons.chat_bubble_outline_rounded,
                    size: 19, color: InkColors.textSecondary),
                style: IconButton.styleFrom(
                  backgroundColor: InkColors.surfaceHigh,
                ),
              ),
              const Spacer(),
              // الإجراءات
              if (booking.status == BookingStatus.pending) ...[
                SizedBox(
                  height: 36,
                  child: VibesButton(
                    label: 'تأكيد',
                    small: true,
                    expanded: false,
                    onPressed: onConfirm,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: VibesButton(
                    label: 'إلغاء',
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
    );
  }
}
