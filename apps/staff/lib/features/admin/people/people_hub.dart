import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/kit.dart';
import 'customers_screen.dart';
import 'disputes_screen.dart';
import 'link_place_screen.dart';
import 'payments_screen.dart';
import 'people_common.dart';
import 'place_claims_screen.dart';
import 'providers_screen.dart';
import 'refunds_screen.dart';

class _HubEntry {
  const _HubEntry({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.anyOf,
    required this.builder,
    this.accent = placeInk,
    this.kpiLabel,
  });
  final String id;

  /// 'people' أو 'money'.
  final String group;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> anyOf;
  final Widget Function() builder;
  final Color accent;

  /// عنوان مؤشر الانتظار (إن كان للوحدة عدّاد معلّق).
  final String? kpiLabel;

  bool get visible => anyOf.any(Session.can);
}

final _entries = <_HubEntry>[
  _HubEntry(
    id: 'customers',
    group: 'people',
    title: 'الزبائن',
    subtitle: 'بحث، ملف، تعديل الاسم، إيقاف',
    icon: Icons.people_alt_rounded,
    anyOf: const ['users.read'],
    builder: () => const AdminCustomersScreen(),
    accent: placeInfo,
  ),
  _HubEntry(
    id: 'providers',
    group: 'people',
    title: 'المزودون',
    subtitle: 'توثيق، رفض، إلغاء توثيق',
    icon: Icons.storefront_rounded,
    anyOf: const ['providers.read'],
    builder: () => const AdminProvidersScreen(),
    accent: placeSuccess,
    kpiLabel: 'مزودون بانتظار التوثيق',
  ),
  _HubEntry(
    id: 'claims',
    group: 'people',
    title: 'طلبات الربط',
    subtitle: 'أصحاب أماكن يطلبون ربطها',
    icon: Icons.how_to_reg_rounded,
    anyOf: const ['providers.read'],
    builder: () => const PlaceClaimsScreen(),
    accent: placeBrass,
    kpiLabel: 'طلبات ربط معلّقة',
  ),
  _HubEntry(
    id: 'link',
    group: 'people',
    title: 'ربط مكان',
    subtitle: 'ربط مكان بحساب مزود',
    icon: Icons.add_link_rounded,
    anyOf: const ['providers.link'],
    builder: () => const LinkPlaceScreen(),
    accent: placeShiftEvening,
  ),
  _HubEntry(
    id: 'payments',
    group: 'money',
    title: 'المدفوعات',
    subtitle: 'إثباتات، اعتماد، استرداد',
    icon: Icons.payments_rounded,
    anyOf: const ['payments.read'],
    builder: () => const AdminPaymentsScreen(),
    accent: placeInfo,
    kpiLabel: 'إثباتات دفع للمراجعة',
  ),
  _HubEntry(
    id: 'refunds',
    group: 'money',
    title: 'الاسترداد والإلغاء',
    subtitle: 'طلبات الزبائن مع سياق الدفع',
    icon: Icons.currency_exchange_rounded,
    anyOf: const ['refunds.review'],
    builder: () => const AdminRefundsScreen(),
    accent: placeWarning,
    kpiLabel: 'طلبات استرداد',
  ),
  _HubEntry(
    id: 'disputes',
    group: 'money',
    title: 'النزاعات',
    subtitle: 'فتح نزاع وحلّه',
    icon: Icons.gavel_rounded,
    anyOf: const ['disputes.review'],
    builder: () => const AdminDisputesScreen(),
    accent: placeDanger,
    kpiLabel: 'نزاعات مفتوحة',
  ),
];

/// مدخل «الناس والمال»: الزبائن، المزودون، طلبات الربط، المدفوعات، الاسترداد، النزاعات.
/// يظهر فقط إذا امتلك الموظف أيّاً من [PeopleMoneyHubScreen.permissionCodes].
class PeopleMoneyHubScreen extends StatefulWidget {
  const PeopleMoneyHubScreen({super.key, this.embedded = false});

  /// true عند تضمينه داخل شاشة لها Scaffold مسبقاً.
  final bool embedded;

