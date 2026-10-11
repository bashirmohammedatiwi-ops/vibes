import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
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
      'PENDING' => placeWarning,
      'ACCEPTED' => placeSuccess,
      'DECLINED' => placeDanger,
      _ => placeInk3,
    };

/// حالة مشتركة لقوائم مرقّمة مع بحث وفلتر (بنمط slivers).
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

  Widget searchField(String hint) => Pad(
        top: 4,
        bottom: 6,
        child: BookingSearchField(
          controller: search,
          hint: hint,
          onChanged: (_) {
            setState(() {});
            debounce.run(reset);
          },
          onClear: reset,
        ),
      );

  /// صفحة قائمة مرقّمة كاملة: رأس + بحث/فلاتر + عناصر + تحميل المزيد.
  Widget pagedPage({
    required String title,
    String? subtitle,
    required List<Widget> header,
    required String countLabel,
    required Widget Function(Map<String, dynamic> row) itemBuilder,
    required IconData emptyIcon,
    required String emptyTitle,
    String? emptySubtitle,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 300) loadMore();
        return false;
      },
      child: StaffPage(
        title: title,
        subtitle: subtitle,
        onRefresh: load,
        slivers: [
          ...header.map((w) => SliverToBoxAdapter(child: w)),
          if (!loading && error == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 8),
                child: Text('$total $countLabel', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w700)),
              ),
            ),
          ...asyncSlivers(
            loading: loading,
            error: error,
            isEmpty: rows.isEmpty,
            onRetry: load,
            skeletonHeight: 104,
            emptyIcon: emptyIcon,
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle,
            slivers: [
              SliverList.builder(itemCount: rows.length, itemBuilder: (_, i) => itemBuilder(rows[i])),
              SliverToBoxAdapter(child: LoadMoreTile(hasMore: page < totalPages, loading: loadingMore, onPressed: loadMore)),
            ],
          ),
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
    final status = o['status']?.toString();
    showStaffSheet<void>(
      context,
      title: property?['name']?.toString() ?? 'عرض سعر',
      child: Builder(
        builder: (ctx) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusChip(offerStatusLabel(status), color: offerStatusColor(status)),
                  const Spacer(),
                  Text(formatIqd(o['amount']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w900, color: placeInk)),
                ],
              ),
              const SizedBox(height: 12),
              StaffCard(
                child: Column(
                  children: [
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
              ),
              if (customer?['phone'] != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => callPhone(context, '${customer!['phone']}'),
                    icon: const Icon(Icons.call_rounded, size: 18, color: placeSuccess),
                    label: const Text('اتصال بالزبون'),
                  ),
                ),
              ],
              if (o['bookingId'] != null && canReadBookings) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return pagedPage(
      title: 'عروض الأسعار',
      subtitle: 'عروض المزوّدين للزبائن',
      countLabel: 'عرض',
      emptyIcon: Icons.local_offer_outlined,
      emptyTitle: 'لا عروض أسعار',
      emptySubtitle: 'لا توجد عروض مطابقة لهذا الفلتر',
      header: [
        searchField('هاتف الزبون أو اسم المكان'),
        SegmentFilter<String>(
          options: const ['ALL', 'PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED'],
          value: _status,
          labelOf: (s) => s == 'ALL' ? 'الكل' : offerStatusLabel(s),
          colorOf: (s) => s == 'ALL' ? null : offerStatusColor(s),
          onChanged: (s) {
            setState(() => _status = s);
            reset();
          },
        ),
      ],
      itemBuilder: (o) => _OfferCard(offer: o, onTap: () => _details(o)),
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
    final status = o['status']?.toString();
    return Pad(
      bottom: 10,
      child: StaffCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(icon: Icons.local_offer_rounded, color: offerStatusColor(status), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asMap(o['property'])?['name']?.toString() ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                      Text(
                        '${provider?['businessName'] ?? 'مزوّد'} ← ${customer?['name'] ?? customer?['phone'] ?? 'زبون'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(offerStatusLabel(status), color: offerStatusColor(status), dense: true),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: placeLineSoft),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(formatIqd(o['amount']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                const SizedBox(width: 8),
                BookingShiftChip(shift: o['shift']?.toString()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fmtRange(o['startDate'], o['endDate']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return pagedPage(
      title: 'قوائم الزبائن',
      subtitle: 'المفضلة والقوائم المحفوظة',
      countLabel: 'قائمة',
      emptyIcon: Icons.collections_bookmark_outlined,
      emptyTitle: 'لا قوائم محفوظة',
      header: [
        searchField('اسم القائمة أو الزبون أو الهاتف'),
        SegmentFilter<String>(
          options: const ['ALL', 'PUBLIC', 'PRIVATE'],
          value: _visibility,
          labelOf: (s) => switch (s) {
            'PUBLIC' => 'عامة',
            'PRIVATE' => 'خاصة',
            _ => 'الكل',
          },
          onChanged: (s) {
            setState(() => _visibility = s);
            reset();
          },
        ),
      ],
      itemBuilder: (c) => Pad(
        bottom: 10,
        child: StaffCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CollectionDetailScreen(collectionId: '${c['id']}')),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: NetImage(url: mediaUrl(c['coverUrl']?.toString()), icon: Icons.collections_bookmark_outlined, radius: StaffRadius.md),
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
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
                          ),
                        ),
                        if (c['isDefault'] == true) ...[
                          const SizedBox(width: 6),
                          const StatusChip('المفضلة', color: placeBrass, dense: true),
                        ],
                      ],
                    ),
                    Text(
                      [asMap(c['user'])?['name'], asMap(c['user'])?['phone']].whereType<Object>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip('${asMap(c['_count'])?['items'] ?? 0} مكان', color: placeInk, dense: true),
                        StatusChip(
                          c['visibility'] == 'PUBLIC' ? 'عامة' : 'خاصة',
                          color: c['visibility'] == 'PUBLIC' ? placeSuccess : placeInk2,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: placeInk3),
            ],
          ),
        ),
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
    final phone = user?['phone']?.toString();
    return StaffPage(
      title: c?['name']?.toString() ?? 'القائمة',
      subtitle: c == null ? null : '${items.length} مكان · ${c['visibility'] == 'PUBLIC' ? 'عامة' : 'خاصة'}',
      onRefresh: _load,
      slivers: [
        ...asyncSlivers(
          loading: _loading,
          error: _error,
          isEmpty: c == null,
          onRetry: _load,
          skeletonCount: 4,
          emptyIcon: Icons.collections_bookmark_outlined,
          emptyTitle: 'القائمة غير موجودة',
          slivers: c == null
              ? const []
              : [
                  if ((c['description']?.toString() ?? '').isNotEmpty)
                    SliverToBoxAdapter(
                      child: Pad(
                        top: 4,
                        child: Text('${c['description']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: placeInk2, height: 1.6)),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Pad(
                      top: 4,
                      child: StaffCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Avatar('${user?['name'] ?? '؟'}', size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${user?['name'] ?? 'بدون اسم'}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                                      if (phone != null)
                                        Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2)),
                                    ],
                                  ),
                                ),
                                if (phone != null)
                                  RoundIconAction(icon: Icons.call_rounded, color: placeSuccess, tooltip: 'اتصال', onTap: () => callPhone(context, phone)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 4),
                            InfoLine(icon: Icons.visibility_outlined, label: 'الظهور', value: c['visibility'] == 'PUBLIC' ? 'عامة' : 'خاصة'),
                            InfoLine(icon: Icons.add_circle_outline_rounded, label: 'أُنشئت', value: fmtStamp(c['createdAt'])),
                            InfoLine(icon: Icons.update_rounded, label: 'آخر تحديث', value: fmtStamp(c['updatedAt'])),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SectionHeader('الأماكن', count: items.length)),
                  if (items.isEmpty)
                    const SliverToBoxAdapter(child: EmptyView(icon: Icons.inbox_outlined, title: 'القائمة فارغة'))
                  else
                    SliverToBoxAdapter(
                      child: Pad(
                        child: TileGroup(
                          children: [
                            for (final item in items)
                              TaskTile(
                                icon: placeTypeIcon(asMap(item['property'])?['type']?.toString()),
                                color: placeBrass,
                                title: '${asMap(item['property'])?['name'] ?? '—'}',
                                subtitle: [
                                  placeTypeLabel(asMap(item['property'])?['type']?.toString()),
                                  asMap(asMap(item['property'])?['city'])?['nameAr'],
                                  'أُضيف ${fmtStamp(item['createdAt'])}',
                                  if ((item['note']?.toString() ?? '').isNotEmpty) '“${item['note']}”',
                                ].whereType<Object>().join(' · '),
                                trailing: const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}
