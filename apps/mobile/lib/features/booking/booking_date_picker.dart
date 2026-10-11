import '../../core/theme/world_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/models/models.dart';
import '../property/place_experience_ui.dart';
import '../property/shift_calendar_ui.dart';

/// ═══════════════════════════════════════════════════════════
/// لوحة اختيار التاريخ — نفس لغة تصميم لوحة الشفتات:
/// أبيض نظيف، حبر عميق، أسعار كاملة، توفر واضح.
/// ═══════════════════════════════════════════════════════════

class BookingDateSelection {
  const BookingDateSelection({
    required this.start,
    required this.endExclusive,
    required this.estimatedTotal,
  });

  final DateTime start;
  final DateTime endExclusive;
  final num estimatedTotal;

  int get days => endExclusive.difference(start).inDays;
}

/// يوم واحد (صباحي/مسائي/يوم كامل ليوم واحد) أو نطاق (يوم كامل متعدد).
enum BookingDatePickMode { singleDay, range }

Future<BookingDateSelection?> showBookingDatePicker({
  required BuildContext context,
  required String propertyName,
  required AvailabilityData availability,
  required ShiftType shift,
  DateTime? initialStart,
  DateTime? initialEndExclusive,
  BookingDatePickMode? mode,
}) {
  final resolvedMode =
      mode ??
      (shift == ShiftType.full
          ? BookingDatePickMode.range
          : BookingDatePickMode.singleDay);
  return showModalBottomSheet<BookingDateSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => BookingDatePickerPanel(
      propertyName: propertyName,
      availability: availability,
      shift: shift,
      initialStart: initialStart,
      initialEndExclusive: initialEndExclusive,
      mode: resolvedMode,
      embedded: false,
      onConfirm: (selection) => Navigator.pop(ctx, selection),
      onCancel: () => Navigator.pop(ctx),
    ),
  );
}

/// تقويم الحجز — يُستخدم كـ sheet أو مضمّناً داخل معالج الحجز.
class BookingDatePickerPanel extends StatefulWidget {
  const BookingDatePickerPanel({
    super.key,
    required this.propertyName,
    required this.availability,
    required this.shift,
    required this.mode,
    required this.onConfirm,
    this.onCancel,
    this.initialStart,
    this.initialEndExclusive,
    this.embedded = false,
    this.autoConfirmSingleDay = false,
  });

  final String propertyName;
  final AvailabilityData availability;
  final ShiftType shift;
  final BookingDatePickMode mode;
  final ValueChanged<BookingDateSelection> onConfirm;
  final VoidCallback? onCancel;
  final DateTime? initialStart;
  final DateTime? initialEndExclusive;
  final bool embedded;

  /// في الوضع المضمّن: بعد اختيار يوم واحد يُعتمد مباشرة.
  final bool autoConfirmSingleDay;

  @override
  State<BookingDatePickerPanel> createState() => _BookingDatePickerPanelState();
}

class _BookingDatePickerPanelState extends State<BookingDatePickerPanel> {
  DateTime? _start;
  DateTime? _endInclusive;
  bool _awaitingRangeEnd = false;
  String? _error;