  /// أي صلاحية من هذه تكفي لإظهار المدخل.
  static const permissionCodes = <String>[
    'users.read',
    'users.write',
    'providers.read',
    'providers.link',
    'payments.read',
    'payments.verify',
    'payments.refund',
    'refunds.review',
    'cancellations.review',
    'disputes.review',
  ];

  static bool get isVisible => _entries.any((e) => e.visible);

  @override
  State<PeopleMoneyHubScreen> createState() => _PeopleMoneyHubScreenState();
}

class _PeopleMoneyHubScreenState extends State<PeopleMoneyHubScreen> {
  final Map<String, int> _badges = {};
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int?> _count(String path, {String field = 'total'}) async {
    try {
      final data = await Api.send(path);
      if (data is List) return data.length;
      return asInt(asMap(data)[field]);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final jobs = <String, Future<int?>>{
      if (Session.can('providers.read')) 'providers': _count('/api/admin/providers?kyc=pending&pageSize=1'),
      if (Session.can('providers.read')) 'claims': _count('/api/admin/providers/claims?status=PENDING'),
      if (Session.can('payments.read')) 'payments': _count('/api/admin/payments?pageSize=1', field: 'pendingProof'),
      if (Session.can('refunds.review')) 'refunds': _count('/api/admin/refunds?status=PENDING&pageSize=1'),
      if (Session.can('disputes.review') && Session.can('bookings.read'))
        'disputes': _count('/api/admin/bookings?status=DISPUTED&pageSize=1'),
    };
    final results = await Future.wait(jobs.values);
    if (!mounted) return;
    setState(() {
      final keys = jobs.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        final v = results[i];
        if (v != null) _badges[keys[i]] = v;
      }
      _loading = false;
      _loaded = true;
    });
  }

  Future<void> _open(_HubEntry e) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => e.builder()));
    if (mounted) _load();
  }

  TaskTile _tile(_HubEntry e) => TaskTile(
        icon: e.icon,
        color: e.accent,
        title: e.title,
        subtitle: e.subtitle,
        count: _badges[e.id],
        onTap: () => _open(e),
      );

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) => e.visible).toList();
    final people = visible.where((e) => e.group == 'people').toList();
    final money = visible.where((e) => e.group == 'money').toList();
    // مؤشرات الانتظار: الوحدات المرئية التي لها عدّاد تمكّنا من جلبه (أو ما زال يُحمَّل).
    final kpis = visible.where((e) => e.kpiLabel != null && (!_loaded || _badges.containsKey(e.id))).toList();
    int sum(List<_HubEntry> list) => list.fold(0, (a, e) => a + (_badges[e.id] ?? 0));

    return StaffPage(
      title: 'الناس والمال',
      subtitle: 'الزبائن والمزودون والمدفوعات والنزاعات',
      showBack: widget.embedded ? false : null,
      onRefresh: _load,
      actions: [
        if (_loading && _loaded)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold))),
          ),
      ],
      slivers: [
        if (visible.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              title: 'لا وحدات متاحة',
              subtitle: 'اطلب من المدير منحك صلاحيات الزبائن أو المدفوعات',
            ),
          )
        else ...[
          // ── مؤشرات الانتظار ──
          if (kpis.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  for (final e in kpis)
                    if (!_loaded)
                      const SkeletonBox(height: 100)
                    else
                      KpiTile(
                        label: e.kpiLabel!,
                        value: '${_badges[e.id] ?? 0}',
                        icon: e.icon,
                        color: e.accent,
                        alert: (_badges[e.id] ?? 0) > 0,
                        onTap: () => _open(e),
                      ),
                ],
              ),
            ),
          if (people.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader('الناس', subtitle: 'الزبائن والمزودون وربط الأماكن', count: sum(people)),
            ),
            SliverToBoxAdapter(child: Pad(bottom: 0, child: TileGroup(children: [for (final e in people) _tile(e)]))),
          ],
          if (money.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader('المال', subtitle: 'المدفوعات والاسترداد والنزاعات', count: sum(money)),
            ),
            SliverToBoxAdapter(child: Pad(bottom: 0, child: TileGroup(children: [for (final e in money) _tile(e)]))),
          ],
        ],
      ],
    );
  }
}
