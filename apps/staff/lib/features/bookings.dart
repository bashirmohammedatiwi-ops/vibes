import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/shift.dart';
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/ui.dart';
import 'chat_room.dart';
import 'ops/ops_booking_detail.dart';
import '../core/net_image.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.embedded = false});

  /// عند الفتح من تبويب العمليات — شريط رجوع.
  final bool embedded;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<dynamic> _rows = [];
  String _status = 'PENDING';
  bool _loading = true;
  String? _error;
  String _query = '';

  Future<void> _load() async {
    setState(() {
      _loading = true;
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

  List<dynamic> get _filtered {
    final q = _query.trim().toLowerCase();
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
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaisonHeader(
          title: 'الحجوزات',
          subtitle: 'تأكيد، دفع، وتفاصيل كاملة',
          trailing: widget.embedded
              ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'بحث باسم المكان أو الزبون', prefixIcon: Icon(Icons.search)),
          ),
        ),
        const SizedBox(height: 4),
        FilterChipsRow(
          options: const ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED', 'COMPLETED', 'CANCELLED'],
          selected: _status,
          labelBuilder: bookingStatusAr,
          onSelected: (v) {
            setState(() => _status = v);
            _load();
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
                : _error != null
                    ? ListView(
                        children: [
                          EmptyState(title: 'تعذّر التحميل', subtitle: _error),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                          ),
                        ],
                      )
                    : _filtered.isEmpty
                        ? ListView(children: const [EmptyState(title: 'لا حجوزات في هذا الفلتر')])
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final row = _filtered[index] as Map;
                              return _BookingCard(row: row, onChanged: _load);
                            },
                          ),
          ),
        ),
      ],
    );
    if (!widget.embedded) return body;
    return Scaffold(body: SafeArea(child: body));
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

  Future<void> _openChat(BuildContext context) async {
    final user = row['user'] as Map?;
    final userId = user?['id']?.toString();
    if (userId == null) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          contactUserId: userId,
          contactName: user?['name']?.toString() ?? user?['phone']?.toString() ?? 'زبون',
          contactPhone: user?['phone']?.toString(),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحجز'),
        content: Text('تأكيد حجز ${row['property']?['name'] ?? ''}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.send('/api/staff/bookings/${row['id']}/confirm', method: 'POST');
      onChanged();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التأكيد')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await promptText(context, title: 'سبب الإلغاء');
    if (reason == null) return;
    try {
      await Api.send('/api/staff/bookings/${row['id']}/cancel', method: 'POST', body: {'reason': reason.isEmpty ? 'إلغاء من المكتب' : reason});
      onChanged();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _verifyPayment(BuildContext context) async {
    final payment = row['payment'] as Map?;
    final id = payment?['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد الدفع'),
        content: const Text('تأكيد استلام الدفع واعتماده؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.send('/api/staff/payments/$id/verify', method: 'POST');
      onChanged();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد الدفع')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showProof(BuildContext context, String url) {
    final full = url.startsWith('http') ? url : '$apiBase$url';
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('إثبات الدفع'),
              automaticallyImplyLeading: false,
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
            InteractiveViewer(
              child: staffNetworkImage(
                full,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('تعذّر عرض الصورة'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = row['user'] as Map?;
    final payment = row['payment'] as Map?;
    final start = row['startDate'] != null ? DateFormat('d MMM', 'ar').format(DateTime.parse(row['startDate'] as String)) : '';
    final shift = row['shift']?.toString();
    final payStatus = payment?['status']?.toString();
    final proofUrl = payment?['proofUrl']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user != null) ContactAvatar(name: user['name']?.toString() ?? '', phone: user['phone']?.toString(), size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['property']?['name']?.toString() ?? 'حجز', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('${user?['name'] ?? ''} · ${user?['phone'] ?? ''}', style: const TextStyle(color: placeInk2)),
                      ],
                    ),
                  ),
                  ShiftBadge(shift: shift),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: placeInk2),
                  const SizedBox(width: 6),
                  Text(start, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(formatIqd(row['totalPrice']), style: const TextStyle(fontWeight: FontWeight.w800, color: placeBrass)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(bookingStatusAr(row['status']?.toString())),
                    backgroundColor: placePaper,
                    side: const BorderSide(color: placeLine),
                  ),
                  if (payment != null)
                    Chip(
                      label: Text(paymentStatusAr(payStatus)),
                      backgroundColor: paymentStatusColor(payStatus).withValues(alpha: 0.12),
                      labelStyle: TextStyle(color: paymentStatusColor(payStatus), fontWeight: FontWeight.w700),
                      side: BorderSide.none,
                    ),
                  if (proofUrl != null && proofUrl.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.image_outlined, size: 16),
                      label: const Text('إثبات'),
                      onPressed: () => _showProof(context, proofUrl),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (Session.can('inbox.read') && user?['id'] != null)
                    OutlinedButton.icon(onPressed: () => _openChat(context), icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('محادثة')),
                  if (Session.can('bookings.confirm') && row['status'] == 'PENDING')
                    FilledButton(onPressed: () => _confirm(context), child: const Text('تأكيد')),
                  if (Session.can('payments.verify') && payStatus == 'PENDING')
                    OutlinedButton(onPressed: () => _verifyPayment(context), child: const Text('اعتماد الدفع')),
                  if (Session.can('bookings.cancel') && row['status'] != 'CANCELLED' && row['status'] != 'COMPLETED')
                    TextButton(onPressed: () => _cancel(context), child: const Text('إلغاء', style: TextStyle(color: placeDanger))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) => _openDetail(context);
}
