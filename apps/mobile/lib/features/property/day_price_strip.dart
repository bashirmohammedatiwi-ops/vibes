import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// شريط أسعار الأيام — تمرير أفقي بسعر كل يوم
/// الأيام بأحكام قواعد تظهر بحد ذهبي
/// ═══════════════════════════════════════════════════════════

class DayPriceStrip extends StatelessWidget {
  const DayPriceStrip({super.key, required this.days, this.selectedShift});

  final List<DayPricing> days;
  final ShiftType? selectedShift;

  static const _weekdayLabels = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

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
          final day = days[i];
          final shift = selectedShift ?? ShiftType.full;
          final price = day.priceFor(shift);

          final disabled = day.isPast || day.isBlocked || day.isBooked;
          final weekend = day.date.weekday == DateTime.friday ||
              day.date.weekday == DateTime.saturday;

          return Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: VibesTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(VibesRadius.md),
              border: Border.all(
                color: disabled
                    ? VibesTheme.hairlineOf(context)
                    : weekend
                        ? GoldColors.gold.withValues(alpha: .45)
                        : VibesTheme.hairlineOf(context),
              ),
            ),
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
                    '${PriceText.format(price)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: disabled
                              ? VibesTheme.textTertiaryOf(context)
                              : GoldColors.gold,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
