import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'payment_detail.dart';
import 'people_common.dart';

/// المدفوعات: فلاتر الحالة وطريقة الدفع، إثباتات بانتظار المراجعة، واعتماد/رفض جماعي — `payments.read`.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key, this.initialStatus = 'PENDING', this.proofOnly = false});
  final String initialStatus;
  final bool proofOnly;

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _list = PagedListController();
  String _q = '';
  late String _status = widget.initialStatus;
  String _method = 'all';
  late bool _proofOnly = widget.proofOnly;
  int? _total;
  int _pendingProof = 0;
  final Set<String> _selected = {};

  bool get _canVerify => Session.can('payments.verify');
  bool get _selecting => _selected.isNotEmpty;

  Future<PageResult> _fetch(int page) => fetchPage(
        '/api/admin/payments',
        {
          'q': _q,
          'status': _status == 'all' ? null : _status,
          'method': _method == 'all' ? null : _method,
          'hasProof': _proofOnly ? 'true' : null,
        },
        page: page,
      );

  void _toggle(Map<String, dynamic> p) {
    if (!_canVerify || p['status'] != 'PENDING') return;
    HapticFeedback.selectionClick();
    setState(() {
      final id = '${p['id']}';
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  Future<void> _open(Map<String, dynamic> p) async {
    if (_selecting) return _toggle(p);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminPaymentDetailScreen(paymentId: '${p['id']}')),
    );
    if (changed == true) _list.reload();
  }

  Future<void> _bulk(String status) async {
    final ids = _selected.toList();
    String? note;
    if (status == 'FAILED') {
      note = await showInputSheet(
        context,
        title: 'رفض ${ids.length} دفعة',
        subtitle: 'سبب الرفض يُحفظ مع كل دفعة.',
        label: 'سبب الرفض',
        confirmLabel: 'رفض المحدد',
        required: true,
        maxLines: 3,
        danger: true,
      );
      if (note == null || !mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'رفض ${ids.length} دفعة؟',
        message: 'ستُعلَّم الدفعات المحددة «فشل» مع سبب الرفض.',
        confirmLabel: 'رفض',
        danger: true,
      );
      if (!ok) return;
    } else {
      final ok = await confirmDialog(
        context,
        title: 'اعتماد ${ids.length} دفعة؟',
        message: 'ستُعلَّم الدفعات المحددة مدفوعة وتتأكد حجوزاتها تلقائياً.',
        confirmLabel: 'اعتماد',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    try {
      final res = await withBusy(
        context,
        () => Api.map('/api/admin/payments/bulk', method: 'POST', body: {
          'ids': ids,
          'status': status,
          if (note != null && note.isNotEmpty) 'adminNote': note,
        }),
      );
      if (!mounted) return;
      final updated = asInt(res?['updated']);
      final failed = asInt(res?['failed']);
      showToast(context, failed == 0 ? 'تم تحديث $updated دفعة' : 'تم $updated · تعذّر $failed', error: failed > 0 && updated == 0);
      setState(_selected.clear);
      _list.reload();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  void _selectAll() {
    setState(() {
      for (final p in _list.items) {
        if (p['status'] == 'PENDING') _selected.add('${p['id']}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: PagedStaffPage(
        title: _selecting ? '${_selected.length} محددة' : 'المدفوعات',
        subtitle: _selecting ? 'اعتمد أو ارفض الدفعات المحددة' : (_total == null ? null : '$_total دفعة'),
        leading: _selecting
            ? IconButton(tooltip: 'إلغاء التحديد', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_selected.clear))
            : null,
        actions: [
          if (_selecting) IconButton(tooltip: 'تحديد الكل', icon: const Icon(Icons.select_all_rounded), onPressed: _selectAll),
        ],
        resetKey: '$_q|$_status|$_method|$_proofOnly',
        controller: _list,
        fetch: _fetch,
        onLoaded: (r) => setState(() {
          _total = r.total;
          _pendingProof = asInt(r.raw['pendingProof']);
        }),
        search: SearchBox(
          hint: 'الزبون، الهاتف، المكان أو رقم العملية',
          padding: SearchBox.barPadding,
          onChanged: (v) => setState(() => _q = v),
        ),
        filters: FilterBar(groups: [
          FilterGroup(
            options: const ['PENDING', 'PAID', 'FAILED', 'REFUNDED', 'all'],
            selected: _status,
            labelOf: (v) => v == 'all' ? 'كل الحالات' : paymentStatusAr(v),
            onSelected: (v) => setState(() {
              _status = v;
              _selected.clear();
            }),
          ),
          FilterGroup(
            options: const ['proof'],
            selected: _proofOnly ? 'proof' : '',
            labelOf: (_) => 'مع إثبات',
            onSelected: (_) => setState(() => _proofOnly = !_proofOnly),
          ),
          FilterGroup(
            options: const ['all', 'MANUAL', 'ZAIN_CASH', 'QI_CARD'],
            selected: _method,
            labelOf: (v) => v == 'all' ? 'كل الطرق' : methodLabel(v),
            onSelected: (v) => setState(() => _method = v),
          ),
        ]),
        listHeader: _header(),
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: _status == 'PENDING' ? 'لا مدفوعات بانتظار التحقق' : 'لا مدفوعات',
        emptySubtitle: 'غيّر الفلاتر لعرض المزيد',
        itemBuilder: (context, p, _) => _PaymentCard(
          payment: p,
          selected: _selected.contains('${p['id']}'),
          onTap: () => _open(p),
          onLongPress: () => _toggle(p),
        ),
        bottomBar: _selecting
            ? ActionBarShell(
                child: Row(
                  children: [
                    Expanded(
                      child: BarButton(label: 'رفض المحدد', color: placeDanger, outlined: true, onPressed: () => _bulk('FAILED')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: BarButton(
                        label: 'اعتماد ${_selected.length}',
                        icon: Icons.check_circle_rounded,
                        color: placeSuccess,
                        onPressed: () => _bulk('PAID'),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget? _header() {
    final banner = _pendingProof > 0 && !(_status == 'PENDING' && _proofOnly);
    final hint = _canVerify && _status == 'PENDING' && !_selecting;
    if (!banner && !hint) return null;
    return Column(
      children: [
        if (banner)
          NoticeBanner(
            title: '$_pendingProof إثبات دفع بانتظار المراجعة',
            text: 'اضغط لعرضها',
            color: placeWarning,
            icon: Icons.receipt_long_rounded,
            onTap: () => setState(() {
              _status = 'PENDING';
              _proofOnly = true;
            }),
          ),
        if (hint)
          const Padding(
            padding: EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 8),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 16, color: placeInk3),
                SizedBox(width: 6),
                Text('اضغط مطولاً على دفعة للتحديد الجماعي', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w600, color: placeInk3)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.selected, required this.onTap, required this.onLongPress});
  final Map<String, dynamic> payment;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final booking = asMap(p['booking']);
    final user = asMap(booking['user']);
    final status = p['status']?.toString();
    final hasProof = (p['proofUrl']?.toString() ?? '').isNotEmpty;
    final needsReview = status == 'PENDING' && hasProof;
    return ListCard(
      selected: selected,
      highlight: needsReview ? placeWarning.withValues(alpha: 0.45) : null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ListRow(
        leading: selected
            ? const SizedBox(width: 44, height: 44, child: Icon(Icons.check_circle_rounded, color: placeGold, size: 30))
            : IconBox(icon: methodIcon(p['method']?.toString()), color: paymentStatusColor(status), size: 44),
        title: nonEmpty(asMap(booking['property'])['name'], 'دفعة'),
        subtitle: '${nonEmpty(user['name'] ?? booking['guestName'], 'زبون')} · ${methodLabel(p['method']?.toString())}',
        chips: [
          StatusChip(paymentStatusAr(status), color: paymentStatusColor(status), dense: true),
          if (hasProof) const StatusChip('إثبات', color: placeShiftEvening, dense: true),
        ],
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MetaText(formatIqd(p['amount']), strong: true),
            const SizedBox(height: 4),
            MetaText(relativeAr(p['createdAt'])),
          ],
        ),
      ),
    );
  }
}
