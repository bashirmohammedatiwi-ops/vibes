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
  late ShiftType _shift = widget.shift;
  late final BookingDatePickMode _fullMode = widget.shift == ShiftType.full
      ? widget.mode
      : BookingDatePickMode.singleDay;
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

  bool get _singleDay =>
      _shift != ShiftType.full || _fullMode == BookingDatePickMode.singleDay;

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
          child: _AvailabilityLegend(
            showSplit: _allowedShifts.contains(ShiftType.morning),
            periodName: _shiftName(_shift),
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
                      shift: _shift,
                      allowedShifts: _allowedShifts,
                      isFree: _free,
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
            periodLabel: [
              _shiftName(_shift),
              if (_shiftTime(_shift) != null) _shiftTime(_shift)!,
            ].join(' · '),
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
    required this.allowedShifts,
    required this.isFree,
    required this.hybridMarkers,
    required this.availability,
    required this.start,
    required this.endInclusive,
    required this.onSelect,
  });

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
            mainAxisSpacing: 6,
            crossAxisSpacing: 5,
            mainAxisExtent: 62,
          ),
          itemCount: leading + monthLength - skipCells,
          itemBuilder: (context, rawIndex) {
            final index = rawIndex + skipCells;
            if (index < leading) return const SizedBox.shrink();
            final number = index - leading + 1;
            final date = DateTime(month.year, month.month, number);
            final pricing = byDay[number];
            final disabled = !isFree(date, pricing, shift);
            final otherFree = allowedShifts.any(
              (x) => x != shift && isFree(date, pricing, x),
            );
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
              partial: disabled && otherFree,
              partialLabel: () {
                final m = isFree(date, pricing, ShiftType.morning);
                final e = isFree(date, pricing, ShiftType.evening);
                if (m && !e) return 'صباحي فقط';
                if (e && !m) return 'مسائي فقط';
                return 'فترة أخرى';
              }(),
              morningFree: isFree(date, pricing, ShiftType.morning),
              eveningFree: isFree(date, pricing, ShiftType.evening),
              showSplit: allowedShifts.contains(ShiftType.morning),
              selected: isStart || isEnd,
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
    required this.pricing,
    required this.shift,
    required this.hybridMarkers,
    required this.disabled,
    required this.partial,
    this.partialLabel = 'جزئي',
    required this.morningFree,
    required this.eveningFree,
    required this.showSplit,
    required this.selected,
    required this.inRange,
    this.onTap,
  });

  final DateTime date;
  final DayPricing? pricing;
  final ShiftType shift;
  final bool hybridMarkers;

  /// غير متاح للفترة المختارة.
  final bool disabled;

  /// غير متاح للفترة المختارة لكن فترة أخرى متاحة فيه.
  final bool partial;
  final String partialLabel;
  final bool morningFree;
  final bool eveningFree;
  final bool showSplit;
  final bool selected;
  final bool inRange;
  final VoidCallback? onTap;

  static const _free = Color(0xFF16A34A);
  static const _taken = Color(0xFFD5D9E0);
  static const _partial = Color(0xFFD97706);

  /// سعر مختصر يُقرأ بسهولة: 240 ألف، 1.2م
  static String _short(num v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1).replaceAll('.0', '')}م';
    }
    if (v >= 1000) return '${(v / 1000).round()} ألف';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final past = pricing == null || pricing!.isPast;
    final accent = placeShiftColor(shift);
    final weekend =
        date.weekday == DateTime.friday || date.weekday == DateTime.saturday;

    final Color bg;
    final Color border;
    if (selected) {
      bg = accent;
      border = accent;
    } else if (inRange) {
      bg = accent.withValues(alpha: .1);
      border = accent.withValues(alpha: .35);
    } else if (past) {
      bg = Colors.transparent;
      border = Colors.transparent;
    } else if (!disabled) {
      bg = Colors.white;
      border = _free.withValues(alpha: .35);
    } else if (partial) {
      bg = _partial.withValues(alpha: .07);
      border = _partial.withValues(alpha: .3);
    } else {
      bg = const Color(0xFFF1F3F6);
      border = const Color(0xFFE6E9EE);
    }

    final numberColor = selected
        ? Colors.white
        : past
        ? placeInk2.withValues(alpha: .35)
        : disabled
        ? placeInk2
        : weekend
        ? placeBrass
        : placeInk;

    final String? label;
    final Color labelColor;
    if (past) {
      label = null;
      labelColor = placeInk2;
    } else if (!disabled) {
      label = _short(pricing!.priceFor(shift));
      labelColor = selected ? Colors.white : const Color(0xFF15803D);
    } else if (partial) {
      label = partialLabel;
      labelColor = _partial;
    } else {
      label = 'محجوز';
      labelColor = placeInk2.withValues(alpha: .7);
    }

    Widget seg(bool free) => Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: selected
              ? (free ? Colors.white : Colors.white.withValues(alpha: .35))
              : (free ? _free : _taken),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    return Semantics(
      button: !past,
      label: '${date.day}${label == null ? '' : ' · $label'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                  decoration: disabled && !partial && !past && !selected
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: placeInk2.withValues(alpha: .5),
                  height: 1.1,
                ),
              ),
              const Spacer(),
              if (label != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      height: 1.2,
                    ),
                  ),
                ),
              // شريط الفترتين: يمين = صباحي، يسار = مسائي (أخضر = متاح)
              if (showSplit && !past) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    seg(morningFree),
                    const SizedBox(width: 2),
                    seg(eveningFree),
                  ],
                ),
              ],
            ],
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

/// دليل الألوان أعلى التقويم.
class _AvailabilityLegend extends StatelessWidget {
  const _AvailabilityLegend({
    required this.showSplit,
    required this.periodName,
  });

  final bool showSplit;
  final String periodName;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t, {Color? border}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
            border: border == null ? null : Border.all(color: border),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          t,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: placeInk2,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: placeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              dot(
                Colors.white,
                'متاح ($periodName)',
                border: const Color(0xFF86C79A),
              ),
              dot(
                const Color(0xFFFBEBD4),
                'فترة أخرى متاحة — اضغط',
                border: const Color(0xFFEFC48A),
              ),
              dot(
                const Color(0xFFF1F3F6),
                'محجوز',
                border: const Color(0xFFE6E9EE),
              ),
            ],
          ),
          if (showSplit) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5D9E0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.wb_sunny_rounded,
                  size: 13,
                  color: placeShiftMorning,
                ),
                const Text(
                  ' صباحي  ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: placeInk2,
                  ),
                ),
                const Icon(
                  Icons.nightlight_round,
                  size: 12,
                  color: placeShiftEvening,
                ),
                const Expanded(
                  child: Text(
                    ' مسائي · الأخضر متاح والرمادي محجوز',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: placeInk2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
  });

  final String? periodLabel;
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
