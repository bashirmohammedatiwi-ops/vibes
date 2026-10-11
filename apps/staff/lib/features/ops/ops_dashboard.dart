import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

class OpsDashboardScreen extends StatefulWidget {
  const OpsDashboardScreen({super.key});

  @override
  State<OpsDashboardScreen> createState() => _OpsDashboardScreenState();
}

class _OpsDashboardScreenState extends State<OpsDashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _stats = await Api.map('/api/staff/dashboard');
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _n(String k) => (_stats[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة اليوم')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Row(children: [StatTile(label: 'انتظار مكالمة', value: '${_n('waiting')}', accent: placeBrass), const SizedBox(width: 10), StatTile(label: 'حجوزات اليوم', value: '${_n('todayBookings')}')]),
            const SizedBox(height: 10),
            Row(children: [StatTile(label: 'بانتظار تأكيد', value: '${_n('pendingBookings')}'), const SizedBox(width: 10), StatTile(label: 'بانتظار دفع', value: '${_n('awaitingPayment')}', accent: placeShiftMorning)]),
            const SizedBox(height: 10),
            Row(children: [StatTile(label: 'مدفوعات معلّقة', value: '${_n('pendingPayments')}'), const SizedBox(width: 10), StatTile(label: 'أماكن بانتظار', value: '${_n('pendingProperties')}', accent: placeShiftEvening)]),
            const SizedBox(height: 10),
            Row(children: [StatTile(label: 'طلبات مفتوحة', value: '${_n('openRequests')}'), const SizedBox(width: 10), StatTile(label: 'رسائل غير مقروءة', value: '${_n('unreadMessages')}')]),
            const SizedBox(height: 10),
            Row(children: [StatTile(label: 'مزودون بانتظار', value: '${_n('pendingProviders')}'), const SizedBox(width: 10), const Expanded(child: SizedBox())]),
          ],
        ),
      ),
    );
  }
}
