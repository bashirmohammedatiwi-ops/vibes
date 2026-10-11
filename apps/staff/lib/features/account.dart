import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/app_version.dart';
import '../core/permissions.dart';
import '../core/session.dart';
import '../core/shift.dart';
import '../core/staff_capabilities.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';
import 'login.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
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

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text('ستتوقف المكالمات والإشعارات على هذا الجهاز حتى تسجّل الدخول مجدداً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: placeDanger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (ok == true) await _logout();
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: Session.deviceId));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ معرّف الجهاز')));
  }

  @override
  Widget build(BuildContext context) {
    final phone = Session.me['phone']?.toString() ?? '';
    final perms = Session.permissions;
    return StaffPage(
      title: 'حسابي',
      subtitle: phone.isEmpty ? null : phone,
      showBack: false,
      onRefresh: _refreshMe,
      actions: [
        if (_refreshing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Pad(
            top: 4,
            child: _ProfileCard(phone: phone, permissionCount: perms.length),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader('الصلاحيات', subtitle: perms.isEmpty ? 'لم تُمنح صلاحيات بعد' : 'ما يمكنك فعله في التطبيق — يحدّدها المشرف'),
        ),
        SliverToBoxAdapter(
          child: Pad(bottom: 0, child: _PermissionGroups(permissions: perms)),
        ),
        const SliverToBoxAdapter(child: SectionHeader('الجهاز والتنبيهات', subtitle: 'لضمان وصول المكالمات والرسائل في الوقت المناسب')),
        SliverToBoxAdapter(
          child: Pad(
            bottom: 0,
            child: TileGroup(
              children: [
                const TaskTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'صلاحية الإشعارات',
                  subtitle: 'مطلوبة لرنين المكالمات',
                  color: placeInfo,
                  onTap: StaffPermissions.requestForCallCenter,
                ),
                const TaskTile(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'تجاهل تحسين البطارية',
                  subtitle: 'يبقي الرنين يعمل في الخلفية',
                  color: placeSuccess,
                  onTap: StaffPermissions.openBatterySettings,
                ),
                TaskTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'معرّف الجهاز',
                  subtitle: Session.deviceId,
                  color: placeInk2,
                  onTap: _copyDeviceId,
                  trailing: const Icon(Icons.copy_rounded, size: 20, color: placeInk3),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('حول التطبيق')),
        SliverToBoxAdapter(
          child: Pad(
            bottom: 0,
            child: TileGroup(
              children: [
                TaskTile(
                  icon: Icons.info_rounded,
                  title: 'إصدار التطبيق',
                  subtitle: '$staffAppVersionLabel · VIBES مكتب',
                  color: placeBrass,
                  trailing: const SizedBox.shrink(),
                ),
                const TaskTile(
                  icon: Icons.dns_rounded,
                  title: 'الخادم',
                  subtitle: apiBase,
                  color: placeNavyHigh,
                  trailing: SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Pad(
            top: 24,
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: placeDanger,
                  side: BorderSide(color: placeDanger.withValues(alpha: .35)),
                  backgroundColor: Colors.white,
                ),
                onPressed: _loggingOut ? null : _confirmLogout,
                icon: _loggingOut
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: placeDanger))
                    : const Icon(Icons.logout_rounded),
                label: const Text('خروج آمن'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// بطاقة الملف الشخصي: اسم، هاتف، حالة الحضور، وعدد الصلاحيات.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.phone, required this.permissionCount});

  final String phone;
  final int permissionCount;

  @override
  Widget build(BuildContext context) {
    final state = Session.presenceState;
    final color = presenceColor(state);
    final name = Session.displayName;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: placeNavyFill,
        borderRadius: BorderRadius.circular(StaffRadius.xl),
        boxShadow: const [BoxShadow(color: Color(0x290F1B2D), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(gradient: placeGoldFill, shape: BoxShape.circle),
                    child: Text(
                      name.trim().isNotEmpty ? name.trim().characters.first : 'م',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk, fontSize: 24, height: 1.2),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 1,
                    end: 1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: placeNavy, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 19, color: Colors.white),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderPill(icon: Icons.circle, iconColor: color, label: presenceLabel(state)),
              const SizedBox(width: 8),
              _HeaderPill(icon: Icons.verified_user_rounded, iconColor: placeGold, label: '$permissionCount صلاحية'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.iconColor, required this.label});

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 9 : 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// صلاحيات الموظف مجمّعة كما يعرّفها الخادم (المكالمات، الحجوزات، المال…).
class _PermissionGroups extends StatelessWidget {
  const _PermissionGroups({required this.permissions});

  final List<String> permissions;

  List<(String, List<String>)> _groups() {
    final catalog = Session.me['catalog'];
    final raw = catalog is Map ? catalog['groups'] : null;
    if (raw is! List || raw.isEmpty) return [('صلاحياتك', permissions)];
    final out = <(String, List<String>)>[];
    final seen = <String>{};
    for (final g in raw.whereType<Map>()) {
      final codes = (g['codes'] as List? ?? const []).map((e) => e.toString()).toList();
      final mine = codes.where(permissions.contains).toList();
      seen.addAll(codes);
      if (mine.isNotEmpty) out.add((g['label']?.toString() ?? '', mine));
    }
    final rest = permissions.where((c) => !seen.contains(c)).toList();
    if (rest.isNotEmpty) out.add(('أخرى', rest));
    return out;
  }

  static IconData _groupIcon(String label) {
    if (label.contains('مكالم')) return Icons.phone_in_talk_rounded;
    if (label.contains('محادث') || label.contains('رسائل')) return Icons.forum_rounded;
    if (label.contains('حجز') || label.contains('حجوز')) return Icons.event_available_rounded;
    if (label.contains('مال') || label.contains('دفع') || label.contains('مدفوع')) return Icons.account_balance_wallet_rounded;
    if (label.contains('أماكن') || label.contains('مكان')) return Icons.villa_rounded;
    if (label.contains('محتوى') || label.contains('تسويق')) return Icons.campaign_rounded;
    if (label.contains('زبائن') || label.contains('مزود')) return Icons.groups_rounded;
    if (label.contains('إعداد') || label.contains('تقارير')) return Icons.tune_rounded;
    return Icons.verified_user_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    if (permissions.isEmpty) {
      return StaffCard(
        child: Row(
          children: const [
            IconBox(icon: Icons.lock_outline_rounded, color: placeWarning),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'لا صلاحيات بعد — تواصل مع المدير',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final (label, codes) in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaffCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBox(icon: _groupIcon(label), color: placeBrass, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14.5, color: placeInk),
                        ),
                      ),
                      CountBadge(codes.length, color: placeBrass),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final code in codes)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: placePaper,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: placeLineSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, size: 14, color: placeSuccess),
                              const SizedBox(width: 4),
                              Text(
                                staffPermissionLabel(code),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
