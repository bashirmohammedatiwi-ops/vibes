import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../../widgets/ui.dart';
import 'content_common.dart';

/// حالة الكوبون المحسوبة (كما في لوحة الإدارة).
enum CouponState { active, scheduled, expired, exhausted, inactive }

CouponState couponStateOf(Map<String, dynamic> c) {
  final now = DateTime.now();
  if (c['isActive'] != true) return CouponState.inactive;
  final expires = parseDate(c['expiresAt']);
  if (expires != null && expires.isBefore(now)) return CouponState.expired;
  final starts = parseDate(c['startsAt']);
  if (starts != null && starts.isAfter(now)) return CouponState.scheduled;
  final maxUses = c['maxUses'];
  if (maxUses != null && asInt(c['usedCount']) >= asInt(maxUses)) return CouponState.exhausted;
  return CouponState.active;
}

String couponStateLabel(CouponState s) => switch (s) {
  CouponState.active => 'فعّال',
  CouponState.scheduled => 'لم يبدأ',
  CouponState.expired => 'منتهي',
  CouponState.exhausted => 'مستنفد',
  CouponState.inactive => 'موقوف',
};

Color couponStateColor(CouponState s) => switch (s) {
  CouponState.active => placeSuccess,
  CouponState.scheduled => placeShiftMorning,
  CouponState.expired => placeDanger,
  CouponState.exhausted => const Color(0xFFB45309),
  CouponState.inactive => placeInk2,
};

String couponDiscountText(Map<String, dynamic> c) {
  final v = asDouble(c['discountValue']) ?? 0;
  if (c['discountType'] == 'FIXED') return 'خصم ${formatIqd(v)}';
  final n = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  return 'خصم $n%';
}

