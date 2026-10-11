import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';
import 'booking_wizard.dart';

/// فلاتر قائمة الحجوزات المتقدّمة (مطابقة لاستعلام `GET /api/admin/bookings`).
class BookingFilters {
  String? status;
  String? shift;
  String? origin;
  String? paymentStatus;
  String? paymentMethod;
  DateTime? from;
  DateTime? to;
  Map<String, dynamic>? property;

  BookingFilters({this.status, this.shift, this.origin, this.paymentStatus, this.paymentMethod, this.from, this.to, this.property});

  BookingFilters copy() => BookingFilters(
        status: status,
        shift: shift,
        origin: origin,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        from: from,
        to: to,
        property: property,
      );

  /// عدد الفلاتر الإضافية (غير الحالة).
  int get extraCount => [shift, origin, paymentStatus, paymentMethod, from, to, property].where((v) => v != null).length;

  Map<String, String?> toQuery() => {
        'status': status,
        'shift': shift,
        'origin': origin,
        'paymentStatus': paymentStatus,
        'paymentMethod': paymentMethod,
        'from': from == null ? null : isoDay(from!),
        'to': to == null ? null : isoDay(to!),
        'propertyId': property?['id']?.toString(),
      };
}

/// قائمة الحجوزات المتقدّمة مع إحصاءات وفلاتر وإجراءات جماعية — `bookings.read`
/// (الإجراءات الجماعية `bookings.write`).
class AdminBookingsListScreen extends StatefulWidget {
  const AdminBookingsListScreen({super.key, this.initialStatus, this.initialOrigin});
  final String? initialStatus;
  final String? initialOrigin;

  @override
  State<AdminBookingsListScreen> createState() => _AdminBookingsListScreenState();
}

class _AdminBookingsListScreenState extends State<AdminBookingsListScreen> {
  late final BookingFilters _filters = BookingFilters(status: widget.initialStatus, origin: widget.initialOrigin);
  final _search = TextEditingController();
  final _debounce = Debouncer();

  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _stats;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _seq = 0;

