import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api.dart';
import '../../../core/shift.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';
import 'booking_wizard.dart';

/// تقويم الحجوزات الشهري (`/api/admin/calendar`) — `bookings.read`.
/// النقر على يوم يعرض حجوزاته وفتراته المحظورة أسفل الشبكة مباشرة.
class BookingsCalendarScreen extends StatefulWidget {
  const BookingsCalendarScreen({super.key, this.initialProperty});
  final Map<String, dynamic>? initialProperty;

  @override
  State<BookingsCalendarScreen> createState() => _BookingsCalendarScreenState();
}

class _DayInfo {
  final Map<String, int> shifts = {'MORNING': 0, 'EVENING': 0, 'FULL': 0};
  final List<Map<String, dynamic>> bookings = [];
  final List<Map<String, dynamic>> blocked = [];
  int get total => bookings.length;
}

class _BookingsCalendarScreenState extends State<BookingsCalendarScreen> {
  static const _weekdays = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

  late DateTime _month;
  DateTime? _selected;
  String _type = 'ALL';
  Map<String, dynamic>? _property;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _blocked = [];
  Map<String, _DayInfo> _days = {};
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dayOnly(now);
    _property = widget.initialProperty;
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = _bookings.isEmpty && _blocked.isEmpty;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/calendar${buildQuery({
        'month': DateFormat('yyyy-MM').format(_month),
        'propertyId': _property?['id']?.toString(),
        'propertyType': _type == 'ALL' ? null : _type,
      })}');
      if (!mounted || seq != _seq) return;
      _bookings = [for (final b in (data['bookings'] as List? ?? const [])) if (b is Map) Map<String, dynamic>.from(b)];
      _blocked = [for (final b in (data['blockedSlots'] as List? ?? const [])) if (b is Map) Map<String, dynamic>.from(b)];
      _days = _index();
    } catch (e) {
      if (!mounted || seq != _seq) return;
      _error = errorText(e);
    }
    if (mounted && seq == _seq) setState(() => _loading = false);
  }

  Map<String, _DayInfo> _index() {
    final map = <String, _DayInfo>{};
    final monthStart = DateTime(_month.year, _month.month);
    final monthEnd = DateTime(_month.year, _month.month + 1);
    for (final b in _bookings) {
      final s = parseDay(b['startDate']);
      if (s == null) continue;
      final e = parseDay(b['endDate']) ?? s.add(const Duration(days: 1));
      final shift = b['shift']?.toString() ?? 'FULL';
      var cursor = s.isBefore(monthStart) ? monthStart : s;
      final stop = e.isAfter(monthEnd) ? monthEnd : e;
      var guard = 0;
      do {
        final info = map.putIfAbsent(isoDay(cursor), _DayInfo.new);
        info.bookings.add(b);
        info.shifts[shift] = (info.shifts[shift] ?? 0) + 1;
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
        guard++;
      } while (cursor.isBefore(stop) && guard < 62);
    }
    for (final slot in _blocked) {
      final d = parseDay(slot['date']);
      if (d == null) continue;
      map.putIfAbsent(isoDay(d), _DayInfo.new).blocked.add(slot);
    }
    return map;
  }

  void _setMonth(DateTime month) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _month = month;
      _selected = (month.year == now.year && month.month == now.month) ? dayOnly(now) : null;
      _bookings = [];
      _blocked = [];
      _days = {};
    });
    _load();
  }

  void _shiftMonth(int delta) => _setMonth(DateTime(_month.year, _month.month + delta));

  Future<void> _chooseProperty() async {
    final p = await pickProperty(context, approvedOnly: false);
    if (p == null) return;
    setState(() => _property = p);
    _load();
  }

  Future<void> _openBooking(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingManageScreen(bookingId: id)));
    if (mounted) _load();
  }

  Future<void> _newBooking({DateTime? day}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewBookingWizardScreen(
        initialDate: day,
        initialProperty: day == null
            ? null
            : (_property?['status'] == null || _property?['status'] == 'APPROVED' ? _property : null),
      ),
    ));
    if (mounted) _load();
  }

  void _selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() => _selected = day);
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _bookings.where((b) => b['status'] == 'CONFIRMED' || b['status'] == 'COMPLETED').length;
    final pending = _bookings.where((b) => b['status'] == 'PENDING' || b['status'] == 'AWAITING_PAYMENT').length;
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    return StaffPage(
      title: 'التقويم',
      subtitle: 'الإشغال اليومي حسب الشفت',
      onRefresh: _load,
      actions: [
        if (!isThisMonth)
          IconButton(
            tooltip: 'هذا الشهر',
            onPressed: () => _setMonth(DateTime(now.year, now.month)),
            icon: const Icon(Icons.today_rounded),
          ),
      ],
      floatingActionButton: canWriteBookings
          ? FloatingActionButton.extended(
              heroTag: 'calendar-new-booking',
              onPressed: () => _newBooking(day: _selected),
              icon: const Icon(Icons.add_rounded),
              label: Text(_selected == null ? 'حجز جديد' : 'حجز ${fmtShortDay(_selected!)}'),
            )
          : null,
      slivers: [
        // ── فلاتر ──
        SliverToBoxAdapter(
          child: SegmentFilter<String>(
            options: const ['ALL', 'FARM', 'HALL', 'DECORATION'],
            value: _type,
            labelOf: (t) => t == 'ALL' ? 'كل الأنواع' : placeTypeLabel(t),
            onChanged: (t) {
              setState(() => _type = t);
              _load();
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Pad(
            top: 6,
            child: StaffCard(
              onTap: _chooseProperty,
              radius: StaffRadius.md,
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
              child: Row(
                children: [
                  Icon(Icons.home_work_rounded, size: 20, color: _property == null ? placeInk3 : placeBrass),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _property == null ? 'كل الأماكن — اضغط لاختيار مكان' : '${_property!['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: _property == null ? placeInk2 : placeInk),
                    ),
                  ),
                  if (_property != null)
                    IconButton(
                      tooltip: 'كل الأماكن',
                      onPressed: () {
                        setState(() => _property = null);
                        _load();
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    )
                  else
                    const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.expand_more_rounded, color: placeInk3)),
                ],
              ),
            ),
          ),
        ),
        // ── الشهر + أرقام ──
        SliverToBoxAdapter(
          child: Pad(
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              decoration: BoxDecoration(gradient: placeNavyFill, borderRadius: BorderRadius.circular(StaffRadius.lg)),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'الشهر السابق',
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMM('ar').format(_month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      if (_loading && _bookings.isNotEmpty)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
                      IconButton(
                        tooltip: 'الشهر التالي',
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _HeroNum(label: 'حجوزات الشهر', value: _bookings.length, dot: Colors.white54),
                      _HeroNum(label: 'مؤكدة', value: confirmed, dot: const Color(0xFF34D399)),
                      _HeroNum(label: 'معلّقة', value: pending, dot: const Color(0xFFFBBF24)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── الشبكة ──
        if (_error != null)
          SliverToBoxAdapter(child: ErrorPanel(message: _error!, onRetry: _load))
        else if (_loading && _bookings.isEmpty)
          const SliverToBoxAdapter(child: Pad(child: SkeletonBox(height: 360)))
        else ...[
          SliverToBoxAdapter(child: Pad(child: _grid())),
          SliverToBoxAdapter(child: _legend()),
          ..._dayDetails(),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 72)),
      ],
    );
  }

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7; // الأحد = 0
    final todayIso = isoDay(dayOnly(DateTime.now()));
    final selectedIso = _selected == null ? null : isoDay(_selected!);
    return StaffCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.w800, color: placeInk3)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.68,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, i) {
              if (i < leading) return const SizedBox.shrink();
              final date = DateTime(_month.year, _month.month, i - leading + 1);
              final iso = isoDay(date);
              return _DayCell(
                day: date.day,
                info: _days[iso],
                today: iso == todayIso,
                selected: iso == selectedIso,
                past: iso.compareTo(todayIso) < 0,
                onTap: () => _selectDay(date),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: placeInk2)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(placeShiftMorning, 'صباحي (ص)'),
          item(placeShiftEvening, 'مسائي (م)'),
          item(placeShiftFull, 'يوم كامل (ك)'),
          item(placeDanger, 'محظور'),
        ],
      ),
    );
  }

  List<Widget> _dayDetails() {
    final day = _selected;
    if (day == null) {
      return const [
        SliverToBoxAdapter(
          child: EmptyView(icon: Icons.touch_app_rounded, title: 'اختر يوماً', subtitle: 'اضغط على أي يوم لعرض حجوزاته وفتراته المحظورة'),
        ),
      ];
    }
    final info = _days[isoDay(day)];
    final empty = info == null || (info.bookings.isEmpty && info.blocked.isEmpty);
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          relativeDayLabel(day) == fmtDay(day) ? fmtDay(day) : '${relativeDayLabel(day)} · ${fmtShortDay(day)}',
          subtitle: '${info?.total ?? 0} حجز · ${info?.blocked.length ?? 0} فترة محظورة',
          count: info?.total,
          actionLabel: canWriteBookings ? 'حجز في هذا اليوم' : null,
          onAction: canWriteBookings ? () => _newBooking(day: day) : null,
        ),
      ),
      if (empty)
        const SliverToBoxAdapter(
          child: EmptyView(icon: Icons.event_available_rounded, title: 'يوم فارغ', subtitle: 'لا حجوزات ولا فترات محظورة'),
        )
      else ...[
        SliverList.builder(
          itemCount: info.bookings.length,
          itemBuilder: (_, i) => BookingRowCard(row: info.bookings[i], onTap: () => _openBooking('${info.bookings[i]['id']}')),
        ),
        if (info.blocked.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('فترات محظورة')),
          SliverToBoxAdapter(
            child: Pad(
              child: TileGroup(
                children: [
                  for (final s in info.blocked)
                    TaskTile(
                      icon: Icons.block_rounded,
                      color: placeDanger,
                      title: '${asMap(s['property'])?['name'] ?? 'مكان'}',
                      subtitle: [shiftShort(s['shift']?.toString()), if ((s['reason']?.toString() ?? '').isNotEmpty) '${s['reason']}'].join(' · '),
                      trailing: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    ];
  }
}

class _HeroNum extends StatelessWidget {
  const _HeroNum({required this.label, required this.value, required this.dot});
  final String label;
  final int value;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .72)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.info, required this.today, required this.selected, required this.past, required this.onTap});
  final int day;
  final _DayInfo? info;
  final bool today;
  final bool selected;
  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = info;
    final busy = i != null && i.total > 0;
    final blocked = i != null && i.blocked.isNotEmpty;
    final bg = selected ? placeInk : (busy ? placeGoldSoft : (past ? placePaper : Colors.white));
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(StaffRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StaffRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StaffRadius.sm),
            border: Border.all(
              color: selected ? placeInk : (today ? placeGold : (blocked ? placeDanger.withValues(alpha: 0.45) : placeLineSoft)),
              width: today || selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : (past ? placeInk3 : placeInk),
                ),
              ),
              const SizedBox(height: 2),
              if (i != null)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in const ['MORNING', 'EVENING', 'FULL'])
                          if ((i.shifts[s] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: _ShiftCount(shift: s, count: i.shifts[s]!),
                            ),
                        if (blocked) Icon(Icons.block_rounded, size: 13, color: selected ? Colors.white : placeDanger.withValues(alpha: 0.85)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftCount extends StatelessWidget {
  const _ShiftCount({required this.shift, required this.count});
  final String shift;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = shiftColor(shift);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Text(
        '${shiftBadgeChar(shift)}$count',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 9.5, height: 1.35, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}
