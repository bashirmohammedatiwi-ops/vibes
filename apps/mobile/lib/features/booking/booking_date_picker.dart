import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

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

Future<BookingDateSelection?> showBookingDatePicker({
  required BuildContext context,
  required String propertyName,
  required AvailabilityData availability,
  required ShiftType shift,
  DateTime? initialStart,
  DateTime? initialEndExclusive,
}) {
  return showModalBottomSheet<BookingDateSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BookingDatePickerSheet(
      propertyName: propertyName,
      availability: availability,
      shift: shift,
      initialStart: initialStart,
      initialEndExclusive: initialEndExclusive,
    ),
  );
}

class _BookingDatePickerSheet extends StatefulWidget {
  const _BookingDatePickerSheet({
    required this.propertyName,
    required this.availability,
    required this.shift,
    this.initialStart,
    this.initialEndExclusive,
  });

  final String propertyName;
  final AvailabilityData availability;
  final ShiftType shift;
  final DateTime? initialStart;
  final DateTime? initialEndExclusive;

  @override
  State<_BookingDatePickerSheet> createState() =>
      _BookingDatePickerSheetState();
}

class _BookingDatePickerSheetState extends State<_BookingDatePickerSheet> {
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

  @override
  void initState() {
    super.initState();
    _start = _dateOnly(widget.initialStart);
    final initialEnd = widget.initialEndExclusive;
    if (initialEnd != null && _start != null) {
      _endInclusive = _dateOnly(initialEnd.subtract(const Duration(days: 1)));
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
        pricing.isBooked ||
        pricing.priceFor(widget.shift) <= 0) {
      return true;
    }
    return widget.availability.isBlocked(date, widget.shift);
  }

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
    Navigator.pop(
      context,
      BookingDateSelection(
        start: _start!,
        endExclusive: _endInclusive!.add(const Duration(days: 1)),
        estimatedTotal: _estimatedTotal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _monthGroups;
    final height = MediaQuery.sizeOf(context).height * .92;

    return SizedBox(
      height: height.clamp(620, 820),
      child: Column(
        children: [
          const MaisonSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MaisonIconWell(
                  icon: Icons.calendar_month_outlined,
                  size: 46,
                  color: Vibes.coral,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختر موعدك',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.propertyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _QuickDateChip(
                  label: 'أقرب موعد',
                  icon: Icons.bolt_rounded,
                  onTap: () => _pickQuick(_QuickPick.nearest),
                ),
                const SizedBox(width: 8),
                _QuickDateChip(
                  label: 'نهاية الأسبوع',
                  icon: Icons.weekend_outlined,
                  onTap: () => _pickQuick(_QuickPick.weekend),
                ),
                const SizedBox(width: 8),
                _QuickDateChip(
                  label: 'يومان',
                  icon: Icons.date_range_outlined,
                  onTap: () => _pickQuick(_QuickPick.twoDays),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _CalendarLegend(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: ShapeDecoration(
                  color: SemanticColors.danger.withValues(alpha: .08),
                  shape: const RoundedRectangleBorder(
                    borderRadius: Folio.compact,
                  ),
                ),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: SemanticColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Expanded(
            child: groups.isEmpty
                ? const EmptyCanvas(
                    icon: Icons.event_busy_outlined,
                    title: 'لا مواعيد متاحة',
                    subtitle: 'جرّب لاحقاً أو تواصل مع المالك',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(),
                    ),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _MonthCalendar(
                        month: group.month,
                        days: group.days,
                        shift: widget.shift,
                        availability: widget.availability,
                        start: _start,
                        endInclusive: _endInclusive,
                        onSelect: _select,
                      );
                    },
                  ),
          ),
          _SelectionSummary(
            start: _start,
            endInclusive: _endInclusive,
            days: _selectedDays,
            total: _estimatedTotal,
            dateLabel: _longDate,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
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

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const RoundedRectangleBorder(borderRadius: Folio.compact),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          color: VibesTheme.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.compact,
            side: BorderSide(color: VibesTheme.hairlineOf(context)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Vibes.teal),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _LegendItem(
            color: VibesTheme.actionOf(context),
            label: 'اختيارك',
          ),
          const SizedBox(width: 14),
          _LegendItem(
            color: VibesTheme.surfaceOf(context),
            border: VibesTheme.hairlineStrongOf(context),
            label: 'متاح',
          ),
          const SizedBox(width: 14),
          _LegendItem(
            color: VibesTheme.surfaceHighOf(context),
            label: 'غير متاح',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Folio.compact,
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: VibesTheme.textTertiaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.days,
    required this.shift,
    required this.availability,
    required this.start,
    required this.endInclusive,
    required this.onSelect,
  });

  final DateTime month;
  final List<DayPricing> days;
  final ShiftType shift;
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
        Row(
          children: [
            Container(width: 3, height: 22, color: Vibes.coral),
            const SizedBox(width: 10),
            Text(
              '${_months[month.month - 1]} ${month.year}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final label in _weekdayShort)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
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
            childAspectRatio: .76,
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
                pricing.isBooked ||
                pricing.priceFor(shift) <= 0 ||
                availability.isBlocked(date, shift);
            final isStart = _sameDate(date, start);
            final isEnd = _sameDate(date, endInclusive);
            final inRange =
                start != null &&
                endInclusive != null &&
                date.isAfter(start!) &&
                date.isBefore(endInclusive!);

            return _BookingDayCell(
              date: date,
              pricing: pricing,
              shift: shift,
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

class _BookingDayCell extends StatelessWidget {
  const _BookingDayCell({
    required this.date,
    required this.pricing,
    required this.shift,
    required this.disabled,
    required this.selected,
    required this.inRange,
    this.onTap,
  });

  final DateTime date;
  final DayPricing? pricing;
  final ShiftType shift;
  final bool disabled;
  final bool selected;
  final bool inRange;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      customBorder: const RoundedRectangleBorder(borderRadius: Folio.compact),
      child: AnimatedContainer(
        duration: VibesMotion.fast,
        decoration: ShapeDecoration(
          color: selected
              ? VibesTheme.actionOf(context)
              : inRange
              ? (VibesTheme.isDark(context)
                    ? VibesDark.coralMint
                    : Vibes.coralMint)
              : disabled
              ? VibesTheme.surfaceHighOf(context).withValues(alpha: .65)
              : VibesTheme.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.compact,
            side: BorderSide(
              color: selected
                  ? VibesTheme.actionOf(context)
                  : inRange
                  ? Vibes.teal.withValues(alpha: .28)
                  : VibesTheme.hairlineOf(context),
            ),
          ),
        ),
        child: Opacity(
          opacity: disabled ? .38 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? VibesTheme.onActionOf(context)
                      : VibesTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              if (disabled)
                Icon(
                  pricing?.isBooked == true
                      ? Icons.lock_outline_rounded
                      : Icons.remove_rounded,
                  size: 10,
                  color: selected
                      ? VibesTheme.onActionOf(context)
                      : VibesTheme.textTertiaryOf(context),
                )
              else
                Text(
                  _shortPrice(pricing!.priceFor(shift)),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white70 : Vibes.teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortPrice(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}م';
    }
    if (value >= 1000) return '${(value / 1000).round()}أ';
    return '$value';
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.start,
    required this.endInclusive,
    required this.days,
    required this.total,
    required this.dateLabel,
    required this.onConfirm,
  });

  final DateTime? start;
  final DateTime? endInclusive;
  final int days;
  final num total;
  final String Function(DateTime date) dateLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final ready = start != null && endInclusive != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VibesTheme.surfaceOf(context),
        border: Border(top: BorderSide(color: VibesTheme.hairlineOf(context))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101B3857),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
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
                              ? days == 1
                                    ? dateLabel(start!)
                                    : '${dateLabel(start!)} — ${dateLabel(endInclusive!)}'
                              : 'اختر اليوم الأول',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (ready)
                          Text(
                            '$days ${days == 1 ? 'يوم' : 'أيام'} · سعر تقديري',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (ready) PriceText(total, compact: true),
                ],
              ),
              const SizedBox(height: 11),
              VibesButton(
                label: ready ? 'اعتماد الموعد' : 'اختر موعداً للمتابعة',
                icon: Icons.arrow_back_rounded,
                onPressed: ready ? onConfirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
