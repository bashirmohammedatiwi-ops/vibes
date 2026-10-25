import '../../core/theme/world_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/models/models.dart';
import '../booking/booking_date_picker.dart';
import 'place_booking_sheets.dart';
import 'place_experience_ui.dart';
import 'shift_calendar_ui.dart';

/// نتيجة معالج الحجز الموحّد.
class PlaceBookingDraft {
  const PlaceBookingDraft({
    required this.shift,
    required this.guests,
    required this.start,
    required this.endExclusive,
    this.fullDayMulti = false,
    this.estimatedTotal,
  });

  final ShiftType shift;
  final int guests;
  final DateTime start;
  final DateTime endExclusive;
  final bool fullDayMulti;
  final num? estimatedTotal;

  BookingDatePickMode get dateMode =>
      fullDayMulti ? BookingDatePickMode.range : BookingDatePickMode.singleDay;
}

enum PlaceBookingWizardStep { period, guests, dates, review }

/// معالج حجز: فترة → ضيوف → تاريخ (مضمّن) → مراجعة.
Future<PlaceBookingDraft?> showPlaceBookingWizard({
  required BuildContext context,
  required Property property,
  required List<DayPricing> dayPrices,
  required Future<AvailabilityData> Function() loadAvailability,
  ShiftType? initialShift,
  int initialGuests = 2,
  DateTime? initialStart,
  DateTime? initialEndExclusive,
  bool? initialFullDayMulti,
  PlaceBookingWizardStep startAt = PlaceBookingWizardStep.period,
  bool editOnly = false,
}) {
  return showModalBottomSheet<PlaceBookingDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PlaceBookingWizardSheet(
      property: property,
      dayPrices: dayPrices,
      loadAvailability: loadAvailability,
      initialShift: initialShift,
      initialGuests: initialGuests,
      initialStart: initialStart,
      initialEndExclusive: initialEndExclusive,
      initialFullDayMulti: initialFullDayMulti,
      startAt: startAt,
      editOnly: editOnly,
    ),
  );
}

class _PlaceBookingWizardSheet extends StatefulWidget {
  const _PlaceBookingWizardSheet({
    required this.property,
    required this.dayPrices,
    required this.loadAvailability,
    required this.startAt,
    required this.editOnly,
    this.initialShift,
    this.initialGuests = 2,
    this.initialStart,
    this.initialEndExclusive,
    this.initialFullDayMulti,
  });

  final Property property;
  final List<DayPricing> dayPrices;
  final Future<AvailabilityData> Function() loadAvailability;
  final ShiftType? initialShift;
  final int initialGuests;
  final DateTime? initialStart;
  final DateTime? initialEndExclusive;
  final bool? initialFullDayMulti;
  final PlaceBookingWizardStep startAt;
  final bool editOnly;

  @override
  State<_PlaceBookingWizardSheet> createState() =>
      _PlaceBookingWizardSheetState();
}

