import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/shift.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'catalog_common.dart';

const activityActionLabels = <String, String>{
  'property.create': 'إنشاء مكان',
  'property.update': 'تحديث مكان',
  'property.delete': 'حذف مكان',
  'property.publish': 'نشر مكان',
  'property.suspend': 'إيقاف مكان',
  'property.reject': 'رفض مكان',
  'property.duplicate': 'نسخ مكان',
  'property.bulk': 'إجراء جماعي',
  'media.upload': 'رفع صورة',
  'media.delete': 'حذف صورة',
  'media.reorder': 'إعادة ترتيب الصور',
  'media.set_primary': 'تعيين غلاف',
  'booking.create': 'إنشاء حجز',
  'booking.reschedule': 'إعادة جدولة',
  'booking.status': 'تحديث حجز',
  'booking.note': 'ملاحظة حجز',
  'booking.note.edit': 'تعديل ملاحظة',
  'booking.note.delete': 'حذف ملاحظة',
  'booking.dispute': 'فتح نزاع',
  'booking.dispute.resolve': 'حل نزاع',
  'user.create': 'إنشاء مستخدم',
  'user.update': 'تحديث مستخدم',
  'user.deactivate': 'تعطيل مستخدم',
  'user.delete': 'حذف مستخدم',
  'review.show': 'إظهار تقييم',
  'review.hide': 'إخفاء تقييم',
  'review.delete': 'حذف تقييم',
  'payment.status': 'تحديث دفعة',
  'payment.review': 'مراجعة دفعة',
  'payment.proof': 'رفع إثبات دفع',
  'payment.refund': 'استرداد دفعة',
  'refund.approve': 'قبول استرداد',
  'refund.reject': 'رفض استرداد',
  'social.moderate': 'مراجعة منشور',
  'banner.create': 'إنشاء بانر',
  'banner.update': 'تحديث بانر',
  'banner.delete': 'حذف بانر',
  'location.province': 'إضافة محافظة',
  'location.province.create': 'إضافة محافظة',
  'location.province.update': 'تعديل محافظة',
  'location.province.delete': 'حذف محافظة',
  'location.city': 'إضافة مدينة',
  'location.city.create': 'إضافة مدينة',
  'location.city.update': 'تعديل مدينة',
  'location.city.delete': 'حذف مدينة',
  'amenity.create': 'إضافة ميزة',
  'amenity.update': 'تعديل ميزة',
  'amenity.delete': 'حذف ميزة',
  'provider.verify': 'توثيق مزود',
  'provider.reject': 'رفض مزود',
  'provider.revoke': 'إلغاء توثيق',
  'settings.update': 'تحديث الإعدادات',
  'coupon.create': 'إنشاء كوبون',
  'coupon.update': 'تعديل كوبون',
  'coupon.delete': 'حذف كوبون',
  'seed.complete': 'تهيئة النظام',
};

const _entityLabels = <String, String>{
  'property': 'مكان',
  'booking': 'حجز',
  'payment': 'دفعة',
  'user': 'مستخدم',
  'provider': 'مزود',
  'review': 'تقييم',
  'media': 'صورة',
  'banner': 'بانر',
  'amenity': 'ميزة',
  'province': 'محافظة',
  'city': 'مدينة',
  'location': 'موقع',
  'coupon': 'كوبون',
  'refund': 'استرداد',
  'social': 'اجتماعي',
  'settings': 'إعدادات',
};

String activityLabel(String action) {
  final hit = activityActionLabels[action];
  if (hit != null) return hit;
  // أقرب بادئة معروفة (مثل booking.status.x)
  final parts = action.split('.');
  while (parts.length > 1) {
    parts.removeLast();
    final p = activityActionLabels[parts.join('.')];
    if (p != null) return p;
  }
  return action;
}

IconData _entityIcon(String? type) => switch (type) {
      'property' => Icons.home_work_outlined,
      'booking' => Icons.event_note_outlined,
      'payment' => Icons.payments_outlined,
      'user' => Icons.person_outline,
      'provider' => Icons.storefront_outlined,
      'review' => Icons.star_outline_rounded,
      'media' => Icons.photo_outlined,
      'banner' => Icons.view_carousel_outlined,
      'amenity' => Icons.sell_outlined,
      'province' || 'city' || 'location' => Icons.location_on_outlined,
      'coupon' => Icons.local_offer_outlined,
      'settings' => Icons.settings_outlined,
      _ => Icons.history_rounded,
    };

Color _actionColor(String action) {
  if (action.contains('delete') || action.contains('reject') || action.contains('suspend') || action.contains('deactivate')) {
    return placeDanger;
  }
  if (action.contains('create') || action.contains('publish') || action.contains('approve') || action.contains('verify')) {
    return placeSuccess;
  }
  return placeInk;
}

String? _metaSummary(String action, dynamic raw) {
  if (raw is! Map || raw.isEmpty) return null;
  final m = Map<String, dynamic>.from(raw);
  final parts = <String>[];
  if (m['name'] != null) parts.add('${m['name']}');
  if (m['type'] is String) parts.add(placeTypeLabel(m['type'] as String));
  if (m['status'] is String) {
    final s = m['status'] as String;
    final b = bookingStatusAr(s);
    parts.add('الحالة: ${b != s ? b : placeStatusLabel(s)}');
  }
  if (m['reason'] != null) parts.add('${m['reason']}');
  if (action == 'property.bulk' && m['action'] != null) parts.add('إجراء: ${m['action']}');
  if (m['count'] is num) parts.add('${m['count']} عنصر');
  return parts.isEmpty ? null : parts.join(' · ');
}

