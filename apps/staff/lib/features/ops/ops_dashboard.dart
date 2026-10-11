import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/kit.dart';

/// «لوحة اليوم» — أرقام لحظية لكل ما ينتظر في المنصة.
class OpsDashboardScreen extends StatefulWidget {
  const OpsDashboardScreen({super.key});

  @override
  State<OpsDashboardScreen> createState() => _OpsDashboardScreenState();
}

class _OpsDashboardScreenState extends State<OpsDashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loaded = false;

  Future<void> _load() async {
    try {
      final data = await Api.map('/api/staff/dashboard');
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _n(String k) => (_stats[k] as num?)?.toInt() ?? 0;

  Widget _grid(List<Widget> children) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
    sliver: SliverGrid.count(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: children),
  );

  KpiTile _kpi(String label, String key, IconData icon, Color color, {bool alertable = true}) =>
      KpiTile(label: label, value: '${_n(key)}', icon: icon, color: color, alert: alertable && _n(key) > 0);

  @override
  Widget build(BuildContext context) {
    return StaffPage(
      title: 'لوحة اليوم',
      subtitle: 'أرقام لحظية — اسحب للتحديث',
      onRefresh: _load,
      slivers: [
        if (!_loaded)
          _grid(List.generate(8, (_) => const SkeletonBox(height: double.infinity)))
        else ...[
          const SliverToBoxAdapter(child: SectionHeader('التواصل')),
          _grid([
            _kpi('مكالمات بالانتظار', 'waiting', Icons.phone_in_talk_rounded, placeWarning),
            _kpi('رسائل غير مقروءة', 'unreadMessages', Icons.forum_rounded, placeInfo),
          ]),
          const SliverToBoxAdapter(child: SectionHeader('الحجوزات')),
          _grid([
            _kpi('حجوزات اليوم', 'todayBookings', Icons.today_rounded, placeSuccess, alertable: false),
            _kpi('بانتظار التأكيد', 'pendingBookings', Icons.hourglass_top_rounded, placeBrass),
            _kpi('بانتظار الدفع', 'awaitingPayment', Icons.payments_rounded, placeWarning),
            _kpi('طلبات مفتوحة', 'openRequests', Icons.rule_rounded, placeDanger),
          ]),
          const SliverToBoxAdapter(child: SectionHeader('المراجعة')),
          _grid([
            _kpi('مدفوعات معلّقة', 'pendingPayments', Icons.receipt_long_rounded, placeInfo),
            _kpi('أماكن بانتظار', 'pendingProperties', Icons.villa_rounded, placeShiftEvening),
            _kpi('مزودون بانتظار', 'pendingProviders', Icons.storefront_rounded, placeNavyHigh),
          ]),
        ],
      ],
    );
  }
}
