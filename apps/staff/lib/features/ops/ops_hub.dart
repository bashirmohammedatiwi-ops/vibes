import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/office_nav.dart';
import '../../core/staff_capabilities.dart';
import '../../core/theme.dart';
import '../../widgets/kit.dart';
import '../admin/bookings/bookings_desk.dart';
import '../admin/catalog/catalog_hub.dart';
import '../admin/content/content_hub.dart';
import '../admin/people/people_hub.dart';
import '../global_search.dart';
import '../requests.dart';
import 'ops_dashboard.dart';
import 'ops_invoices.dart';
import 'ops_properties.dart';

/// ═══════════════════════════════════════════════════════════
/// «الإدارة» — تبويب رئيسي: بحث شامل، أرقام ما ينتظر، ثم الأقسام
/// مجمّعة (العمل اليومي / الأماكن والمحتوى / الإدارة والتقارير).
/// كل قسم يظهر حسب صلاحيات الموظف فقط (visibleOpsModules).
/// ═══════════════════════════════════════════════════════════
class OpsHubScreen extends StatefulWidget {
  const OpsHubScreen({super.key, this.onNavigate});

  final void Function(StaffTab tab)? onNavigate;

  @override
  State<OpsHubScreen> createState() => _OpsHubScreenState();
}

/// مجموعات العرض — ترتيب الوحدات داخل كل مجموعة.
const _groups = <(String, String, List<String>)>[
  ('العمل اليومي', 'ما يحتاج متابعة اليوم', ['desk', 'requests', 'dashboard']),
  ('الأماكن والمحتوى', 'ما يراه الزبون في التطبيق', ['properties', 'content']),
  ('الإدارة والتقارير', 'المال، الفواتير، الإعدادات والتقارير', ['people', 'invoices', 'catalog']),
];

class _OpsHubScreenState extends State<OpsHubScreen> {
  Map<String, dynamic> _stats = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.map('/api/staff/ops/overview');
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  int _n(String key) => (_stats[key] as num?)?.toInt() ?? 0;

  Future<void> _open(OpsModule mod) async {
    final Widget? page = switch (mod.id) {
      'desk' => const BookingsDeskScreen(),
      'people' => const PeopleMoneyHubScreen(),
      'content' => const ContentHubScreen(),
      'catalog' => const CatalogHubScreen(),
      'dashboard' => const OpsDashboardScreen(),
      'properties' => const OpsPropertiesScreen(),
      'invoices' => const OpsInvoicesScreen(),
      'requests' => Scaffold(
        appBar: AppBar(title: const Text('الطلبات')),
        body: const RequestsScreen(),
      ),
      _ => null,
    };
    if (page == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final modules = visibleOpsModules();
    final byId = {for (final m in modules) m.id: m};
    final placed = <String>{};
    final groups = <(String, String, List<OpsModule>)>[];
    for (final (title, sub, ids) in _groups) {
      final list = [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
      placed.addAll(list.map((m) => m.id));
      if (list.isNotEmpty) groups.add((title, sub, list));
    }
    // أي وحدة جديدة لم تُصنَّف بعد تظهر في «أخرى» حتى لا تختفي.
    final rest = modules.where((m) => !placed.contains(m.id)).toList();
    if (rest.isNotEmpty) groups.add(('أخرى', 'أدوات إضافية', rest));

    final has = byId.containsKey;
    final kpis = <Widget>[
      KpiTile(
        label: 'مكالمات بالانتظار',
        value: '${_n('waiting')}',
        icon: Icons.phone_in_talk_rounded,
        color: placeWarning,
        alert: _n('waiting') > 0,
        onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(StaffTab.now),
      ),
      KpiTile(
        label: 'حجوزات معلّقة',
        value: '${_n('pendingBookings')}',
        icon: Icons.event_note_rounded,
        color: placeBrass,
        alert: _n('pendingBookings') > 0,
        onTap: has('desk') ? () => _open(byId['desk']!) : null,
      ),
      KpiTile(
        label: 'دفع بانتظار التحقق',
        value: '${_n('pendingPayments')}',
        icon: Icons.receipt_long_rounded,
        color: placeInfo,
        alert: _n('pendingPayments') > 0,
        onTap: has('people') ? () => _open(byId['people']!) : null,
      ),
      KpiTile(
        label: 'أماكن بانتظار الاعتماد',
        value: '${_n('pendingProperties')}',
        icon: Icons.home_work_rounded,
        color: placeShiftEvening,
        alert: _n('pendingProperties') > 0,
        onTap: has('properties') ? () => _open(byId['properties']!) : null,
      ),
    ];
    final pendingTotal = modules.fold<int>(0, (s, m) => s + _badgeFor(m.id));

    return StaffPage(
      title: 'الإدارة',
      subtitle: pendingTotal > 0 ? '$pendingTotal عنصر بانتظار قرارك' : 'كل أدوات العمل في مكان واحد',
      showBack: false,
      onRefresh: _load,
      actions: [IconButton(tooltip: 'بحث', icon: const Icon(Icons.search_rounded), onPressed: _openSearch)],
      slivers: [
        SliverToBoxAdapter(
          child: Pad(
            top: 4,
            child: SearchLauncher(hint: 'ابحث برقم هاتف، زبون، مكان، حوالة…', onTap: _openSearch),
          ),
        ),
        // ── أرقام ما ينتظر ──
        if (!_loaded)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: List.generate(4, (_) => const SkeletonBox(height: double.infinity)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
            sliver: SliverGrid.count(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: kpis),
          ),
        // ── الأقسام المجمّعة ──
        for (final (title, sub, list) in groups) ...[
          SliverToBoxAdapter(
            child: SectionHeader(title, subtitle: sub, count: list.fold<int>(0, (s, m) => s + _badgeFor(m.id))),
          ),
          SliverToBoxAdapter(
            child: Pad(
              bottom: 0,
              child: TileGroup(
                children: [
                  for (final m in list)
                    TaskTile(
                      icon: _moduleIcon(m.icon),
                      title: m.title,
                      subtitle: m.subtitle,
                      color: _moduleColor(m.id),
                      count: _badgeFor(m.id),
                      onTap: () => _open(m),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (modules.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              title: 'لا توجد أقسام متاحة',
              subtitle: 'لم تُمنح صلاحيات إدارية بعد — تواصل مع المشرف.',
            ),
          ),
      ],
    );
  }

  int _badgeFor(String id) => switch (id) {
    'desk' => _n('pendingBookings') + _n('awaitingPayment'),
    'people' => _n('pendingPayments') + _n('pendingProviders') + _n('openRequests'),
    'properties' => _n('pendingProperties'),
    'requests' => _n('openRequests'),
    _ => 0,
  };
}

IconData _moduleIcon(String key) => switch (key) {
  'dashboard' => Icons.space_dashboard_rounded,
  'home_work' => Icons.villa_rounded,
  'event' => Icons.event_available_rounded,
  'people' => Icons.account_balance_wallet_rounded,
  'rule' => Icons.rule_rounded,
  'collections' => Icons.campaign_rounded,
  'tune' => Icons.tune_rounded,
  'receipt' => Icons.receipt_long_rounded,
  _ => Icons.apps_rounded,
};

Color _moduleColor(String id) => switch (id) {
  'desk' => placeInfo,
  'requests' => placeWarning,
  'dashboard' => placeNavyHigh,
  'people' => placeSuccess,
  'properties' => placeShiftEvening,
  'content' => const Color(0xFFBE185D),
  'invoices' => placeInk2,
  'catalog' => placeBrass,
  _ => placeInk,
};
