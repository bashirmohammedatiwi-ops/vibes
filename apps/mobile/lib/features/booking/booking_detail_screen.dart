import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/world_ui.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import '../chat/call_screen.dart';
import '../../shared/data/marketplace_providers.dart';
import 'booking_actions.dart';
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

  Future<void> _cancel(Booking booking) =>
      cancelBookingFlow(context, ref, booking);

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

  Future<void> _requestCancel(Booking booking) =>
      requestRefundFlow(context, ref, booking);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingDetailProvider(widget.id));

    return booking.when(
      loading: () => Scaffold(
        backgroundColor: context.world.canvas,
        body: const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              SizedBox(height: 60),
              WorldSkeleton(height: 220, radius: 28),
              SizedBox(height: 16),
              WorldSkeleton(height: 110, radius: 24),
              SizedBox(height: 12),
              WorldSkeleton(height: 160, radius: 24),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: maisonError(e),
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.id)),
        ),
      ),
      data: (b) {
        final palette = WorldPalette.forType(b.propertyType);
        return AnimatedTheme(
          data: applyWorld(Theme.of(context), palette),
          child: Builder(builder: (context) => _page(context, b, palette)),
        );
      },
    );
  }

  Widget _page(BuildContext context, Booking b, WorldPalette p) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final status = _statusLook(b);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: p.canvas,
        body: RefreshIndicator(
          color: p.accent,
          edgeOffset: top,
          onRefresh: () async =>
              ref.invalidate(bookingDetailProvider(widget.id)),
          child: ListView(
            padding: EdgeInsets.only(bottom: 32 + bottom),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              // ── الغلاف ──
              SizedBox(
                height: 268 + top,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if ((b.coverUrl ?? '').isNotEmpty)
                      VibesNetImage(url: b.coverUrl!, fit: BoxFit.cover)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: p.nightfall),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, .3, 1],
                          colors: [
                            Colors.black.withValues(alpha: .45),
                            Colors.transparent,
                            p.night.withValues(alpha: .92),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: top + 8,
                      start: 16,
                      end: 16,
                      child: Row(
                        children: [
                          _GlassButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/bookings'),
                          ),
                          const Spacer(),
                          _StatusBadge(look: status),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      start: 20,
                      end: 20,
                      bottom: 44,
                      child: GestureDetector(
                        onTap: () => context.push('/property/${b.propertyId}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.propertyName ?? 'حجزك',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 15,
                                  color: p.accentLight,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  b.cityName ?? 'العراق',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: .85),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'عرض المكان',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: p.accentLight,
                                    decoration: TextDecoration.underline,
                                    decorationColor: p.accentLight.withValues(
                                      alpha: .5,
                                    ),
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

              // ── التذكرة: التاريخ والفترة والرمز ──
              Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _TicketCard(
                    booking: b,
                    palette: p,
                    daysUntil: _daysUntil(b.startDate),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── مراحل الحجز ──
                    _Stepper(booking: b, palette: p),
                    const SizedBox(height: 14),

                    // ── الخطوة التالية ──
                    if (b.payment != null && !b.payment!.isPaid) ...[
                      _PaymentCard(
                        booking: b,
                        uploading: _uploading,
                        onUpload: () => _uploadProof(b),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (b.status == BookingStatus.completed && b.canReview) ...[
                      _NextActionCard(
                        palette: p,
                        icon: Icons.star_rounded,
                        title: 'كيف كانت تجربتك؟',
                        body:
                            'تقييمك يساعد ضيوفاً آخرين ويشجّع المضيف على التميّز',
                        action: 'قيّم المكان',
                        onTap: () => showReviewSheet(context, ref, b),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── التفاصيل ──
                    _Section(
                      title: 'تفاصيل الحجز',
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.event_rounded,
                            label: 'الوصول',
                            value: _longDate(b.startDate),
                          ),
                          _InfoRow(
                            icon: Icons.event_available_rounded,
                            label: 'المغادرة',
                            value: _longDate(
                              b.endDate.subtract(const Duration(days: 1)),
                            ),
                          ),
                          _InfoRow(
                            icon: Icons.schedule_rounded,
                            label: 'الفترة',
                            value: b.shiftLabelAr,
                          ),
                          _InfoRow(
                            icon: Icons.groups_rounded,
                            label: 'الضيوف',
                            value: b.guests == 1
                                ? 'ضيف واحد'
                                : '${b.guests} ضيف',
                          ),
                          if (b.notes?.isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.sticky_note_2_outlined,
                              label: 'ملاحظاتك',
                              value: b.notes!,
                              last: true,
                            )
                          else
                            _InfoRow(
                              icon: Icons.nights_stay_outlined,
                              label: 'المدة',
                              value: b.nights == 1
                                  ? 'ليلة واحدة'
                                  : '${b.nights} ليالٍ',
                              last: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── المبلغ ──
                    _Section(
                      title: 'المبلغ',
                      trailing: GestureDetector(
                        onTap: () => context.push('/booking/${b.id}/invoice'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 16,
                              color: p.accentDeep,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'الفاتورة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: p.accentDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          if (b.discountAmount > 0) ...[
                            _MoneyRow(
                              label: 'السعر الأصلي',
                              value: b.totalPrice + b.discountAmount,
                              muted: true,
                            ),
                            _MoneyRow(
                              label: 'الخصم',
                              value: -b.discountAmount,
                              color: const Color(0xFF0E9F6E),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                height: 1,
                                color: p.accent.withValues(alpha: .12),
                              ),
                            ),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Expanded(
                                child: Text(
                                  'الإجمالي',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Vibes.inkSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                formatIqdShort(b.totalPrice),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Vibes.ink,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'د.ع',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.accentDeep,
                                ),
                              ),
                            ],
                          ),
                          if (b.payment?.isPaid == true) ...[
                            const SizedBox(height: 10),
                            const _Note(
                              icon: Icons.verified_rounded,
                              color: Color(0xFF0E9F6E),
                              text: 'تم استلام الدفع — حجزك مضمون',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── التواصل ──
                    _Section(
                      title: 'تواصل مع المضيف',
                      child: Row(
                        children: [
                          Expanded(
                            child: WorldButton(
                              label: 'محادثة',
                              icon: Icons.chat_bubble_rounded,
                              height: 50,
                              onTap: () => _openChat(b),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: WorldGhostButton(
                              label: 'اتصال',
                              icon: Icons.call_rounded,
                              height: 50,
                              onTap: () =>
                                  startCall(ref, context, bookingId: b.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── إجراءات ثانوية ──
                    if (b.status == BookingStatus.completed)
                      _ActionTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'انشر تجربتك',
                        subtitle: 'شارك صورك مع مجتمع VIBES',
                        onTap: () => _shareExperience(b),
                      ),
                    if (b.status == BookingStatus.completed ||
                        b.status == BookingStatus.cancelled)
                      _ActionTile(
                        icon: Icons.replay_rounded,
                        title: 'احجز مرة أخرى',
                        subtitle: 'نفس المكان بموعد جديد',
                        onTap: () => context.push('/book/${b.propertyId}'),
                      ),
                    _ActionTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'الفاتورة الإلكترونية',
                      subtitle: 'التفاصيل المالية ونسخة للمشاركة',
                      onTap: () => context.push('/booking/${b.id}/invoice'),
                    ),
                    if (b.payment?.isPaid == true ||
                        b.payment?.proofUrl != null) ...[
                      const SizedBox(height: 4),
                      _PaymentCard(
                        booking: b,
                        uploading: _uploading,
                        onUpload: () => _uploadProof(b),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // ── الإلغاء ──
                    if (canCancelDirectly(b))
                      _CancelButton(
                        label: 'إلغاء الحجز',
                        onTap: () => _cancel(b),
                      )
                    else if (refundRequestPending(b))
                      const _Note(
                        icon: Icons.hourglass_top_rounded,
                        color: Color(0xFFB45309),
                        text:
                            'طلب الإلغاء والاسترداد قيد المراجعة — سنبلغك بالنتيجة',
                      )
                    else if (canRequestRefund(b))
                      _CancelButton(
                        label: 'طلب إلغاء واسترداد المبلغ',
                        onTap: () => _requestCancel(b),
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

  static const _months = [
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
  static const _weekdays = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  String _longDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  int _daysUntil(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(start.year, start.month, start.day);
    return target.difference(today).inDays;
  }
}

// ═══════════════════════════════════════════════════════════
// مكوّنات الصفحة
// ═══════════════════════════════════════════════════════════

typedef _Look = ({String label, Color color, IconData icon});

_Look _statusLook(Booking b) => switch (b.status) {
  BookingStatus.pending => (
    label: 'بانتظار المضيف',
    color: const Color(0xFFB45309),
    icon: Icons.hourglass_top_rounded,
  ),
  BookingStatus.awaitingPayment => (
    label: 'بانتظار الدفع',
    color: const Color(0xFFD97706),
    icon: Icons.payments_rounded,
  ),
  BookingStatus.confirmed => (
    label: 'مؤكد',
    color: const Color(0xFF0E9F6E),
    icon: Icons.verified_rounded,
  ),
  BookingStatus.completed => (
    label: 'مكتمل',
    color: const Color(0xFF2563EB),
    icon: Icons.task_alt_rounded,
  ),
  BookingStatus.cancelled => (
    label: 'ملغى',
    color: const Color(0xFFDC2626),
    icon: Icons.cancel_rounded,
  ),
  BookingStatus.disputed => (
    label: 'قيد النزاع',
    color: const Color(0xFF7C3AED),
    icon: Icons.gavel_rounded,
  ),
};

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: .3),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.look});

  final _Look look;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(look.icon, size: 15, color: look.color),
          const SizedBox(width: 5),
          Text(
            look.label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: look.color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// التذكرة — كتلة تاريخ كبيرة، العدّ التنازلي، الفترة، ورمز الحجز.
class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.booking,
    required this.palette,
    required this.daysUntil,
  });

  final Booking booking;
  final WorldPalette palette;
  final int daysUntil;

  static const _months = [
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

  String get _countdown {
    final s = booking.status;
    if (s == BookingStatus.cancelled) return 'تم إلغاء هذا الحجز';
    if (s == BookingStatus.completed)
      return 'انتهت مناسبتك — نتمنى أنها كانت رائعة';
    if (daysUntil < 0) return 'مناسبتك جارية الآن';
    if (daysUntil == 0) return 'موعدك اليوم!';
    if (daysUntil == 1) return 'موعدك غداً';
    if (daysUntil == 2) return 'بعد يومين';
    if (daysUntil <= 10) return 'بعد $daysUntil أيام';
    return 'بعد $daysUntil يوماً';
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final d = booking.startDate;
    final code = (booking.invoiceNumber ?? booking.id.split('-').first)
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: p.fill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: p.onAccent,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      _months[d.month - 1],
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.onAccent.withValues(alpha: .85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _countdown,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          icon: Icons.schedule_rounded,
                          text: booking.shiftLabelAr,
                          palette: p,
                        ),
                        _Chip(
                          icon: Icons.nights_stay_outlined,
                          text: booking.nights == 1
                              ? 'ليلة'
                              : '${booking.nights} ليالٍ',
                          palette: p,
                        ),
                        _Chip(
                          icon: Icons.groups_rounded,
                          text: '${booking.guests}',
                          palette: p,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // خط القطع المتقطع
          Row(
            children: List.generate(
              34,
              (i) => Expanded(
                child: Container(
                  height: 1.4,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  color: i.isEven
                      ? p.accent.withValues(alpha: .22)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'رمز الحجز',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Vibes.inkTertiary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نُسخ رمز الحجز'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Vibes.ink,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 16, color: p.accentDeep),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.palette});

  final IconData icon;
  final String text;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.accentFaint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.accentDeep),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: palette.accentDeep,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// مراحل الحجز أفقياً — دوائر متصلة، والمرحلة الحالية بتدرّج العالم.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.booking, required this.palette});

  final Booking booking;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    final s = booking.status;
    if (s == BookingStatus.cancelled || s == BookingStatus.disputed) {
      final look = _statusLook(booking);
      return _Note(
        icon: look.icon,
        color: look.color,
        text: s == BookingStatus.cancelled
            ? 'هذا الحجز ملغى'
            : 'الحجز قيد مراجعة نزاع — سيتواصل معك فريق الدعم',
      );
    }
    final current = switch (s) {
      BookingStatus.pending => 0,
      BookingStatus.awaitingPayment => 1,
      BookingStatus.confirmed => 2,
      _ => 3,
    };
    const labels = ['الطلب', 'الدفع', 'التأكيد', 'المناسبة'];
    const icons = [
      Icons.send_rounded,
      Icons.payments_rounded,
      Icons.verified_rounded,
      Icons.celebration_rounded,
    ];
    final p = palette;
    final hint = switch (s) {
      BookingStatus.pending => 'أُرسل طلبك — ينتظر موافقة المضيف',
      BookingStatus.awaitingPayment => 'وافق المضيف! أكمل الدفع لتأكيد موعدك',
      BookingStatus.confirmed => 'حجزك مؤكد — كل شيء جاهز لمناسبتك',
      _ => 'اكتملت مناسبتك — شكراً لاختيارك VIBES',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.accent.withValues(alpha: .10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: i == current ? 40 : 34,
                        height: i == current ? 40 : 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: i <= current ? p.fill : null,
                          color: i <= current ? null : const Color(0xFFF2F3F5),
                          boxShadow: i == current
                              ? [
                                  BoxShadow(
                                    color: p.glow.withValues(alpha: .4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          i < current ? Icons.check_rounded : icons[i],
                          size: i == current ? 19 : 16,
                          color: i <= current ? p.onAccent : Vibes.inkTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: i == current
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: i <= current ? Vibes.ink : Vibes.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 3)
                  Expanded(
                    flex: 0,
                    child: Container(
                      width: 18,
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                        color: i < current ? p.accent : const Color(0xFFE6E8EB),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: p.accentFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: p.accentDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.accent.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Vibes.ink,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: p.accent.withValues(alpha: .08)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: p.accentFaint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: p.accentDeep),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Vibes.inkTertiary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Vibes.ink,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.color,
    this.muted = false,
  });

  final String label;
  final num value;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final neg = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Vibes.inkSecondary,
              ),
            ),
          ),
          Text(
            '${neg ? '− ' : ''}${formatIqdShort(value.abs())} د.ع',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color ?? (muted ? Vibes.inkTertiary : Vibes.ink),
              decoration: muted ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final WorldPalette palette;
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: p.nightfall,
        borderRadius: BorderRadius.circular(24),
        boxShadow: p.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: p.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: p.onAccent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      body,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: .75),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WorldButton(
            label: action,
            icon: icon,
            height: 48,
            palette: p,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.accent.withValues(alpha: .10)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.accentFaint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 21, color: p.accentDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Vibes.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: p.accentDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
        icon: const Icon(Icons.close_rounded, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// بطاقة الدفع — الحالة والمبلغ، تعليمات التحويل، ورفع الإيصال أو معاينته.
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
    final p = context.world;
    final instructions =
        ref.watch(appSettingsProvider).value?.paymentInstructions ?? '';
    final payment = booking.payment!;
    final awaiting = !payment.isPaid && payment.proofUrl == null;
    final (label, color) = payment.isPaid
        ? ('مدفوع', const Color(0xFF0E9F6E))
        : payment.proofUrl != null
        ? ('الإيصال قيد المراجعة', const Color(0xFF2563EB))
        : ('بانتظار الدفع', const Color(0xFFD97706));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: awaiting
              ? const Color(0xFFD97706).withValues(alpha: .35)
              : p.accent.withValues(alpha: .10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
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
              const Text(
                'الدفع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
              const SizedBox(width: 8),
              WorldStatusChip(label: label, color: color),
              const Spacer(),
              Text(
                '${formatIqdShort(payment.amount)} د.ع',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
            ],
          ),
          if (payment.proofUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VibesNetImage(url: payment.proofUrl!, height: 170),
            ),
            if (!payment.isPaid) ...[
              const SizedBox(height: 10),
              const _Note(
                icon: Icons.schedule_rounded,
                color: Color(0xFF2563EB),
                text: 'سيراجع الفريق الإيصال ويؤكد حجزك قريباً',
              ),
            ],
          ],
          if (awaiting) ...[
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  instructions,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Vibes.inkSecondary,
                    height: 1.7,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            WorldButton(
              label: 'رفع إيصال الدفع',
              icon: Icons.upload_rounded,
              loading: uploading,
              onTap: onUpload,
            ),
            const SizedBox(height: 8),
            const Text(
              'حوّل المبلغ ثم ارفع صورة الإيصال هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Vibes.inkTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
