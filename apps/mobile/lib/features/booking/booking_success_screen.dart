import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
import '../property/place_experience_ui.dart' show placeFormatDateShort;
import 'booking_providers.dart';

/// ═══════════════════════════════════════════════════════════
/// نجاح الحجز — احتفال بلون عالم المكان المحجوز:
/// سماء العالم، قصاصات ملوّنة، علامة صح تُرسم ذاتياً، وتذكرة
/// حجز أنيقة (المكان، التاريخ، الفترة، الإجمالي) مع خطوة واحدة
/// واضحة للتالي: إكمال الدفع.
/// ═══════════════════════════════════════════════════════════
class BookingSuccessScreen extends ConsumerStatefulWidget {
  const BookingSuccessScreen({super.key, this.bookingId});

  final String? bookingId;

  @override
  ConsumerState<BookingSuccessScreen> createState() =>
      _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends ConsumerState<BookingSuccessScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(myBookingsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.bookingId;
    final booking = id == null
        ? null
        : ref.watch(bookingDetailProvider(id)).valueOrNull;
    final p = booking != null
        ? WorldPalette.forType(booking.propertyType)
        : context.world;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: p.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            WorldAtmosphere(palette: p, night: true, intensity: 1.5),
            const Positioned.fill(
              child: IgnorePointer(
                child: ConfettiBurst(pieces: 56, spread: .9),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                children: [
                  Center(
                    child:
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .08),
                            border: Border.all(
                              color: p.accentLight.withValues(alpha: .6),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: p.glow.withValues(alpha: .5),
                                blurRadius: 60,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: const DrawnCheckmark(size: 64),
                        ).animate().scale(
                          begin: const Offset(.5, .5),
                          curve: Curves.easeOutBack,
                          duration: 800.ms,
                        ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                        'تمّ استلام حجزك 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: .2, end: 0, delay: 300.ms),
                  const SizedBox(height: 8),
                  Text(
                    'خطوة أخيرة: أكمل الدفع ليتأكد حجزك فوراً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .75),
                    ),
                  ).animate().fadeIn(delay: 450.ms),
                  const SizedBox(height: 26),
                  if (booking != null)
                    _Ticket(booking: booking, palette: p)
                        .animate()
                        .fadeIn(delay: 550.ms)
                        .slideY(
                          begin: .12,
                          end: 0,
                          delay: 550.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  const SizedBox(height: 26),
                  _Steps(
                    palette: p,
                    paid: booking?.payment != null,
                  ).animate().fadeIn(delay: 700.ms),
                  const SizedBox(height: 26),
                  if (id != null) ...[
                    WorldButton(
                      label: 'إكمال الدفع والتفاصيل',
                      icon: Icons.lock_outline_rounded,
                      palette: p,
                      onTap: () => context.go('/booking/$id'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: WorldGhostButton(
                            label: 'الفاتورة',
                            icon: Icons.receipt_long_outlined,
                            onDark: true,
                            onTap: () => context.go('/booking/$id/invoice'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: WorldGhostButton(
                            label: 'حجوزاتي',
                            icon: Icons.calendar_month_outlined,
                            onDark: true,
                            onTap: () => context.go('/bookings'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    WorldButton(
                      label: 'حجوزاتي',
                      icon: Icons.calendar_month_outlined,
                      palette: p,
                      onTap: () => context.go('/bookings'),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      'العودة للرئيسية',
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: .6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تذكرة الحجز — بطاقة بيضاء بثقبين جانبيين وخط متقطع.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.booking, required this.palette});

  final Booking booking;
  final WorldPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final cover = booking.coverUrl;
    return ClipPath(
      clipper: const _TicketClipper(notchY: 108),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 108,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: cover == null
                            ? ColoredBox(color: p.accentSoft)
                            : VibesNetImage(url: cover, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.propertyName ?? 'حجزك',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF141C2B),
                            ),
                          ),
                          if ((booking.cityName ?? '').isNotEmpty)
                            Text(
                              booking.cityName!,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5A6678),
                              ),
                            ),
                          const SizedBox(height: 6),
                          WorldStatusChip(
                            label: booking.statusLabelAr,
                            color: p.accentDeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _DashPainter(color: const Color(0xFFE4E9F0)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  _Cell(
                    label: 'التاريخ',
                    value: placeFormatDateShort(booking.startDate),
                  ),
                  _Cell(label: 'الفترة', value: booking.shiftLabelAr),
                  _Cell(
                    label: 'الإجمالي',
                    value: '${formatIqdShort(booking.totalPrice)} د.ع',
                    color: p.accentDeep,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A9099),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color ?? const Color(0xFF141C2B),
            ),
          ),
        ],
      ),
    );
  }
}

/// ما بعد الحجز — ثلاث مراحل واضحة.
class _Steps extends StatelessWidget {
  const _Steps({required this.palette, required this.paid});

  final WorldPalette palette;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final steps = [('تم الطلب', true), ('الدفع', paid), ('التأكيد', false)];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: steps[i].$2
                    ? palette.accentLight
                    : Colors.white.withValues(alpha: .18),
              ),
            ),
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: steps[i].$2
                      ? palette.accentLight
                      : Colors.white.withValues(alpha: .08),
                  border: Border.all(
                    color: steps[i].$2
                        ? palette.accentLight
                        : Colors.white.withValues(alpha: .3),
                  ),
                ),
                child: Center(
                  child: steps[i].$2
                      ? Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: palette.night,
                        )
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[i].$1,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: steps[i].$2 ? .95 : .6),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.notchY});

  final double notchY;

  @override
  Path getClip(Size size) {
    const r = 12.0;
    const corner = 22.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(corner),
        ),
      );
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(size.width, notchY), radius: r));
    return Path.combine(PathOperation.difference, path, notches);
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) =>
      oldClipper.notchY != notchY;
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + 6).clamp(0, size.width), 0),
        paint,
      );
      x += 11;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
