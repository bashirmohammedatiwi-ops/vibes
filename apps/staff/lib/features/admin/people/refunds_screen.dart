import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../ops/ops_booking_detail.dart';
import 'people_common.dart';

/// طلبات الاسترداد والإلغاء من الزبائن مع سياق الحجز والدفع —
/// العرض `refunds.review`، قرار الإلغاء `cancellations.review`.
class AdminRefundsScreen extends StatefulWidget {
  const AdminRefundsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<AdminRefundsScreen> createState() => _AdminRefundsScreenState();
}

class _AdminRefundsScreenState extends State<AdminRefundsScreen> {
  final _list = PagedListController();
  late String _type = widget.initialTab == 1 ? 'cancellations' : 'refunds';
  String _status = 'PENDING';
  String _q = '';

  Future<PageResult> _fetchRefunds(int page) =>
      fetchPage('/api/admin/refunds', {'status': _status == 'all' ? null : _status, 'q': _q}, page: page);

  Future<PageResult> _fetchCancellations(int page) async {
    final data = await Api.map(buildPath('/api/admin/refunds', {'status': _status == 'all' ? null : _status, 'pageSize': 1}));
    var items = asMapList(data['cancellations']);
    final q = _q.toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((c) {
        final user = asMap(c['user']);
        final prop = asMap(asMap(c['booking'])['property']);
        return '${user['name'] ?? ''} ${user['phone'] ?? ''} ${prop['name'] ?? ''} ${c['reason'] ?? ''}'.toLowerCase().contains(q);
      }).toList();
    }
    return PageResult(items: items, total: items.length, totalPages: 1, raw: data);
  }

  Future<void> _review({required bool refund, required Map<String, dynamic> row, required bool approve}) async {
    final booking = asMap(row['booking']);
    final amount = formatIqd(refund ? row['amount'] : row['expectedRefund']);
    final what = refund ? 'الاسترداد' : 'الإلغاء';
    String? note;
    if (approve) {
      note = await showInputSheet(
        context,
        title: 'الموافقة على $what',
        subtitle: refund
            ? 'سيُلغى الحجز، وإن كانت الدفعة مدفوعة ستُعلَّم «مستردة» ($amount).'
            : 'سيُلغى الحجز ويتحرّر موعده. الاسترداد المتوقع: $amount.',
        label: 'ملاحظة (اختياري)',
        confirmLabel: 'متابعة',
        maxLines: 2,
      );
      if (note == null || !mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'تأكيد الموافقة',
        message: 'الموافقة على طلب $what لحجز «${nonEmpty(asMap(booking['property'])['name'], '')}»؟ لا يمكن التراجع.',
        confirmLabel: 'موافقة',
        danger: true,
      );
      if (!ok || !mounted) return;
    } else {
      note = await showInputSheet(
        context,
        title: 'رفض طلب $what',
        subtitle: 'سيصل السبب للزبون.',
        label: 'سبب الرفض',
        confirmLabel: 'رفض الطلب',
        required: true,
        maxLines: 3,
        danger: true,
      );
      if (note == null || !mounted) return;
    }
    final path = refund ? '/api/admin/refunds/${row['id']}' : '/api/admin/cancellations/${row['id']}';
    final done = await runAction(context, () async {
      await withBusy(context, () => Api.send(path, method: 'PATCH', body: {'approve': approve, if (note!.isNotEmpty) 'adminNote': note}));
    }, success: approve ? 'تمت الموافقة' : 'تم رفض الطلب');
    if (done) {
      _list.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final refunds = _type == 'refunds';
    return PagedStaffPage(
      title: 'الاسترداد والإلغاء',
      subtitle: refunds ? 'طلبات استرداد الزبائن مع سياق الدفع' : 'طلبات إلغاء الحجوزات',
      resetKey: '$_type|$_status|$_q',
      controller: _list,
      fetch: refunds ? _fetchRefunds : _fetchCancellations,
      search: SearchBox(
        hint: 'الزبون، الهاتف أو المكان',
        padding: SearchBox.barPadding,
        onChanged: (v) => setState(() => _q = v),
      ),
      filters: FilterBar(groups: [
        FilterGroup(
          options: const ['refunds', 'cancellations'],
          selected: _type,
          labelOf: (v) => v == 'refunds' ? 'طلبات الاسترداد' : 'طلبات الإلغاء',
          onSelected: (v) => setState(() => _type = v),
        ),
        FilterGroup(
          options: const ['PENDING', 'APPROVED', 'REJECTED', 'all'],
          selected: _status,
          labelOf: (v) => v == 'all' ? 'الكل' : requestStatusLabel(v),
          onSelected: (v) => setState(() => _status = v),
        ),
      ]),
      emptyIcon: refunds ? Icons.currency_exchange_rounded : Icons.event_busy_rounded,
      emptyTitle: _status == 'PENDING' ? (refunds ? 'لا طلبات استرداد معلّقة' : 'لا طلبات إلغاء معلّقة') : 'لا طلبات',
      skeletonHeight: 150,
      itemBuilder: (context, r, _) => _RequestCard(
        row: r,
        refund: refunds,
        canReview: Session.can(refunds ? 'refunds.review' : 'cancellations.review'),
        onApprove: () => _review(refund: refunds, row: r, approve: true),
        onReject: () => _review(refund: refunds, row: r, approve: false),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.row,
    required this.refund,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });
  final Map<String, dynamic> row;
  final bool refund;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final user = asMap(row['user']);
    final booking = asMap(row['booking']);
    final payment = asMap(booking['payment']);
    final status = row['status']?.toString();
    final reason = row['reason']?.toString() ?? '';
    final adminNote = row['adminNote']?.toString() ?? '';
    final name = nonEmpty(user['name'], 'زبون');
    final phone = user['phone']?.toString();
    final pending = status == 'PENDING';
    return ListCard(
      highlight: pending ? placeGold.withValues(alpha: 0.45) : null,
      onTap: booking['id'] != null && Session.can('bookings.read')
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: '${booking['id']}')))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListRow(
            leading: Avatar(name, size: 44, color: refund ? placeWarning : placeDanger),
            title: name,
            subtitleWidget: (phone ?? '').isEmpty ? null : PhoneText(phone),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(requestStatusLabel(status), color: requestStatusColor(status), dense: true),
                const SizedBox(height: 4),
                MetaText(relativeAr(row['createdAt'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // المبلغ
          Row(
            children: [
              Text(
                refund ? 'مبلغ الاسترداد المطلوب' : 'الاسترداد المتوقع',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
              ),
              const Spacer(),
              Text(
                formatIqd(refund ? row['amount'] : row['expectedRefund']),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // سياق الحجز والدفع
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(StaffRadius.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 16, color: placeBrass),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(nonEmpty(asMap(booking['property'])['name'], 'حجز'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                    ),
                  ],
                ),
                Text(
                  '${fmtDay(booking['startDate'])} · ${formatIqd(booking['totalPrice'])}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusChip(
                      'الحجز: ${bookingStatusLabel(booking['status']?.toString())}',
                      color: bookingStatusColor(booking['status']?.toString()),
                      dense: true,
                    ),
                    if (payment['status'] != null)
                      StatusChip(
                        'الدفع: ${paymentStatusAr(payment['status']?.toString())} ${formatIqd(payment['amount'])}',
                        color: paymentStatusColor(payment['status']?.toString()),
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('سبب الزبون: $reason', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: placeInk, height: 1.5)),
          ],
          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('ملاحظة الإدارة: $adminNote', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, height: 1.5)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              PhoneButtons(phone: phone, compact: true),
              const Spacer(),
              if (pending && canReview) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: placeDanger, minimumSize: const Size(0, 44)),
                  onPressed: onReject,
                  child: const Text('رفض'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: placeSuccess, minimumSize: const Size(0, 44)),
                  onPressed: onApprove,
                  child: const Text('موافقة'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
