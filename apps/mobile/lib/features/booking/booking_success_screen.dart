import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, this.bookingId});

  final String? bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VibesDark.canvas, Vibes.coral],
          ),
        ),
        child: Stack(
          children: [
            const PositionedDirectional(
              top: 76,
              end: 22,
              child: IgnorePointer(
                child: Opacity(
                  opacity: .16,
                  child: CrestSeal(size: 132, color: Vibes.tealBright),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 3, child: ColoredBox(color: Vibes.teal)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),
                    FolioPanel(
                      color: Vibes.canvas,
                      borderColor: Vibes.teal.withValues(alpha: .45),
                      railColor: Vibes.teal,
                      shadows: const [
                        BoxShadow(
                          color: Color(0x551B3857),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          children: [
                            const VibesLogo.mark(size: 72)
                                .animate()
                                .fadeIn()
                                .scaleXY(begin: .92, end: 1, duration: 700.ms),
                            const SizedBox(height: 22),
                            const ArcFlourish(width: 48),
                            const SizedBox(height: 14),
                            Text(
                              'تمّ استلام طلبكم',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Vibes.ink,
                                  ),
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 12),
                            Text(
                              'أكمل الدفع من تفاصيل الحجز ليتم تأكيده بسرعة',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Vibes.inkSecondary,
                                    height: 1.8,
                                  ),
                            ).animate().fadeIn(delay: 400.ms),
                            const SizedBox(height: 28),
                            if (bookingId != null)
                              VibesButton(
                                label: 'تفاصيل الحجز والدفع',
                                icon: Icons.receipt_long_rounded,
                                onPressed: () =>
                                    context.go('/booking/$bookingId'),
                              ).animate().fadeIn(delay: 500.ms),
                            if (bookingId != null) const SizedBox(height: 12),
                            if (bookingId != null)
                              TextButton(
                                onPressed: () =>
                                    context.go('/booking/$bookingId/invoice'),
                                child: Text(
                                  'عرض الفاتورة',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Vibes.coral,
                                      ),
                                ),
                              ).animate().fadeIn(delay: 560.ms),
                            if (bookingId != null) const SizedBox(height: 8),
                            VibesButton(
                              label: 'حجوزاتي',
                              icon: Icons.calendar_month_rounded,
                              ghost: true,
                              onPressed: () => context.go('/bookings'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
