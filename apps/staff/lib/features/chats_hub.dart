import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/kit.dart';
import 'chat_room.dart';

/// ═══════════════════════════════════════════════════════════
/// «الوارد» — محادثات الزبائن (زبون واحد = صف واحد يجمع كل محادثاته)
/// مع بحث وفلاتر، و«المكالمات» (طابور الانتظار + آخر المكالمات) لمن
/// يملك صلاحية المكالمات.
/// ═══════════════════════════════════════════════════════════
class ChatsHubScreen extends StatefulWidget {
  const ChatsHubScreen({super.key});

  @override
  State<ChatsHubScreen> createState() => _ChatsHubScreenState();
}

enum _InboxMode { chats, calls }

class _ChatsHubScreenState extends State<ChatsHubScreen> {
  final _search = TextEditingController();
  List<dynamic> _contacts = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'all';
  Timer? _refresh;

  _InboxMode _mode = _InboxMode.chats;
  List<dynamic> _queue = [];
  List<dynamic> _recentCalls = [];
  bool _callsLoaded = false;

  bool get _canCalls => Session.can('calls.answer') || Session.can('calls.monitor');
  bool get _canLookup => Session.can('users.read');

  @override
  void initState() {
    super.initState();
    _load();
    if (_canCalls) _loadCalls();
    _refresh = Timer.periodic(const Duration(seconds: 12), (_) {
      _load(silent: true);
      if (_canCalls && _mode == _InboxMode.calls) _loadCalls();
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await Api.map('/api/staff/contacts');
      _contacts = data['items'] as List<dynamic>? ?? [];
      _error = null;
    } catch (e) {
      if (!silent) _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCalls() async {
    await Future.wait([
      Api.map('/api/staff/queue/waiting').then((q) {
        _queue = q['items'] as List<dynamic>? ?? [];
      }).catchError((_) {}),
      Api.map('/api/staff/calls/recent').then((c) {
        _recentCalls = c['items'] as List<dynamic>? ?? [];
      }).catchError((_) {}),
    ]);
    if (mounted) setState(() => _callsLoaded = true);
  }

  Future<void> _refreshAll() async {
    if (_mode == _InboxMode.calls) {
      await _loadCalls();
    } else {
      await _load();
    }
  }

  Future<void> _searchByPhone({String? initial}) async {
    final phone = await showStaffSheet<String>(
      context,
      title: 'محادثة جديدة برقم الهاتف',
      child: _PhoneLookupForm(initial: initial),
    );
    if (phone == null || phone.trim().isEmpty) return;
    try {
      final found = await Api.map('/api/staff/customers?phone=${Uri.encodeComponent(phone.trim())}');
      final user = found['user'];
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يُعثر على زبون بهذا الرقم')));
        return;
      }
      await _openContact(Map<String, dynamic>.from(user as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openContact(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          contactUserId: userId,
          contactName: user['name']?.toString() ?? user['phone']?.toString() ?? 'زبون',
          contactPhone: user['phone']?.toString(),
        ),
      ),
    );
    _load(silent: true);
  }

  // ── مساعدات القائمة ──
  static int _unreadOf(Map row) => (row['unread'] as num?)?.toInt() ?? 0;

  static bool _urgentOf(Map row) =>
      (row['conversations'] as List?)?.any((c) => (c as Map)['priority'] == 'URGENT') ?? false;

  static bool _closedOf(Map row) {
    final primary = row['primaryConversationId'];
    final convs = (row['conversations'] as List?) ?? const [];
    for (final c in convs) {
      final m = c as Map;
      if (m['id'] == primary) {
        final s = m['status']?.toString();
        return s == 'CLOSED' || s == 'RESOLVED';
      }
    }
    return false;
  }

  bool _matchesQuery(Map row) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final user = row['user'] as Map?;
    final name = user?['name']?.toString().toLowerCase() ?? '';
    final phone = user?['phone']?.toString() ?? '';
    return name.contains(q) || phone.contains(q);
  }

  List<Map> get _searched => _contacts.map((e) => e as Map).where(_matchesQuery).toList();

  List<Map> get _visible {
    return _searched.where((row) {
      if (_filter == 'unread' && _unreadOf(row) == 0) return false;
      if (_filter == 'urgent' && !_urgentOf(row)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalUnread = _contacts.fold<int>(0, (s, r) => s + _unreadOf(r as Map));
    final unreadChats = _contacts.where((r) => _unreadOf(r as Map) > 0).length;
    final subtitle = _mode == _InboxMode.calls
        ? (_queue.isEmpty ? 'لا أحد في الانتظار' : '${_queue.length} في طابور الانتظار')
        : (_loading && _contacts.isEmpty
            ? 'جارٍ التحميل…'
            : (totalUnread > 0 ? '${_contacts.length} زبون · $unreadChats بانتظار الرد' : '${_contacts.length} زبون · كل شيء مقروء'));

    return StaffPage(
      title: 'الوارد',
      subtitle: subtitle,
      showBack: false,
      onRefresh: _refreshAll,
      actions: [
        if (_canLookup)
          IconButton(
            tooltip: 'محادثة جديدة برقم الهاتف',
            onPressed: () => _searchByPhone(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
      ],
      floatingActionButton: _canLookup && _mode == _InboxMode.chats
          ? FloatingActionButton.extended(
              heroTag: 'inbox-new-chat',
              onPressed: () => _searchByPhone(),
              icon: const Icon(Icons.dialpad_rounded),
              label: const Text('محادثة برقم'),
            )
          : null,
      slivers: [
        if (_canCalls)
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: _InboxSegment(
                mode: _mode,
                chatsBadge: unreadChats,
                callsBadge: _queue.length,
                onChanged: (m) {
                  HapticFeedback.selectionClick();
                  setState(() => _mode = m);
                  if (m == _InboxMode.calls) _loadCalls();
                },
              ),
            ),
          ),
        if (_mode == _InboxMode.chats) ..._chatSlivers() else ..._callSlivers(),
        // مساحة لزر «محادثة برقم» العائم
        if (_canLookup && _mode == _InboxMode.chats) const SliverToBoxAdapter(child: SizedBox(height: 64)),
      ],
    );
  }

  // ═══════════════ المحادثات ═══════════════
  List<Widget> _chatSlivers() {
    final searched = _searched;
    final counts = {
      'all': searched.length,
      'unread': searched.where((r) => _unreadOf(r) > 0).length,
      'urgent': searched.where(_urgentOf).length,
    };
    final visible = _visible;

    return [
      SliverToBoxAdapter(
        child: Pad(
          top: _canCalls ? 0 : 4,
          bottom: 10,
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, color: placeInk),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو رقم الهاتف',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
            children: [
              for (final f in const ['all', 'unread', 'urgent']) ...[
                _FilterPill(
                  label: switch (f) {
                    'unread' => 'غير مقروءة',
                    'urgent' => 'عاجلة',
                    _ => 'الكل',
                  },
                  count: counts[f] ?? 0,
                  selected: _filter == f,
                  alertColor: f == 'urgent' ? placeDanger : (f == 'unread' ? placeSuccess : null),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = f);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (_loading && _contacts.isEmpty)
        const _ChatSkeletonSliver()
      else if (_error != null && _contacts.isEmpty)
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.cloud_off_rounded,
            title: 'تعذّر تحميل المحادثات',
            subtitle: _error,
            actionLabel: 'إعادة المحاولة',
            onAction: _load,
          ),
        )
      else if (visible.isEmpty)
        SliverToBoxAdapter(child: _emptyChats())
      else
        SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = visible[index];
            final user = Map<String, dynamic>.from(row['user'] as Map);
            final last = row['lastMessage'] as Map?;
            final isImage = last?['kind']?.toString() == 'IMAGE';
            var preview = last?['body']?.toString() ?? '';
            if (isImage && preview.isEmpty) preview = 'صورة';
            return Pad(
              bottom: 0,
              child: ChatListTile(
                name: user['name']?.toString() ?? user['phone']?.toString() ?? 'زبون',
                phone: user['phone']?.toString(),
                subtitle: row['propertyName']?.toString(),
                preview: preview,
                previewIcon: isImage ? Icons.photo_outlined : null,
                time: formatChatListTime(row['lastAt']?.toString()),
                unread: _unreadOf(row),
                urgent: _urgentOf(row),
                threads: (row['conversationCount'] as num?)?.toInt() ?? 0,
                closed: _closedOf(row),
                onTap: () => _openContact(user),
              ),
            );
          },
        ),
    ];
  }

  Widget _emptyChats() {
    if (_query.trim().isNotEmpty) {
      final looksLikePhone = RegExp(r'^[+\d\s-]{6,}$').hasMatch(_query.trim());
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: 'لا نتائج لـ «${_query.trim()}»',
        subtitle: looksLikePhone && _canLookup ? 'قد يكون زبوناً لم يراسلنا بعد — ابحث عنه في الزبائن' : 'جرّب اسماً آخر أو رقم الهاتف',
        actionLabel: looksLikePhone && _canLookup ? 'بدء محادثة مع الرقم' : null,
        onAction: looksLikePhone && _canLookup ? () => _searchByPhone(initial: _query.trim()) : null,
      );
    }
    return switch (_filter) {
      'unread' => EmptyView(
          icon: Icons.mark_chat_read_outlined,
          title: 'لا رسائل غير مقروءة',
          subtitle: 'أحسنت — كل المحادثات تمت قراءتها',
          actionLabel: 'عرض الكل',
          onAction: () => setState(() => _filter = 'all'),
        ),
      'urgent' => EmptyView(
          icon: Icons.outlined_flag_rounded,
          title: 'لا محادثات عاجلة',
          subtitle: 'المحادثات المعلّمة كعاجلة تظهر هنا',
          actionLabel: 'عرض الكل',
          onAction: () => setState(() => _filter = 'all'),
        ),
      _ => EmptyView(
          icon: Icons.forum_outlined,
          title: 'لا محادثات بعد',
          subtitle: 'ستظهر رسائل الزبائن هنا فور وصولها',
          actionLabel: _canLookup ? 'بدء محادثة برقم' : null,
          onAction: _canLookup ? () => _searchByPhone() : null,
        ),
    };
  }

  // ═══════════════ المكالمات ═══════════════
  void _openCaller({required String? id, required String? name, required String? phone}) {
    if (id == null || !Session.can('inbox.read')) return;
    _openContact({'id': id, 'name': name, 'phone': phone});
  }

  List<Widget> _callSlivers() {
    if (!_callsLoaded) return const [SkeletonSliver(count: 5, height: 68)];
    if (_queue.isEmpty && _recentCalls.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.phone_in_talk_outlined,
            title: 'لا مكالمات بعد',
            subtitle: 'المكالمات الواردة والصادرة تظهر هنا مع طابور الانتظار',
          ),
        ),
      ];
    }
    final meId = Session.me['id']?.toString();
    return [
      if (_queue.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader('طابور الانتظار', count: _queue.length, subtitle: 'زبائن ينتظرون الرد الآن')),
        SliverToBoxAdapter(
          child: Pad(
            child: TileGroup(
              children: [
                for (final raw in _queue)
                  Builder(builder: (context) {
                    final m = Map<String, dynamic>.from(raw as Map);
                    final wait = (m['waitedSeconds'] as num?)?.toInt() ?? 0;
                    return _CallRow(
                      name: m['callerName']?.toString() ?? 'زبون',
                      phone: m['callerPhone']?.toString(),
                      meta: m['place']?.toString(),
                      icon: Icons.ring_volume_rounded,
                      color: placeWarning,
                      trailing: StatusChip(_fmtSeconds(wait), color: wait > 60 ? placeDanger : placeWarning, dense: true),
                      onTap: () => _openCaller(
                        id: m['callerId']?.toString(),
                        name: m['callerName']?.toString(),
                        phone: m['callerPhone']?.toString(),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
      if (_recentCalls.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader('آخر المكالمات')),
        SliverToBoxAdapter(
          child: Pad(
            child: TileGroup(
              children: [
                for (final raw in _recentCalls)
                  Builder(builder: (context) {
                    final m = raw as Map;
                    final caller = (m['caller'] as Map?) ?? const {};
                    final callee = (m['callee'] as Map?) ?? const {};
                    final outgoing = caller['id']?.toString() == meId && callee.isNotEmpty;
                    final party = outgoing ? callee : caller;
                    final status = m['status']?.toString();
                    final missed = status == 'MISSED';
                    final created = DateTime.tryParse(m['createdAt']?.toString() ?? '')?.toLocal();
                    final duration = (m['durationSeconds'] as num?)?.toInt();
                    final meta = [
                      outgoing ? 'صادرة' : 'واردة',
                      if (missed) 'فائتة' else _callStatus(status),
                      if (duration != null && duration > 0) _fmtSeconds(duration),
                    ].where((e) => e.isNotEmpty).join(' · ');
                    return _CallRow(
                      name: (party['name'] ?? party['phone'] ?? 'مكالمة').toString(),
                      phone: party['phone']?.toString(),
                      meta: meta,
                      icon: missed
                          ? Icons.call_missed_rounded
                          : (outgoing ? Icons.call_made_rounded : Icons.call_received_rounded),
                      color: missed ? placeDanger : (status == 'ACTIVE' ? placeInfo : placeSuccess),
                      trailing: Text(
                        created == null ? '' : formatChatListTime(created.toIso8601String()),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk3),
                      ),
                      onTap: party['id'] == null
                          ? null
                          : () => _openCaller(
                                id: party['id']?.toString(),
                                name: party['name']?.toString(),
                                phone: party['phone']?.toString(),
                              ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  static String _callStatus(String? s) => switch (s) {
        'RINGING' => 'يرنّ',
        'ACTIVE' => 'جارية',
        'ENDED' => 'منتهية',
        'DECLINED' => 'مرفوضة',
        _ => '',
      };

  static String _fmtSeconds(int seconds) {
    if (seconds < 60) return '$secondsث';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return s == 0 ? '$mد' : '$mد $sث';
    return '${m ~/ 60}س ${m % 60}د';
  }
}

/// مبدّل «المحادثات | المكالمات».
class _InboxSegment extends StatelessWidget {
  const _InboxSegment({required this.mode, required this.onChanged, this.chatsBadge = 0, this.callsBadge = 0});

  final _InboxMode mode;
  final ValueChanged<_InboxMode> onChanged;
  final int chatsBadge;
  final int callsBadge;

  @override
  Widget build(BuildContext context) {
    Widget seg(_InboxMode m, IconData icon, String label, int badge, Color badgeColor) {
      final selected = mode == m;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(StaffRadius.sm),
              boxShadow: selected ? staffCardShadow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: selected ? placeInk : placeInk2),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? placeInk : placeInk2,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  CountBadge(badge, color: badgeColor),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: placeLineSoft, borderRadius: BorderRadius.circular(StaffRadius.md)),
      child: Row(
        children: [
          seg(_InboxMode.chats, Icons.forum_rounded, 'المحادثات', chatsBadge, placeSuccess),
          seg(_InboxMode.calls, Icons.call_rounded, 'المكالمات', callsBadge, placeWarning),
        ],
      ),
    );
  }
}

/// فلتر بشكل كبسولة مع عدّاد.
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.count, required this.selected, required this.onTap, this.alertColor});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? alertColor;

  @override
  Widget build(BuildContext context) {
    final countColor = selected ? Colors.white.withValues(alpha: .75) : (count > 0 && alertColor != null ? alertColor! : placeInk3);
    return Material(
      color: selected ? placeInk : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? placeInk : placeLine)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : placeInk),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w800, color: countColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف مكالمة (طابور / سجل).
class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.name,
    required this.icon,
    required this.color,
    this.phone,
    this.meta,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String? phone;
  final String? meta;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub = meta ?? '';
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ContactAvatar(name: name, phone: phone, size: 42),
                PositionedDirectional(
                  end: -3,
                  bottom: -3,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: Icon(icon, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk)),
                  if (sub.isNotEmpty)
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
                  if (phone != null && phone!.isNotEmpty)
                    Text(phone!, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11.5, fontWeight: FontWeight.w600, color: placeInk3)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// هيكل تحميل بشكل صفوف المحادثات.
class _ChatSkeletonSliver extends StatelessWidget {
  const _ChatSkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Pad(
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StaffRadius.lg),
            border: Border.all(color: placeLine),
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 50, height: 50, radius: 25),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14, radius: 6),
                    SizedBox(height: 10),
                    SkeletonBox(height: 12, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نموذج إدخال رقم الهاتف لبدء محادثة.
class _PhoneLookupForm extends StatefulWidget {
  const _PhoneLookupForm({this.initial});

  final String? initial;

  @override
  State<_PhoneLookupForm> createState() => _PhoneLookupFormState();
}

class _PhoneLookupFormState extends State<_PhoneLookupForm> {
  late final _c = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'أدخل رقم الزبون لفتح محادثته (أو بدء محادثة جديدة معه).',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, height: 1.5),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.search,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 17, fontWeight: FontWeight.w700, color: placeInk, letterSpacing: .5),
          decoration: const InputDecoration(
            hintText: '07XX XXX XXXX',
            prefixIcon: Icon(Icons.phone_rounded),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _c,
          builder: (context, v, _) => FilledButton.icon(
            onPressed: v.text.trim().isEmpty ? null : _submit,
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('بحث وفتح المحادثة'),
          ),
        ),
      ],
    );
  }
}
