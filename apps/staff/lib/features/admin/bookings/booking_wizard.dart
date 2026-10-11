import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('حجز جديد')),
        bottomNavigationBar: BottomActionBar(
          label: _step == _steps.length - 1 ? 'إنشاء الحجز' : 'التالي',
          busy: _creating,
          onPressed: _next,
          secondaryLabel: _step == 0 ? 'إلغاء' : 'السابق',
          onSecondary: _back,
        ),
        body: Column(
          children: [
            _StepHeader(steps: _steps, current: _step, onTap: (i) {
              if (i < _step) setState(() => _step = i);
            }),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
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
          ],
        ),
      ),
    );
  }

  List<Widget> _customerStep() {
    final canSearch = Session.can('users.read');
    return [
      FormSection(
        title: 'بيانات الزبون',
        subtitle: canSearch
            ? 'اختر زبوناً موجوداً أو أدخل رقماً جديداً'
            : 'أدخل رقم الزبون — يُنشأ حسابه تلقائياً إن لم يكن مسجلاً',
        icon: Icons.person_outline_rounded,
        children: [
          if (canSearch)
            OutlinedButton.icon(
              onPressed: _chooseCustomer,
              icon: const Icon(Icons.person_search_outlined),
              label: Text(_customer == null ? 'بحث في الزبائن' : 'تغيير الزبون'),
            ),
          if (_customer != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: placeSuccess.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: placeSuccess.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: placeSuccess),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'زبون مسجّل · ${asMap(_customer!['_count'])?['bookings'] ?? 0} حجز سابق',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeSuccess),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _customer = null;
                      _phone.clear();
                      _name.clear();
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
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
    return [
      FormSection(
        title: 'المكان',
        subtitle: 'الأماكن المنشورة فقط قابلة للحجز',
        icon: Icons.home_work_outlined,
        children: [
          if (p == null)
            _BigPickButton(icon: Icons.search_rounded, label: 'اختر المكان', onTap: _chooseProperty)
          else ...[
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: placeBrass.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(placeTypeIcon(p['type']?.toString()), color: placeBrass),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['name']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(
                        [
                          placeTypeLabel(p['type']?.toString()),
                          if (asMap(p['city'])?['nameAr'] != null) '${asMap(p['city'])!['nameAr']}',
                        ].join(' · '),
                        style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (_loadingProperty)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (p['pricePerDay'] != null) StatusPill(label: 'اليوم ${formatIqd(p['pricePerDay'])}', color: placeInk),
                if (p['priceMorningShift'] != null)
                  StatusPill(label: 'صباحي ${formatIqd(p['priceMorningShift'])}', color: placeShiftMorning),
                if (p['priceEveningShift'] != null)
                  StatusPill(label: 'مسائي ${formatIqd(p['priceEveningShift'])}', color: placeShiftEvening),
                if ((asNum(p['capacity']) ?? 0) > 0) StatusPill(label: 'السعة ${p['capacity']}', color: placeInk2),
                StatusPill(
                  label: _shiftOptions.length == 1
                      ? (_shiftOptions.first == 'FULL' ? 'يوم كامل فقط' : 'شفت واحد')
                      : (_shiftOptions.contains('FULL') ? 'يوم كامل أو شفتات' : 'شفتات فقط'),
                  color: placeBrass,
                ),
              ],
            ),
            OutlinedButton.icon(onPressed: _chooseProperty, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('تغيير المكان')),
          ],
        ],
      ),
    ];
  }

  List<Widget> _scheduleStep() {
    final capacity = (asNum(_property?['capacity']) ?? 0).toInt();
    return [
      FormSection(
        title: 'الموعد',
        icon: Icons.event_outlined,
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
            Align(alignment: AlignmentDirectional.centerStart, child: ShiftBadge(shift: _shiftOptions.first)),
          if (_shift == 'FULL')
            DaysStepper(
              value: _days,
              onChanged: (v) {
                setState(() => _days = v);
                _requote();
              },
            ),
          DaysStepper(
            label: capacity > 0 ? 'عدد الضيوف (السعة $capacity)' : 'عدد الضيوف',
            value: _guests,
            max: capacity > 0 ? capacity : 2000,
            onChanged: (v) => setState(() => _guests = v),
          ),
          if (_start != null && _days > 1)
            Text(
              'من ${fmtDay(_start!)} حتى ${fmtDay(_end!.subtract(const Duration(days: 1)))}',
              style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: QuoteCard(quote: _quote, loading: _quoting, error: _quoteError),
      ),
    ];
  }

  List<Widget> _reviewStep() {
    return [
      FormSection(
        title: 'الملخص',
        icon: Icons.fact_check_outlined,
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
      FormSection(
        title: 'خصم وملاحظات',
        icon: Icons.local_offer_outlined,
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
          if (_couponError != null)
            Text(_couponError!, style: const TextStyle(fontFamily: 'Cairo', color: placeDanger, fontWeight: FontWeight.w800)),
          StaffField(controller: _notes, label: 'ملاحظات الحجز', hint: 'تظهر في تفاصيل الحجز', maxLines: 3),
          ToggleRow(
            title: 'تأكيد فوري واعتبار الدفع مستلماً',
            subtitle: 'للطلبات الهاتفية المدفوعة — وإلا يبقى الحجز «بانتظار التأكيد»',
            value: _confirmNow,
            onChanged: (v) => setState(() => _confirmNow = v),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: QuoteCard(quote: _quote, loading: _quoting, error: _quoteError),
      ),
    ];
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.steps, required this.current, required this.onTap});
  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= current ? placeBrass : placeLine,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${i + 1}. ${steps[i]}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: i == current ? FontWeight.w900 : FontWeight.w700,
                        color: i <= current ? placeInk : placeInk2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < steps.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _BigPickButton extends StatelessWidget {
  const _BigPickButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: placePaper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: placeBrass.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: placeBrass, size: 28),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
          ],
        ),
      ),
    );
  }
}
