import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
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
      body: MaisonWash(
        child: Column(
          children: [
            const MaisonPageHeader(title: 'تقويم الحجوزات'),
            Expanded(
              child: properties.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: const [
                    ShimmerBox(height: 52, radius: VibesRadius.lg),
                    SizedBox(height: 14),
                    ShimmerBox(height: 320, radius: VibesRadius.xl),
                    SizedBox(height: 14),
                    ShimmerBox(height: 120, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
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
                  final bookings = ref.watch(
                    providerPropertyBookingsProvider(selected),
                  );

                  return Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            for (final property in list)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 8),
                                child: MaisonChip(
                                  label: property.name,
                                  active: selected == property.id,
                                  onTap: () =>
                                      setState(() => _propertyId = property.id),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: bookings.when(
                          loading: () => ListView(
                            padding: const EdgeInsets.all(16),
                            children: List.generate(
                              5,
                              (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ShimmerBox(
                                  height: 64,
                                  radius: VibesRadius.md,
                                ),
                              ),
                            ),
                          ),
                          error: (e, _) => ErrorCanvas(message: maisonError(e)),
                          data: (items) => ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                            children: [
                              FolioPanel(
                                child: TableCalendar(
                                  locale: 'ar',
                                  firstDay: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDay: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                  focusedDay: _focused,
                                  selectedDayPredicate: (day) =>
                                      _selectedDay != null &&
                                      day.year == _selectedDay!.year &&
                                      day.month == _selectedDay!.month &&
                                      day.day == _selectedDay!.day,
                                  calendarFormat: CalendarFormat.month,
                                  headerStyle: HeaderStyle(
                                    titleTextStyle: TextStyle(
                                      color: VibesTheme.textPrimaryOf(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    formatButtonVisible: false,
                                    leftChevronIcon: const Icon(
                                      Icons.chevron_right,
                                      color: Vibes.coral,
                                    ),
                                    rightChevronIcon: const Icon(
                                      Icons.chevron_left,
                                      color: Vibes.coral,
                                    ),
                                  ),
                                  daysOfWeekStyle: const DaysOfWeekStyle(
                                    weekdayStyle: TextStyle(
                                      color: Vibes.inkTertiary,
                                    ),
                                    weekendStyle: TextStyle(color: Vibes.teal),
                                  ),
                                  calendarStyle: CalendarStyle(
                                    defaultTextStyle: TextStyle(
                                      color: VibesTheme.textSecondaryOf(
                                        context,
                                      ),
                                    ),
                                    weekendTextStyle: const TextStyle(
                                      color: Vibes.teal,
                                    ),
                                    todayTextStyle: const TextStyle(
                                      color: Vibes.coral,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    todayDecoration: const BoxDecoration(
                                      color: Vibes.surfaceMuted,
                                      borderRadius: Folio.compact,
                                    ),
                                    selectedTextStyle: const TextStyle(
                                      color: Vibes.onCoral,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    selectedDecoration: const BoxDecoration(
                                      color: Vibes.coral,
                                      borderRadius: Folio.compact,
                                    ),
                                    markerDecoration: const BoxDecoration(
                                      color: Vibes.teal,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(2),
                                      ),
                                    ),
                                    outsideDaysVisible: false,
                                  ),
                                  eventLoader: (day) => items
                                      .where(
                                        (b) =>
                                            !day.isBefore(b.startDate) &&
                                            day.isBefore(b.endDate),
                                      )
                                      .toList(),
                                  onDaySelected: (selected, focused) {
                                    setState(() {
                                      _selectedDay = selected;
                                      _focused = focused;
                                    });
                                  },
                                  onPageChanged: (d) =>
                                      setState(() => _focused = d),
                                ),
                              ),
                              const SizedBox(height: 16),

                              _ExternalBookingCard(
                                propertyId: selected,
                                day: _selectedDay,
                                onDone: () {
                                  ref.invalidate(
                                    providerPropertyBookingsProvider(selected),
                                  );
                                  ref.invalidate(providerOverviewProvider);
                                },
                              ),
                              const SizedBox(height: 12),

                              // حجز/فتح أيام
                              _BlockDaysCard(
                                propertyId: selected,
                                day: _selectedDay,
                                onDone: () => ref.invalidate(
                                  providerPropertyBookingsProvider(selected),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // حجوزات الشهر
                              SectionHeader('حجوزات ${_monthLabel(_focused)}'),
                              ...items
                                  .where(
                                    (b) =>
                                        b.startDate.month == _focused.month &&
                                        b.startDate.year == _focused.year,
                                  )
                                  .map(
                                    (b) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: FolioPanel(
                                        railColor: b.isExternal
                                            ? Vibes.teal
                                            : Vibes.coral,
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      b.userName ??
                                                          b.userPhone ??
                                                          'ضيف',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    Text(
                                                      '${b.startDate.day}/${b.startDate.month} · ${b.shiftLabelAr}${b.isExternal ? ' · خارجي' : ''}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Vibes
                                                                .inkTertiary,
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Vibes.coral,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
      'كانون الأول',
    ];
    return months[d.month - 1];
  }
}

class _ExternalBookingCard extends ConsumerStatefulWidget {
  const _ExternalBookingCard({
    required this.propertyId,
    required this.onDone,
    this.day,
  });

  final String propertyId;
  final VoidCallback onDone;
  final DateTime? day;

  @override
  ConsumerState<_ExternalBookingCard> createState() =>
      _ExternalBookingCardState();
}

class _ExternalBookingCardState extends ConsumerState<_ExternalBookingCard> {
  Future<void> _open() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VibesTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (context) => _ExternalBookingForm(
        propertyId: widget.propertyId,
        day: widget.day ?? DateTime.now(),
      ),
    );
    if (saved == true) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: Vibes.teal.withValues(alpha: .4),
      railColor: Vibes.teal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سجّل الحجز الخارجي',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'إذا جاءك ضيف من واتساب أو مباشرة ولم تسجّله، سيظهر اليوم متاحاً على VIBEES وقد يُحجز مرتين.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            VibesButton(
              label: widget.day == null
                  ? 'حجز خارجي'
                  : 'حجز خارجي ليوم ${widget.day!.day}/${widget.day!.month}',
              small: true,
              onPressed: _open,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalBookingForm extends ConsumerStatefulWidget {
  const _ExternalBookingForm({required this.propertyId, required this.day});

  final String propertyId;
  final DateTime day;

  @override
  ConsumerState<_ExternalBookingForm> createState() =>
      _ExternalBookingFormState();
}

class _ExternalBookingFormState extends ConsumerState<_ExternalBookingForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _price;
  String _shift = 'FULL';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _price = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _price.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await createExternalBooking(
        ref.read(apiClientProvider),
        propertyId: widget.propertyId,
        startDate: _ymd(widget.day),
        shift: _shift,
        guestName: _name.text.trim(),
        guestPhone: _phone.text.trim(),
        totalPrice: num.tryParse(_price.text.trim()),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaisonSheetHandle(),
          Text(
            'حجز خارجي · ${widget.day.day}/${widget.day.month}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'يُقفل هذا اليوم عن ضيوف التطبيق فور الحفظ.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Vibes.inkTertiary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children:
                [
                  ('FULL', 'يوم كامل'),
                  ('MORNING', 'صباح'),
                  ('EVENING', 'مساء'),
                ].map((item) {
                  return MaisonChip(
                    label: item.$2,
                    active: _shift == item.$1,
                    onTap: () => setState(() => _shift = item.$1),
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          MaisonField(label: 'اسم الضيف', controller: _name),
          const SizedBox(height: 10),
          MaisonField(
            label: 'هاتف الضيف',
            controller: _phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          MaisonField(
            label: 'المبلغ (اختياري)',
            controller: _price,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          VibesButton(
            label: 'حفظ وإغلاق اليوم',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
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
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        ],
        available: available,
      );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(maisonError(e))));
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
              const Icon(
                Icons.event_busy_outlined,
                size: 18,
                color: Vibes.coral,
              ),
              const SizedBox(width: 8),
              Text(
                'إدارة الإغلاق',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: ThreadProgress(width: 96)),
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
                      onPressed: () =>
                          _block(widget.day ?? DateTime.now(), false),
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
                      onPressed: () =>
                          _block(widget.day ?? DateTime.now(), true),
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
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'ممتلكاتي',
              trailing: TextButton(
                onPressed: () => context.push('/provider/properties/new'),
                child: Text(
                  'إضافة',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Vibes.coral,
                  ),
                ),
              ),
            ),
            Expanded(
              child: properties.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: const [
                    ShimmerBox(height: 240, radius: VibesRadius.xl),
                    SizedBox(height: 14),
                    ShimmerBox(height: 240, radius: VibesRadius.xl),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(providerPropertiesProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyCanvas(
                      icon: Icons.home_work_outlined,
                      title: 'لا ممتلكات بعد',
                      subtitle:
                          'أضف بيانات المكان — فريق VIBEES يصوره بعد الموافقة',
                      action: VibesButton(
                        label: 'إضافة مكان',
                        small: true,
                        ghost: true,
                        onPressed: () =>
                            context.push('/provider/properties/new'),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async =>
                        ref.invalidate(providerPropertiesProvider),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _ProviderPropertyCard(
                        property: list[i],
                      ).animate(delay: Duration(milliseconds: i * 40)).fadeIn(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FolioPanel(
        color: VibesTheme.surfaceOf(context),
        shadows: Vibes.card,
        railColor: approved ? Vibes.teal : Vibes.coral,
        child: Column(
          children: [
            ClipPath(
              clipper: const ShapeBorderClipper(shape: Folio.shape),
              child: property.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: property.coverUrl!,
                      height: 148,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : ColoredBox(
                      color: Vibes.surfaceMuted,
                      child: const SizedBox(
                        height: 148,
                        width: double.infinity,
                        child: Icon(
                          Icons.home_work_outlined,
                          size: 40,
                          color: Vibes.inkTertiary,
                        ),
                      ),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Vibes.ink,
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Vibes.inkTertiary),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  Row(
                    children: [
                      _PropertyLink(
                        label: 'الأسعار',
                        onTap: () => context.push(
                          '/provider/properties/${property.id}/pricing',
                        ),
                      ),
                      _PropertyLink(
                        label: 'الوسائط',
                        onTap: () => context.push(
                          '/provider/properties/${property.id}/media',
                        ),
                      ),
                      _PropertyLink(
                        label: 'التوفر',
                        onTap: () => context.push(
                          '/provider/properties/${property.id}/availability',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyLink extends StatelessWidget {
  const _PropertyLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Vibes.coral,
            ),
          ),
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
      body: MaisonWash(
        child: Column(
          children: [
            const MaisonPageHeader(title: 'الأرباح'),
            Expanded(
              child: revenue.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: const [
                    ShimmerBox(height: 120, radius: VibesRadius.xl),
                    SizedBox(height: 14),
                    ShimmerBox(height: 220, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(providerRevenueProvider(6)),
                ),
                data: (rows) {
                  final total = rows.fold<num>(0, (sum, r) => sum + r.revenue);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      FolioPanel(
                        color: VibesDark.canvas,
                        borderColor: Vibes.teal.withValues(alpha: .28),
                        shadows: Vibes.floating,
                        railColor: Vibes.teal,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [VibesDark.surface, VibesDark.canvas],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إجمالي آخر 6 أشهر',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Vibes.tealBright.withValues(
                                        alpha: .9,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 6),
                              PriceText(total, onDark: true),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(),
                      const SizedBox(height: 22),

                      // الرسم
                      const SectionHeader('الإيراد الشهري'),
                      FolioPanel(
                        child: SizedBox(
                          height: 200,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _RevenueChart(rows: rows),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const SectionHeader('التفاصيل'),
                      FolioPanel(
                        shadows: Vibes.card,
                        child: Column(
                          children: [
                            for (var i = 0; i < rows.length; i++) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      rows[rows.length - 1 - i].month,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      '${rows[rows.length - 1 - i].bookings} حجزاً',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Vibes.inkTertiary),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${PriceText.format(rows[rows.length - 1 - i].revenue)} د.ع',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: Vibes.coral,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (i < rows.length - 1)
                                Divider(
                                  height: 1,
                                  color: VibesTheme.hairlineOf(context),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
          style: TextStyle(color: Vibes.inkTertiary, fontSize: 13),
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
                    color: Vibes.inkTertiary,
                    fontSize: 11,
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
                borderRadius: Folio.compact,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Vibes.coralBright, Vibes.coral],
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
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(title: 'الأسعار', onBack: () => context.pop()),
            Expanded(
              child: preview.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: const [
                    ShimmerBox(height: 64, radius: VibesRadius.lg),
                    SizedBox(height: 8),
                    ShimmerBox(height: 64, radius: VibesRadius.lg),
                    SizedBox(height: 8),
                    ShimmerBox(height: 64, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(
                    providerPricingPreviewProvider(propertyId),
                  ),
                ),
                data: (days) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionHeader(
                                'معاينة الأسعار',
                                subtitle: 'سعر كل يوم كما يراه العميل',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          child: VibesButton(
                            label: 'قاعدة جديدة',
                            small: true,
                            expanded: false,
                            onPressed: () =>
                                _openRuleSheet(context, ref, propertyId),
                          ),
                        ),
                      ],
                    ),
                    ...days.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FolioPanel(
                          borderColor: (d['ruleName'] as String?) != null
                              ? Vibes.teal.withValues(alpha: .4)
                              : VibesTheme.hairlineOf(context),
                          railColor: (d['ruleName'] as String?) != null
                              ? Vibes.teal
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  d['date'] as String,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                                if ((d['ruleName'] as String?) != null) ...[
                                  const SizedBox(width: 8),
                                  StatusPill(
                                    label: d['ruleName'] as String,
                                    color: Vibes.coral,
                                    compact: true,
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  '${PriceText.format((d['prices'] as Map)['full'])} د.ع',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Vibes.coral,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'وسائط المكان',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: property.when(
                loading: () => GridView.count(
                  padding: const EdgeInsets.all(20),
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: const [
                    ShimmerBox(height: 110, radius: VibesRadius.md),
                    ShimmerBox(height: 110, radius: VibesRadius.md),
                    ShimmerBox(height: 110, radius: VibesRadius.md),
                    ShimmerBox(height: 110, radius: VibesRadius.md),
                    ShimmerBox(height: 110, radius: VibesRadius.md),
                    ShimmerBox(height: 110, radius: VibesRadius.md),
                  ],
                ),
                error: (e, _) => ErrorCanvas(message: maisonError(e)),
                data: (p) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SectionHeader(
                      'صور المكان',
                      subtitle:
                          'فريق VIBEES يصور المزرعة أو القاعة بعد الموافقة — لا ترفع صوراً بنفسك',
                    ),
                    if (p.media.isEmpty)
                      const EmptyCanvas(
                        icon: Icons.photo_outlined,
                        title: 'لا وسائط',
                        subtitle:
                            'فريق VIBEES يلتقط الصور بعد الموافقة على المكان',
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
                        itemBuilder: (context, i) => FolioPanel(
                          clip: true,
                          child: CachedNetworkImage(
                            imageUrl: p.media[i].posterUrl ?? p.media[i].url,
                            fit: BoxFit.cover,
                            height: 110,
                            width: double.infinity,
                          ),
                        ),
                      ),
                  ],
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
    final availability = ref.watch(
      providerAvailabilityProvider((id: propertyId, month: null)),
    );

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'إدارة التوفر',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: availability.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [
                    ShimmerBox(height: 56, radius: VibesRadius.lg),
                    SizedBox(height: 8),
                    ShimmerBox(height: 56, radius: VibesRadius.lg),
                    SizedBox(height: 8),
                    ShimmerBox(height: 56, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(message: maisonError(e)),
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
                      ...slots.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FolioPanel(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
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
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Vibes.inkTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نموذج إضافة قاعدة أسعار من الجوال — أيام أسبوع أو فترة
Future<void> _openRuleSheet(
  BuildContext context,
  WidgetRef ref,
  String propertyId,
) async {
  final nameCtrl = TextEditingController();
  final fullCtrl = TextEditingController();
  final morningCtrl = TextEditingController();
  final eveningCtrl = TextEditingController();
  var ruleType = 'WEEKDAY';
  final days = <int>{};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VibesTheme.surfaceOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(12),
      ),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MaisonSheetHandle(),
              Text(
                'قاعدة أسعار جديدة',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const ArcFlourish(width: 28),
              const SizedBox(height: 16),
              Row(
                children: [
                  MaisonChip(
                    label: 'أيام أسبوع',
                    active: ruleType == 'WEEKDAY',
                    onTap: () => setSheet(() => ruleType = 'WEEKDAY'),
                  ),
                  const SizedBox(width: 10),
                  MaisonChip(
                    label: 'فترة/موسم',
                    active: ruleType == 'DATE_RANGE',
                    onTap: () => setSheet(() => ruleType = 'DATE_RANGE'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MaisonField(
                label: 'اسم القاعدة (اختياري)',
                controller: nameCtrl,
              ),
              const SizedBox(height: 12),
              MaisonField(
                label: 'سعر اليوم الكامل',
                controller: fullCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MaisonField(
                      label: 'الصباحي',
                      controller: morningCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MaisonField(
                      label: 'المسائي',
                      controller: eveningCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              // منتقي الأيام للقاعدة الأسبوعية
              if (ruleType == 'WEEKDAY') ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (i) {
                    const labels = [
                      'أحد',
                      'إثن',
                      'ثلا',
                      'أرب',
                      'خمي',
                      'جمع',
                      'سبت',
                    ];
                    final active = days.contains(i);
                    return GestureDetector(
                      onTap: () =>
                          setSheet(() => active ? days.remove(i) : days.add(i)),
                      child: AnimatedContainer(
                        duration: VibesMotion.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: ShapeDecoration(
                          gradient: active ? Vibes.coralFill : null,
                          color: active ? null : Vibes.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: Folio.compact,
                            side: active
                                ? BorderSide.none
                                : const BorderSide(color: Vibes.hairline),
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: Theme.of(sheetContext).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Vibes.onCoral
                                    : Vibes.inkSecondary,
                              ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 18),
              VibesButton(
                label: 'إضافة القاعدة',
                onPressed: () async {
                  final full = num.tryParse(fullCtrl.text);
                  if (ruleType == 'WEEKDAY' && days.isEmpty) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('اختر يوم اسبوع واحداً على الأقل'),
                      ),
                    );
                    return;
                  }
                  if (full == null &&
                      num.tryParse(morningCtrl.text) == null &&
                      num.tryParse(eveningCtrl.text) == null) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('أدخل سعراً واحداً على الأقل'),
                      ),
                    );
                    return;
                  }
                  try {
                    final client = ref.read(apiClientProvider);
                    await client.post(
                      '/api/provider/properties/$propertyId/pricing-rules',
                      body: {
                        'name': nameCtrl.text.trim(),
                        'ruleType': ruleType,
                        if (ruleType == 'WEEKDAY') 'daysOfWeek': days.toList(),
                        'fullDayPrice': full,
                        'morningPrice': num.tryParse(morningCtrl.text),
                        'eveningPrice': num.tryParse(eveningCtrl.text),
                        'isActive': true,
                      },
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    ref.invalidate(providerPricingPreviewProvider(propertyId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تمت إضافة القاعدة')),
                      );
                    }
                  } catch (e) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(
                        sheetContext,
                      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
