import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
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
      if (note == null) return;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                backgroundColor: placeInk,
                foregroundColor: Colors.white,
                leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_selected.clear)),
                title: Text('${_selected.length} محددة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final p in _list.items) {
                          if (p['status'] == 'PENDING') _selected.add('${p['id']}');
                        }
                      });
                    },
                    child: const Text('تحديد الكل', style: TextStyle(color: Colors.white)),
                  ),
                ],
              )
            : AppBar(title: const Text('المدفوعات')),
        body: Column(
          children: [
            SearchBox(hint: 'الزبون، الهاتف، المكان أو رقم العملية', onChanged: (v) => setState(() => _q = v)),
            FilterBar(groups: [
              FilterGroup(
                options: const ['PENDING', 'PAID', 'FAILED', 'REFUNDED', 'all'],
                selected: _status,
                labelOf: (v) => v == 'all' ? 'كل الحالات' : paymentStatusAr(v),
                onSelected: (v) => setState(() {
                  _status = v;
                  _selected.clear();
                }),
              ),
            ]),
            FilterBar(groups: [
              FilterGroup(
                options: const ['all', 'MANUAL', 'ZAIN_CASH', 'QI_CARD'],
                selected: _method,
                labelOf: (v) => v == 'all' ? 'كل الطرق' : methodLabel(v),
                onSelected: (v) => setState(() => _method = v),
              ),
              FilterGroup(
                options: const ['proof'],
                selected: _proofOnly ? 'proof' : '',
                labelOf: (_) => 'مع إثبات',
                onSelected: (_) => setState(() => _proofOnly = !_proofOnly),
              ),
            ]),
            Expanded(
              child: PagedList(
                key: ValueKey('$_q|$_status|$_method|$_proofOnly'),
                controller: _list,
                fetch: _fetch,
                onLoaded: (r) => setState(() {
                  _total = r.total;
                  _pendingProof = asInt(r.raw['pendingProof']);
                }),
                header: _header(),
                emptyTitle: _status == 'PENDING' ? 'لا مدفوعات بانتظار التحقق' : 'لا مدفوعات',
                emptySubtitle: 'غيّر الفلاتر لعرض المزيد',
                itemBuilder: (context, p, _) => _PaymentCard(
                  payment: p,
                  selected: _selected.contains('${p['id']}'),
                  onTap: () => _open(p),
                  onLongPress: () => _toggle(p),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _selecting
            ? Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: placeLine))),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: placeDanger),
                        onPressed: () => _bulk('FAILED'),
                        child: const Text('رفض المحدد'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: placeSuccess),
                        onPressed: () => _bulk('PAID'),
                        child: Text('اعتماد ${_selected.length}'),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        if (_pendingProof > 0 && !(_status == 'PENDING' && _proofOnly))
          NoticeBanner(
            title: '$_pendingProof إثبات دفع بانتظار المراجعة',
            text: 'اضغط لعرضها',
            color: placeShiftMorning,
            icon: Icons.receipt_long_outlined,
            onTap: () => setState(() {
              _status = 'PENDING';
              _proofOnly = true;
            }),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Row(
            children: [
              Text(_total == null ? '' : '$_total دفعة',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2)),
              const Spacer(),
              if (_canVerify && _status == 'PENDING' && !_selecting)
                const Text('اضغط مطولاً للتحديد الجماعي',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk2)),
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
      highlight: needsReview ? placeShiftMorning.withValues(alpha: 0.45) : null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          if (selected)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 10),
              child: Icon(Icons.check_circle_rounded, color: placeBrass, size: 26),
            )
          else
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsetsDirectional.only(end: 10),
              decoration: BoxDecoration(color: paymentStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(methodIcon(p['method']?.toString()), color: paymentStatusColor(status), size: 22),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nonEmpty(asMap(booking['property'])['name'], 'دفعة'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w900, color: placeInk)),
                Text(
                  '${nonEmpty(user['name'] ?? booking['guestName'], 'زبون')} · ${methodLabel(p['method']?.toString())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusPill(label: paymentStatusAr(status), color: paymentStatusColor(status)),
                    if (hasProof) StatusPill(label: 'إثبات', color: placeShiftEvening, icon: Icons.image_outlined),
                    StatusPill(label: relativeAr(p['createdAt']), color: placeInk2),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatIqd(p['amount']),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: placeInk)),
        ],
      ),
    );
  }
}
