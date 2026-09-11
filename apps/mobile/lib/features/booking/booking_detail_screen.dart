
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'booking_providers.dart';

/// ═══════════════════════════════════════════════════════════
/// تفاصيل الحجز — خط زمني للحالة + رفع إثبات دفع + إلغاء
/// ═══════════════════════════════════════════════════════════

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _uploading = false;

  Future<void> _uploadProof(Booking booking) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (photo == null) return;

    setState(() => _uploading = true);
    try {
      final client = ref.read(apiClientProvider);
      final fileName = photo.path.split('/').last;
      final file = await MultipartFile.fromFile(
        photo.path,
        filename: fileName,
      );
      final media = await client.upload(
        '/api/media/upload',
        fieldName: 'file',
        file: file,
      ) as Map<String, dynamic>;

      // إرفاق الإثبات بالحجز
      await client.post(
        '/api/bookings/${booking.id}/payment-proof',
        body: {'proofUrl': media['url']},
      );

      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع إثبات الدفع — بانتظار المراجعة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = ref.read(apiClientProvider);
      await client.patch(
        '/api/bookings/${booking.id}/status',
        body: {'status': 'CANCELLED'},
      );
      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.id));
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingDetailProvider(widget.id));

    return booking.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: GoldColors.gold)),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.id)),
        ),
      ),
      data: (b) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحجز')),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // المكان
            VibesCard(
              onTap: () => context.push('/property/${b.propertyId}'),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.propertyName ?? 'مكان',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${b.cityName ?? ''} · ${b.shiftLabelAr}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: VibesTheme.textTertiaryOf(context),
                  ),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 18),

            // الخط الزمني للحالة
            const SectionHeader('حالة الحجز'),
            _StatusTimeline(booking: b),
            const SizedBox(height: 18),

            // التفاصيل
            const SectionHeader('تفاصيل'),
            VibesCard(
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'التواريخ',
                    value:
                        '${_fmt(b.startDate)} → ${_fmt(b.endDate.subtract(const Duration(days: 1)))} (${b.nights} ${b.nights == 1 ? 'ليلة' : 'ليالٍ'})',
                  ),
                  _divider(context),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'الوقت',
                    value: b.shiftLabelAr,
                  ),
                  _divider(context),
                  _DetailRow(
                    icon: Icons.groups_outlined,
                    label: 'الضيوف',
                    value: '${b.guests} ضيف',
                  ),
                  if (b.discountAmount > 0) ...[
                    _divider(context),
                    _DetailRow(
                      icon: Icons.local_offer_rounded,
                      label: 'الخصم',
                      value: '− ${PriceText.format(b.discountAmount)} د.ع',
                      valueColor: SemanticColors.success,
                    ),
                  ],
                  _divider(context),
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    label: 'الإجمالي',
                    value: '${PriceText.format(b.totalPrice)} د.ع',
                    valueColor: GoldColors.gold,
                  ),
                  if (b.notes?.isNotEmpty == true) ...[
                    _divider(context),
                    _DetailRow(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظاتك',
                      value: b.notes!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // الدفع
            if (b.payment != null) ...[
              const SectionHeader('الدفع'),
              _PaymentCard(
                booking: b,
                uploading: _uploading,
                onUpload: () => _uploadProof(b),
              ),
              const SizedBox(height: 18),
            ],

            // الإلغاء
            if (b.status == BookingStatus.pending ||
                b.status == BookingStatus.confirmed)
              SizedBox(
                width: double.infinity,
                child: VibesButton(
                  label: 'إلغاء الحجز',
                  ghost: true,
                  onPressed: () => _cancel(b),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}';

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        color: VibesTheme.hairlineOf(context),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: VibesTheme.textTertiaryOf(context)),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VibesTheme.textTertiaryOf(context),
                ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? VibesTheme.textPrimaryOf(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    // مراحل الخط الزمني حسب الحالة
    final stages = <({String label, bool done, bool current})>[
      (
        label: 'تم إنشاء الحجز',
        done: true,
        current: booking.status == BookingStatus.pending,
      ),
      (
        label: booking.status == BookingStatus.awaitingPayment
            ? 'بانتظار إثبات الدفع'
            : 'تم الدفع',
        done: booking.status != BookingStatus.pending &&
            booking.status != BookingStatus.awaitingPayment,
        current: booking.status == BookingStatus.awaitingPayment,
      ),
      (
        label: 'مؤكد',
        done: booking.status == BookingStatus.confirmed ||
            booking.status == BookingStatus.completed,
        current: booking.status == BookingStatus.confirmed,
      ),
      (
        label: 'مكتمل',
        done: booking.status == BookingStatus.completed,
        current: false,
      ),
    ];

    if (booking.status == BookingStatus.cancelled) {
      stages.clear();
      stages.add((label: 'ملغى', done: true, current: true));
    }

    return VibesCard(
      child: Column(
        children: [
          for (var i = 0; i < stages.length; i++)
            IntrinsicHeight(
              child: Row(
                children: [
                  // الخط الرأسي + النقطة
                  SizedBox(
                    width: 30,
                    child: Column(
                      children: [
                        if (i > 0)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: stages[i].done || stages[i].current
                                  ? GoldColors.gold.withValues(alpha: .5)
                                  : VibesTheme.hairlineOf(context),
                            ),
                          ),
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stages[i].done
                                ? GoldColors.gold
                                : stages[i].current
                                    ? GoldColors.goldSoft
                                    : VibesTheme.surfaceHighOf(context),
                            border: stages[i].current
                                ? Border.all(color: GoldColors.gold, width: 1.5)
                                : null,
                          ),
                        ),
                        if (i < stages.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: stages[i].done
                                  ? GoldColors.gold.withValues(alpha: .5)
                                  : VibesTheme.hairlineOf(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        stages[i].label,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: stages[i].done || stages[i].current
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: stages[i].done || stages[i].current
                                      ? VibesTheme.textPrimaryOf(context)
                                      : VibesTheme.textTertiaryOf(context),
                                ),
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.booking,
    required this.uploading,
    required this.onUpload,
  });

  final Booking booking;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final payment = booking.payment!;
    final awaiting = !payment.isPaid && payment.proofUrl == null;

    return VibesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: payment.isPaid
                    ? 'مدفوع'
                    : payment.proofUrl != null
                        ? 'بانتظار المراجعة'
                        : 'بانتظار الدفع',
                color: payment.isPaid
                    ? SemanticColors.success
                    : payment.proofUrl != null
                        ? SemanticColors.info
                        : SemanticColors.warning,
              ),
              const Spacer(),
              Text(
                '${PriceText.format(payment.amount)} د.ع',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: GoldColors.gold,
                    ),
              ),
            ],
          ),

          // إثبات الدفع المرفوع
          if (payment.proofUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(VibesRadius.md),
              child: CachedNetworkImage(
                imageUrl: payment.proofUrl!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيراجع الفريق الإثبات ويؤكد الحجز قريباً',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                  ),
            ),
          ],

          // رفع الإثبات
          if (awaiting) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: VibesButton(
                label: 'رفع إثبات الدفع',
                icon: Icons.upload_file_outlined,
                loading: uploading,
                onPressed: onUpload,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'حوّل المبلغ ثم ارفع صورة الإيصال هنا',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
