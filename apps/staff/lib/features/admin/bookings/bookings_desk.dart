import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';
import 'booking_wizard.dart';
import 'bookings_calendar.dart';
import 'bookings_list.dart';
import 'offers_collections.dart';

/// ═══════════════════════════════════════════════════════════
/// «الحجوزات» — تبويب رئيسي: أرقام سريعة، حجز جديد، بحث فوري،
/// شرائح الحالات، الخط الزمني لليوم والأيام القادمة، ومداخل
/// التقويم وكل الحجوزات وعروض الأسعار وقوائم الزبائن.
///
/// الصلاحيات:
/// - حجز جديد: `bookings.write`
/// - الأرقام + البحث + الخط الزمني + التقويم + القوائم + العروض: `bookings.read`
/// - قوائم الزبائن: بدون صلاحية خاصة
/// ═══════════════════════════════════════════════════════════
class BookingsDeskScreen extends StatefulWidget {
  const BookingsDeskScreen({super.key});

  /// هل تُعرض بطاقة المكتب في القائمة الرئيسية؟
  static bool get isVisible => canReadBookings || canWriteBookings;

  @override
  State<BookingsDeskScreen> createState() => _BookingsDeskScreenState();
}

/// شرائح الحالة في الصفحة الرئيسية.
const _segUpcoming = 'UPCOMING';
const _segments = [_segUpcoming, 'PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'];

class _BookingsDeskScreenState extends State<BookingsDeskScreen> {
  Map<String, dynamic>? _stats;
  String? _statsError;
  bool _statsLoading = true;

  String _segment = _segUpcoming;
  final Map<String, List<Map<String, dynamic>>> _lists = {};
  final Map<String, int> _totals = {};
  final Map<String, String?> _listErrors = {};
  bool _listLoading = true;
  int _listSeq = 0;

  final _search = TextEditingController();
  final _debounce = Debouncer();
  List<Map<String, dynamic>> _hits = [];
  bool _searching = false;
  int _searchSeq = 0;

