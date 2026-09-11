import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// مسار الحجز — تاريخ/شفت واعٍ بالأسعار + ضيوف + quote حي + كوبون
/// ═══════════════════════════════════════════════════════════

class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key, required this.propertyId});

  final String propertyId;

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
  bool _submitting = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _coupon.addListener(_onCouponChanged);
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
      final data = await client.post(
        '/api/admin/bookings/quote',
        body: {
          'propertyId': widget.propertyId,
          'startDate': _dateKey(_start!),
          'endDate': _dateKey(_end!),
          'shift': _shift.name.toUpperCase(),
          if (_coupon.text.trim().isNotEmpty)
            'couponCode': _coupon.text.trim().toUpperCase(),
        },
      ) as Map<String, dynamic>;

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
        _quoteError = e.toString();
      });
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDates(Property property) async {
    final now = DateTime.now();
    final availability = ref.read(
      availabilityProvider((id: widget.propertyId, month: null)),
    );
    final blockedDays = availability.value?.slots
            .map((k) => k.substring(0, 10))
            .toSet() ??
        <String>{};

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      initialEntryMode: DatePickerEntryMode.calendar,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: GoldColors.gold,
                onPrimary: GoldColors.onGold,
              ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      // تحقق محلي من الأيام المغلقة داخل النطاق
      final hasBlocked = blockedDays.any((key) {
        final date = DateTime.tryParse(key);
        return date != null &&
            !date.isBefore(picked.start) &&
            date.isBefore(picked.end.add(const Duration(days: 1)));
      });

      if (hasBlocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('النطاق يتضمن أياماً مغلقة — اختر تواريخ أخرى')),
        );
        return;
      }

      setState(() {
        _start = picked.start;
        _end = picked.end.add(const Duration(days: 1));
      });
      _fetchQuote();
    }
  }

  Future<void> _submit(Property property) async {
    if (!_datesReady) return;
    setState(() => _submitting = true);

    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        '/api/bookings',
        body: {
          'propertyId': widget.propertyId,
          'startDate': _dateKey(_start!),
          'endDate': _dateKey(_end!),
          'shift': _shift.name.toUpperCase(),
          'guests': _guests,
          'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
          if (_coupon.text.trim().isNotEmpty)
            'couponCode': _coupon.text.trim().toUpperCase(),
        },
      ) as Map<String, dynamic>;

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.pushReplacement('/booking-success');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = ref.watch(propertyDetailProvider(widget.propertyId));

    return property.when(
      loading: () => Scaffold(
        body: const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(propertyDetailProvider(widget.propertyId)),
        ),
      ),
      data: (p) {
        final supportsShifts = p.supportsShifts;
        if (!supportsShifts) _shift = ShiftType.full;
        final labels = p.shiftLabels;

        return Scaffold(
          appBar: AppBar(title: const Text('حجز المكان')),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              // ملخص المكان
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Text(
                          '${p.typeLabelAr} · ${p.cityName ?? ''}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: 22),

              // اختيار الشفت
              if (supportsShifts) ...[
                const SectionHeader('اختر وقت الزيارة'),
                Row(
                  children: [
                    _ShiftOption(
                      label: 'صباحي',
                      time: labels.morning,
                      selected: _shift == ShiftType.morning,
                      onTap: () {
                        setState(() => _shift = ShiftType.morning);
                        _fetchQuote();
                      },
                    ),
                    const SizedBox(width: 8),
                    _ShiftOption(
                      label: 'مسائي',
                      time: labels.evening,
                      selected: _shift == ShiftType.evening,
                      onTap: () {
                        setState(() => _shift = ShiftType.evening);
                        _fetchQuote();
                      },
                    ),
                    const SizedBox(width: 8),
                    _ShiftOption(
                      label: 'يوم كامل',
                      time: null,
                      selected: _shift == ShiftType.full,
                      onTap: () {
                        setState(() => _shift = ShiftType.full);
                        _fetchQuote();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],

              // التواريخ
              const SectionHeader('اختر التواريخ'),
              _DatesCard(
                start: _start,
                end: _end,
                onTap: () => _pickDates(p),
              ),
              const SizedBox(height: 22),

              // الضيوف
              const SectionHeader('عدد الضيوف'),
              _GuestsStepper(
                value: _guests,
                max: p.capacity > 0 ? p.capacity : 200,
                onChanged: (v) => setState(() => _guests = v),
              ),
              const SizedBox(height: 22),

              // ملاحظات
              const SectionHeader('ملاحظات للمالك (اختياري)'),
              TextField(
                controller: _notes,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'أي طلبات خاصة؟',
                ),
              ),
              const SizedBox(height: 22),

              // الكوبون
              const SectionHeader('رمز الخصم (اختياري)'),
              TextField(
                controller: _coupon,
                textInputAction: TextInputAction.done,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  hintText: 'مثال: VIBES10',
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixIcon: _quote != null && _quote!['discount'] != null &&
                          (_quote!['discount'] as num) > 0
                      ? const Icon(Icons.check_circle_rounded,
                          color: GoldColors.gold)
                      : null,
                ),
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
        );
      },
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
          decoration: BoxDecoration(
            gradient: selected ? GoldColors.gradient : null,
            color: selected ? null : VibesTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(VibesRadius.md),
            border: selected
                ? null
                : Border.all(color: VibesTheme.hairlineOf(context)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? GoldColors.onGold : null,
                    ),
              ),
              if (time != null) ...[
                const SizedBox(height: 2),
                Text(
                  time!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? GoldColors.onGold
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
  const _DatesCard({this.start, this.end, required this.onTap});

  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;

  String _format(DateTime d) =>
      '${d.day}/${d.month}${d.year != DateTime.now().year ? '/${d.year}' : ''}';

  @override
  Widget build(BuildContext context) {
    final ready = start != null && end != null;
    return GestureDetector(
      onTap: onTap,
      child: VibesCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GoldColors.goldSoft,
                borderRadius: BorderRadius.circular(VibesRadius.md),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: GoldColors.gold, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ready
                  ? Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                  ),
                            ),
                            Text(
                              _format(start!),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.arrow_forward_rounded, size: 18),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إلى',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                  ),
                            ),
                            Text(
                              _format(end!.subtract(const Duration(days: 1))),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      'اضغط لاختيار التواريخ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VibesTheme.textTertiaryOf(context),
                          ),
                    ),
            ),
            Icon(Icons.chevron_left_rounded,
                size: 20, color: VibesTheme.textTertiaryOf(context)),
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
        decoration: BoxDecoration(
          color: enabled ? GoldColors.goldSoft : VibesTheme.surfaceHighOf(context),
          borderRadius: BorderRadius.circular(VibesRadius.md),
          border: Border.all(color: VibesTheme.hairlineOf(context)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? GoldColors.gold : VibesTheme.textTertiaryOf(context),
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
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(color: GoldColors.gold, strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return VibesCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: SemanticColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SemanticColors.warning,
                    ),
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
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'الإجمالي ${nights != null ? '· $nights ${nights == 1 ? 'ليلة' : 'ليالٍ'}' : ''}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              StatusPill(
                label: available ? 'متاح' : 'محجوز بهذه التواريخ',
                color: available
                    ? SemanticColors.success
                    : SemanticColors.danger,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
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
              const Spacer(),
              PriceText(total),
            ],
          ),
        ],
      ),
    );
  }
}
