import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'provider_data.dart';
import '../../shared/data/property_providers.dart';
import '../../core/network/api_client.dart';

/// ═══════════════════════════════════════════════════════════
/// نافذة المزوّد — التقويم، الممتلكات، الأرباح، الأسعار، الوسائط، التوفر
/// ═══════════════════════════════════════════════════════════

// ── 3) التقويم ──

class ProviderCalendarScreen extends ConsumerStatefulWidget {
  const ProviderCalendarScreen({super.key});

  @override
  ConsumerState<ProviderCalendarScreen> createState() =>
      _ProviderCalendarScreenState();
}

class _ProviderCalendarScreenState
    extends ConsumerState<ProviderCalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selectedDay;
  String? _propertyId;

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(providerPropertiesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('تقويم الحجوزات'),
      ),
      body: properties.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(providerPropertiesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyCanvas(
              icon: Icons.home_work_outlined,
              title: 'لا ممتلكات بعد',
              subtitle: 'أضف ممتلكاتك أولاً لإدارة تقويمها',
            );
          }

          final selected = _propertyId ?? list.first.id;
          final bookings =
              ref.watch(providerPropertyBookingsProvider(selected));

          return Column(
            children: [
              // منتقي المكان
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: InkColors.surface,
                  borderRadius: BorderRadius.circular(VibesRadius.md),
                  border: Border.all(color: InkColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    dropdownColor: InkColors.surface,
                    items: list
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  color: InkColors.textPrimary,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _propertyId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: bookings.when(
                  loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: GoldColors.gold),
                  ),
                  error: (e, _) => ErrorCanvas(message: e.toString()),
                  data: (items) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      TableCalendar(
                        locale: 'ar',
                        firstDay: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDay:
                            DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focused,
                        calendarFormat: CalendarFormat.month,
                        headerStyle: const HeaderStyle(
                          titleTextStyle: TextStyle(
                            color: InkColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          formatButtonVisible: false,
                          leftChevronIcon:
                              Icon(Icons.chevron_right, color: GoldColors.gold),
                          rightChevronIcon:
                              Icon(Icons.chevron_left, color: GoldColors.gold),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle:
                              TextStyle(color: InkColors.textTertiary),
                          weekendStyle: TextStyle(color: GoldColors.gold),
                        ),
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: const TextStyle(
                              color: InkColors.textSecondary),
                          weekendTextStyle:
                              const TextStyle(color: GoldColors.gold),
                          todayTextStyle: const TextStyle(
                              color: GoldColors.onGold),
                          todayDecoration: BoxDecoration(
                            color: GoldColors.goldSoft,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: GoldColors.gold,
                            shape: BoxShape.circle,
                          ),
                          outsideDaysVisible: false,
                        ),
                        eventLoader: (day) => items
                            .where((b) =>
                                !day.isBefore(b.startDate) &&
                                day.isBefore(b.endDate))
                            .toList(),
                        onDaySelected: (selected, focused) {
                          setState(() {
                            _selectedDay = selected;
                            _focused = focused;
                          });
                        },
                        onPageChanged: (d) => setState(() => _focused = d),
                      ),
                      const SizedBox(height: 16),

                      // حجز/فتح أيام
                      _BlockDaysCard(
                        propertyId: selected,
                        day: _selectedDay,
                        onDone: () => ref.invalidate(
                            providerPropertyBookingsProvider(selected)),
                      ),
                      const SizedBox(height: 18),

                      // حجوزات الشهر
                      SectionHeader('حجوزات ${_monthLabel(_focused)}'),
                      ...items
                          .where((b) =>
                              b.startDate.month == _focused.month &&
                              b.startDate.year == _focused.year)
                          .map((b) => Container(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: InkColors.surface,
                                  borderRadius: BorderRadius.circular(
                                      VibesRadius.md),
                                  border:
                                      Border.all(color: InkColors.hairline),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.userName ?? b.userPhone ?? 'ضيف',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                          ),
                                          Text(
                                            '${b.startDate.day}/${b.startDate.month} · ${b.shiftLabelAr}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: InkColors
                                                      .textTertiary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${PriceText.format(b.totalPrice)} د.ع',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: GoldColors.gold,
                                          ),
                                    ),
                                  ],
                                ),
                              )),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول'
    ];
    return months[d.month - 1];
  }
}

class _BlockDaysCard extends ConsumerStatefulWidget {
  const _BlockDaysCard({
    required this.propertyId,
    required this.onDone,
    this.day,
  });

  final String propertyId;
  final VoidCallback onDone;
  final DateTime? day;

  @override
  ConsumerState<_BlockDaysCard> createState() => _BlockDaysCardState();
}

