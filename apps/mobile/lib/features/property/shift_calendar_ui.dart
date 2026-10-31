import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../shared/models/models.dart';

/// ألوان وعلامات موحّدة للشفتات في التقويم والحجز.
Color get placeShiftMorning =>
    themed(const Color(0xFFD97706), const Color(0xFFF2A94A));
Color get placeShiftEvening =>
    themed(const Color(0xFF4F46E5), const Color(0xFF9D97F5));
Color get placeShiftFull => themed(const Color(0xFF141C2B), VibesDark.ink);
Color get _placeInk2 => themed(const Color(0xFF5A6678), VibesDark.inkSecondary);
Color get _placeBrass => themed(const Color(0xFFA5813A), Brand.brassLight);

/// النص فوق تعبئة الشفت: أبيض نهاراً، وحبر داكن ليلاً لأن ألوان الشفت تفتح.
Color get placeOnFill => themed(Colors.white, VibesDark.canvas);

Color placeShiftColor(ShiftType shift) => switch (shift) {
  ShiftType.morning => placeShiftMorning,
  ShiftType.evening => placeShiftEvening,
  ShiftType.full => placeShiftFull,
};

String placeShiftShortLabel(ShiftType shift) => switch (shift) {
  ShiftType.morning => 'صباح'.tr,
  ShiftType.evening => 'مساء'.tr,
  ShiftType.full => 'يوم كامل'.tr,
};

ShiftType shiftTypeFromApi(String? raw) => switch (raw) {
  'MORNING' => ShiftType.morning,
  'EVENING' => ShiftType.evening,
  _ => ShiftType.full,
};

String apiShiftFor(ShiftType shift) => switch (shift) {
  ShiftType.morning => 'MORNING',
  ShiftType.evening => 'EVENING',
  ShiftType.full => 'FULL',
};

String placeShiftBadgeChar(ShiftType shift) => switch (shift) {
  ShiftType.morning => I18n.isEn ? 'M' : 'ص', // i18n-ok
  ShiftType.evening => I18n.isEn ? 'E' : 'م', // i18n-ok
  ShiftType.full => I18n.isEn ? 'F' : 'ك', // i18n-ok
};

List<ShiftType> orderShiftsForDisplay(Iterable<ShiftType> shifts) {
  const order = [ShiftType.morning, ShiftType.evening, ShiftType.full];
  final set = shifts.toSet();
  return order.where(set.contains).toList();
}

bool shiftTypesConflict(ShiftType a, ShiftType b) {
  if (a == ShiftType.full || b == ShiftType.full) return true;
  return a == b;
}

extension DayPricingShiftX on DayPricing {
  Set<ShiftType> get occupiedShifts {
    if (bookedShifts.isNotEmpty) return bookedShifts.toSet();
    if (isBooked) return {ShiftType.full};
    return {};
  }

  bool isShiftOccupied(ShiftType shift) {
    for (final occupied in occupiedShifts) {
      if (shiftTypesConflict(shift, occupied)) return true;
    }
    return false;
  }

  /// شفتات تُعرض كشرائط/نقاط على خلية اليوم (بدون تكرار منطقي).
  List<ShiftType> calendarOccupancyMarkers({bool hybrid = true}) {
    final occupied = occupiedShifts;
    if (occupied.isEmpty) return const [];
    if (!hybrid || occupied.contains(ShiftType.full)) {
      return const [ShiftType.full];
    }
    final out = <ShiftType>[];
    if (occupied.contains(ShiftType.morning)) out.add(ShiftType.morning);
    if (occupied.contains(ShiftType.evening)) out.add(ShiftType.evening);
    return out;
  }
}

/// شريط ملوّن أسفل خلية التقويم (صباح / مساء / يوم كامل).
class PlaceShiftStripeRow extends StatelessWidget {
  const PlaceShiftStripeRow({
    super.key,
    required this.shifts,
    this.height = 3,
    this.onDark = false,
  });

  final List<ShiftType> shifts;
  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) return const SizedBox.shrink();
    final ordered = orderShiftsForDisplay(shifts);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Row(
        children: [
          for (final s in ordered)
            Expanded(
              child: Container(
                height: height,
                color: onDark
                    ? placeShiftColor(s).withValues(alpha: .92)
                    : placeShiftColor(s),
              ),
            ),
        ],
      ),
    );
  }
}

