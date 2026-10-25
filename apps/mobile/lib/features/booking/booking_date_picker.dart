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
    this.shift,
  });

  final DateTime start;
  final DateTime endExclusive;
  final num estimatedTotal;

  /// الفترة التي اعتمدها الزبون في التقويم (قد تختلف عمّا بدأ به).
  final ShiftType? shift;

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
  ({String morning, String evening})? shiftTimes,
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
      shiftTimes: shiftTimes,
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
    this.shiftTimes,
  });

  /// أوقات الفترات لعرضها (مثلاً 08:00 – 14:00).
  final ({String morning, String evening})? shiftTimes;

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
  /// الفترة الحالية — يغيّرها الزبون من أعلى التقويم دون الرجوع.
  late ShiftType _shift = _allowedShifts.contains(widget.shift)
      ? widget.shift
      : _allowedShifts.first;
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

  /// صباحي/مسائي: يوم واحد. اليوم الكامل: يوم أو أكثر (اضغط يوم النهاية).
  bool get _singleDay => _shift != ShiftType.full;

  /// يوم المغادرة يظهر للمسائي واليوم الكامل (اليوم التالي لآخر يوم محجوز).
  DateTime? get _departure {
    final end = _endInclusive;
    if (end == null || _shift == ShiftType.morning) return null;
    return end.add(const Duration(days: 1));
  }

  /// الفترات التي يقبلها المكان.
  List<ShiftType> get _allowedShifts =>
      switch (widget.availability.bookingMode) {
        BookingMode.shifts => const [ShiftType.morning, ShiftType.evening],
        BookingMode.hybrid => const [
          ShiftType.morning,
          ShiftType.evening,
          ShiftType.full,
        ],
        _ => const [ShiftType.full],
      };

  /// هل الفترة [shift] متاحة في هذا اليوم؟
  bool _free(DateTime date, DayPricing? p, ShiftType shift) {
    if (p == null ||
        p.isPast ||
        p.isBlocked ||
        p.isShiftOccupied(shift) ||
        p.priceFor(shift) <= 0) {
      return false;
    }
    return !widget.availability.isBlocked(date, shift);
  }

  String _shiftName(ShiftType s) => switch (s) {
    ShiftType.morning => 'الفترة الصباحية',
    ShiftType.evening => 'الفترة المسائية',
    ShiftType.full => 'اليوم الكامل',
  };

  String? _shiftTime(ShiftType s) => switch (s) {
    ShiftType.morning => widget.shiftTimes?.morning,
    ShiftType.evening => widget.shiftTimes?.evening,
    ShiftType.full => null,
  };

  void _changeShift(ShiftType s) {
    if (s == _shift) return;
    HapticFeedback.selectionClick();
    setState(() {
      _shift = s;
      _error = null;
      // يبقى اليوم المختار إن كانت الفترة الجديدة متاحة فيه
      final start = _start;
      if (start != null && !_free(start, _byDate[_key(start)], s)) {
        _start = null;
        _endInclusive = null;
        _awaitingRangeEnd = false;
      } else if (start != null && _singleDay) {
        _endInclusive = start;
        _awaitingRangeEnd = false;
      }
    });
  }

  /// يوم غير متاح للفترة الحالية: نوضح السبب ونعرض البديل المتاح فيه.
  Future<void> _explainUnavailable(DateTime date, DayPricing? p) async {
    HapticFeedback.lightImpact();
    if (p == null || p.isPast) {
      setState(() => _error = 'هذا اليوم مضى — اختر يوماً قادماً');
      return;
    }
    final alternatives = _allowedShifts
        .where((s) => s != _shift && _free(date, p, s))
        .toList();
    if (alternatives.isEmpty) {
      setState(
        () => _error = '${_longDate(date)} محجوز بالكامل — اختر يوماً آخر',
      );
      return;
    }
    final chosen = await showModalBottomSheet<ShiftType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlternativeSheet(
        dateLabel: _longDate(date),
        unavailable: _shiftName(_shift),
        options: [
          for (final s in alternatives)
            (
              shift: s,
              name: _shiftName(s),
              time: _shiftTime(s),
              price: p.priceFor(s),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    _changeShift(chosen);
    _select(date, p);
  }

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

  bool _disabled(DateTime date, DayPricing? pricing) =>
      !_free(date, pricing, _shift);

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
    if (_disabled(date, pricing)) {
      _explainUnavailable(date, pricing);
      return;
    }
    HapticFeedback.selectionClick();

    setState(() {
      _error = null;
      // صباحي / مسائي / يوم كامل ليوم واحد: ضغطة واحدة تكفي
      if (_singleDay) {
        _start = date;
        _endInclusive = date;
        _awaitingRangeEnd = false;
        return;
      }
      // يوم كامل: أول ضغطة = يوم واحد جاهز للاعتماد،
      // وضغطة على يوم لاحق تمدّ الحجز حتى ذلك اليوم.
      final start = _start;
      final end = _endInclusive;
      if (start == null || end == null || !date.isAfter(end)) {
        _start = date;
        _endInclusive = date;
        _awaitingRangeEnd = false;
        return;
      }
      if (!_rangeIsAvailable(start, date)) {
        _error = 'يوجد يوم غير متاح بين اليومين — اخترنا لك اليوم الجديد فقط';
        _start = date;
        _endInclusive = date;
        _awaitingRangeEnd = false;
        return;
      }
      _endInclusive = date;
      _awaitingRangeEnd = false;
    });
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
      total += map[_key(day)]?.priceFor(_shift) ?? 0;
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
        shift: _shift,
      ),
    );
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
                        widget.propertyName,
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

        // ── الفترة: تُختار هنا مباشرة، والتقويم يتلوّن فوراً ──
        if (_allowedShifts.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _PeriodSwitcher(
              allowed: _allowedShifts,
              selected: _shift,
              name: (s) => switch (s) {
                ShiftType.morning => 'صباحي',
                ShiftType.evening => 'مسائي',
                ShiftType.full => 'يوم كامل',
              },
              time: _shiftTime,
              onChanged: _changeShift,
            ),
          ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AvailabilityLegend(),
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
                      shift: _shift,
                      allowedShifts: _allowedShifts,
                      isFree: _free,
                      hybridMarkers: _hybridCalendar,
                      availability: widget.availability,
                      start: _start,
                      endInclusive: _endInclusive,
                      departure: _departure,
                      onSelect: _select,
                    );
                  },
                ),
        ),
        _SummaryBar(
          start: _start,
          endInclusive: _endInclusive,
          days: _selectedDays,
          total: _estimatedTotal,
          awaitingEnd: _awaitingRangeEnd,
          singleDay: _singleDay,
          dateLabel: _longDate,
          departureLabel: _departure == null ? null : _longDate(_departure!),
          periodLabel: [
            _shiftName(_shift),
            if (_shiftTime(_shift) != null) _shiftTime(_shift)!,
          ].join(' · '),
          onConfirm: _confirm,
        ),
      ],
    );

    if (embedded) return panel;
    return SizedBox(height: height.clamp(620, 820), child: panel);
  }

  String _shiftHintLabel() {
    final period = switch (_shift) {
      ShiftType.morning => 'الفترة الصباحية',
      ShiftType.evening => 'الفترة المسائية',
      ShiftType.full => 'اليوم الكامل',
    };
    if (_singleDay) {
      return _shift == ShiftType.evening
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

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.days,
    required this.shift,
    required this.allowedShifts,
    required this.isFree,
    required this.hybridMarkers,
    required this.availability,
    required this.start,
    required this.endInclusive,
    required this.departure,
    required this.onSelect,
  });

  final DateTime? departure;
  final DateTime month;
  final List<DayPricing> days;
  final ShiftType shift;
  final List<ShiftType> allowedShifts;
  final bool Function(DateTime date, DayPricing? p, ShiftType shift) isFree;
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
    // الأسابيع الماضية بالكامل في الشهر الحالي لا تُعرض — يبدأ التقويم
    // من أسبوع اليوم فلا يرى الزبون صفوفاً فارغة باهتة.
    final now = DateTime.now();
    var skipCells = 0;
    if (now.year == month.year && now.month == month.month) {
      final todayIndex = leading + now.day - 1;
      skipCells = (todayIndex ~/ 7) * 7;
    }

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
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            mainAxisExtent: 46,
          ),
          itemCount: leading + monthLength - skipCells,
          itemBuilder: (context, rawIndex) {
            final index = rawIndex + skipCells;
            if (index < leading) return const SizedBox.shrink();
            final number = index - leading + 1;
            final date = DateTime(month.year, month.month, number);
            final pricing = byDay[number];
            final disabled = !isFree(date, pricing, shift);
            final isStart = _sameDate(date, start);
            final isEnd = _sameDate(date, endInclusive);
            final inRange =
                start != null &&
                endInclusive != null &&
                date.isAfter(start!) &&
                date.isBefore(endInclusive!);

            return _DayCell(
              date: date,
              past: pricing == null || pricing.isPast,
              available: !disabled,
              selected: isStart || isEnd,
              departure: _sameDate(date, departure),
              inRange: inRange,
              onTap: pricing == null || pricing.isPast
                  ? null
                  : () => onSelect(date, pricing),
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
    required this.past,
    required this.available,
    required this.selected,
    required this.inRange,
    this.departure = false,
    this.onTap,
  });

  /// يوم المغادرة (بعد المسائي أو اليوم الكامل).
  final bool departure;
  final DateTime date;
  final bool past;

  /// متاح للفترة المختارة (أخضر) — وإلا غير متاح (أحمر).
  final bool available;
  final bool selected;
  final bool inRange;
  final VoidCallback? onTap;

  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (selected) {
      bg = green;
      fg = Colors.white;
      border = green;
    } else if (inRange) {
      bg = green.withValues(alpha: .18);
      fg = const Color(0xFF15803D);
      border = green.withValues(alpha: .4);
    } else if (departure) {
      bg = Colors.white;
      fg = const Color(0xFF15803D);
      border = green;
    } else if (past) {
      bg = Colors.transparent;
      fg = placeInk2.withValues(alpha: .3);
      border = Colors.transparent;
    } else if (available) {
      bg = green.withValues(alpha: .10);
      fg = const Color(0xFF15803D);
      border = green.withValues(alpha: .35);
    } else {
      bg = red.withValues(alpha: .08);
      fg = red;
      border = red.withValues(alpha: .28);
    }

    return Semantics(
      button: !past,
      label:
          '${date.day} ${past
              ? ''
              : available
              ? 'متاح'
              : 'غير متاح'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
              width: selected || departure ? 1.8 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: green.withValues(alpha: .35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: departure && !selected
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'مغادرة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                        height: 1.2,
                      ),
                    ),
                  ],
                )
              : selected
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  '${date.day}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}