class _BlockDaysCardState extends ConsumerState<_BlockDaysCard> {
  bool _saving = false;

  Future<void> _block(DateTime day, bool available) async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await setAvailability(
        client,
        widget.propertyId,
        dates: [
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'
        ],
        available: available,
      );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VibesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy_outlined,
                  size: 18, color: GoldColors.gold),
              const SizedBox(width: 8),
              Text(
                'إدارة الإغلاق',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.day == null
                ? 'اختر يوماً من التقويم أعلاه ثم أغلقه أو افتحه'
                : 'اليوم المحدد: ${widget.day!.day}/${widget.day!.month}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VibesTheme.textTertiaryOf(context),
                ),
          ),
          const SizedBox(height: 12),
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: GoldColors.gold, strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: VibesButton(
                      label: 'إغلاق اليوم المحدد',
                      small: true,
                      onPressed: () => _block(widget.day ?? DateTime.now(), false),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: VibesButton(
                      label: 'فتح اليوم',
                      small: true,
                      ghost: true,
                      onPressed: () => _block(widget.day ?? DateTime.now(), true),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── 4) الممتلكات ──

class ProviderPropertiesScreen extends ConsumerWidget {
  const ProviderPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(providerPropertiesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('ممتلكاتي'),
      ),
      body: properties.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(providerPropertiesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyCanvas(
              icon: Icons.home_work_outlined,
              title: 'لا ممتلكات بعد',
              subtitle: 'أضف ممتلكاتك من تطبيق VIBES لتبدأ باستقبال الحجوزات',
              action: VibesButton(
                label: 'إضافة مكان',
                small: true,
                ghost: true,
                onPressed: () {},
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: list.length,
            itemBuilder: (context, i) =>
                _ProviderPropertyCard(property: list[i])
                    .animate(delay: Duration(milliseconds: i * 40))
                    .fadeIn(),
          );
        },
      ),
    );
  }
}

