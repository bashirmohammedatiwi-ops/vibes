import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import 'booking_date_picker.dart';

/// ═══════════════════════════════════════════════════════════
/// مسار الحجز — تاريخ/شفت واعٍ بالأسعار + ضيوف + quote حي + كوبون
/// ═══════════════════════════════════════════════════════════

class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.propertyId,
    this.initialDate,
  });

  final String propertyId;
  final String? initialDate;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  ShiftType _shift = ShiftType.full;
  DateTime? _start;
  DateTime? _end;
  int _guests = 2;
  final _notes = TextEditingController();
  final _coupon = TextEditingController();

  Map<String, dynamic>? _quote;
  bool _quoting = false;
  String? _quoteError;
  bool _loadingDates = false;
  AvailabilityData? _calendarAvailability;
  bool _submitting = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _coupon.addListener(_onCouponChanged);
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

  @override
  void dispose() {
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  void _onCouponChanged() {
    final text = _coupon.text.trim().toUpperCase();
    if (text.length >= 3) _fetchQuote();
  }

  bool get _datesReady => _start != null && _end != null;

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
                  if (_coupon.text.trim().isNotEmpty)
                    'couponCode': _coupon.text.trim().toUpperCase(),
                },
              )
              as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _quote = data;
        _quoting = false;
        _couponError =
            (_coupon.text.trim().isNotEmpty && (data['discount'] ?? 0) == 0)
            ? 'الرمز غير مطبق — تحقق منه'
            : null;
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

  Future<void> _pickDates(Property property) async {
    if (_loadingDates) return;
    setState(() => _loadingDates = true);

    AvailabilityData availability;
    try {
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
      availability = AvailabilityData(
        slots: mergedSlots,
        dayPrices: dayPrices,
        bookingMode: results.firstOrNull?.bookingMode,
      );
      if (mounted) {
        setState(() {
          _loadingDates = false;
          _calendarAvailability = availability;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingDates = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحميل المواعيد: $error')));
      return;
    }

    if (!mounted) return;
    final picked = await showBookingDatePicker(
      context: context,
      propertyName: property.name,
      availability: availability,
      shift: _shift,
      initialStart: _start,
      initialEndExclusive: _end,
    );

    if (picked == null || !mounted) return;
    setState(() {
      _start = picked.start;
      _end = picked.endExclusive;
      _quote = null;
      _quoteError = null;
    });
    _fetchQuote();
  }

  void _changeShift(ShiftType shift) {
    if (_shift == shift) return;
    setState(() {
      _shift = shift;
      _quote = null;
      _quoteError = null;
    });

    if (!_datesReady) return;
    final availability =
        _calendarAvailability ??
        ref
            .read(availabilityProvider((id: widget.propertyId, month: null)))
            .valueOrNull;
    if (availability == null) {
      _fetchQuote();
      return;
    }

    for (
      var date = _start!;
      date.isBefore(_end!);
      date = date.add(const Duration(days: 1))
    ) {
      final pricing = availability.pricingFor(date);
      final unavailable =
          pricing == null ||
          pricing.isBooked ||
          pricing.isBlocked ||
          pricing.priceFor(shift) <= 0 ||
          availability.isBlocked(date, shift);
      if (unavailable) {
        setState(() {
          _start = null;
          _end = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذا الموعد غير متاح للفترة الجديدة — اختر موعداً آخر',
            ),
          ),
        );
        return;
      }
    }
    _fetchQuote();
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
                  'notes': _notes.text.trim().isNotEmpty
                      ? _notes.text.trim()
                      : null,
                  if (_coupon.text.trim().isNotEmpty)
                    'couponCode': _coupon.text.trim().toUpperCase(),
                },
              )
              as Map<String, dynamic>;

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final bookingId = created['id'] as String?;
      context.pushReplacement(
        bookingId != null
            ? '/booking-success?id=$bookingId'
            : '/booking-success',
      );
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
        body: MaisonWash(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              children: [
                ShimmerBox(height: 28, radius: VibesRadius.md),
                SizedBox(height: 16),
                ShimmerBox(height: 72, radius: VibesRadius.lg),
                SizedBox(height: 16),
                ShimmerBox(height: 220, radius: VibesRadius.xl),
                SizedBox(height: 16),
                ShimmerBox(height: 120, radius: VibesRadius.lg),
              ],
            ),
          ),
        ),
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
        if (!supportsShifts) _shift = ShiftType.full;
        final labels = p.shiftLabels;

        return Scaffold(
          body: MaisonWash(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                MaisonPageHeader(
                  title: 'حجز المكان',
                  kicker: 'أكمل دعوتك',
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: 8),
                VibesCard(
                  child: Row(
                    children: [
                      PetalMark(size: 8, color: TypeColors.of(p.type.name)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${p.typeLabelAr} · ${p.cityName ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 22),

                // ① وقت الزيارة
                if (supportsShifts) ...[
                  const _StepTitle('وقت الزيارة'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ShiftOption(
                        label: 'صباحي',
                        time: labels.morning,
                        selected: _shift == ShiftType.morning,
                        onTap: () => _changeShift(ShiftType.morning),
                      ),
                      const SizedBox(width: 8),
                      _ShiftOption(
                        label: 'مسائي',
                        time: labels.evening,
                        selected: _shift == ShiftType.evening,
                        onTap: () => _changeShift(ShiftType.evening),
                      ),
                      const SizedBox(width: 8),
                      _ShiftOption(
                        label: 'يوم كامل',
                        time: null,
                        selected: _shift == ShiftType.full,
                        onTap: () => _changeShift(ShiftType.full),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],

                // ② التواريخ
                const _StepTitle('التواريخ'),
                const SizedBox(height: 12),
                _DatesCard(
                  start: _start,
                  end: _end,
                  loading: _loadingDates,
                  onTap: () => _pickDates(p),
                ),
                const SizedBox(height: 22),

                // ③ الضيوف
                const _StepTitle('عدد الضيوف'),
                const SizedBox(height: 12),
                _GuestsStepper(
                  value: _guests,
                  max: p.capacity > 0 ? p.capacity : 200,
                  onChanged: (v) => setState(() => _guests = v),
                ),
                const SizedBox(height: 22),

                // ملاحظات
                const SectionHeader('ملاحظات للمالك (اختياري)'),
                MaisonField(
                  label: 'أي طلبات خاصة؟',
                  controller: _notes,
                  maxLines: 2,
                ),
                const SizedBox(height: 22),

                // ④ الكوبون
                const _StepTitle('رمز الخصم'),
                const SizedBox(height: 12),
                FolioPanel(
                  color: VibesTheme.surfaceOf(context),
                  borderColor: VibesTheme.hairlineStrongOf(context),
                  radius: Folio.chrome,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _coupon,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.characters,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VibesTheme.textPrimaryOf(context),
                        letterSpacing: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'VIBES10',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        suffixIcon:
                            _quote != null &&
                                _quote!['discount'] != null &&
                                (_quote!['discount'] as num) > 0
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Vibes.teal,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final coupons =
                        ref.watch(publicCouponsProvider).valueOrNull ?? [];
                    final applicable = coupons
                        .where(
                          (c) => c.matchesProperty(
                            id: p.id,
                            type: p.type.name.toUpperCase(),
                          ),
                        )
                        .toList();
                    if (applicable.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final coupon in applicable)
                            MaisonChip(
                              label: '${coupon.code} · ${coupon.discountLabel}',
                              active:
                                  _coupon.text.trim().toUpperCase() ==
                                  coupon.code,
                              onTap: () {
                                setState(() => _coupon.text = coupon.code);
                                _onCouponChanged();
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (_couponError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _couponError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SemanticColors.warning,
                      ),
                    ),
                  ),
                const SizedBox(height: 26),

                // السعر الحي
                _QuoteCard(
                  quote: _quote,
                  quoting: _quoting,
                  error: _quoteError,
                  nights: _datesReady
                      ? _end!.difference(_start!).inDays.clamp(1, 365)
                      : null,
                  shiftLabel: _shift,
                ),
                const SizedBox(height: 24),

                VibesButton(
                  label: 'تأكيد الحجز',
                  icon: Icons.check_rounded,
                  loading: _submitting,
                  onPressed: _datesReady ? () => _submit(p) : null,
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'الدفع يتم بعد تأكيد الحجز — تحويل أو نقدي',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ArcFlourish(width: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ShiftOption extends StatelessWidget {
  const _ShiftOption({
    required this.label,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: VibesMotion.fast,
          curve: VibesMotion.curve,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: ShapeDecoration(
            gradient: selected ? Vibes.coralFill : null,
            color: selected ? null : VibesTheme.surfaceOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: Folio.radius,
              side: selected
                  ? BorderSide.none
                  : BorderSide(color: VibesTheme.hairlineOf(context)),
            ),
            shadows: selected
                ? const [
                    BoxShadow(
                      color: Color(0x331B3857),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? Vibes.onCoral : null,
                ),
              ),
              if (time != null) ...[
                const SizedBox(height: 2),
                Text(
                  time!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? Vibes.onCoral
                        : VibesTheme.textTertiaryOf(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  const _DatesCard({
    this.start,
    this.end,
    this.loading = false,
    required this.onTap,
  });

  final DateTime? start;
  final DateTime? end;
  final bool loading;
  final VoidCallback onTap;

  String _format(DateTime d) =>
      '${d.day}/${d.month}${d.year != DateTime.now().year ? '/${d.year}' : ''}';

  @override
  Widget build(BuildContext context) {
    final ready = start != null && end != null;
    final days = ready ? end!.difference(start!).inDays : 0;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: VibesCard(
        featured: ready,
        child: Row(
          children: [
            const MaisonIconWell(icon: Icons.calendar_month_rounded, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: ready
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          days == 1
                              ? _format(start!)
                              : '${_format(start!)} — ${_format(end!.subtract(const Duration(days: 1)))}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          days == 1
                              ? 'موعد ليوم واحد · اضغط للتعديل'
                              : '$days أيام · اضغط للتعديل',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: VibesTheme.textTertiaryOf(context),
                              ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اختر موعدك من التقويم',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'شاهد الأسعار والأيام المتاحة قبل المتابعة',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: VibesTheme.textTertiaryOf(context),
                              ),
                        ),
                      ],
                    ),
            ),
            if (loading) const ThreadProgress(width: 48)
            else
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: VibesTheme.textTertiaryOf(context),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuestsStepper extends StatelessWidget {
  const _GuestsStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return VibesCard(
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'ضيف (الحد $max)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: enabled ? Vibes.tealMint : VibesTheme.surfaceHighOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.compact,
            side: BorderSide(color: VibesTheme.hairlineOf(context)),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Vibes.teal : VibesTheme.textTertiaryOf(context),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    this.quote,
    this.quoting = false,
    this.error,
    this.nights,
    required this.shiftLabel,
  });

  final Map<String, dynamic>? quote;
  final bool quoting;
  final String? error;
  final int? nights;
  final ShiftType shiftLabel;

  @override
  Widget build(BuildContext context) {
    if (quoting) {
      return const VibesCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              ShimmerBox(height: 18, radius: VibesRadius.sm),
              SizedBox(height: 10),
              ShimmerBox(height: 28, radius: VibesRadius.sm),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return VibesCard(
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: SemanticColors.warning,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: SemanticColors.warning),
              ),
            ),
          ],
        ),
      );
    }

    if (quote == null) {
      return VibesCard(
        child: Center(
          child: Text(
            'اختر التواريخ لعرض السعر الحي',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VibesTheme.textTertiaryOf(context),
            ),
          ),
        ),
      );
    }

    final total = quote!['totalPrice'] as num? ?? 0;
    final original = quote!['originalTotal'] as num? ?? total;
    final discount = quote!['discount'] as num? ?? 0;
    final available = quote!['available'] as bool? ?? true;

    return VibesCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              StatusPill(
                label: available ? 'متاح' : 'محجوز بهذه التواريخ',
                color: available ? Vibes.success : Vibes.danger,
                compact: true,
              ),
              const Spacer(),
              if (nights != null)
                Text(
                  '$nights ${nights == 1 ? 'ليلة' : 'ليالٍ'}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Vibes.inkTertiary),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (discount > 0) ...[
            Row(
              children: [
                Text(
                  'السعر قبل الخصم',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${PriceText.format(original)} د.ع',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'خصم الكوبون',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SemanticColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '− ${PriceText.format(discount)} د.ع',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SemanticColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'الإجمالي',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Vibes.inkTertiary),
              ),
              const Spacer(),
              Text(
                '${PriceText.format(total)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Vibes.teal,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'د.ع',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Vibes.inkTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
