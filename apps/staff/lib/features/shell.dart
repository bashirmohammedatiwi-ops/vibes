import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/connectivity.dart';
import '../core/office_nav.dart';
import '../core/session.dart';
import '../core/staff_notifications.dart';
import '../core/theme.dart';
import '../core/staff_capabilities.dart';
import 'account.dart';
import 'calls.dart';
import 'chat_room.dart';
import 'chats_hub.dart';
import 'today.dart';
import 'admin/bookings/bookings_desk.dart';
import 'ops/ops_hub.dart';

class OfficeShell extends StatefulWidget {
  const OfficeShell({super.key});

  @override
  State<OfficeShell> createState() => _OfficeShellState();
}

class _OfficeShellState extends State<OfficeShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _heartbeat;
  Timer? _ring;
  Timer? _metrics;
  Timer? _session;
  Map<String, dynamic>? _incoming;
  String? _banner;
  Map<String, int> _badges = {};
  int _lastUnread = 0;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  void goTo(StaffTab tab) => setState(() => _index = staffTabIndex(tab));

  void _openIncomingChat() {
    final call = _incoming;
    if (call == null) return;
    final userId = call['callerId']?.toString();
    final name = call['callerName']?.toString() ?? 'زبون';
    final phone = call['callerPhone']?.toString();
    StaffNotifications.cancelIncomingCall();
    setState(() => _incoming = null);
    if (userId == null || !Session.can('inbox.read')) return;
    goTo(StaffTab.chats);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            contactUserId: userId,
            contactName: name,
            contactPhone: phone,
          ),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _beat());
    _ring = Timer.periodic(const Duration(seconds: 2), (_) => _look());
    _metrics = Timer.periodic(const Duration(seconds: 25), (_) => _loadBadges());
    // الصلاحيات تُعدَّل من لوحة التحكم — نلتقطها خلال دقيقة دون إعادة دخول
    _session = Timer.periodic(const Duration(seconds: 60), (_) => _refreshSession());
    _beat();
    _loadBadges();
    // iOS: إذن الإشعارات بعد الدخول (لرنين المكالمات وتنبيهات الرسائل)
    StaffNotifications.requestIosPermission().catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      StaffNotifications.cancelIncomingCall();
      _look();
      _refreshSession();
    }
  }

  Future<void> _loadBadges() async {
    try {
      final data = await Api.map('/api/staff/dashboard');
      if (!mounted) return;
      final unread = (data['unreadMessages'] as num?)?.toInt() ?? 0;
      final chatsTab = staffTabIndex(StaffTab.chats);
      final onChats = _index == chatsTab && Session.can('inbox.read');
      if (unread > _lastUnread && !onChats && _lifecycle != AppLifecycleState.resumed) {
        await StaffNotifications.showNewMessage(
          title: 'رسائل جديدة',
          body: 'لديك $unread رسالة غير مقروءة',
        );
      } else if (unread > _lastUnread && !onChats && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('رسالة جديدة · $unread غير مقروء'),
            action: SnackBarAction(label: 'فتح', onPressed: () => goTo(StaffTab.chats)),
          ),
        );
      }
      _lastUnread = unread;
      setState(() {
        _badges = {
          'chats': unread,
          'bookings': ((data['pendingBookings'] as num?)?.toInt() ?? 0) + ((data['awaitingPayment'] as num?)?.toInt() ?? 0),
          'requests': (data['openRequests'] as num?)?.toInt() ?? 0,
          'waiting': (data['waiting'] as num?)?.toInt() ?? 0,
          'pendingProperties': (data['pendingProperties'] as num?)?.toInt() ?? 0,
          'pendingPayments': (data['pendingPayments'] as num?)?.toInt() ?? 0,
        };
      });
    } catch (_) {}
  }

  Future<void> _refreshSession() async {
    try {
      final before = Session.permissions.toSet();
      Session.applyMe(await Api.map('/api/staff/me'));
      if (!mounted) return;
      final after = Session.permissions.toSet();
      final changed = before.length != after.length || !before.containsAll(after);
      setState(() {
        // الأقسام الظاهرة قد تتغير مع الصلاحيات — لا نتجاوز آخر تبويب
        final count = visibleStaffTabs().length;
        if (_index >= count) _index = count - 1;
      });
      if (changed && before.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدّث المدير صلاحياتك — الأقسام محدّثة الآن')),
        );
      }
    } catch (_) {}
  }

  Future<void> _beat() async {
    await Session.keepAlive();
    try {
      final data = await Api.map('/api/staff/presence/heartbeat', method: 'POST', body: {'deviceId': Session.deviceId});
      final state = data['state']?.toString();
      if (state != null) {
        Session.me['presenceState'] = state;
        if (mounted) setState(() {});
      }
      if (data['takenOver'] == true && mounted) {
        setState(() => _banner = 'تم تسجيل الدخول من جهاز آخر — قد لا تصلك المكالمات هنا');
      }
    } catch (_) {}
  }

  Future<void> _look() async {
    if (!Session.can('calls.answer') || _incoming != null) return;
    try {
      final data = await Api.map('/api/staff/calls/ringing');
      final call = data['call'];
      if (call is Map && mounted) {
        final map = Map<String, dynamic>.from(call);
        final isNew = _incoming == null || _incoming?['id']?.toString() != map['id']?.toString();
        setState(() => _incoming = map);
        if (isNew || _lifecycle != AppLifecycleState.resumed) {
          await StaffNotifications.showIncomingCall(
            callerName: map['callerName']?.toString() ?? 'زبون',
            place: map['place']?.toString(),
          );
        }
      } else if (_incoming == null) {
        await StaffNotifications.cancelIncomingCall();
      }
    } catch (_) {}
  }

  void _onPresenceChanged(String state) {
    Session.me['presenceState'] = state;
    setState(() {});
  }

  void _dismissIncoming() {
    StaffNotifications.cancelIncomingCall();
    setState(() => _incoming = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _ring?.cancel();
    _metrics?.cancel();
    _session?.cancel();
    super.dispose();
  }

  Widget _badgeIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opsBadge = (_badges['requests'] ?? 0) +
        (_badges['pendingProperties'] ?? 0) +
        (_badges['pendingPayments'] ?? 0);
    final pages = <Widget>[
      TodayScreen(onPresenceChanged: _onPresenceChanged, onOpenInbox: () => goTo(StaffTab.chats)),
      if (Session.can('inbox.read')) const ChatsHubScreen(),
      if (Session.can('bookings.read') || Session.can('bookings.write')) const BookingsDeskScreen(),
      if (hasOpsAccess) OpsHubScreen(onNavigate: goTo),
      const AccountScreen(),
    ];
    final todayBadge = (_badges['waiting'] ?? 0);
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: _badgeIcon(Icons.space_dashboard_outlined, todayBadge),
        selectedIcon: _badgeIcon(Icons.space_dashboard_rounded, todayBadge),
        label: 'اليوم',
      ),
      if (Session.can('inbox.read'))
        NavigationDestination(
          icon: _badgeIcon(Icons.forum_outlined, _badges['chats'] ?? 0),
          selectedIcon: _badgeIcon(Icons.forum_rounded, _badges['chats'] ?? 0),
          label: 'الوارد',
        ),
      if (Session.can('bookings.read') || Session.can('bookings.write'))
        NavigationDestination(
          icon: _badgeIcon(Icons.event_note_outlined, _badges['bookings'] ?? 0),
          selectedIcon: _badgeIcon(Icons.event_note_rounded, _badges['bookings'] ?? 0),
          label: 'الحجوزات',
        ),
      if (hasOpsAccess)
        NavigationDestination(
          icon: _badgeIcon(Icons.grid_view_outlined, opsBadge),
          selectedIcon: _badgeIcon(Icons.grid_view_rounded, opsBadge),
          label: 'الإدارة',
        ),
      const NavigationDestination(
        icon: Icon(Icons.account_circle_outlined),
        selectedIcon: Icon(Icons.account_circle_rounded),
        label: 'حسابي',
      ),
    ];
    final safeIndex = _index.clamp(0, pages.length - 1);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Scaffold(
            body: ConnectivityBanner(
              child: Column(
                children: [
                  if (_banner != null)
                    MaterialBanner(
                      content: Text(_banner!),
                      leading: const Icon(Icons.warning_amber_rounded, color: placeBrass),
                      actions: [TextButton(onPressed: () => setState(() => _banner = null), child: const Text('إخفاء'))],
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: safeIndex,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: placeLine))),
              child: NavigationBar(
                selectedIndex: safeIndex,
                onDestinationSelected: (value) {
                  if (value != safeIndex) HapticFeedback.selectionClick();
                  setState(() => _index = value);
                },
                destinations: destinations,
              ),
            ),
          ),
          if (_incoming != null)
            IncomingCallOverlay(
              call: _incoming!,
              onDismiss: _dismissIncoming,
              onOpenChat: Session.can('inbox.read') ? _openIncomingChat : null,
            ),
        ],
      ),
    );
  }
}
