import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
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
        SnackBar(content: Text('تم رفع إثبات الدفع — بانتظار المراجعة'.tr)),
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
      title: 'انشر تجربتك'.tr,
      message: photos.isEmpty
          ? 'أضف وصفاً، ويمكن استخدام صورة المكان إن وُجدت.'.tr
          : 'سيتم إرفاق {n} صور مع تجربتك.'.trN(
              photos.length > 6 ? 6 : photos.length,
            ),
      hint: 'كيف كانت إقامتك؟'.tr,
      confirmLabel: 'نشر'.tr,
      cancelLabel: 'لاحقاً'.tr,
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
          SnackBar(content: Text('أضف وصفاً أو صورة قبل النشر'.tr)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('نُشرت تجربتك في الاستكشاف'.tr)));
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
                              b.propertyName ?? 'حجزك'.tr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
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
                                Flexible(
                                  child: Text(
                                    b.cityName ?? 'العراق'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: VibesFont.ui,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(
                                        alpha: .85,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'عرض المكان'.tr,
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
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
                        title: 'كيف كانت تجربتك؟'.tr,
                        body:
                            'تقييمك يساعد ضيوفاً آخرين ويشجّع المضيف على التميّز' // i18n-ok
                                .tr,
                        action: 'قيّم المكان'.tr,
                        onTap: () => showReviewSheet(context, ref, b),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── التفاصيل ──
                    _Section(
                      title: 'تفاصيل الحجز'.tr,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.event_rounded,
                            label: 'الوصول'.tr,
                            value: _longDate(b.startDate),
                          ),
                          _InfoRow(
                            icon: Icons.event_available_rounded,
                            label: 'المغادرة'.tr,
                            value: _longDate(
                              b.endDate.subtract(const Duration(days: 1)),
                            ),
                          ),
                          _InfoRow(
                            icon: Icons.schedule_rounded,
                            label: 'الفترة'.tr,
                            value: b.shiftLabelAr.tr,
                          ),
                          _InfoRow(
                            icon: Icons.groups_rounded,
                            label: 'الضيوف'.tr,
                            value: b.guests == 1
                                ? 'ضيف واحد'.tr
                                : '{n} ضيف'.trN(b.guests),
                          ),
                          if (b.notes?.isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.sticky_note_2_outlined,
                              label: 'ملاحظاتك'.tr,
                              value: b.notes!,
                              last: true,
                            )
                          else
                            _InfoRow(
                              icon: Icons.nights_stay_outlined,
                              label: 'المدة'.tr,
                              value: b.nights == 1
                                  ? 'ليلة واحدة'.tr
                                  : '{n} ليالٍ'.trN(b.nights),
                              last: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── المبلغ ──
                    _Section(
                      title: 'المبلغ'.tr,
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
                              'الفاتورة'.tr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
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
                              label: 'السعر الأصلي'.tr,
                              value: b.totalPrice + b.discountAmount,
                              muted: true,
                            ),
                            _MoneyRow(
                              label: 'الخصم'.tr,
                              value: -b.discountAmount,
                              color: _ok,
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
                              Expanded(
                                child: Text(
                                  'الإجمالي'.tr,
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Vibes.inkSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                formatIqdShort(b.totalPrice),
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Vibes.ink,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'د.ع'.tr,
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.accentDeep,
                                ),
                              ),
                            ],
                          ),
                          if (b.payment?.isPaid == true) ...[
                            const SizedBox(height: 10),
                            _Note(
                              icon: Icons.verified_rounded,
                              color: _ok,
                              text: 'تم استلام الدفع — حجزك مضمون'.tr,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── التواصل ──
                    _Section(
                      title: 'تواصل مع المضيف'.tr,
                      child: Row(
                        children: [
                          Expanded(
                            child: WorldButton(
                              label: 'محادثة'.tr,
                              icon: Icons.chat_bubble_rounded,
                              height: 50,
                              onTap: () => _openChat(b),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: WorldGhostButton(
                              label: 'اتصال'.tr,
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
                        title: 'انشر تجربتك'.tr,
                        subtitle: 'شارك صورك مع مجتمع أجواء'.tr,
                        onTap: () => _shareExperience(b),
                      ),
                    if (b.status == BookingStatus.completed ||
                        b.status == BookingStatus.cancelled)
                      _ActionTile(
                        icon: Icons.replay_rounded,
                        title: 'احجز مرة أخرى'.tr,
                        subtitle: 'نفس المكان بموعد جديد'.tr,
                        onTap: () => context.push('/book/${b.propertyId}'),
                      ),
                    _ActionTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'الفاتورة الإلكترونية'.tr,
                      subtitle: 'التفاصيل المالية ونسخة للمشاركة'.tr,
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
                        label: 'إلغاء الحجز'.tr,
                        onTap: () => _cancel(b),
                      )
                    else if (refundRequestPending(b))
                      _Note(
                        icon: Icons.hourglass_top_rounded,
                        color: _amberDeep,
                        text:
                            'طلب الإلغاء والاسترداد قيد المراجعة — سنبلغك بالنتيجة' // i18n-ok
                                .tr,
                      )
                    else if (canRequestRefund(b))
                      _CancelButton(
                        label: 'طلب إلغاء واسترداد المبلغ'.tr,
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
    'يناير', // i18n-ok
    'فبراير', // i18n-ok
    'مارس', // i18n-ok
    'أبريل', // i18n-ok
    'مايو', // i18n-ok
    'يونيو', // i18n-ok
    'يوليو', // i18n-ok
    'أغسطس', // i18n-ok
    'سبتمبر', // i18n-ok
    'أكتوبر', // i18n-ok
    'نوفمبر', // i18n-ok
    'ديسمبر', // i18n-ok
  ];
  static const _weekdays = [
    'الإثنين', // i18n-ok
    'الثلاثاء', // i18n-ok
    'الأربعاء', // i18n-ok
    'الخميس', // i18n-ok
    'الجمعة', // i18n-ok
    'السبت', // i18n-ok
    'الأحد', // i18n-ok
  ];

  String _longDate(DateTime d) {
    final weekday = _weekdays[d.weekday - 1].tr;
    final month = _months[d.month - 1].tr;
    if (I18n.isEn) return '${_short(weekday)}, ${_short(month)} ${d.day}';
    return '$weekday ${d.day} $month';
  }

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

Color get _ok => themed(const Color(0xFF0E9F6E), VibesDark.success);
Color get _amberDeep => themed(const Color(0xFFB45309), VibesDark.warning);
Color get _amber => themed(const Color(0xFFD97706), VibesDark.warning);
Color get _blue => themed(const Color(0xFF2563EB), VibesDark.info);
Color get _red => themed(const Color(0xFFDC2626), VibesDark.danger);
Color get _violet => themed(const Color(0xFF7C3AED), const Color(0xFFBBA6F6));

String _short(String s) => s.length > 3 ? s.substring(0, 3) : s;

typedef _Look = ({String label, Color color, IconData icon});

_Look _statusLook(Booking b) => switch (b.status) {
  BookingStatus.pending => (
    label: 'بانتظار المضيف'.tr,
    color: _amberDeep,
    icon: Icons.hourglass_top_rounded,
  ),
  BookingStatus.awaitingPayment => (
    label: 'بانتظار الدفع'.tr,
    color: _amber,
    icon: Icons.payments_rounded,
  ),
  BookingStatus.confirmed => (
    label: 'مؤكد'.tr,
    color: _ok,
    icon: Icons.verified_rounded,
  ),
  BookingStatus.completed => (
    label: 'مكتمل'.tr,
    color: _blue,
    icon: Icons.task_alt_rounded,
  ),
  BookingStatus.cancelled => (
    label: 'ملغى'.tr,
    color: _red,
    icon: Icons.cancel_rounded,
  ),
  BookingStatus.disputed => (
    label: 'قيد النزاع'.tr,
    color: _violet,
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
        color: Vibes.surface,
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
              fontFamily: VibesFont.ui,
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
    'يناير', // i18n-ok
    'فبراير', // i18n-ok
    'مارس', // i18n-ok
    'أبريل', // i18n-ok
    'مايو', // i18n-ok
    'يونيو', // i18n-ok
    'يوليو', // i18n-ok
    'أغسطس', // i18n-ok
    'سبتمبر', // i18n-ok
    'أكتوبر', // i18n-ok
    'نوفمبر', // i18n-ok
    'ديسمبر', // i18n-ok
  ];

  String get _countdown {
    final s = booking.status;
    if (s == BookingStatus.cancelled) return 'تم إلغاء هذا الحجز'.tr;
    if (s == BookingStatus.completed)
      return 'انتهت مناسبتك — نتمنى أنها كانت رائعة'.tr;
    if (daysUntil < 0) return 'مناسبتك جارية الآن'.tr;
    if (daysUntil == 0) return 'موعدك اليوم!'.tr;
    if (daysUntil == 1) return 'موعدك غداً'.tr;
    if (daysUntil == 2) return 'بعد يومين'.tr;
    if (daysUntil <= 10) return 'بعد {n} أيام'.trN(daysUntil);
    return 'بعد {n} يوماً'.trN(daysUntil);
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
        color: Vibes.surface,
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
                      I18n.isEn
                          ? _short(_months[d.month - 1].tr)
                          : _months[d.month - 1],
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
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
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
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
                          text: booking.shiftLabelAr.tr,
                          palette: p,
                        ),
                        _Chip(
                          icon: Icons.nights_stay_outlined,
                          text: booking.nights == 1
                              ? 'ليلة'.tr
                              : '{n} ليالٍ'.trN(booking.nights),
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
              Text(
                'رمز الحجز'.tr,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
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
                    SnackBar(
                      content: Text('نُسخ رمز الحجز'.tr),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      code,
                      style: TextStyle(
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
              fontFamily: VibesFont.ui,
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
            ? 'هذا الحجز ملغى'.tr
            : 'الحجز قيد مراجعة نزاع — سيتواصل معك فريق الدعم'.tr,
      );
    }
    final current = switch (s) {
      BookingStatus.pending => 0,
      BookingStatus.awaitingPayment => 1,
      BookingStatus.confirmed => 2,
      _ => 3,
    };
    final labels = ['الطلب'.tr, 'الدفع'.tr, 'التأكيد'.tr, 'المناسبة'.tr];
    const icons = [
      Icons.send_rounded,
      Icons.payments_rounded,
      Icons.verified_rounded,
      Icons.celebration_rounded,
    ];
    final p = palette;
    final hint = switch (s) {
      BookingStatus.pending => 'أُرسل طلبك — ينتظر موافقة المضيف'.tr,
      BookingStatus.awaitingPayment =>
        'وافق المضيف! أكمل الدفع لتأكيد موعدك'.tr,
      BookingStatus.confirmed => 'حجزك مؤكد — كل شيء جاهز لمناسبتك'.tr,
      _ => 'اكتملت مناسبتك — شكراً لاختيارك أجواء'.tr,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Vibes.surface,
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
                          color: i <= current
                              ? null
                              : themed(
                                  const Color(0xFFF2F3F5),
                                  VibesDark.surfaceMuted,
                                ),
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
                          fontFamily: VibesFont.ui,
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
                        color: i < current
                            ? p.accent
                            : themed(
                                const Color(0xFFE6E8EB),
                                VibesDark.hairline,
                              ),
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
                fontFamily: VibesFont.ui,
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
        color: Vibes.surface,
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
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
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
              style: TextStyle(
                fontFamily: VibesFont.ui,
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
                style: TextStyle(
                  fontFamily: VibesFont.ui,
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
    final formatted = '{amount} د.ع'.trArgs({
      'amount': formatIqdShort(value.abs()),
    });
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Vibes.inkSecondary,
              ),
            ),
          ),
          Text(
            '${neg ? '− ' : ''}$formatted',
            style: TextStyle(
              fontFamily: VibesFont.ui,
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
        color: color.withValues(alpha: Appearance.isDark ? .14 : .09),
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
                fontFamily: VibesFont.ui,
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
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      body,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
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
            color: Vibes.surface,
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
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Vibes.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // الأيقونة تنعكس تلقائياً؛ العربية تبقى كما هي والإنجليزية تشير للأمام.
              Icon(
                I18n.isEn
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: p.accentDeep,
              ),
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
        style: TextButton.styleFrom(foregroundColor: _red),
        icon: const Icon(Icons.close_rounded, size: 18),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
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
        ? ('مدفوع'.tr, _ok)
        : payment.proofUrl != null
        ? ('الإيصال قيد المراجعة'.tr, _blue)
        : ('بانتظار الدفع'.tr, _amber);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: awaiting
              ? _amber.withValues(alpha: .35)
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
              Text(
                'الدفع'.tr,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
              if (!I18n.isEn) ...[
                const SizedBox(width: 8),
                WorldStatusChip(label: label, color: color),
              ],
              const Spacer(),
              Text(
                '{amount} د.ع'.trArgs({
                  'amount': formatIqdShort(payment.amount),
                }),
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
            ],
          ),
          // الإنجليزية أعرض: الحالة في سطرها كي لا يضيق الصف.
          if (I18n.isEn) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: WorldStatusChip(label: label, color: color),
            ),
          ],
          if (payment.proofUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VibesNetImage(url: payment.proofUrl!, height: 170),
            ),
            if (!payment.isPaid) ...[
              const SizedBox(height: 10),
              _Note(
                icon: Icons.schedule_rounded,
                color: _blue,
                text: 'سيراجع الفريق الإيصال ويؤكد حجزك قريباً'.tr,
              ),
            ],
          ],
          if (awaiting) ...[
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themed(
                    const Color(0xFFF6F7F9),
                    VibesDark.surfaceMuted,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  instructions,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
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
              label: 'رفع إيصال الدفع'.tr,
              icon: Icons.upload_rounded,
              loading: uploading,
              onTap: onUpload,
            ),
            const SizedBox(height: 8),
            Text(
              'حوّل المبلغ ثم ارفع صورة الإيصال هنا'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VibesFont.ui,
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
