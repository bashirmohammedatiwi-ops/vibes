import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'ops_booking_detail.dart';

class OpsInvoicesScreen extends StatefulWidget {
  const OpsInvoicesScreen({super.key});

  @override
  State<OpsInvoicesScreen> createState() => _OpsInvoicesScreenState();
}

class _OpsInvoicesScreenState extends State<OpsInvoicesScreen> {
  List<dynamic> _rows = [];
  String _status = 'ALL';
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _status == 'ALL' ? '' : '?status=$_status';
      _rows = await Api.list('/api/staff/invoices$q');
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

  String _statusAr(String? raw) => switch (raw) {
        'ISSUED' => 'صادرة',
        'PAID' => 'مدفوعة',
        'VOID' => 'ملغاة',
        'REFUNDED' => 'مستردة',
        _ => raw ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير')),
      body: Column(
        children: [
          FilterChipsRow(
            options: const ['ALL', 'ISSUED', 'PAID', 'VOID', 'REFUNDED'],
            selected: _status,
            labelBuilder: (s) => switch (s) {
              'ALL' => 'الكل',
              'ISSUED' => 'صادرة',
              'PAID' => 'مدفوعة',
              'VOID' => 'ملغاة',
              'REFUNDED' => 'مستردة',
              _ => s,
            },
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
                  : _rows.isEmpty
                      ? ListView(children: const [EmptyState(title: 'لا فواتير')])
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final row = _rows[i] as Map;
                            final booking = row['booking'] as Map?;
                            final bookingId = booking?['id']?.toString();
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: InkWell(
                                onTap: bookingId == null
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => OpsBookingDetailScreen(bookingId: bookingId),
                                          ),
                                        ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              row['number']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _statusAr(row['status']?.toString()),
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: placeBrass),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        booking?['property']?['name']?.toString() ?? 'حجز',
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                      Text(
                                        '${booking?['user']?['name'] ?? booking?['guestName'] ?? ''} · ${formatIqd(row['total'])}',
                                        style: const TextStyle(color: placeInk2),
                                      ),
                                    ],
                                  ),
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
