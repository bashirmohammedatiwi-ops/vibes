import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';

/// ═══════════════════════════════════════════════════════════
/// تقويم التوفر الشهري — متاح/محجوز/مغلق بأسعار يومية ملونة
/// ═══════════════════════════════════════════════════════════

class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    super.key,
    required this.days,
    required this.selectedShift,
    this.onDayTap,
  });

  final List<DayPricing> days;
  final ShiftType selectedShift;
  final ValueChanged<DayPricing>? onDayTap;

  static const _weekdayLabels = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // تجميع حسب الشهر
    final months = <String, List<DayPricing>>{};
    for (final d in days) {
      final key = '${d.date.year}-${d.date.month}';
      months.putIfAbsent(key, () => []).add(d);
    }

    return Column(
      children: months.entries.map((month) {
        final list = month.value;
        final first = list.first.date;
        final title = _monthTitle(first);

        // إزاحة أول يوم حسب موقع الاثنين-first grid: نجعل الأحد أولاً
        final leading = (first.weekday % 7);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MaisonKicker(title),
                  const SizedBox(height: 6),
                  Text(
                    '${first.year}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: _weekdayLabels
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: .82,
              children: [
                for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                for (final day in list) _DayCell(
                  day: day,
                  shift: selectedShift,
                  onTap: onDayTap != null ? () => onDayTap!(day) : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        );
      }).toList(),
    );
  }

  String _monthTitle(DateTime d) {
    const months = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول'
    ];
    return months[d.month - 1];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.shift, this.onTap});

  final DayPricing day;
  final ShiftType shift;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = day.isPast || day.isBlocked || day.isBooked;
    final price = day.priceFor(shift);

    final weekend =
        day.date.weekday == DateTime.friday ||
        day.date.weekday == DateTime.saturday;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: VibesMotion.fast,
        decoration: ShapeDecoration(
          color: disabled
              ? VibesTheme.surfaceHighOf(context).withValues(alpha: .55)
              : weekend
              ? Vibes.tealMint
              : VibesTheme.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.compact,
            side: BorderSide(
              color: day.isBooked
                  ? Vibes.danger.withValues(alpha: .35)
                  : disabled
                  ? VibesTheme.hairlineOf(context)
                  : weekend
                  ? Vibes.teal.withValues(alpha: .45)
                  : VibesTheme.hairlineOf(context),
            ),
          ),
        ),
        child: Opacity(
          opacity: disabled ? .45 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.date.day}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: VibesTheme.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(height: 2),
              if (disabled)
                Icon(
                  day.isBooked ? Icons.event_busy_rounded : Icons.block_rounded,
                  size: 12,
                  color: VibesTheme.textTertiaryOf(context),
                )
              else
                Text(
                  _shortPrice(price),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Vibes.teal,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortPrice(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).round()}k';
    return '$v';
  }
}
