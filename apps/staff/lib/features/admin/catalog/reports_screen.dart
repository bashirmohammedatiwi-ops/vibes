import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/shift.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../../widgets/ui.dart' show FilterChipsRow;
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
    return StaffPage(
      title: 'التقارير',
      subtitle: _rangeText(),
      bottom: catalogBusyBar(_loading && hasData),
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: 'فترة مخصصة',
          onPressed: () => _selectPreset('custom'),
          icon: Icon(Icons.date_range_rounded, color: _preset == 'custom' ? placeBrass : placeInk),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: FilterChipsRow(
            options: _presets,
            selected: _preset,
            onSelected: _selectPreset,
            labelBuilder: _presetLabel,
          ),
        ),
        if (!hasData && _loading) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 0),
            sliver: SliverGrid(
              gridDelegate: _kpiGrid,
              delegate: SliverChildBuilderDelegate((_, _) => const SkeletonBox(height: 128), childCount: 6),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SkeletonSliver(count: 3, height: 200),
        ] else if (!hasData && _error != null)
          SliverFillRemaining(hasScrollBody: false, child: CatalogErrorView(message: _error!, onRetry: _load))
        else ...[
          if (_error != null)
            SliverToBoxAdapter(
              child: CatalogAlertBanner(
                text: 'تعذّر التحديث: $_error',
                icon: Icons.cloud_off_rounded,
                onTap: _load,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 0),
            sliver: SliverGrid(
              gridDelegate: _kpiGrid,
              delegate: SliverChildListDelegate(_kpis()),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _revenueTrend(),
              _byStatus(),
              _byWorld(),
              _byProvince(),
              _topProperties(),
              _topProviders(),
              if (_stats.isNotEmpty) ..._overall(),
            ]),
          ),
        ],
      ],
    );
  }

  static const _kpiGrid = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    mainAxisExtent: 128,
  );

  String _rangeText() {
    final r = _range;
    final f = DateFormat('d MMM yyyy', 'ar');
    final days = r.end.difference(r.start).inDays + 1;
    return days == 1 ? f.format(r.start) : '${f.format(r.start)} — ${f.format(r.end)} · $days يوماً';
  }

  /// قسم موحّد: عنوان + بطاقة بيضاء تحتوي الرسم.
  Widget _card(String title, Widget child, {String? trailing, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, subtitle: trailing),
        Pad(
          bottom: 0,
          child: StaffCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ),
      ],
    );
  }

  List<Widget> _kpis() {
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
    return cards;
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
                    fontFamily: 'Montserrat', fontWeight: FontWeight.w900, color: rank <= 3 ? placeBrass : placeInk2)),
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
      const SectionHeader('نظرة عامة على المنصة', subtitle: 'كل الأوقات'),
      Pad(
        bottom: 0,
        child: GridView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 118,
          ),
          children: [
            KpiTile(label: 'المستخدمون', value: fmtCount(s['users']), icon: Icons.people_alt_outlined, color: placeInfo),
            KpiTile(label: 'الأماكن', value: fmtCount(s['properties']), icon: Icons.home_work_outlined, color: placeShiftEvening),
            KpiTile(label: 'حجوزات فعّالة', value: fmtCount(s['bookings']), icon: Icons.event_note_outlined, color: placeInk),
            KpiTile(
              label: 'حجوزات هذا الشهر',
              value: fmtCount(s['monthlyBookings']),
              icon: Icons.calendar_month_outlined,
              color: placeBrass,
            ),
            KpiTile(
              label: 'إجمالي الإيراد',
              value: fmtCompact(asNum(s['totalRevenue'])),
              icon: Icons.payments_outlined,
              color: placeSuccess,
            ),
            KpiTile(
              label: 'أماكن مميزة',
              value: fmtCount(s['featuredProperties']),
              icon: Icons.workspace_premium_outlined,
              color: placeGold,
            ),
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
                              fontFamily: 'Montserrat',
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
