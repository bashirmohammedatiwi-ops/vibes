import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/shift.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';
import 'admin/bookings/booking_wizard.dart';
import 'admin/bookings/bookings_calendar.dart';
import 'admin/bookings/bookings_list.dart';
import 'admin/people/customers_screen.dart';
import 'admin/people/payments_screen.dart';
import 'admin/people/providers_screen.dart';
import 'admin/people/refunds_screen.dart';
import 'chat_room.dart';
import 'global_search.dart';
import 'ops/ops_properties.dart';

/// ═══════════════════════════════════════════════════════════
/// «اليوم» — الشاشة الرئيسية للموظف: جاهزية المكالمات، بحث شامل،
/// مؤشرات لحظية، «يحتاج انتباهك» (كل ما ينتظر قراراً)، اختصارات،
/// طابور الانتظار وآخر المكالمات، ولوحة المشرف.
/// ═══════════════════════════════════════════════════════════
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.onPresenceChanged, required this.onOpenInbox});

  final ValueChanged<String> onPresenceChanged;
  final VoidCallback onOpenInbox;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String _state = Session.presenceState;
  Map<String, int> _dash = {};
  Map<String, dynamic>? _supervisor;
  List<dynamic> _queue = [];
  List<dynamic> _recentCalls = [];
  bool _loaded = false;
  bool _busy = false;
  Timer? _timer;

  bool get _calls => Session.can('calls.answer') || Session.can('calls.monitor');

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _state = Session.presenceState;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final jobs = <Future<void>>[
      Api.map('/api/staff/dashboard').then((data) {
        final next = <String, int>{};
        for (final e in data.entries) {
          next[e.key] = (e.value as num?)?.toInt() ?? 0;
        }
        if (mounted) setState(() => _dash = next);
      }).catchError((_) {}),
    ];
    if (_calls) {
      jobs.add(Api.map('/api/staff/queue/waiting').then((q) {
        if (mounted) setState(() => _queue = q['items'] as List<dynamic>? ?? []);
      }).catchError((_) {}));
      jobs.add(Api.map('/api/staff/calls/recent').then((c) {
        if (mounted) setState(() => _recentCalls = c['items'] as List<dynamic>? ?? []);
      }).catchError((_) {}));
    }
    if (Session.can('calls.monitor')) {
      jobs.add(Api.map('/api/staff/supervisor').then((s) {
        if (mounted) setState(() => _supervisor = s);
      }).catchError((_) {}));
    }
    await Future.wait(jobs);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _setPresence(String state) async {
    if (_busy || state == _state) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      await Api.send('/api/staff/presence', method: 'POST', body: {'state': state, 'deviceId': Session.deviceId});
      if (!mounted) return;
      setState(() => _state = state);
      Session.me['presenceState'] = state;
      widget.onPresenceChanged(state);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _refresh();
  }

  void _openChat(Map caller) {
    final id = caller['id']?.toString() ?? caller['callerId']?.toString();
    if (id == null || !Session.can('inbox.read')) return;
    _open(ChatRoomScreen(
      contactUserId: id,
      contactName: (caller['name'] ?? caller['callerName'] ?? 'زبون').toString(),
      contactPhone: (caller['phone'] ?? caller['callerPhone'])?.toString(),
    ));
  }

  int _n(String k) => _dash[k] ?? 0;

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'صباح الخير' : (h < 18 ? 'نهارك سعيد' : 'مساء الخير');
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE d MMMM', 'ar').format(DateTime.now());
    final tasks = _tasks();
    final pendingTotal = tasks.fold<int>(0, (s, t) => s + (t.count ?? 0));

    return StaffPage(
      title: '$_greeting، ${Session.displayName.split(' ').first}',
      subtitle: date,
      showBack: false,
      onRefresh: _refresh,
      actions: [
        IconButton(
          tooltip: 'بحث',
          icon: const Icon(Icons.search_rounded),
          onPressed: () => _open(const GlobalSearchScreen()),
        ),
      ],
      slivers: [
        if (Session.can('calls.answer'))
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: _PresenceCard(
                state: _state,
                busy: _busy,
                waiting: _n('waiting'),
                onChanged: _setPresence,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Pad(
            top: Session.can('calls.answer') ? 0 : 4,
            child: SearchLauncher(
              hint: 'ابحث برقم هاتف، زبون، مكان، حوالة…',
              onTap: () => _open(const GlobalSearchScreen()),
            ),
          ),
        ),
        // ── مؤشرات لحظية ──
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 118, // ارتفاع ثابت — لا تجاوز مع خط Cairo الطويل
            ),
            delegate: SliverChildListDelegate([
              if (_calls)
                KpiTile(
                  label: 'مكالمات بالانتظار',
                  value: '${_n('waiting')}',
                  icon: Icons.phone_in_talk_rounded,
                  color: placeWarning,
                  alert: _n('waiting') > 0,
                ),
              if (Session.can('inbox.read'))
                KpiTile(
                  label: 'رسائل غير مقروءة',
                  value: '${_n('unreadMessages')}',
                  icon: Icons.forum_rounded,
                  color: placeInfo,
                  alert: _n('unreadMessages') > 0,
                  onTap: widget.onOpenInbox,
                ),
              if (Session.can('bookings.read'))
                KpiTile(
                  label: 'حجوزات اليوم',
                  value: '${_n('todayBookings')}',
                  icon: Icons.today_rounded,
                  color: placeSuccess,
                  onTap: () => _open(const BookingsCalendarScreen()),
                ),
              if (Session.can('bookings.read'))
                KpiTile(
                  label: 'بانتظار التأكيد',
                  value: '${_n('pendingBookings')}',
                  icon: Icons.hourglass_top_rounded,
                  color: placeBrass,
                  alert: _n('pendingBookings') > 0,
                  onTap: () => _open(const AdminBookingsListScreen(initialStatus: 'PENDING')),
                ),
            ]),
          ),
        ),
        // ── يحتاج انتباهك ──
        if (tasks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader('يحتاج انتباهك', subtitle: 'كل ما ينتظر قراراً منك الآن', count: pendingTotal),
          ),
          SliverToBoxAdapter(
            child: Pad(
              bottom: 0,
              child: pendingTotal == 0 && _loaded
                  ? StaffCard(
                      child: Row(
                        children: const [
                          IconBox(icon: Icons.task_alt_rounded, color: placeSuccess),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'كل شيء تحت السيطرة — لا مهام معلّقة',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TileGroup(children: tasks.where((t) => (t.count ?? 0) > 0).toList()),
            ),
          ),
        ],
        // ── اختصارات ──
        if (_shortcuts().isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('اختصارات')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 104,
              ),
              delegate: SliverChildListDelegate(_shortcuts()),
            ),
          ),
        ],
        // ── طابور الانتظار ──
        if (_calls && _queue.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader('طابور الانتظار', count: _queue.length)),
          SliverToBoxAdapter(
            child: Pad(
              child: TileGroup(
                children: [
                  for (final raw in _queue.take(8))
                    Builder(builder: (context) {
                      final m = Map<String, dynamic>.from(raw as Map);
                      final wait = (m['waitedSeconds'] as num?)?.toInt() ?? 0;
                      return TaskTile(
                        icon: Icons.ring_volume_rounded,
                        color: placeWarning,
                        title: m['callerName']?.toString() ?? 'زبون',
                        subtitle: [m['place'], m['callerPhone']].whereType<Object>().join(' · '),
                        trailing: StatusChip(_fmtWait(wait), color: wait > 60 ? placeDanger : placeWarning, dense: true),
                        onTap: Session.can('inbox.read') && m['callerId'] != null
                            ? () => _openChat({'id': m['callerId'], 'name': m['callerName'], 'phone': m['callerPhone']})
                            : null,
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
        // ── آخر المكالمات ──
        if (_calls && _recentCalls.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('آخر المكالمات')),
          SliverToBoxAdapter(
            child: Pad(
              child: TileGroup(
                children: [
                  for (final raw in _recentCalls.take(6))
                    Builder(builder: (context) {
                      final m = raw as Map;
                      final caller = (m['caller'] as Map?) ?? const {};
                      final missed = m['status']?.toString() == 'MISSED';
                      final created = DateTime.tryParse(m['createdAt']?.toString() ?? '')?.toLocal();
                      return TaskTile(
                        icon: missed ? Icons.call_missed_rounded : Icons.call_rounded,
                        color: missed ? placeDanger : placeSuccess,
                        title: (caller['name'] ?? caller['phone'] ?? 'مكالمة').toString(),
                        subtitle: [
                          m['place'],
                          missed ? 'فائتة' : _callStatus(m['status']?.toString()),
                          if (m['durationSeconds'] is int) _fmtWait(m['durationSeconds'] as int),
                        ].whereType<Object>().where((e) => '$e'.isNotEmpty).join(' · '),
                        trailing: Text(
                          created == null ? '' : DateFormat('HH:mm').format(created),
                          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk3),
                        ),
                        onTap: caller['id'] != null ? () => _openChat(caller) : null,
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
        // ── لوحة المشرف ──
        if (Session.can('calls.monitor') && _supervisor != null) ...[
          const SliverToBoxAdapter(child: SectionHeader('لوحة المشرف', subtitle: 'أداء الفريق اليوم')),
          SliverToBoxAdapter(
            child: Pad(
              child: Row(
                children: [
                  Expanded(child: KpiTile(label: 'أُجيبت اليوم', value: '${_supervisor!['answeredToday'] ?? 0}', icon: Icons.call_received_rounded, color: placeSuccess)),
                  const SizedBox(width: 10),
                  Expanded(child: KpiTile(label: 'فائتة اليوم', value: '${_supervisor!['missedToday'] ?? 0}', icon: Icons.call_missed_rounded, color: placeDanger, alert: ((_supervisor!['missedToday'] as num?) ?? 0) > 0)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: Pad(child: _AgentsList(agents: (_supervisor!['agents'] as List<dynamic>? ?? const [])))),
        ],
      ],
    );
  }

  List<TaskTile> _tasks() {
    final out = <TaskTile>[];
    if (Session.can('bookings.read')) {
      out.add(TaskTile(
        icon: Icons.event_note_rounded,
        color: placeBrass,
        title: 'حجوزات بانتظار التأكيد',
        subtitle: 'راجعها وأكّدها أو تواصل مع الزبون',
        count: _n('pendingBookings'),
        onTap: () => _open(const AdminBookingsListScreen(initialStatus: 'PENDING')),
      ));
      out.add(TaskTile(
        icon: Icons.payments_rounded,
        color: placeWarning,
        title: 'بانتظار الدفع',
        subtitle: 'حجوزات لم يصل إيصالها بعد',
        count: _n('awaitingPayment'),
        onTap: () => _open(const AdminBookingsListScreen(initialStatus: 'AWAITING_PAYMENT')),
      ));
    }
    if (Session.can('payments.read')) {
      out.add(TaskTile(
        icon: Icons.receipt_long_rounded,
        color: placeInfo,
        title: 'إيصالات دفع للمراجعة',
        subtitle: 'اعتمد أو ارفض الحوالات المرفوعة',
        count: _n('pendingPayments'),
        onTap: () => _open(const AdminPaymentsScreen(proofOnly: true)),
      ));
    }
    if (Session.can('refunds.review') || Session.can('cancellations.review')) {
      out.add(TaskTile(
        icon: Icons.assignment_return_rounded,
        color: placeDanger,
        title: 'طلبات إلغاء واسترداد',
        subtitle: 'قرارات تنتظر المراجعة',
        count: _n('openRequests'),
        onTap: () => _open(const AdminRefundsScreen()),
      ));
    }
    if (Session.can('properties.read')) {
      out.add(TaskTile(
        icon: Icons.home_work_rounded,
        color: placeShiftEvening,
        title: 'أماكن بانتظار الاعتماد',
        subtitle: 'راجع البيانات والصور قبل النشر',
        count: _n('pendingProperties'),
        onTap: () => _open(const OpsPropertiesScreen()),
      ));
    }
    if (Session.can('providers.read')) {
      out.add(TaskTile(
        icon: Icons.verified_user_rounded,
        color: placeSuccess,
        title: 'مزودون بانتظار التوثيق',
        subtitle: 'تحقق من الهوية والملكية',
        count: _n('pendingProviders'),
        onTap: () => _open(const AdminProvidersScreen()),
      ));
    }
    return out;
  }

  List<Widget> _shortcuts() => [
        if (Session.can('bookings.write'))
          QuickAction(icon: Icons.add_card_rounded, label: 'حجز جديد', color: placeBrass, onTap: () => _open(const NewBookingWizardScreen())),
        if (Session.can('bookings.read'))
          QuickAction(icon: Icons.calendar_month_rounded, label: 'التقويم', color: placeInk, onTap: () => _open(const BookingsCalendarScreen())),
        if (Session.can('users.read'))
          QuickAction(icon: Icons.person_search_rounded, label: 'الزبائن', color: placeInfo, onTap: () => _open(const AdminCustomersScreen())),
        if (Session.can('properties.read'))
          QuickAction(icon: Icons.villa_rounded, label: 'الأماكن', color: placeShiftEvening, onTap: () => _open(const OpsPropertiesScreen())),
      ];

  String _callStatus(String? s) => switch (s) {
        'RINGING' => 'يرنّ',
        'ACTIVE' => 'جارية',
        'ENDED' => 'منتهية',
        _ => s ?? '',
      };

  String _fmtWait(int seconds) {
    if (seconds < 60) return '$secondsث';
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// بطاقة الجاهزية: كحلية، حالة الموظف، ومبدّل «متاح / استراحة».
class _PresenceCard extends StatelessWidget {
  const _PresenceCard({required this.state, required this.busy, required this.waiting, required this.onChanged});

  final String state;
  final bool busy;
  final int waiting;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final available = state == 'AVAILABLE' || state == 'RINGING' || state == 'ON_CALL';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: placeNavyFill, borderRadius: BorderRadius.circular(StaffRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: available ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أنت ${presenceLabel(state)}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              if (waiting > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: placeGold, borderRadius: BorderRadius.circular(999)),
                  child: Text('$waiting بالانتظار', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w900, color: placeInk)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            available ? 'المكالمات الواردة تصلك الآن' : 'لن تصلك مكالمات حتى تعود متاحاً',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .7)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(StaffRadius.md)),
            child: Row(
              children: [
                _seg('متاح للمكالمات', Icons.headset_mic_rounded, available, () => onChanged('AVAILABLE')),
                _seg('استراحة', Icons.coffee_rounded, !available, () => onChanged('AWAY')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool on, VoidCallback tap) {
    return Expanded(
      child: GestureDetector(
        onTap: busy ? null : tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(StaffRadius.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: on ? placeInk : Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: on ? placeInk : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentsList extends StatelessWidget {
  const _AgentsList({required this.agents});

  final List<dynamic> agents;

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) {
      return const StaffCard(child: Text('لا يوجد موظفون متصلون الآن', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)));
    }
    return TileGroup(
      children: [
        for (final raw in agents)
          Builder(builder: (context) {
            final m = raw as Map;
            final state = m['state']?.toString() ?? 'OFFLINE';
            final name = (m['user']?['name'] ?? m['user']?['phone'] ?? 'موظف').toString();
            final color = switch (state) {
              'AVAILABLE' => placeSuccess,
              'ON_CALL' || 'RINGING' => placeInfo,
              'AWAY' => placeWarning,
              _ => placeInk3,
            };
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Avatar(name, size: 38),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk))),
                  StatusChip(presenceLabel(state), color: color, dense: true),
                ],
              ),
            );
          }),
      ],
    );
  }
}
