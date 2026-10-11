import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/kit.dart';
import '../../../widgets/ui.dart' show lightTap;
import 'activity_screen.dart';
import 'admin_notifications_screen.dart';
import 'amenities_screen.dart';
import 'catalog_common.dart';
import 'locations_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class _HubEntry {
  const _HubEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    this.requires,
    this.writeCode,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
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
    color: placeSuccess,
    requires: 'reports.read',
    builder: (_) => const ReportsScreen(),
  ),
  _HubEntry(
    id: 'notifications',
    title: 'إشعارات الإدارة',
    subtitle: 'تنبيهات الفريق وقراءتها',
    icon: Icons.notifications_active_outlined,
    color: placeBrass,
    requires: 'activity.read',
    builder: (_) => const AdminNotificationsScreen(),
  ),
  _HubEntry(
    id: 'activity',
    title: 'سجل النشاط',
    subtitle: 'كل إجراءات الفريق',
    icon: Icons.history_rounded,
    color: placeInfo,
    requires: 'activity.read',
    builder: (_) => const ActivityLogScreen(),
  ),
  _HubEntry(
    id: 'locations',
    title: 'المحافظات والمدن',
    subtitle: 'المواقع وصور المحافظات',
    icon: Icons.location_city_outlined,
    color: placeShiftEvening,
    writeCode: 'locations.write',
    builder: (_) => const LocationsScreen(),
  ),
  _HubEntry(
    id: 'amenities',
    title: 'مزايا الأماكن',
    subtitle: 'الكتالوج حسب الفئة والنوع',
    icon: Icons.sell_outlined,
    color: placeBrass,
    writeCode: 'amenities.write',
    builder: (_) => const AmenitiesScreen(),
  ),
  _HubEntry(
    id: 'settings',
    title: 'إعدادات المنصة',
    subtitle: 'الدعم، الدفع، الشفتات، الصيانة',
    icon: Icons.tune_rounded,
    color: placeInk,
    writeCode: 'settings.write',
    builder: (_) => const PlatformSettingsScreen(),
  ),
];

const _groups = <(String, String?, List<String>)>[
  ('التحليلات والمتابعة', 'أرقام المنصة وحركة الفريق', ['reports', 'notifications', 'activity']),
  ('كتالوج المنصة', 'القوائم التي تظهر في نماذج الأماكن', ['locations', 'amenities']),
  ('الإعدادات', null, ['settings']),
];

/// مدخل "الإعداد والتقارير": المواقع، المزايا، الإعدادات، التقارير، النشاط والإشعارات.
/// المواقع والمزايا والإعدادات ظاهرة لكل الموظفين (قراءة فقط بدون صلاحية التعديل)،
/// والتقارير تتطلب reports.read، والنشاط والإشعارات تتطلب activity.read.
class CatalogHubScreen extends StatefulWidget {
  const CatalogHubScreen({super.key, this.embedded = false});

  /// true عند عرضه داخل تبويب بدون زر رجوع.
  final bool embedded;

  /// هل يظهر المدخل لهذا الموظف؟ (دائماً — أقسام القراءة متاحة للجميع)
  static bool get isVisible => true;

  @override
  State<CatalogHubScreen> createState() => _CatalogHubScreenState();
}

class _CatalogHubScreenState extends State<CatalogHubScreen> {
  int _unread = 0;
  bool _maintenance = false;
  Map<String, dynamic> _stats = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadUnread(), _loadSettingsFlag(), _loadStats()]);
    if (mounted) setState(() => _loaded = true);
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

  /// مؤشرات المنصة العامة (نفس مصدر شاشة التقارير) — لمن يملك reports.read فقط.
  Future<void> _loadStats() async {
    if (!Session.can('reports.read')) return;
    try {
      final data = await Api.map('/api/admin/dashboard/stats');
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
  }

  _HubEntry _entry(String id) => _entries.firstWhere((e) => e.id == id);

  Future<void> _open(_HubEntry e) async {
    lightTap();
    await Navigator.of(context).push(MaterialPageRoute(builder: e.builder));
    if (mounted) _refresh();
  }

  List<Widget> _kpis() {
    final tiles = <Widget>[];
    final notif = _entry('notifications');
    final reports = _entry('reports');
    final settings = _entry('settings');
    if (notif.visible) {
      tiles.add(KpiTile(
        label: 'إشعارات غير مقروءة',
        value: _loaded ? fmtCount(_unread) : '—',
        icon: Icons.notifications_active_outlined,
        color: placeBrass,
        alert: _unread > 0,
        onTap: () => _open(notif),
      ));
    }
    tiles.add(KpiTile(
      label: 'وضع الصيانة',
      value: !_loaded ? '—' : (_maintenance ? 'مفعّل' : 'متوقف'),
      icon: Icons.construction_rounded,
      color: _maintenance ? placeDanger : placeSuccess,
      alert: _maintenance,
      onTap: () => _open(settings),
    ));
    if (reports.visible && _stats.isNotEmpty) {
      tiles.add(KpiTile(
        label: 'حجوزات هذا الشهر',
        value: fmtCount(_stats['monthlyBookings']),
        icon: Icons.event_available_outlined,
        color: placeInfo,
        onTap: () => _open(reports),
      ));
      tiles.add(KpiTile(
        label: 'إجمالي الإيراد',
        value: fmtCompact(asNum(_stats['totalRevenue'])),
        icon: Icons.payments_outlined,
        color: placeSuccess,
        onTap: () => _open(reports),
      ));
    }
    return tiles;
  }

  Widget _tile(_HubEntry e) {
    final count = e.id == 'notifications' ? _unread : 0;
    Widget? trailing;
    if (count == 0) {
      if (e.id == 'settings' && _maintenance) {
        trailing = const StatusChip('صيانة', color: placeDanger, dense: true);
      } else if (e.readOnly) {
        trailing = const StatusChip('عرض فقط', color: placeInk2, dense: true);
      }
    }
    return TaskTile(
      icon: e.icon,
      title: e.title,
      subtitle: e.subtitle,
      color: e.color,
      count: count,
      trailing: trailing,
      onTap: () => _open(e),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _kpis();
    return StaffPage(
      title: 'الإعداد والتقارير',
      subtitle: 'كتالوج المنصة وإعداداتها وتقاريرها',
      showBack: widget.embedded ? false : null,
      onRefresh: _refresh,
      slivers: [
        if (_maintenance)
          SliverToBoxAdapter(
            child: CatalogAlertBanner(
              text: 'وضع الصيانة مفعّل — الحجز متوقف للعملاء',
              icon: Icons.construction_rounded,
              onTap: () => _open(_entry('settings')),
            ),
          ),
        if (kpis.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 118,
              ),
              delegate: SliverChildListDelegate(kpis),
            ),
          ),
        for (final (title, subtitle, ids) in _groups)
          ...() {
            final entries = [for (final id in ids) _entry(id)].where((e) => e.visible).toList();
            if (entries.isEmpty) return const <Widget>[];
            final pending = entries.fold<int>(0, (s, e) => s + (e.id == 'notifications' ? _unread : 0));
            return <Widget>[
              SliverToBoxAdapter(child: SectionHeader(title, subtitle: subtitle, count: pending)),
              SliverToBoxAdapter(child: Pad(child: TileGroup(children: [for (final e in entries) _tile(e)]))),
            ];
          }(),
      ],
    );
  }
}