class _ProviderPropertyCard extends StatelessWidget {
  const _ProviderPropertyCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final approved = property.status == 'APPROVED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(VibesRadius.lg),
        border: Border.all(color: InkColors.hairline),
      ),
      child: Column(
        children: [
          // صورة غلاف
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(VibesRadius.lg),
            ),
            child: property.coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: property.coverUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 140,
                    color: InkColors.surfaceHigh,
                    child: const Icon(Icons.home_work_outlined,
                        size: 40, color: InkColors.textTertiary),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        property.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: InkColors.textPrimary,
                                ),
                      ),
                    ),
                    StatusPill(
                      label: approved
                          ? 'منشور'
                          : property.status == 'PENDING'
                              ? 'بانتظار المراجعة'
                              : property.status == 'REJECTED'
                                  ? 'مرفوض'
                                  : 'مسودة',
                      color: approved
                          ? SemanticColors.success
                          : property.status == 'PENDING'
                              ? SemanticColors.warning
                              : SemanticColors.danger,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${property.typeLabelAr} · ${property.cityName ?? ''} · ${property.bookingsCount} حجزاً',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: InkColors.textTertiary,
                      ),
                ),
                const SizedBox(height: 14),

                // أزرار الإدارة
                Row(
                  children: [
                    Expanded(
                      child: _ManageAction(
                        icon: Icons.payments_outlined,
                        label: 'الأسعار',
                        onTap: () => context.push(
                          '/provider/properties/${property.id}/pricing',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ManageAction(
                        icon: Icons.photo_library_outlined,
                        label: 'الوسائط',
                        onTap: () => context.push(
                          '/provider/properties/${property.id}/media',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ManageAction(
                        icon: Icons.event_available_outlined,
                        label: 'التوفر',
                        onTap: () => context.push(
                          '/provider/properties/${property.id}/availability',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageAction extends StatelessWidget {
  const _ManageAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: InkColors.surfaceHigh,
          borderRadius: BorderRadius.circular(VibesRadius.md),
          border: Border.all(color: InkColors.hairline),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: GoldColors.gold),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: InkColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 5) الأرباح ──

class ProviderEarningsScreen extends ConsumerWidget {
  const ProviderEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue = ref.watch(providerRevenueProvider(6));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الأرباح'),
      ),
      body: revenue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(providerRevenueProvider(6)),
        ),
        data: (rows) {
          final total =
              rows.fold<num>(0, (sum, r) => sum + r.revenue);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // الإجمالي
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VibesRadius.xl),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF26221A), Color(0xFF15130E)],
                  ),
                  border:
                      Border.all(color: GoldColors.gold.withValues(alpha: .25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي آخر 6 أشهر',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: GoldColors.gold.withValues(alpha: .85),
                          ),
                    ),
                    const SizedBox(height: 6),
                    PriceText(total),
                  ],
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 22),

              // الرسم
              const SectionHeader('الإيراد الشهري'),
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InkColors.surface,
                  borderRadius: BorderRadius.circular(VibesRadius.lg),
                  border: Border.all(color: InkColors.hairline),
                ),
                child: _RevenueChart(rows: rows),
              ),
              const SizedBox(height: 22),

              // التفاصيل
              const SectionHeader('التفاصيل'),
              for (final r in rows.reversed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: InkColors.surface,
                    borderRadius: BorderRadius.circular(VibesRadius.md),
                    border: Border.all(color: InkColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Text(
                        r.month,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${r.bookings} حجزاً',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: InkColors.textTertiary,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${PriceText.format(r.revenue)} د.ع',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: GoldColors.gold,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.rows});

  final List<({String month, num revenue, int bookings})> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.every((r) => r.revenue == 0)) {
      return const Center(
        child: Text(
          'لا أرباح بعد — ستظهر هنا مع أول حجز مؤكد',
          style: TextStyle(color: InkColors.textTertiary, fontSize: 13),
        ),
      );
    }

    final maxRevenue = rows
        .map((r) => r.revenue)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  value.toInt() >= 0 && value.toInt() < rows.length
                      ? rows[value.toInt()].month.substring(5)
                      : '',
                  style: const TextStyle(
                    color: InkColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        barGroups: rows.asMap().entries.map((entry) {
          final height = maxRevenue == 0
              ? 0.0
              : (entry.value.revenue / maxRevenue) * 10;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: height,
                width: 26,
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GoldColors.goldLight, GoldColors.goldDeep],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── 6) الأسعار ──

class ProviderPricingScreen extends ConsumerWidget {
  const ProviderPricingScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(providerPricingPreviewProvider(propertyId));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الأسعار'),
      ),
      body: preview.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(providerPricingPreviewProvider(propertyId)),
        ),
        data: (days) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SectionHeader(
              'معاينة الأسعار',
              subtitle: 'سعر كل يوم كما يراه العميل — عدّل القواعد من لوحة الويب',
            ),
            ...days.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: InkColors.surface,
                    borderRadius: BorderRadius.circular(VibesRadius.md),
                    border: Border.all(
                      color: (d['ruleName'] as String?) != null
                          ? GoldColors.gold.withValues(alpha: .35)
                          : InkColors.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        d['date'] as String,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                      ),
                      if ((d['ruleName'] as String?) != null) ...[
                        const SizedBox(width: 8),
                        StatusPill(
                          label: d['ruleName'] as String,
                          color: GoldColors.gold,
                          compact: true,
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${PriceText.format((d['prices'] as Map)['full'])} د.ع',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: GoldColors.gold,
                            ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── 7) الوسائط والتوفر — شاشات إدارة مبسطة ──

class ProviderMediaScreen extends ConsumerWidget {
  const ProviderMediaScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(propertyId));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('وسائط المكان'),
      ),
      body: property.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(message: e.toString()),
        data: (p) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(
              'الصور والفيديو الحالية',
              subtitle: 'ارفع المزيد من لوحة الويب للحصول على المعالجة الكاملة',
            ),
            if (p.media.isEmpty)
              const EmptyCanvas(
                icon: Icons.photo_outlined,
                title: 'لا وسائط',
                subtitle: 'ارفع صوراً وفيديوهات ليجذب مكانك المزيد من العملاء',
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: p.media.length,
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(VibesRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: p.media[i].posterUrl ?? p.media[i].url,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProviderAvailabilityScreen extends ConsumerWidget {
  const ProviderAvailabilityScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability =
        ref.watch(providerAvailabilityProvider((id: propertyId, month: null)));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('إدارة التوفر'),
      ),
      body: availability.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(message: e.toString()),
        data: (slots) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(
              'الأيام المغلقة',
              subtitle: 'لتعديل التواريخ استخدم التقويم الرئيسي',
            ),
            if (slots.isEmpty)
              const EmptyCanvas(
                icon: Icons.event_available_outlined,
                title: 'كل الأيام مفتوحة',
                subtitle: 'لا توجد أيام مغلقة حالياً',
              )
            else
              ...slots.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: InkColors.surface,
                      borderRadius: BorderRadius.circular(VibesRadius.md),
                      border: Border.all(color: InkColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Text(
                          (s['date'] as String).substring(0, 10),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          s['shift'] as String? ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: InkColors.textTertiary),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
