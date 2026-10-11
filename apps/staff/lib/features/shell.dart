import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/connectivity.dart';
import '../core/office_nav.dart';
import '../core/session.dart';
import '../core/staff_notifications.dart';
import '../core/theme.dart';
import '../core/staff_capabilities.dart';
import 'account.dart';
import 'bookings.dart';
import 'calls.dart';
import 'chat_room.dart';
import 'chats_hub.dart';
import 'now.dart';
import 'ops/ops_hub.dart';
import 'requests.dart';

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
    _beat();
    _loadBadges();
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
      Session.applyMe(await Api.map('/api/staff/me'));
      if (mounted) setState(() {});
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
    final opsBadge = (_badges['bookings'] ?? 0) +
        (_badges['requests'] ?? 0) +
        (_badges['pendingProperties'] ?? 0) +
        (_badges['pendingPayments'] ?? 0);
    final pages = <Widget>[
      NowScreen(onPresenceChanged: _onPresenceChanged, onNavigate: goTo, badges: _badges),
      if (Session.can('inbox.read')) const ChatsHubScreen(),
      if (Session.can('bookings.read')) const BookingsScreen(),
      if (hasOpsAccess) OpsHubScreen(onNavigate: goTo),
      if (Session.can('cancellations.review') || Session.can('refunds.review')) const RequestsScreen(),
      const AccountScreen(),
    ];
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: _badgeIcon(Icons.headset_mic_outlined, _badges['waiting'] ?? 0),
        selectedIcon: _badgeIcon(Icons.headset_mic, _badges['waiting'] ?? 0),
        label: 'الآن',
      ),
      if (Session.can('inbox.read'))
        NavigationDestination(
          icon: _badgeIcon(Icons.chat_bubble_outline, _badges['chats'] ?? 0),
          selectedIcon: _badgeIcon(Icons.chat_bubble, _badges['chats'] ?? 0),
          label: 'محادثات',
        ),
      if (Session.can('bookings.read'))
        NavigationDestination(
          icon: _badgeIcon(Icons.event_available_outlined, _badges['bookings'] ?? 0),
          selectedIcon: _badgeIcon(Icons.event_available, _badges['bookings'] ?? 0),
          label: 'الحجوزات',
        ),
      if (hasOpsAccess)
        NavigationDestination(
          icon: _badgeIcon(Icons.dashboard_customize_outlined, opsBadge),
          selectedIcon: _badgeIcon(Icons.dashboard_customize, opsBadge),
          label: 'عمليات',
        ),
      if (Session.can('cancellations.review') || Session.can('refunds.review'))
        NavigationDestination(
          icon: _badgeIcon(Icons.rule_outlined, _badges['requests'] ?? 0),
          selectedIcon: _badgeIcon(Icons.rule, _badges['requests'] ?? 0),
          label: 'الطلبات',
        ),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
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
            bottomNavigationBar: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: destinations,
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
