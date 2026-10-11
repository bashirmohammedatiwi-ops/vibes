import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/kit.dart';

/// الأسعار والتوفر: قواعد أسعار (أيام الأسبوع / مواسم) + حظر وفتح الأيام.
class PropertyPricingScreen extends StatelessWidget {
  const PropertyPricingScreen({super.key, required this.propertyId, required this.propertyName});

  final String propertyId;
  final String propertyName;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الأسعار والتوفر'),
              Text(
                propertyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
              ),
            ],
          ),
          bottom: const TabBar(
            labelColor: placeInk,
            unselectedLabelColor: placeInk3,
            indicatorColor: placeGold,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: placeLine,
            labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.sell_rounded, size: 20), iconMargin: EdgeInsets.only(bottom: 2), text: 'قواعد الأسعار'),
              Tab(icon: Icon(Icons.event_busy_rounded, size: 20), iconMargin: EdgeInsets.only(bottom: 2), text: 'التوفر والحظر'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RulesTab(propertyId: propertyId),
            _AvailabilityTab(propertyId: propertyId),
          ],
        ),
      ),
    );
  }
}

const _dayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const _dayShort = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

String _isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

// ───────────────────────── قواعد الأسعار ─────────────────────────

class _RulesTab extends StatefulWidget {
  const _RulesTab({required this.propertyId});
  final String propertyId;

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;
  String? _error;

  bool get _canWrite => Session.can('properties.write');
  String get _base => '/api/staff/properties/${widget.propertyId}/pricing-rules';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.list(_base);
      _rules = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Map<String, dynamic> rule, bool active) async {
    try {
      await Api.send('$_base/${rule['id']}', method: 'PATCH', body: {'isActive': active});
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> rule) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف القاعدة؟',
      message: 'ستُحذف قاعدة «${rule['name'] ?? ''}» ويعود التسعير للقواعد الأخرى/الافتراضي.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.send('$_base/${rule['id']}', method: 'DELETE');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _add() async {
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _RuleSheet(),
    );
    if (body == null) return;
    try {
      await Api.send(_base, method: 'POST', body: body);
      if (mounted) showToast(context, 'تمت إضافة القاعدة');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  String _describe(Map<String, dynamic> r) {
    if (r['ruleType'] == 'DATE_RANGE') {
      String d(dynamic v) => v == null ? '—' : '$v'.substring(0, 10);
      return 'من ${d(r['startDate'])} إلى ${d(r['endDate'])}';
    }
    final days = (r['daysOfWeek'] as List? ?? [])
        .map((e) => int.tryParse('$e'))
        .whereType<int>()
        .where((i) => i >= 0 && i < 7)
        .map((i) => _dayNames[i])
        .join('، ');
    return days.isEmpty ? 'أيام الأسبوع' : days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'قاعدة جديدة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(StaffSpace.page),
              physics: const NeverScrollableScrollPhysics(),
              children: const [SkeletonBox(height: 150), SizedBox(height: 10), SkeletonBox(height: 150)],
            )
          : _error != null
          ? Center(
              child: EmptyView(
                icon: Icons.cloud_off_rounded,
                title: 'تعذّر تحميل القواعد',
                subtitle: _error,
                actionLabel: 'إعادة المحاولة',
                onAction: _load,
              ),
            )
          : RefreshIndicator(
              color: placeGold,
              onRefresh: _load,
              child: _rules.isEmpty
                  ? ListView(
                      children: [
                        EmptyView(
                          icon: Icons.sell_outlined,
                          title: 'لا قواعد أسعار',
                          subtitle: 'يُستخدم السعر الافتراضي للمكان. أضف قاعدة لنهاية الأسبوع أو لموسم معيّن.',
                          actionLabel: _canWrite ? 'إضافة قاعدة' : null,
                          onAction: _canWrite ? _add : null,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(StaffSpace.page, StaffSpace.page, StaffSpace.page, 100),
                      itemCount: _rules.length,
                      separatorBuilder: (_, _) => const SizedBox(height: StaffSpace.gap),
                      itemBuilder: (context, i) => _ruleCard(_rules[i]),
                    ),
            ),
    );
  }

  Widget _ruleCard(Map<String, dynamic> r) {
    final active = r['isActive'] != false;
    final season = r['ruleType'] == 'DATE_RANGE';
    final color = season ? placeShiftEvening : placeBrass;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : .6,
      child: StaffCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBox(icon: season ? Icons.date_range_rounded : Icons.view_week_rounded, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (r['name']?.toString() ?? '').isEmpty ? 'قاعدة بدون اسم' : '${r['name']}',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15, color: placeInk),
                        ),
                        Text(
                          _describe(r),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            color: placeInk2,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(season ? 'موسم' : 'أسبوعية', color: color, dense: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (r['fullDayPrice'] != null) _PriceChip('يوم كامل', formatIqd(r['fullDayPrice'])),
                  if (r['morningPrice'] != null) _PriceChip('صباحي', formatIqd(r['morningPrice'])),
                  if (r['eveningPrice'] != null) _PriceChip('مسائي', formatIqd(r['eveningPrice'])),
                  _PriceChip('الأولوية', '${r['priority'] ?? 0}'),
                ],
              ),
            ),
            if (_canWrite) ...[
              const Divider(height: 1, color: placeLineSoft),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: ToggleRow(title: active ? 'مفعّلة' : 'معطّلة', value: active, onChanged: (v) => _toggle(r, v)),
                    ),
                    IconButton(
                      tooltip: 'حذف القاعدة',
                      onPressed: () => _delete(r),
                      icon: const Icon(Icons.delete_outline_rounded, color: placeDanger),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: placePaper,
        borderRadius: BorderRadius.circular(StaffRadius.sm),
        border: Border.all(color: placeLineSoft),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(color: placeInk2, fontSize: 11.5),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: placeInk),
            ),
          ],
        ),
        style: const TextStyle(fontFamily: 'Cairo'),
      ),
    );
  }
}

