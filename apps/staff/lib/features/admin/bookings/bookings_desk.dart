import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';
import 'booking_wizard.dart';
import 'bookings_calendar.dart';
import 'bookings_list.dart';
import 'offers_collections.dart';

/// مكتب الحجوزات — نقطة الدخول لإدارة الحجوزات من الهاتف (بديل لوحة الويب).
///
/// كل بطاقة تظهر حسب الصلاحية:
/// - حجز جديد: `bookings.write`
/// - كل الحجوزات + الإحصاءات + التقويم + عروض الأسعار + البحث السريع: `bookings.read`
/// - قوائم الزبائن: بدون صلاحية خاصة
class BookingsDeskScreen extends StatefulWidget {
  const BookingsDeskScreen({super.key});

  /// هل تُعرض بطاقة المكتب في القائمة الرئيسية؟
  static bool get isVisible => canReadBookings || canWriteBookings;

  @override
  State<BookingsDeskScreen> createState() => _BookingsDeskScreenState();
}

class _BookingsDeskScreenState extends State<BookingsDeskScreen> {
  Map<String, dynamic>? _stats;
  String? _statsError;
  bool _loading = true;

  final _search = TextEditingController();
  final _debounce = Debouncer();
  List<Map<String, dynamic>> _hits = [];
  bool _searching = false;

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
      setState(() => _loading = false);
      return;
    }
    try {
      _stats = await Api.map('/api/admin/bookings/stats');
      _statsError = null;
    } catch (e) {
      _statsError = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _hits = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final data = await Api.map('/api/admin/search${buildQuery({'q': q})}');
      if (!mounted || _search.text.trim() != q.trim()) return;
      _hits = [for (final b in (data['bookings'] as List? ?? const [])) if (b is Map) Map<String, dynamic>.from(b)];
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _push(Widget page) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_DeskTile>[
      if (canWriteBookings)
        _DeskTile(
          icon: Icons.add_circle_outline_rounded,
          title: 'حجز جديد',
          subtitle: 'نيابةً عن زبون مع سعر فوري',
          highlight: true,
          onTap: () => _push(const NewBookingWizardScreen()),
        ),
      if (canReadBookings) ...[
        _DeskTile(
          icon: Icons.view_list_rounded,
          title: 'كل الحجوزات',
          subtitle: 'فلاتر متقدّمة وإجراءات جماعية',
          onTap: () => _push(const AdminBookingsListScreen()),
        ),
        _DeskTile(
          icon: Icons.calendar_month_outlined,
          title: 'التقويم',
          subtitle: 'الإشغال اليومي حسب الشفت',
          onTap: () => _push(const BookingsCalendarScreen()),
        ),
        _DeskTile(
          icon: Icons.hourglass_top_rounded,
          title: 'بانتظار التأكيد',
          subtitle: 'حجوزات تحتاج إجراء',
          badge: (asNum(_stats?['pending']) ?? 0).toInt(),
          onTap: () => _push(const AdminBookingsListScreen(initialStatus: 'PENDING')),
        ),
        _DeskTile(
          icon: Icons.local_offer_outlined,
          title: 'عروض الأسعار',
          subtitle: 'عروض المزوّدين للزبائن',
          onTap: () => _push(const PriceOffersScreen()),
        ),
      ],
      _DeskTile(
        icon: Icons.collections_bookmark_outlined,
        title: 'قوائم الزبائن',
        subtitle: 'المفضلة والقوائم المحفوظة',
        onTap: () => _push(const CollectionsScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('مكتب الحجوزات')),
      body: RefreshIndicator(
        color: placeBrass,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const MaisonHeader(title: 'الحجوزات', subtitle: 'إنشاء، متابعة، جدولة، وملاحظات الفريق'),
            if (canReadBookings) ...[
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: placeBrass)),
                )
              else if (_statsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(_statsError!, style: const TextStyle(fontFamily: 'Cairo', color: placeDanger)),
                )
              else
                _statsBlock(),
              _searchBlock(),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.02,
                children: tiles,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsBlock() {
    final s = _stats ?? const {};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              StatTile(label: 'بانتظار التأكيد', value: '${s['pending'] ?? 0}', accent: placeShiftMorning),
              const SizedBox(width: 8),
              StatTile(label: 'مؤكدة', value: '${s['confirmed'] ?? 0}', accent: placeSuccess),
              const SizedBox(width: 8),
              StatTile(label: 'الإجمالي', value: '${s['total'] ?? 0}'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: placeInk,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: placeBrass),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'إيراد الحجوزات المؤكدة والمكتملة',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatIqd(s['revenue']),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              StatusPill(label: 'مكتملة ${s['completed'] ?? 0}', color: const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              StatusPill(label: 'خارجية ${s['external'] ?? 0}', color: placeShiftEvening),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (v) {
              setState(() {});
              _debounce.run(() => _runSearch(v));
            },
            decoration: InputDecoration(
              hintText: 'بحث سريع عن حجز: هاتف، اسم، مكان',
              prefixIcon: const Icon(Icons.manage_search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() {
                            _search.clear();
                            _hits = [];
                          }),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
            ),
          ),
        ),
        if (_search.text.trim().length >= 2 && !_searching && _hits.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text('لا حجوزات مطابقة', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
          ),
        for (final b in _hits)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: placeLine)),
                onTap: () => _push(BookingManageScreen(bookingId: '${b['id']}')),
                title: Text(
                  '${asMap(b['property'])?['name'] ?? 'حجز'}',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [
                    guestName(b),
                    ?guestPhone(b),
                    if (parseDay(b['startDate']) != null) fmtShortDay(parseDay(b['startDate'])!),
                  ].join(' · '),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
                trailing: BookingStatusPill(status: b['status']?.toString()),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeskTile extends StatelessWidget {
  const _DeskTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : placeInk;
    return Material(
      color: highlight ? placeInk : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: highlight ? placeInk : placeLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: highlight ? placeBrass.withValues(alpha: 0.25) : placeInk.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: highlight ? placeBrass : placeInk, size: 22),
                  ),
                  const Spacer(),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: placeBrass, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '$badge',
                        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: highlight ? Colors.white70 : placeInk2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
