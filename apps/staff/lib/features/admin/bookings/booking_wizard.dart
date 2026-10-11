import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';

/// معالج حجز جديد نيابةً عن زبون — `bookings.write`.
/// اختيار الزبون من القائمة يتطلب `users.read`؛ وإلا يُدخل الهاتف والاسم يدوياً
/// (الخادم ينشئ حساب الزبون تلقائياً إن لم يكن موجوداً).
class NewBookingWizardScreen extends StatefulWidget {
  const NewBookingWizardScreen({super.key, this.initialProperty, this.initialDate});

  /// مكان مُختار مسبقاً (مثلاً من التقويم).
  final Map<String, dynamic>? initialProperty;
  final DateTime? initialDate;

  @override
  State<NewBookingWizardScreen> createState() => _NewBookingWizardScreenState();
}

class _NewBookingWizardScreenState extends State<NewBookingWizardScreen> {
  static const _steps = ['الزبون', 'المكان', 'الموعد', 'المراجعة'];

  int _step = 0;

  // الزبون
  final _phone = TextEditingController();
  final _name = TextEditingController();
  Map<String, dynamic>? _customer;

  // المكان
  Map<String, dynamic>? _property;
  bool _loadingProperty = false;

  // الموعد
  DateTime? _start;
  int _days = 1;
  String _shift = 'FULL';
  int _guests = 1;

  // المراجعة
  final _notes = TextEditingController();
  final _coupon = TextEditingController();
  bool _confirmNow = true;

  // السعر
  final _debounce = Debouncer();
  Map<String, dynamic>? _quote;
  String? _quoteError;
  String? _couponError;
  bool _quoting = false;
  int _seq = 0;