/// مبدّل الفترة أعلى التقويم — يعرض الاسم والوقت ويلوّن التقويم فوراً.
class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.allowed,
    required this.selected,
    required this.name,
    required this.time,
    required this.onChanged,
  });

  final List<ShiftType> allowed;
  final ShiftType selected;
  final String Function(ShiftType) name;
  final String? Function(ShiftType) time;
  final ValueChanged<ShiftType> onChanged;

  IconData _icon(ShiftType s) => switch (s) {
    ShiftType.morning => Icons.wb_sunny_rounded,
    ShiftType.evening => Icons.nightlight_round,
    ShiftType.full => Icons.calendar_today_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final s in allowed)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: s == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: s == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _icon(s),
                            size: 16,
                            color: s == selected
                                ? placeShiftColor(s)
                                : placeInk2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            name(s),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: s == selected ? placeInk : placeInk2,
                            ),
                          ),
                        ],
                      ),
                      if (time(s) != null)
                        Text(
                          time(s)!,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: s == selected
                                ? placeInk2
                                : placeInk2.withValues(alpha: .7),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// دليل الألوان — سطر واحد: أخضر متاح، أحمر غير متاح.
class _AvailabilityLegend extends StatelessWidget {
  const _AvailabilityLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: c),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          t,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: placeInk,
          ),
        ),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(_DayCell.green, 'متاح'),
        const SizedBox(width: 22),
        item(_DayCell.red, 'غير متاح'),
      ],
    );
  }
}