  final Set<String> _selected = {};
  bool _bulkBusy = false;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStats();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce.dispose();
    super.dispose();
  }

  String _query(int page) => buildQuery({
        ..._filters.toQuery(),
        'q': _search.text,
        'page': '$page',
        'pageSize': '20',
      });

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = _rows.isEmpty;
      _error = null;
    });
    try {
      final data = await Api.send('/api/admin/bookings${_query(1)}');
      if (!mounted || seq != _seq) return;
      _rows = pagedItems(data);
      _page = 1;
      _totalPages = pagedTotalPages(data);
      _total = pagedTotal(data);
      _selected.removeWhere((id) => !_rows.any((r) => r['id'] == id));
    } catch (e) {
      if (!mounted || seq != _seq) return;
      _error = errorText(e);
      _rows = [];
    }
    if (mounted && seq == _seq) setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    try {
      final s = await Api.map('/api/admin/bookings/stats');
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      // الإحصاءات ثانوية — نتجاهل الخطأ
    }
  }

  Future<void> _refresh() => Future.wait([_load(), _loadStats()]);

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    final seq = _seq;
    try {
      final data = await Api.send('/api/admin/bookings${_query(_page + 1)}');
      if (!mounted || seq != _seq) return;
      _rows.addAll(pagedItems(data));
      _page++;
      _totalPages = pagedTotalPages(data);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _reset() {
    setState(() {
      _rows = [];
      _selected.clear();
    });
    _load();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<BookingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FiltersSheet(initial: _filters.copy()),
    );
    if (result == null) return;
    setState(() {
      _filters
        ..shift = result.shift
        ..origin = result.origin
        ..paymentStatus = result.paymentStatus
        ..paymentMethod = result.paymentMethod
        ..from = result.from
        ..to = result.to
        ..property = result.property;
    });
    _reset();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingManageScreen(bookingId: '${row['id']}')));
    if (mounted) _refresh();
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  Future<void> _bulk() async {
    final result = await showStatusSheet(
      context,
      title: 'إجراء جماعي',
      subtitle: 'تطبيق الحالة على ${_selected.length} حجز',
      options: const ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED', 'COMPLETED', 'CANCELLED'],
    );
    if (result == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الإجراء الجماعي',
      message: 'سيتم نقل ${_selected.length} حجز إلى «${statusLabel(result.status)}».',
      confirmLabel: 'تطبيق',
      danger: result.status == 'CANCELLED',
    );
    if (!ok) return;
    setState(() => _bulkBusy = true);
    try {
      final res = await Api.map('/api/admin/bookings/bulk', method: 'POST', body: {
        'ids': _selected.toList(),
        'status': result.status,
        if (result.note.isNotEmpty) 'adminNote': result.note,
      });
      HapticFeedback.mediumImpact();
      final updated = res['updated'] ?? 0;
      final failed = (res['failed'] as num?)?.toInt() ?? 0;
      if (mounted) {
        showToast(context, failed > 0 ? 'حُدّث $updated · فشل $failed' : 'تم تحديث $updated حجز', error: failed > 0);
      }
      _selected.clear();
      await _refresh();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  int? _statusCount(String s) {
    final st = _stats;
    if (st == null) return null;
    return switch (s) {
      'ALL' => (asNum(st['total']) ?? 0).toInt(),
      'PENDING' => (asNum(st['pending']) ?? 0).toInt(),
      'CONFIRMED' => (asNum(st['confirmed']) ?? 0).toInt(),
      'COMPLETED' => (asNum(st['completed']) ?? 0).toInt(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final page = StaffPage(
      title: _selecting ? '${_selected.length} محدد' : 'كل الحجوزات',
      subtitle: _selecting ? 'اختر الحجوزات ثم طبّق الحالة' : (_stats == null ? null : 'الإيراد المؤكد ${formatIqd(_stats!['revenue'])}'),
      onRefresh: _refresh,
      leading: _selecting
          ? IconButton(tooltip: 'إلغاء التحديد', onPressed: () => setState(_selected.clear), icon: const Icon(Icons.close_rounded))
          : null,
      actions: [
        if (_selecting)
          IconButton(
            tooltip: 'تحديد الكل',
            onPressed: () => setState(() => _selected.addAll(_rows.map((r) => '${r['id']}'))),
            icon: const Icon(Icons.select_all_rounded),
          ),
      ],
      floatingActionButton: !_selecting && canWriteBookings
          ? FloatingActionButton(
              heroTag: 'list-new-booking',
              tooltip: 'حجز جديد',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewBookingWizardScreen()));
                if (mounted) _refresh();
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
      slivers: [
        if (!_selecting) SliverToBoxAdapter(child: _StatsStrip(stats: _stats, onPick: _pickStatus)),
        SliverToBoxAdapter(
          child: Pad(
            top: 4,
            bottom: 6,
            child: BookingSearchField(
              controller: _search,
              hint: 'هاتف، اسم الزبون، أو المكان',
              onChanged: (_) {
                setState(() {});
                _debounce.run(_reset);
              },
              onClear: _reset,
              trailing: Badge(
                isLabelVisible: _filters.extraCount > 0,
                label: Text('${_filters.extraCount}'),
                backgroundColor: placeBrass,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: _filters.extraCount > 0 ? placeInk : Colors.white,
                      foregroundColor: _filters.extraCount > 0 ? Colors.white : placeInk,
                      side: const BorderSide(color: placeLine),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.md)),
                    ),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'فلاتر',
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SegmentFilter<String>(
            options: const ['ALL', ...allBookingStatuses],
            value: _filters.status ?? 'ALL',
            labelOf: (s) => s == 'ALL' ? 'الكل' : statusLabel(s),
            colorOf: (s) => s == 'ALL' ? null : statusColor(s),
            countOf: _statusCount,
            onChanged: _pickStatus,
          ),
        ),
        if (_filters.extraCount > 0) SliverToBoxAdapter(child: _activeFilters()),
        if (!_loading && _error == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 8),
              child: Text(
                canWriteBookings && !_selecting ? '$_total نتيجة · اضغط مطولاً للتحديد الجماعي' : '$_total نتيجة',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ...asyncSlivers(
          loading: _loading,
          error: _error,
          isEmpty: _rows.isEmpty,
          onRetry: _refresh,
          skeletonHeight: 140,
          emptyIcon: Icons.search_off_rounded,
          emptyTitle: 'لا حجوزات مطابقة',
          emptySubtitle: 'جرّب تغيير الفلاتر أو البحث',
          slivers: [
            SliverList.builder(
              itemCount: _rows.length,
              itemBuilder: (_, i) {
                final row = _rows[i];
                return BookingRowCard(
                  row: row,
                  selectable: _selecting,
                  selected: _selected.contains('${row['id']}'),
                  onTap: () => _selecting ? _toggle('${row['id']}') : _open(row),
                  onLongPress: canWriteBookings ? () => _toggle('${row['id']}') : null,
                );
              },
            ),
            SliverToBoxAdapter(child: LoadMoreTile(hasMore: _page < _totalPages, loading: _loadingMore, onPressed: _loadMore)),
          ],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 64)),
      ],
    );
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
          return false;
        },
        child: withBottomBar(
          page,
          _selecting
              ? BookingActionBar(
                  children: [
                    BarButton(label: 'إلغاء التحديد', primary: false, onPressed: () => setState(_selected.clear)),
                    BarButton(
                      label: 'تغيير حالة المحدد (${_selected.length})',
                      icon: Icons.swap_horiz_rounded,
                      flex: 2,
                      busy: _bulkBusy,
                      onPressed: _bulk,
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  void _pickStatus(String s) {
    setState(() => _filters.status = s == 'ALL' ? null : s);
    _reset();
  }

  Widget _activeFilters() {
    final f = _filters;
    final chips = <Widget>[
      if (f.property != null) _chip('المكان: ${f.property!['name']}', () => f.property = null),
      if (f.shift != null) _chip(shiftShort(f.shift), () => f.shift = null),
      if (f.origin != null) _chip(originLabel(f.origin), () => f.origin = null),
      if (f.paymentStatus != null) _chip('الدفع: ${paymentStatusAr(f.paymentStatus)}', () => f.paymentStatus = null),
      if (f.paymentMethod != null) _chip(paymentMethodAr(f.paymentMethod), () => f.paymentMethod = null),
      if (f.from != null) _chip('من ${fmtShortDay(f.from!)}', () => f.from = null),
      if (f.to != null) _chip('إلى ${fmtShortDay(f.to!)}', () => f.to = null),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 6, StaffSpace.page, 0),
      child: Row(children: [for (final c in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: c)]),
    );
  }

  Widget _chip(String label, VoidCallback clear) => InputChip(
        label: Text(label),
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeBrass),
        backgroundColor: placeGoldSoft,
        side: BorderSide(color: placeGold.withValues(alpha: 0.4)),
        deleteIconColor: placeBrass,
        onDeleted: () {
          setState(clear);
          _reset();
        },
      );
}

/// شريط أرقام أفقي قابل للنقر (يضبط فلتر الحالة).
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats, required this.onPick});
  final Map<String, dynamic>? stats;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) return const SizedBox.shrink(); // الإحصاءات ثانوية
    String n(String k) => '${s[k] ?? 0}';
    final tiles = [
      KpiTile(label: 'الإجمالي', value: n('total'), icon: Icons.event_note_rounded, onTap: () => onPick('ALL')),
      KpiTile(
        label: 'بانتظار التأكيد',
        value: n('pending'),
        icon: Icons.hourglass_top_rounded,
        color: placeWarning,
        alert: (asNum(s['pending']) ?? 0) > 0,
        onTap: () => onPick('PENDING'),
      ),
      KpiTile(label: 'مؤكدة', value: n('confirmed'), icon: Icons.verified_rounded, color: placeSuccess, onTap: () => onPick('CONFIRMED')),
      KpiTile(label: 'مكتملة', value: n('completed'), icon: Icons.task_alt_rounded, color: placeInfo, onTap: () => onPick('COMPLETED')),
      KpiTile(label: 'خارجية', value: n('external'), icon: Icons.public_rounded, color: placeShiftEvening),
    ];
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 4),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(width: 128, child: tiles[i]),
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});
  final BookingFilters initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final BookingFilters _f = widget.initial;

  Widget _group(String title, List<String?> options, String? value, String Function(String?) label, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: placeInk)),
        const SizedBox(height: 8),
        ChoicePills<String?>(options: options, value: value, labelOf: label, onChanged: (v) => setState(() => onChanged(v))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 16),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('فلاتر متقدّمة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _f
                          ..shift = null
                          ..origin = null
                          ..paymentStatus = null
                          ..paymentMethod = null
                          ..from = null
                          ..to = null
                          ..property = null;
                      }),
                      child: const Text('مسح الكل'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('المكان', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: placeInk)),
                const SizedBox(height: 8),
                StaffCard(
                  radius: StaffRadius.md,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
                  onTap: () async {
                    final p = await pickProperty(context, approvedOnly: false);
                    if (p != null) setState(() => _f.property = p);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.home_work_rounded, size: 20, color: _f.property == null ? placeInk3 : placeBrass),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _f.property == null ? 'كل الأماكن' : '${_f.property!['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk),
                        ),
                      ),
                      if (_f.property != null)
                        IconButton(tooltip: 'مسح', onPressed: () => setState(() => _f.property = null), icon: const Icon(Icons.close_rounded, size: 20))
                      else
                        const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.expand_more_rounded, color: placeInk3)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('تاريخ البداية', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: placeInk)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DateField(
                        label: 'من',
                        date: _f.from,
                        onTap: () async {
                          final d = await pickDay(context, initial: _f.from);
                          if (d != null) setState(() => _f.from = d);
                        },
                        onClear: () => setState(() => _f.from = null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DateField(
                        label: 'إلى',
                        date: _f.to,
                        onTap: () async {
                          final d = await pickDay(context, initial: _f.to ?? _f.from);
                          if (d != null) setState(() => _f.to = d);
                        },
                        onClear: () => setState(() => _f.to = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _group('الشفت', const [null, 'FULL', 'MORNING', 'EVENING'], _f.shift,
                    (v) => v == null ? 'الكل' : shiftShort(v), (v) => _f.shift = v),
                const SizedBox(height: 18),
                _group('المصدر', const [null, 'PLATFORM', 'EXTERNAL'], _f.origin,
                    (v) => v == null ? 'الكل' : originLabel(v), (v) => _f.origin = v),
                const SizedBox(height: 18),
                _group('حالة الدفع', const [null, 'PENDING', 'PAID', 'FAILED', 'REFUNDED'], _f.paymentStatus,
                    (v) => v == null ? 'الكل' : paymentStatusAr(v), (v) => _f.paymentStatus = v),
                const SizedBox(height: 18),
                _group('طريقة الدفع', const [null, 'MANUAL', 'ZAIN_CASH', 'QI_CARD'], _f.paymentMethod,
                    (v) => v == null ? 'الكل' : paymentMethodAr(v), (v) => _f.paymentMethod = v),
              ],
            ),
          ),
          BookingActionBar(
            children: [
              BarButton(
                label: 'تطبيق الفلاتر',
                icon: Icons.check_rounded,
                onPressed: () {
                  if (_f.from != null && _f.to != null && _f.to!.isBefore(_f.from!)) {
                    showToast(context, 'تاريخ «إلى» قبل «من»', error: true);
                    return;
                  }
                  Navigator.pop(context, _f);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
