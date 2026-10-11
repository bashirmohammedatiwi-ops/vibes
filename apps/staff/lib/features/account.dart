import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/app_version.dart';
import '../core/permissions.dart';
import '../core/session.dart';
import '../core/shift.dart';
import '../core/staff_capabilities.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'login.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _permissionLabels = staffPermissionLabels;

  bool _refreshing = false;
  bool _loggingOut = false;
  Future<void> _refreshMe() async {
    setState(() => _refreshing = true);
    try {
      Session.applyMe(await Api.map('/api/staff/me'));
    } catch (_) {}
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await Api.send('/api/staff/presence', method: 'POST', body: {'state': 'AWAY', 'deviceId': Session.deviceId});
    } catch (_) {}
    try {
      if (Session.refreshToken != null && Session.refreshToken!.isNotEmpty) {
        await Api.send('/api/auth/logout', method: 'POST', body: {'refreshToken': Session.refreshToken});
      }
    } catch (_) {}
    await Session.clear(notify: false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshMe,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MaisonHeader(
            title: 'حسابي',
            subtitle: Session.me['phone']?.toString() ?? '',
            trailing: _refreshing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: placeBrass.withValues(alpha: 0.15),
                      child: Text(
                        Session.displayName.isNotEmpty ? Session.displayName.characters.first : 'م',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: placeBrass, fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Session.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              PresenceDot(state: Session.presenceState),
                              const SizedBox(width: 6),
                              Text(presenceLabel(Session.presenceState), style: const TextStyle(color: placeInk2)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('الصلاحيات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in Session.permissions)
                  Chip(
                    label: Text(_permissionLabels[code] ?? code),
                    backgroundColor: placePaper,
                    side: const BorderSide(color: placeLine),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('الجهاز والتنبيهات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('صلاحية الإشعارات'),
                    subtitle: const Text('مطلوبة لرنين المكالمات'),
                    onTap: () => StaffPermissions.requestForCallCenter(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.battery_charging_full_outlined),
                    title: const Text('تجاهل تحسين البطارية'),
                    subtitle: const Text('يبقي الرنين يعمل في الخلفية'),
                    onTap: () => StaffPermissions.openBatterySettings(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('معرّف الجهاز'),
                    subtitle: Text(Session.deviceId, style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: Session.deviceId));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('إصدار التطبيق'),
                    subtitle: Text('$staffAppVersionLabel · VIBES مكتب'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('الخادم'),
                    subtitle: Text(apiBase, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton(
              onPressed: _loggingOut ? null : _logout,
              child: _loggingOut
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('خروج آمن'),
            ),
          ),
        ],
      ),
    );
  }
}