  bool get _searchMode => _search.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!canReadBookings) {
      setState(() {
        _statsLoading = false;
        _listLoading = false;
      });
      return;
    }
    await Future.wait([_loadStats(), _loadSegment(_segment)]);
  }

  Future<void> _loadStats() async {
    try {
      final s = await Api.map('/api/admin/bookings/stats');
      _stats = s;
      _statsError = null;
    } catch (e) {
      _statsError = errorText(e);
    }
    if (mounted) setState(() => _statsLoading = false);
  }

  String _segmentQuery(String seg) {
    if (seg == _segUpcoming) {
      final today = dayOnly(DateTime.now());
      return buildQuery({
        'from': isoDay(today),
        'to': isoDay(today.add(const Duration(days: 6))),
        'pageSize': '100',
      });
    }
    return buildQuery({'status': seg, 'pageSize': '15'});
  }

  Future<void> _loadSegment(String seg) async {
    final seq = ++_listSeq;
    setState(() => _listLoading = !_lists.containsKey(seg));
    try {
      final data = await Api.send('/api/admin/bookings${_segmentQuery(seg)}');
      if (!mounted || seq != _listSeq) return;
      var rows = pagedItems(data);
      if (seg == _segUpcoming) {
        rows = rows.where((r) => r['status'] != 'CANCELLED').toList()
          ..sort((a, b) {
            final da = parseDay(a['startDate']) ?? DateTime(2100);
            final db = parseDay(b['startDate']) ?? DateTime(2100);
            final c = da.compareTo(db);
            return c != 0 ? c : _shiftOrder(a['shift']).compareTo(_shiftOrder(b['shift']));
          });
        _totals[seg] = rows.length;
      } else {
        _totals[seg] = pagedTotal(data);
      }
      _lists[seg] = rows;
      _listErrors[seg] = null;
    } catch (e) {
      if (!mounted || seq != _listSeq) return;
      _listErrors[seg] = errorText(e);
    }
    if (mounted && seq == _listSeq) setState(() => _listLoading = false);
  }

  static int _shiftOrder(dynamic s) => switch ('$s') {
        'MORNING' => 0,
        'FULL' => 1,
        _ => 2,
      };

  void _selectSegment(String seg) {
    setState(() => _segment = seg);
    _loadSegment(seg);
  }

  Future<void> _runSearch(String q) async {
    final term = q.trim();
    if (term.length < 2) {
      setState(() {
        _hits = [];
        _searching = false;
      });
      return;
    }
    final seq = ++_searchSeq;
    setState(() => _searching = true);
    try {
      final data = await Api.send('/api/admin/bookings${buildQuery({'q': term, 'pageSize': '10'})}');
      if (!mounted || seq != _searchSeq) return;
      _hits = pagedItems(data);
    } catch (e) {
      if (mounted && seq == _searchSeq) showToast(context, errorText(e), error: true);
    }
    if (mounted && seq == _searchSeq) setState(() => _searching = false);
  }

  Future<void> _push(Widget page) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  void _openBooking(Map<String, dynamic> b) => _push(BookingManageScreen(bookingId: '${b['id']}'));

  int _stat(String k) => (asNum(_stats?[k]) ?? 0).toInt();

  // ─────────── الواجهة ───────────

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE d MMMM', 'ar').format(DateTime.now());
    return StaffPage(
      title: 'الحجوزات',
      subtitle: date,
      onRefresh: _load,
      actions: [
        if (canReadBookings)
          IconButton(
            tooltip: 'التقويم',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _push(const BookingsCalendarScreen()),
          ),
      ],
      floatingActionButton: canWriteBookings
          ? FloatingActionButton.extended(
              heroTag: 'desk-new-booking',
              onPressed: () => _push(const NewBookingWizardScreen()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('حجز جديد'),
            )
          : null,
      slivers: [
        if (canReadBookings) ...[
          SliverToBoxAdapter(child: Pad(top: 4, child: _statsHero())),
          SliverToBoxAdapter(
            child: Pad(
              child: BookingSearchField(
                controller: _search,
                hint: 'بحث فوري: هاتف، اسم الزبون، أو المكان',
                busy: _searching,
                onChanged: (v) {
                  setState(() {});
                  _debounce.run(() => _runSearch(v));
                },
                onClear: () => setState(() => _hits = []),
              ),
            ),
          ),
          if (_searchMode) ..._searchSlivers() else ..._segmentSlivers(),
        ] else
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: StaffCard(
                child: Row(
                  children: const [
                    IconBox(icon: Icons.info_outline_rounded, color: placeInfo),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'يمكنك إنشاء حجوزات جديدة. عرض الحجوزات يتطلب صلاحية القراءة.',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // ── أدوات ──
        const SliverToBoxAdapter(child: SectionHeader('أدوات الحجوزات')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
          sliver: SliverGrid.count(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .74,
            children: [
              if (canWriteBookings)
                QuickAction(icon: Icons.add_card_rounded, label: 'حجز جديد', color: placeBrass, onTap: () => _push(const NewBookingWizardScreen())),
              if (canReadBookings) ...[
                QuickAction(icon: Icons.calendar_month_rounded, label: 'التقويم', color: placeInk, onTap: () => _push(const BookingsCalendarScreen())),
                QuickAction(icon: Icons.view_list_rounded, label: 'كل الحجوزات', color: placeInfo, onTap: () => _push(const AdminBookingsListScreen())),
                QuickAction(icon: Icons.local_offer_rounded, label: 'عروض الأسعار', color: placeShiftEvening, onTap: () => _push(const PriceOffersScreen())),
              ],
              QuickAction(icon: Icons.collections_bookmark_rounded, label: 'قوائم الزبائن', color: placeSuccess, onTap: () => _push(const CollectionsScreen())),
              if (canReadBookings)
                QuickAction(
                  icon: Icons.public_rounded,
                  label: 'الخارجية',
                  color: placeWarning,
                  onTap: () => _push(const AdminBookingsListScreen(initialOrigin: 'EXTERNAL')),
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 72)),
      ],
    );
  }

  /// بطاقة الأرقام الكحلية.
  Widget _statsHero() {
    if (_statsLoading) return const SkeletonBox(height: 168);
    if (_statsError != null) {
      return StaffCard(
        onTap: () {
          setState(() => _statsLoading = true);
          _loadStats();
        },
        child: Row(
          children: [
            const IconBox(icon: Icons.cloud_off_rounded, color: placeDanger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_statsError!, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2)),
            ),
            const Icon(Icons.refresh_rounded, color: placeInk3),
          ],
        ),
      );
    }
    final pending = _stat('pending');
    Widget cell(String label, int value, Color dot, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(StaffRadius.md),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 4),
                  Row(
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
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
      decoration: BoxDecoration(gradient: placeNavyFill, borderRadius: BorderRadius.circular(StaffRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إيراد المؤكدة والمكتملة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .7)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        formatIqd(_stats?['revenue']),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              if (pending > 0)
                Material(
                  color: placeGold,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _selectSegment('PENDING'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        '$pending تحتاج تأكيد',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.white.withValues(alpha: .12)),
          const SizedBox(height: 4),
          Row(
            children: [
              cell('بانتظار التأكيد', pending, const Color(0xFFFBBF24), () => _selectSegment('PENDING')),
              cell('مؤكدة', _stat('confirmed'), const Color(0xFF34D399), () => _selectSegment('CONFIRMED')),
              cell('مكتملة', _stat('completed'), const Color(0xFF93C5FD), () => _push(const AdminBookingsListScreen(initialStatus: 'COMPLETED'))),
              cell('الإجمالي', _stat('total'), Colors.white54, () => _push(const AdminBookingsListScreen())),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _searchSlivers() {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          'نتائج البحث',
          count: _hits.length,
          actionLabel: 'بحث متقدّم',
          onAction: () => _push(const AdminBookingsListScreen()),
        ),
      ),
      if (_searching && _hits.isEmpty)
        const SkeletonSliver(count: 3, height: 140)
      else if (_hits.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyView(icon: Icons.search_off_rounded, title: 'لا حجوزات مطابقة', subtitle: 'جرّب رقماً آخر أو جزءاً من الاسم'),
        )
      else
        SliverList.builder(
          itemCount: _hits.length,
          itemBuilder: (_, i) => BookingRowCard(row: _hits[i], onTap: () => _openBooking(_hits[i])),
        ),
    ];
  }

  String _segmentLabel(String s) => switch (s) {
        _segUpcoming => 'اليوم والقادمة',
        'PENDING' => 'بانتظار التأكيد',
        'AWAITING_PAYMENT' => 'بانتظار الدفع',
        'CONFIRMED' => 'مؤكدة',
        _ => s,
      };

  List<Widget> _segmentSlivers() {
    final rows = _lists[_segment] ?? const <Map<String, dynamic>>[];
    final error = _listErrors[_segment];
    final upcoming = _segment == _segUpcoming;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SegmentFilter<String>(
            options: _segments,
            value: _segment,
            labelOf: _segmentLabel,
            colorOf: (s) => s == _segUpcoming ? null : statusColor(s),
            countOf: (s) => s == 'PENDING' && _stats != null ? _stat('pending') : _totals[s],
            onChanged: _selectSegment,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          upcoming ? 'الخط الزمني' : _segmentLabel(_segment),
          subtitle: upcoming ? 'حجوزات تبدأ خلال ٧ أيام' : 'الأحدث أولاً',
          count: upcoming ? null : _totals[_segment],
          actionLabel: 'عرض الكل',
          onAction: () => _push(upcoming
              ? const AdminBookingsListScreen()
              : AdminBookingsListScreen(initialStatus: _segment)),
        ),
      ),
      ...asyncSlivers(
        loading: _listLoading && rows.isEmpty,
        error: rows.isEmpty ? error : null,
        isEmpty: rows.isEmpty,
        onRetry: () => _loadSegment(_segment),
        skeletonCount: 3,
        skeletonHeight: 140,
        emptyIcon: upcoming ? Icons.event_available_rounded : statusIcon(_segment),
        emptyTitle: upcoming ? 'لا حجوزات خلال الأيام القادمة' : 'لا حجوزات ${_segmentLabel(_segment)}',
        emptySubtitle: upcoming ? 'الأيام السبعة القادمة فارغة حتى الآن' : 'كل شيء تحت السيطرة',
        emptyActionLabel: canWriteBookings ? 'حجز جديد' : null,
        onEmptyAction: canWriteBookings ? () => _push(const NewBookingWizardScreen()) : null,
        slivers: upcoming ? _timeline(rows) : [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) => BookingRowCard(row: rows[i], onTap: () => _openBooking(rows[i])),
          ),
        ],
      ),
    ];
  }

  /// مجموعات حسب يوم البداية مع عنوان لكل يوم.
  List<Widget> _timeline(List<Map<String, dynamic>> rows) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final d = parseDay(r['startDate']);
      groups.putIfAbsent(d == null ? '' : isoDay(d), () => []).add(r);
    }
    final out = <Widget>[];
    for (final e in groups.entries) {
      final d = DateTime.tryParse(e.key);
      final isToday = d != null && dayOnly(d) == dayOnly(DateTime.now());
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isToday ? placeGold : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isToday ? placeGold : placeInk3, width: 2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                d == null ? 'بدون تاريخ' : relativeDayLabel(d),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: isToday ? placeBrass : placeInk),
              ),
              if (d != null && relativeDayLabel(d) != fmtDay(d)) ...[
                const SizedBox(width: 6),
                Text(fmtShortDay(d), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk3)),
              ],
              const SizedBox(width: 8),
              const Expanded(child: Divider(height: 1)),
              const SizedBox(width: 8),
              Text('${e.value.length} حجز', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2)),
            ],
          ),
        ),
      ));
      out.add(SliverList.builder(
        itemCount: e.value.length,
        itemBuilder: (_, i) => BookingRowCard(row: e.value[i], onTap: () => _openBooking(e.value[i])),
      ));
    }
    return out;
  }
}