  bool _creating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProperty != null) _setProperty(widget.initialProperty!);
    if (widget.initialDate != null) _start = dayOnly(widget.initialDate!);
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _notes.dispose();
    _coupon.dispose();
    _debounce.dispose();
    super.dispose();
  }

  List<String> get _shiftOptions => shiftsForProperty(_property);
  DateTime? get _end => _start?.add(Duration(days: _days));
  String get _normalizedPhone => normalizeIraqiPhone(_phone.text);
  bool get _phoneValid => _normalizedPhone.length >= 12;

  // ─────────── المكان ───────────

  Future<void> _setProperty(Map<String, dynamic> p) async {
    setState(() {
      _property = p;
      final opts = _shiftOptions;
      if (!opts.contains(_shift)) _shift = opts.first;
      if (_shift != 'FULL') _days = 1;
    });
    _requote();
    // نتائج البحث العام لا تحتوي وضع الحجز/السعة — نجلب التفاصيل إن أمكن.
    if (!p.containsKey('bookingMode') && Session.can('properties.read')) {
      setState(() => _loadingProperty = true);
      try {
        final full = await Api.map('/api/admin/properties/${p['id']}');
        if (!mounted || _property?['id'] != p['id']) return;
        setState(() {
          _property = full;
          final opts = _shiftOptions;
          if (!opts.contains(_shift)) _shift = opts.first;
        });
        _requote();
      } catch (_) {
        // نكمل بالقيم الافتراضية حسب نوع المكان
      } finally {
        if (mounted) setState(() => _loadingProperty = false);
      }
    }
  }

  Future<void> _chooseProperty() async {
    final p = await pickProperty(context);
    if (p != null) await _setProperty(p);
  }

  Future<void> _chooseCustomer() async {
    final c = await pickCustomer(context);
    if (c == null) return;
    setState(() {
      _customer = c;
      _phone.text = c['phone']?.toString() ?? '';
      _name.text = c['name']?.toString() ?? '';
    });
  }

  // ─────────── السعر ───────────

  void _requote() {
    if (_property == null || _start == null) {
      setState(() {
        _quote = null;
        _quoteError = null;
        _quoting = false;
      });
      return;
    }
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    _debounce.run(_fetchQuote);
  }

  Map<String, dynamic> _quoteBody({bool withCoupon = true}) => {
        'propertyId': _property!['id'],
        'startDate': isoDay(_start!),
        'endDate': isoDay(_end!),
        'shift': _shift,
        if (withCoupon && _coupon.text.trim().isNotEmpty) 'couponCode': _coupon.text.trim(),
      };

  Future<void> _fetchQuote() async {
    if (_property == null || _start == null) return;
    final seq = ++_seq;
    final hasCoupon = _coupon.text.trim().isNotEmpty;
    Map<String, dynamic>? quote;
    String? quoteError;
    String? couponError;
    try {
      quote = await Api.map('/api/admin/bookings/quote', method: 'POST', body: _quoteBody());
    } catch (e) {
      if (hasCoupon) {
        // قد يكون الخطأ من رمز الخصم — نعيد الحساب بدونه لنُظهر التوفر والسعر.
        try {
          quote = await Api.map('/api/admin/bookings/quote', method: 'POST', body: _quoteBody(withCoupon: false));
          couponError = errorText(e);
        } catch (e2) {
          quoteError = errorText(e2);
        }
      } else {
        quoteError = errorText(e);
      }
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _quote = quote;
      _quoteError = quoteError;
      _couponError = couponError;
      _quoting = false;
    });
  }

  // ─────────── تنقل ───────────

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (!_phoneValid) return 'أدخل رقم هاتف عراقي صحيح (مثال 07XXXXXXXXX)';
      case 1:
        if (_property == null) return 'اختر المكان أولاً';
      case 2:
        if (_start == null) return 'اختر يوم الحجز';
        if (_quoting) return 'انتظر اكتمال حساب السعر';
        if (_quoteError != null) return _quoteError;
        if (_quote != null && _quote!['available'] != true) return 'الموعد المختار محجوز — غيّر اليوم أو الشفت';
    }
    return null;
  }

  void _next() {
    final error = _validateStep(_step);
    if (error != null) {
      showToast(context, error, error: true);
      return;
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _create();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _create() async {
    for (var i = 0; i < 3; i++) {
      final error = _validateStep(i);
      if (error != null) {
        setState(() => _step = i);
        showToast(context, error, error: true);
        return;
      }
    }
    if (_couponError != null) {
      showToast(context, 'رمز الخصم غير صالح — صحّحه أو احذفه', error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'إنشاء الحجز',
      message:
          '${_property!['name']} · ${fmtRange(isoDay(_start!), isoDay(_end!))} · ${shiftShort(_shift)}\n'
          'للزبون ${_name.text.trim().isEmpty ? _normalizedPhone : _name.text.trim()}'
          '${_quote != null ? '\nالمبلغ: ${formatIqd(_quote!['totalPrice'])}' : ''}'
          '${_confirmNow ? '\nسيُؤكَّد الحجز ويُعتبر مدفوعاً فوراً.' : '\nسيبقى الحجز بانتظار التأكيد.'}',
      confirmLabel: 'إنشاء',
    );
    if (!ok) return;
    setState(() => _creating = true);
    try {
      final booking = await Api.map('/api/admin/bookings', method: 'POST', body: {
        ..._quoteBody(),
        'guests': _guests,
        'customerPhone': _normalizedPhone,
        if (_name.text.trim().isNotEmpty) 'customerName': _name.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'confirmImmediately': _confirmNow,
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      showToast(context, 'تم إنشاء الحجز بنجاح');
      if (!canReadBookings) {
        Navigator.pop(context, true);
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BookingManageScreen(bookingId: '${booking['id']}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      final msg = errorText(e);
      showToast(context, msg, error: true);
      // تعارض توفر — نعود لخطوة الموعد مع تحديث السعر
      if (msg.contains('محجوز') || msg.contains('غير متاح')) {
        setState(() => _step = 2);
        _requote();
      }
    }
  }

  // ─────────── الواجهة ───────────

  static const _stepIcons = [
    Icons.person_rounded,
    Icons.home_work_rounded,
    Icons.event_rounded,
    Icons.fact_check_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps.length - 1;
    final page = StaffPage(
      title: 'حجز جديد',
      subtitle: 'الخطوة ${_step + 1} من ${_steps.length} · ${_steps[_step]}',
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: _StepHeader(
          steps: _steps,
          icons: _stepIcons,
          current: _step,
          onTap: (i) {
            if (i < _step) setState(() => _step = i);
          },
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: switch (_step) {
                    0 => _customerStep(),
                    1 => _propertyStep(),
                    2 => _scheduleStep(),
                    _ => _reviewStep(),
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: withBottomBar(
        page,
        BookingActionBar(
          top: _step >= 2 ? _priceStrip() : null,
          children: [
            BarButton(
              label: _step == 0 ? 'إلغاء' : 'السابق',
              icon: _step == 0 ? null : Icons.arrow_back_rounded,
              primary: false,
              onPressed: _creating ? null : _back,
            ),
            BarButton(
              label: last ? 'إنشاء الحجز' : 'التالي',
              icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
              flex: 2,
              busy: _creating,
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }

  /// ملخص السعر فوق أزرار الشريط السفلي.
  Widget _priceStrip() {
    final q = _quote;
    final available = q?['available'] == true;
    return Row(
      children: [
        const Text('الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: placeInk2)),
        const SizedBox(width: 8),
        if (_quoting)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold))
        else
          Text(
            q == null ? '—' : formatIqd(q['totalPrice']),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk),
          ),
        const Spacer(),
        if (!_quoting && q != null)
          StatusChip(available ? 'متاح' : 'غير متاح', color: available ? placeSuccess : placeDanger, dense: true)
        else if (!_quoting && _quoteError != null)
          const StatusChip('تعذّر الحساب', color: placeDanger, dense: true),
      ],
    );
  }

  List<Widget> _customerStep() {
    final canSearch = Session.can('users.read');
    return [
      if (canSearch)
        Pad(
          child: _PickCard(
            icon: Icons.person_search_rounded,
            title: _customer == null ? 'بحث في الزبائن' : 'تغيير الزبون',
            subtitle: 'اختر زبوناً مسجلاً بالاسم أو الهاتف',
            onTap: _chooseCustomer,
          ),
        ),
      if (_customer != null)
        Pad(
          child: StaffCard(
            color: placeSuccess.withValues(alpha: .05),
            borderColor: placeSuccess.withValues(alpha: .3),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
            child: Row(
              children: [
                Avatar(_name.text.isEmpty ? (_customer!['phone']?.toString() ?? '') : _name.text, size: 42, color: placeSuccess),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.text.isEmpty ? 'زبون مسجّل' : _name.text,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                      Text(
                        'زبون مسجّل · ${asMap(_customer!['_count'])?['bookings'] ?? 0} حجز سابق',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeSuccess),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إزالة',
                  onPressed: () => setState(() {
                    _customer = null;
                    _phone.clear();
                    _name.clear();
                  }),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      BookingSection(
        title: 'بيانات الزبون',
        subtitle: canSearch
            ? 'أو أدخل رقماً جديداً — يُنشأ الحساب تلقائياً'
            : 'أدخل رقم الزبون — يُنشأ حسابه تلقائياً إن لم يكن مسجلاً',
        icon: Icons.person_rounded,
        children: [
          StaffField(
            controller: _phone,
            label: 'رقم الهاتف *',
            hint: '07XXXXXXXXX',
            keyboard: TextInputType.phone,
            ltr: true,
            onChanged: (_) => setState(() {
              if (_customer != null && _phone.text != _customer!['phone']) _customer = null;
            }),
            helper: _phone.text.isEmpty
                ? null
                : (_phoneValid ? 'سيُحفظ كـ $_normalizedPhone' : 'رقم غير مكتمل'),
          ),
          StaffField(controller: _name, label: 'اسم الزبون (اختياري)'),
        ],
      ),
    ];
  }

  List<Widget> _propertyStep() {
    final p = _property;
    if (p == null) {
      return [
        Pad(
          child: _PickCard(
            icon: Icons.travel_explore_rounded,
            title: 'اختر المكان',
            subtitle: 'الأماكن المنشورة فقط قابلة للحجز',
            onTap: _chooseProperty,
            large: true,
          ),
        ),
      ];
    }
    return [
      Pad(
        child: StaffCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBox(icon: placeTypeIcon(p['type']?.toString()), color: placeBrass, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['name']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: placeInk)),
                        Text(
                          [
                            placeTypeLabel(p['type']?.toString()),
                            if (asMap(p['city'])?['nameAr'] != null) '${asMap(p['city'])!['nameAr']}',
                          ].join(' · '),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (_loadingProperty)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (p['pricePerDay'] != null) StatusChip('اليوم ${formatIqd(p['pricePerDay'])}', color: placeInk, dense: true),
                  if (p['priceMorningShift'] != null)
                    StatusChip('صباحي ${formatIqd(p['priceMorningShift'])}', color: placeShiftMorning, dense: true),
                  if (p['priceEveningShift'] != null)
                    StatusChip('مسائي ${formatIqd(p['priceEveningShift'])}', color: placeShiftEvening, dense: true),
                  if ((asNum(p['capacity']) ?? 0) > 0) StatusChip('السعة ${p['capacity']}', color: placeInk2, dense: true),
                  StatusChip(
                    _shiftOptions.length == 1
                        ? (_shiftOptions.first == 'FULL' ? 'يوم كامل فقط' : 'شفت واحد')
                        : (_shiftOptions.contains('FULL') ? 'يوم كامل أو شفتات' : 'شفتات فقط'),
                    color: placeBrass,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _chooseProperty, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('تغيير المكان')),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _scheduleStep() {
    final capacity = (asNum(_property?['capacity']) ?? 0).toInt();
    return [
      BookingSection(
        title: 'الموعد',
        subtitle: _property?['name']?.toString(),
        icon: Icons.event_rounded,
        children: [
          DateField(
            label: 'يوم الحجز',
            date: _start,
            onTap: () async {
              final today = dayOnly(DateTime.now());
              final picked = await pickDay(context, initial: _start ?? today, first: today);
              if (picked == null) return;
              setState(() => _start = dayOnly(picked));
              _requote();
            },
          ),
          if (_shiftOptions.length > 1)
            ShiftChooser(
              options: _shiftOptions,
              value: _shift,
              onChanged: (v) {
                setState(() {
                  _shift = v;
                  if (v != 'FULL') _days = 1;
                });
                _requote();
              },
            )
          else
            Align(alignment: AlignmentDirectional.centerStart, child: BookingShiftChip(shift: _shiftOptions.first, short: false)),
          if (_shift == 'FULL')
            DaysStepper(
              value: _days,
              onChanged: (v) {
                setState(() => _days = v);
                _requote();
              },
            ),
          DaysStepper(
            label: capacity > 0 ? 'الضيوف (السعة $capacity)' : 'عدد الضيوف',
            icon: Icons.people_alt_rounded,
            value: _guests,
            max: capacity > 0 ? capacity : 2000,
            onChanged: (v) => setState(() => _guests = v),
          ),
          if (_start != null && _days > 1)
            Text(
              'من ${fmtDay(_start!)} حتى ${fmtDay(_end!.subtract(const Duration(days: 1)))}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      Pad(child: QuoteCard(quote: _quote, loading: _quoting, error: _quoteError)),
    ];
  }

  List<Widget> _reviewStep() {
    return [
      BookingSection(
        title: 'الملخص',
        icon: Icons.fact_check_rounded,
        trailing: TextButton(onPressed: () => setState(() => _step = 0), child: const Text('تعديل')),
        children: [
          InfoLine(
            icon: Icons.person_outline_rounded,
            label: 'الزبون',
            value: [if (_name.text.trim().isNotEmpty) _name.text.trim(), _normalizedPhone].join(' · '),
          ),
          InfoLine(icon: Icons.home_work_outlined, label: 'المكان', value: '${_property?['name'] ?? '—'}'),
          InfoLine(
            icon: Icons.event_outlined,
            label: 'الموعد',
            value: _start == null ? '—' : fmtRange(isoDay(_start!), isoDay(_end!)),
          ),
          InfoLine(icon: Icons.schedule_rounded, label: 'الشفت', value: shiftShort(_shift)),
          InfoLine(icon: Icons.people_outline, label: 'الضيوف', value: '$_guests'),
        ],
      ),
      BookingSection(
        title: 'خصم وملاحظات',
        icon: Icons.local_offer_rounded,
        color: placeShiftEvening,
        children: [
          StaffField(
            controller: _coupon,
            label: 'رمز الخصم (اختياري)',
            ltr: true,
            onChanged: (_) => _requote(),
            helper: _couponError == null && (asNum(_quote?['discount']) ?? 0) > 0
                ? 'رمز صالح — خصم ${formatIqd(_quote!['discount'])}'
                : null,
          ),
          if (_couponError != null) HintBanner(icon: Icons.error_outline_rounded, text: _couponError!, color: placeDanger),
          StaffField(controller: _notes, label: 'ملاحظات الحجز', hint: 'تظهر في تفاصيل الحجز', maxLines: 3),
        ],
      ),
      Pad(
        child: StaffCard(
          color: _confirmNow ? placeSuccess.withValues(alpha: .05) : Colors.white,
          borderColor: _confirmNow ? placeSuccess.withValues(alpha: .3) : placeLine,
          onTap: () => setState(() => _confirmNow = !_confirmNow),
          child: ToggleRow(
            title: 'تأكيد فوري واعتبار الدفع مستلماً',
            subtitle: 'للطلبات الهاتفية المدفوعة — وإلا يبقى الحجز «بانتظار التأكيد»',
            value: _confirmNow,
            onChanged: (v) => setState(() => _confirmNow = v),
          ),
        ),
      ),
      Pad(child: QuoteCard(quote: _quote, loading: _quoting, error: _quoteError)),
    ];
  }
}

/// شريط الخطوات (دوائر مرقّمة + خط تقدّم) — يُثبَّت أسفل رأس الصفحة.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.steps, required this.icons, required this.current, required this.onTap});
  final List<String> steps;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: placePaper,
      padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(StaffRadius.sm),
                onTap: i < current ? () => onTap(i) : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: i < current ? placeSuccess : (i == current ? placeInk : Colors.white),
                        shape: BoxShape.circle,
                        border: Border.all(color: i <= current ? Colors.transparent : placeLine),
                      ),
                      child: Icon(
                        i < current ? Icons.check_rounded : icons[i],
                        size: 16,
                        color: i <= current ? Colors.white : placeInk3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: i == current ? FontWeight.w900 : FontWeight.w700,
                        color: i <= current ? placeInk : placeInk3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < current ? placeSuccess : placeLine,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة اختيار كبيرة (اختيار مكان / بحث في الزبائن).
class _PickCard extends StatelessWidget {
  const _PickCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.large = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      color: placeGoldSoft,
      borderColor: placeGold.withValues(alpha: .45),
      padding: EdgeInsets.all(large ? 20 : 14),
      child: Row(
        children: [
          IconBox(icon: icon, color: placeBrass, size: large ? 52 : 44, filled: large),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: large ? 17 : 15, fontWeight: FontWeight.w900, color: placeInk)),
                Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: placeInk2)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: placeBrass),
        ],
      ),
    );
  }
}
