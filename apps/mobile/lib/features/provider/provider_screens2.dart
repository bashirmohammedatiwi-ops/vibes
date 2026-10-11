import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
import '../../core/theme/world_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
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
import 'provider_scope.dart';
import 'provider_ui.dart';
import '../property/place_experience_ui.dart';
import '../property/shift_calendar_ui.dart';
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
  DateTime? _selectedDay = DateTime.now();
  String? _propertyId;
  bool _pendingExternalSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(providerCalendarPropertyIdProvider);
      if (id != null) {
        setState(() => _propertyId = id);
        ref.read(providerCalendarPropertyIdProvider.notifier).state = null;
      }
    });
  }

  Future<void> _openExternalForm(String propertyId, DateTime day) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _ExternalBookingForm(propertyId: propertyId, day: day),
    );
    if (saved == true) {
      ref.invalidate(providerPropertyBookingsProvider(propertyId));
      ref.invalidate(providerOverviewProvider);
      final monthKey =
          '${_focused.year}-${_focused.month.toString().padLeft(2, '0')}';
      ref.invalidate(
        providerAvailabilityProvider((id: propertyId, month: monthKey)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(providerCalendarOpenExternalProvider, (prev, next) {
      if (next) {
        ref.read(providerCalendarOpenExternalProvider.notifier).state = false;
        setState(() {
          _selectedDay = DateTime.now();
          _pendingExternalSheet = true;
        });
      }
    });

    final properties = ref.watch(providerPropertiesProvider);

    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
        child: Column(
          children: [
            const MaisonPageHeader(title: 'تقويم الحجوزات'),
            Expanded(
              child: properties.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: const [
                    WorldSkeleton(height: 52, radius: 20),
                    SizedBox(height: 14),
                    WorldSkeleton(height: 320, radius: 20),
                    SizedBox(height: 14),
                    WorldSkeleton(height: 120, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(providerPropertiesProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const WorldEmpty(
                      icon: Icons.home_work_rounded,
                      title: 'لا أماكن مربوطة',
                      subtitle:
                          'راسل الدعم لربط مزرعتك أو قاعتك بحسابك ثم أدر التقويم من هنا',
                    );
                  }

                  final selected = _propertyId ?? list.first.id;
                  final monthKey =
                      '${_focused.year}-${_focused.month.toString().padLeft(2, '0')}';
                  final bookings = ref.watch(
                    providerPropertyBookingsProvider(selected),
                  );
                  final availability = ref.watch(
                    providerAvailabilityProvider((
                      id: selected,
                      month: monthKey,
                    )),
                  );

                  if (_pendingExternalSheet) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _pendingExternalSheet = false);
                      _openExternalForm(
                        selected,
                        _selectedDay ?? DateTime.now(),
                      );
                    });
                  }

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
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
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
                          data: (items) {
                            final closedDates = availability.maybeWhen(
                              data: (slots) => slots
                                  .where((s) => s['isAvailable'] == false)
                                  .map(
                                    (s) =>
                                        (s['date'] as String).substring(0, 10),
                                  )
                                  .toSet(),
                              orElse: () => <String>{},
                            );

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: OwnerCalendarLegend(),
                                ),
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
                                        color: VibesTheme.textPrimaryOf(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                      formatButtonVisible: false,
                                      leftChevronIcon: const Icon(
                                        Icons.chevron_right,
                                        color: ownerGoldDeep,
                                      ),
                                      rightChevronIcon: const Icon(
                                        Icons.chevron_left,
                                        color: ownerGoldDeep,
                                      ),
                                    ),
                                    daysOfWeekStyle: const DaysOfWeekStyle(
                                      weekdayStyle: TextStyle(
                                        color: Vibes.inkTertiary,
                                      ),
                                      weekendStyle: TextStyle(
                                        color: ownerNavyHigh,
                                      ),
                                    ),
                                    calendarStyle: CalendarStyle(
                                      defaultTextStyle: TextStyle(
                                        color: VibesTheme.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                      weekendTextStyle: const TextStyle(
                                        color: ownerNavyHigh,
                                      ),
                                      todayTextStyle: const TextStyle(
                                        color: ownerGoldDeep,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      todayDecoration: const BoxDecoration(
                                        color: Vibes.surfaceMuted,
                                        borderRadius: Folio.compact,
                                      ),
                                      selectedTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      selectedDecoration: const BoxDecoration(
                                        color: ownerGoldDeep,
                                        borderRadius: Folio.compact,
                                      ),
                                      markerDecoration: const BoxDecoration(
                                        color: ownerNavyHigh,
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
                                    calendarBuilders: CalendarBuilders(
                                      defaultBuilder: (context, day, focused) {
                                        final key = placeDateKey(day);
                                        final closed = closedDates.contains(
                                          key,
                                        );
                                        final dayBookings = items
                                            .where(
                                              (b) =>
                                                  ownerBookingCoversDay(b, day),
                                            )
                                            .toList();
                                        final shifts = <ShiftType>{
                                          for (final b in dayBookings) b.shift,
                                        }.toList();

                                        if (!closed && shifts.isEmpty)
                                          return null;

                                        return Container(
                                          margin: const EdgeInsets.all(5),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: closed
                                                ? ownerPaper
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: closed
                                                  ? ownerLine
                                                  : ownerNavy.withValues(
                                                      alpha: .12,
                                                    ),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontWeight: FontWeight.w800,
                                                  color: closed
                                                      ? placeInk2
                                                      : VibesTheme.textSecondaryOf(
                                                          context,
                                                        ),
                                                  decoration: closed
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                  decorationColor: placeInk2,
                                                ),
                                              ),
                                              if (shifts.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: PlaceShiftStripeRow(
                                                    shifts: shifts,
                                                    height: 2.5,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                      markerBuilder: (context, day, events) {
                                        if (events.isEmpty) return null;
                                        final shifts = <ShiftType>{
                                          for (final e in events)
                                            if (e is Booking) e.shift,
                                        }.toList();
                                        if (shifts.isEmpty) return null;
                                        final ordered = orderShiftsForDisplay(
                                          shifts,
                                        );
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < ordered.length;
                                              i++
                                            ) ...[
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color:
                                                      events.any(
                                                        (e) =>
                                                            e is Booking &&
                                                            e.isExternal &&
                                                            e.shift ==
                                                                ordered[i],
                                                      )
                                                      ? ownerGoldDeep
                                                      : placeShiftColor(
                                                          ordered[i],
                                                        ),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              if (i < ordered.length - 1)
                                                const SizedBox(width: 2),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                    onDaySelected: (selected, focused) {
                                      setState(() {
                                        _selectedDay = selected;
                                        _focused = focused;
                                      });
                                    },
                                    onPageChanged: (d) {
                                      setState(() => _focused = d);
                                      final key =
                                          '${d.year}-${d.month.toString().padLeft(2, '0')}';
                                      ref.invalidate(
                                        providerAvailabilityProvider((
                                          id: selected,
                                          month: key,
                                        )),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_selectedDay != null) ...[
                                  OwnerSelectedDayCard(
                                    day: _selectedDay!,
                                    bookings: items
                                        .where(
                                          (b) => ownerBookingCoversDay(
                                            b,
                                            _selectedDay!,
                                          ),
                                        )
                                        .toList(),
                                    isClosed: closedDates.contains(
                                      placeDateKey(_selectedDay!),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                _ExternalBookingCard(
                                  propertyId: selected,
                                  day: _selectedDay,
                                  onDone: () {
                                    ref.invalidate(
                                      providerPropertyBookingsProvider(
                                        selected,
                                      ),
                                    );
                                    ref.invalidate(providerOverviewProvider);
                                    ref.invalidate(
                                      providerAvailabilityProvider((
                                        id: selected,
                                        month: monthKey,
                                      )),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // حجز/فتح أيام
                                _BlockDaysCard(
                                  propertyId: selected,
                                  day: _selectedDay,
                                  onDone: () {
                                    ref.invalidate(
                                      providerPropertyBookingsProvider(
                                        selected,
                                      ),
                                    );
                                    ref.invalidate(
                                      providerAvailabilityProvider((
                                        id: selected,
                                        month: monthKey,
                                      )),
                                    );
                                  },
                                ),
                                const SizedBox(height: 18),

                                // حجوزات الشهر
                                SectionHeader(
                                  'حجوزات ${_monthLabel(_focused)}',
                                ),
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
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => context.push(
                                              '/provider/bookings/${b.id}',
                                            ),
                                            borderRadius: Folio.radius,
                                            child: FolioPanel(
                                              railColor: b.isExternal
                                                  ? ownerGoldDeep
                                                  : placeShiftColor(b.shift),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  b.userName ??
                                                                      b.userPhone ??
                                                                      'ضيف',
                                                                  style: const TextStyle(
                                                                    fontFamily:
                                                                        'Cairo',
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    color:
                                                                        ownerNavy,
                                                                  ),
                                                                ),
                                                              ),
                                                              PlaceShiftBadge(
                                                                shift: b.shift,
                                                                compact: true,
                                                                external: b
                                                                    .isExternal,
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            '${ownerRelativeBookingDay(b.startDate)}${b.isExternal ? ' · خارجي' : ''}',
                                                            style:
                                                                const TextStyle(
                                                                  fontFamily:
                                                                      'Cairo',
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      placeInk2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      '${PriceText.format(b.totalPrice)} د.ع',
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: ownerNavy,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons
                                                          .chevron_left_rounded,
                                                      color: placeInk2,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            );
                          },
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
      borderColor: ownerNavyHigh.withValues(alpha: .4),
      railColor: ownerNavyHigh,
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
              'إذا جاءك ضيف من واتساب أو مباشرة ولم تسجّله، سيظهر اليوم متاحاً على VIBES وقد يُحجز مرتين.',
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
  late final TextEditingController _guests;
  late final TextEditingController _notes;
  String _shift = 'FULL';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _price = TextEditingController();
    _guests = TextEditingController(text: '1');
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _price.dispose();
    _guests.dispose();
    _notes.dispose();
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
        guests: int.tryParse(_guests.text.trim()),
        totalPrice: num.tryParse(_price.text.trim()),
        notes: _notes.text.trim(),
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
                  return OwnerShiftChip(
                    apiShift: item.$1,
                    label: item.$2,
                    selected: _shift == item.$1,
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
          const SizedBox(height: 10),
          MaisonField(
            label: 'عدد الضيوف',
            controller: _guests,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          MaisonField(label: 'ملاحظة (اختياري)', controller: _notes),
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
  String _shift = 'FULL';

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
        shift: _shift,
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
                color: ownerGoldDeep,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children:
                [
                  ('FULL', 'يوم كامل'),
                  ('MORNING', 'صباح'),
                  ('EVENING', 'مساء'),
                ].map((item) {
                  return OwnerShiftChip(
                    apiShift: item.$1,
                    label: item.$2,
                    selected: _shift == item.$1,
                    onTap: () => setState(() => _shift = item.$1),
                  );
                }).toList(),
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
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
        child: Column(
          children: [
            const MaisonPageHeader(title: 'أماكني', kicker: 'إدارة الممتلكات'),
            Expanded(
              child: properties.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: const [
                    WorldSkeleton(height: 320, radius: 26),
                    SizedBox(height: 16),
                    WorldSkeleton(height: 320, radius: 26),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(providerPropertiesProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const WorldEmpty(
                      icon: Icons.home_work_rounded,
                      title: 'لا أماكن مربوطة بعد',
                      subtitle:
                          'راسل الدعم باسم المكان. بعد التأكد من الملكية يظهر هنا.',
                    );
                  }

                  return RefreshIndicator(
                    color: ownerNavyHigh,
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

class _ProviderPropertyCard extends ConsumerWidget {
  const _ProviderPropertyCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = property;
    final approved = p.status == 'APPROVED';
    final statusLabel = approved
        ? 'منشور'
        : p.status == 'PENDING'
        ? 'بانتظار المراجعة'
        : p.status == 'REJECTED'
        ? 'مرفوض'
        : 'مسودة';
    final statusColor = approved
        ? const Color(0xFF34D399)
        : p.status == 'PENDING'
        ? ownerGoldLight
        : const Color(0xFFF87171);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: ownerLine),
          boxShadow: [
            BoxShadow(
              color: ownerNavy.withValues(alpha: .06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => context.push('/property/${p.id}'),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PropertyCover(property: p, memCacheWidth: 900),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [.45, 1],
                          colors: [Colors.transparent, Color(0xCC0B1A2E)],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 12,
                      start: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ownerNavy.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 16,
                      end: 16,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            [
                              p.typeLabelAr,
                              if (p.cityName?.isNotEmpty == true) p.cityName!,
                            ].join(' · '),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  _PropStat(
                    icon: Icons.star_rounded,
                    value: p.ratingCount > 0
                        ? p.ratingAvg.toStringAsFixed(1)
                        : '—',
                    label: p.ratingCount > 0
                        ? '${p.ratingCount} تقييم'
                        : 'لا تقييم',
                  ),
                  _PropStat(
                    icon: Icons.event_available_rounded,
                    value: '${p.bookingsCount}',
                    label: 'حجز',
                  ),
                  _PropStat(
                    icon: Icons.visibility_rounded,
                    value: formatIqdShort(p.viewCount),
                    label: 'مشاهدة',
                  ),
                  _PropStat(
                    icon: Icons.favorite_rounded,
                    value: '${p.followersCount}',
                    label: 'متابع',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  _PropAction(
                    icon: Icons.calendar_month_rounded,
                    label: 'التقويم',
                    primary: true,
                    onTap: () {
                      ref
                              .read(providerCalendarPropertyIdProvider.notifier)
                              .state =
                          p.id;
                      context.go('/provider/calendar');
                    },
                  ),
                  _PropAction(
                    icon: Icons.sell_rounded,
                    label: 'الأسعار',
                    onTap: () =>
                        context.push('/provider/properties/${p.id}/pricing'),
                  ),
                  _PropAction(
                    icon: Icons.photo_library_rounded,
                    label: 'الوسائط',
                    onTap: () =>
                        context.push('/provider/properties/${p.id}/media'),
                  ),
                  _PropAction(
                    icon: Icons.event_busy_rounded,
                    label: 'التوفر',
                    onTap: () => context.push(
                      '/provider/properties/${p.id}/availability',
                    ),
                  ),
                  _PropAction(
                    icon: Icons.visibility_rounded,
                    label: 'معاينة',
                    onTap: () => context.push('/property/${p.id}'),
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

class _PropStat extends StatelessWidget {
  const _PropStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: ownerGold),
              const SizedBox(width: 3),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ownerNavy,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: placeInk2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropAction extends StatelessWidget {
  const _PropAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: primary ? ownerNavyFill : null,
                color: primary ? null : ownerPaper,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                size: 21,
                color: primary ? ownerGoldLight : ownerNavyHigh,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: ownerNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 5) الأرباح ──

const _arMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// "2026-10" → "أكتوبر" (و"أكتوبر 2025" عند [withYear]).
String _monthAr(String ym, {bool withYear = false}) {
  final parts = ym.split('-');
  final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (m == null || m < 1 || m > 12) return ym;
  return withYear ? '${_arMonths[m - 1]} ${parts[0]}' : _arMonths[m - 1];
}

class ProviderEarningsScreen extends ConsumerStatefulWidget {
  const ProviderEarningsScreen({super.key});

  @override
  ConsumerState<ProviderEarningsScreen> createState() =>
      _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState
    extends ConsumerState<ProviderEarningsScreen> {
  int _months = 6;
  int? _selected;

  void _share(List<({String month, num revenue, int bookings})> rows) {
    final total = rows.fold<num>(0, (s, r) => s + r.revenue);
    final count = rows.fold<int>(0, (s, r) => s + r.bookings);
    final lines = [
      'تقرير أرباح VIBES — آخر $_months أشهر',
      '',
      for (final r in rows.reversed)
        '${_monthAr(r.month, withYear: true)}: ${PriceText.format(r.revenue)} د.ع (${r.bookings} حجز)',
      '',
      'الإجمالي: ${PriceText.format(total)} د.ع · $count حجز',
    ];
    Share.share(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    const p = WorldPalette.owner;
    final revenue = ref.watch(providerRevenueProvider(_months));
    final month = ref.watch(providerOverviewProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(
        children: [
          MaisonPageHeader(
            title: 'الأرباح والتقارير',
            trailing: revenue.maybeWhen(
              data: (rows) => IconButton(
                tooltip: 'مشاركة التقرير',
                onPressed: () => _share(rows),
                icon: const Icon(Icons.ios_share_rounded),
                color: ownerNavy,
              ),
              orElse: () => null,
            ),
          ),
          Expanded(
            child: revenue.when(
              skipLoadingOnReload: true,
              loading: () => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: const [
                  WorldSkeleton(height: 210, radius: 26),
                  SizedBox(height: 14),
                  WorldSkeleton(height: 90, radius: 20),
                  SizedBox(height: 14),
                  WorldSkeleton(height: 240, radius: 24),
                ],
              ),
              error: (e, _) => ErrorCanvas(
                message: maisonError(e),
                onRetry: () => ref.invalidate(providerRevenueProvider(_months)),
              ),
              data: (raw) {
                final rows = [...raw]
                  ..sort((a, b) => a.month.compareTo(b.month));
                final total = rows.fold<num>(0, (s, r) => s + r.revenue);
                final count = rows.fold<int>(0, (s, r) => s + r.bookings);
                final best = rows.isEmpty
                    ? null
                    : rows.reduce((a, b) => b.revenue > a.revenue ? b : a);
                final o = month.valueOrNull;
                final sel = _selected != null && _selected! < rows.length
                    ? rows[_selected!]
                    : null;

                return RefreshIndicator(
                  color: p.accentDeep,
                  onRefresh: () async {
                    ref.invalidate(providerRevenueProvider(_months));
                    ref.invalidate(providerOverviewProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      OwnerRevenueHero(
                        revenue: o?.monthRevenue ?? 0,
                        bookingsCount: o?.monthBookings ?? 0,
                        series: rows.map((r) => r.revenue).toList(),
                      ).animate().fadeIn(duration: 350.ms),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OwnerMetricTile(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'إجمالي $_months أشهر',
                              value: formatIqdShort(total),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OwnerMetricTile(
                              icon: Icons.receipt_rounded,
                              label: 'متوسط الحجز',
                              value: count == 0
                                  ? '—'
                                  : formatIqdShort(total / count),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OwnerMetricTile(
                              icon: Icons.emoji_events_rounded,
                              label: best == null || best.revenue == 0
                                  ? 'أفضل شهر'
                                  : 'أفضل: ${_monthAr(best.month)}',
                              value: best == null || best.revenue == 0
                                  ? '—'
                                  : formatIqdShort(best.revenue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OwnerShiftRevenueBreakdown(
                        stats: o?.monthByShift ?? const ProviderMonthByShift(),
                      ).animate().fadeIn(delay: 80.ms),
                      const SizedBox(height: 22),
                      OwnerSectionTitle(
                        'الإيراد الشهري',
                        subtitle: sel == null
                            ? 'اضغط على شهر لعرض تفاصيله'
                            : '${_monthAr(sel.month, withYear: true)} · ${PriceText.format(sel.revenue)} د.ع · ${sel.bookings} حجز',
                        trailing: _PeriodToggle(
                          value: _months,
                          onChanged: (v) => setState(() {
                            _months = v;
                            _selected = null;
                          }),
                        ),
                      ),
                      Container(
                        height: 230,
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: ownerLine),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: _RevenueChart(
                            rows: rows,
                            selected: _selected,
                            onSelect: (i) => setState(
                              () => _selected = _selected == i ? null : i,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const OwnerSectionTitle('التفاصيل'),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: ownerLine),
                        ),
                        child: Column(
                          children: [
                            for (final (i, r) in rows.reversed.indexed) ...[
                              _MonthRow(
                                label: _monthAr(r.month, withYear: true),
                                revenue: r.revenue,
                                bookings: r.bookings,
                                share: best == null || best.revenue == 0
                                    ? 0
                                    : r.revenue / best.revenue,
                                highlight: sel != null && sel.month == r.month,
                              ),
                              if (i < rows.length - 1)
                                const Divider(height: 1, color: ownerLine),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ownerPaper,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in const [6, 12])
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(m);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: value == m ? ownerNavyFill : null,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$m أشهر',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: value == m ? ownerGoldLight : placeInk2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.label,
    required this.revenue,
    required this.bookings,
    required this.share,
    required this.highlight,
  });

  final String label;
  final num revenue;
  final int bookings;
  final double share;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: highlight ? ownerGold.withValues(alpha: .08) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ownerNavy,
                  ),
                ),
              ),
              Text(
                '$bookings حجز',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: placeInk2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${PriceText.format(revenue)} د.ع',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: ownerNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: ownerPaper,
              valueColor: const AlwaysStoppedAnimation(ownerGold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({
    required this.rows,
    required this.selected,
    required this.onSelect,
  });

  final List<({String month, num revenue, int bookings})> rows;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || rows.every((r) => r.revenue == 0)) {
      return const Center(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            'لا أرباح بعد — ستظهر هنا مع أول حجز مؤكد',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: placeInk2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final maxRevenue = rows
        .map((r) => r.revenue)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final barWidth = rows.length > 8 ? 14.0 : 24.0;

    return BarChart(
      BarChartData(
        maxY: maxRevenue * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRevenue / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: ownerLine, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.spot != null) {
              HapticFeedback.selectionClick();
              onSelect(response!.spot!.touchedBarGroupIndex);
            }
          },
        ),
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
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                final label = _monthAr(rows[i].month);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    rows.length > 8 ? label.substring(0, 3) : label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: selected == i ? ownerGoldDeep : placeInk2,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].revenue.toDouble(),
                  width: barWidth,
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: selected == null || selected == i
                        ? (i == rows.length - 1 || selected == i
                              ? const [ownerGoldLight, ownerGoldDeep]
                              : const [ownerNavyHigh, ownerNavy])
                        : [
                            ownerNavyHigh.withValues(alpha: .25),
                            ownerNavy.withValues(alpha: .25),
                          ],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxRevenue * 1.15,
                    color: ownerPaper,
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
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
    final rules = ref.watch(providerPricingRulesProvider(propertyId));

    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
        child: Column(
          children: [
            MaisonPageHeader(title: 'الأسعار', onBack: () => context.pop()),
            Expanded(
              child: preview.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: const [
                    WorldSkeleton(height: 64, radius: 20),
                    SizedBox(height: 8),
                    WorldSkeleton(height: 64, radius: 20),
                    SizedBox(height: 8),
                    WorldSkeleton(height: 64, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(
                    providerPricingPreviewProvider(propertyId),
                  ),
                ),
                data: (days) {
                  final ruleList = rules.valueOrNull ?? [];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (ruleList.isNotEmpty) ...[
                        const OwnerSectionTitle(
                          'قواعد الأسعار',
                          subtitle: 'تُطبَّق تلقائياً على الأيام المطابقة',
                        ),
                        for (final rule in ruleList)
                          _ProviderPriceRuleRow(
                            propertyId: propertyId,
                            rule: rule,
                          ),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const OwnerSectionTitle(
                                  'معاينة 21 يوماً',
                                  subtitle: 'كما يراها الضيف في التطبيق',
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ownerPaper,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (d['ruleName'] as String?) != null
                                    ? ownerGoldDeep.withValues(alpha: .45)
                                    : ownerLine,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  d['date'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ownerNavy,
                                  ),
                                ),
                                if ((d['ruleName'] as String?) != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ownerGoldDeep.withValues(
                                        alpha: .15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      d['ruleName'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: ownerGoldDeep,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  '${PriceText.format((d['prices'] as Map)['full'])} د.ع',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: ownerNavy,
                                  ),
                                ),
                              ],
                            ),
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
}

class _ProviderPriceRuleRow extends ConsumerWidget {
  const _ProviderPriceRuleRow({required this.propertyId, required this.rule});

  final String propertyId;
  final Map<String, dynamic> rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (rule['name'] as String?)?.trim();
    final full = rule['fullDayPrice'];
    final active = rule['isActive'] != false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ownerLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name?.isNotEmpty == true ? name! : 'قاعدة أسعار',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: active ? ownerNavy : placeInk2,
                    ),
                  ),
                  Text(
                    full != null
                        ? '${PriceText.format(full is num ? full : num.tryParse('$full') ?? 0)} د.ع · يوم كامل'
                        : 'أسعار شفتات مخصّصة',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'حذف القاعدة',
              onPressed: () async {
                final id = rule['id'] as String?;
                if (id == null) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .delete(
                        '/api/provider/properties/$propertyId/pricing-rules/$id',
                      );
                  ref.invalidate(providerPricingRulesProvider(propertyId));
                  ref.invalidate(providerPricingPreviewProvider(propertyId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف القاعدة')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(maisonError(e))));
                  }
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, color: placeInk2),
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
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
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
                    WorldSkeleton(height: 110, radius: 20),
                    WorldSkeleton(height: 110, radius: 20),
                    WorldSkeleton(height: 110, radius: 20),
                    WorldSkeleton(height: 110, radius: 20),
                    WorldSkeleton(height: 110, radius: 20),
                    WorldSkeleton(height: 110, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(message: maisonError(e)),
                data: (p) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SectionHeader(
                      'صور المكان',
                      subtitle:
                          'فريق VIBES يصور المزرعة أو القاعة بعد الموافقة — لا ترفع صوراً بنفسك',
                    ),
                    if (p.media.isEmpty)
                      const WorldEmpty(
                        icon: Icons.photo_outlined,
                        title: 'لا وسائط',
                        subtitle:
                            'فريق VIBES يلتقط الصور بعد الموافقة على المكان',
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

  static String _shiftAr(String? shift) => switch (shift) {
    'MORNING' => 'صباح',
    'EVENING' => 'مساء',
    'FULL' => 'يوم كامل',
    _ => shift ?? '',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(
      providerAvailabilityProvider((id: propertyId, month: null)),
    );

    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
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
                    WorldSkeleton(height: 56, radius: 20),
                    SizedBox(height: 8),
                    WorldSkeleton(height: 56, radius: 20),
                    SizedBox(height: 8),
                    WorldSkeleton(height: 56, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(message: maisonError(e)),
                data: (slots) {
                  final closed = slots
                      .where((s) => s['isAvailable'] == false)
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const OwnerSectionTitle(
                        'الأيام والشفتات المغلقة',
                        subtitle:
                            'افتح يوماً ليعود متاحاً للضيوف، أو استخدم التقويم لإغلاق تواريخ جديدة',
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ref
                                  .read(
                                    providerCalendarPropertyIdProvider.notifier,
                                  )
                                  .state =
                              propertyId;
                          context.go('/provider/calendar');
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('فتح التقويم'),
                        style: TextButton.styleFrom(foregroundColor: ownerNavy),
                      ),
                      if (closed.isEmpty)
                        const WorldEmpty(
                          icon: Icons.event_available_outlined,
                          title: 'كل الأيام مفتوحة',
                          subtitle: 'لا توجد أيام مغلقة حالياً',
                        )
                      else
                        for (final s in closed)
                          _AvailabilityClosedRow(
                            propertyId: propertyId,
                            date: (s['date'] as String).substring(0, 10),
                            shift: s['shift'] as String?,
                            shiftLabel: _shiftAr(s['shift'] as String?),
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

class _AvailabilityClosedRow extends ConsumerWidget {
  const _AvailabilityClosedRow({
    required this.propertyId,
    required this.date,
    required this.shift,
    required this.shiftLabel,
  });

  final String propertyId;
  final String date;
  final String? shift;
  final String shiftLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: ownerPaper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ownerLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ownerNavy,
                    ),
                  ),
                  Text(
                    shiftLabel,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await clearAvailabilitySlots(
                    ref.read(apiClientProvider),
                    propertyId,
                    dates: [date],
                    shifts: shift != null ? [shift!] : null,
                  );
                  ref.invalidate(
                    providerAvailabilityProvider((id: propertyId, month: null)),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('أُعيد اليوم للتوفر')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(maisonError(e))));
                  }
                }
              },
              child: const Text(
                'فتح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
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
              MaisonField(label: 'اسم القاعدة (اختياري)', controller: nameCtrl),
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
                          gradient: active ? ownerNavyFill : null,
                          color: active ? null : Vibes.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: Folio.compact,
                            side: active
                                ? const BorderSide(color: Color(0x73A87F33))
                                : const BorderSide(color: Vibes.hairline),
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: Theme.of(sheetContext).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? ownerGoldLight
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
                    ref.invalidate(providerPricingRulesProvider(propertyId));
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
