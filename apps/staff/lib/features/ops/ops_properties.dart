import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/kit.dart';
import '../../widgets/ui.dart';
import 'property_detail.dart';
import 'property_editor.dart';

/// الأماكن: بحث وفلترة، فتح صفحة المكان، إضافة مكان جديد، واعتماد/تعليق سريع.
class OpsPropertiesScreen extends StatefulWidget {
  const OpsPropertiesScreen({super.key});

  @override
  State<OpsPropertiesScreen> createState() => _OpsPropertiesScreenState();
}

class _OpsPropertiesScreenState extends State<OpsPropertiesScreen> {
  List<dynamic> _rows = [];
  String _status = 'ALL';
  String _type = 'ALL';
  String _q = '';
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  final _search = TextEditingController();

  bool get _canWrite => Session.can('properties.write');
  bool get _canModerate => Session.can('properties.moderate');

  @override
  void initState() {
    super.initState();
    // المعتمِد يبدأ من «بانتظار» كما كان، وغيره من «الكل»
    _status = _canModerate ? 'PENDING' : 'ALL';
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final params = <String>[
        if (_status != 'ALL') 'status=$_status',
        if (_q.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(_q.trim())}',
      ];
      final path = '/api/staff/properties${params.isEmpty ? '' : '?${params.join('&')}'}';
      _rows = await Api.list(path);
      _error = null;
    } catch (e) {
      _rows = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String v) {
    setState(() {}); // لإظهار/إخفاء زر المسح
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _q = v;
      _load(silent: true);
    });
  }

  Future<void> _setStatus(String id, String status) async {
    String? reason;
    if (status == 'REJECTED' || status == 'SUSPENDED') {
      reason = await promptText(context, title: 'سبب القرار');
      if (reason == null) return;
    }
    try {
      await Api.send('/api/staff/properties/$id/status', method: 'POST', body: {'status': status, if (reason != null) 'reason': reason});
      await _load(silent: true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: id)));
    if (mounted) _load(silent: true);
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PropertyEditorScreen()));
    if (mounted) _load(silent: true);
  }

  List<dynamic> get _filtered => _type == 'ALL' ? _rows : _rows.where((r) => r is Map && r['type'] == _type).toList();

  static const _types = ['ALL', 'FARM', 'HALL', 'DECORATION'];

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return StaffPage(
      title: 'الأماكن',
      subtitle: _loading ? 'جارٍ التحميل…' : '${rows.length} مكان${_status == 'ALL' ? '' : ' · ${placeStatusLabel(_status)}'}',
      onRefresh: () => _load(silent: true),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_home_work_rounded),
              label: const Text(
                'مكان جديد',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
              ),
            )
          : null,
      slivers: [
        if (!_canWrite && !_canModerate)
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: StaffCard(
                color: placeGoldSoft,
                borderColor: placeGold.withValues(alpha: .35),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: placeBrass, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'صلاحية «عرض الأماكن» فقط — لإضافة أو تعديل مكان اطلب «إضافة وتعديل الأماكن» من المشرف.',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: placeInk, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Pad(
            top: 4,
            bottom: 0,
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف',
                prefixIcon: const Icon(Icons.search_rounded, color: placeInk2),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _q = '';
                          setState(() {});
                          _load(silent: true);
                        },
                      ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: FilterChipsRow(
            options: const ['ALL', 'PENDING', 'APPROVED', 'DRAFT', 'SUSPENDED', 'REJECTED'],
            selected: _status,
            labelBuilder: (s) => s == 'ALL' ? 'كل الحالات' : placeStatusLabel(s),
            onSelected: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page, vertical: 4),
              itemCount: _types.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _types[i];
                return _TypeChip(
                  label: t == 'ALL' ? 'كل الأنواع' : placeTypeLabel(t),
                  icon: t == 'ALL' ? Icons.apps_rounded : placeTypeIcon(t),
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (_loading)
          const SkeletonSliver(count: 4, height: 250)
        else if (_error != null)
          SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.cloud_off_rounded,
              title: 'تعذّر التحميل',
              subtitle: _error,
              actionLabel: 'إعادة المحاولة',
              onAction: _load,
            ),
          )
        else if (rows.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.villa_outlined,
              title: 'لا أماكن في هذا الفلتر',
              subtitle: 'جرّب حالة أو نوعاً آخر، أو امسح البحث.',
              actionLabel: _canWrite ? 'إضافة مكان' : null,
              onAction: _canWrite ? _create : null,
            ),
          )
        else
          SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: StaffSpace.gap),
            itemBuilder: (context, i) => Pad(
              bottom: 0,
              child: _PropertyCard(
                row: Map<String, dynamic>.from(rows[i] as Map),
                canModerate: _canModerate,
                onOpen: _open,
                onStatus: _setStatus,
              ),
            ),
          ),
        if (_canWrite) const SliverToBoxAdapter(child: SizedBox(height: 72)),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(999);
    return Material(
      color: selected ? placeGoldSoft : Colors.white,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: selected ? placeGold : placeLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? placeBrass : placeInk3),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? placeBrass : placeInk2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.row, required this.canModerate, required this.onOpen, required this.onStatus});

  final Map<String, dynamic> row;
  final bool canModerate;
  final void Function(String id) onOpen;
  final void Function(String id, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString();
    final type = row['type']?.toString();
    final media = row['media'];
    String? cover;
    if (media is List && media.isNotEmpty && media.first is Map) {
      final m = media.first as Map;
      cover = (m['thumbnailUrl'] ?? m['url'])?.toString();
    }
    final mediaCount = media is List ? media.length : 0;
    final city = row['city'] is Map ? (row['city'] as Map)['nameAr']?.toString() ?? '' : '';
    final rating = double.tryParse('${row['ratingAvg'] ?? 0}') ?? 0;
    final provider = row['provider'] is Map ? (row['provider'] as Map)['businessName']?.toString() ?? '' : '';
    final showActions = canModerate && (status == 'PENDING' || status == 'DRAFT' || status == 'SUSPENDED' || status == 'APPROVED');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: placeLine),
        boxShadow: staffCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => onOpen(id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── الغلاف + الحالة ──
              SizedBox(
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: cover, radius: 0, icon: placeTypeIcon(type)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x330F1B2D), Color(0x000F1B2D), Color(0x660F1B2D)],
                          stops: [0, .45, 1],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: _Glass(
                        child: StatusPill(label: placeStatusLabel(status), color: placeStatusColor(status)),
                      ),
                    ),
                    if (row['featured'] == true)
                      const PositionedDirectional(
                        top: 10,
                        end: 10,
                        child: _Glass(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 15, color: placeBrass),
                                SizedBox(width: 4),
                                Text(
                                  'مميّز',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: placeBrass),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      bottom: 10,
                      start: 12,
                      child: Row(
                        children: [
                          Icon(placeTypeIcon(type), size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            [placeTypeLabel(type), city].where((e) => e.isNotEmpty && e != '—').join(' · '),
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    if (mediaCount > 1)
                      PositionedDirectional(
                        bottom: 10,
                        end: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$mediaCount',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // ── الاسم والأرقام ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: placeInk),
                    ),
                    if (provider.isNotEmpty)
                      Text(
                        'المزوّد: $provider',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Stat(icon: Icons.sell_rounded, text: '${formatIqd(row['pricePerDay'])} / يوم'),
                        const SizedBox(width: 14),
                        if (rating > 0) _Stat(icon: Icons.star_rounded, text: rating.toStringAsFixed(1), color: placeBrass),
                        const Spacer(),
                        const Icon(Icons.chevron_left_rounded, color: placeInk3),
                      ],
                    ),
                  ],
                ),
              ),
              if (showActions) ...[
                const Divider(height: 1, color: placeLineSoft),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      if (status == 'PENDING' || status == 'DRAFT')
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: placeSuccess),
                            onPressed: () => onStatus(id, 'APPROVED'),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('اعتماد'),
                          ),
                        ),
                      if (status == 'SUSPENDED')
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => onStatus(id, 'APPROVED'),
                            icon: const Icon(Icons.publish_rounded, size: 18),
                            label: const Text('إعادة نشر'),
                          ),
                        ),
                      if (status != 'SUSPENDED') ...[
                        if (status != 'APPROVED') const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onStatus(id, 'SUSPENDED'),
                            icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                            label: const Text('تعليق'),
                          ),
                        ),
                      ],
                      if (status == 'PENDING') ...[
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: placeDanger),
                          onPressed: () => onStatus(id, 'REJECTED'),
                          child: const Text('رفض'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color = placeInk2});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: placeInk),
        ),
      ],
    );
  }
}

/// خلفية بيضاء شبه شفافة للشارات فوق الصور.
class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(999)),
      child: child,
    );
  }
}
