import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/form_kit.dart';
import '../widgets/kit.dart';
import 'chat_room.dart';

/// طلبات الإلغاء والاسترداد المعلّقة — مع سياق الحجز وقرار سريع.
///
/// تعمل كصفحة مستقلة (رأس كبير) أو مضمّنة داخل Scaffold له شريط علوي
/// (كما في مركز العمليات) — عندها تعرض المحتوى فقط دون رأس إضافي.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

enum _Tab { cancellations, refunds }

class _RequestsScreenState extends State<RequestsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;
  _Tab _tab = _Tab.cancellations;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data.isEmpty;
      _error = null;
    });
    try {
      final data = await Api.map('/api/staff/requests');
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذّر الاتصال — تحقّق من الشبكة');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review({
    required Map row,
    required bool approve,
    required String kind, // cancellations | refunds
    required String what, // الإلغاء | الاسترداد
    String? amount,
  }) async {
    final id = row['id']?.toString();
    if (id == null || _busy.contains(id)) return;
    final note = await _DecisionSheet.show(
      context,
      approve: approve,
      title: approve ? 'موافقة على $what' : 'رفض $what',
      amount: amount,
    );
    if (note == null || !mounted) return; // أُغلقت الورقة — لا قرار
    setState(() => _busy.add(id));
    try {
      await Api.send('/api/staff/requests/$kind/$id', method: 'POST', body: {'approve': approve, 'note': note});
      HapticFeedback.mediumImpact();
      if (mounted) showToast(context, approve ? 'تمت الموافقة على $what' : 'تم رفض $what');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e is ApiException ? e.message : 'تعذّر تنفيذ القرار', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _openUserChat(Map? user) async {
    final userId = user?['id']?.toString();
    if (userId == null) return;
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            contactUserId: userId,
            contactName: user?['name']?.toString() ?? user?['phone']?.toString() ?? 'زبون',
            contactPhone: user?['phone']?.toString(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String? _time(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    return d == null ? null : DateFormat('d MMM · HH:mm', 'ar').format(d.toLocal());
  }

  List<Widget> _slivers() {
    final cancellations = (_data['cancellations'] as List<dynamic>? ?? []);
    final refunds = (_data['refunds'] as List<dynamic>? ?? []);
    final rows = _tab == _Tab.cancellations ? cancellations : refunds;

    final out = <Widget>[
      // ── مؤشرات + مبدّل القسم ──
      SliverToBoxAdapter(
        child: Pad(
          top: 4,
          child: Row(
            children: [
              Expanded(
                child: _TabTile(
                  label: 'طلبات إلغاء',
                  count: cancellations.length,
                  icon: Icons.event_busy_rounded,
                  color: placeWarning,
                  selected: _tab == _Tab.cancellations,
                  onTap: () => setState(() => _tab = _Tab.cancellations),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TabTile(
                  label: 'طلبات استرداد',
                  count: refunds.length,
                  icon: Icons.assignment_return_rounded,
                  color: placeDanger,
                  selected: _tab == _Tab.refunds,
                  onTap: () => setState(() => _tab = _Tab.refunds),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          _tab == _Tab.cancellations ? 'إلغاءات بانتظار القرار' : 'استردادات بانتظار القرار',
          subtitle: 'راجع سياق الحجز قبل الموافقة أو الرفض',
          count: rows.length,
        ),
      ),
    ];

    if (_loading) {
      out.add(const SkeletonSliver(count: 4, height: 150));
      return out;
    }
    if (_error != null && _data.isEmpty) {
      out.add(SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'تعذّر تحميل الطلبات',
          subtitle: _error,
          actionLabel: 'إعادة المحاولة',
          onAction: _load,
        ),
      ));
      return out;
    }
    if (rows.isEmpty) {
      out.add(SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.task_alt_rounded,
          title: _tab == _Tab.cancellations ? 'لا طلبات إلغاء معلّقة' : 'لا طلبات استرداد معلّقة',
          subtitle: 'كل شيء تحت السيطرة — اسحب للأسفل للتحديث',
        ),
      ));
      return out;
    }

    out.add(SliverList.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final map = rows[i] as Map;
        final booking = map['booking'] as Map?;
        final place = (booking?['property'] as Map?)?['name']?.toString() ?? '';
        final id = map['id']?.toString() ?? '';
        if (_tab == _Tab.cancellations) {
          final user = map['user'] as Map? ?? booking?['user'] as Map?;
          final refund = map['expectedRefund'];
          return Pad(
            bottom: 0,
            child: _RequestCard(
              kindLabel: 'إلغاء',
              kindColor: placeWarning,
              title: place.isNotEmpty ? place : 'طلب إلغاء',
              reason: map['reason']?.toString(),
              user: user,
              amountLabel: 'الاسترداد المتوقع',
              amount: refund == null ? null : formatIqd(refund),
              time: _time(map['createdAt']),
              busy: _busy.contains(id),
              canReview: Session.can('cancellations.review'),
              onChat: () => _openUserChat(user),
              onApprove: () => _review(row: map, approve: true, kind: 'cancellations', what: 'الإلغاء', amount: refund == null ? null : formatIqd(refund)),
              onReject: () => _review(row: map, approve: false, kind: 'cancellations', what: 'الإلغاء'),
            ),
          );
        }
        final user = map['user'] as Map?;
        return Pad(
          bottom: 0,
          child: _RequestCard(
            kindLabel: 'استرداد',
            kindColor: placeDanger,
            title: place.isNotEmpty ? place : 'طلب استرداد',
            reason: map['reason']?.toString(),
            user: user,
            amountLabel: 'المبلغ المطلوب',
            amount: formatIqd(map['amount']),
            time: _time(map['createdAt']),
            busy: _busy.contains(id),
            canReview: Session.can('refunds.review'),
            onChat: () => _openUserChat(user),
            onApprove: () => _review(row: map, approve: true, kind: 'refunds', what: 'الاسترداد', amount: formatIqd(map['amount'])),
            onReject: () => _review(row: map, approve: false, kind: 'refunds', what: 'الاسترداد'),
          ),
        );
      },
    ));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // مضمّنة داخل Scaffold آخر (له شريط علوي)؟ نعرض المحتوى فقط.
    final host = Scaffold.maybeOf(context);
    final embedded = host != null && host.hasAppBar;
    if (embedded) {
      return RefreshIndicator(
        color: placeGold,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ..._slivers(),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      );
    }
    return StaffPage(
      title: 'الطلبات',
      subtitle: 'إلغاء واسترداد — مع سياق الحجز',
      onRefresh: _load,
      slivers: _slivers(),
    );
  }
}

/// بلاطة مؤشر تعمل كمبدّل قسم.
class _TabTile extends StatelessWidget {
  const _TabTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      color: selected ? placeInk : Colors.white,
      borderColor: selected ? placeInk : placeLine,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: .12) : color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: selected ? placeGold : color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(fontFamily: 'Montserrat', fontSize: 20, fontWeight: FontWeight.w800, color: selected ? Colors.white : placeInk, height: 1.1),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white70 : placeInk2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة طلب: الزبون، المكان، السبب، المبلغ، وأزرار القرار.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.kindLabel,
    required this.kindColor,
    required this.title,
    required this.reason,
    required this.user,
    required this.amountLabel,
    required this.amount,
    required this.time,
    required this.busy,
    required this.canReview,
    required this.onChat,
    required this.onApprove,
    required this.onReject,
  });

  final String kindLabel;
  final Color kindColor;
  final String title;
  final String? reason;
  final Map? user;
  final String amountLabel;
  final String? amount;
  final String? time;
  final bool busy;
  final bool canReview;
  final VoidCallback onChat;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final name = user?['name']?.toString() ?? '';
    final phone = user?['phone']?.toString();
    final canChat = Session.can('inbox.read') && user != null;
    final hasReason = reason != null && reason!.trim().isNotEmpty;

    return StaffCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (user != null)
                ContactAvatar(name: name, phone: phone, size: 42)
              else
                IconBox(icon: Icons.person_outline_rounded, color: placeInk3, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : (phone ?? 'زبون'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk),
                    ),
                    if (name.isNotEmpty && phone != null && phone.isNotEmpty)
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(kindLabel, color: kindColor, dense: true),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(StaffRadius.md)),
            child: Column(
              children: [
                InfoRow(icon: Icons.home_work_outlined, label: 'المكان', value: title),
                if (amount != null) InfoRow(icon: Icons.payments_outlined, label: amountLabel, value: amount!, valueColor: placeBrass),
                if (time != null) InfoRow(icon: Icons.schedule_rounded, label: 'وقت الطلب', value: time!),
              ],
            ),
          ),
          if (hasReason) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.format_quote_rounded, size: 18, color: placeInk3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason!.trim(),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: placeInk2, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
          if (canChat || canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canChat)
                  SizedBox(
                    height: 48,
                    child: TextButton.icon(
                      onPressed: busy ? null : onChat,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('محادثة'),
                    ),
                  ),
                const Spacer(),
                if (canReview && busy)
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: placeGold)),
                    ),
                  )
                else if (canReview) ...[
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: placeDanger,
                        side: BorderSide(color: placeDanger.withValues(alpha: .4)),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(backgroundColor: placeSuccess, padding: const EdgeInsets.symmetric(horizontal: 18)),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('موافقة'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ورقة تأكيد القرار مع ملاحظة اختيارية. تُرجع الملاحظة ('' إن فرغت)
/// أو null عند الإغلاق دون تأكيد.
class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({required this.approve, this.amount});

  final bool approve;
  final String? amount;

  static Future<String?> show(BuildContext context, {required bool approve, required String title, String? amount}) {
    return showStaffSheet<String>(context, title: title, child: _DecisionSheet(approve: approve, amount: amount));
  }

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.approve ? placeSuccess : placeDanger;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(StaffRadius.md)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.approve ? Icons.verified_rounded : Icons.block_rounded, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.approve
                        ? 'سيُنفَّذ القرار فوراً ويُبلَّغ الزبون.${widget.amount != null ? '\nالمبلغ: ${widget.amount}' : ''}'
                        : 'سيُرفض الطلب ويُبلَّغ الزبون. يُفضّل كتابة سبب واضح.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: color, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 2,
            minLines: 2,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: placeInk),
            decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: () => Navigator.pop(context, _note.text.trim()),
                    child: Text(widget.approve ? 'تأكيد الموافقة' : 'تأكيد الرفض'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
