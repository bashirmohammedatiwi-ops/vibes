import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../../widgets/ui.dart' show FilterChipsRow;
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
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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
    final picked = await showActionSheet(
      context,
      title: 'مسح الإشعارات المقروءة',
      actions: const [
        SheetAction('30', 'الأقدم من 30 يوماً', Icons.history_rounded),
        SheetAction('7', 'الأقدم من 7 أيام', Icons.history_rounded),
        SheetAction('0', 'كل المقروءة', Icons.delete_sweep_outlined, danger: true),
      ],
    );
    final days = picked == null ? null : int.tryParse(picked);
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
    final color = _typeColor(type);
    showStaffSheet<void>(
      context,
      title: '${n['title'] ?? ''}',
      child: Builder(
        builder: (sheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusChip(_typeLabels[type] ?? type ?? '—', color: color == placeInk ? placeInk2 : color),
                  const Spacer(),
                  Text(fmtDateTime(n['createdAt']), style: catalogMetaStyle),
                ],
              ),
              if ('${n['body'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 12),
                StaffCard(
                  child: SelectableText('${n['body']}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: placeInk, height: 1.6)),
                ),
              ],
              if (n['entityType'] != null || n['entityId'] != null) ...[
                const SizedBox(height: 10),
                StaffCard(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
                  child: Column(
                    children: [
                      CopyRow(label: 'العنصر', value: '${n['entityType'] ?? ''}'),
                      CopyRow(label: 'المعرّف', value: '${n['entityId'] ?? ''}'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: placeDanger,
                    side: BorderSide(color: placeDanger.withValues(alpha: .4)),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await _delete(n);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف الإشعار'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: StaffPage(
        title: 'إشعارات الإدارة',
        subtitle: _loading && _items.isEmpty ? null : '${fmtCount(_unread)} غير مقروء من ${fmtCount(_total)}',
        bottom: catalogBusyBar(_busy),
        onRefresh: _load,
        actions: [
          IconButton(tooltip: 'تعليم الكل كمقروء', onPressed: _busy ? null : _readAll, icon: const Icon(Icons.done_all_rounded)),
          IconButton(tooltip: 'مسح المقروء', onPressed: _busy ? null : _clearRead, icon: const Icon(Icons.delete_sweep_outlined)),
        ],
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
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: FilterChipsRow(
                    options: ['ALL', ..._typeLabels.keys],
                    selected: _type,
                    onSelected: (v) {
                      setState(() => _type = v);
                      _load();
                    },
                    labelBuilder: (v) => v == 'ALL' ? 'كل الأنواع' : _typeLabels[v]!,
                  ),
                ),
                CatalogResultsLine(
                  text: _loading ? 'جارٍ التحميل…' : '${fmtCount(_total)} إشعار — اسحب البطاقة للحذف',
                ),
              ],
            ),
          ),
          if (_loading && _items.isEmpty)
            const SkeletonSliver(count: 8, height: 72)
          else if (_error != null && _items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: CatalogErrorView(message: _error!, onRetry: _load))
          else if (_items.isEmpty)
            SliverToBoxAdapter(
              child: EmptyView(
                icon: Icons.notifications_off_outlined,
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
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: placeBrass, strokeWidth: 2),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                return Pad(bottom: 8, child: _tile(_items[i]));
              },
            ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: placeDanger, borderRadius: BorderRadius.circular(StaffRadius.lg)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 6),
            Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
      child: StaffCard(
        padding: const EdgeInsets.all(12),
        color: unread ? placeGoldSoft : Colors.white,
        borderColor: unread ? placeGold.withValues(alpha: .35) : placeLine,
        onTap: () => _open(n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBox(icon: _typeIcon(type), color: color, size: 40),
            const SizedBox(width: 12),
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
                          style: catalogTitleStyle.copyWith(fontWeight: unread ? FontWeight.w900 : FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(relativeTimeAr(n['createdAt']), style: catalogMetaStyle),
                    ],
                  ),
                  if ('${n['body'] ?? ''}'.isNotEmpty)
                    Text(
                      '${n['body']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: catalogSubtitleStyle.copyWith(height: 1.45),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusChip(_typeLabels[type] ?? type ?? 'نظام', color: color == placeInk ? placeInk2 : color, dense: true),
                      const Spacer(),
                      if (unread)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(color: placeGold, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
