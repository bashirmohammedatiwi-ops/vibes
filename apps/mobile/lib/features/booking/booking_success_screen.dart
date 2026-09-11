import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// نجاح الحجز — انبعاث ذهبي هادئ ثم عودة للحجوزات
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VibesTheme.canvasOf(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              // الدائرة الذهبية المتوهجة
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: GoldColors.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: GoldColors.gold.withValues(alpha: .4),
                      blurRadius: 50,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: GoldColors.onGold,
                  size: 60,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: .97, end: 1.02, duration: 1600.ms)
                  .fadeIn(),
              const SizedBox(height: 32),
              Text(
                'تم استلام حجزك',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 10),
              Text(
                'سيتواصل معك فريق VIBES أو المالك لتأكيد الحجز وتفاصيل الدفع',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VibesTheme.textSecondaryOf(context),
                      height: 1.8,
                    ),
              ).animate().fadeIn(delay: 400.ms),
              const Spacer(),
              VibesButton(
                label: 'حجوزاتي',
                icon: Icons.calendar_month_rounded,
                onPressed: () => context.go('/bookings'),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: .1, end: 0),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('العودة للرئيسية'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
