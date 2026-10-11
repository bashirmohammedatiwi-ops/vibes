import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
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
    final reason = await showTextSheet(
      context,
      title: 'فتح نزاع',
      label: 'سبب النزاع',
      hint: 'مثال: الزبون يطالب باسترداد',
      confirmLabel: 'فتح النزاع',
      danger: true,
    );
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
    final text = await showTextSheet(
      context,
      title: 'تعديل الملاحظة',
      label: 'نص الملاحظة',
      initial: note['content']?.toString() ?? '',
      maxLines: 6,
    );
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

  /// كل الإجراءات المتاحة حسب الحالة والصلاحية.
  List<_Act> _actionsFor(String? status) {
    final acts = <_Act>[];
    if (canWriteBookings) {
      if (status == 'PENDING') {
        acts.add(_Act(Icons.verified_rounded, 'تأكيد الحجز', () => _quickStatus('CONFIRMED', 'تأكيد الحجز'), primary: true));
        acts.add(_Act(Icons.payments_outlined, 'طلب الدفع', () => _quickStatus('AWAITING_PAYMENT', 'طلب الدفع'), quick: true));
      }
      if (status == 'AWAITING_PAYMENT') {
        acts.add(_Act(Icons.verified_rounded, 'تأكيد الدفع', () => _quickStatus('CONFIRMED', 'تأكيد الحجز'), primary: true));
      }
      if (status == 'CONFIRMED') {
        acts.add(_Act(Icons.task_alt_rounded, 'تمت الزيارة', () => _quickStatus('COMPLETED', 'إغلاق الحجز كمكتمل'), primary: true));
      }
      acts.add(_Act(Icons.swap_horiz_rounded, 'تغيير الحالة', _changeStatus));
      if (status != 'CANCELLED' && status != 'COMPLETED') {
        acts.add(_Act(Icons.edit_calendar_rounded, 'إعادة جدولة', _reschedule));
      }
    }
    if (Session.can('disputes.review')) {
      if (status == 'DISPUTED') {
        acts.add(_Act(Icons.gavel_rounded, 'حل النزاع', _resolveDispute, primary: true));
      } else if (status != 'CANCELLED') {
        acts.add(_Act(Icons.report_gmailerrorred_rounded, 'فتح نزاع', _openDispute, danger: true));
      }
    }
    return acts;
  }

  Future<void> _moreSheet(List<_Act> acts) async {
    final picked = await showStaffSheet<_Act>(
      context,
      title: 'إجراءات الحجز',
      child: SingleChildScrollView(
        child: TileGroup(
          children: [
            for (final a in acts)
              TaskTile(
                icon: a.icon,
                color: a.danger ? placeDanger : (a.primary ? placeSuccess : placeInk),
                title: a.label,
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) picked.onTap();
  }

  Widget? _bottomBar() {
    final b = _booking;
    if (b == null) return null;
    final acts = _actionsFor(_status);
    if (acts.isEmpty) return null;
    final primary = acts.where((a) => a.primary).toList();
    final quick = acts.where((a) => a.quick).toList();
    final rest = acts.where((a) => !a.primary).toList();
    return BookingActionBar(
      children: [
        if (rest.isNotEmpty)
          BarButton(
            label: primary.isEmpty ? 'إجراءات الحجز' : 'المزيد',
            icon: Icons.more_horiz_rounded,
            primary: primary.isEmpty,
            busy: _busy && primary.isEmpty,
            onPressed: () => _moreSheet(rest),
          ),
        if (quick.isNotEmpty) BarButton(label: quick.first.label, icon: quick.first.icon, primary: false, onPressed: _busy ? null : quick.first.onTap),
        if (primary.isNotEmpty)
          BarButton(label: primary.first.label, icon: primary.first.icon, busy: _busy, flex: 2, onPressed: primary.first.onTap),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final property = asMap(b?['property']);
    final id = '${b?['id'] ?? widget.bookingId}';
    final page = StaffPage(
      title: property?['name']?.toString() ?? 'إدارة الحجز',
      subtitle: '#${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()} · ${b == null ? 'جارٍ التحميل' : statusLabel(_status)}',
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
              SliverToBoxAdapter(child: Pad(top: 4, child: SkeletonBox(height: 220))),
              SkeletonSliver(count: 3, height: 130),
            ]
          : _error != null || b == null
              ? [SliverToBoxAdapter(child: ErrorPanel(message: _error ?? 'الحجز غير موجود', onRetry: _load))]
              : _content(b),
    );
    return withBottomBar(page, _loading ? null : _bottomBar());
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
    final phone = guestPhone(b);
    final canChat = Session.can('inbox.read') && guestUserId(b) != null;
    final discount = asNum(b['discountAmount']) ?? 0;
    final sColor = statusColor(status);

    return [
      // ── رأس: المكان والحالة والسعر ──
      SliverToBoxAdapter(
        child: Pad(
          top: 4,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StaffRadius.lg),
              border: Border.all(color: placeLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (media != null)
                  SizedBox(
                    height: 150,
                    child: NetImage(url: mediaUrl((media['thumbnailUrl'] ?? media['url'])?.toString()), radius: 0),
                  ),
                Container(
                  color: sColor.withValues(alpha: .07),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      IconBox(icon: statusIcon(status), color: sColor, size: 36, filled: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusLabel(status), style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: sColor)),
                            Text(statusHint(status), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(placeTypeIcon(property?['type']?.toString()), size: 18, color: placeBrass),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [
                                placeTypeLabel(property?['type']?.toString()),
                                if (city?['nameAr'] != null) city!['nameAr'].toString(),
                                if (province?['nameAr'] != null) province!['nameAr'].toString(),
                              ].join(' · '),
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fmtRange(b['startDate'], b['endDate']),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          BookingShiftChip(shift: b['shift']?.toString(), short: false),
                          StatusChip(
                            originLabel(b['origin']?.toString()),
                            color: b['origin'] == 'EXTERNAL' ? placeShiftEvening : placeInk2,
                            dense: true,
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: '${b['id']}'));
                              HapticFeedback.selectionClick();
                              showToast(context, 'نُسخ رقم الحجز');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 13, color: placeInk2),
                                  const SizedBox(width: 4),
                                  Text(
                                    '#${'${b['id']}'.length > 8 ? '${b['id']}'.substring(0, 8).toUpperCase() : b['id']}',
                                    style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.w800, color: placeInk),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: placeInk2)),
                          const Spacer(),
                          Text(formatIqd(b['totalPrice']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w900, color: placeInk)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ── الزبون ──
      SliverToBoxAdapter(
        child: Pad(
          child: StaffCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Avatar(guestName(b), size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guestName(b), style: const TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w900, color: placeInk)),
                          if (phone != null)
                            Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2)),
                        ],
                      ),
                    ),
                    if (phone != null)
                      RoundIconAction(
                        icon: Icons.copy_rounded,
                        tooltip: 'نسخ الرقم',
                        color: placeInk2,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: phone));
                          showToast(context, 'نُسخ الرقم');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.call_rounded,
                        label: 'اتصال',
                        color: placeSuccess,
                        onTap: phone == null ? null : () => callPhone(context, phone),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.chat_rounded,
                        label: 'محادثة',
                        color: placeInfo,
                        onTap: canChat ? () => openGuestChat(context, b) : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ContactButton(icon: Icons.people_alt_rounded, label: '${b['guests'] ?? 1} ضيف', color: placeInk2, onTap: null, info: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      if (status == 'DISPUTED' && (b['disputeReason'] != null || b['disputeNote'] != null))
        SliverToBoxAdapter(
          child: BookingSection(
            title: 'نزاع مفتوح',
            icon: Icons.gavel_rounded,
            color: placeDanger,
            children: [
              if (b['disputeReason'] != null) InfoLine(icon: Icons.report_outlined, label: 'السبب', value: '${b['disputeReason']}'),
              if (b['disputeNote'] != null) InfoLine(icon: Icons.notes_rounded, label: 'ملاحظة', value: '${b['disputeNote']}'),
            ],
          ),
        ),

      SliverToBoxAdapter(
        child: BookingSection(
          title: 'الموعد',
          icon: Icons.event_note_rounded,
          color: placeInfo,
          children: [
            InfoLine(icon: Icons.event_outlined, label: 'التاريخ', value: fmtRange(b['startDate'], b['endDate'])),
            InfoLine(icon: Icons.schedule_rounded, label: 'الشفت', value: shiftShort(b['shift']?.toString())),
            InfoLine(icon: Icons.add_circle_outline_rounded, label: 'أُنشئ', value: fmtStamp(b['createdAt'])),
            InfoLine(icon: Icons.update_rounded, label: 'آخر تحديث', value: fmtStamp(b['updatedAt'])),
          ],
        ),
      ),

      SliverToBoxAdapter(
        child: BookingSection(
          title: 'المبلغ والدفع',
          icon: Icons.payments_rounded,
          color: placeSuccess,
          trailing: payment == null
              ? null
              : StatusChip(
                  paymentStatusAr(payment['status']?.toString()),
                  color: paymentStatusColor(payment['status']?.toString()),
                  dense: true,
                ),
          children: [
            InfoLine(icon: Icons.sell_outlined, label: 'الإجمالي', value: formatIqd(b['totalPrice'])),
            if (discount > 0) InfoLine(icon: Icons.local_offer_outlined, label: 'الخصم', value: formatIqd(discount)),
            if (payment == null)
              const InfoLine(icon: Icons.receipt_long_outlined, label: 'الدفع', value: 'لا يوجد سجل دفع')
            else ...[
              InfoLine(icon: Icons.receipt_long_outlined, label: 'حالة الدفع', value: paymentStatusAr(payment['status']?.toString())),
              InfoLine(icon: Icons.account_balance_wallet_outlined, label: 'الطريقة', value: paymentMethodAr(payment['method']?.toString())),
              InfoLine(icon: Icons.attach_money_rounded, label: 'المبلغ', value: formatIqd(payment['amount'])),
              if (payment['transactionRef'] != null)
                InfoLine(icon: Icons.tag_rounded, label: 'المرجع', value: '${payment['transactionRef']}', ltr: true),
              if ((payment['adminNote']?.toString() ?? '').isNotEmpty)
                InfoLine(icon: Icons.sticky_note_2_outlined, label: 'ملاحظة الدفع', value: '${payment['adminNote']}'),
              if ((payment['proofUrl']?.toString() ?? '').isNotEmpty)
                GestureDetector(
                  onTap: () => showImageViewer(context, mediaUrl(payment['proofUrl'].toString())),
                  child: Container(
                    height: 120,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(StaffRadius.md), border: Border.all(color: placeLine)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetImage(url: mediaUrl(payment['proofUrl'].toString()), icon: Icons.receipt_outlined, radius: 0),
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
      ),

      if ((b['notes']?.toString() ?? '').trim().isNotEmpty)
        SliverToBoxAdapter(
          child: BookingSection(
            title: 'ملاحظات الحجز',
            subtitle: 'ملاحظات الزبون وملاحظات تغيير الحالة',
            icon: Icons.notes_rounded,
            color: placeInk2,
            children: [
              Text('${b['notes']}', style: const TextStyle(fontFamily: 'Cairo', height: 1.6, fontWeight: FontWeight.w600, color: placeInk)),
            ],
          ),
        ),

      SliverToBoxAdapter(child: _notesSection()),
    ];
  }

  Widget _notesSection() {
    return BookingSection(
      title: 'الملاحظات الداخلية',
      subtitle: 'لا يراها الزبون — للتنسيق بين الفريق',
      icon: Icons.forum_rounded,
      color: placeShiftEvening,
      trailing: _notes.isEmpty ? null : CountBadge(_notes.length, color: placeShiftEvening),
      children: [
        if (_notesError != null)
          HintBanner(icon: Icons.error_outline_rounded, text: _notesError!, color: placeDanger)
        else if (_notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('لا ملاحظات بعد — ابدأ أول ملاحظة', style: TextStyle(fontFamily: 'Cairo', color: placeInk3, fontWeight: FontWeight.w700)),
          )
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
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: placeInk),
                decoration: const InputDecoration(hintText: 'اكتب ملاحظة داخلية…'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              width: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(52, 52)),
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
    final authorName = mine ? 'أنت' : (author?['name']?.toString() ?? author?['phone']?.toString() ?? 'موظف');
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 0, 10),
      decoration: BoxDecoration(
        color: mine ? placeGoldSoft : placePaper,
        borderRadius: BorderRadius.circular(StaffRadius.md),
        border: Border.all(color: mine ? placeGold.withValues(alpha: 0.35) : placeLineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(authorName, size: 30, color: mine ? placeBrass : placeNavyHigh),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                    ),
                    if (note['isInternal'] == false) ...[
                      const SizedBox(width: 6),
                      const StatusChip('عامة', color: placeShiftEvening, dense: true),
                    ],
                  ],
                ),
                Text(fmtStamp(note['createdAt']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: placeInk3)),
                const SizedBox(height: 4),
                Text('${note['content'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', height: 1.5, fontWeight: FontWeight.w600, color: placeInk)),
              ],
            ),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              tooltip: 'خيارات',
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: placeInk2),
              onSelected: (v) => v == 'edit' ? _editNote(note) : _deleteNote(note),
              itemBuilder: (_) => [
                if (canEdit) const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: placeDanger))),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _Act {
  const _Act(this.icon, this.label, this.onTap, {this.primary = false, this.danger = false, this.quick = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  /// يظهر كزر ثانوي مباشر في الشريط السفلي (بجانب الرئيسي).
  final bool quick;
}

/// زر تواصل مربّع (أيقونة فوق نص) بارتفاع 56.
class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.color, required this.onTap, this.info = false});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || info;
    final c = enabled ? color : placeInk3;
    return Material(
      color: c.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(StaffRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(StaffRadius.md),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: c),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: c)),
            ],
          ),
        ),
      ),
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
    final page = StaffPage(
      title: 'إعادة جدولة',
      subtitle: property?['name']?.toString() ?? 'الحجز',
      slivers: [
        // الموعد الحالي
        SliverToBoxAdapter(
          child: Pad(
            top: 4,
            child: StaffCard(
              color: placePaper,
              borderColor: placeLine,
              child: Row(
                children: [
                  const IconBox(icon: Icons.history_rounded, color: placeInk2, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الموعد الحالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2)),
                        Text(
                          fmtRange(_b['startDate'], _b['endDate']),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: placeInk),
                        ),
                      ],
                    ),
                  ),
                  BookingShiftChip(shift: _b['shift']?.toString()),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: BookingSection(
            title: 'الموعد الجديد',
            icon: Icons.edit_calendar_rounded,
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
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Pad(
            child: QuoteCard(
              quote: _quote,
              loading: _quoting,
              error: _quoteError,
              compareTo: asNum(_b['totalPrice']),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: BookingSection(
            title: 'ملاحظة',
            icon: Icons.sticky_note_2_rounded,
            color: placeInk2,
            children: [
              StaffField(controller: _note, label: 'سبب إعادة الجدولة (اختياري)', maxLines: 3),
            ],
          ),
        ),
      ],
    );
    return withBottomBar(
      page,
      BookingActionBar(
        children: [
          BarButton(label: 'تراجع', primary: false, onPressed: _saving ? null : () => Navigator.pop(context)),
          BarButton(
            label: 'حفظ الموعد الجديد',
            icon: Icons.check_rounded,
            flex: 2,
            busy: _saving,
            onPressed: (_quoting || (_quote?['available'] == false)) ? null : _save,
          ),
        ],
      ),
    );
  }
}
