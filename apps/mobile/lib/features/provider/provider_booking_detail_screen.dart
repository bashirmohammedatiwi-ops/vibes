import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../chat/call_screen.dart';
import '../property/place_experience_ui.dart';
import 'provider_data.dart';
import 'provider_ui.dart';
import '../../core/theme/world_theme.dart';
import '../property/shift_calendar_ui.dart';

final providerBookingDetailProvider = FutureProvider.family<Booking, String>((
  ref,
  id,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get('/api/provider/bookings/$id');
  return Booking.fromJson(data as Map<String, dynamic>);
});

class ProviderBookingDetailScreen extends ConsumerWidget {
  const ProviderBookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
    Booking booking,
  ) async {
    if (status == 'CANCELLED') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'إلغاء هذا الحجز؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'سيُبلَّغ الضيف ويعود اليوم متاحاً في التقويم.',
            style: TextStyle(fontFamily: 'Cairo', height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: ownerNavy),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: SemanticColors.danger,
                shape: const StadiumBorder(),
              ),
              child: const Text('نعم، إلغاء'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.mediumImpact();
    try {
      final client = ref.read(apiClientProvider);
      if (booking.isExternal && status == 'CANCELLED') {
        await cancelExternalBooking(client, booking.id);
      } else {
        await updateBookingStatus(client, booking.id, status);
      }
      ref.invalidate(providerBookingDetailProvider(bookingId));
      ref.invalidate(providerOverviewProvider);
      ref.invalidate(providerBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'CONFIRMED' ? 'تم تأكيد الحجز' : 'تم إلغاء الحجز',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(maisonError(e))));
      }
    }
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .post('/api/conversations/booking', body: {'bookingId': bookingId});
      final id = (data as Map<String, dynamic>)['id'] as String?;
      if (context.mounted && id != null) context.push('/chat/$id');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(maisonError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(providerBookingDetailProvider(bookingId));

    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: detail.when(
        loading: () => const Center(child: ThreadProgress(width: 120)),
        error: (e, _) => ErrorCanvas(
          message: maisonError(e),
          onRetry: () =>
              ref.invalidate(providerBookingDetailProvider(bookingId)),
        ),
        data: (booking) {
          final guest = booking.userName ?? booking.guestName ?? 'ضيف';
          final phone = booking.userPhone ?? booking.guestPhone;
          final pay = booking.payment;

          return Column(
            children: [
              MaisonPageHeader(
                title: 'تفاصيل الحجز',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: ownerNavy,
                  onRefresh: () async =>
                      ref.invalidate(providerBookingDetailProvider(bookingId)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      Row(
                        children: [
                          const OwnerBrassRule(),
                          const Spacer(),
                          if (booking.isExternal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ownerPaper,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ownerLine),
                              ),
                              child: const Text(
                                'حجز خارجي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: placeInk2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () =>
                            context.push('/property/${booking.propertyId}'),
                        child: Text(
                          booking.propertyName ?? 'مكان',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: ownerNavy,
                            decoration: TextDecoration.underline,
                            decorationColor: ownerGoldDeep,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PlaceShiftBadge(
                        shift: booking.shift,
                        external: booking.isExternal,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_dateAr(booking.startDate)} · $guest',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: placeInk2,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _DetailCard(
                        children: [
                          _DetailRow(
                            label: 'الحالة',
                            value: booking.statusLabelAr,
                            valueColor: _statusColor(booking.status),
                          ),
                          _DetailRow(
                            label: 'المبلغ',
                            value:
                                '${PriceText.format(booking.totalPrice)} د.ع',
                            valueBold: true,
                          ),
                          if (booking.guests > 0)
                            _DetailRow(
                              label: 'الضيوف',
                              value: '${booking.guests}',
                            ),
                          if (pay != null)
                            _DetailRow(
                              label: 'الدفع',
                              value: pay.isPaid ? 'مدفوع' : 'بانتظار الدفع',
                            ),
                          if (booking.invoiceNumber != null)
                            _DetailRow(
                              label: 'الفاتورة',
                              value: booking.invoiceNumber!,
                            ),
                        ],
                      ),
                      if (booking.notes != null &&
                          booking.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _DetailCard(
                          children: [
                            const Text(
                              'ملاحظات',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: placeInk2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              booking.notes!,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ownerNavy,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      const OwnerSectionTitle('تواصل مع الضيف'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (phone != null) ...[
                            _ContactChip(
                              icon: Icons.call_outlined,
                              label: 'اتصال',
                              onTap: () => _launchTel(phone),
                            ),
                            _ContactChip(
                              icon: Icons.chat_outlined,
                              label: 'واتساب',
                              onTap: () => _launchWhatsApp(phone),
                            ),
                            _ContactChip(
                              icon: Icons.copy_outlined,
                              label: 'نسخ الرقم',
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: phone));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ الرقم')),
                                );
                              },
                            ),
                          ],
                          if (!booking.isExternal)
                            _ContactChip(
                              icon: Icons.forum_outlined,
                              label: 'رسالة',
                              onTap: () => _openChat(context, ref),
                            ),
                          _ContactChip(
                            icon: Icons.videocam_outlined,
                            label: 'مكالمة بالتطبيق',
                            onTap: () =>
                                startCall(ref, context, bookingId: booking.id),
                          ),
                        ],
                      ),
                      if (booking.status == BookingStatus.pending &&
                          !booking.isExternal) ...[
                        const SizedBox(height: 24),
                        VibesButton(
                          label: 'تأكيد الحجز',
                          onPressed: () =>
                              _setStatus(context, ref, 'CONFIRMED', booking),
                        ),
                        const SizedBox(height: 10),
                        VibesButton(
                          label: 'رفض الحجز',
                          ghost: true,
                          onPressed: () =>
                              _setStatus(context, ref, 'CANCELLED', booking),
                        ),
                      ],
                      if (booking.isExternal &&
                          booking.status != BookingStatus.cancelled) ...[
                        const SizedBox(height: 24),
                        VibesButton(
                          label: 'إلغاء الحجز الخارجي',
                          ghost: true,
                          onPressed: () =>
                              _setStatus(context, ref, 'CANCELLED', booking),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _dateAr(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static Color _statusColor(BookingStatus s) => switch (s) {
    BookingStatus.confirmed => SemanticColors.success,
    BookingStatus.completed => SemanticColors.success,
    BookingStatus.cancelled => SemanticColors.danger,
    _ => ownerGoldDeep,
  };

  static Future<void> _launchTel(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> _launchWhatsApp(String phone) async {
    final uri = Uri.parse(
      'https://wa.me/${phone.replaceFirst(RegExp(r'^\+'), '')}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ownerPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ownerLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool valueBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: placeInk2,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: valueBold ? 16 : 14,
              fontWeight: valueBold ? FontWeight.w900 : FontWeight.w800,
              color: valueColor ?? ownerNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ownerLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: ownerNavy),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ownerNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
