import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../home/home_sections.dart';
import 'booking_date_picker.dart';
import '../property/place_experience_ui.dart';
import '../property/place_booking_sheets.dart';
import '../property/place_booking_wizard.dart';
import 'booking_providers.dart';
import '../property/shift_calendar_ui.dart';

/// ═══════════════════════════════════════════════════════════
/// مسار الحجز — ملخص دائم بأسطر واضحة، كل سطر يفتح لوحة
/// قرار واحدة مركّزة (نمط Airbnb: لا نموذج طويل أبداً)
/// ═══════════════════════════════════════════════════════════

class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.propertyId,
    this.initialDate,
    this.initialShift,
  });

  final String propertyId;
  final String? initialDate;
  final String? initialShift;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  ShiftType _shift = ShiftType.full;
  DateTime? _start;
  DateTime? _end;
  int _guests = 2;
  bool _fullDayMulti = false;
  String _notes = '';
  String _coupon = '';

  Map<String, dynamic>? _quote;
  bool _quoting = false;
  String? _quoteError;
  bool _loadingDates = false;
  AvailabilityData? _calendarAvailability;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final fromQuery = placeShiftFromQuery(widget.initialShift);
    if (fromQuery != null) _shift = fromQuery;
    final raw = widget.initialDate;
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        _start = DateTime(parsed.year, parsed.month, parsed.day);
        _end = _start!.add(const Duration(days: 1));
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuote());
      }
    }
  }

  bool get _datesReady => _start != null && _end != null;

  /// الإجمالي من استجابة الـ quote — الحقل totalPrice (وأحياناً total).
  num? get _quoteTotal {
    final q = _quote;
    if (q == null) return null;
    final raw = q['totalPrice'] ?? q['total'];
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

  String get _shiftLabel {
    switch (_shift) {
      case ShiftType.morning:
        return 'الفترة الصباحية';
      case ShiftType.evening:
        return 'الفترة المسائية';
      case ShiftType.full:
        return _fullDayMulti ? 'يوم كامل · عدة أيام' : 'يوم كامل';
    }
  }

  Future<AvailabilityData> _loadCalendarAvailability() async {
    final now = DateTime.now();
    final months = List.generate(5, (index) {
      final month = DateTime(now.year, now.month + index);
      return '${month.year.toString().padLeft(4, '0')}-'
          '${month.month.toString().padLeft(2, '0')}';
    });
    final results = await Future.wait(
      months.map(
        (month) => ref.read(
          availabilityProvider((id: widget.propertyId, month: month)).future,
        ),
      ),
    );
    final mergedSlots = <String>{};
    final mergedDays = <String, DayPricing>{};
    for (final result in results) {
      mergedSlots.addAll(result.slots);
      for (final day in result.dayPrices) {
        mergedDays[_dateKey(day.date)] = day;
      }
    }
    final dayPrices = mergedDays.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final availability = AvailabilityData(
      slots: mergedSlots,
      dayPrices: dayPrices,
      bookingMode: results.firstOrNull?.bookingMode,
    );
    _calendarAvailability = availability;
    return availability;
  }

  Future<void> _applyDraft(PlaceBookingDraft draft) async {
    setState(() {
      _shift = draft.shift;
      _guests = draft.guests;
      _start = draft.start;
      _end = draft.endExclusive;
      _fullDayMulti = draft.fullDayMulti;
      _quote = null;
      _quoteError = null;
    });
    await _fetchQuote();
  }

  Future<void> _openWizard(
    Property property, {
    PlaceBookingWizardStep startAt = PlaceBookingWizardStep.period,
    bool editOnly = false,
  }) async {
    final draft = await showPlaceBookingWizard(
      context: context,
      property: property,
      dayPrices:
          _calendarAvailability?.dayPrices ??
          ref
              .read(availabilityProvider((id: widget.propertyId, month: null)))
              .valueOrNull
              ?.dayPrices ??
          const <DayPricing>[],
      loadAvailability: _loadCalendarAvailability,
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
                  'propertyId': widget.propertyId,
                  'startDate': _dateKey(_start!),
                  'endDate': _dateKey(_end!),
                  'shift': _shift.name.toUpperCase(),
                  if (_coupon.isNotEmpty) 'couponCode': _coupon,
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
        _quoteError = maisonError(e);
      });
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── التواريخ — بحسب قواعد الفترة ──
  Future<void> _openDates(Property property) async {
    if (_loadingDates) return;
    setState(() => _loadingDates = true);

    AvailabilityData availability;
    try {
      availability = await _loadCalendarAvailability();
      if (mounted) setState(() => _loadingDates = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingDates = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحميل المواعيد: $error')));
      return;
    }

    if (!mounted) return;
    final mode = (_shift == ShiftType.full && _fullDayMulti)
        ? BookingDatePickMode.range
        : BookingDatePickMode.singleDay;
    final picked = await showBookingDatePicker(
      context: context,
      propertyName: property.name,
      availability: availability,
      shift: _shift,
      initialStart: _start,
      initialEndExclusive: _end,
      mode: mode,
      shiftTimes: property.shiftLabels,
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
      _quoteError = null;
    });
    _fetchQuote();
  }

  Future<void> _openShift(Property property) => _openWizard(
    property,
    startAt: PlaceBookingWizardStep.period,
    editOnly: true,
  );

  Future<void> _openGuests(Property property) => _openWizard(
    property,
    startAt: PlaceBookingWizardStep.guests,
    editOnly: true,
  );

  // ── لوحة الملاحظة ──
  Future<void> _openNotes() async {
    final picked = await showPlaceNotesSheet(context: context, initial: _notes);
    if (picked == null || !mounted) return;
    setState(() => _notes = picked);
  }

  // ── لوحة الكوبون ──
  Future<void> _openCoupon(List<String> suggested) async {
    final discount = (_quote?['discount'] as num?) ?? 0;
    final picked = await showPlaceCouponSheet(
      context: context,
      initial: _coupon,
      suggested: suggested,
      applied: discount > 0,
      error: _couponPendingError(),
    );
    if (picked == null || !mounted) return;
    final clean = picked.toUpperCase();
    setState(() => _coupon = clean);
    if (clean.length >= 3) {
      _fetchQuote();
    } else if (clean.isEmpty && _coupon != clean) {
      _fetchQuote();
    }
  }

  String? _couponPendingError() {
    if (_coupon.isEmpty || _quote == null) return null;
    return ((_quote?['discount'] ?? 0) == 0)
        ? 'الرمز غير مطبق — تحقق منه'
        : null;
  }

  Future<void> _submit(Property property) async {
    if (!_datesReady) return;
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
                  'propertyId': widget.propertyId,
                  'startDate': _dateKey(_start!),
                  'endDate': _dateKey(_end!),
                  'shift': _shift.name.toUpperCase(),
                  'guests': _guests,
                  'notes': _notes.isNotEmpty ? _notes : null,
                  if (_coupon.isNotEmpty) 'couponCode': _coupon,
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = ref.watch(propertyDetailProvider(widget.propertyId));

    return property.when(
      loading: () => const Scaffold(
        backgroundColor: placePaper,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: maisonError(e),
          onRetry: () =>
              ref.invalidate(propertyDetailProvider(widget.propertyId)),
        ),
      ),
      data: (p) {
        final supportsShifts = p.supportsShifts;
        if (!supportsShifts && _shift != ShiftType.full) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _shift = ShiftType.full);
          });
        }
        final accent = accentForType(p.type.name);

        final availability = ref
            .watch(availabilityProvider((id: widget.propertyId, month: null)))
            .valueOrNull;
        final coupons = ref.watch(publicCouponsProvider).valueOrNull ?? [];
        final suggestedCodes = coupons
            .where(
              (c) =>
                  c.matchesProperty(id: p.id, type: p.type.name.toUpperCase()),
            )
            .map((c) => c.code)
            .toList();

        return Scaffold(
          backgroundColor: placePaper,
          body: Stack(
            children: [
              // المحتوى — سطور قرار واضحة
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'إتمام الحجز',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: placeInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // بطاقة المكان — مصغّرة أنيقة
                  _PlaceMiniHeader(
                    property: p,
                    accent: accent,
                  ).animate().fadeIn(),

                  const SizedBox(height: 16),

                  if (!_datesReady) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _openWizard(p),
                        child: const Text(
                          'اختر الموعد — فترة ثم ضيوف ثم تاريخ',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ترتيب عملي: فترة → ضيوف → تاريخ → اختياري
                  _DecisionCard(
                    children: [
                      if (supportsShifts) ...[
                        _DecisionRow(
                          icon: _shift == ShiftType.morning
                              ? Icons.wb_sunny_outlined
                              : _shift == ShiftType.evening
                              ? Icons.nights_stay_outlined
                              : Icons.calendar_today_rounded,
                          title: 'الفترة',
                          value: _shiftLabel,
                          iconTint: placeShiftColor(_shift),
                          trailing: PlaceShiftBadge(
                            shift: _shift,
                            compact: true,
                          ),
                          onTap: () => _openShift(p),
                        ),
                        const _RowDivider(),
                      ],
                      _DecisionRow(
                        icon: Icons.groups_rounded,
                        title: 'الضيوف',
                        value: _guests == 1 ? 'ضيف واحد' : '$_guests ضيوف',
                        onTap: () => _openGuests(p),
                      ),
                      const _RowDivider(),
                      _DecisionRow(
                        icon: Icons.calendar_month_rounded,
                        title: 'التاريخ',
                        value: _datesReady
                            ? placeFormatDateRange(_start!, _end!)
                            : 'اختر موعدك',
                        hint: _loadingDates
                            ? 'جاري التحميل…'
                            : (_datesReady &&
                                      _end!.difference(_start!).inDays == 1
                                  ? 'مغادرة تلقائية في اليوم التالي'
                                  : null),
                        strong: _datesReady,
                        onTap: () => _openDates(p),
                      ),
                      const _RowDivider(),
                      _DecisionRow(
                        icon: Icons.note_alt_outlined,
                        title: 'ملاحظة',
                        value: _notes.isEmpty
                            ? 'أضف مناسبتك (اختياري)'
                            : _notes,
                        valueMaxLines: _notes.isEmpty ? 1 : 2,
                        onTap: _openNotes,
                      ),
                      if (suggestedCodes.isNotEmpty || _coupon.isNotEmpty) ...[
                        const _RowDivider(),
                        _DecisionRow(
                          icon: Icons.local_offer_outlined,
                          title: 'خصم',
                          value: _coupon.isEmpty ? 'أضف رمزاً' : _coupon,
                          trailing: (_quote?['discount'] ?? 0) > 0
                              ? const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Color(0xFF15803D),
                                )
                              : null,
                          onTap: () => _openCoupon(suggestedCodes),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // تفصيل الليالي — بعد اختيار التاريخ
                  if (_datesReady)
                    PlaceNightlyPriceList(
                      property: p,
                      start: _start!,
                      endExclusive: _end!,
                      shift: _shift,
                      availability: _calendarAvailability ?? availability,
                    ),

                  // السعر — واضح وكامل
                  PlaceQuoteSummaryCard(
                    quoting: _quoting,
                    error: _quoteError,
                    nights: _datesReady
                        ? _end!.difference(_start!).inDays.clamp(1, 365)
                        : null,
                    total: _quoteTotal,
                    discount: _quoteDiscount ?? 0,
                    hint: 'اختر التاريخ لعرض الإجمالي الكامل',
                  ),

                  const SizedBox(height: 10),
                  const PlaceTrustHints(),
                ],
              ),

              // الشريط السفلي — السعر + تأكيد
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PlaceStickyCheckoutBar(
                  amount:
                      _quoteTotal ??
                      placeReferencePrice(p, availability?.dayPrices ?? []),
                  amountLabel: _datesReady
                      ? (_quoteTotal != null
                            ? 'الإجمالي النهائي'
                            : 'جاري الحساب…')
                      : 'يبدأ من',
                  buttonLabel: 'تأكيد الحجز',
                  accent: accent,
                  enabled: _datesReady && !_quoting,
                  loading: _submitting,
                  onConfirm: () => _submit(p),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// رأس مصغّر للمكان — صورة + اسم + نوع، سطر واحد.
class _PlaceMiniHeader extends StatelessWidget {
  const _PlaceMiniHeader({required this.property, required this.accent});

  final Property property;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/property/${property.id}'),
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: placeLine),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: property.coverUrl != null
                    ? VibesNetImage(url: property.coverUrl!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: accent.withValues(alpha: .15),
                        child: Icon(
                          Icons.home_work_rounded,
                          color: accent,
                          size: 26,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: placeInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${property.typeLabelAr} · ${property.cityName ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: placeInk2.withValues(alpha: .5),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة القرار — إطار أبيض واحد يجمع كل الأسطر.
class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
        boxShadow: [
          BoxShadow(
            color: placeInk.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.only(start: 62),
      child: Divider(height: 1, color: placeLine),
    );
  }
}

/// سطر قرار — أيقونة + عنوان يسار، قيمة يمين، سهم فتح.
class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.hint,
    this.strong = false,
    this.trailing,
    this.valueMaxLines = 1,
    this.iconTint,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final String? hint;
  final bool strong;
  final Widget? trailing;
  final int valueMaxLines;
  final Color? iconTint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconTint ?? placeInk2),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: placeInk2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: valueMaxLines,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: strong
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              color: strong ? placeInk : placeInk2,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 6),
                          trailing!,
                        ],
                      ],
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: placeBrass,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: placeInk2.withValues(alpha: .45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
