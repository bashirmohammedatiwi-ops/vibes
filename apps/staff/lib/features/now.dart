import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/office_nav.dart';
import '../core/permissions.dart';
import '../core/session.dart';
import '../core/shift.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'chat_room.dart';

class NowScreen extends StatefulWidget {
  const NowScreen({
    super.key,
    required this.onPresenceChanged,
    required this.onNavigate,
    this.badges = const {},
  });

  final ValueChanged<String> onPresenceChanged;
  final ValueChanged<StaffTab> onNavigate;
  final Map<String, int> badges;

  @override
  State<NowScreen> createState() => _NowScreenState();
}

class _NowScreenState extends State<NowScreen> {
  String _state = Session.presenceState;
  Map<String, dynamic>? _supervisor;
  Map<String, int> _dash = {};
  List<dynamic> _queue = [];
  List<dynamic> _recentCalls = [];
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _state = Session.presenceState;
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh(silent: true));
  }

  @override
  void didUpdateWidget(covariant NowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _state = Session.presenceState;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final data = await Api.map('/api/staff/dashboard');
      if (mounted) {
        final next = <String, int>{};
        for (final e in data.entries) {
          next[e.key] = (e.value as num?)?.toInt() ?? 0;
        }
        setState(() => _dash = next);
      }
    } catch (_) {}

    if (Session.can('calls.answer') || Session.can('calls.monitor')) {
      try {
        final q = await Api.map('/api/staff/queue/waiting');
        if (mounted) setState(() => _queue = q['items'] as List<dynamic>? ?? []);
      } catch (_) {}
      try {
        final calls = await Api.map('/api/staff/calls/recent');
        if (mounted) setState(() => _recentCalls = calls['items'] as List<dynamic>? ?? []);
      } catch (_) {}
    }

    if (Session.can('calls.monitor')) {
      try {
        final sup = await Api.map('/api/staff/supervisor');
        if (mounted) setState(() => _supervisor = sup);
      } catch (_) {}
    }
    if (!silent && mounted) setState(() => _state = Session.presenceState);
  }

  Future<void> _setPresence(String state) async {
    setState(() => _busy = true);
    try {
      await Api.send('/api/staff/presence', method: 'POST', body: {'state': state, 'deviceId': Session.deviceId});
      if (!mounted) return;
      setState(() => _state = state);
      Session.me['presenceState'] = state;
      widget.onPresenceChanged(state);
      if (state == 'AVAILABLE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فعّل تجاهل تحسين البطارية حتى لا يفوتك الرنين')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openQueueChat(Map row) async {
    final userId = row['callerId']?.toString();
    if (userId == null || !Session.can('inbox.read')) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          contactUserId: userId,
          contactName: row['callerName']?.toString() ?? 'زبون',
          contactPhone: row['callerPhone']?.toString(),
        ),
      ),
    );
  }

  String _callStatusAr(String? s) => switch (s) {
        'RINGING' => 'يرنّ',
        'ACTIVE' => 'جارية',
        'ENDED' => 'منتهية',
        'MISSED' => 'فائتة',
        _ => s ?? '',
      };

  String _fmtWait(int seconds) {
    if (seconds < 60) return '${seconds}ث';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final canAnswer = Session.can('calls.answer');
    final canMonitor = Session.can('calls.monitor');
    final waiting = _dash['waiting'] ?? widget.badges['waiting'] ?? _queue.length;

    return RefreshIndicator(
      onRefresh: () => _refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [placeInk, placeInk.withValues(alpha: 0.88)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Session.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          PresenceDot(state: _state, pulse: _state == 'AVAILABLE' || _state == 'RINGING'),
                          const SizedBox(width: 8),
                          Text(presenceLabel(_state), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (waiting > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: placeBrass.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                    child: Text('$waiting منتظر', style: const TextStyle(color: placeBrass, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('اختصارات العمل', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (Session.can('inbox.read'))
                  _ShortcutChip(
                    icon: Icons.chat_bubble_outline,
                    label: 'المحادثات',
                    count: _dash['unreadMessages'] ?? widget.badges['chats'] ?? 0,
                    onTap: () => widget.onNavigate(StaffTab.chats),
                  ),
                if (Session.can('bookings.read'))
                  _ShortcutChip(
                    icon: Icons.event_available_outlined,
                    label: 'حجوزات معلّقة',
                    count: (_dash['pendingBookings'] ?? 0) + (_dash['awaitingPayment'] ?? 0),
                    onTap: () => widget.onNavigate(StaffTab.bookings),
                  ),
                if (Session.can('cancellations.review') || Session.can('refunds.review'))
                  _ShortcutChip(
                    icon: Icons.rule_folder_outlined,
                    label: 'طلبات',
                    count: _dash['openRequests'] ?? widget.badges['requests'] ?? 0,
                    onTap: () => widget.onNavigate(StaffTab.requests),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                StatTile(label: 'في الانتظار', value: '$waiting', accent: waiting > 0 ? placeBrass : placeInk),
                const SizedBox(width: 10),
                StatTile(label: 'رسائل جديدة', value: '${_dash['unreadMessages'] ?? 0}', accent: placeSuccess),
              ],
            ),
          ),
          if (canAnswer) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('جاهزية المكالمات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PresenceCard(
                busy: _busy,
                state: _state,
                onAvailable: () => _setPresence('AVAILABLE'),
                onAway: () => _setPresence('AWAY'),
              ),
            ),
          ] else if (!canMonitor)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('استخدم المحادثات والحجوزات حسب صلاحياتك — لوحة المكالمات للخطوط الصوتية.', style: TextStyle(color: placeInk2)),
            ),
          if ((canAnswer || canMonitor) && _queue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('طابور الانتظار', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final raw in _queue.take(8))
              () {
                final map = Map<String, dynamic>.from(raw as Map);
                return _QueueTile(
                  row: map,
                  waitLabel: _fmtWait((map['waitedSeconds'] as num?)?.toInt() ?? 0),
                  onOpen: Session.can('inbox.read') ? () => _openQueueChat(map) : null,
                );
              }(),
          ],
          if ((canAnswer || canMonitor) && _recentCalls.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('آخر المكالمات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final raw in _recentCalls.take(6))
              Builder(
                builder: (context) {
                  final map = raw as Map;
                  final caller = map['caller'] as Map?;
                  final status = map['status']?.toString();
                  final created = map['createdAt']?.toString();
                  final time = created != null
                      ? DateFormat('HH:mm').format(DateTime.parse(created).toLocal())
                      : '';
                  final dur = map['durationSeconds'] as int?;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        status == 'MISSED' ? Icons.call_missed : Icons.call,
                        color: status == 'MISSED' ? placeDanger : placeSuccess,
                      ),
                      title: Text(
                        caller?['name']?.toString() ?? caller?['phone']?.toString() ?? 'مكالمة',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${map['place'] ?? ''} · ${_callStatusAr(status)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(time, style: const TextStyle(fontSize: 12, color: placeInk2)),
                          if (dur != null) Text(_fmtWait(dur), style: const TextStyle(fontSize: 11, color: placeInk2)),
                        ],
                      ),
                      onTap: Session.can('inbox.read') && caller?['id'] != null
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    contactUserId: caller!['id'].toString(),
                                    contactName: caller['name']?.toString() ?? 'زبون',
                                    contactPhone: caller['phone']?.toString(),
                                  ),
                                ),
                              )
                          : null,
                    ),
                  );
                },
              ),
          ],
          if (canMonitor && _supervisor != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('لوحة المشرف', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  StatTile(label: 'أُجيب اليوم', value: '${_supervisor!['answeredToday'] ?? 0}'),
                  const SizedBox(width: 10),
                  StatTile(label: 'فائت', value: '${_supervisor!['missedToday'] ?? 0}', accent: placeDanger),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StatTile(
                label: 'متوسط فقد الحزم',
                value: _supervisor!['avgPacketLoss'] == null ? '—' : '${(_supervisor!['avgPacketLoss'] as num).toStringAsFixed(1)}%',
              ),
            ),
            const SizedBox(height: 12),
            ..._buildAgentList(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAgentList() {
    final agents = (_supervisor?['agents'] as List<dynamic>? ?? []);
    if (agents.isEmpty) return [const EmptyState(title: 'لا يوجد موظفون متصلون')];
    return agents.map((row) {
      final map = row as Map;
      final state = map['state']?.toString() ?? 'OFFLINE';
      final name = map['user']?['name'] ?? map['user']?['phone'] ?? 'موظف';
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: ListTile(
          leading: PresenceDot(state: state),
          title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(presenceLabel(state)),
          trailing: state == 'AVAILABLE' ? const Icon(Icons.check_circle, color: placeSuccess) : null,
        ),
      );
    }).toList();
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.row, required this.waitLabel, this.onOpen});

  final Map row;
  final String waitLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final offered = row['state'] == 'OFFERED';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: offered ? placeBrass.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: placeInk.withValues(alpha: 0.1),
          child: const Icon(Icons.phone_in_talk, color: placeInk, size: 20),
        ),
        title: Text(row['callerName']?.toString() ?? 'زبون', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${row['place'] ?? ''} · ${row['callerPhone'] ?? ''}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(waitLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: placeBrass)),
            Text(offered ? 'يُعرض' : 'انتظار', style: const TextStyle(fontSize: 11, color: placeInk2)),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 52) / 2,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: placeLine), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon, color: placeInk),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: placeBrass.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, color: placeBrass)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresenceCard extends StatelessWidget {
  const _PresenceCard({required this.busy, required this.state, required this.onAvailable, required this.onAway});

  final bool busy;
  final String state;
  final VoidCallback onAvailable;
  final VoidCallback onAway;

  @override
  Widget build(BuildContext context) {
    final inCall = state == 'IN_CALL' || state == 'RINGING' || state == 'WRAP_UP';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AudioWaveBars(active: state == 'AVAILABLE' || inCall, color: placeBrass),
          const SizedBox(height: 16),
          Text(
            inCall
                ? (state == 'WRAP_UP' ? 'غلّف المكالمة ثم اضغط متاح' : 'أنت على الخط — لا يمكن تغيير الحالة الآن')
                : (state == 'AVAILABLE' ? 'أنت جاهز لاستقبال المكالمات' : 'اضغط «متاح» لاستقبال المكالمات'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: placeInk2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy || state == 'AVAILABLE' || (inCall && state != 'WRAP_UP') ? null : onAvailable,
            style: FilledButton.styleFrom(backgroundColor: placeSuccess),
            child: busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(state == 'WRAP_UP' ? 'العودة للمتاح' : 'متاح للعمل'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy || state == 'AWAY' || inCall ? null : onAway,
            child: const Text('استراحة'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () async {
              await StaffPermissions.openBatterySettings();
            },
            icon: const Icon(Icons.battery_charging_full, size: 18),
            label: const Text('تجاهل تحسين البطارية'),
          ),
        ],
      ),
    );
  }
}
