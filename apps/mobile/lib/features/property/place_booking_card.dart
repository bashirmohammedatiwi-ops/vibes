import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/world_ui.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../auth/auth_controller.dart';
import 'place_experience_ui.dart';
import 'shift_calendar_ui.dart';
import 'place_booking_sheets.dart';
import 'place_booking_wizard.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_date_picker.dart';
import '../../shared/widgets/maison_chrome.dart';

/// بطاقة الحجز — تدفق عملي: فترة → ضيوف → تاريخ، ثم تعديل سهل لأي بند.
class PlaceBookingCard extends ConsumerStatefulWidget {
  const PlaceBookingCard({
    super.key,
    required this.property,
    required this.accent,
    required this.dayPrices,
    this.initialDate,
    this.initialShift,
  });

  final Property property;
  final Color accent;
  final List<DayPricing> dayPrices;
  final DateTime? initialDate;
  final ShiftType? initialShift;

  @override
  ConsumerState<PlaceBookingCard> createState() => PlaceBookingCardState();
}

class PlaceBookingCardState extends ConsumerState<PlaceBookingCard> {
  ShiftType _shift = ShiftType.full;
  DateTime? _start;
  DateTime? _end;
  int _guests = 2;
  bool _fullDayMulti = false;

  Map<String, dynamic>? _quote;
  bool _quoting = false;
  String? _quoteError;
  bool _loadingWizard = false;
  AvailabilityData? _fullAvailability;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _shift = widget.initialShift ?? ShiftType.full;
    // مكان بالشفتات فقط لا يقبل «يوم كامل» — الافتراضي صباحي
    if (_shift == ShiftType.full && !widget.property.supportsFullDay) {
      _shift = ShiftType.morning;
    }
    if (widget.initialShift == null && widget.property.supportsShifts) {
      final avail = computeShiftAvailability(widget.dayPrices);
      ShiftType? cheapest;
      num? cheapestPrice;
      for (final s in [ShiftType.morning, ShiftType.evening, ShiftType.full]) {
        if (!avail[s]!.isAvailable) continue;
        if (s == ShiftType.full && !widget.property.supportsFullDay) continue;
        final price = switch (s) {
          ShiftType.morning => widget.property.priceMorningShift ?? 0,
          ShiftType.evening => widget.property.priceEveningShift ?? 0,
          ShiftType.full => widget.property.pricePerDay,
        };
        if (price <= 0) continue;
        if (cheapestPrice == null || price < cheapestPrice) {
          cheapestPrice = price;
          cheapest = s;
        }
      }
      if (cheapest != null) _shift = cheapest;
    }
    if (widget.initialDate != null) {
      _start = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      _end = _start!.add(const Duration(days: 1));
      _fullDayMulti = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuote());
    }
  }

  bool get _datesReady => _start != null && _end != null;
  bool get _ready => _datesReady;

  num? get _quoteTotal {
    final q = _quote;
    if (q == null) return null;
    final raw = q['totalPrice'] ?? q['total'];
    if (raw is num) return raw;
    return num.tryParse('$raw');
  }

  num? get _quoteOriginalTotal {
    final q = _quote;
    if (q == null) return null;
    final raw = q['originalTotal'] ?? q['original_total'];
    if (raw is num) return raw;
    return num.tryParse('$raw');
  }

  num? get _quoteDiscount {
    final q = _quote;
    if (q == null) return null;
    final raw = q['discount'];
    if (raw is num) return raw;
    return num.tryParse('$raw');
  }

  String get _shiftLabel => switch (_shift) {
    ShiftType.morning => 'الفترة الصباحية',
    ShiftType.evening => 'الفترة المسائية',
    ShiftType.full => _fullDayMulti ? 'يوم كامل · عدة أيام' : 'يوم كامل',
  };

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetchQuote() async {
    if (!_datesReady) return;
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final data =
          await client.post(
                '/api/bookings/quote',
                body: {
                  'propertyId': widget.property.id,
                  'startDate': _dateKey(_start!),
                  'endDate': _dateKey(_end!),
                  'shift': _shift.name.toUpperCase(),
                },
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _quote = data;
        _quoting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quoting = false;
        // رسالة الخادم أوضح (موعد محجوز، شفت غير متاح…) من رسالة عامة
        final msg = maisonError(e);
        _quoteError = msg.trim().isEmpty ? 'تعذر حساب السعر — حاول مجدداً' : msg;
      });
    }
  }

  Future<AvailabilityData> _loadFullAvailability() async {
    if (_fullAvailability != null) return _fullAvailability!;
    final now = DateTime.now();
    final months = List.generate(5, (index) {
      final m = DateTime(now.year, now.month + index);
      return '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
    });
    final results = await Future.wait(
      months.map(
        (month) => ref.read(
          availabilityProvider((id: widget.property.id, month: month)).future,
        ),
      ),
    );
    final slots = <String>{};
    final days = <String, DayPricing>{};
    for (final r in results) {
      slots.addAll(r.slots);
      for (final day in r.dayPrices) {
        days[_dateKey(day.date)] = day;
      }
    }
    final dayPrices = days.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    _fullAvailability = AvailabilityData(
      slots: slots,
      dayPrices: dayPrices,
      bookingMode: results.firstOrNull?.bookingMode,
    );
    return _fullAvailability!;
  }

  Future<void> _applyDraft(PlaceBookingDraft draft) async {
    setState(() {
      _shift = draft.shift;
      _guests = draft.guests;
      _start = draft.start;
      _end = draft.endExclusive;
      _fullDayMulti = draft.fullDayMulti;
      _quote = null;
    });
    await _fetchQuote();
  }

  /// يُستدعى من الشريط السفلي في صفحة المكان.
  Future<void> openWizard() => _startWizard();

  Future<void> _startWizard({
    PlaceBookingWizardStep startAt = PlaceBookingWizardStep.period,
    bool editOnly = false,
  }) async {
    if (_loadingWizard) return;
    setState(() => _loadingWizard = true);
    try {
      // حمّل التوفر مسبقاً لخطوة التاريخ
      await _loadFullAvailability();
    } catch (_) {
      // المعالج سيحاول مجدداً
    }
    if (!mounted) return;
    setState(() => _loadingWizard = false);

    final draft = await showPlaceBookingWizard(
      context: context,
      property: widget.property,
      dayPrices: _fullAvailability?.dayPrices ?? widget.dayPrices,
      loadAvailability: _loadFullAvailability,
      initialShift: _shift,
      initialGuests: _guests,
      initialStart: _start,
      initialEndExclusive: _end,
      initialFullDayMulti: _fullDayMulti,
      startAt: startAt,
      editOnly: editOnly,
    );
    if (draft == null || !mounted) return;
    await _applyDraft(draft);
  }

  Future<void> _editDatesOnly() async {
    setState(() => _loadingWizard = true);
    AvailabilityData availability;
    try {
      availability = await _loadFullAvailability();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingWizard = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحميل المواعيد: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _loadingWizard = false);

    final mode = (_shift == ShiftType.full && _fullDayMulti)
        ? BookingDatePickMode.range
        : BookingDatePickMode.singleDay;

    final picked = await showBookingDatePicker(
      context: context,
      propertyName: widget.property.name,
      availability: availability,
      shift: _shift,
      initialStart: _start,
      initialEndExclusive: _end,
      mode: mode,
      shiftTimes: widget.property.shiftLabels,
    );
    if (picked == null || !mounted) return;
    setState(() {
      // الفترة قد تتغير من أعلى التقويم
      if (picked.shift != null) {
        _shift = picked.shift!;
        if (_shift != ShiftType.full) _fullDayMulti = false;
      }
      _start = picked.start;
      _end = picked.endExclusive;
      _quote = null;
    });
    _fetchQuote();
  }

  Future<void> _reserve() async {
    if (!_datesReady || _submitting) return;
    if (!ref.read(authControllerProvider).loggedIn) {
      final ok = await context.push<bool>('/login');
      if (ok != true || !mounted) return;
      if (!ref.read(authControllerProvider).loggedIn) return;
    }
    setState(() => _submitting = true);
    try {
      final client = ref.read(apiClientProvider);
      final created =
          await client.post(
                '/api/bookings',
                body: {
                  'propertyId': widget.property.id,
                  'startDate': _dateKey(_start!),
                  'endDate': _dateKey(_end!),
                  'shift': _shift.name.toUpperCase(),
                  'guests': _guests,
                },
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // الحجز الجديد يظهر فوراً في «حجوزاتي» كبانتظار التأكيد
      ref.invalidate(myBookingsProvider);
      final bookingId = created['id'] as String?;
      if (bookingId == null) {
        context.pushReplacement('/booking-success');
        return;
      }
      try {
        final conv = await client.post(
          '/api/conversations/booking',
          body: {'bookingId': bookingId},
        );
        if (!mounted) return;
        final conversationId = (conv as Map<String, dynamic>)['id'] as String?;
        context.pushReplacement(
          conversationId != null
              ? '/chat/$conversationId?pay=$bookingId'
              : '/booking-success?id=$bookingId',
        );
      } catch (_) {
        if (!mounted) return;
        context.pushReplacement('/booking-success?id=$bookingId');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء الحجز — حاول مجدداً')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final accent = widget.accent;
    final total = _quoteTotal;
    final nights = _datesReady
        ? _end!.difference(_start!).inDays.clamp(1, 365)
        : null;

    final world = context.world;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: world.accent.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: world.glow.withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس البطاقة — صبغة العالم وسعر البداية
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [world.canvasTint, Colors.white],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: world.fill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _ready
                        ? Icons.receipt_long_rounded
                        : Icons.event_available_rounded,
                    color: world.onAccent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ready ? 'ملخص حجزك' : 'احجز هذا المكان',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Vibes.ink,
                          height: 1.25,
                        ),
                      ),
                      Text(
                        _ready
                            ? 'اضغط أي بند لتعديله فوراً'
                            : 'ثلاث خطوات فقط وتنتهي',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Vibes.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'يبدأ من',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: world.accentDeep,
                      ),
                    ),
                    PlaceFullPriceText(
                      placeReferencePrice(p, widget.dayPrices),
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!_ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: _EmptyBookingStart(
                loading: _loadingWizard,
                accent: accent,
                supportsShifts: p.supportsShifts,
                onStart: () => _startWizard(),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                children: [
                  _StayTimelineCard(
                    property: p,
                    shift: _shift,
                    start: _start!,
                    endExclusive: _end!,
                    onEditDates: _editDatesOnly,
                  ),
                  const SizedBox(height: 8),
                  if (p.supportsShifts)
                    _EditableChip(
                      icon: _shift == ShiftType.morning
                          ? Icons.wb_sunny_outlined
                          : _shift == ShiftType.evening
                          ? Icons.nights_stay_outlined
                          : Icons.calendar_today_rounded,
                      tint: placeShiftColor(_shift),
                      label: 'الفترة',
                      value: _shiftLabel,
                      onTap: () => _startWizard(
                        startAt: PlaceBookingWizardStep.period,
                        editOnly: true,
                      ),
                    ),
                  _EditableChip(
                    icon: Icons.groups_rounded,
                    tint: context.world.accentDeep,
                    label: 'الضيوف',
                    value: _guests == 1 ? 'ضيف واحد' : '$_guests ضيوف',
                    onTap: () => _startWizard(
                      startAt: PlaceBookingWizardStep.guests,
                      editOnly: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: SizedBox(
                width: double.infinity,
                child: _ReserveButton(
                  state: _submitting
                      ? _ReserveState.loading
                      : (total != null
                            ? _ReserveState.ready
                            : _ReserveState.calculating),
                  total: total,
                  accent: accent,
                  onTap: _reserve,
                ),
              ),
            ),
            if (!_quoting && total != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.world.canvas,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.world.accent.withValues(alpha: .10),
                    ),
                  ),
                  child: Column(
                    children: [
                      _priceLine(
                        '$nights ${nights == 1 ? 'ليلة' : 'ليالٍ'} × $_shiftPriceLabel',
                        placeFullPrice(_quoteOriginalTotal ?? total),
                      ),
                      if ((_quoteDiscount ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _priceLine(
                            'خصم الكوبون',
                            '− ${placeFullPrice(_quoteDiscount!)}',
                          ),
                        ),
                      if (nights != null && nights > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _priceLine(
                            'الإجمالي الكامل',
                            placeFullPrice(total),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else if (_quoteError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  _quoteError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: TextButton(
                  onPressed: () => _startWizard(),
                  child: const Text(
                    'إعادة اختيار الموعد من البداية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: placeInk2,
                    ),
                  ),
                ),
              ),
            ),
          ],

          Center(
            child: Text(
              '🔒 لن تُخصم أي رسوم الآن',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: placeInk2.withValues(alpha: .8),
              ),
            ),
          ),
          if (widget.dayPrices.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () => showPlaceDayPricingSheet(
                  context: context,
                  property: widget.property,
                  days: widget.dayPrices,
                ),
                child: const Text(
                  'أسعار بتواريخ محددة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: placeInk2,
                    decoration: TextDecoration.underline,
                    decorationColor: placeLine,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: placeInk2,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: placeInk,
          ),
        ),
      ],
    );
  }

  String get _shiftPriceLabel => switch (_shift) {
    ShiftType.morning => 'صباحي',
    ShiftType.evening => 'مسائي',
    ShiftType.full => 'يوم كامل',
  };
}

class _StayTimelineCard extends StatelessWidget {
  const _StayTimelineCard({
    required this.property,
    required this.shift,
    required this.start,
    required this.endExclusive,
    required this.onEditDates,
  });

  final Property property;
  final ShiftType shift;
  final DateTime start;
  final DateTime endExclusive;
  final VoidCallback onEditDates;

  @override
  Widget build(BuildContext context) {
    final t = placeStayTimelineLabels(property, shift, start, endExclusive);
    return Material(
      color: context.world.canvas,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onEditDates();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _miniLine(
                      Icons.login_rounded,
                      placeShiftColor(shift),
                      'وصول',
                      t.arrival,
                    ),
                    const SizedBox(height: 10),
                    _miniLine(
                      Icons.logout_rounded,
                      placeInk,
                      'مغادرة',
                      t.departure,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: placeLine),
                ),
                child: const Text(
                  'تعديل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: placeInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniLine(IconData icon, Color tint, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: placeInk2,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
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

class _EmptyBookingStart extends StatelessWidget {
  const _EmptyBookingStart({
    required this.loading,
    required this.accent,
    required this.supportsShifts,
    required this.onStart,
  });

  final bool loading;
  final Color accent;
  final bool supportsShifts;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final steps = supportsShifts
        ? const [
            (Icons.schedule_rounded, 'الفترة'),
            (Icons.groups_rounded, 'الضيوف'),
            (Icons.calendar_month_rounded, 'التاريخ'),
          ]
        : const [
            (Icons.timelapse_rounded, 'المدة'),
            (Icons.groups_rounded, 'الضيوف'),
            (Icons.calendar_month_rounded, 'التاريخ'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: world.canvas,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: world.accent.withValues(alpha: .10)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        gradient: LinearGradient(
                          colors: [
                            world.accent.withValues(alpha: .15),
                            world.accent.withValues(alpha: .45),
                          ],
                        ),
                      ),
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: world.accent.withValues(alpha: .35),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        steps[i].$1,
                        size: 19,
                        color: world.accentDeep,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${i + 1}. ${steps[i].$2}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Vibes.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        WorldButton(
          label: 'اختر الموعد',
          icon: Icons.calendar_month_rounded,
          loading: loading,
          onTap: onStart,
        ),
      ],
    );
  }
}

class _EditableChip extends StatelessWidget {
  const _EditableChip({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.world.accent.withValues(alpha: .14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const SizedBox(width: 12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.world.accentFaint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'تعديل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.world.accentDeep,
                    ),
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

enum _ReserveState { calculating, ready, loading }

class _ReserveButton extends StatelessWidget {
  const _ReserveButton({
    required this.state,
    required this.total,
    required this.accent,
    required this.onTap,
  });

  final _ReserveState state;
  final num? total;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _ReserveState.loading => const WorldButton(
        label: 'جاري الحجز',
        loading: true,
        onTap: null,
      ),
      _ReserveState.calculating => const WorldButton(
        label: 'جاري حساب الإجمالي…',
        icon: Icons.hourglass_top_rounded,
      ),
      _ReserveState.ready => WorldButton(
        label: 'احجز الآن — ${placeFullPrice(total!)} د.ع',
        icon: Icons.lock_rounded,
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
      ),
    };
  }
}
