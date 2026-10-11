import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/shift.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../chat_room.dart';

class OpsBookingDetailScreen extends StatefulWidget {
  const OpsBookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<OpsBookingDetailScreen> createState() => _OpsBookingDetailScreenState();
}

class _OpsBookingDetailScreenState extends State<OpsBookingDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      _data = await Api.map('/api/staff/bookings/${widget.bookingId}');
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    try {
      await Api.send('/api/staff/bookings/${widget.bookingId}/confirm', method: 'POST');
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التأكيد')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cancel() async {
    final reason = await promptText(context, title: 'سبب الإلغاء');
    if (reason == null) return;
    try {
      await Api.send(
        '/api/staff/bookings/${widget.bookingId}/cancel',
        method: 'POST',
        body: {'reason': reason.isEmpty ? 'إلغاء من المكتب' : reason},
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addNote() async {
    final note = await promptText(context, title: 'ملاحظة داخلية');
    if (note == null || note.trim().isEmpty) return;
    try {
      await Api.send(
        '/api/staff/bookings/${widget.bookingId}/notes',
        method: 'POST',
        body: {'body': note.trim()},
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _verifyPay() async {
    final id = _data?['payment']?['id']?.toString();
    if (id == null) return;
    try {
      await Api.send('/api/staff/payments/$id/verify', method: 'POST');
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final user = d?['user'] as Map?;
    final property = d?['property'] as Map?;
    final payment = d?['payment'] as Map?;
    final notes = (d?['bookingNotes'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الحجز'),
        actions: [
          if (Session.can('inbox.read') && user?['id'] != null)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      contactUserId: user!['id'].toString(),
                      contactName: user['name']?.toString() ?? 'زبون',
                      contactPhone: user['phone']?.toString(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(title: 'تعذّر التحميل', subtitle: _error)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Text(
                        property?['name']?.toString() ?? 'حجز',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${user?['name'] ?? d?['guestName'] ?? ''} · ${user?['phone'] ?? d?['guestPhone'] ?? ''}',
                        style: const TextStyle(color: placeInk2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(bookingStatusAr(d?['status']?.toString()))),
                          Chip(label: Text(formatIqd(d?['totalPrice']))),
                          if (d?['startDate'] != null)
                            Chip(
                              label: Text(
                                DateFormat('d MMM yyyy', 'ar').format(DateTime.parse(d!['startDate'] as String)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (payment != null) ...[
                        Card(
                          child: ListTile(
                            title: Text('الدفع · ${paymentStatusAr(payment['status']?.toString())}'),
                            subtitle: Text(formatIqd(payment['amount'])),
                            trailing: Session.can('payments.verify') && payment['status'] == 'PENDING'
                                ? FilledButton(onPressed: _verifyPay, child: const Text('اعتماد'))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (Session.can('bookings.confirm') && d?['status'] == 'PENDING')
                            Expanded(child: FilledButton(onPressed: _confirm, child: const Text('تأكيد'))),
                          if (Session.can('bookings.confirm') && d?['status'] == 'PENDING') const SizedBox(width: 8),
                          if (Session.can('bookings.cancel') &&
                              ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'].contains(d?['status']))
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancel,
                                child: const Text('إلغاء'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('ملاحظات داخلية', style: TextStyle(fontWeight: FontWeight.w900)),
                          const Spacer(),
                          if (Session.can('bookings.write'))
                            TextButton.icon(onPressed: _addNote, icon: const Icon(Icons.add, size: 18), label: const Text('إضافة')),
                        ],
                      ),
                      if (notes.isEmpty)
                        const Text('لا ملاحظات بعد', style: TextStyle(color: placeInk2))
                      else
                        ...notes.map((n) {
                          final map = n as Map;
                          return Card(
                            child: ListTile(
                              title: Text(map['content']?.toString() ?? ''),
                              subtitle: Text(
                                '${map['author']?['name'] ?? ''} · ${map['createdAt'] != null ? DateFormat('d/M HH:mm').format(DateTime.parse(map['createdAt'] as String).toLocal()) : ''}',
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
