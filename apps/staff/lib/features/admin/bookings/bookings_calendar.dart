import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api.dart';
import '../../../core/shift.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';
import 'booking_wizard.dart';

/// تقويم الحجوزات الشهري (`/api/admin/calendar`) — `bookings.read`.
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

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _bookings = [];
      _blocked = [];
      _days = {};
    });
    _load();
  }

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

  void _openDay(DateTime day) {
    final info = _days[isoDay(day)];
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: placePaper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: placeLine, borderRadius: BorderRadius.circular(4))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmtDay(day), style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(
                          '${info?.total ?? 0} حجز · ${info?.blocked.length ?? 0} فترة محظورة',
                          style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (canWriteBookings)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => NewBookingWizardScreen(
                            initialDate: day,
                            initialProperty: _property?['status'] == null || _property?['status'] == 'APPROVED' ? _property : null,
                          ),
                        ));
                        if (mounted) _load();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('حجز'),
                    ),
                ],
              ),
            ),
            if (info == null || (info.bookings.isEmpty && info.blocked.isEmpty))
              const EmptyState(title: 'يوم فارغ', subtitle: 'لا حجوزات ولا فترات محظورة')
            else ...[
              for (final b in info.bookings)
                BookingRowCard(
                  row: b,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openBooking('${b['id']}');
                  },
                ),
              if (info.blocked.isNotEmpty) ...[
                const SectionLabel('فترات محظورة'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in info.blocked)
                        StatusPill(
                          label: '${asMap(s['property'])?['name'] ?? 'مكان'} · ${shiftShort(s['shift']?.toString())}',
                          color: placeDanger,
                          icon: Icons.block_rounded,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _bookings.where((b) => b['status'] == 'CONFIRMED' || b['status'] == 'COMPLETED').length;
    final pending = _bookings.where((b) => b['status'] == 'PENDING' || b['status'] == 'AWAITING_PAYMENT').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقويم الحجوزات'),
        actions: [
          IconButton(
            tooltip: 'هذا الشهر',
            onPressed: () {
              final now = DateTime.now();
              setState(() => _month = DateTime(now.year, now.month));
              _load();
            },
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ),
      floatingActionButton: canWriteBookings
          ? FloatingActionButton.extended(
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewBookingWizardScreen()));
                if (mounted) _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('حجز جديد'),
            )
          : null,
      body: RefreshIndicator(
        color: placeBrass,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            FilterChipsRow(
              options: const ['ALL', 'FARM', 'HALL', 'DECORATION'],
              selected: _type,
              labelBuilder: (t) => t == 'ALL' ? 'كل الأنواع' : placeTypeLabel(t),
              onSelected: (t) {
                setState(() => _type = t);
                _load();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InputChip(
                avatar: const Icon(Icons.home_work_outlined, size: 18),
                label: Text(_property == null ? 'كل الأماكن — اختر مكاناً' : '${_property!['name']}'),
                onPressed: _chooseProperty,
                onDeleted: _property == null
                    ? null
                    : () {
                        setState(() => _property = null);
                        _load();
                      },
                backgroundColor: Colors.white,
                side: const BorderSide(color: placeLine),
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_right_rounded)),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM('ar').format(_month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (_loading && _bookings.isNotEmpty)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_left_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  StatTile(label: 'حجوزات الشهر', value: '${_bookings.length}'),
                  const SizedBox(width: 8),
                  StatTile(label: 'مؤكدة', value: '$confirmed', accent: placeSuccess),
                  const SizedBox(width: 8),
                  StatTile(label: 'معلّقة', value: '$pending', accent: placeShiftMorning),
                ],
              ),
            ),
            if (_error != null)
              ErrorPanel(message: _error!, onRetry: _load)
            else if (_loading && _bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: placeBrass)),
              )
            else
              _grid(),
            _legend(),
          ],
        ),
      ),
    );
  }

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7; // الأحد = 0
    final todayIso = isoDay(dayOnly(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.w800, color: placeInk2)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 0.7,
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
                past: iso.compareTo(todayIso) < 0,
                onTap: () => _openDay(date),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.info, required this.today, required this.past, required this.onTap});
  final int day;
  final _DayInfo? info;
  final bool today;
  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = info;
    final busy = i != null && i.total > 0;
    final blocked = i != null && i.blocked.isNotEmpty;
    return Material(
      color: busy ? placeBrass.withValues(alpha: 0.07) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: today ? placeBrass : (blocked ? placeDanger.withValues(alpha: 0.45) : placeLine),
              width: today ? 1.6 : 1,
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
                  color: past ? placeInk2.withValues(alpha: 0.55) : placeInk,
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
                        if (blocked) Icon(Icons.block_rounded, size: 13, color: placeDanger.withValues(alpha: 0.85)),
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
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Text(
        '${shiftBadgeChar(shift)}$count',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 9.5, height: 1.35, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}
