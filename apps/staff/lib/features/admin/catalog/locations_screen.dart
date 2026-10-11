import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'catalog_common.dart';

/// المحافظات والمدن — عرض للجميع، وإضافة/تعديل/حذف/صورة بصلاحية locations.write.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _search = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _expanded = {};

  List<Map<String, dynamic>> _provinces = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String? _uploadingId;
  double _uploadProgress = 0;
  bool _busy = false;

  bool get _canWrite => Session.can('locations.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_provinces.isEmpty) _loading = true;
    });
    try {
      final rows = await Api.list('/api/admin/locations/provinces');
      if (!mounted) return;
      setState(() {
        _provinces = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  List<Map<String, dynamic>> _citiesOf(Map<String, dynamic> p) =>
      (p['cities'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  int _cityCount(Map<String, dynamic> p) =>
      (p['_count'] is Map ? asNum(p['_count']['cities']).toInt() : null) ?? _citiesOf(p).length;

  bool _matches(Map<String, dynamic> m) {
    final q = _q.toLowerCase();
    return '${m['nameAr'] ?? ''}'.toLowerCase().contains(q) || '${m['nameEn'] ?? ''}'.toLowerCase().contains(q);
  }

  /// يعيد المحافظات المطابقة مع المدن المطابقة (أو كل المدن إن طابقت المحافظة نفسها).
  List<(Map<String, dynamic>, List<Map<String, dynamic>>, bool)> get _visible {
    final out = <(Map<String, dynamic>, List<Map<String, dynamic>>, bool)>[];
    for (final p in _provinces) {
      final cities = _citiesOf(p);
      if (_q.isEmpty || _matches(p)) {
        out.add((p, cities, false));
        continue;
      }
      final hits = cities.where(_matches).toList();
      if (hits.isNotEmpty) out.add((p, hits, true));
    }
    return out;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showToast(context, success);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── المحافظات ─────────

  Future<void> _addProvince() async {
    final res = await showNameSheet(context, title: 'محافظة جديدة', confirmLabel: 'إضافة');
    if (res == null) return;
    final nameAr = res['nameAr']!;
    final nameEn = res['nameEn']!.isEmpty ? nameAr : res['nameEn']!;
    await _run(
      () => Api.send('/api/admin/locations/provinces', method: 'POST', body: {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'slug': slugify(res['nameEn']!.isNotEmpty ? res['nameEn']! : nameAr),
      }),
      'تمت إضافة المحافظة',
    );
  }

  Future<void> _renameProvince(Map<String, dynamic> p) async {
    final res = await showNameSheet(
      context,
      title: 'تعديل المحافظة',
      nameAr: '${p['nameAr'] ?? ''}',
      nameEn: '${p['nameEn'] ?? ''}',
    );
    if (res == null) return;
    await _run(
      () => Api.send('/api/admin/locations/provinces/${p['id']}', method: 'PATCH', body: {
        'nameAr': res['nameAr'],
        'nameEn': res['nameEn']!.isEmpty ? res['nameAr'] : res['nameEn'],
      }),
      'تم تعديل المحافظة',
    );
  }

  Future<void> _deleteProvince(Map<String, dynamic> p) async {
    final cities = _cityCount(p);
    if (cities > 0) {
      showToast(context, 'احذف مدن المحافظة ($cities) أولاً', error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'حذف المحافظة',
      message: 'سيتم حذف «${p['nameAr']}» نهائياً. لا يمكن التراجع.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    await _run(
      () => Api.send('/api/admin/locations/provinces/${p['id']}', method: 'DELETE'),
      'تم حذف المحافظة',
    );
  }

  Future<void> _pickImage(Map<String, dynamic> p) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 2200);
    } catch (e) {
      if (mounted) showToast(context, 'تعذّر فتح المعرض', error: true);
      return;
    }
    if (file == null || !mounted) return;
    final id = '${p['id']}';
    setState(() {
      _uploadingId = id;
      _uploadProgress = 0;
    });
    try {
      final media = await Api.uploadFile(
        '/api/media/upload',
        file.path,
        onProgress: (v) {
          if (mounted) setState(() => _uploadProgress = v);
        },
      );
      final url = media is Map ? media['url']?.toString() : null;
      if (url == null || url.isEmpty) throw ApiException('لم يُرجع الخادم رابط الصورة');
      await Api.send('/api/admin/locations/provinces/$id', method: 'PATCH', body: {
        'nameAr': p['nameAr'],
        'nameEn': p['nameEn'] ?? p['nameAr'],
        'imageUrl': url,
      });
      if (mounted) showToast(context, 'تم حفظ صورة المحافظة');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploadingId = null);
    }
  }

  Future<void> _removeImage(Map<String, dynamic> p) async {
    final ok = await confirmDialog(
      context,
      title: 'إزالة الصورة',
      message: 'إزالة صورة «${p['nameAr']}»؟',
      confirmLabel: 'إزالة',
      danger: true,
    );
    if (!ok) return;
    await _run(
      () => Api.send('/api/admin/locations/provinces/${p['id']}', method: 'PATCH', body: {
        'nameAr': p['nameAr'],
        'nameEn': p['nameEn'] ?? p['nameAr'],
        'imageUrl': '',
      }),
      'تمت إزالة الصورة',
    );
  }

  // ───────── المدن ─────────

  Future<void> _addCity(Map<String, dynamic> p) async {
    final res = await showNameSheet(
      context,
      title: 'مدينة جديدة',
      subtitle: 'في محافظة ${p['nameAr']}',
      confirmLabel: 'إضافة',
    );
    if (res == null) return;
    final nameAr = res['nameAr']!;
    await _run(
      () => Api.send('/api/admin/locations/provinces/${p['id']}/cities', method: 'POST', body: {
        'nameAr': nameAr,
        'nameEn': res['nameEn']!.isEmpty ? nameAr : res['nameEn'],
        'slug': slugify(res['nameEn']!.isNotEmpty ? res['nameEn']! : nameAr),
      }),
      'تمت إضافة المدينة',
    );
    _expanded.add('${p['id']}');
  }

  Future<void> _renameCity(Map<String, dynamic> c) async {
    final res = await showNameSheet(
      context,
      title: 'تعديل المدينة',
      nameAr: '${c['nameAr'] ?? ''}',
      nameEn: '${c['nameEn'] ?? ''}',
    );
    if (res == null) return;
    await _run(
      () => Api.send('/api/admin/locations/cities/${c['id']}', method: 'PATCH', body: {
        'nameAr': res['nameAr'],
        'nameEn': res['nameEn']!.isEmpty ? res['nameAr'] : res['nameEn'],
      }),
      'تم تعديل المدينة',
    );
  }

  Future<void> _deleteCity(Map<String, dynamic> c) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف المدينة',
      message: 'سيتم حذف «${c['nameAr']}». لا يمكن حذف مدينة مرتبطة بأماكن.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    await _run(
      () => Api.send('/api/admin/locations/cities/${c['id']}', method: 'DELETE'),
      'تم حذف المدينة',
    );
  }

  Future<void> _cityActions(Map<String, dynamic> c) async {
    if (!_canWrite) return;
    lightTap();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                '${c['nameAr']}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل الاسم'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: placeDanger),
              title: const Text('حذف المدينة', style: TextStyle(color: placeDanger)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'rename') await _renameCity(c);
    if (action == 'delete') await _deleteCity(c);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final totalCities = _provinces.fold<int>(0, (s, p) => s + _cityCount(p));
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحافظات والمدن'),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _addProvince,
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('محافظة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const CatalogLoadingView()
            : _error != null && _provinces.isEmpty
                ? CatalogErrorView(message: _error!, onRetry: _load)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            StatTile(label: 'محافظات', value: fmtCount(_provinces.length)),
                            const SizedBox(width: 10),
                            StatTile(label: 'مدن', value: fmtCount(totalCities), accent: placeBrass),
                          ],
                        ),
                      ),
                      if (!_canWrite) const ReadOnlyBanner(),
                      CatalogSearchField(
                        controller: _search,
                        hint: 'ابحث عن محافظة أو مدينة…',
                        onChanged: (v) => setState(() => _q = v.trim()),
                      ),
                      const SizedBox(height: 6),
                      if (_provinces.isEmpty)
                        const EmptyState(title: 'لا توجد محافظات بعد', subtitle: 'أضف أول محافظة لتظهر في نماذج الأماكن')
                      else if (visible.isEmpty)
                        const EmptyState(title: 'لا نتائج مطابقة', subtitle: 'جرّب اسماً آخر')
                      else
                        for (final (p, cities, cityHit) in visible) _provinceCard(p, cities, cityHit),
                    ],
                  ),
      ),
    );
  }

  Widget _provinceCard(Map<String, dynamic> p, List<Map<String, dynamic>> cities, bool cityHit) {
    final id = '${p['id']}';
    final open = cityHit || _expanded.contains(id);
    final count = _cityCount(p);
    final image = p['imageUrl']?.toString();
    final uploading = _uploadingId == id;
    return CatalogCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              lightTap();
              setState(() => open ? _expanded.remove(id) : _expanded.add(id));
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetImage(url: image, radius: 14, icon: Icons.landscape_outlined),
                        if (uploading)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                value: _uploadProgress > 0 && _uploadProgress < 1 ? _uploadProgress : null,
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['nameAr'] ?? '—'}',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w900, color: placeInk),
                        ),
                        if ('${p['nameEn'] ?? ''}'.isNotEmpty && p['nameEn'] != p['nameAr'])
                          Text(
                            '${p['nameEn']}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
                          ),
                        const SizedBox(height: 4),
                        StatusPill(
                          label: count == 0 ? 'بلا مدن' : '$count مدينة',
                          color: count == 0 ? placeInk2 : placeSuccess,
                          icon: Icons.location_city_outlined,
                        ),
                      ],
                    ),
                  ),
                  if (_canWrite)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: placeInk2),
                      onSelected: (v) {
                        switch (v) {
                          case 'city':
                            _addCity(p);
                          case 'rename':
                            _renameProvince(p);
                          case 'image':
                            _pickImage(p);
                          case 'noimage':
                            _removeImage(p);
                          case 'delete':
                            _deleteProvince(p);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'city', child: Text('إضافة مدينة')),
                        const PopupMenuItem(value: 'rename', child: Text('تعديل الاسم')),
                        PopupMenuItem(
                          value: 'image',
                          enabled: !uploading,
                          child: Text(image == null || image.isEmpty ? 'رفع صورة' : 'تغيير الصورة'),
                        ),
                        if (image != null && image.isNotEmpty)
                          const PopupMenuItem(value: 'noimage', child: Text('إزالة الصورة')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف المحافظة', style: TextStyle(color: placeDanger)),
                        ),
                      ],
                    ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, color: placeInk2),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (cities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('لا مدن في هذه المحافظة بعد', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in cities)
                        InputChip(
                          label: Text('${c['nameAr']}'),
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk),
                          backgroundColor: placePaper,
                          side: const BorderSide(color: placeLine),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onPressed: _canWrite ? () => _cityActions(c) : null,
                          onDeleted: _canWrite ? () => _deleteCity(c) : null,
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          deleteButtonTooltipMessage: 'حذف',
                        ),
                      if (_canWrite && !cityHit)
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 18, color: placeBrass),
                          label: const Text('مدينة'),
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeBrass),
                          backgroundColor: placeBrass.withValues(alpha: 0.08),
                          side: BorderSide(color: placeBrass.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onPressed: () => _addCity(p),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
