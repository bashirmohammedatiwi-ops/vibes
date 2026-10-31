import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// شريط أسعار الأيام — تمرير أفقي بسعر كل يوم
/// الأيام بأحكام قواعد تظهر بحد ذهبي
/// ═══════════════════════════════════════════════════════════

class DayPriceStrip extends StatelessWidget {
  const DayPriceStrip({super.key, required this.days, this.selectedShift});

  final List<DayPricing> days;
  final ShiftType? selectedShift;

  static List<String> get _weekdayLabels => [
    'أحد'.tr,
    'إثن'.tr,
    'ثلا'.tr,
    'أرب'.tr,
    'خمي'.tr,
    'جمع'.tr,
    'سبت'.tr,
  ];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final accent = context.world.accent;
          final day = days[i];
          final shift = selectedShift ?? ShiftType.full;
          final price = day.priceFor(shift);

          final disabled = day.isPast || day.isBlocked || day.isBooked;
          final weekend =
              day.date.weekday == DateTime.friday ||
              day.date.weekday == DateTime.saturday;

          final cell = FolioPanel(
            radius: Folio.compact,
            color: disabled
                ? VibesTheme.surfaceOf(context)
                : weekend
                ? context.world.accentFaint
                : VibesTheme.surfaceOf(context),
            borderColor: disabled
                ? VibesTheme.hairlineOf(context)
                : accent.withValues(alpha: weekend ? .5 : .35),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Opacity(
                opacity: disabled ? .45 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdayLabels[day.date.weekday % 7],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VibesTheme.textTertiaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.date.day}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VibesTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PriceText.format(price),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: disabled
                            ? VibesTheme.textTertiaryOf(context)
                            : accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
          if (i < 8 && !reduce) {
            return cell
                .animate(delay: Duration(milliseconds: 60 * i))
                .fadeIn(duration: VibesMotion.slow)
                .slideX(
                  begin: I18n.isEn ? -.08 : .08,
                  end: 0,
                  duration: VibesMotion.slow,
                  curve: VibesMotion.curve,
                );
          }
          return cell;
        },
      ),
    );
  }
}