/// الكوبونات: بحث بالرمز، فلترة بالحالة، إنشاء/تعديل، تفعيل، حذف، وتجربة كوبون.
/// القراءة `coupons.read` — الكتابة `coupons.write`.
class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  static const _pageSize = 50;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _q = '';
  String _filter = 'ALL';
  final Set<String> _busy = {};
  int _seq = 0;

  bool get _canWrite => Session.can('coupons.write');

  static const _filters = ['ALL', 'active', 'scheduled', 'expired', 'exhausted', 'inactive'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _path(int page) {
    final params = <String>[
      'page=$page',
      'pageSize=$_pageSize',
      if (_q.isNotEmpty) 'q=${Uri.encodeQueryComponent(_q.toUpperCase())}',
      if (_filter == 'active' || _filter == 'scheduled' || _filter == 'exhausted') 'activeOnly=true',
    ];
    return '/api/admin/coupons?${params.join('&')}';
  }

  Future<void> _load({bool silent = false}) async {
    final seq = ++_seq;
    if (!silent) setState(() => _loading = true);
    try {
      final data = await Api.map(_path(1));
      if (seq != _seq) return;
      _rows = asMapList(data['items']);
      _page = 1;
      _totalPages = asInt(data['totalPages'], 1);
      _total = asInt(data['total']);
      _error = null;
    } catch (e) {
      if (seq != _seq) return;
      if (silent && _rows.isNotEmpty) {
        if (mounted) showToast(context, '$e', error: true);
      } else {
        _rows = [];
        _error = '$e';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    final seq = _seq;
    try {
      final data = await Api.map(_path(_page + 1));
      if (seq == _seq) {
        _rows.addAll(asMapList(data['items']));
        _page += 1;
        _totalPages = asInt(data['totalPages'], _totalPages);
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == 'ALL') return _rows;
    return _rows.where((c) => couponStateOf(c).name == _filter).toList();
  }

  Future<void> _toggle(Map<String, dynamic> row, bool value) async {
    final id = '${row['id']}';
    final prev = row['isActive'] == true;
    setState(() {
      row['isActive'] = value;
      _busy.add(id);
    });
    try {
      await Api.send('/api/admin/coupons/$id', method: 'PATCH', body: {'isActive': value});
      if (mounted) showToast(context, value ? 'تم تفعيل ${row['code']}' : 'تم إيقاف ${row['code']}');
    } catch (e) {
      row['isActive'] = prev;
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final used = asInt(asMap(row['_count'])['redemptions']) > 0 || asInt(row['usedCount']) > 0;
    final ok = await confirmDialog(
      context,
      title: 'حذف ${row['code']}؟',
      message: used ? 'هذا الكوبون مستخدم سابقاً، لذلك سيتم إيقافه بدلاً من حذفه للحفاظ على السجل.' : 'سيُحذف الكوبون نهائياً.',
      confirmLabel: used ? 'إيقاف' : 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    strongTap();
    try {
      final res = await Api.send('/api/admin/coupons/${row['id']}', method: 'DELETE');
      if (!mounted) return;
      if (res is Map && res['deactivated'] == true) {
        setState(() => row['isActive'] = false);
        showToast(context, 'الكوبون مستخدم — تم إيقافه بدلاً من حذفه');
      } else {
        setState(() {
          _rows.remove(row);
          _total = max(0, _total - 1);
        });
        showToast(context, 'تم حذف الكوبون');
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? row]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CouponEditorScreen(coupon: row)));
    if (saved == true && mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final hasMore = _page < _totalPages;
    final filtered = _q.isNotEmpty || _filter != 'ALL';
    final state = contentStateSliver(
      loading: _loading,
      error: _error,
      isEmpty: rows.isEmpty && !hasMore,
      onRetry: _load,
      emptyIcon: Icons.local_offer_outlined,
      emptyTitle: filtered ? 'لا كوبونات مطابقة' : 'لا توجد كوبونات',
      emptySubtitle: _canWrite && !filtered ? 'أنشئ أول كوبون خصم' : null,
      emptyActionLabel: _canWrite && !filtered ? 'كوبون جديد' : null,
      onEmptyAction: () => _openEditor(),
      skeletonHeight: 132,
    );
    return ContentAutoLoad(
      hasMore: hasMore && !_loading && _error == null,
      loading: _loadingMore,
      onLoadMore: _loadMore,
      child: StaffPage(
        title: 'الكوبونات',
        subtitle: _loading ? 'جارٍ التحميل…' : '$_total كوبون',
        onRefresh: () => _load(silent: true),
        actions: [
          IconButton(tooltip: 'تجربة كوبون', icon: const Icon(Icons.fact_check_outlined), onPressed: () => showCouponTester(context)),
        ],
        floatingActionButton: _canWrite
            ? FloatingActionButton.extended(
                onPressed: () => _openEditor(),
                backgroundColor: placeInk,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'كوبون جديد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                ),
              )
            : null,
        bottom: ContentToolbar(
          height: kContentToolbarHeight,
          children: [
            ContentSearchField(
              hint: 'ابحث برمز الكوبون',
              onChanged: (v) {
                _q = v;
                _load(silent: _rows.isNotEmpty);
              },
            ),
            ContentChips<String>(
              selected: _filter,
              options: [
                for (final f in _filters)
                  ContentChip(f, f == 'ALL' ? 'الكل' : couponStateLabel(CouponState.values.byName(f)), count: f == 'ALL' ? _total : null),
              ],
              onSelected: (v) {
                final serverChanged =
                    (v == 'active' || v == 'scheduled' || v == 'exhausted') !=
                    (_filter == 'active' || _filter == 'scheduled' || _filter == 'exhausted');
                setState(() => _filter = v);
                if (serverChanged) _load();
              },
            ),
          ],
        ),
        slivers: [
          if (!_canWrite)
            const SliverToBoxAdapter(child: ReadOnlyNotice(message: 'عرض فقط — لإنشاء أو تعديل الكوبونات اطلب صلاحية «تعديل الكوبونات».')),
          if (state != null)
            state
          else ...[
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                return Padding(
                  key: ValueKey(row['id']),
                  padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 10),
                  child: _CouponCard(
                    row: row,
                    canWrite: _canWrite,
                    busy: _busy.contains('${row['id']}'),
                    onToggle: (v) => _toggle(row, v),
                    onEdit: () => _openEditor(row),
                    onDelete: () => _delete(row),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: LoadMoreFooter(
                hasMore: hasMore,
                loading: _loadingMore,
                onLoadMore: _loadMore,
                total: _filter == 'ALL' ? _total : null,
              ),
            ),
          ],
          if (_canWrite) const SliverToBoxAdapter(child: SizedBox(height: 72)),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.row,
    required this.canWrite,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final bool canWrite;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  void _copy(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    lightTap();
    showToast(context, 'نُسخ الرمز $code');
  }

  @override
  Widget build(BuildContext context) {
    final state = couponStateOf(row);
    final color = couponStateColor(state);
    final code = row['code']?.toString() ?? '';
    final description = row['description']?.toString() ?? '';
    final used = asInt(row['usedCount']);
    final maxUses = row['maxUses'];
    final perUser = row['maxUsesPerUser'];
    final minTotal = asDouble(row['minBookingTotal']);
    final starts = parseDate(row['startsAt']);
    final expires = parseDate(row['expiresAt']);
    final types = (row['appliesToTypes'] as List? ?? []).map((e) => '$e').toList();
    final property = asMap(row['property']);

    final meta = <(IconData, String)>[
      (Icons.confirmation_number_outlined, maxUses == null ? 'استُخدم $used · بلا حد' : 'استُخدم $used من ${asInt(maxUses)}'),
      if (perUser != null) (Icons.person_outline_rounded, '${asInt(perUser)} لكل مستخدم'),
      if (minTotal != null && minTotal > 0) (Icons.price_check_rounded, 'حد أدنى ${formatIqd(minTotal)}'),
      if (starts != null || expires != null)
        (Icons.date_range_outlined, '${starts != null ? formatDay(starts) : 'الآن'} ← ${expires != null ? formatDay(expires) : 'مفتوح'}'),
      (Icons.category_outlined, types.isEmpty ? 'كل الأنواع' : types.map(placeTypeLabel).join('، ')),
      if (property.isNotEmpty) (Icons.place_outlined, property['name']?.toString() ?? ''),
    ];
    final usage = maxUses == null || asInt(maxUses) <= 0 ? null : (used / asInt(maxUses)).clamp(0.0, 1.0);

    return ContentRowCard(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 8),
      onTap: canWrite ? onEdit : null,
      onLongPress: () => _copy(context, code),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(icon: Icons.local_offer_rounded, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      couponDiscountText(row),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5, color: placeInk),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: placeGoldSoft.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: placeBrass.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                letterSpacing: 1.1,
                                color: placeInk,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(couponStateLabel(state), color: color, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (canWrite)
                busy
                    ? const InlineBusy()
                    : Switch.adaptive(value: row['isActive'] == true, activeTrackColor: placeGold, onChanged: onToggle),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [for (final m in meta) ContentMeta(icon: m.$1, text: m.$2)],
          ),
          if (usage != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: usage,
                minHeight: 5,
                backgroundColor: placeLineSoft,
                color: usage >= 1 ? placeDanger : placeGold,
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CardAction(icon: Icons.copy_rounded, tooltip: 'نسخ الرمز', onTap: () => _copy(context, code)),
              if (canWrite) ...[
                const SizedBox(width: 6),
                CardAction(icon: Icons.edit_outlined, tooltip: 'تعديل', onTap: onEdit),
                const SizedBox(width: 6),
                CardAction(icon: Icons.delete_outline_rounded, tooltip: 'حذف', onTap: onDelete, color: placeDanger),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// إنشاء/تعديل كوبون — كل حقول AdminCouponDto.
class CouponEditorScreen extends StatefulWidget {
  const CouponEditorScreen({super.key, this.coupon});

  final Map<String, dynamic>? coupon;

  @override
  State<CouponEditorScreen> createState() => _CouponEditorScreenState();
}

class _CouponEditorScreenState extends State<CouponEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _minTotal = TextEditingController();
  final _maxUses = TextEditingController();
  final _perUser = TextEditingController();

  String _type = 'PERCENT';
  DateTime? _startsAt;
  DateTime? _expiresAt;
  final Set<String> _types = {};
  String? _propertyId;
  String? _propertyName;
  bool _active = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.coupon != null;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    if (c != null) {
      _code.text = c['code']?.toString() ?? '';
      _description.text = c['description']?.toString() ?? '';
      _type = c['discountType']?.toString() ?? 'PERCENT';
      _value.text = _num(c['discountValue']);
      _minTotal.text = _num(c['minBookingTotal']);
      _maxUses.text = _num(c['maxUses']);
      _perUser.text = _num(c['maxUsesPerUser']);
      _startsAt = parseDate(c['startsAt']);
      _expiresAt = parseDate(c['expiresAt']);
      _types.addAll((c['appliesToTypes'] as List? ?? []).map((e) => '$e'));
      final p = asMap(c['property']);
      _propertyId = c['propertyId']?.toString() ?? p['id']?.toString();
      _propertyName = p['name']?.toString();
      if (_propertyId != null && _propertyName == null) _propertyName = 'مكان محدد';
      _active = c['isActive'] != false;
    }
  }

  String _num(dynamic v) {
    final d = asDouble(v);
    if (d == null) return '';
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  @override
  void dispose() {
    for (final c in [_code, _description, _value, _minTotal, _maxUses, _perUser]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final code = 'VIBES${List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join()}';
    setState(() {
      _code.text = code;
      _dirty = true;
    });
    lightTap();
  }

  String? _intValidator(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final n = parseNumber(s);
    if (n == null || n != n.roundToDouble() || n < 1) return 'رقم صحيح ≥ 1';
    return null;
  }

  Future<void> _pickProperty() async {
    final picked = await pickProperty(context);
    if (picked == null || !mounted) return;
    setState(() {
      _propertyId = picked.id;
      _propertyName = picked.name;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showToast(context, 'راجع الحقول المحددة بالأحمر', error: true);
      return;
    }
    if (_startsAt != null && _expiresAt != null && _startsAt!.isAfter(_expiresAt!)) {
      showToast(context, 'بداية الصلاحية بعد نهايتها', error: true);
      return;
    }
    setState(() => _saving = true);
    final minTotal = parseNumber(_minTotal.text);
    final maxUses = parseNumber(_maxUses.text)?.round();
    final perUser = parseNumber(_perUser.text)?.round();
    final starts = _startsAt == null ? null : DateTime(_startsAt!.year, _startsAt!.month, _startsAt!.day).toUtc().toIso8601String();
    final expires = _expiresAt == null
        ? null
        : DateTime(_expiresAt!.year, _expiresAt!.month, _expiresAt!.day, 23, 59, 59).toUtc().toIso8601String();
    final body = <String, dynamic>{
      'code': _code.text.trim().toUpperCase(),
      'description': _description.text.trim(),
      'discountType': _type,
      'discountValue': parseNumber(_value.text) ?? 0,
      'appliesToTypes': _types.toList(),
      'isActive': _active,
    };
    // عند الإنشاء نحذف الحقول الفارغة؛ عند التعديل نرسل null لمسح القيمة.
    void put(String key, Object? value) {
      if (value != null) {
        body[key] = value;
      } else if (_isEdit) {
        body[key] = null;
      }
    }

    put('minBookingTotal', minTotal);
    put('maxUses', maxUses);
    put('maxUsesPerUser', perUser);
    put('startsAt', starts);
    put('expiresAt', expires);
    put('propertyId', _propertyId);

    try {
      if (_isEdit) {
        await Api.send('/api/admin/coupons/${widget.coupon!['id']}', method: 'PATCH', body: body);
      } else {
        await Api.send('/api/admin/coupons', method: 'POST', body: body);
      }
      if (!mounted) return;
      showToast(context, _isEdit ? 'تم حفظ الكوبون' : 'تم إنشاء الكوبون ${body['code']}');
      _dirty = false;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<StaffBrand>()?.montserrat ?? const TextStyle();
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDiscard(context);
        if (leave && mounted) Navigator.of(this.context).pop();
      },
      child: ContentEditorScaffold(
        bar: BottomActionBar(label: _isEdit ? 'حفظ التعديلات' : 'إنشاء الكوبون', busy: _saving, onPressed: _save),
        child: Form(
          key: _formKey,
          onChanged: _touch,
          child: StaffPage(
            title: _isEdit ? 'تعديل الكوبون' : 'كوبون جديد',
            subtitle: _isEdit ? (widget.coupon!['code']?.toString() ?? '') : 'رمز خصم جديد للزبائن',
            slivers: [
              SliverList.list(
                children: [
                  FormSection(
                    title: 'الرمز',
                    subtitle: 'يُحوّل لحروف كبيرة تلقائياً',
                    icon: Icons.local_offer_outlined,
                    children: [
                      TextFormField(
                        controller: _code,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_\-]')), _UpperCaseFormatter()],
                        style: mono.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.4, color: placeInk),
                        validator: (v) => (v == null || v.trim().length < 3) ? 'الرمز 3 أحرف على الأقل' : null,
                        decoration: InputDecoration(
                          labelText: 'رمز الكوبون',
                          hintText: 'SUMMER25',
                          suffixIcon: IconButton(tooltip: 'توليد رمز', icon: const Icon(Icons.casino_outlined), onPressed: _generateCode),
                        ),
                      ),
                      StaffField(controller: _description, label: 'وصف داخلي (اختياري)', maxLines: 2),
                    ],
                  ),
                  FormSection(
                    title: 'قيمة الخصم',
                    icon: Icons.percent_rounded,
                    children: [
                      ChoicePills<String>(
                        options: const ['PERCENT', 'FIXED'],
                        value: _type,
                        labelOf: (t) => t == 'PERCENT' ? 'نسبة مئوية %' : 'مبلغ ثابت د.ع',
                        iconOf: (t) => t == 'PERCENT' ? Icons.percent_rounded : Icons.payments_outlined,
                        onChanged: (t) => setState(() {
                          _type = t;
                          _dirty = true;
                        }),
                      ),
                      StaffField(
                        controller: _value,
                        label: _type == 'PERCENT' ? 'النسبة (0 - 100)' : 'المبلغ بالدينار',
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        suffix: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _type == 'PERCENT' ? '%' : 'د.ع',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk2),
                          ),
                        ),
                        validator: (v) {
                          final n = parseNumber(v);
                          if (n == null) return 'أدخل قيمة الخصم';
                          if (n <= 0) return 'القيمة يجب أن تكون أكبر من صفر';
                          if (_type == 'PERCENT' && n > 100) return 'النسبة لا تتجاوز 100%';
                          return null;
                        },
                      ),
                      StaffField(
                        controller: _minTotal,
                        label: 'الحد الأدنى لإجمالي الحجز (اختياري)',
                        keyboard: TextInputType.number,
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return null;
                          final n = parseNumber(v);
                          return (n == null || n < 0) ? 'قيمة غير صالحة' : null;
                        },
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'حدود الاستخدام',
                    subtitle: 'اتركها فارغة لعدم التقييد',
                    icon: Icons.confirmation_number_outlined,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StaffField(
                              controller: _maxUses,
                              label: 'الاستخدام الكلي',
                              keyboard: TextInputType.number,
                              digitsOnly: true,
                              validator: _intValidator,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StaffField(
                              controller: _perUser,
                              label: 'لكل مستخدم',
                              keyboard: TextInputType.number,
                              digitsOnly: true,
                              validator: _intValidator,
                            ),
                          ),
                        ],
                      ),
                      if (_isEdit)
                        Text(
                          'استُخدم حتى الآن ${asInt(widget.coupon!['usedCount'])} مرة',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  FormSection(
                    title: 'فترة الصلاحية',
                    subtitle: 'ينتهي الكوبون بنهاية يوم الانتهاء',
                    icon: Icons.date_range_outlined,
                    children: [
                      DateField(
                        label: 'يبدأ من',
                        value: _startsAt,
                        onChanged: (d) => setState(() {
                          _startsAt = d;
                          _dirty = true;
                        }),
                      ),
                      DateField(
                        label: 'ينتهي في',
                        value: _expiresAt,
                        firstDate: _startsAt,
                        onChanged: (d) => setState(() {
                          _expiresAt = d;
                          _dirty = true;
                        }),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'نطاق التطبيق',
                    subtitle: 'بدون اختيار = كل الأنواع وكل الأماكن',
                    icon: Icons.category_outlined,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in const ['FARM', 'HALL', 'DECORATION'])
                            FilterChip(
                              label: Text(placeTypeLabel(t)),
                              avatar: Icon(placeTypeIcon(t), size: 17, color: _types.contains(t) ? Colors.white : placeInk2),
                              selected: _types.contains(t),
                              showCheckmark: false,
                              selectedColor: placeInk,
                              side: BorderSide(color: _types.contains(t) ? placeInk : placeLine),
                              labelStyle: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                                color: _types.contains(t) ? Colors.white : placeInk,
                              ),
                              onSelected: (on) => setState(() {
                                on ? _types.add(t) : _types.remove(t);
                                _dirty = true;
                              }),
                            ),
                        ],
                      ),
                      PropertyPickerField(
                        label: 'حصر بمكان محدد (اختياري)',
                        name: _propertyName,
                        placeholder: 'كل الأماكن',
                        onPick: _pickProperty,
                        onClear: () => setState(() {
                          _propertyId = null;
                          _propertyName = null;
                          _dirty = true;
                        }),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'الحالة',
                    icon: Icons.toggle_on_outlined,
                    children: [
                      ToggleRow(
                        title: 'فعّال',
                        subtitle: 'يمكن للزبائن استخدامه ضمن الشروط أعلاه',
                        value: _active,
                        onChanged: (v) => setState(() {
                          _active = v;
                          _dirty = true;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// أداة «تجربة كوبون» — POST /api/admin/coupons/validate (تتطلب coupons.read).
Future<void> showCouponTester(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _CouponTesterSheet(),
  );
}

class _CouponTesterSheet extends StatefulWidget {
  const _CouponTesterSheet();

  @override
  State<_CouponTesterSheet> createState() => _CouponTesterSheetState();
}

class _CouponTesterSheetState extends State<_CouponTesterSheet> {
  final _code = TextEditingController();
  final _total = TextEditingController();
  PickedProperty? _property;
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.trim();
    final total = parseNumber(_total.text);
    if (code.isEmpty || _property == null || total == null) {
      setState(() => _error = 'أدخل الرمز والمكان والإجمالي');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await Api.map(
        '/api/admin/coupons/validate',
        method: 'POST',
        body: {'code': code, 'propertyId': _property!.id, 'total': total},
      );
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تجربة كوبون',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk),
          ),
          const Text(
            'تحقق من صلاحية رمز على مكان ومبلغ محددين',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_UpperCaseFormatter()],
            decoration: const InputDecoration(labelText: 'الرمز', prefixIcon: Icon(Icons.local_offer_outlined)),
          ),
          const SizedBox(height: 10),
          PropertyPickerField(
            label: 'المكان',
            name: _property?.name,
            onPick: () async {
              final p = await pickProperty(context);
              if (p != null && mounted) setState(() => _property = p);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'إجمالي الحجز (د.ع)', prefixIcon: Icon(Icons.payments_outlined)),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: placeDanger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(
                _error!,
                style: const TextStyle(fontFamily: 'Cairo', color: placeDanger, fontWeight: FontWeight.w700),
              ),
            ),
          if (_result != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: placeSuccess.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ الكوبون ${_result!['code'] ?? ''} صالح',
                    style: const TextStyle(fontFamily: 'Cairo', color: placeSuccess, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الخصم: ${formatIqd(_result!['discount'])}',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk),
                  ),
                  Text(
                    'بعد الخصم: ${formatIqd(_result!['totalAfterDiscount'])}',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk),
                  ),
                ],
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('تحقق'),
          ),
        ],
      ),
    );
  }
}