/// نافذة البديل: الفترة المختارة محجوزة لكن غيرها متاح في نفس اليوم.
class _AlternativeSheet extends StatelessWidget {
  const _AlternativeSheet({
    required this.dateLabel,
    required this.unavailable,
    required this.options,
  });

  final String dateLabel;
  final String unavailable;
  final List<({ShiftType shift, String name, String? time, num price})> options;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: placeLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            dateLabel,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: placeInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$unavailable محجوزة في هذا اليوم، لكن يمكنك الحجز في:',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: placeInk2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: placeShiftColor(o.shift).withValues(alpha: .35),
                  ),
                ),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () => Navigator.pop(context, o.shift),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: placeShiftColor(
                              o.shift,
                            ).withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            switch (o.shift) {
                              ShiftType.morning => Icons.wb_sunny_rounded,
                              ShiftType.evening => Icons.nightlight_round,
                              ShiftType.full => Icons.calendar_today_rounded,
                            },
                            color: placeShiftColor(o.shift),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: placeInk,
                                ),
                              ),
                              if (o.time != null)
                                Text(
                                  o.time!,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: placeInk2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PlaceFullPriceText(o.price, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'اختيار يوم آخر',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
    this.periodLabel,
    this.departureLabel,
  });

  final String? periodLabel;
  final String? departureLabel;
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
                        if (periodLabel != null)
                          Text(
                            periodLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: placeInk2,
                            ),
                          ),
                        if (ready && departureLabel != null)
                          Text(
                            'المغادرة: $departureLabel',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        if (ready && !singleDay)
                          Text(
                            days > 1
                                ? '$days أيام'
                                : 'لأكثر من يوم: اضغط على يوم النهاية',
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
