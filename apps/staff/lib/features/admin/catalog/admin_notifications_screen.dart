import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'catalog_common.dart';

const _typeLabels = <String, String>{
  'BOOKING_NEW': 'حجز جديد',
  'BOOKING_STATUS': 'تحديث حجز',
  'PAYMENT_PROOF': 'إثبات دفع',
  'PAYMENT_RECEIVED': 'دفعة مستلمة',
  'REVIEW_NEW': 'تقييم جديد',
  'PROPERTY_PENDING': 'مكان بانتظار',
  'MESSAGE': 'رسالة',
  'OFFER': 'عرض سعر',
  'INVOICE': 'فاتورة',
  'REFUND_REQUEST': 'طلب استرداد',
  'SOCIAL': 'اجتماعي',
  'SYSTEM': 'نظام',
};

IconData _typeIcon(String? t) => switch (t) {
      'BOOKING_NEW' => Icons.event_available_outlined,
      'BOOKING_STATUS' => Icons.event_note_outlined,
      'PAYMENT_PROOF' => Icons.receipt_long_outlined,
      'PAYMENT_RECEIVED' => Icons.payments_outlined,
      'REVIEW_NEW' => Icons.star_outline_rounded,
      'PROPERTY_PENDING' => Icons.home_work_outlined,
      'MESSAGE' => Icons.chat_bubble_outline_rounded,
      'OFFER' => Icons.local_offer_outlined,
      'INVOICE' => Icons.description_outlined,
      'REFUND_REQUEST' => Icons.currency_exchange_rounded,
      'SOCIAL' => Icons.groups_outlined,
      _ => Icons.notifications_none_rounded,
    };

Color _typeColor(String? t) => switch (t) {
      'BOOKING_NEW' || 'PAYMENT_RECEIVED' => placeSuccess,
      'PAYMENT_PROOF' || 'REFUND_REQUEST' => placeShiftMorning,
      'PROPERTY_PENDING' || 'OFFER' => placeShiftEvening,
      'REVIEW_NEW' => placeBrass,
      _ => placeInk,
    };

