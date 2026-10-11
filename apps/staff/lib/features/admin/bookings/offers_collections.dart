import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'booking_kit.dart';
import 'booking_manage.dart';

String offerStatusLabel(String? s) => switch (s) {
      'PENDING' => 'بانتظار رد الزبون',
      'ACCEPTED' => 'مقبول',
      'DECLINED' => 'مرفوض',
      'EXPIRED' => 'منتهي',
      _ => s ?? '—',
    };

Color offerStatusColor(String? s) => switch (s) {
      'PENDING' => placeShiftMorning,
      'ACCEPTED' => placeSuccess,
      'DECLINED' => placeDanger,
      _ => placeInk2,
    };

/// حالة مشتركة لقوائم مرقّمة مع بحث وفلتر.
mixin _PagedSearch<T extends StatefulWidget> on State<T> {
  final search = TextEditingController();
  final debounce = Debouncer();
  List<Map<String, dynamic>> rows = [];
  int page = 1;
  int totalPages = 1;
  int total = 0;
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int _seq = 0;

  String endpoint(int page);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    debounce.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final seq = ++_seq;
    setState(() {
      loading = rows.isEmpty;
      error = null;
    });
    try {
      final data = await Api.send(endpoint(1));
      if (!mounted || seq != _seq) return;
      rows = pagedItems(data);
      page = 1;
      totalPages = pagedTotalPages(data);
      total = pagedTotal(data);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      error = errorText(e);
      rows = [];
    }
    if (mounted && seq == _seq) setState(() => loading = false);
  }

  void reset() {
    setState(() => rows = []);
    load();
  }

  Future<void> loadMore() async {
    if (loadingMore || page >= totalPages) return;
    setState(() => loadingMore = true);
    final seq = _seq;
    try {
      final data = await Api.send(endpoint(page + 1));
      if (!mounted || seq != _seq) return;
      rows.addAll(pagedItems(data));
      page++;
      totalPages = pagedTotalPages(data);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => loadingMore = false);
  }

  Widget searchField(String hint) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          controller: search,
          onChanged: (_) => debounce.run(reset),
          decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded)),
        ),
      );

  Widget scrollBody({
    required List<Widget> header,
    required List<Widget> children,
    required String emptyTitle,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) loadMore();
        return false;
      },
      child: AsyncList(
        loading: loading,
        error: error,
        isEmpty: rows.isEmpty,
        onRefresh: load,
        emptyTitle: emptyTitle,
        header: header,
        children: [
          ...children,
          LoadMoreTile(hasMore: page < totalPages, loading: loadingMore, onPressed: loadMore),
        ],
      ),
    );
  }
}

// ───────────────────────── عروض الأسعار ─────────────────────────

/// عروض الأسعار التي يرسلها المزوّدون للزبائن (`GET /api/admin/offers`) — `bookings.read`. للعرض فقط.
class PriceOffersScreen extends StatefulWidget {
  const PriceOffersScreen({super.key});

  @override
  State<PriceOffersScreen> createState() => _PriceOffersScreenState();
}

class _PriceOffersScreenState extends State<PriceOffersScreen> with _PagedSearch {
  String _status = 'ALL';

