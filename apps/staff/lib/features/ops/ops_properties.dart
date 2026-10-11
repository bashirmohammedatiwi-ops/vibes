import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
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
      await Api.send(
        '/api/staff/properties/$id/status',
        method: 'POST',
        body: {'status': status, if (reason != null) 'reason': reason},
      );
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

  List<dynamic> get _filtered =>
      _type == 'ALL' ? _rows : _rows.where((r) => r is Map && r['type'] == _type).toList();

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('الأماكن')),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_home_work_outlined),
              label: const Text('مكان جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      body: Column(
        children: [
          if (!_canWrite && !_canModerate)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'صلاحية «عرض الأماكن» فقط — لإضافة أو تعديل مكان اطلب «إضافة وتعديل الأماكن» من المشرف.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, height: 1.35),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
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
          FilterChipsRow(
            options: const ['ALL', 'PENDING', 'APPROVED', 'DRAFT', 'SUSPENDED', 'REJECTED'],
            selected: _status,
            labelBuilder: (s) => s == 'ALL' ? 'الكل' : placeStatusLabel(s),
            onSelected: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in const ['ALL', 'FARM', 'HALL', 'DECORATION'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(t == 'ALL' ? 'كل الأنواع' : placeTypeLabel(t)),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                      selectedColor: placeBrass.withValues(alpha: 0.2),
                      side: BorderSide(color: _type == t ? placeBrass : placeLine),
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12.5),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: _loading
                  ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator(color: placeBrass))])
                  : _error != null
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          EmptyState(title: 'تعذّر التحميل', subtitle: _error),
                        ])
                      : rows.isEmpty
                          ? ListView(children: const [SizedBox(height: 60), EmptyState(title: 'لا أماكن في هذا الفلتر')])
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, _canWrite ? 100 : 24),
                              itemCount: rows.length,
                              itemBuilder: (context, i) => _PropertyCard(
                                row: Map<String, dynamic>.from(rows[i] as Map),
                                canModerate: _canModerate,
                                onOpen: _open,
                                onStatus: _setStatus,
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.row,
    required this.canModerate,
    required this.onOpen,
    required this.onStatus,
  });

  final Map<String, dynamic> row;
  final bool canModerate;
  final void Function(String id) onOpen;
  final void Function(String id, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString();
    final media = row['media'];
    String? cover;
    if (media is List && media.isNotEmpty && media.first is Map) {
      final m = media.first as Map;
      cover = (m['thumbnailUrl'] ?? m['url'])?.toString();
    }
    final city = row['city'] is Map ? (row['city'] as Map)['nameAr']?.toString() ?? '' : '';
    final rating = double.tryParse('${row['ratingAvg'] ?? 0}') ?? 0;
    final provider = row['provider'] is Map ? (row['provider'] as Map)['businessName']?.toString() ?? '' : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
      ),
      child: InkWell(
        onTap: () => onOpen(id),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(width: 88, height: 88, child: NetImage(url: cover, radius: 14, icon: placeTypeIcon(row['type']?.toString()))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row['name']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: placeInk),
                              ),
                            ),
                            if (row['featured'] == true) const Icon(Icons.workspace_premium_rounded, size: 18, color: placeBrass),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [placeTypeLabel(row['type']?.toString()), city].where((e) => e.isNotEmpty).join(' · '),
                          style: const TextStyle(color: placeInk2, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatIqd(row['pricePerDay']),
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13.5, color: placeInk),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            StatusPill(label: placeStatusLabel(status), color: placeStatusColor(status)),
                            const SizedBox(width: 8),
                            if (rating > 0) ...[
                              const Icon(Icons.star_rounded, size: 15, color: placeBrass),
                              Text(' ${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (provider.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('المزوّد: $provider', style: const TextStyle(fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600)),
                ),
              if (canModerate && (status == 'PENDING' || status == 'DRAFT' || status == 'SUSPENDED' || status == 'APPROVED'))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (status == 'PENDING' || status == 'DRAFT')
                        FilledButton(
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                          onPressed: () => onStatus(id, 'APPROVED'),
                          child: const Text('اعتماد'),
                        ),
                      if (status == 'SUSPENDED')
                        FilledButton(
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                          onPressed: () => onStatus(id, 'APPROVED'),
                          child: const Text('إعادة نشر'),
                        ),
                      if (status != 'SUSPENDED')
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                          onPressed: () => onStatus(id, 'SUSPENDED'),
                          child: const Text('تعليق'),
                        ),
                      if (status == 'PENDING')
                        TextButton(
                          onPressed: () => onStatus(id, 'REJECTED'),
                          child: const Text('رفض'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
