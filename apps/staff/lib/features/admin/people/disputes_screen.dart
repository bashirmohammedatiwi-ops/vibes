import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../ops/ops_booking_detail.dart';
import 'people_common.dart';

/// فتح نزاع على حجز (سبب + ملاحظة) — `disputes.review`. يُرجع true عند النجاح.
Future<bool> openDisputeFor(BuildContext context, Map<String, dynamic> booking) async {
  final res = await showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _OpenDisputeSheet(booking: booking),
  );
  if (res == null || !context.mounted) return false;
  final ok = await confirmDialog(
    context,
    title: 'فتح نزاع؟',
    message: 'سيتحوّل الحجز إلى حالة «نزاع» ويُعلَّق حتى يُحل، وتُسجَّل ملاحظة في الحجز.',
    confirmLabel: 'فتح النزاع',
    danger: true,
  );
  if (!ok || !context.mounted) return false;
  return runAction(context, () async {
    await withBusy(
      context,
      () => Api.map('/api/admin/bookings/${booking['id']}/dispute', method: 'POST', body: {
        'reason': res['reason'],
        if ((res['note'] ?? '').isNotEmpty) 'note': res['note'],
      }),
    );
  }, success: 'تم فتح النزاع');
}

/// النزاعات المفتوحة (حجوزات بحالة DISPUTED) مع الحل وفتح نزاع جديد —
/// `disputes.review` (+ `bookings.read` لعرض القائمة).
class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  final _list = PagedListController();
  String _q = '';
  int? _total;

  bool get _canReview => Session.can('disputes.review');

  Future<PageResult> _fetch(int page) => fetchPage('/api/admin/bookings', {'status': 'DISPUTED', 'q': _q}, page: page);

  Future<void> _resolve(Map<String, dynamic> booking) async {
    final res = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _ResolveSheet(booking: booking),
    );
    if (res == null || !mounted) return;
    final status = res['status']!;
    final ok = await confirmDialog(
      context,
      title: 'حل النزاع؟',
      message: switch (status) {
        'CONFIRMED' => 'سيُثبَّت الحجز كمؤكد.',
        'CANCELLED' => 'سيُلغى الحجز ويتحرّر موعده. إن كان مدفوعاً راجع الاسترداد من شاشة المدفوعات.',
        _ => 'سيُعلَّم الحجز مكتملاً.',
      },
      confirmLabel: 'تأكيد القرار',
      danger: status == 'CANCELLED',
    );
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await withBusy(
        context,
        () => Api.map('/api/admin/bookings/${booking['id']}/dispute/resolve', method: 'POST', body: {
          'status': status,
          if ((res['note'] ?? '').isNotEmpty) 'note': res['note'],
        }),
      );
    }, success: 'تم حل النزاع — ${bookingStatusLabel(status)}');
    if (done) _list.reload();
  }

  Future<void> _newDispute() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const OpenDisputeScreen()));
    if (ok == true) _list.reload();
  }

  @override
  Widget build(BuildContext context) {
    final canList = Session.can('bookings.read');
    return Scaffold(
      appBar: AppBar(title: const Text('النزاعات')),
      floatingActionButton: _canReview && canList
          ? FloatingActionButton.extended(
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              onPressed: _newDispute,
              icon: const Icon(Icons.gavel_rounded),
              label: const Text('فتح نزاع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      body: !canList
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('تحتاج صلاحية «عرض الحجوزات» لعرض النزاعات',
                    textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
              ),
            )
          : Column(
              children: [
                SearchBox(hint: 'الزبون، الهاتف أو المكان', onChanged: (v) => setState(() => _q = v)),
                Expanded(
                  child: PagedList(
                    key: ValueKey(_q),
                    controller: _list,
                    fetch: _fetch,
                    bottomPadding: 96,
                    onLoaded: (r) => setState(() => _total = r.total),
                    header: _total == null || _total == 0
                        ? null
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Text('$_total نزاع مفتوح — راجع ملاحظات الحجز وإثبات الدفع قبل القرار',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2)),
                          ),
                    emptyTitle: 'لا نزاعات مفتوحة',
                    emptySubtitle: 'كل الحجوزات بحالة طبيعية',
                    itemBuilder: (context, b, _) => _DisputeCard(
                      booking: b,
                      canResolve: _canReview,
                      onResolve: () => _resolve(b),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.booking, required this.canResolve, required this.onResolve});
  final Map<String, dynamic> booking;
  final bool canResolve;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final user = asMap(b['user']);
    final property = asMap(b['property']);
    final payment = asMap(b['payment']);
    final phone = user['phone']?.toString() ?? b['guestPhone']?.toString();
    final reason = b['disputeReason']?.toString() ?? '';
    final note = b['disputeNote']?.toString() ?? '';
    return ListCard(
      highlight: placeDanger.withValues(alpha: 0.3),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: '${b['id']}'))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nonEmpty(property['name'], 'حجز'),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                    Text(
                      '${nonEmpty(user['name'] ?? b['guestName'], 'زبون')} · ${fmtDay(b['startDate'])} · ${formatIqd(b['totalPrice'])}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const StatusPill(label: 'نزاع', color: placeDanger, icon: Icons.gavel_rounded),
            ],
          ),
          if (reason.isNotEmpty || note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: placeDanger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reason.isNotEmpty)
                    Text('السبب: $reason', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk)),
                  if (note.isNotEmpty)
                    Text(note, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, height: 1.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (payment['status'] != null)
                StatusPill(
                  label: 'الدفع: ${paymentStatusAr(payment['status']?.toString())}',
                  color: paymentStatusColor(payment['status']?.toString()),
                ),
              const SizedBox(width: 6),
              PhoneButtons(phone: phone, compact: true),
              const Spacer(),
              if (canResolve)
                FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  onPressed: onResolve,
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('حل النزاع'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolveSheet extends StatefulWidget {
  const _ResolveSheet({required this.booking});
  final Map<String, dynamic> booking;

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  String? _status;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const Text('حل النزاع', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
          Text(nonEmpty(asMap(widget.booking['property'])['name'], ''),
              style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text('القرار', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2)),
          const SizedBox(height: 8),
          ChoicePills<String>(
            options: const ['CONFIRMED', 'CANCELLED', 'COMPLETED'],
            value: _status,
            labelOf: (v) => switch (v) { 'CONFIRMED' => 'تأكيد الحجز', 'CANCELLED' => 'إلغاء الحجز', _ => 'تعليمه مكتملاً' },
            iconOf: (v) => switch (v) {
              'CONFIRMED' => Icons.check_circle_outline,
              'CANCELLED' => Icons.cancel_outlined,
              _ => Icons.flag_outlined,
            },
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 14),
          StaffField(controller: _note, label: 'ملاحظة القرار (اختياري)', maxLines: 3),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _status == null ? null : () => Navigator.pop(context, {'status': _status!, 'note': _note.text.trim()}),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }
}

class _OpenDisputeSheet extends StatefulWidget {
  const _OpenDisputeSheet({required this.booking});
  final Map<String, dynamic> booking;

  @override
  State<_OpenDisputeSheet> createState() => _OpenDisputeSheetState();
}

class _OpenDisputeSheetState extends State<_OpenDisputeSheet> {
  final _reason = TextEditingController();
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _quick = ['خلاف على المبلغ', 'المكان لا يطابق الوصف', 'مشكلة في الدفع', 'شكوى من المزود', 'شكوى من الزبون'];

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const Text('فتح نزاع', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
            Text(nonEmpty(asMap(widget.booking['property'])['name'], ''),
                style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in _quick)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: placePaper,
                    side: const BorderSide(color: placeLine),
                    onPressed: () => setState(() => _reason.text = q),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            StaffField(
              controller: _reason,
              label: 'سبب النزاع *',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'السبب مطلوب' : null,
            ),
            const SizedBox(height: 12),
            StaffField(controller: _note, label: 'تفاصيل (اختياري)', maxLines: 3),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: placeDanger),
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(context, {'reason': _reason.text.trim(), 'note': _note.text.trim()});
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// اختيار حجز لفتح نزاع عليه.
class OpenDisputeScreen extends StatefulWidget {
  const OpenDisputeScreen({super.key});

  @override
  State<OpenDisputeScreen> createState() => _OpenDisputeScreenState();
}

class _OpenDisputeScreenState extends State<OpenDisputeScreen> {
  String _q = '';
  String _status = 'CONFIRMED';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فتح نزاع على حجز')),
      body: Column(
        children: [
          SearchBox(hint: 'ابحث بالزبون، الهاتف أو المكان', onChanged: (v) => setState(() => _q = v)),
          FilterBar(groups: [
            FilterGroup(
              options: const ['CONFIRMED', 'COMPLETED', 'AWAITING_PAYMENT', 'PENDING', 'CANCELLED'],
              selected: _status,
              labelOf: bookingStatusLabel,
              onSelected: (v) => setState(() => _status = v),
            ),
          ]),
          Expanded(
            child: PagedList(
              key: ValueKey('$_q|$_status'),
              fetch: (page) => fetchPage('/api/admin/bookings', {'q': _q, 'status': _status}, page: page),
              emptyTitle: 'لا حجوزات مطابقة',
              emptySubtitle: 'جرّب بحثاً أو حالة أخرى',
              itemBuilder: (context, b, _) {
                final user = asMap(b['user']);
                final status = b['status']?.toString();
                return ListCard(
                  onTap: () async {
                    final ok = await openDisputeFor(context, b);
                    if (ok && context.mounted) Navigator.of(context).pop(true);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nonEmpty(asMap(b['property'])['name'], 'حجز'),
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                            Text(
                              '${nonEmpty(user['name'] ?? b['guestName'], 'زبون')} · ${fmtDay(b['startDate'])} · ${formatIqd(b['totalPrice'])}',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                            ),
                            PhoneText(user['phone']?.toString() ?? b['guestPhone']?.toString()),
                          ],
                        ),
                      ),
                      StatusPill(label: bookingStatusLabel(status), color: bookingStatusColor(status)),
                      const SizedBox(width: 6),
                      const Icon(Icons.gavel_rounded, color: placeDanger, size: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
