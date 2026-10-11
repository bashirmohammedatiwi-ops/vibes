import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'booking_kit.dart';

/// إدارة حجز واحد: التفاصيل الكاملة، تغيير الحالة، إعادة الجدولة، النزاع، والملاحظات الداخلية.
///
/// صلاحيات: العرض والملاحظات `bookings.read` — الحالة/الجدولة/حذف الملاحظات `bookings.write`
/// — النزاع `disputes.review`.
class BookingManageScreen extends StatefulWidget {
  const BookingManageScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<BookingManageScreen> createState() => _BookingManageScreenState();
}

class _BookingManageScreenState extends State<BookingManageScreen> {
  Map<String, dynamic>? _booking;
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;
  String? _notesError;
  bool _busy = false;
  final _noteInput = TextEditingController();
  bool _sendingNote = false;

  String get _base => '/api/admin/bookings/${widget.bookingId}';
  String? get _status => _booking?['status']?.toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_booking == null) _loading = true;
    });
    try {
      final results = await Future.wait<Object?>([
        Api.map(_base),
        Api.send('$_base/notes').then<Object?>((v) => v).catchError((Object e) => e),
      ]);
      _booking = results[0] as Map<String, dynamic>;
      final notesRaw = results[1];
      if (notesRaw is List) {
        _notes = [for (final n in notesRaw) if (n is Map) Map<String, dynamic>.from(n)];
        _notesError = null;
      } else {
        _notesError = notesRaw is Object ? errorText(notesRaw) : null;
      }
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reloadNotes() async {
    try {
      final rows = await Api.list('$_base/notes');
      _notes = [for (final n in rows) if (n is Map) Map<String, dynamic>.from(n)];
      _notesError = null;
    } catch (e) {
      _notesError = errorText(e);
    }
    if (mounted) setState(() {});
  }

  // ─────────── الحالة ───────────

  Future<void> _changeStatus() async {
    final result = await showStatusSheet(
      context,
      options: allBookingStatuses.where((s) => s != 'DISPUTED').toList(),
      current: _status,
      subtitle: 'الحالة الحالية: ${statusLabel(_status)}',
    );
    if (result == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد تغيير الحالة',
      message: 'سيتم نقل الحجز إلى «${statusLabel(result.status)}» وإشعار الأطراف المعنية.',
      confirmLabel: 'تطبيق',
      danger: result.status == 'CANCELLED',
    );
    if (!ok) return;
    await _run(() async {
      await Api.send('$_base/status', method: 'PATCH', body: {
        'status': result.status,
        if (result.note.isNotEmpty) 'adminNote': result.note,
      });
    }, 'تم تحديث الحالة إلى ${statusLabel(result.status)}');
  }

  Future<void> _quickStatus(String status, String label) async {
    final ok = await confirmDialog(
      context,
      title: label,
      message: 'سيتم نقل الحجز إلى «${statusLabel(status)}».',
      confirmLabel: label,
    );
    if (!ok) return;
    await _run(
      () => Api.send('$_base/status', method: 'PATCH', body: {'status': status}),
      'تم تحديث الحالة إلى ${statusLabel(status)}',
    );
  }

  // ─────────── النزاع ───────────

  Future<void> _openDispute() async {
    final reason = await promptText(context, title: 'فتح نزاع — السبب', hint: 'مثال: الزبون يطالب باسترداد');
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    await _run(
      () => Api.send('$_base/dispute', method: 'POST', body: {'reason': reason.trim()}),
      'تم فتح النزاع',
    );
  }

  Future<void> _resolveDispute() async {
    final result = await showStatusSheet(
      context,
      title: 'حل النزاع',
      subtitle: 'اختر الحالة النهائية للحجز',
      options: const ['CONFIRMED', 'COMPLETED', 'CANCELLED'],
    );
    if (result == null || !mounted) return;
    await _run(
      () => Api.send('$_base/dispute/resolve', method: 'POST', body: {
        'status': result.status,
        if (result.note.isNotEmpty) 'note': result.note,
      }),
      'تم حل النزاع',
    );
  }

  // ─────────── الجدولة ───────────

  Future<void> _reschedule() async {
    final b = _booking;
    if (b == null) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BookingRescheduleScreen(booking: b)),
    );
    if (done == true) await _load();
  }

  Future<void> _run(Future<dynamic> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      HapticFeedback.mediumImpact();
      if (mounted) showToast(context, success);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────── الملاحظات ───────────

  bool _ownsNote(Map note) =>
      note['authorId']?.toString() == Session.me['id']?.toString() || Session.me['role'] == 'ADMIN';

  Future<void> _addNote() async {
    final text = _noteInput.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingNote = true);
    try {
      await Api.send('$_base/notes', method: 'POST', body: {'content': text, 'isInternal': true});
      _noteInput.clear();
      if (mounted) FocusScope.of(context).unfocus();
      HapticFeedback.selectionClick();
      await _reloadNotes();
      if (mounted) showToast(context, 'أُضيفت الملاحظة');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sendingNote = false);
    }
  }

  Future<void> _editNote(Map note) async {
    final controller = TextEditingController(text: note['content']?.toString() ?? '');
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تعديل الملاحظة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            StaffField(controller: controller, label: 'نص الملاحظة', maxLines: 5),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;
    if (text.isEmpty) {
      showToast(context, 'الملاحظة فارغة', error: true);
      return;
    }
    try {
      await Api.send('$_base/notes/${note['id']}', method: 'PATCH', body: {'content': text});
      await _reloadNotes();
      if (mounted) showToast(context, 'تم تعديل الملاحظة');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _deleteNote(Map note) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الملاحظة',
      message: 'لا يمكن التراجع عن الحذف.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.send('$_base/notes/${note['id']}', method: 'DELETE');
      await _reloadNotes();
      if (mounted) showToast(context, 'حُذفت الملاحظة');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  // ─────────── الواجهة ───────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الحجز'),
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
          ],
        ),
        body: AsyncList(
          loading: _loading,
          error: _error,
          isEmpty: _booking == null,
          onRefresh: _load,
          children: _booking == null ? const [] : _content(_booking!),
        ),
    );
  }

  List<Widget> _content(Map<String, dynamic> b) {
    final property = asMap(b['property']);
    final payment = asMap(b['payment']);
    final city = asMap(property?['city']);
    final province = asMap(city?['province']);
    final media = property?['media'] is List && (property!['media'] as List).isNotEmpty
        ? asMap((property['media'] as List).first)
        : null;
    final status = _status;
    final active = ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'].contains(status);
    final phone = guestPhone(b);
    final discount = asNum(b['discountAmount']) ?? 0;

    return [
      // ── رأس ──
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: placeLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (media != null)
              SizedBox(
                height: 140,
                child: NetImage(url: mediaUrl((media['thumbnailUrl'] ?? media['url'])?.toString()), radius: 0),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property?['name']?.toString() ?? 'حجز',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w900, color: placeInk),
                        ),
                      ),
                      BookingStatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      placeTypeLabel(property?['type']?.toString()),
                      if (city?['nameAr'] != null) city!['nameAr'].toString(),
                      if (province?['nameAr'] != null) province!['nameAr'].toString(),
                    ].join(' · '),
                    style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ShiftBadge(shift: b['shift']?.toString()),
                      StatusPill(
                        label: originLabel(b['origin']?.toString()),
                        color: b['origin'] == 'EXTERNAL' ? placeShiftEvening : placeInk2,
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: '${b['id']}'));
                          showToast(context, 'نُسخ رقم الحجز');
                        },
                        child: StatusPill(
                          label: '#${'${b['id']}'.substring(0, 8).toUpperCase()}',
                          color: placeInk,
                          icon: Icons.copy_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── إجراءات ──
      if (canWriteBookings || Session.can('disputes.review')) _actions(status, active),

      if (status == 'DISPUTED' && (b['disputeReason'] != null || b['disputeNote'] != null))
        FormSection(
          title: 'نزاع مفتوح',
          icon: Icons.gavel_rounded,
          children: [
            if (b['disputeReason'] != null) InfoLine(icon: Icons.report_outlined, label: 'السبب', value: '${b['disputeReason']}'),
            if (b['disputeNote'] != null) InfoLine(icon: Icons.notes_rounded, label: 'ملاحظة', value: '${b['disputeNote']}'),
          ],
        ),

      FormSection(
        title: 'الزبون',
        icon: Icons.person_outline_rounded,
        children: [
          InfoLine(icon: Icons.badge_outlined, label: 'الاسم', value: guestName(b)),
          InfoLine(
            icon: Icons.phone_outlined,
            label: 'الهاتف',
            value: phone ?? '—',
            ltr: true,
            trailing: phone == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconAction(icon: Icons.copy_rounded, onTap: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        showToast(context, 'نُسخ الرقم');
                      }),
                      _IconAction(icon: Icons.call_rounded, onTap: () => callPhone(context, phone)),
                    ],
                  ),
          ),
          InfoLine(icon: Icons.people_outline, label: 'الضيوف', value: '${b['guests'] ?? 1}'),
        ],
      ),

      FormSection(
        title: 'الموعد',
        icon: Icons.event_note_outlined,
        children: [
          InfoLine(icon: Icons.event_outlined, label: 'التاريخ', value: fmtRange(b['startDate'], b['endDate'])),
          InfoLine(icon: Icons.schedule_rounded, label: 'الشفت', value: shiftShort(b['shift']?.toString())),
          InfoLine(icon: Icons.add_circle_outline_rounded, label: 'أُنشئ', value: fmtStamp(b['createdAt'])),
          InfoLine(icon: Icons.update_rounded, label: 'آخر تحديث', value: fmtStamp(b['updatedAt'])),
        ],
      ),

      FormSection(
        title: 'المبلغ والدفع',
        icon: Icons.payments_outlined,
        children: [
          InfoLine(icon: Icons.sell_outlined, label: 'الإجمالي', value: formatIqd(b['totalPrice'])),
          if (discount > 0) InfoLine(icon: Icons.local_offer_outlined, label: 'الخصم', value: formatIqd(discount)),
          if (payment == null)
            const InfoLine(icon: Icons.receipt_long_outlined, label: 'الدفع', value: 'لا يوجد سجل دفع')
          else ...[
            InfoLine(
              icon: Icons.receipt_long_outlined,
              label: 'حالة الدفع',
              value: paymentStatusAr(payment['status']?.toString()),
              trailing: StatusPill(
                label: paymentStatusAr(payment['status']?.toString()),
                color: paymentStatusColor(payment['status']?.toString()),
              ),
            ),
            InfoLine(icon: Icons.account_balance_wallet_outlined, label: 'الطريقة', value: paymentMethodAr(payment['method']?.toString())),
            InfoLine(icon: Icons.attach_money_rounded, label: 'المبلغ', value: formatIqd(payment['amount'])),
            if (payment['transactionRef'] != null)
              InfoLine(icon: Icons.tag_rounded, label: 'المرجع', value: '${payment['transactionRef']}', ltr: true),
            if ((payment['adminNote']?.toString() ?? '').isNotEmpty)
              InfoLine(icon: Icons.sticky_note_2_outlined, label: 'ملاحظة الدفع', value: '${payment['adminNote']}'),
            if ((payment['proofUrl']?.toString() ?? '').isNotEmpty)
              GestureDetector(
                onTap: () => _showProof(mediaUrl(payment['proofUrl'].toString())),
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: placeLine)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetImage(url: mediaUrl(payment['proofUrl'].toString()), icon: Icons.receipt_outlined),
                      const PositionedDirectional(
                        bottom: 8,
                        start: 8,
                        child: StatusPill(label: 'إثبات الدفع', color: placeInk, icon: Icons.zoom_in_rounded),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),

      if ((b['notes']?.toString() ?? '').trim().isNotEmpty)
        FormSection(
          title: 'ملاحظات الحجز',
          subtitle: 'ملاحظات الزبون وملاحظات تغيير الحالة',
          icon: Icons.notes_rounded,
          children: [
            Text('${b['notes']}', style: const TextStyle(fontFamily: 'Cairo', height: 1.6, fontWeight: FontWeight.w600)),
          ],
        ),

      _notesSection(),
      const SizedBox(height: 24),
    ];
  }

  Widget _actions(String? status, bool active) {
    final buttons = <Widget>[];
    if (canWriteBookings) {
      if (status == 'PENDING') {
        buttons.add(_ActionButton(
          icon: Icons.payments_outlined,
          label: 'طلب الدفع',
          onTap: () => _quickStatus('AWAITING_PAYMENT', 'طلب الدفع'),
        ));
        buttons.add(_ActionButton(
          icon: Icons.verified_outlined,
          label: 'تأكيد',
          primary: true,
          onTap: () => _quickStatus('CONFIRMED', 'تأكيد الحجز'),
        ));
      }
      if (status == 'AWAITING_PAYMENT') {
        buttons.add(_ActionButton(
          icon: Icons.verified_outlined,
          label: 'تأكيد الدفع',
          primary: true,
          onTap: () => _quickStatus('CONFIRMED', 'تأكيد الحجز'),
        ));
      }
      if (status == 'CONFIRMED') {
        buttons.add(_ActionButton(
          icon: Icons.task_alt_rounded,
          label: 'تمت الزيارة',
          primary: true,
          onTap: () => _quickStatus('COMPLETED', 'إغلاق الحجز كمكتمل'),
        ));
      }
      buttons.add(_ActionButton(icon: Icons.swap_horiz_rounded, label: 'تغيير الحالة', onTap: _changeStatus));
      if (status != 'CANCELLED' && status != 'COMPLETED') {
        buttons.add(_ActionButton(icon: Icons.edit_calendar_outlined, label: 'إعادة جدولة', onTap: _reschedule));
      }
    }
    if (Session.can('disputes.review')) {
      if (status == 'DISPUTED') {
        buttons.add(_ActionButton(icon: Icons.gavel_rounded, label: 'حل النزاع', primary: true, onTap: _resolveDispute));
      } else if (status != 'CANCELLED') {
        buttons.add(_ActionButton(icon: Icons.report_gmailerrorred_rounded, label: 'فتح نزاع', danger: true, onTap: _openDispute));
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Widget _notesSection() {
    return FormSection(
      title: 'الملاحظات الداخلية',
      subtitle: 'لا يراها الزبون — للتنسيق بين الفريق',
      icon: Icons.forum_outlined,
      children: [
        if (_notesError != null)
          Text(_notesError!, style: const TextStyle(color: placeDanger, fontFamily: 'Cairo'))
        else if (_notes.isEmpty)
          const Text('لا ملاحظات بعد — ابدأ أول ملاحظة', style: TextStyle(fontFamily: 'Cairo', color: placeInk2))
        else
          for (final note in _notes) _noteBubble(note),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _noteInput,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                decoration: const InputDecoration(hintText: 'اكتب ملاحظة داخلية…'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              width: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: _sendingNote ? null : _addNote,
                child: _sendingNote
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _noteBubble(Map<String, dynamic> note) {
    final author = asMap(note['author']);
    final mine = note['authorId']?.toString() == Session.me['id']?.toString();
    final canEdit = _ownsNote(note);
    final canDelete = canEdit && canWriteBookings;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: mine ? placeBrass.withValues(alpha: 0.08) : placePaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mine ? placeBrass.withValues(alpha: 0.3) : placeLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mine ? 'أنت' : (author?['name']?.toString() ?? author?['phone']?.toString() ?? 'موظف'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(fmtStamp(note['createdAt']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk2)),
                    if (note['isInternal'] == false) ...[
                      const SizedBox(width: 6),
                      const StatusPill(label: 'عامة', color: placeShiftEvening),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('${note['content'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', height: 1.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: placeInk2),
              onSelected: (v) => v == 'edit' ? _editNote(note) : _deleteNote(note),
              itemBuilder: (_) => [
                if (canEdit) const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: placeDanger))),
              ],
            ),
        ],
      ),
    );
  }

  void _showProof(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: AspectRatio(aspectRatio: 3 / 4, child: NetImage(url: url, fit: BoxFit.contain, radius: 0)),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.primary = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? placeDanger : (primary ? Colors.white : placeInk);
    return Material(
      color: primary ? placeInk : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary ? placeInk : (danger ? placeDanger.withValues(alpha: 0.4) : placeLine)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 18, color: placeBrass)),
    );
  }
}