/// صندوق إشعارات الإدارة (activity.read): قراءة، قراءة الكل، مسح المقروء، حذف.
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  static const _pageSize = 30;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  int _unread = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  String? _error;
  bool _unreadOnly = false;
  String _type = 'ALL';
  String _q = '';
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
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

  String _query(int page) => Uri(queryParameters: {
        'page': '$page',
        'pageSize': '$_pageSize',
        if (_unreadOnly) 'unread': 'true',
        if (_type != 'ALL') 'type': _type,
        if (_q.isNotEmpty) 'q': _q,
      }).query;

  void _applyMeta(Map<String, dynamic> data) {
    _total = asNum(data['total']).toInt();
    _totalPages = asNum(data['totalPages']).toInt().clamp(1, 1 << 30);
    _unread = asNum(data['unreadCount']).toInt();
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/notifications?${_query(1)}');
      if (!mounted || id != _reqId) return;
      setState(() {
        _items
          ..clear()
          ..addAll((data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _page = 1;
        _applyMeta(data);
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
      final data = await Api.map('/api/admin/notifications?${_query(_page + 1)}');
      if (!mounted || id != _reqId) return;
      setState(() {
        final seen = _items.map((e) => '${e['id']}').toSet();
        _items.addAll((data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => !seen.contains('${e['id']}')));
        _page += 1;
        _applyMeta(data);
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

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['isRead'] == true) return;
    setState(() {
      n['isRead'] = true;
      _unread = (_unread - 1).clamp(0, 1 << 30);
    });
    try {
      await Api.send('/api/admin/notifications/${n['id']}/read', method: 'PATCH');
      if (_unreadOnly && mounted) {
        setState(() => _items.remove(n));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        n['isRead'] = false;
        _unread += 1;
      });
      showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _readAll() async {
    if (_unread == 0) {
      showToast(context, 'لا إشعارات غير مقروءة');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.send('/api/admin/notifications/read-all', method: 'POST');
      if (mounted) showToast(context, 'تم تعليم الكل كمقروء');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearRead() async {
    final days = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('مسح الإشعارات المقروءة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('تُحذف نهائياً — غير المقروءة لا تتأثر',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2)),
            ),
            for (final (d, label) in const [(30, 'الأقدم من 30 يوماً'), (7, 'الأقدم من 7 أيام'), (0, 'كل المقروءة')])
              ListTile(
                leading: Icon(d == 0 ? Icons.delete_sweep_outlined : Icons.history_rounded,
                    color: d == 0 ? placeDanger : placeInk),
                title: Text(label, style: TextStyle(color: d == 0 ? placeDanger : placeInk)),
                onTap: () => Navigator.pop(context, d),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (days == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد المسح',
      message: days == 0 ? 'حذف كل الإشعارات المقروءة نهائياً؟' : 'حذف المقروءة الأقدم من $days يوماً نهائياً؟',
      confirmLabel: 'مسح',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final res = await Api.map('/api/admin/notifications/clear-read', method: 'POST', body: {'olderThanDays': days});
      if (mounted) showToast(context, 'تم حذف ${fmtCount(res['deleted'])} إشعار');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _delete(Map<String, dynamic> n) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الإشعار',
      message: '«${n['title']}» سيُحذف نهائياً.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return false;
    try {
      await Api.send('/api/admin/notifications/${n['id']}', method: 'DELETE');
      if (!mounted) return true;
      setState(() {
        _items.remove(n);
        _total = (_total - 1).clamp(0, 1 << 30);
        if (n['isRead'] != true) _unread = (_unread - 1).clamp(0, 1 << 30);
      });
      showToast(context, 'تم حذف الإشعار');
      return true;
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
      return false;
    }
  }

  void _open(Map<String, dynamic> n) {
    _markRead(n);
    final type = n['type']?.toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusPill(label: _typeLabels[type] ?? type ?? '—', color: _typeColor(type), icon: _typeIcon(type)),
                  const Spacer(),
                  Text(fmtDateTime(n['createdAt']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2)),
                ],
              ),
              const SizedBox(height: 12),
              Text('${n['title'] ?? ''}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
              if ('${n['body'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText('${n['body']}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: placeInk, height: 1.6)),
              ],
              if (n['entityType'] != null || n['entityId'] != null) ...[
                const SizedBox(height: 10),
                CopyRow(label: 'العنصر', value: '${n['entityType'] ?? ''}'),
                CopyRow(label: 'المعرّف', value: '${n['entityId'] ?? ''}'),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: placeDanger),
                onPressed: () async {
                  Navigator.pop(sheet);
                  await _delete(n);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('حذف الإشعار'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إشعارات الإدارة'),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
        actions: [
          IconButton(tooltip: 'تعليم الكل كمقروء', onPressed: _busy ? null : _readAll, icon: const Icon(Icons.done_all_rounded)),
          IconButton(tooltip: 'مسح المقروء', onPressed: _busy ? null : _clearRead, icon: const Icon(Icons.delete_sweep_outlined)),
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
                  CatalogSearchField(controller: _search, hint: 'بحث في العنوان والنص…', onChanged: _onSearch),
                  FilterChipsRow(
                    options: const ['ALL', 'UNREAD'],
                    selected: _unreadOnly ? 'UNREAD' : 'ALL',
                    onSelected: (v) {
                      setState(() => _unreadOnly = v == 'UNREAD');
                      _load();
                    },
                    labelBuilder: (v) => v == 'UNREAD' ? 'غير المقروءة ($_unread)' : 'الكل',
                  ),
                  FilterChipsRow(
                    options: ['ALL', ..._typeLabels.keys],
                    selected: _type,
                    onSelected: (v) {
                      setState(() => _type = v);
                      _load();
                    },
                    labelBuilder: (v) => v == 'ALL' ? 'كل الأنواع' : _typeLabels[v]!,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Text(
                      _loading ? 'جارٍ التحميل…' : '${fmtCount(_total)} إشعار · ${fmtCount(_unread)} غير مقروء — اسحب لليسار للحذف',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2),
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: _unreadOnly ? 'لا إشعارات غير مقروءة' : 'لا إشعارات',
                  subtitle: 'كل شيء تحت السيطرة',
                ),
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
                            : const SizedBox.shrink(),
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

  Widget _tile(Map<String, dynamic> n) {
    final unread = n['isRead'] != true;
    final type = n['type']?.toString();
    final color = _typeColor(type);
    return Dismissible(
      key: ValueKey('notif-${n['id']}'),
      direction: DismissDirection.startToEnd, // في RTL: سحب لليسار
      confirmDismiss: (_) => _delete(n),
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: placeDanger, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: CatalogCard(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(12),
        onTap: () => _open(n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(type), size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${n['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                            color: placeInk,
                          ),
                        ),
                      ),
                      Text(relativeTimeAr(n['createdAt']),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk2)),
                    ],
                  ),
                  if ('${n['body'] ?? ''}'.isNotEmpty)
                    Text(
                      '${n['body']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, height: 1.4),
                    ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsetsDirectional.only(start: 8, top: 6),
                decoration: const BoxDecoration(color: placeBrass, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