  @override
  String endpoint(int page) => '/api/admin/offers${buildQuery({
        'status': _status == 'ALL' ? null : _status,
        'q': search.text,
        'page': '$page',
        'pageSize': '20',
      })}';

  void _details(Map<String, dynamic> o) {
    final property = asMap(o['property']);
    final customer = asMap(o['customer']);
    final provider = asMap(o['provider']);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: placePaper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        property?['name']?.toString() ?? 'عرض سعر',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    StatusPill(label: offerStatusLabel(o['status']?.toString()), color: offerStatusColor(o['status']?.toString())),
                  ],
                ),
              ),
              FormSection(
                title: 'تفاصيل العرض',
                icon: Icons.local_offer_outlined,
                children: [
                  InfoLine(icon: Icons.attach_money_rounded, label: 'المبلغ', value: formatIqd(o['amount'])),
                  InfoLine(icon: Icons.event_outlined, label: 'الموعد', value: fmtRange(o['startDate'], o['endDate'])),
                  InfoLine(icon: Icons.schedule_rounded, label: 'الشفت', value: shiftShort(o['shift']?.toString())),
                  InfoLine(icon: Icons.storefront_outlined, label: 'المزوّد', value: provider?['businessName']?.toString() ?? '—'),
                  InfoLine(
                    icon: Icons.person_outline_rounded,
                    label: 'الزبون',
                    value: [customer?['name'], customer?['phone']].whereType<Object>().join(' · '),
                  ),
                  InfoLine(icon: Icons.add_circle_outline_rounded, label: 'أُرسل', value: fmtStamp(o['createdAt'])),
                  if (o['expiresAt'] != null) InfoLine(icon: Icons.timer_off_outlined, label: 'ينتهي', value: fmtStamp(o['expiresAt'])),
                  if ((o['message']?.toString() ?? '').isNotEmpty)
                    InfoLine(icon: Icons.chat_bubble_outline_rounded, label: 'الرسالة', value: '${o['message']}'),
                ],
              ),
              if (o['bookingId'] != null && canReadBookings)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BookingManageScreen(bookingId: '${o['bookingId']}')),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('فتح الحجز الناتج'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عروض الأسعار')),
      body: scrollBody(
        emptyTitle: 'لا عروض أسعار',
        header: [
          searchField('هاتف الزبون أو اسم المكان'),
          FilterChipsRow(
            options: const ['ALL', 'PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED'],
            selected: _status,
            labelBuilder: (s) => s == 'ALL' ? 'الكل' : offerStatusLabel(s),
            onSelected: (s) {
              setState(() => _status = s);
              reset();
            },
          ),
          if (!loading && error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('$total عرض', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w700)),
            ),
        ],
        children: [for (final o in rows) _OfferCard(offer: o, onTap: () => _details(o))],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final customer = asMap(o['customer']);
    final provider = asMap(o['provider']);
    return _Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asMap(o['property'])?['name']?.toString() ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(label: offerStatusLabel(o['status']?.toString()), color: offerStatusColor(o['status']?.toString())),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${provider?['businessName'] ?? 'مزوّد'} ← ${customer?['name'] ?? customer?['phone'] ?? 'زبون'}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(formatIqd(o['amount']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              ShiftBadge(shift: o['shift']?.toString()),
              const Spacer(),
              Text(fmtRange(o['startDate'], o['endDate']),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── القوائم المحفوظة ─────────────────────────

/// قوائم الزبائن المحفوظة (`GET /api/admin/collections`) — لا تتطلب صلاحية خاصة. للعرض فقط.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> with _PagedSearch {
  String _visibility = 'ALL';

  @override
  String endpoint(int page) => '/api/admin/collections${buildQuery({
        'visibility': _visibility == 'ALL' ? null : _visibility,
        'q': search.text,
        'page': '$page',
        'pageSize': '20',
      })}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قوائم الزبائن')),
      body: scrollBody(
        emptyTitle: 'لا قوائم محفوظة',
        header: [
          searchField('اسم القائمة أو الزبون أو الهاتف'),
          FilterChipsRow(
            options: const ['ALL', 'PUBLIC', 'PRIVATE'],
            selected: _visibility,
            labelBuilder: (s) => switch (s) {
              'PUBLIC' => 'عامة',
              'PRIVATE' => 'خاصة',
              _ => 'الكل',
            },
            onSelected: (s) {
              setState(() => _visibility = s);
              reset();
            },
          ),
          if (!loading && error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('$total قائمة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w700)),
            ),
        ],
        children: [
          for (final c in rows)
            _Card(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CollectionDetailScreen(collectionId: '${c['id']}')),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: NetImage(url: mediaUrl(c['coverUrl']?.toString()), icon: Icons.collections_bookmark_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${c['name'] ?? '—'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (c['isDefault'] == true) ...[
                              const SizedBox(width: 6),
                              const StatusPill(label: 'المفضلة', color: placeBrass),
                            ],
                          ],
                        ),
                        Text(
                          [asMap(c['user'])?['name'], asMap(c['user'])?['phone']].whereType<Object>().join(' · '),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            StatusPill(label: '${asMap(c['_count'])?['items'] ?? 0} مكان', color: placeInk),
                            const SizedBox(width: 6),
                            StatusPill(
                              label: c['visibility'] == 'PUBLIC' ? 'عامة' : 'خاصة',
                              color: c['visibility'] == 'PUBLIC' ? placeSuccess : placeInk2,
                              icon: c['visibility'] == 'PUBLIC' ? Icons.public_rounded : Icons.lock_outline_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: placeInk2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// تفاصيل قائمة محفوظة (`GET /api/admin/collections/:id`).
class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      _data = await Api.map('/api/admin/collections/${widget.collectionId}');
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _data;
    final items = [for (final i in (c?['items'] as List? ?? const [])) if (i is Map) Map<String, dynamic>.from(i)];
    final user = asMap(c?['user']);
    return Scaffold(
      appBar: AppBar(title: Text(c?['name']?.toString() ?? 'القائمة')),
      body: AsyncList(
        loading: _loading,
        error: _error,
        isEmpty: c == null,
        onRefresh: _load,
        children: c == null
            ? const []
            : [
                FormSection(
                  title: '${c['name'] ?? ''}',
                  subtitle: (c['description']?.toString() ?? '').isEmpty ? null : '${c['description']}',
                  icon: Icons.collections_bookmark_outlined,
                  children: [
                    InfoLine(icon: Icons.person_outline_rounded, label: 'الزبون', value: '${user?['name'] ?? 'بدون اسم'}'),
                    if (user?['phone'] != null) InfoLine(icon: Icons.phone_outlined, label: 'الهاتف', value: '${user!['phone']}', ltr: true),
                    InfoLine(icon: Icons.visibility_outlined, label: 'الظهور', value: c['visibility'] == 'PUBLIC' ? 'عامة' : 'خاصة'),
                    InfoLine(icon: Icons.add_circle_outline_rounded, label: 'أُنشئت', value: fmtStamp(c['createdAt'])),
                    InfoLine(icon: Icons.update_rounded, label: 'آخر تحديث', value: fmtStamp(c['updatedAt'])),
                  ],
                ),
                SectionLabel('الأماكن (${items.length})'),
                if (items.isEmpty) const EmptyState(title: 'القائمة فارغة'),
                for (final item in items)
                  _Card(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: placeBrass.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(placeTypeIcon(asMap(item['property'])?['type']?.toString()), color: placeBrass),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${asMap(item['property'])?['name'] ?? '—'}',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                [
                                  placeTypeLabel(asMap(item['property'])?['type']?.toString()),
                                  asMap(asMap(item['property'])?['city'])?['nameAr'],
                                  'أُضيف ${fmtStamp(item['createdAt'])}',
                                ].whereType<Object>().join(' · '),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2, fontWeight: FontWeight.w600),
                              ),
                              if ((item['note']?.toString() ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('“${item['note']}”', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: placeLine)),
            child: child,
          ),
        ),
      ),
    );
  }
}