/// نقاط صغيرة لكل شفت محجوز.
class PlaceShiftOccupancyDots extends StatelessWidget {
  const PlaceShiftOccupancyDots({
    super.key,
    required this.day,
    this.hybrid = true,
    this.onDark = false,
    this.size = 5,
  });

  final DayPricing day;
  final bool hybrid;
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final markers = day.calendarOccupancyMarkers(hybrid: hybrid);
    if (markers.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in markers) ...[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: onDark
                  ? placeShiftColor(s).withValues(alpha: .95)
                  : placeShiftColor(s),
              shape: BoxShape.circle,
              border: onDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: .35),
                      width: .6,
                    )
                  : null,
            ),
          ),
          if (s != markers.last) SizedBox(width: size * .35),
        ],
      ],
    );
  }
}

class PlaceShiftBadge extends StatelessWidget {
  const PlaceShiftBadge({
    super.key,
    required this.shift,
    this.compact = false,
    this.external = false,
    this.onDark = false,
  });

  final ShiftType shift;
  final bool compact;
  final bool external;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = external ? _placeBrass : placeShiftColor(shift);
    final fg = onDark ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: .14)
            : color.withValues(alpha: external ? .14 : .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: .35)
              : color.withValues(alpha: .45),
        ),
      ),
      child: Text(
        compact ? placeShiftBadgeChar(shift) : placeShiftShortLabel(shift),
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          color: fg,
          height: 1.1,
        ),
      ),
    );
  }
}

/// شريط فلترة الشفتات (حجوزات المزوّد وغيرها).
class OwnerShiftFilterBar extends StatelessWidget {
  const OwnerShiftFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ShiftType? selected;
  final ValueChanged<ShiftType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _AllPeriodsChip(
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          for (final shift in const [
            ShiftType.morning,
            ShiftType.evening,
            ShiftType.full,
          ]) ...[
            OwnerShiftChip(
              apiShift: apiShiftFor(shift),
              label: placeShiftShortLabel(shift),
              selected: selected == shift,
              onTap: () => onSelected(shift),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _AllPeriodsChip extends StatelessWidget {
  const _AllPeriodsChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? placeShiftFull : Vibes.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? placeShiftFull
                  : _placeInk2.withValues(alpha: .35),
            ),
          ),
          child: Text(
            'كل الفترات'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? placeOnFill : _placeInk2,
            ),
          ),
        ),
      ),
    );
  }
}

/// ملخص عدد الحجوزات لكل شفت (مثلاً وصول اليوم).
class OwnerShiftDaySummary extends StatelessWidget {
  const OwnerShiftDaySummary({super.key, required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();
    final counts = <ShiftType, int>{for (final s in ShiftType.values) s: 0};
    for (final b in bookings) {
      counts[b.shift] = counts[b.shift]! + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final shift in const [
            ShiftType.morning,
            ShiftType.evening,
            ShiftType.full,
          ])
            if (counts[shift]! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlaceShiftBadge(shift: shift, compact: true),
                  const SizedBox(width: 4),
                  Text(
                    '${counts[shift]}',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: placeShiftFull,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// رقائق اختيار الشفت في بوابة المزوّد (إغلاق / حجز خارجي).
class OwnerShiftChip extends StatelessWidget {
  const OwnerShiftChip({
    super.key,
    required this.apiShift,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String apiShift;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shift = shiftTypeFromApi(apiShift);
    final color = placeShiftColor(shift);
    return Material(
      color: selected ? color.withValues(alpha: .12) : Vibes.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: .35),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : _placeInk2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceShiftLegendRow extends StatelessWidget {
  const PlaceShiftLegendRow({
    super.key,
    this.includeSelection = false,
    this.includeUnavailable = true,
  });

  final bool includeSelection;
  final bool includeUnavailable;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (includeSelection)
          _LegendChip(color: placeShiftFull, label: 'اختيارك'.tr, filled: true),
        _LegendChip(color: placeShiftMorning, label: 'صباح'.tr),
        _LegendChip(color: placeShiftEvening, label: 'مساء'.tr),
        _LegendChip(color: placeShiftFull, label: 'يوم كامل'.tr),
        if (includeUnavailable)
          _LegendChip(
            color: themed(const Color(0xFFEDF0F4), VibesDark.hairlineStrong),
            label: 'غير متاح'.tr,
            filled: true,
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    this.filled = false,
  });

  final Color color;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: filled ? color : color, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _placeInk2,
          ),
        ),
      ],
    );
  }
}