class _RuleSheet extends StatefulWidget {
  const _RuleSheet();

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  final _name = TextEditingController();
  final _full = TextEditingController();
  final _morning = TextEditingController();
  final _evening = TextEditingController();
  final _priority = TextEditingController(text: '0');
  String _type = 'WEEKDAY';
  final Set<int> _days = {4, 5}; // الخميس والجمعة افتراضياً
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _name.dispose();
    _full.dispose();
    _morning.dispose();
    _evening.dispose();
    _priority.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 4),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    if (_type == 'WEEKDAY' && _days.isEmpty) {
      showToast(context, 'اختر يوماً واحداً على الأقل', error: true);
      return;
    }
    if (_type == 'DATE_RANGE') {
      if (_start == null || _end == null) {
        showToast(context, 'حدّد بداية الفترة ونهايتها', error: true);
        return;
      }
      if (_end!.isBefore(_start!)) {
        showToast(context, 'نهاية الفترة قبل بدايتها', error: true);
        return;
      }
    }
    final full = parseNumber(_full.text);
    final morning = parseNumber(_morning.text);
    final evening = parseNumber(_evening.text);
    if (full == null && morning == null && evening == null) {
      showToast(context, 'أدخل سعراً واحداً على الأقل', error: true);
      return;
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'ruleType': _type,
      if (_type == 'WEEKDAY') 'daysOfWeek': (_days.toList()..sort()),
      if (_type == 'DATE_RANGE') 'startDate': _isoDay(_start!),
      if (_type == 'DATE_RANGE') 'endDate': _isoDay(_end!),
      if (full != null) 'fullDayPrice': full,
      if (morning != null) 'morningPrice': morning,
      if (evening != null) 'eveningPrice': evening,
      'priority': (parseNumber(_priority.text) ?? 0).round(),
      'isActive': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'قاعدة سعر جديدة',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk),
            ),
            const Text(
              'تتفوّق القاعدة على السعر الافتراضي في الأيام التي تنطبق عليها.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
            ),
            const SizedBox(height: 16),
            StaffField(controller: _name, label: 'اسم القاعدة', hint: 'مثال: أسعار نهاية الأسبوع'),
            const SizedBox(height: 14),
            const _SheetLabel('تنطبق على'),
            const SizedBox(height: 8),
            ChoicePills<String>(
              options: const ['WEEKDAY', 'DATE_RANGE'],
              iconOf: (t) => t == 'WEEKDAY' ? Icons.view_week_rounded : Icons.date_range_rounded,
              value: _type,
              labelOf: (t) => t == 'WEEKDAY' ? 'أيام الأسبوع' : 'فترة / موسم',
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            if (_type == 'WEEKDAY')
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(_dayNames[i]),
                      selected: _days.contains(i),
                      showCheckmark: false,
                      selectedColor: placeInk,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _days.contains(i) ? placeInk : placeLine),
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: _days.contains(i) ? Colors.white : placeInk,
                      ),
                      onSelected: (on) => setState(() => on ? _days.add(i) : _days.remove(i)),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _DateBox(label: 'من', date: _start, onTap: () => _pickDate(true)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateBox(label: 'إلى (شاملة)', date: _end, onTap: () => _pickDate(false)),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const _SheetLabel('الأسعار (د.ع) — سعر واحد على الأقل'),
            const SizedBox(height: 8),
            StaffField(controller: _full, label: 'سعر اليوم الكامل', keyboard: TextInputType.number),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StaffField(controller: _morning, label: 'سعر الصباحي', keyboard: TextInputType.number),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffField(controller: _evening, label: 'سعر المسائي', keyboard: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StaffField(
              controller: _priority,
              label: 'الأولوية',
              helper: 'الأعلى يتفوّق عند تعارض القواعد',
              keyboard: TextInputType.number,
              digitsOnly: true,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_rounded), label: const Text('إضافة القاعدة')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event_outlined, size: 19)),
        child: Text(
          date == null ? 'اختر' : _isoDay(date!),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, color: date == null ? placeInk2 : placeInk),
        ),
      ),
    );
  }
}

// ───────────────────────── التوفر ─────────────────────────

