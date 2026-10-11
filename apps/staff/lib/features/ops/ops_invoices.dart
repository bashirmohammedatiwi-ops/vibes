import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/kit.dart';
import '../../widgets/ui.dart';
import 'ops_booking_detail.dart';

/// الفواتير — تصفية حسب الحالة، والضغط يفتح الحجز.
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

  static String _statusAr(String? raw) => switch (raw) {
    'ALL' => 'الكل',
    'ISSUED' => 'صادرة',
    'PAID' => 'مدفوعة',
    'VOID' => 'ملغاة',
    'REFUNDED' => 'مستردة',
    _ => raw ?? '—',
  };

  static Color _statusColor(String? raw) => switch (raw) {
    'PAID' => placeSuccess,
    'ISSUED' => placeInfo,
    'VOID' => placeInk3,
    'REFUNDED' => placeWarning,
    _ => placeInk2,
  };

  @override
  Widget build(BuildContext context) {
    return StaffPage(
      title: 'الفواتير',
      subtitle: _loading ? 'جارٍ التحميل…' : '${_rows.length} فاتورة',
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: FilterChipsRow(
            options: const ['ALL', 'ISSUED', 'PAID', 'VOID', 'REFUNDED'],
            selected: _status,
            labelBuilder: _statusAr,
            onSelected: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
        if (_loading)
          const SkeletonSliver(count: 6, height: 92)
        else if (_rows.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyView(icon: Icons.receipt_long_rounded, title: 'لا فواتير', subtitle: 'لا توجد فواتير بهذه الحالة.'),
          )
        else
          SliverList.separated(
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = _rows[i] as Map;
              final booking = row['booking'] as Map?;
              final bookingId = booking?['id']?.toString();
              final status = row['status']?.toString();
              final customer = '${booking?['user']?['name'] ?? booking?['guestName'] ?? ''}';
              return Pad(
                bottom: 0,
                child: StaffCard(
                  onTap: bookingId == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: bookingId))),
                  child: Row(
                    children: [
                      const IconBox(icon: Icons.receipt_long_rounded, color: placeBrass, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking?['property']?['name']?.toString() ?? 'حجز',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w900, color: placeInk),
                            ),
                            Text(
                              row['number']?.toString() ?? '',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk3),
                            ),
                            if (customer.trim().isNotEmpty)
                              Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: placeInk2),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusChip(_statusAr(status), color: _statusColor(status), dense: true),
                          const SizedBox(height: 6),
                          Text(
                            formatIqd(row['total']),
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w900, color: placeInk),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
