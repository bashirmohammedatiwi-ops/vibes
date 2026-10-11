import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/form_kit.dart' show showToast, confirmDialog;
import '../widgets/kit.dart';
import 'admin/bookings/booking_kit.dart';
import 'ops/ops_booking_detail.dart';

/// قائمة الحجوزات المبسّطة (واجهة الموظف `/api/staff/bookings`): تأكيد، اعتماد دفع،
/// إلغاء، ومحادثة — حسب الصلاحيات `bookings.confirm` / `payments.verify` /
/// `bookings.cancel` / `inbox.read`.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.embedded = false});

  /// عند الفتح من تبويب العمليات — شريط رجوع.
  final bool embedded;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const _statuses = ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED', 'COMPLETED', 'CANCELLED'];

  List<dynamic> _rows = [];
  String _status = 'PENDING';
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  Future<void> _load() async {
    setState(() {
      _loading = _rows.isEmpty;
      _error = null;
    });
    try {
      _rows = await Api.list('/api/staff/bookings?status=$_status');
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((row) {
      final map = row as Map;
      final user = map['user'] as Map?;
      final prop = map['property']?['name']?.toString().toLowerCase() ?? '';
      final name = user?['name']?.toString().toLowerCase() ?? '';
      final phone = user?['phone']?.toString() ?? '';
      return prop.contains(q) || name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return StaffPage(
      title: 'الحجوزات',
      subtitle: 'تأكيد، دفع، وتفاصيل كاملة',
      showBack: widget.embedded ? null : false,
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: Pad(
            top: 4,
            bottom: 6,
            child: BookingSearchField(
              controller: _search,
              hint: 'بحث باسم المكان أو الزبون',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SegmentFilter<String>(
            options: _statuses,
            value: _status,
            labelOf: statusLabel,
            colorOf: statusColor,
            onChanged: (v) {
              setState(() {
                _status = v;
                _rows = [];
              });
              _load();
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ...asyncSlivers(
          loading: _loading,
          error: _error,
          isEmpty: rows.isEmpty,
          onRetry: _load,
          skeletonHeight: 150,
          emptyIcon: statusIcon(_status),
          emptyTitle: 'لا حجوزات في هذا الفلتر',
          slivers: [
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => _BookingCard(row: rows[index] as Map, onChanged: _load),
            ),
          ],
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.row, required this.onChanged});

  final Map row;
  final VoidCallback onChanged;

  Future<void> _openDetail(BuildContext context) async {
    final id = row['id']?.toString();
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: id)),
    );
    onChanged();
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الحجز',
      message: 'تأكيد حجز ${row['property']?['name'] ?? ''}؟',
      confirmLabel: 'تأكيد',
    );
    if (!ok) return;
    try {
      await Api.send('/api/staff/bookings/${row['id']}/confirm', method: 'POST');
      HapticFeedback.mediumImpact();
      onChanged();
      if (context.mounted) showToast(context, 'تم التأكيد');
    } catch (e) {
      if (context.mounted) showToast(context, e is ApiException ? e.message : '$e', error: true);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await showTextSheet(
      context,
      title: 'إلغاء الحجز',
      label: 'سبب الإلغاء',
      hint: 'اختياري — يُرسل «إلغاء من المكتب» إن تُرك فارغاً',
      confirmLabel: 'إلغاء الحجز',
      danger: true,
    );
    if (reason == null) return;
    try {
      await Api.send('/api/staff/bookings/${row['id']}/cancel', method: 'POST', body: {'reason': reason.isEmpty ? 'إلغاء من المكتب' : reason});
      onChanged();
      if (context.mounted) showToast(context, 'تم إلغاء الحجز');
    } catch (e) {
      if (context.mounted) showToast(context, e is ApiException ? e.message : '$e', error: true);
    }
  }

  Future<void> _verifyPayment(BuildContext context) async {
    final payment = row['payment'] as Map?;
    final id = payment?['id']?.toString();
    if (id == null) return;
    final ok = await confirmDialog(context, title: 'اعتماد الدفع', message: 'تأكيد استلام الدفع واعتماده؟', confirmLabel: 'اعتماد');
    if (!ok) return;
    try {
      await Api.send('/api/staff/payments/$id/verify', method: 'POST');
      onChanged();
      if (context.mounted) showToast(context, 'تم اعتماد الدفع');
    } catch (e) {
      if (context.mounted) showToast(context, e is ApiException ? e.message : '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Map<String, dynamic>.from(row);
    final payment = row['payment'] as Map?;
    final payStatus = payment?['status']?.toString();
    final proofUrl = payment?['proofUrl']?.toString();
    final status = row['status']?.toString();
    final actions = <Widget>[
      if (proofUrl != null && proofUrl.isNotEmpty)
        _SmallAction(icon: Icons.receipt_long_rounded, label: 'الإثبات', onTap: () => showImageViewer(context, mediaUrl(proofUrl))),
      if (Session.can('bookings.cancel') && status != 'CANCELLED' && status != 'COMPLETED')
        _SmallAction(icon: Icons.block_rounded, label: 'إلغاء', color: placeDanger, onTap: () => _cancel(context)),
      if (Session.can('payments.verify') && payStatus == 'PENDING')
        _SmallAction(icon: Icons.price_check_rounded, label: 'اعتماد الدفع', color: placeSuccess, onTap: () => _verifyPayment(context)),
      if (Session.can('bookings.confirm') && status == 'PENDING')
        _SmallAction(icon: Icons.verified_rounded, label: 'تأكيد', color: placeInk, filled: true, onTap: () => _confirm(context)),
    ];
    return Column(
      children: [
        BookingRowCard(
          row: r,
          onTap: () => _openDetail(context),
          padding: EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, actions.isEmpty ? 10 : 6),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 14),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.onTap, this.color = placeInk2, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(StaffRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(StaffRadius.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: filled ? Colors.white : color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