  static const _months = [
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

  static const _weekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  bool get _singleDay => widget.mode == BookingDatePickMode.singleDay;

  @override
  void initState() {
    super.initState();
    _start = _dateOnly(widget.initialStart);
    final initialEnd = widget.initialEndExclusive;
    if (_start != null) {
      if (_singleDay) {
        _endInclusive = _start;
        _awaitingRangeEnd = false;
      } else if (initialEnd != null) {
        _endInclusive = _dateOnly(initialEnd.subtract(const Duration(days: 1)));
      }
    }
  }

  List<DayPricing> get _days {
    final sorted = [...widget.availability.dayPrices]
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  Map<String, DayPricing> get _byDate => {
    for (final day in _days) _key(day.date): day,
  };

  List<({DateTime month, List<DayPricing> days})> get _monthGroups {
    final groups = <String, List<DayPricing>>{};
    for (final day in _days) {
      groups
          .putIfAbsent(
            '${day.date.year}-${day.date.month}',
            () => <DayPricing>[],
          )
          .add(day);
    }
    return groups.values
        .map(
          (items) => (
            month: DateTime(items.first.date.year, items.first.date.month),
            days: items,
          ),
        )
        .toList();
  }

  bool _disabled(DateTime date, DayPricing? pricing) {
    if (pricing == null ||
        pricing.isPast ||
        pricing.isBlocked ||
        pricing.isShiftOccupied(widget.shift) ||
        pricing.priceFor(widget.shift) <= 0) {
      return true;
    }
    return widget.availability.isBlocked(date, widget.shift);
  }

  bool get _hybridCalendar =>
      widget.availability.bookingMode == BookingMode.hybrid ||
      widget.availability.bookingMode == BookingMode.shifts;

  bool _rangeIsAvailable(DateTime start, DateTime endInclusive) {
    final map = _byDate;
    for (
      var day = start;
      !day.isAfter(endInclusive);
      day = day.add(const Duration(days: 1))
    ) {
      if (_disabled(day, map[_key(day)])) return false;
    }
    return true;
  }

  void _select(DateTime date, DayPricing pricing) {
    if (_disabled(date, pricing)) return;
    HapticFeedback.selectionClick();

    setState(() {
      _error = null;
      // صباحي / مسائي / يوم كامل ليوم واحد: ضغطة واحدة تكفي
      if (_singleDay) {
        _start = date;
        _endInclusive = date;
        _awaitingRangeEnd = false;
        _maybeAutoConfirm();
        return;
      }
      if (_start == null || !_awaitingRangeEnd || date.isBefore(_start!)) {
        _start = date;
        _endInclusive = date;
        _awaitingRangeEnd = true;
        return;
      }

      if (!_rangeIsAvailable(_start!, date)) {
        _error = 'يوجد يوم غير متاح داخل هذا النطاق';
        _start = date;
        _endInclusive = date;
        _awaitingRangeEnd = true;
        return;
      }
      _endInclusive = date;
      _awaitingRangeEnd = false;
    });
  }

  void _pickQuick(_QuickPick pick) {
    final available = _days.where(
      (day) => !_disabled(_dateOnly(day.date)!, day),
    );

    if (pick == _QuickPick.weekend) {
      for (final day in available) {
        if (day.date.weekday == DateTime.friday ||
            day.date.weekday == DateTime.saturday) {
          _setRange(_dateOnly(day.date)!, 1);
          return;
        }
      }
      setState(() => _error = 'لا توجد عطلة نهاية أسبوع متاحة حالياً');
      return;
    }

    if (pick == _QuickPick.twoDays) {
      if (_singleDay) {
        setState(() => _error = 'هذه الفترة يوم واحد فقط');
        return;
      }
      for (final day in available) {
        final start = _dateOnly(day.date)!;
        if (_rangeIsAvailable(start, start.add(const Duration(days: 1)))) {
          _setRange(start, 2);
          return;
        }
      }
      setState(() => _error = 'لا يوجد نطاق يومين متصل متاح حالياً');
      return;
    }

    final first = available.firstOrNull;
    if (first == null) {
      setState(() => _error = 'لا توجد مواعيد متاحة حالياً');
      return;
    }
    _setRange(_dateOnly(first.date)!, 1);
  }

  void _setRange(DateTime start, int length) {
    final end = start.add(Duration(days: length - 1));
    if (!_rangeIsAvailable(start, end)) {
      setState(() => _error = 'لا يتوفر نطاق متصل بهذه المدة');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _start = start;
      _endInclusive = end;
      _awaitingRangeEnd = false;
      _error = null;
    });
    _maybeAutoConfirm();
  }

  num get _estimatedTotal {
    if (_start == null || _endInclusive == null) return 0;
    final map = _byDate;
    num total = 0;
    for (
      var day = _start!;
      !day.isAfter(_endInclusive!);
      day = day.add(const Duration(days: 1))
    ) {
      total += map[_key(day)]?.priceFor(widget.shift) ?? 0;
    }
    return total;
  }

  int get _selectedDays {
    if (_start == null || _endInclusive == null) return 0;
    return _endInclusive!.difference(_start!).inDays + 1;
  }

  void _confirm() {
    if (_start == null || _endInclusive == null) return;
    HapticFeedback.mediumImpact();
    widget.onConfirm(
      BookingDateSelection(
        start: _start!,
        endExclusive: _endInclusive!.add(const Duration(days: 1)),
        estimatedTotal: _estimatedTotal,
      ),
    );
  }

  void _maybeAutoConfirm() {
    if (!widget.autoConfirmSingleDay || !_singleDay) return;
    if (_start != null && _endInclusive != null && !_awaitingRangeEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirm();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _monthGroups;
    final embedded = widget.embedded;
    final height = MediaQuery.sizeOf(context).height * (embedded ? .72 : .92);

    final panel = Column(
      children: [
        if (!embedded) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: placeLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        if (!embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _singleDay ? 'اختر اليوم' : 'اختر مدة الإقامة',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: placeInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.propertyName} · ${_shiftHintLabel()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: placeInk2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded, color: placeInk2),
                ),
              ],
            ),
          ),
        if (embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _shiftHintLabel(),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: placeInk2,
                ),
              ),
            ),
          ),

        // اختصارات سريعة — نفس أسلوب رقائق لوحة الشفتات
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _QuickChip(
                label: 'أقرب موعد متاح',
                icon: Icons.bolt_rounded,
                onTap: () => _pickQuick(_QuickPick.nearest),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: 'عطلة نهاية الأسبوع',
                icon: Icons.weekend_outlined,
                onTap: () => _pickQuick(_QuickPick.weekend),
              ),
              if (!_singleDay) ...[
                const SizedBox(width: 8),
                _QuickChip(
                  label: 'يومان متصلان',
                  icon: Icons.date_range_outlined,
                  onTap: () => _pickQuick(_QuickPick.twoDays),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PlaceShiftLegendRow(
            includeSelection: true,
            includeUnavailable: true,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
          ),
        Expanded(
          child: groups.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 44,
                        color: placeLine,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'لا مواعيد متاحة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: placeInk2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'جرّب لاحقاً أو تواصل مع المضيف',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: placeInk2,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 22),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _MonthCalendar(
                      month: group.month,
                      days: group.days,
                      shift: widget.shift,
                      hybridMarkers: _hybridCalendar,
                      availability: widget.availability,
                      start: _start,
                      endInclusive: _endInclusive,
                      onSelect: _select,
                    );
                  },
                ),
        ),
        if (!widget.autoConfirmSingleDay || !_singleDay)
          _SummaryBar(
            start: _start,
            endInclusive: _endInclusive,
            days: _selectedDays,
            total: _estimatedTotal,
            awaitingEnd: _awaitingRangeEnd,
            singleDay: _singleDay,
            dateLabel: _longDate,
            onConfirm: _confirm,
          )
        else if (_start != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'تم اختيار ${_longDate(_start!)} · متابعة…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: placeInk2,
              ),
            ),
          ),
      ],
    );

    if (embedded) return panel;
    return SizedBox(height: height.clamp(620, 820), child: panel);
  }

  String _shiftHintLabel() {
    final period = switch (widget.shift) {
      ShiftType.morning => 'الفترة الصباحية',
      ShiftType.evening => 'الفترة المسائية',
      ShiftType.full => 'اليوم الكامل',
    };
    if (_singleDay) {
      return widget.shift == ShiftType.evening
          ? '$period · المغادرة تلقائياً في اليوم التالي'
          : '$period · يوم واحد · المغادرة اليوم التالي';
    }
    return '$period · اختر أول وآخر يوم';
  }

  String _longDate(DateTime date) =>
      '${_weekdays[date.weekday % 7]} ${date.day} ${_months[date.month - 1]}';

  static DateTime? _dateOnly(DateTime? value) =>
      value == null ? null : DateTime(value.year, value.month, value.day);

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

