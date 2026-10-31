import '../../core/theme/world_theme.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
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
    backgroundColor: Vibes.surface,
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
    'كانون الثاني', // i18n-ok
    'شباط', // i18n-ok
    'آذار', // i18n-ok
    'نيسان', // i18n-ok
    'أيار', // i18n-ok
    'حزيران', // i18n-ok
    'تموز', // i18n-ok
    'آب', // i18n-ok
    'أيلول', // i18n-ok
    'تشرين الأول', // i18n-ok
    'تشرين الثاني', // i18n-ok
    'كانون الأول', // i18n-ok
  ];

  static const _weekdays = [
    'الأحد', // i18n-ok
    'الإثنين', // i18n-ok
    'الثلاثاء', // i18n-ok
    'الأربعاء', // i18n-ok
    'الخميس', // i18n-ok
    'الجمعة', // i18n-ok
    'السبت', // i18n-ok
  ];

  /// صباحي/مسائي: يوم واحد. اليوم الكامل: يوم أو أكثر (اضغط يوم النهاية).
  bool get _singleDay => _shift != ShiftType.full || _isService;

  /// التزيين خدمة ليوم المناسبة: يوم واحد، بلا يوم مغادرة.
  bool get _isService => widget.availability.isService;

  /// يوم المغادرة يظهر للمسائي واليوم الكامل (اليوم التالي لآخر يوم محجوز).
  DateTime? get _departure {
    final end = _endInclusive;
    if (end == null || _shift == ShiftType.morning || _isService) return null;
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
    ShiftType.morning => 'الفترة الصباحية'.tr,
    ShiftType.evening => 'الفترة المسائية'.tr,
    ShiftType.full => 'اليوم الكامل'.tr,
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
      setState(() => _error = 'هذا اليوم مضى — اختر يوماً قادماً'.tr);
      return;
    }
    final alternatives = _allowedShifts
        .where((s) => s != _shift && _free(date, p, s))
        .toList();
    if (alternatives.isEmpty) {
      setState(
        () => _error = '{date} محجوز بالكامل — اختر يوماً آخر'.trArgs({
          'date': _longDate(date),
        }),
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
        _error =
            'يوجد يوم غير متاح بين اليومين — اخترنا لك اليوم الجديد فقط'.tr;
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
                        _isService
                            ? 'اختر يوم المناسبة'.tr
                            : _singleDay
                            ? 'اختر اليوم'.tr
                            : 'اختر مدة الإقامة'.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
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
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
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
                  icon: Icon(Icons.close_rounded, color: placeInk2),
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
                style: TextStyle(
                  fontFamily: VibesFont.ui,
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
                ShiftType.morning => 'صباحي'.tr,
                ShiftType.evening => 'مسائي'.tr,
                ShiftType.full => 'يوم كامل'.tr,
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
                color: themed(
                  const Color(0xFFB45309),
                  VibesDark.warning,
                ).withValues(alpha: Appearance.isDark ? .14 : .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: themed(const Color(0xFFB45309), VibesDark.warning),
                ),
              ),
            ),
          ),
        Expanded(
          child: groups.isEmpty
              ? Center(
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
                        'لا مواعيد متاحة'.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: placeInk2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'جرّب لاحقاً أو تواصل مع المضيف'.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
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
          periodLabel: _isService
              ? 'خدمة التزيين · سعر موحّد'.tr
              : [
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
      ShiftType.morning => 'الفترة الصباحية'.tr,
      ShiftType.evening => 'الفترة المسائية'.tr,
      ShiftType.full => 'اليوم الكامل'.tr,
    };
    if (_singleDay) {
      return _shift == ShiftType.evening
          ? '{period} · المغادرة تلقائياً في اليوم التالي'.trArgs({
              'period': period,
            })
          : '{period} · يوم واحد · المغادرة اليوم التالي'.trArgs({
              'period': period,
            });
    }
    return '{period} · اختر أول وآخر يوم'.trArgs({'period': period});
  }

  String _longDate(DateTime date) {
    final weekday = _weekdays[date.weekday % 7].tr;
    final month = _months[date.month - 1].tr;
    if (I18n.isEn) return '${_short(weekday)}, ${_short(month)} ${date.day}';
    return '$weekday ${date.day} $month';
  }

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
    'كانون الثاني', // i18n-ok
    'شباط', // i18n-ok
    'آذار', // i18n-ok
    'نيسان', // i18n-ok
    'أيار', // i18n-ok
    'حزيران', // i18n-ok
    'تموز', // i18n-ok
    'آب', // i18n-ok
    'أيلول', // i18n-ok
    'تشرين الأول', // i18n-ok
    'تشرين الثاني', // i18n-ok
    'كانون الأول', // i18n-ok
  ];

  static const _weekdayShort = [
    'أحد', // i18n-ok
    'إثن', // i18n-ok
    'ثلا', // i18n-ok
    'أرب', // i18n-ok
    'خمي', // i18n-ok
    'جمع', // i18n-ok
    'سبت', // i18n-ok
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
              '${_months[month.month - 1].tr} ${month.year}',
              style: TextStyle(
                fontFamily: VibesFont.ui,
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
                  label.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
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
          // بلا فراغ أفقي: شريط المدة يتصل من خلية لأخرى بلا انقطاع
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
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
            final multi =
                start != null &&
                endInclusive != null &&
                endInclusive!.isAfter(start!);

            // الشريط يمتد من أول يوم حتى يوم المغادرة (أو آخر يوم)
            final bandLast = departure ?? endInclusive;
            final inBand =
                start != null &&
                bandLast != null &&
                bandLast.isAfter(start!) &&
                !date.isBefore(start!) &&
                !date.isAfter(bandLast);
            final column = index % 7;

            return _DayCell(
              date: date,
              past: pricing == null || pricing.isPast,
              available: !disabled,
              selected: isStart || isEnd,
              caption: !multi
                  ? null
                  : isStart
                  ? 'البداية'.tr
                  : isEnd
                  ? 'آخر يوم'.tr
                  : null,
              departure: _sameDate(date, departure),
              inRange:
                  inBand && !isStart && !isEnd && !_sameDate(date, departure),
              bandPrev: inBand && !isStart,
              bandNext: inBand && !_sameDate(date, bandLast),
              roundStart: column == 0 || number == 1,
              roundEnd: column == 6 || number == monthLength,
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
    this.caption,
    this.departure = false,
    this.bandPrev = false,
    this.bandNext = false,
    this.roundStart = false,
    this.roundEnd = false,
    this.onTap,
  });

  /// يوم المغادرة (بعد المسائي أو اليوم الكامل).
  final bool departure;
  final DateTime date;
  final bool past;

  /// متاح للفترة المختارة (أخضر) — وإلا غير متاح (أحمر).
  final bool available;
  final bool selected;

  /// يوم داخل المدة (بين البداية والنهاية).
  final bool inRange;

  /// عنوان صغير تحت الرقم لطرفي المدة («البداية» / «آخر يوم»).
  final String? caption;

  /// شريط المدة يتصل باليوم السابق / التالي.
  final bool bandPrev;
  final bool bandNext;

  /// طرف صف الأسبوع أو الشهر — يُدوَّر الشريط عنده.
  final bool roundStart;
  final bool roundEnd;
  final VoidCallback? onTap;

  static Color get green => themed(const Color(0xFF16A34A), VibesDark.success);
  static Color get greenDeep =>
      themed(const Color(0xFF15803D), const Color(0xFF7FDDB3));
  static Color get onGreen => themed(Colors.white, const Color(0xFF06231A));
  static Color get red => themed(const Color(0xFFDC2626), VibesDark.danger);

  /// شريط المدة: ليلاً أخضر عميق مشبع يقرأ كشريط، لا كتلة نعناع باهتة.
  static Color get band =>
      themed(const Color(0xFFDDF6E6), const Color(0xFF1C4F4A));
  static const _r = Radius.circular(14);

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (selected) {
      bg = green;
      fg = onGreen;
      border = green;
    } else if (inRange) {
      bg = Colors.transparent;
      fg = greenDeep;
      border = Colors.transparent;
    } else if (departure) {
      bg = Vibes.surface;
      fg = greenDeep;
      border = green;
    } else if (past) {
      bg = Colors.transparent;
      fg = placeInk2.withValues(alpha: .3);
      border = Colors.transparent;
    } else if (available) {
      bg = green.withValues(alpha: .10);
      fg = greenDeep;
      border = green.withValues(alpha: .35);
    } else {
      bg = red.withValues(alpha: .08);
      fg = red;
      border = red.withValues(alpha: .28);
    }

    Widget half(bool on, {required bool startSide}) => Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: on ? band : band.withValues(alpha: 0),
          borderRadius: BorderRadiusDirectional.horizontal(
            start: startSide && roundStart ? _r : Radius.zero,
            end: !startSide && roundEnd ? _r : Radius.zero,
          ),
        ),
      ),
    );

    // «Check-out» لا تتسع في خلية اليوم، فالاختصار للإنجليزية فقط.
    final label = departure && !selected
        ? (I18n.isEn ? 'Out' : 'مغادرة') // i18n-ok
        : caption;

    final number = Text(
      '${date.day}',
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: label != null ? 13.5 : 15,
        fontWeight: FontWeight.w800,
        color: fg,
        height: 1.1,
      ),
    );

    final Widget content;
    if (label != null) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          number,
          Builder(
            builder: (_) {
              final text = Text(
                label,
                maxLines: I18n.isEn ? 1 : null,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? onGreen.withValues(alpha: .92) : fg,
                  height: 1.25,
                ),
              );
              return I18n.isEn
                  ? FittedBox(fit: BoxFit.scaleDown, child: text)
                  : text;
            },
          ),
        ],
      );
    } else if (selected) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_rounded, size: 14, color: onGreen),
          const SizedBox(width: 2),
          number,
        ],
      );
    } else if (inRange) {
      // نقطة صغيرة تؤكد أن اليوم ضمن المدة
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          number,
          const SizedBox(height: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: green, shape: BoxShape.circle),
          ),
        ],
      );
    } else {
      content = number;
    }

    return Semantics(
      button: !past,
      selected: selected || inRange,
      label: past
          ? '${date.day} '
          : available
          ? '{day} متاح'.trArgs({'day': date.day})
          : '{day} غير متاح'.trArgs({'day': date.day}),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // شريط المدة خلف الأيام — متصل عبر الأسبوع
          Row(
            children: [
              half(bandPrev, startSide: true),
              half(bandNext, startSide: false),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
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
                            color: green.withValues(
                              alpha: Appearance.isDark ? .22 : .35,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: content,
              ),
            ),
          ),
        ],
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
        color: themed(const Color(0xFFF3F4F7), VibesDark.surfaceMuted),
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
                    color: s == selected
                        ? themed(Colors.white, VibesDark.hairline)
                        : Colors.transparent,
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
                          Flexible(
                            child: Text(
                              name(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: s == selected ? placeInk : placeInk2,
                              ),
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
          style: TextStyle(
            fontFamily: VibesFont.ui,
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
        item(_DayCell.green, 'متاح'.tr),
        const SizedBox(width: 22),
        item(_DayCell.red, 'غير متاح'.tr),
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
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: placeInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '{shift} محجوزة في هذا اليوم، لكن يمكنك الحجز في:'.trArgs({
              'shift': unavailable,
            }),
            style: TextStyle(
              fontFamily: VibesFont.ui,
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
                color: themed(Colors.white, VibesDark.surfaceMuted),
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
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: placeInk,
                                ),
                              ),
                              if (o.time != null)
                                Text(
                                  o.time!,
                                  style: TextStyle(
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
            child: Text(
              'اختيار يوم آخر'.tr,
              style: TextStyle(
                fontFamily: VibesFont.ui,
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
    final stay = ready && !singleDay && days > 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Vibes.surface,
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
              if (stay) ...[
                _StayStrip(
                  from: dateLabel(start!),
                  to: departureLabel ?? dateLabel(endInclusive!),
                  toTitle: departureLabel != null
                      ? 'المغادرة'.tr
                      : 'آخر يوم'.tr,
                  days: days,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        periodLabel ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: placeInk2,
                        ),
                      ),
                    ),
                    PlaceFullPriceText(total, size: 18),
                  ],
                ),
              ] else
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
                                      ? 'اختر يوم المغادرة'.tr
                                      : (singleDay
                                            ? 'اضغط يوماً واحداً'.tr
                                            : 'اختر يوم الوصول'.tr)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
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
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: placeInk2,
                              ),
                            ),
                          if (ready && departureLabel != null)
                            Text(
                              'المغادرة: {date}'.trArgs({
                                'date': departureLabel,
                              }),
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _DayCell.greenDeep,
                              ),
                            ),
                          if (ready && !singleDay)
                            Text(
                              days > 1
                                  ? '{n} أيام'.trN(days)
                                  : 'لأكثر من يوم: اضغط على يوم النهاية'.tr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
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
                    foregroundColor: themed(Colors.white, Brand.midnight),
                    disabledBackgroundColor: context.world.accentDeep
                        .withValues(alpha: .25),
                    disabledForegroundColor: Appearance.isDark
                        ? VibesDark.inkSecondary
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: ready ? onConfirm : null,
                  child: Text(
                    ready ? 'اعتماد الموعد'.tr : 'اختر موعداً للمتابعة'.tr,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
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

/// شريط الإقامة لعدة أيام: البداية ←  عدد الأيام  → المغادرة.
class _StayStrip extends StatelessWidget {
  const _StayStrip({
    required this.from,
    required this.to,
    required this.toTitle,
    required this.days,
  });

  final String from;
  final String to;
  final String toTitle;
  final int days;

  static Color get green => _DayCell.green;
  static Color get greenDeep => _DayCell.greenDeep;
  static Color get background =>
      themed(const Color(0xFFF1FBF4), const Color(0xFF15363A));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Expanded(child: _end('البداية'.tr, from, CrossAxisAlignment.start)),
          // الخط الواصل وعدد الأيام في المنتصف
          Expanded(
            child: Row(
              children: [
                const _Dot(),
                Expanded(
                  child: Container(
                    height: 2,
                    color: green.withValues(alpha: .35),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: I18n.isEn ? 7 : 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: green,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: green.withValues(
                          alpha: Appearance.isDark ? .18 : .3,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '{n} أيام'.trN(days),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: I18n.isEn ? 10.5 : 11.5,
                      fontWeight: FontWeight.w900,
                      color: _DayCell.onGreen,
                      height: 1.3,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: green.withValues(alpha: .35),
                  ),
                ),
                const _Dot(hollow: true),
              ],
            ),
          ),
          Expanded(child: _end(toTitle, to, CrossAxisAlignment.end)),
        ],
      ),
    );
  }

  Widget _end(String title, String label, CrossAxisAlignment align) {
    // «الأربعاء 4 تشرين الثاني» → اسم اليوم فوق والتاريخ تحته
    final space = label.indexOf(' ');
    // الإنجليزية: «Wed, Nov 4» — الفاصلة لا تظهر حين يصبح اليوم سطراً مستقلاً.
    final weekday = (space > 0 ? label.substring(0, space) : label).replaceAll(
      ',',
      '',
    );
    final date = space > 0 ? label.substring(space + 1) : '';
    final textAlign = align == CrossAxisAlignment.start
        ? TextAlign.start
        : TextAlign.end;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: greenDeep,
            height: 1.2,
          ),
        ),
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: placeInk,
            height: 1.35,
          ),
        ),
        Text(
          weekday,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: placeInk2,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.hollow = false});

  final bool hollow;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: hollow
          ? themed(Colors.white, _StayStrip.background)
          : _StayStrip.green,
      shape: BoxShape.circle,
      border: Border.all(color: _StayStrip.green, width: 2),
    ),
  );
}

String _short(String s) => s.length > 3 ? s.substring(0, 3) : s;