/// سجل نشاط الفريق — فلاتر وبحث وتحميل تدريجي (activity.read).
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key, this.entityType, this.entityId});

  /// فلترة اختيارية مسبقة (مثلاً سجل مكان معيّن).
  final String? entityType;
  final String? entityId;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _pageSize = 30;
  static const _entityFilters = [
    'ALL', 'property', 'booking', 'payment', 'user', 'provider', 'review', //
    'amenity', 'province', 'city', 'media', 'banner', 'settings',
  ];

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _entity = 'ALL';
  String _q = '';
  DateTimeRange? _range;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.entityType != null) _entity = widget.entityType!;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _query(int page) {
    final params = <String, String>{
      'page': '$page',
      'pageSize': '$_pageSize',
      if (_entity != 'ALL') 'entityType': _entity,
      if (widget.entityId != null) 'entityId': widget.entityId!,
      if (_q.isNotEmpty) 'q': _q,
      if (_range != null) 'from': isoDay(_range!.start),
      if (_range != null) 'to': isoDay(_range!.end),
    };
    return Uri(queryParameters: params).query;
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/activities?${_query(1)}');
      if (!mounted || id != _reqId) return;
      setState(() {
        _items
          ..clear()
          ..addAll((data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _page = 1;
        _total = asNum(data['total']).toInt();
        _totalPages = asNum(data['totalPages']).toInt().clamp(1, 1 << 30);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    final id = _reqId;
    setState(() => _loadingMore = true);
    try {
      final data = await Api.map('/api/admin/activities?${_query(_page + 1)}');
      if (!mounted || id != _reqId) return;
      setState(() {
        _items.addAll((data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _page += 1;
        _totalPages = asNum(data['totalPages']).toInt().clamp(1, 1 << 30);
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (_q == v.trim()) return;
      _q = v.trim();
      _load();
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'فترة السجل',
      saveText: 'تطبيق',
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  void _showDetail(Map<String, dynamic> row) {
    final user = row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : <String, dynamic>{};
    final meta = row['metadata'];
    final metaText = meta is Map && meta.isNotEmpty ? const JsonEncoder.withIndent('  ').convert(meta) : null;
    final action = '${row['action'] ?? ''}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(activityLabel(action),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w900, color: placeInk)),
            const SizedBox(height: 4),
            Text(fmtDateTime(row['createdAt']), style: const TextStyle(fontFamily: 'Cairo', color: placeInk2)),
            const SizedBox(height: 14),
            CopyRow(label: 'المنفّذ', value: '${user['name'] ?? ''}', ltr: false),
            CopyRow(label: 'الهاتف', value: '${user['phone'] ?? ''}'),
            CopyRow(label: 'رمز الإجراء', value: action),
            CopyRow(label: 'نوع العنصر', value: _entityLabels[row['entityType']] ?? '${row['entityType'] ?? ''}', ltr: false),
            CopyRow(label: 'معرّف العنصر', value: '${row['entityId'] ?? ''}'),
            if (metaText != null) ...[
              const SizedBox(height: 12),
              const Text('البيانات الإضافية',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(
                  metaText,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: placeInk),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل النشاط'),
        actions: [
          IconButton(
            tooltip: 'الفترة',
            onPressed: _pickRange,
            icon: Icon(Icons.date_range_rounded, color: _range != null ? placeBrass : placeInk),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CatalogSearchField(controller: _search, hint: 'بحث بالاسم أو الهاتف أو الإجراء…', onChanged: _onSearch),
                  if (widget.entityId == null)
                    FilterChipsRow(
                      options: _entityFilters,
                      selected: _entity,
                      onSelected: (v) {
                        setState(() => _entity = v);
                        _load();
                      },
                      labelBuilder: (v) => v == 'ALL' ? 'الكل' : (_entityLabels[v] ?? v),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _loading ? 'جارٍ التحميل…' : '${fmtCount(_total)} سجل',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk2),
                          ),
                        ),
                        if (_range != null)
                          InputChip(
                            label: Text('${fmtShortDate(_range!.start)} – ${fmtShortDate(_range!.end)}'),
                            labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700),
                            onDeleted: () {
                              setState(() => _range = null);
                              _load();
                            },
                            onPressed: _pickRange,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_loading && _items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: placeBrass)),
              )
            else if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: placeInk2)),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                  ],
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(title: 'لا نشاط مطابق', subtitle: 'غيّر الفلاتر أو الفترة'),
              )
            else
              SliverList.builder(
                itemCount: _items.length + 1,
                itemBuilder: (context, i) {
                  if (i == _items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: _loadingMore
                            ? const CircularProgressIndicator(color: placeBrass, strokeWidth: 2)
                            : Text(
                                _page >= _totalPages ? 'نهاية السجل' : '',
                                style: const TextStyle(fontFamily: 'Cairo', color: placeInk2),
                              ),
                      ),
                    );
                  }
                  return _tile(_items[i]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> row) {
    final action = '${row['action'] ?? ''}';
    final type = row['entityType']?.toString();
    final user = row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : <String, dynamic>{};
    final color = _actionColor(action);
    final meta = _metaSummary(action, row['metadata']);
    return CatalogCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
      onTap: () => _showDetail(row),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_entityIcon(type), size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(activityLabel(action),
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                    ),
                    Text(relativeTimeAr(row['createdAt']),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk2)),
                  ],
                ),
                Text(
                  '${user['name'] ?? user['phone'] ?? 'النظام'}${type != null ? ' · ${_entityLabels[type] ?? type}' : ''}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2),
                ),
                if (meta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
