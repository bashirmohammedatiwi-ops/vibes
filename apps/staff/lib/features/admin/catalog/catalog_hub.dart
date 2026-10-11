import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'activity_screen.dart';
import 'admin_notifications_screen.dart';
import 'amenities_screen.dart';
import 'locations_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class _HubEntry {
  const _HubEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.requires,
    this.writeCode,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  /// صلاحية لازمة لظهور البطاقة (null = لكل الموظفين).
  final String? requires;

  /// صلاحية التعديل — بدونها تُعرض البطاقة "عرض فقط".
  final String? writeCode;

  bool get visible => requires == null || Session.can(requires!);
  bool get readOnly => writeCode != null && !Session.can(writeCode!);
}

final _entries = <_HubEntry>[
  _HubEntry(
    id: 'reports',
    title: 'التقارير',
    subtitle: 'إيراد، حجوزات، عوالم، أعلى الأماكن',
    icon: Icons.insights_rounded,
    requires: 'reports.read',
    builder: (_) => const ReportsScreen(),
  ),
  _HubEntry(
    id: 'notifications',
    title: 'إشعارات الإدارة',
    subtitle: 'تنبيهات الفريق وقراءتها',
    icon: Icons.notifications_active_outlined,
    requires: 'activity.read',
    builder: (_) => const AdminNotificationsScreen(),
  ),
  _HubEntry(
    id: 'activity',
    title: 'سجل النشاط',
    subtitle: 'كل إجراءات الفريق',
    icon: Icons.history_rounded,
    requires: 'activity.read',
    builder: (_) => const ActivityLogScreen(),
  ),
  _HubEntry(
    id: 'locations',
    title: 'المحافظات والمدن',
    subtitle: 'المواقع وصور المحافظات',
    icon: Icons.location_city_outlined,
    writeCode: 'locations.write',
    builder: (_) => const LocationsScreen(),
  ),
  _HubEntry(
    id: 'amenities',
    title: 'مزايا الأماكن',
    subtitle: 'الكتالوج حسب الفئة والنوع',
    icon: Icons.sell_outlined,
    writeCode: 'amenities.write',
    builder: (_) => const AmenitiesScreen(),
  ),
  _HubEntry(
    id: 'settings',
    title: 'إعدادات المنصة',
    subtitle: 'الدعم، الدفع، الشفتات، الصيانة',
    icon: Icons.tune_rounded,
    writeCode: 'settings.write',
    builder: (_) => const PlatformSettingsScreen(),
  ),
];

/// مدخل "الإعداد والتقارير": المواقع، المزايا، الإعدادات، التقارير، النشاط والإشعارات.
/// المواقع والمزايا والإعدادات ظاهرة لكل الموظفين (قراءة فقط بدون صلاحية التعديل)،
/// والتقارير تتطلب reports.read، والنشاط والإشعارات تتطلب activity.read.
class CatalogHubScreen extends StatefulWidget {
  const CatalogHubScreen({super.key, this.embedded = false});

  /// true عند عرضه داخل تبويب بدون AppBar خاص.
  final bool embedded;

  /// هل يظهر المدخل لهذا الموظف؟ (دائماً — أقسام القراءة متاحة للجميع)
  static bool get isVisible => true;

  @override
  State<CatalogHubScreen> createState() => _CatalogHubScreenState();
}

class _CatalogHubScreenState extends State<CatalogHubScreen> {
  int _unread = 0;
  bool _maintenance = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadUnread(), _loadSettingsFlag()]);
  }

  Future<void> _loadUnread() async {
    if (!Session.can('activity.read')) return;
    try {
      final data = await Api.map('/api/admin/notifications?pageSize=1&unread=true');
      final n = data['unreadCount'];
      if (mounted) setState(() => _unread = n is num ? n.toInt() : int.tryParse('$n') ?? 0);
    } catch (_) {}
  }

  Future<void> _loadSettingsFlag() async {
    try {
      final data = await Api.map('/api/admin/settings');
      if (mounted) setState(() => _maintenance = data['maintenanceMode'] == true);
    } catch (_) {}
  }

  Future<void> _open(_HubEntry e) async {
    lightTap();
    await Navigator.of(context).push(MaterialPageRoute(builder: e.builder));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) => e.visible).toList();
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (widget.embedded)
            const MaisonHeader(title: 'الإعداد والتقارير', subtitle: 'كتالوج المنصة وإعداداتها وتقاريرها'),
          if (_maintenance)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: placeDanger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(_entries.firstWhere((e) => e.id == 'settings')),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.construction_rounded, color: placeDanger, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'وضع الصيانة مفعّل — الحجز متوقف للعملاء',
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeDanger),
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: placeDanger),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.12,
              children: [
                for (final e in visible)
                  _HubTile(
                    entry: e,
                    badge: e.id == 'notifications' ? _unread : 0,
                    onTap: () => _open(e),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعداد والتقارير')),
      body: body,
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.entry, required this.onTap, this.badge = 0});

  final _HubEntry entry;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: placeLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: placeInk.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(entry.icon, color: placeInk, size: 22),
                  ),
                  const Spacer(),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: placeBrass, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else if (entry.readOnly)
                    const StatusPill(label: 'عرض فقط', color: placeInk2, icon: Icons.visibility_outlined),
                ],
              ),
              const Spacer(),
              Text(
                entry.title,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
              ),
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: placeInk2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
