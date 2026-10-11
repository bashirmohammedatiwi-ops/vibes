import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/ui.dart';
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
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.anyOf,
    required this.builder,
    this.accent = placeInk,
  });
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> anyOf;
  final Widget Function() builder;
  final Color accent;

  bool get visible => anyOf.any(Session.can);
}

final _entries = <_HubEntry>[
  _HubEntry(
    id: 'customers',
    title: 'الزبائن',
    subtitle: 'بحث، ملف، تعديل الاسم، إيقاف',
    icon: Icons.people_alt_outlined,
    anyOf: const ['users.read'],
    builder: () => const AdminCustomersScreen(),
  ),
  _HubEntry(
    id: 'providers',
    title: 'المزودون',
    subtitle: 'توثيق، رفض، إلغاء توثيق',
    icon: Icons.storefront_outlined,
    anyOf: const ['providers.read'],
    builder: () => const AdminProvidersScreen(),
    accent: placeBrass,
  ),
  _HubEntry(
    id: 'claims',
    title: 'طلبات الربط',
    subtitle: 'أصحاب أماكن يطلبون ربطها',
    icon: Icons.how_to_reg_outlined,
    anyOf: const ['providers.read'],
    builder: () => const PlaceClaimsScreen(),
    accent: placeBrass,
  ),
  _HubEntry(
    id: 'link',
    title: 'ربط مكان',
    subtitle: 'ربط مكان بحساب مزود',
    icon: Icons.add_link_rounded,
    anyOf: const ['providers.link'],
    builder: () => const LinkPlaceScreen(),
    accent: placeBrass,
  ),
  _HubEntry(
    id: 'payments',
    title: 'المدفوعات',
    subtitle: 'إثباتات، اعتماد، استرداد',
    icon: Icons.payments_outlined,
    anyOf: const ['payments.read'],
    builder: () => const AdminPaymentsScreen(),
    accent: placeSuccess,
  ),
  _HubEntry(
    id: 'refunds',
    title: 'الاسترداد والإلغاء',
    subtitle: 'طلبات الزبائن مع سياق الدفع',
    icon: Icons.currency_exchange_rounded,
    anyOf: const ['refunds.review'],
    builder: () => const AdminRefundsScreen(),
    accent: placeShiftMorning,
  ),
  _HubEntry(
    id: 'disputes',
    title: 'النزاعات',
    subtitle: 'فتح نزاع وحلّه',
    icon: Icons.gavel_rounded,
    anyOf: const ['disputes.review'],
    builder: () => const AdminDisputesScreen(),
    accent: placeDanger,
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
    });
  }

  Future<void> _open(_HubEntry e) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => e.builder()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) => e.visible).toList();
    final content = RefreshIndicator(
      color: placeBrass,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          MaisonHeader(
            title: 'الناس والمال',
            subtitle: 'الزبائن والمزودون والمدفوعات والنزاعات — حسب صلاحياتك',
            trailing: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass))
                : null,
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const EmptyState(title: 'لا وحدات متاحة', subtitle: 'اطلب من المدير منحك صلاحيات الزبائن أو المدفوعات')
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [for (final e in visible) _HubTile(entry: e, badge: _badges[e.id] ?? 0, onTap: () => _open(e))],
              ),
            ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(appBar: AppBar(title: const Text('الناس والمال')), body: content);
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.entry, required this.badge, required this.onTap});
  final _HubEntry entry;
  final int badge;
  final VoidCallback onTap;

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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: placeLine)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: entry.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(entry.icon, color: entry.accent, size: 22),
                  ),
                  const Spacer(),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: placeBrass, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(entry.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: placeInk2, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
