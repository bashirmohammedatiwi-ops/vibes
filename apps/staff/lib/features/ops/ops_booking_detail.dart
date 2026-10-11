import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart' show showToast, confirmDialog;
import '../../widgets/kit.dart';
import '../admin/bookings/booking_kit.dart';

/// تفاصيل حجز (واجهة الموظف `/api/staff/bookings/:id`): تأكيد، إلغاء،
/// اعتماد الدفع، وملاحظات داخلية — حسب صلاحيات `bookings.confirm` /
/// `bookings.cancel` / `payments.verify` / `bookings.write`.
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      _data = await Api.map('/api/staff/bookings/${widget.bookingId}');
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<dynamic> Function() action, String? success) async {
    setState(() => _busy = true);
    try {
      await action();
      HapticFeedback.mediumImpact();
      await _load();
      if (mounted && success != null) showToast(context, success);
    } catch (e) {
      if (mounted) showToast(context, e is ApiException ? e.message : '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الحجز',
      message: 'تأكيد حجز ${_data?['property']?['name'] ?? ''}؟',
      confirmLabel: 'تأكيد',
    );
    if (!ok) return;
    await _run(() => Api.send('/api/staff/bookings/${widget.bookingId}/confirm', method: 'POST'), 'تم التأكيد');
  }

  Future<void> _cancel() async {
    final reason = await showTextSheet(
      context,
      title: 'إلغاء الحجز',
      label: 'سبب الإلغاء',
      hint: 'اختياري — يُرسل «إلغاء من المكتب» إن تُرك فارغاً',
      confirmLabel: 'إلغاء الحجز',
      danger: true,
    );
    if (reason == null) return;
    await _run(
      () => Api.send(
        '/api/staff/bookings/${widget.bookingId}/cancel',
        method: 'POST',
        body: {'reason': reason.isEmpty ? 'إلغاء من المكتب' : reason},
      ),
      'تم إلغاء الحجز',
    );
  }

  Future<void> _addNote() async {
    final note = await showTextSheet(context, title: 'ملاحظة داخلية', label: 'نص الملاحظة', hint: 'لا يراها الزبون', confirmLabel: 'إضافة');
    if (note == null || note.trim().isEmpty) return;
    await _run(
      () => Api.send('/api/staff/bookings/${widget.bookingId}/notes', method: 'POST', body: {'body': note.trim()}),
      'أُضيفت الملاحظة',
    );
  }

  Future<void> _verifyPay() async {
    final id = _data?['payment']?['id']?.toString();
    if (id == null) return;
    final ok = await confirmDialog(context, title: 'اعتماد الدفع', message: 'تأكيد استلام الدفع واعتماده؟', confirmLabel: 'اعتماد');
    if (!ok) return;
    await _run(() => Api.send('/api/staff/payments/$id/verify', method: 'POST'), 'تم اعتماد الدفع');
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final property = d?['property'] as Map?;
    final status = d?['status']?.toString();
    final canConfirm = Session.can('bookings.confirm') && status == 'PENDING';
    final canCancel = Session.can('bookings.cancel') && ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'].contains(status);

    final page = StaffPage(
      title: property?['name']?.toString() ?? 'تفاصيل الحجز',
      subtitle: d == null ? null : statusLabel(status),
      onRefresh: _load,
      actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
          ),
      ],
      slivers: _loading
          ? const [
              SliverToBoxAdapter(child: Pad(top: 4, child: SkeletonBox(height: 180))),
              SkeletonSliver(count: 3, height: 96),
            ]
          : _error != null || d == null
              ? [SliverToBoxAdapter(child: ErrorPanel(message: _error ?? 'الحجز غير موجود', onRetry: _load))]
              : _content(d),
    );
    return withBottomBar(
      page,
      d == null || (!canConfirm && !canCancel)
          ? null
          : BookingActionBar(
              children: [
                if (canCancel) BarButton(label: 'إلغاء', icon: Icons.block_rounded, primary: false, danger: true, onPressed: _busy ? null : _cancel),
                if (canConfirm) BarButton(label: 'تأكيد الحجز', icon: Icons.verified_rounded, flex: 2, busy: _busy, onPressed: _confirm),
              ],
            ),
    );
  }

  List<Widget> _content(Map<String, dynamic> d) {
    final payment = d['payment'] as Map?;
    final notes = (d['bookingNotes'] as List?) ?? const [];
    final status = d['status']?.toString();
    final phone = guestPhone(d);
    final canChat = Session.can('inbox.read') && guestUserId(d) != null;
    final sColor = statusColor(status);
    final payStatus = payment?['status']?.toString();
    final proofUrl = payment?['proofUrl']?.toString();

    return [
      SliverToBoxAdapter(
        child: Pad(
          top: 4,
          child: StaffCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: .07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(StaffRadius.lg)),
                  ),
                  child: Row(
                    children: [
                      IconBox(icon: statusIcon(status), color: sColor, size: 34, filled: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(statusLabel(status), style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: sColor)),
                      ),
                      Text(formatIqd(d['totalPrice']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: Row(
                    children: [
                      Avatar(guestName(d), size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(guestName(d), style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                            if (phone != null)
                              Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2)),
                          ],
                        ),
                      ),
                      if (phone != null) RoundIconAction(icon: Icons.call_rounded, color: placeSuccess, tooltip: 'اتصال', onTap: () => callPhone(context, phone)),
                      if (canChat) RoundIconAction(icon: Icons.chat_rounded, color: placeInfo, tooltip: 'محادثة', onTap: () => openGuestChat(context, d)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(fmtRange(d['startDate'], d['endDate']), color: placeInk, dense: true),
                      BookingShiftChip(shift: d['shift']?.toString()),
                      if (d['guests'] != null) StatusChip('${d['guests']} ضيف', color: placeInk2, dense: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (payment != null)
        SliverToBoxAdapter(
          child: BookingSection(
            title: 'الدفع',
            icon: Icons.payments_rounded,
            color: placeSuccess,
            trailing: StatusChip(paymentStatusAr(payStatus), color: paymentStatusColor(payStatus), dense: true),
            children: [
              InfoLine(icon: Icons.attach_money_rounded, label: 'المبلغ', value: formatIqd(payment['amount'])),
              if (payment['method'] != null) InfoLine(icon: Icons.account_balance_wallet_outlined, label: 'الطريقة', value: paymentMethodAr(payment['method']?.toString())),
              if (proofUrl != null && proofUrl.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => showImageViewer(context, mediaUrl(proofUrl)),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('عرض إثبات الدفع'),
                  ),
                ),
              if (Session.can('payments.verify') && payStatus == 'PENDING')
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: placeSuccess),
                    onPressed: _busy ? null : _verifyPay,
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('اعتماد الدفع'),
                  ),
                ),
            ],
          ),
        ),
      SliverToBoxAdapter(
        child: SectionHeader(
          'ملاحظات داخلية',
          count: notes.length,
          actionLabel: Session.can('bookings.write') ? 'إضافة' : null,
          onAction: Session.can('bookings.write') ? _addNote : null,
        ),
      ),
      SliverToBoxAdapter(
        child: Pad(
          child: notes.isEmpty
              ? const StaffCard(
                  child: Text('لا ملاحظات بعد', style: TextStyle(fontFamily: 'Cairo', color: placeInk3, fontWeight: FontWeight.w700)),
                )
              : TileGroup(
                  children: [
                    for (final n in notes)
                      Builder(builder: (context) {
                        final map = n as Map;
                        final author = map['author']?['name']?.toString() ?? 'موظف';
                        final created = DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toLocal();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Avatar(author, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      [author, if (created != null) DateFormat('d/M HH:mm').format(created)].join(' · '),
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2),
                                    ),
                                    Text(map['content']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', height: 1.5, fontWeight: FontWeight.w600, color: placeInk)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    ];
  }
}
