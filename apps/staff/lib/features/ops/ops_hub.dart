import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/office_nav.dart';
import '../../core/session.dart';
import '../../core/staff_capabilities.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../admin/bookings/bookings_desk.dart';
import '../admin/catalog/catalog_hub.dart';
import '../admin/content/content_hub.dart';
import '../admin/people/people_hub.dart';
import '../global_search.dart';
import '../requests.dart';
import 'ops_dashboard.dart';
import 'ops_invoices.dart';
import 'ops_properties.dart';

class OpsHubScreen extends StatefulWidget {
  const OpsHubScreen({super.key, this.onNavigate});

  final void Function(StaffTab tab)? onNavigate;

  @override
  State<OpsHubScreen> createState() => _OpsHubScreenState();
}

class _OpsHubScreenState extends State<OpsHubScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Api.map('/api/staff/ops/overview');
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int _n(String key) => (_stats[key] as num?)?.toInt() ?? 0;

  Future<void> _open(OpsModule mod) async {
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final modules = visibleOpsModules();
    final sections = modules
        .where((m) => opsSectionIds.contains(m.id))
        .toList();
    final tools = modules.where((m) => !opsSectionIds.contains(m.id)).toList();
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'صباح الخير'
        : (hour < 18 ? 'نهارك سعيد' : 'مساء الخير');
    final stats = [
      ('انتظار مكالمة', _n('waiting'), Icons.phone_in_talk_rounded, placeBrass),
      (
        'حجوزات معلّقة',
        _n('pendingBookings'),
        Icons.event_note_rounded,
        placeInk,
      ),
      (
        'دفع معلّق',
        _n('pendingPayments'),
        Icons.receipt_long_rounded,
        placeShiftMorning,
      ),
      (
        'أماكن بانتظار',
        _n('pendingProperties'),
        Icons.home_work_rounded,
        placeShiftEvening,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MaisonHeader(
            title: 'مركز العمليات',
            subtitle: '$greet، ${Session.displayName}',
            trailing: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          // ── بحث شامل ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openSearch,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: placeLine),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: placeInk2),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ابحث برقم هاتف، زبون، مكان، حوالة…',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: placeInk2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── أرقام لحظية ──
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, value, icon, color) = stats[i];
                return _MiniStat(
                  label,
                  '$value',
                  color,
                  icon: icon,
                  alert: value > 0,
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (sections.isNotEmpty) ...[
            const _SectionTitle('أقسام العمل'),
            for (final mod in sections)
              _SectionCard(
                module: mod,
                badge: _badgeFor(mod.id),
                onTap: () => _open(mod),
              ),
          ],
          if (tools.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _SectionTitle('أدوات سريعة'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final (i, mod) in tools.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _OpsTile(
                        module: mod,
                        badge: _badgeFor(mod.id),
                        onTap: () => _open(mod),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _badgeFor(String id) => switch (id) {
    'desk' => _n('pendingBookings') + _n('awaitingPayment'),
    'people' =>
      _n('pendingPayments') + _n('pendingProviders') + _n('openRequests'),
    'properties' => _n('pendingProperties'),
    'requests' => _n('openRequests'),
    _ => 0,
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: placeInk,
        ),
      ),
    );
  }
}

IconData _moduleIcon(String key) => switch (key) {
  'dashboard' => Icons.space_dashboard_rounded,
  'home_work' => Icons.home_work_rounded,
  'event' => Icons.event_available_rounded,
  'people' => Icons.groups_rounded,
  'rule' => Icons.rule_rounded,
  'collections' => Icons.campaign_rounded,
  'tune' => Icons.tune_rounded,
  'receipt' => Icons.receipt_long_rounded,
  _ => Icons.apps_rounded,
};

Color _moduleColor(String id) => switch (id) {
  'desk' => placeInk,
  'people' => const Color(0xFF0F766E),
  'properties' => placeShiftEvening,
  'content' => const Color(0xFFBE185D),
  'catalog' => placeBrass,
  _ => placeInk,
};

/// بطاقة قسم كبرى: أيقونة ملوّنة، عنوان ووصف، وشارة بما ينتظر.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.module,
    required this.onTap,
    this.badge = 0,
  });
  final OpsModule module;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = _moduleColor(module.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: placeLine),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [color.withValues(alpha: .85), color],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _moduleIcon(module.icon),
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: placeInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        module.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: placeInk2,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: placeBrass,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_left_rounded, color: placeInk2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
    this.label,
    this.value,
    this.color, {
    required this.icon,
    this.alert = false,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: alert ? color.withValues(alpha: .07) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert ? color.withValues(alpha: .35) : placeLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: placeInk2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({required this.module, required this.onTap, this.badge = 0});
  final OpsModule module;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: placeLine),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                backgroundColor: placeBrass,
                child: Icon(
                  _moduleIcon(module.icon),
                  color: placeInk,
                  size: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: placeInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
