import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../ops/ops_booking_detail.dart';
import 'people_common.dart';

/// فتح نزاع على حجز (سبب + ملاحظة) — `disputes.review`. يُرجع true عند النجاح.
Future<bool> openDisputeFor(BuildContext context, Map<String, dynamic> booking) async {
  final res = await showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
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
    final fab = _canReview && canList
        ? FloatingActionButton.extended(
            backgroundColor: placeInk,
            foregroundColor: Colors.white,
            onPressed: _newDispute,
            icon: const Icon(Icons.gavel_rounded),
            label: const Text('فتح نزاع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          )
        : null;
    if (!canList) {
      return const StaffPage(
        title: 'النزاعات',
        slivers: [
          SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              title: 'لا يمكن عرض النزاعات',
              subtitle: 'تحتاج صلاحية «عرض الحجوزات» لعرض النزاعات',
            ),
          ),
        ],
      );
    }
    return PagedStaffPage(
      title: 'النزاعات',
      subtitle: _total == null || _total == 0 ? null : '$_total نزاع مفتوح',
      resetKey: _q,
      controller: _list,
      fetch: _fetch,
      floatingActionButton: fab,
      onLoaded: (r) => setState(() => _total = r.total),
      search: SearchBox(
        hint: 'الزبون، الهاتف أو المكان',
        padding: SearchBox.barPadding,
        onChanged: (v) => setState(() => _q = v),
      ),
      listHeader: _total == null || _total == 0
          ? null
          : const NoticeBanner(
              text: 'راجع ملاحظات الحجز وإثبات الدفع قبل اتخاذ القرار.',
              color: placeDanger,
              icon: Icons.gavel_rounded,
            ),
      emptyIcon: Icons.verified_outlined,
      emptyTitle: 'لا نزاعات مفتوحة',
      emptySubtitle: 'كل الحجوزات بحالة طبيعية',
      skeletonHeight: 140,
      itemBuilder: (context, b, _) => _DisputeCard(
        booking: b,
        canResolve: _canReview,
        onResolve: () => _resolve(b),
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
          ListRow(
            leading: const IconBox(icon: Icons.gavel_rounded, color: placeDanger, size: 44),
            title: nonEmpty(property['name'], 'حجز'),
            subtitle: '${nonEmpty(user['name'] ?? b['guestName'], 'زبون')} · ${fmtDay(b['startDate'])}',
            chips: [
              const StatusChip('نزاع', color: placeDanger, dense: true),
              if (payment['status'] != null)
                StatusChip(
                  'الدفع: ${paymentStatusAr(payment['status']?.toString())}',
                  color: paymentStatusColor(payment['status']?.toString()),
                  dense: true,
                ),
            ],
            trailing: MetaText(formatIqd(b['totalPrice']), strong: true),
          ),
          if (reason.isNotEmpty || note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: placeDanger.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(StaffRadius.md)),
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
          const SizedBox(height: 12),
          Row(
            children: [
              PhoneButtons(phone: phone, compact: true),
              const Spacer(),
              if (canResolve)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
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
    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle('حل النزاع', subtitle: nonEmpty(asMap(widget.booking['property'])['name'], '')),
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
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
    return SheetBody(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle('فتح نزاع', subtitle: nonEmpty(asMap(widget.booking['property'])['name'], '')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in _quick)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: placePaper,
                    side: const BorderSide(color: placeLine),
                    shape: const StadiumBorder(),
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
              style: FilledButton.styleFrom(backgroundColor: placeDanger, minimumSize: const Size.fromHeight(50)),
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
    return PagedStaffPage(
      title: 'فتح نزاع على حجز',
      subtitle: 'اختر الحجز المتنازع عليه',
      resetKey: '$_q|$_status',
      fetch: (page) => fetchPage('/api/admin/bookings', {'q': _q, 'status': _status}, page: page),
      search: SearchBox(
        hint: 'ابحث بالزبون، الهاتف أو المكان',
        padding: SearchBox.barPadding,
        onChanged: (v) => setState(() => _q = v),
      ),
      filters: FilterBar(groups: [
        FilterGroup(
          options: const ['CONFIRMED', 'COMPLETED', 'AWAITING_PAYMENT', 'PENDING', 'CANCELLED'],
          selected: _status,
          labelOf: bookingStatusLabel,
          onSelected: (v) => setState(() => _status = v),
        ),
      ]),
      emptyIcon: Icons.event_busy_rounded,
      emptyTitle: 'لا حجوزات مطابقة',
      emptySubtitle: 'جرّب بحثاً أو حالة أخرى',
      itemBuilder: (context, b, _) {
        final user = asMap(b['user']);
        final status = b['status']?.toString();
        final phone = user['phone']?.toString() ?? b['guestPhone']?.toString();
        return ListCard(
          onTap: () async {
            final ok = await openDisputeFor(context, b);
            if (ok && context.mounted) Navigator.of(context).pop(true);
          },
          child: ListRow(
            leading: IconBox(icon: Icons.event_note_rounded, color: bookingStatusColor(status), size: 44),
            title: nonEmpty(asMap(b['property'])['name'], 'حجز'),
            subtitle: '${nonEmpty(user['name'] ?? b['guestName'], 'زبون')} · ${fmtDay(b['startDate'])} · ${formatIqd(b['totalPrice'])}',
            subtitleWidget: (phone ?? '').isEmpty ? null : PhoneText(phone),
            chips: [StatusChip(bookingStatusLabel(status), color: bookingStatusColor(status), dense: true)],
            trailing: const Icon(Icons.gavel_rounded, color: placeDanger, size: 20),
          ),
        );
      },
    );
  }
}
