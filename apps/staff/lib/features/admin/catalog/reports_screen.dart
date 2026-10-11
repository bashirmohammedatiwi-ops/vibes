import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/shift.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'catalog_common.dart';
import 'report_charts.dart';

String _bookingStatus(String? s) => s == 'DISPUTED' ? 'متنازع عليه' : bookingStatusAr(s);

Color _statusColor(String? s) => switch (s) {
      'CONFIRMED' => placeSuccess,
      'COMPLETED' => placeInk,
      'PENDING' => placeShiftMorning,
      'AWAITING_PAYMENT' => placeBrass,
      'CANCELLED' => placeDanger,
      'DISPUTED' => const Color(0xFFB45309),
      _ => placeInk2,
    };

/// التقارير — ملخص وتحليلات بفترة زمنية (reports.read).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _preset = '30d';
  DateTimeRange? _custom;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _analytics = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  int _reqId = 0;

  static const _presets = ['today', '7d', '30d', 'month', 'custom'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_preset) {
      'today' => DateTimeRange(start: today, end: today),
      '7d' => DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
      'month' => DateTimeRange(start: DateTime(now.year, now.month, 1), end: today),
      'custom' => _custom ?? DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today),
      _ => DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today),
    };
  }

  String _presetLabel(String p) => switch (p) {
        'today' => 'اليوم',
        '7d' => '7 أيام',
        '30d' => '30 يوماً',
        'month' => 'هذا الشهر',
        _ => _custom == null ? 'مخصص…' : '${fmtShortDate(_custom!.start)} – ${fmtShortDate(_custom!.end)}',
      };

  Future<void> _load() async {
    final id = ++_reqId;
    final r = _range;
    final q = 'from=${isoDay(r.start)}&to=${isoDay(r.end)}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.map('/api/admin/reports/summary?$q'),
        Api.map('/api/admin/reports/analytics?$q'),
        Api.map('/api/admin/dashboard/stats').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted || id != _reqId) return;
      setState(() {
        _summary = results[0];
        _analytics = results[1];
        if (results[2].isNotEmpty) _stats = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  Future<void> _selectPreset(String p) async {
    if (p == 'custom') {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _custom ?? _range,
        helpText: 'اختر الفترة',
        saveText: 'تطبيق',
      );
      if (picked == null) return;
      if (picked.end.difference(picked.start).inDays > 365) {
        if (mounted) showToast(context, 'أقصى فترة سنة واحدة', error: true);
        return;
      }
      _custom = picked;
    }
    setState(() => _preset = p);
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic v) =>
      (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Widget build(BuildContext context) {
    final hasData = _summary.isNotEmpty || _analytics.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        bottom: _loading && hasData
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: !hasData && _loading
            ? const CatalogLoadingView()
            : !hasData && _error != null
                ? CatalogErrorView(message: _error!, onRetry: _load)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      FilterChipsRow(
                        options: _presets,
                        selected: _preset,
                        onSelected: _selectPreset,
                        labelBuilder: _presetLabel,
                      ),
                      _rangeCaption(),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text('تعذّر التحديث: $_error',
                              style: const TextStyle(fontFamily: 'Cairo', color: placeDanger, fontWeight: FontWeight.w700)),
                        ),
                      _kpis(),
                      _revenueTrend(),
                      _byStatus(),
                      _byWorld(),
                      _byProvince(),
                      _topProperties(),
                      _topProviders(),
                      if (_stats.isNotEmpty) ..._overall(),
                    ],
                  ),
      ),
    );
  }

  Widget _rangeCaption() {
    final r = _range;
    final f = DateFormat('d MMMM yyyy', 'ar');
    final days = r.end.difference(r.start).inDays + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        days == 1 ? f.format(r.start) : '${f.format(r.start)} — ${f.format(r.end)} · $days يوماً',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2),
      ),
    );
  }

  Widget _card(String title, Widget child, {String? trailing, IconData? icon}) {
    return FormSection(title: title, subtitle: trailing, icon: icon, children: [child]);
  }

  Widget _kpis() {
    final a = _analytics;
    final s = _summary;
    final change = a['revenueChangePct'];
    final cards = [
      KpiCard(
        label: 'الإيراد',
        value: formatIqd(asNum(a['revenue'] ?? s['revenue'])),
        icon: Icons.payments_outlined,
        accent: placeSuccess,
        changePct: change is num ? change : null,
        caption: 'السابق: ${formatIqd(asNum(a['prevRevenue']))}',
      ),
      KpiCard(
        label: 'الحجوزات',
        value: fmtCount(s['bookings'] ?? a['bookings']),
        icon: Icons.event_available_outlined,
        caption: 'كل الحالات',
      ),
      KpiCard(
        label: 'متوسط قيمة الحجز',
        value: formatIqd(asNum(a['avgBookingValue'])),
        icon: Icons.receipt_long_outlined,
        accent: placeBrass,
      ),
      KpiCard(
        label: 'الإشغال التقريبي',
        value: '${asNum(a['occupancyPct'])}%',
        icon: Icons.donut_large_rounded,
        accent: placeShiftEvening,
        caption: '${fmtCount(a['approvedProperties'])} مكان معتمد',
      ),
      KpiCard(
        label: 'نسبة الإلغاء',
        value: '${asNum(a['cancellationRatePct'])}%',
        icon: Icons.cancel_outlined,
        accent: placeDanger,
      ),
      KpiCard(
        label: 'مهلة الحجز المسبق',
        value: '${asNum(a['avgLeadTimeDays'])} يوم',
        icon: Icons.hourglass_bottom_rounded,
        accent: placeShiftMorning,
        caption: 'متوسط الأيام قبل الموعد',
      ),
      KpiCard(
        label: 'الخصومات',
        value: formatIqd(asNum(a['discounts'])),
        icon: Icons.local_offer_outlined,
        accent: placeBrass,
      ),
      KpiCard(
        label: 'عملاء جدد',
        value: fmtCount(a['newCustomers']),
        icon: Icons.person_add_alt_1_outlined,
        accent: placeSuccess,
        caption: 'من ${fmtCount(a['totalCustomers'])} عميل',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: cards,
      ),
    );
  }

  Widget _revenueTrend() {
    final rows = _rows(_analytics['revenueTrend']);
    if (rows.isEmpty) return const SizedBox.shrink();
    final points = [
      for (final r in rows)
        ChartPoint(
          DateTime.tryParse('${r['date']}') != null ? fmtShortDate(DateTime.parse('${r['date']}')) : '${r['date']}',
          asNum(r['value']).toDouble(),
        ),
    ];
    final total = points.fold<double>(0, (s, p) => s + p.value);
    return _card(
      'الإيراد اليومي',
      TrendChart(
        points: points,
        color: placeSuccess,
        bars: points.length <= 14,
        valueFormatter: (v) => formatIqd(v),
      ),
      icon: Icons.show_chart_rounded,
      trailing: 'إجمالي ${formatIqd(total)} — حجوزات مؤكدة ومكتملة',
    );
  }

  Widget _byStatus() {
    final rows = _rows(_summary['bookingsByStatus'] ?? _analytics['bookingsByStatus'])
      ..sort((a, b) => asNum(b['count']).compareTo(asNum(a['count'])));
    final items = [for (final r in rows) ChartPoint(_bookingStatus('${r['status']}'), asNum(r['count']).toDouble(), detail: '${r['status']}')];
    return _card(
      'الحجوزات حسب الحالة',
      HBarList(items: items, colorOf: (_, p) => _statusColor(p.detail)),
      icon: Icons.fact_check_outlined,
    );
  }

  Widget _byWorld() {
    final rows = _rows(_summary['bookingsByType']);
    final props = _rows(_summary['propertiesByType']);
    final items = [
      for (final r in rows) ChartPoint(placeTypeLabel('${r['type']}'), asNum(r['count']).toDouble(), detail: '${r['type']}'),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final propItems = [
      for (final r in props) ChartPoint(placeTypeLabel('${r['type']}'), asNum(r['count']).toDouble(), detail: '${r['type']}'),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return _card(
      'حسب العالم (نوع المكان)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DonutChart(items: items, colorOf: (p) => worldColor(p.detail), centerLabel: 'حجز'),
          if (propItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('عدد الأماكن لكل نوع (كل الأوقات)',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2)),
            const SizedBox(height: 4),
            HBarList(items: propItems, colorOf: (_, p) => worldColor(p.detail)),
          ],
        ],
      ),
      icon: Icons.public_rounded,
    );
  }

  Widget _byProvince() {
    final rows = _rows(_summary['bookingsByProvince'])
      ..sort((a, b) => asNum(b['count']).compareTo(asNum(a['count'])));
    final items = [for (final r in rows.take(10)) ChartPoint('${r['name']}', asNum(r['count']).toDouble())];
    return _card(
      'الحجوزات حسب المحافظة',
      HBarList(items: items, color: placeShiftEvening),
      icon: Icons.map_outlined,
      trailing: rows.length > 10 ? 'أعلى 10 من ${rows.length}' : null,
    );
  }

  Widget _topProperties() {
    final rows = _rows(_summary['topProperties']);
    return _card(
      'أعلى الأماكن إيراداً',
      rows.isEmpty
          ? const Text('لا حجوزات مؤكدة في هذه الفترة', style: TextStyle(fontFamily: 'Cairo', color: placeInk2))
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _rankRow(
                    i + 1,
                    '${rows[i]['name']}',
                    '${placeTypeLabel('${rows[i]['type']}')} · ${fmtCount(rows[i]['bookings'])} حجز',
                    formatIqd(asNum(rows[i]['revenue'])),
                    worldColor('${rows[i]['type']}'),
                  ),
              ],
            ),
      icon: Icons.emoji_events_outlined,
    );
  }

  Widget _topProviders() {
    final rows = _rows(_analytics['topProviders']);
    if (rows.isEmpty) return const SizedBox.shrink();
    return _card(
      'أعلى المزودين',
      Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _rankRow(
              i + 1,
              '${rows[i]['name']}',
              '${fmtCount(rows[i]['bookings'])} حجز',
              formatIqd(asNum(rows[i]['revenue'])),
              placeBrass,
            ),
        ],
      ),
      icon: Icons.storefront_outlined,
    );
  }

  Widget _rankRow(int rank, String title, String sub, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3 ? placeBrass.withValues(alpha: 0.15) : placePaper,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('$rank',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: rank <= 3 ? placeBrass : placeInk2)),
          ),
          const SizedBox(width: 10),
          Container(width: 3, height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk)),
                Text(sub, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
        ],
      ),
    );
  }

  List<Widget> _overall() {
    final s = _stats;
    final monthly = _rows(s['monthlyRevenue']);
    final points = [
      for (final m in monthly)
        ChartPoint(
          _monthLabel('${m['month']}'),
          asNum(m['revenue']).toDouble(),
          detail: '${fmtCount(m['bookings'])} حجز',
        ),
    ];
    final queue = <(String, String, Color)>[
      ('أماكن بانتظار الاعتماد', 'pendingProperties', placeShiftEvening),
      ('إثباتات دفع معلّقة', 'pendingPaymentProofs', placeShiftMorning),
      ('حجوزات متنازع عليها', 'disputedBookings', placeDanger),
      ('طلبات استرداد', 'pendingRefunds', placeBrass),
      ('طلبات إلغاء', 'pendingCancellations', placeBrass),
      ('مزودون بانتظار التوثيق', 'pendingProviders', placeShiftEvening),
      ('عروض أسعار معلّقة', 'pendingOffers', placeInk2),
      ('بلاغات اجتماعية', 'pendingSocialReports', placeDanger),
      ('محادثات مفتوحة', 'pendingSupport', placeInk),
      ('وصول اليوم', 'todayCheckIns', placeSuccess),
      ('مكالمات فائتة اليوم', 'missedCallsToday', placeDanger),
    ];
    return [
      const SectionLabel('نظرة عامة على المنصة', trailing: 'كل الأوقات'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Column(
          children: [
            Row(children: [
              StatTile(label: 'المستخدمون', value: fmtCount(s['users'])),
              const SizedBox(width: 10),
              StatTile(label: 'الأماكن', value: fmtCount(s['properties']), accent: placeShiftEvening),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              StatTile(label: 'حجوزات فعّالة', value: fmtCount(s['bookings'])),
              const SizedBox(width: 10),
              StatTile(label: 'حجوزات هذا الشهر', value: fmtCount(s['monthlyBookings']), accent: placeBrass),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              StatTile(label: 'إجمالي الإيراد', value: fmtCompact(asNum(s['totalRevenue'])), accent: placeSuccess),
              const SizedBox(width: 10),
              StatTile(label: 'أماكن مميزة', value: fmtCount(s['featuredProperties'])),
            ]),
          ],
        ),
      ),
      if (points.isNotEmpty)
        _card(
          'الإيراد الشهري',
          TrendChart(points: points, bars: true, color: placeBrass, valueFormatter: (v) => formatIqd(v)),
          icon: Icons.bar_chart_rounded,
          trailing: 'آخر ${points.length} أشهر',
        ),
      _card(
        'قوائم الانتظار الآن',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, key, color) in queue)
              if (s[key] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: asNum(s[key]) > 0 ? color.withValues(alpha: 0.08) : placePaper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: asNum(s[key]) > 0 ? color.withValues(alpha: 0.3) : placeLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmtCount(s[key]),
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              color: asNum(s[key]) > 0 ? color : placeInk2)),
                      const SizedBox(width: 6),
                      Text(label,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk)),
                    ],
                  ),
                ),
          ],
        ),
        icon: Icons.pending_actions_outlined,
      ),
    ];
  }

  String _monthLabel(String key) {
    final d = DateTime.tryParse('$key-01');
    return d == null ? key : DateFormat('MMM yy', 'ar').format(d);
  }
}