class _PlaceBookingWizardSheetState extends State<_PlaceBookingWizardSheet> {
  late PlaceBookingWizardStep _step;
  ShiftType? _shift;
  bool? _fullDayMulti;
  late int _guests;
  DateTime? _start;
  DateTime? _end;
  num? _estimatedTotal;
  AvailabilityData? _availability;
  bool _loadingDates = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.startAt;
    _shift = widget.initialShift;
    _guests = widget.initialGuests.clamp(1, _maxGuests);
    _start = widget.initialStart;
    _end = widget.initialEndExclusive;
    _fullDayMulti = widget.initialFullDayMulti;
    if (_shift == ShiftType.full &&
        _fullDayMulti == null &&
        _start != null &&
        _end != null) {
      _fullDayMulti = _end!.difference(_start!).inDays > 1;
    }
    if (!widget.property.supportsShifts) {
      _shift = ShiftType.full;
    }
    if (_step == PlaceBookingWizardStep.dates) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureAvailability(),
      );
    }
    if (_step == PlaceBookingWizardStep.review &&
        (_start == null || _end == null)) {
      _step = PlaceBookingWizardStep.dates;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureAvailability(),
      );
    }
  }

  int get _maxGuests {
    final c = widget.property.capacity;
    return c > 0 ? c : 200;
  }

  int get _stepIndex => switch (_step) {
    PlaceBookingWizardStep.period => 0,
    PlaceBookingWizardStep.guests => 1,
    PlaceBookingWizardStep.dates => 2,
    PlaceBookingWizardStep.review => 3,
  };

  String get _title => switch (_step) {
    PlaceBookingWizardStep.period => 'اختر الفترة',
    PlaceBookingWizardStep.guests => 'كم عدد الضيوف؟',
    PlaceBookingWizardStep.dates =>
      _fullDayMulti == true ? 'اختر مدة الإقامة' : 'اختر اليوم',
    PlaceBookingWizardStep.review => 'راجع حجزك',
  };

  String? get _subtitle => switch (_step) {
    PlaceBookingWizardStep.period =>
      widget.property.supportsShifts
          ? 'اختر الفترة — ننتقل تلقائياً للخطوة التالية'
          : 'حدّد مدة الإقامة ثم أكمل',
    PlaceBookingWizardStep.guests =>
      widget.property.capacity > 0
          ? 'سعة المكان ${widget.property.capacity} — اكتب الرقم من الكيبورد'
          : 'اكتب العدد أو استخدم الاختصارات',
    PlaceBookingWizardStep.dates => _dateSubtitle,
    PlaceBookingWizardStep.review => 'يمكنك تعديل أي بند قبل التأكيد',
  };

  String get _dateSubtitle {
    final s = _shift;
    if (s == ShiftType.morning) {
      return 'يوم واحد · المغادرة تلقائياً في اليوم التالي';
    }
    if (s == ShiftType.evening) {
      return 'يوم واحد · المغادرة تُضبط لليوم التالي تلقائياً';
    }
    if (_fullDayMulti == true) {
      return 'اختر يوم الوصول ثم يوم المغادرة';
    }
    return 'يوم واحد · المغادرة تلقائياً في اليوم التالي';
  }

  Future<void> _ensureAvailability() async {
    if (_availability != null) return;
    setState(() {
      _loadingDates = true;
      _error = null;
    });
    try {
      _availability = await widget.loadAvailability();
      if (!mounted) return;
      setState(() => _loadingDates = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDates = false;
        _error = 'تعذر تحميل المواعيد — حاول مجدداً';
      });
    }
  }

  void _selectShift(ShiftType s) {
    HapticFeedback.selectionClick();
    setState(() {
      _shift = s;
      _error = null;
      if (s != ShiftType.full) {
        _fullDayMulti = false;
      } else {
        _fullDayMulti = null;
      }
      _start = null;
      _end = null;
      _estimatedTotal = null;
    });
    // صباحي/مسائي → انتقال تلقائي بعد لمسة قصيرة
    if (s != ShiftType.full && !widget.editOnly) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (!mounted || _shift != s) return;
        _advanceFromPeriod();
      });
    }
  }

  void _selectDuration(bool multi) {
    HapticFeedback.selectionClick();
    setState(() {
      _fullDayMulti = multi;
      _error = null;
      _start = null;
      _end = null;
      _estimatedTotal = null;
    });
    if (!widget.editOnly) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (!mounted || _fullDayMulti != multi) return;
        _advanceFromPeriod();
      });
    }
  }

  void _advanceFromPeriod() {
    if (_shift == null) return;
    if (_shift == ShiftType.full && _fullDayMulti == null) return;
    if (widget.editOnly) {
      _finishEdit();
      return;
    }
    setState(() => _step = PlaceBookingWizardStep.guests);
  }

  void _goNext() {
    HapticFeedback.selectionClick();
    if (_step == PlaceBookingWizardStep.period) {
      if (_shift == null) {
        setState(() => _error = 'اختر الفترة أولاً');
        return;
      }
      if (_shift == ShiftType.full && _fullDayMulti == null) {
        setState(() => _error = 'حدّد: يوم واحد أم أكثر؟');
        return;
      }
      _advanceFromPeriod();
      return;
    }
    if (_step == PlaceBookingWizardStep.guests) {
      if (_guests < 1) {
        setState(() => _error = 'أدخل عدد ضيوف صالحاً');
        return;
      }
      if (widget.editOnly) {
        _finishEdit();
        return;
      }
      setState(() {
        _step = PlaceBookingWizardStep.dates;
        _error = null;
      });
      _ensureAvailability();
      return;
    }
    if (_step == PlaceBookingWizardStep.review) {
      _popDraft();
    }
  }

  void _goBack() {
    if (widget.editOnly && _step != PlaceBookingWizardStep.dates) {
      Navigator.pop(context);
      return;
    }
    if (_step == PlaceBookingWizardStep.period) {
      Navigator.pop(context);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _step = switch (_step) {
        PlaceBookingWizardStep.guests => PlaceBookingWizardStep.period,
        PlaceBookingWizardStep.dates => PlaceBookingWizardStep.guests,
        PlaceBookingWizardStep.review => PlaceBookingWizardStep.dates,
        PlaceBookingWizardStep.period => PlaceBookingWizardStep.period,
      };
    });
    if (_step == PlaceBookingWizardStep.dates) {
      _ensureAvailability();
    }
  }

  void _onDatePicked(BookingDateSelection picked) {
    HapticFeedback.mediumImpact();
    setState(() {
      // الزبون قد يغيّر الفترة من أعلى التقويم مباشرة
      if (picked.shift != null && picked.shift != _shift) {
        _shift = picked.shift;
        if (_shift != ShiftType.full) _fullDayMulti = false;
      }
      _start = picked.start;
      _end = picked.endExclusive;
      _estimatedTotal = picked.estimatedTotal;
      _error = null;
    });
    if (widget.editOnly) {
      _popDraft();
      return;
    }
    setState(() => _step = PlaceBookingWizardStep.review);
  }

  void _finishEdit() {
    if (_step == PlaceBookingWizardStep.guests) {
      if (_shift != null && _start != null && _end != null) {
        _popDraft();
        return;
      }
      setState(() => _step = PlaceBookingWizardStep.dates);
      _ensureAvailability();
      return;
    }
    if (_step == PlaceBookingWizardStep.period) {
      if (_start != null && _end != null && _shift != null) {
        _popDraft();
        return;
      }
      setState(() => _step = PlaceBookingWizardStep.dates);
      _ensureAvailability();
      return;
    }
  }

  void _popDraft() {
    if (_shift == null || _start == null || _end == null) return;
    Navigator.pop(
      context,
      PlaceBookingDraft(
        shift: _shift!,
        guests: _guests,
        start: _start!,
        endExclusive: _end!,
        fullDayMulti: _fullDayMulti ?? false,
        estimatedTotal: _estimatedTotal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height =
        MediaQuery.sizeOf(context).height *
        (_step == PlaceBookingWizardStep.dates ? 0.92 : 0.88);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height.clamp(560.0, 860.0),
        child: Column(
          children: [
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: Icon(
                      _step == PlaceBookingWizardStep.period ||
                              (widget.editOnly &&
                                  _step != PlaceBookingWizardStep.dates)
                          ? Icons.close_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 20,
                      color: placeInk2,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: placeInk,
                          ),
                        ),
                        if (_subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _subtitle!,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: placeInk2,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.editOnly) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WizardProgress(active: _stepIndex),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    PlaceBookingWizardStep.period => _PeriodStep(
                      property: widget.property,
                      days: widget.dayPrices,
                      selected: _shift,
                      fullDayMulti: _fullDayMulti,
                      onSelectShift: _selectShift,
                      onSelectDuration: _selectDuration,
                    ),
                    PlaceBookingWizardStep.guests => PlaceGuestsEditor(
                      value: _guests,
                      max: _maxGuests,
                      onChanged: (v) => setState(() {
                        _guests = v;
                        _error = null;
                      }),
                    ),
                    PlaceBookingWizardStep.dates => _DatesEmbeddedStep(
                      loading: _loadingDates,
                      availability: _availability,
                      property: widget.property,
                      shift: _shift ?? ShiftType.full,
                      fullDayMulti: _fullDayMulti == true,
                      initialStart: _start,
                      initialEnd: _end,
                      onRetry: _ensureAvailability,
                      onPicked: _onDatePicked,
                    ),
                    PlaceBookingWizardStep.review => _ReviewStep(
                      property: widget.property,
                      shift: _shift!,
                      guests: _guests,
                      start: _start!,
                      endExclusive: _end!,
                      fullDayMulti: _fullDayMulti ?? false,
                      estimatedTotal: _estimatedTotal,
                      onEditPeriod: () =>
                          setState(() => _step = PlaceBookingWizardStep.period),
                      onEditGuests: () =>
                          setState(() => _step = PlaceBookingWizardStep.guests),
                      onEditDates: () {
                        setState(() => _step = PlaceBookingWizardStep.dates);
                        _ensureAvailability();
                      },
                    ),
                  },
                ),
              ),
            ),
            if (_step == PlaceBookingWizardStep.period ||
                _step == PlaceBookingWizardStep.guests ||
                _step == PlaceBookingWizardStep.review)
              PlaceSheetConfirm(
                label: switch (_step) {
                  PlaceBookingWizardStep.period => 'التالي — الضيوف',
                  PlaceBookingWizardStep.guests => 'التالي — التاريخ',
                  PlaceBookingWizardStep.review => 'تأكيد الموعد',
                  _ => 'متابعة',
                },
                onPressed: _goNext,
              ),
          ],
        ),
      ),
    );
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.active});

  final int active;

  static const _labels = ['الفترة', 'الضيوف', 'التاريخ', 'مراجعة'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= active ? context.world.accent : placeLine,
              ),
            ),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < active
                      ? context.world.accentDeep
                      : i == active
                      ? context.world.accent
                      : placePaper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= active ? Colors.transparent : placeLine,
                  ),
                ),
                child: i < active
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: i == active ? Colors.white : placeInk2,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: i <= active ? context.world.accentDeep : placeInk2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DatesEmbeddedStep extends StatelessWidget {
  const _DatesEmbeddedStep({
    required this.loading,
    required this.availability,
    required this.property,
    required this.shift,
    required this.fullDayMulti,
    required this.onRetry,
    required this.onPicked,
    this.initialStart,
    this.initialEnd,
  });

  final bool loading;
  final AvailabilityData? availability;
  final Property property;
  final ShiftType shift;
  final bool fullDayMulti;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final VoidCallback onRetry;
  final ValueChanged<BookingDateSelection> onPicked;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.4),
            SizedBox(height: 12),
            Text(
              'جاري تحميل المواعيد…',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                color: placeInk2,
              ),
            ),
          ],
        ),
      );
    }
    if (availability == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 40, color: placeInk2),
            const SizedBox(height: 10),
            const Text(
              'تعذر تحميل التقويم',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                color: placeInk,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    return BookingDatePickerPanel(
      propertyName: property.name,
      availability: availability!,
      shift: shift,
      mode: fullDayMulti
          ? BookingDatePickMode.range
          : BookingDatePickMode.singleDay,
      initialStart: initialStart,
      initialEndExclusive: initialEnd,
      embedded: true,
      autoConfirmSingleDay: !fullDayMulti,
      shiftTimes: property.shiftLabels,
      onConfirm: onPicked,
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.property,
    required this.shift,
    required this.guests,
    required this.start,
    required this.endExclusive,
    required this.fullDayMulti,
    required this.estimatedTotal,
    required this.onEditPeriod,
    required this.onEditGuests,
    required this.onEditDates,
  });

  final Property property;
  final ShiftType shift;
  final int guests;
  final DateTime start;
  final DateTime endExclusive;
  final bool fullDayMulti;
  final num? estimatedTotal;
  final VoidCallback onEditPeriod;
  final VoidCallback onEditGuests;
  final VoidCallback onEditDates;

  @override
  Widget build(BuildContext context) {
    final timeline = placeStayTimelineLabels(
      property,
      shift,
      start,
      endExclusive,
    );
    final shiftLabel = switch (shift) {
      ShiftType.morning => 'الفترة الصباحية',
      ShiftType.evening => 'الفترة المسائية',
      ShiftType.full => fullDayMulti ? 'يوم كامل · عدة أيام' : 'يوم كامل',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          // خط زمني وصول / مغادرة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: placePaper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _TimelineRow(
                  icon: Icons.login_rounded,
                  tint: placeShiftColor(shift),
                  title: 'الوصول',
                  value: timeline.arrival,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 19),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(width: 2, height: 18, color: placeLine),
                  ),
                ),
                _TimelineRow(
                  icon: Icons.logout_rounded,
                  tint: placeInk,
                  title: 'المغادرة',
                  value: timeline.departure,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ReviewEditable(
            icon: Icons.schedule_rounded,
            tint: placeShiftColor(shift),
            label: 'الفترة',
            value: shiftLabel,
            onEdit: onEditPeriod,
          ),
          _ReviewEditable(
            icon: Icons.groups_rounded,
            tint: placeBrass,
            label: 'الضيوف',
            value: guests == 1 ? 'ضيف واحد' : '$guests ضيوف',
            onEdit: onEditGuests,
          ),
          _ReviewEditable(
            icon: Icons.calendar_month_rounded,
            tint: placeInk,
            label: 'الموعد',
            value: placeFormatDateRange(start, endExclusive),
            onEdit: onEditDates,
          ),
          if (estimatedTotal != null && estimatedTotal! > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: placeLine),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تقدير قبل الكوبون',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: placeInk2,
                      ),
                    ),
                  ),
                  PlaceFullPriceText(estimatedTotal!, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: placeInk2,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: placeInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewEditable extends StatelessWidget {
  const _ReviewEditable({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onEdit();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: placeLine),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: placeInk2,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: placeInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'تعديل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: placeBrass,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodStep extends StatelessWidget {
  const _PeriodStep({
    required this.property,
    required this.days,
    required this.selected,
    required this.fullDayMulti,
    required this.onSelectShift,
    required this.onSelectDuration,
  });

  final Property property;
  final List<DayPricing> days;
  final ShiftType? selected;
  final bool? fullDayMulti;
  final ValueChanged<ShiftType> onSelectShift;
  final ValueChanged<bool> onSelectDuration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShiftOptionsInline(
            property: property,
            days: days,
            selected: selected,
            onSelect: onSelectShift,
          ),
          if (selected == ShiftType.full) ...[
            const SizedBox(height: 18),
            const Text(
              'كم يوماً تريد؟',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: placeInk,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DurationCard(
                    title: 'يوم واحد',
                    subtitle: 'مغادرة الغد تلقائياً',
                    icon: Icons.today_rounded,
                    selected: fullDayMulti == false,
                    onTap: () => onSelectDuration(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DurationCard(
                    title: 'أكثر من يوم',
                    subtitle: 'تختار الوصول والمغادرة',
                    icon: Icons.date_range_rounded,
                    selected: fullDayMulti == true,
                    onTap: () => onSelectDuration(true),
                  ),
                ),
              ],
            ),
          ],
          if (selected == ShiftType.morning ||
              selected == ShiftType.evening) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: placePaper,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    selected == ShiftType.evening
                        ? Icons.nights_stay_outlined
                        : Icons.wb_sunny_outlined,
                    size: 20,
                    color: placeShiftColor(selected!),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected == ShiftType.evening
                          ? 'المسائي يوم واحد — المغادرة غداً تلقائياً'
                          : 'الصباحي يوم واحد — المغادرة غداً تلقائياً',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: placeInk2,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.world.accentDeep : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? context.world.accentDeep : placeLine,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: selected ? Colors.white : placeInk),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : placeInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.78)
                      : placeInk2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftOptionsInline extends StatelessWidget {
  const _ShiftOptionsInline({
    required this.property,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final Property property;
  final List<DayPricing> days;
  final ShiftType? selected;
  final ValueChanged<ShiftType> onSelect;

  @override
  Widget build(BuildContext context) {
    final labels = property.shiftLabels;
    final availability = computeShiftAvailability(days);
    final options = <(ShiftType, String, String?, IconData, Color, num)>[
      (
        ShiftType.morning,
        'الفترة الصباحية',
        labels.morning,
        Icons.wb_sunny_outlined,
        placeShiftMorning,
        property.priceMorningShift ?? 0,
      ),
      (
        ShiftType.evening,
        'الفترة المسائية',
        labels.evening,
        Icons.dark_mode_outlined,
        placeShiftEvening,
        property.priceEveningShift ?? 0,
      ),
      (
        ShiftType.full,
        'اليوم الكامل',
        null,
        Icons.calendar_today_rounded,
        placeShiftFull,
        property.pricePerDay,
      ),
    ];
    final visible = property.supportsShifts
        ? options
              .where((o) => o.$1 != ShiftType.full || property.supportsFullDay)
              .toList()
        : options.where((o) => o.$1 == ShiftType.full).toList();

    return Column(
      children: [
        for (final (type, title, time, icon, tint, price) in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WizardShiftTile(
              icon: icon,
              tint: tint,
              title: title,
              time: time,
              price: price,
              availability: availability[type]!,
              selected: selected == type,
              onTap: () => onSelect(type),
            ),
          ),
      ],
    );
  }
}

class _WizardShiftTile extends StatelessWidget {
  const _WizardShiftTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.time,
    required this.price,
    required this.availability,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? time;
  final num price;
  final PlaceShiftAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = availability.isAvailable;
    return Material(
      color: selected ? tint.withValues(alpha: 0.07) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? tint : placeLine,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Opacity(
            opacity: available ? 1 : 0.5,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? tint : tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : tint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: placeInk,
                        ),
                      ),
                      if (time != null && time!.isNotEmpty)
                        Text(
                          time!,
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
                if (price > 0) PlaceFullPriceText(price, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
