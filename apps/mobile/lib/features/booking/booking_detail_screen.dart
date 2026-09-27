import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import '../chat/call_screen.dart';
import '../../shared/data/marketplace_providers.dart';
import 'booking_providers.dart';
import 'review_sheet.dart';

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
      final file = await MultipartFile.fromFile(photo.path, filename: fileName);
      await client.upload(
        '/api/bookings/${booking.id}/payment-proof',
        fieldName: 'file',
        file: file,
      );

      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع إثبات الدفع — بانتظار المراجعة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showMaisonConfirm(
      context: context,
      title: 'إلغاء الحجز',
      message: 'هل أنت متأكد من إلغاء هذا الحجز؟',
      confirmLabel: 'نعم، إلغاء',
      cancelLabel: 'تراجع',
      destructive: true,
    );

    if (confirmed != true) return;
    HapticFeedback.mediumImpact();

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/api/bookings/${booking.id}/cancel');
      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.id));
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
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

  Future<void> _requestCancel(Booking booking) async {
    final expected = _expectedRefund(booking);
    final reason = await showMaisonPrompt(
      context: context,
      title: 'طلب إلغاء واسترداد',
      message: expected > 0
          ? 'الاسترداد المتوقع: ${PriceText.format(expected)} د.ع. كامل قبل 7 أيام، نصف بين 3 و6 أيام.'
          : 'وفق سياسة الإلغاء لا يُسترد مبلغ لهذا الموعد (أقل من 3 أيام).',
      hint: 'سبب الإلغاء (اختياري)',
      confirmLabel: 'إرسال الطلب',
      cancelLabel: 'تراجع',
    );
    if (reason == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/cancellations',
            body: {'bookingId': booking.id, 'reason': reason},
          );
      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الإلغاء للمراجعة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  Future<void> _shareExperience(Booking booking) async {
    final photos = await ImagePicker().pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (!mounted) return;
    final caption = await showMaisonPrompt(
      context: context,
      title: 'انشر تجربتك',
      message: photos.isEmpty
          ? 'أضف وصفاً، ويمكن استخدام صورة المكان إن وُجدت.'
          : 'سيتم إرفاق ${photos.length > 6 ? 6 : photos.length} صور مع تجربتك.',
      hint: 'كيف كانت إقامتك؟',
      confirmLabel: 'نشر',
      cancelLabel: 'لاحقاً',
    );
    if (caption == null) return;
    try {
      final urls = <String>[];
      for (final photo in photos.take(6)) {
        final bytes = await photo.readAsBytes();
        final name = photo.name.isEmpty ? 'experience.jpg' : photo.name;
        final media = await ref
            .read(apiClientProvider)
            .upload(
              '/api/media/upload',
              fieldName: 'file',
              file: MultipartFile.fromBytes(bytes, filename: name),
              fields: {'propertyId': booking.propertyId},
            );
        final url = media is Map<String, dynamic>
            ? media['url'] as String?
            : null;
        if (url != null && url.isNotEmpty) urls.add(url);
      }
      if (urls.isEmpty && booking.coverUrl != null) {
        urls.add(booking.coverUrl!);
      }
      if (caption.isEmpty && urls.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أضف وصفاً أو صورة قبل النشر')),
        );
        return;
      }
      await ref
          .read(apiClientProvider)
          .post(
            '/api/social/posts',
            body: {
              'bookingId': booking.id,
              'caption': caption,
              if (urls.isNotEmpty) 'mediaUrls': urls,
            },
          );
      ref.invalidate(experiencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نُشرت تجربتك في الاستكشاف')),
      );
      context.push('/experiences');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingDetailProvider(widget.id));

    return booking.when(
      loading: () => const Scaffold(
        body: MaisonWash(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              children: [
                ShimmerBox(height: 28, radius: VibesRadius.md),
                SizedBox(height: 16),
                ShimmerBox(height: 140, radius: VibesRadius.xl),
                SizedBox(height: 12),
                ShimmerBox(height: 90, radius: VibesRadius.lg),
                SizedBox(height: 12),
                ShimmerBox(height: 90, radius: VibesRadius.lg),
              ],
            ),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: maisonError(e),
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.id)),
        ),
      ),
      data: (b) => Scaffold(
        body: MaisonWash(
          child: Column(
            children: [
              MaisonPageHeader(
                title: 'تفاصيل الحجز',
                kicker: 'تأكيد المناسبة',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: Vibes.teal,
                  onRefresh: () async =>
                      ref.invalidate(bookingDetailProvider(widget.id)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      VibesCard(
                        onTap: () => context.push('/property/${b.propertyId}'),
                        child: Row(
                          children: [
                            const MaisonIconWell(
                              icon: Icons.home_work_rounded,
                              size: 52,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.propertyName ?? 'مكان',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${b.cityName ?? ''} · ${b.shiftLabelAr}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: VibesTheme.textTertiaryOf(
                                            context,
                                          ),
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
                                value:
                                    '− ${PriceText.format(b.discountAmount)} د.ع',
                                valueColor: SemanticColors.success,
                              ),
                            ],
                            _divider(context),
                            _DetailRow(
                              icon: Icons.payments_outlined,
                              label: 'الإجمالي',
                              value: '${PriceText.format(b.totalPrice)} د.ع',
                              valueColor: Vibes.teal,
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

                      VibesCard(
                        onTap: () => context.push('/booking/${b.id}/invoice'),
                        child: Row(
                          children: [
                            const MaisonIconWell(
                              icon: Icons.receipt_long_outlined,
                              color: Vibes.teal,
                              background: Vibes.tealMint,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الفاتورة الإلكترونية',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    'اعرض التفاصيل المالية وشارك نسخة الحجز',
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
                            Icon(
                              Icons.chevron_left_rounded,
                              color: VibesTheme.textTertiaryOf(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      VibesCard(
                        onTap: () => _openChat(b),
                        child: Row(
                          children: [
                            const MaisonIconWell(
                              icon: Icons.forum_outlined,
                              color: Vibes.coral,
                              background: Vibes.surface,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'محادثة الحجز',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    'راسل المالك حول المواعيد والتفاصيل',
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
                            Icon(
                              Icons.chevron_left_rounded,
                              color: VibesTheme.textTertiaryOf(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: VibesButton(
                          label: 'اتصل',
                          ghost: true,
                          small: true,
                          expanded: false,
                          onPressed: () => startCall(ref, context, bookingId: b.id),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (b.payment != null) ...[
                        const SectionHeader('الدفع'),
                        _PaymentCard(
                          booking: b,
                          uploading: _uploading,
                          onUpload: () => _uploadProof(b),
                        ),
                        const SizedBox(height: 18),
                      ],

                      if (b.status == BookingStatus.completed &&
                          b.canReview) ...[
                        VibesCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كيف كانت تجربتك؟',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'تقييمك يظهر لضيوف آخرين ويساعد المالك على التحسين',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: VibesTheme.textTertiaryOf(context),
                                    ),
                              ),
                              const SizedBox(height: 14),
                              VibesButton(
                                label: 'قيّم هذا المكان',
                                icon: Icons.star_rounded,
                                onPressed: () =>
                                    showReviewSheet(context, ref, b),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      if (b.status == BookingStatus.completed) ...[
                        VibesButton(
                          label: 'انشر تجربتك',
                          ghost: true,
                          icon: Icons.auto_awesome_outlined,
                          onPressed: () => _shareExperience(b),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (b.status == BookingStatus.completed ||
                          b.status == BookingStatus.cancelled) ...[
                        VibesButton(
                          label: 'احجز مرة أخرى',
                          ghost: true,
                          icon: Icons.replay_rounded,
                          onPressed: () =>
                              context.push('/book/${b.propertyId}'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // الإلغاء
                      if (b.status == BookingStatus.pending ||
                          b.status == BookingStatus.awaitingPayment)
                        SizedBox(
                          width: double.infinity,
                          child: VibesButton(
                            label: 'إلغاء الحجز',
                            ghost: true,
                            onPressed: () => _cancel(b),
                          ),
                        ),
                      if (b.status == BookingStatus.confirmed) ...[
                        if (b.cancellationStatus == 'PENDING')
                          Text(
                            'طلب الإلغاء قيد المراجعة',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: VibesButton(
                              label: 'طلب إلغاء واسترداد',
                              ghost: true,
                              onPressed: () => _requestCancel(b),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}';

  int _daysUntil(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(start.year, start.month, start.day);
    return target.difference(today).inDays;
  }

  num _expectedRefund(Booking booking) {
    final days = _daysUntil(booking.startDate);
    final rate = days >= 7
        ? 1.0
        : days >= 3
        ? 0.5
        : 0.0;
    return (booking.totalPrice * rate).round();
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: VibesTheme.hairlineOf(context));
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
          MaisonIconWell(icon: icon, size: 34, color: Vibes.inkTertiary),
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
        done:
            booking.status != BookingStatus.pending &&
            booking.status != BookingStatus.awaitingPayment,
        current: booking.status == BookingStatus.awaitingPayment,
      ),
      (
        label: 'مؤكد',
        done:
            booking.status == BookingStatus.confirmed ||
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
                                  ? Vibes.teal.withValues(alpha: .5)
                                  : VibesTheme.hairlineOf(context),
                            ),
                          ),
                        PetalMark(
                          size: 11,
                          filled: stages[i].done || stages[i].current,
                          color: stages[i].done
                              ? Vibes.teal
                              : stages[i].current
                              ? Vibes.tealBright
                              : Vibes.hairlineStrong,
                        ),
                        if (i < stages.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: stages[i].done
                                  ? Vibes.teal.withValues(alpha: .5)
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({
    required this.booking,
    required this.uploading,
    required this.onUpload,
  });

  final Booking booking;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructions =
        ref.watch(appSettingsProvider).value?.paymentInstructions ?? '';
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
                  color: Vibes.teal,
                ),
              ),
            ],
          ),

          // إثبات الدفع المرفوع
          if (payment.proofUrl != null) ...[
            const SizedBox(height: 14),
            FolioPanel(
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
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                instructions,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.7,
                  color: VibesTheme.textSecondaryOf(context),
                ),
              ),
            ],
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
