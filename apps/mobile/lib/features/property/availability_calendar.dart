import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import 'place_experience_ui.dart';
import 'shift_calendar_ui.dart';
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
    this.hybridMarkers = true,
  });

  final List<DayPricing> days;
  final ShiftType selectedShift;
  final ValueChanged<DayPricing>? onDayTap;
  final bool hybridMarkers;

  static const _weekdayLabels = [
    'أحد',
    'إثن',
    'ثلا',
    'أرب',
    'خمي',
    'جمع',
    'سبت',
  ];

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
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: PlaceShiftLegendRow(includeSelection: false),
        ),
        ...months.entries.map((month) {
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
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    )
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
                  for (final day in list)
                    _DayCell(
                      day: day,
                      shift: selectedShift,
                      hybridMarkers: hybridMarkers,
                      onTap: onDayTap != null ? () => onDayTap!(day) : null,
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          );
        }).toList(),
      ],
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
      'كانون الأول',
    ];
    return months[d.month - 1];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.shift,
    required this.hybridMarkers,
    this.onTap,
  });

  final DayPricing day;
  final ShiftType shift;
  final bool hybridMarkers;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shiftTaken = day.isShiftOccupied(shift);
    final disabled = day.isPast || day.isBlocked || shiftTaken;
    final price = day.priceFor(shift);
    final accent = placeShiftColor(shift);
    final occupancy = day.calendarOccupancyMarkers(hybrid: hybridMarkers);

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
              color: shiftTaken
                  ? accent.withValues(alpha: .55)
                  : disabled
                  ? VibesTheme.hairlineOf(context)
                  : weekend
                  ? Vibes.teal.withValues(alpha: .45)
                  : accent.withValues(alpha: .28),
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
                day.occupiedShifts.isNotEmpty
                    ? PlaceShiftOccupancyDots(
                        day: day,
                        hybrid: hybridMarkers,
                        size: 4,
                      )
                    : Icon(
                        Icons.block_rounded,
                        size: 12,
                        color: VibesTheme.textTertiaryOf(context),
                      )
              else
                Text(
                  placeFullPrice(price),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    fontSize: 8,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              if (occupancy.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
                  child: PlaceShiftStripeRow(shifts: occupancy, height: 2.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