// ───────────────────────── إعادة الجدولة ─────────────────────────

/// إعادة جدولة حجز (تواريخ + شفت) مع عرض سعر حيّ يستثني الحجز نفسه — `bookings.write`.
class BookingRescheduleScreen extends StatefulWidget {
  const BookingRescheduleScreen({super.key, required this.booking});
  final Map<String, dynamic> booking;

  @override
  State<BookingRescheduleScreen> createState() => _BookingRescheduleScreenState();
}

class _BookingRescheduleScreenState extends State<BookingRescheduleScreen> {
  late DateTime _start;
  late int _days;
  late String _shift;
  late List<String> _shiftOptions;
  final _note = TextEditingController();
  final _debounce = Debouncer();
  Map<String, dynamic>? _quote;
  String? _quoteError;
  bool _quoting = false;
  bool _saving = false;
  int _seq = 0;

  Map<String, dynamic> get _b => widget.booking;

  @override
  void initState() {
    super.initState();
    final s = parseDay(_b['startDate']) ?? dayOnly(DateTime.now());
    final e = parseDay(_b['endDate']) ?? s.add(const Duration(days: 1));
    _start = s;
    _days = dayCount(s, e);
    _shiftOptions = shiftsForProperty(asMap(_b['property']));
    final current = _b['shift']?.toString() ?? 'FULL';
    _shift = _shiftOptions.contains(current) ? current : _shiftOptions.first;
    _requote();
  }