class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab({required this.propertyId});
  final String propertyId;

  @override
  State<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<_AvailabilityTab> {
  late DateTime _month;
  // yyyy-MM-dd -> قائمة الشفتات المحظورة
  Map<String, Set<String>> _blocked = {};
  final Set<String> _selected = {};
  String _shift = 'FULL';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _canWrite => Session.can('properties.write');
  String get _base => '/api/staff/properties/${widget.propertyId}/availability';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.list('$_base?month=${DateFormat('yyyy-MM').format(_month)}');
      final map = <String, Set<String>>{};
      for (final row in rows) {
        if (row is! Map || row['isAvailable'] != false) continue;
        final day = '${row['date']}'.substring(0, 10);
        map.putIfAbsent(day, () => {}).add('${row['shift']}');
      }
      _blocked = map;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected.clear();
    });
    _load();
  }

  Future<void> _apply({required bool block}) async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final dates = _selected.toList()..sort();
      final shifts = [_shift];
      if (block) {
        await Api.send('$_base/bulk', method: 'POST', body: {'dates': dates, 'isAvailable': false, 'shifts': shifts});
      } else {
        await Api.send('$_base/clear', method: 'POST', body: {'dates': dates, 'shifts': shifts});
      }
      HapticFeedback.mediumImpact();
      if (mounted) showToast(context, block ? 'تم حظر ${dates.length} يوم' : 'تم فتح ${dates.length} يوم');
      _selected.clear();
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7; // الأحد = 0
    final today = DateTime.now();
    final todayIso = _isoDay(DateTime(today.year, today.month, today.day));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(StaffSpace.page, 12, StaffSpace.page, 8),
          child: StaffCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                IconButton(tooltip: 'الشهر السابق', onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_right_rounded)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat.yMMMM('ar').format(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                      Text(
                        _canWrite ? 'اضغط الأيام لتحديدها ثم احظر أو افتح' : 'الأيام المحظورة باللون الأحمر',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: placeInk3),
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'الشهر التالي', onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_left_rounded)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
          child: Row(
            children: [
              for (final d in _dayShort)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: placeInk2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: placeGold))
              : _error != null
              ? Center(
                  child: EmptyView(
                    icon: Icons.cloud_off_rounded,
                    title: 'تعذّر تحميل التوفر',
                    subtitle: _error,
                    actionLabel: 'إعادة المحاولة',
                    onAction: _load,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: leading + daysInMonth,
                    itemBuilder: (context, i) {
                      if (i < leading) return const SizedBox.shrink();
                      final day = i - leading + 1;
                      final iso = _isoDay(DateTime(_month.year, _month.month, day));
                      final blockedShifts = _blocked[iso] ?? const <String>{};
                      final blocked = blockedShifts.isNotEmpty;
                      final selected = _selected.contains(iso);
                      final past = iso.compareTo(todayIso) < 0;
                      return GestureDetector(
                        onTap: !_canWrite ? null : () => setState(() => selected ? _selected.remove(iso) : _selected.add(iso)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(
                            color: selected
                                ? placeInk
                                : blocked
                                ? placeDanger.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(StaffRadius.sm),
                            border: Border.all(
                              color: selected
                                  ? placeInk
                                  : blocked
                                  ? placeDanger.withValues(alpha: 0.5)
                                  : (iso == todayIso ? placeGold : placeLine),
                              width: iso == todayIso ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : blocked
                                      ? placeDanger
                                      : (past ? placeInk2.withValues(alpha: 0.5) : placeInk),
                                ),
                              ),
                              if (blocked)
                                Text(
                                  blockedShifts.contains('FULL')
                                      ? 'محظور'
                                      : blockedShifts.length > 1
                                      ? 'شفتان'
                                      : (blockedShifts.first == 'MORNING' ? 'صباحي' : 'مسائي'),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: selected ? Colors.white70 : placeDanger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (_canWrite)
          Container(
            padding: EdgeInsets.fromLTRB(StaffSpace.page, 12, StaffSpace.page, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: placeLine)),
              boxShadow: [BoxShadow(color: Color(0x120F1B2D), blurRadius: 18, offset: Offset(0, -4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _Legend(color: placeDanger, label: 'محظور'),
                    const SizedBox(width: 12),
                    const _Legend(color: placeGold, label: 'اليوم', outline: true),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      TextButton(onPressed: () => setState(_selected.clear), child: Text('إلغاء التحديد (${_selected.length})')),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoicePills<String>(
                        options: const ['FULL', 'MORNING', 'EVENING'],
                        value: _shift,
                        labelOf: (s) => switch (s) {
                          'MORNING' => 'صباحي',
                          'EVENING' => 'مسائي',
                          _ => 'اليوم كاملاً',
                        },
                        onChanged: (v) => setState(() => _shift = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_busy || _selected.isEmpty) ? null : () => _apply(block: false),
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: Text('فتح (${_selected.length})'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: placeDanger),
                        onPressed: (_busy || _selected.isEmpty) ? null : () => _apply(block: true),
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.block_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text('حظر (${_selected.length})'),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: placeInk),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.outline = false});
  final Color color;
  final String label;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outline ? Colors.white : color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: outline ? 1.6 : 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk2),
        ),
      ],
    );
  }
}
