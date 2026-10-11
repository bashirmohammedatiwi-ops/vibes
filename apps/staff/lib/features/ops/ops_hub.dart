import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/office_nav.dart';
import '../../core/session.dart';
import '../../core/staff_capabilities.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../bookings.dart';
import '../requests.dart';
import 'ops_content.dart';
import 'ops_coupons.dart';
import 'ops_customers.dart';
import 'ops_dashboard.dart';
import 'ops_invoices.dart';
import 'ops_payments.dart';
import 'ops_properties.dart';
import 'ops_providers.dart';

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
      'dashboard' => const OpsDashboardScreen(),
      'properties' => const OpsPropertiesScreen(),
      'bookings' => const BookingsScreen(embedded: true),
      'payments' => const OpsPaymentsScreen(),
      'providers' => const OpsProvidersScreen(),
      'customers' => const OpsCustomersScreen(),
      'content' => const OpsContentScreen(),
      'coupons' => const OpsCouponsScreen(),
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

  @override
  Widget build(BuildContext context) {
    final modules = visibleOpsModules();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          MaisonHeader(
            title: 'العمليات',
            subtitle: 'بديل لوحة التحكم — يظهر لك فقط ما لديك صلاحية له',
            trailing: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat('انتظار مكالمة', '${_n('waiting')}', placeBrass),
                _MiniStat('حجوزات معلّقة', '${_n('pendingBookings')}', placeInk),
                _MiniStat('دفع معلّق', '${_n('pendingPayments')}', placeShiftMorning),
                _MiniStat('أماكن بانتظار', '${_n('pendingProperties')}', placeShiftEvening),
              ],
            ),
          ),
          if (modules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'لا وحدات عمليات متاحة لصلاحياتك الحالية',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', color: placeInk2),
              ),
            )
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
                children: [
                  for (final mod in modules)
                    _OpsTile(
                      module: mod,
                      badge: _badgeFor(mod.id),
                      onTap: () => _open(mod),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'صلاحياتك (${Session.permissions.length})',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                color: placeInk,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in Session.permissions)
                  Chip(
                    label: Text(
                      staffPermissionLabels[code] ?? code,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: placePaper,
                    side: const BorderSide(color: placeLine),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _badgeFor(String id) => switch (id) {
        'bookings' => _n('pendingBookings') + _n('awaitingPayment'),
        'payments' => _n('pendingPayments'),
        'properties' => _n('pendingProperties'),
        'providers' => _n('pendingProviders'),
        'requests' => _n('openRequests'),
        _ => 0,
      };
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: placeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: placeInk2)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontFamily: 'Montserrat', fontSize: 20, fontWeight: FontWeight.w800, color: color)),
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

  IconData get _icon => switch (module.icon) {
        'dashboard' => Icons.dashboard_outlined,
        'home_work' => Icons.home_work_outlined,
        'event' => Icons.event_available_outlined,
        'payments' => Icons.payments_outlined,
        'storefront' => Icons.storefront_outlined,
        'people' => Icons.people_outline,
        'rule' => Icons.rule_outlined,
        'collections' => Icons.collections_bookmark_outlined,
        'local_offer' => Icons.local_offer_outlined,
        'receipt' => Icons.receipt_long_outlined,
        _ => Icons.apps_outlined,
      };

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
                    child: Icon(_icon, color: placeInk, size: 22),
                  ),
                  const Spacer(),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: placeBrass,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                module.title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
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