enum _QuickPick { nearest, weekend, twoDays }

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: placePaper,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: placeLine),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: placeBrass),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: placeInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.days,
    required this.shift,
    required this.hybridMarkers,
    required this.availability,
    required this.start,
    required this.endInclusive,
    required this.onSelect,
  });

  final DateTime month;
  final List<DayPricing> days;
  final ShiftType shift;
  final bool hybridMarkers;
  final AvailabilityData availability;
  final DateTime? start;
  final DateTime? endInclusive;
  final void Function(DateTime date, DayPricing pricing) onSelect;

  static const _months = [
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

  static const _weekdayShort = [
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
    final byDay = {for (final day in days) day.date.day: day};
    final leading = DateTime(month.year, month.month, 1).weekday % 7;
    final monthLength = DateTime(month.year, month.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم الشهر — مسطرة نحاسية مثل ترويسات المكان
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: placeBrass,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_months[month.month - 1]} ${month.year}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: placeInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final label in _weekdayShort)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: placeInk2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: .82,
          ),
          itemCount: leading + monthLength,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final number = index - leading + 1;
            final date = DateTime(month.year, month.month, number);
            final pricing = byDay[number];
            final disabled =
                pricing == null ||
                pricing.isPast ||
                pricing.isBlocked ||
                pricing.isShiftOccupied(shift) ||
                pricing.priceFor(shift) <= 0 ||
                availability.isBlocked(date, shift);
            final isStart = _sameDate(date, start);
            final isEnd = _sameDate(date, endInclusive);
            final inRange =
                start != null &&
                endInclusive != null &&
                date.isAfter(start!) &&
                date.isBefore(endInclusive!);

            return _DayCell(
              date: date,
              pricing: pricing,
              shift: shift,
              hybridMarkers: hybridMarkers,
              disabled: disabled,
              selected: isStart || isEnd,
              inRange: inRange,
              onTap: pricing == null ? null : () => onSelect(date, pricing),
            );
          },
        ),
      ],
    );
  }

  bool _sameDate(DateTime value, DateTime? other) =>
      other != null &&
      value.year == other.year &&
      value.month == other.month &&
      value.day == other.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.pricing,
    required this.shift,
    required this.hybridMarkers,
    required this.disabled,
    required this.selected,
    required this.inRange,
    this.onTap,
  });

  final DateTime date;
  final DayPricing? pricing;
  final ShiftType shift;
  final bool hybridMarkers;
  final bool disabled;
  final bool selected;
  final bool inRange;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final weekend =
        date.weekday == DateTime.friday || date.weekday == DateTime.saturday;

    final accent = placeShiftColor(shift);
    final occupancy =
        pricing?.calendarOccupancyMarkers(hybrid: hybridMarkers) ??
        const <ShiftType>[];
    final showStripe = !selected && occupancy.isNotEmpty;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? accent
              : inRange
              ? accent.withValues(alpha: .08)
              : disabled
              ? const Color(0xFFF3F5F8)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? accent
                : inRange
                ? accent.withValues(alpha: .35)
                : !disabled
                ? accent.withValues(alpha: .22)
                : placeLine,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Opacity(
          opacity: disabled ? .42 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : weekend
                      ? placeBrass
                      : placeInk,
                ),
              ),
              const SizedBox(height: 2),
              if (disabled)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (pricing != null && pricing!.occupiedShifts.isNotEmpty)
                      PlaceShiftOccupancyDots(
                        day: pricing!,
                        hybrid: hybridMarkers,
                        onDark: selected,
                        size: 4,
                      )
                    else
                      Icon(
                        Icons.remove_rounded,
                        size: 9,
                        color: selected ? Colors.white70 : placeInk2,
                      ),
                  ],
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      placeFullPrice(pricing!.priceFor(shift)),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white.withValues(alpha: .85)
                            : weekend
                            ? placeBrass
                            : placeInk2,
                      ),
                    ),
                  ),
                ),
              if (showStripe)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
                  child: PlaceShiftStripeRow(
                    shifts: occupancy,
                    height: 2.5,
                    onDark: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.start,
    required this.endInclusive,
    required this.days,
    required this.total,
    required this.awaitingEnd,
    required this.singleDay,
    required this.dateLabel,
    required this.onConfirm,
  });

  final DateTime? start;
  final DateTime? endInclusive;
  final int days;
  final num total;
  final bool awaitingEnd;
  final bool singleDay;
  final String Function(DateTime date) dateLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final ready = start != null && endInclusive != null && !awaitingEnd;
    final departure = start?.add(const Duration(days: 1));

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14141C2B),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ready
                              ? (singleDay || days == 1
                                    ? dateLabel(start!)
                                    : '${dateLabel(start!)} — ${dateLabel(endInclusive!)}')
                              : (awaitingEnd
                                    ? 'اختر يوم المغادرة'
                                    : (singleDay
                                          ? 'اضغط يوماً واحداً'
                                          : 'اختر يوم الوصول')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: placeInk,
                          ),
                        ),
                        if (ready)
                          Text(
                            singleDay || days == 1
                                ? 'مغادرة ${dateLabel(departure!)} · تلقائي'
                                : '$days أيام · سعر تقديري قبل الكوبون',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: placeInk2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (ready) PlaceFullPriceText(total, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.world.accentDeep,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.world.accentDeep
                        .withValues(alpha: .25),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: ready ? onConfirm : null,
                  child: Text(
                    ready ? 'اعتماد الموعد' : 'اختر موعداً للمتابعة',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