  @override
  void dispose() {
    _note.dispose();
    _debounce.dispose();
    super.dispose();
  }

  DateTime get _end => _start.add(Duration(days: _days));

  void _requote() {
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    _debounce.run(_fetchQuote);
  }

  Future<void> _fetchQuote() async {
    final seq = ++_seq;
    try {
      final q = await Api.map('/api/admin/bookings/quote', method: 'POST', body: {
        'propertyId': _b['propertyId'] ?? asMap(_b['property'])?['id'],
        'startDate': isoDay(_start),
        'endDate': isoDay(_end),
        'shift': _shift,
        'excludeBookingId': _b['id'],
      });
      if (!mounted || seq != _seq) return;
      setState(() {
        _quote = q;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _quote = null;
        _quoteError = errorText(e);
      });
    }
    if (mounted && seq == _seq) setState(() => _quoting = false);
  }

  Future<void> _save() async {
    if (_quote != null && _quote!['available'] != true) {
      showToast(context, 'التاريخ المختار محجوز — اختر موعداً آخر', error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'تأكيد إعادة الجدولة',
      message:
          'الموعد الجديد: ${fmtRange(isoDay(_start), isoDay(_end))} — ${shiftShort(_shift)}.\nسيُعاد احتساب السعر${_quote != null ? ' إلى ${formatIqd(_quote!['totalPrice'])}' : ''}.',
      confirmLabel: 'حفظ الموعد',
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await Api.send('/api/admin/bookings/${_b['id']}/dates', method: 'PATCH', body: {
        'startDate': isoDay(_start),
        'endDate': isoDay(_end),
        'shift': _shift,
        if (_note.text.trim().isNotEmpty) 'adminNote': _note.text.trim(),
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      showToast(context, 'تمت إعادة الجدولة');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = asMap(_b['property']);
    final multiDayAllowed = _shift == 'FULL';
    return Scaffold(
      appBar: AppBar(title: const Text('إعادة جدولة')),
      bottomNavigationBar: BottomActionBar(
        label: 'حفظ الموعد الجديد',
        busy: _saving,
        onPressed: (_quoting || (_quote?['available'] == false)) ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MaisonHeader(
            title: property?['name']?.toString() ?? 'الحجز',
            subtitle: 'الموعد الحالي: ${fmtRange(_b['startDate'], _b['endDate'])} · ${shiftShort(_b['shift']?.toString())}',
          ),
          FormSection(
            title: 'الموعد الجديد',
            icon: Icons.edit_calendar_outlined,
            children: [
              DateField(
                label: 'يوم البداية',
                date: _start,
                onTap: () async {
                  final picked = await pickDay(context, initial: _start);
                  if (picked == null) return;
                  setState(() => _start = dayOnly(picked));
                  _requote();
                },
              ),
              if (_shiftOptions.length > 1)
                ShiftChooser(
                  options: _shiftOptions,
                  value: _shift,
                  onChanged: (v) {
                    setState(() {
                      _shift = v;
                      if (v != 'FULL') _days = 1;
                    });
                    _requote();
                  },
                ),
              if (multiDayAllowed)
                DaysStepper(
                  value: _days,
                  onChanged: (v) {
                    setState(() => _days = v);
                    _requote();
                  },
                ),
              Text(
                'من ${fmtDay(_start)} حتى ${fmtDay(_end.subtract(const Duration(days: 1)))}',
                style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: QuoteCard(
              quote: _quote,
              loading: _quoting,
              error: _quoteError,
              compareTo: asNum(_b['totalPrice']),
            ),
          ),
          FormSection(
            title: 'ملاحظة',
            icon: Icons.sticky_note_2_outlined,
            children: [
              StaffField(controller: _note, label: 'سبب إعادة الجدولة (اختياري)', maxLines: 3),
            ],
          ),
        ],
      ),
    );
  }
}
