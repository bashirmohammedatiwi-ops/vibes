import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/ui.dart';
import 'ops_booking_detail.dart';

class OpsPaymentsScreen extends StatefulWidget {
  const OpsPaymentsScreen({super.key});

  @override
  State<OpsPaymentsScreen> createState() => _OpsPaymentsScreenState();
}

class _OpsPaymentsScreenState extends State<OpsPaymentsScreen> {
  List<dynamic> _rows = [];
  String _status = 'PENDING';
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rows = await Api.list('/api/staff/payments?status=$_status');
    } catch (_) {
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _verify(String id) async {
    try {
      await Api.send('/api/staff/payments/$id/verify', method: 'POST');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _reject(String id) async {
    final reason = await promptText(context, title: 'سبب الرفض');
    if (reason == null) return;
    try {
      await Api.send('/api/staff/payments/$id/reject', method: 'POST', body: {'reason': reason});
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المدفوعات')),
      body: Column(
        children: [
          FilterChipsRow(
            options: const ['PENDING', 'PAID', 'FAILED', 'REFUNDED'],
            selected: _status,
            labelBuilder: paymentStatusAr,
            onSelected: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: CircularProgressIndicator(color: placeGold)),
                      ],
                    )
                  : _rows.isEmpty
                  ? ListView(children: const [EmptyState(title: 'لا مدفوعات')])
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final row = _rows[i] as Map;
                        final booking = row['booking'] as Map?;
                        final id = row['id']?.toString() ?? '';
                        final bookingId = booking?['id']?.toString();
                        return Card(
                          margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(StaffRadius.lg),
                            side: const BorderSide(color: placeLine),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking?['property']?['name']?.toString() ?? 'دفعة',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text(
                                  '${booking?['user']?['name'] ?? booking?['guestName'] ?? ''} · ${formatIqd(row['amount'])}',
                                  style: const TextStyle(color: placeInk2),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (Session.can('payments.verify') && row['status'] == 'PENDING') ...[
                                      FilledButton(onPressed: () => _verify(id), child: const Text('اعتماد')),
                                      OutlinedButton(onPressed: () => _reject(id), child: const Text('رفض')),
                                    ],
                                    if (bookingId != null)
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          context,
                                        ).push(MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: bookingId))),
                                        child: const Text('الحجز'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
