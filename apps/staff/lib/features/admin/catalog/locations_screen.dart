import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../../widgets/ui.dart' show FilterChipsRow, lightTap;
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
  String _filter = 'ALL';
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

  bool _hasImage(Map<String, dynamic> p) => '${p['imageUrl'] ?? ''}'.isNotEmpty;

  bool _matches(Map<String, dynamic> m) {
    final q = _q.toLowerCase();
    return '${m['nameAr'] ?? ''}'.toLowerCase().contains(q) || '${m['nameEn'] ?? ''}'.toLowerCase().contains(q);
  }

  bool _passesFilter(Map<String, dynamic> p) => switch (_filter) {
        'NO_IMAGE' => !_hasImage(p),
        'NO_CITIES' => _cityCount(p) == 0,
        _ => true,
      };

  /// يعيد المحافظات المطابقة مع المدن المطابقة (أو كل المدن إن طابقت المحافظة نفسها).
  List<(Map<String, dynamic>, List<Map<String, dynamic>>, bool)> get _visible {
    final out = <(Map<String, dynamic>, List<Map<String, dynamic>>, bool)>[];
    for (final p in _provinces) {
      if (!_passesFilter(p)) continue;
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

  Future<void> _provinceActions(Map<String, dynamic> p) async {
    if (!_canWrite) return;
    lightTap();
    final hasImage = _hasImage(p);
    final uploading = _uploadingId == '${p['id']}';
    final action = await showActionSheet(
      context,
      title: '${p['nameAr'] ?? 'المحافظة'}',
      actions: [
        const SheetAction('city', 'إضافة مدينة', Icons.add_location_alt_outlined),
        const SheetAction('rename', 'تعديل الاسم', Icons.edit_outlined),
        SheetAction('image', hasImage ? 'تغيير الصورة' : 'رفع صورة', Icons.image_outlined, enabled: !uploading),
        if (hasImage) const SheetAction('noimage', 'إزالة الصورة', Icons.hide_image_outlined, danger: true),
        const SheetAction('delete', 'حذف المحافظة', Icons.delete_outline_rounded, danger: true),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'city':
        await _addCity(p);
      case 'rename':
        await _renameProvince(p);
      case 'image':
        await _pickImage(p);
      case 'noimage':
        await _removeImage(p);
      case 'delete':
        await _deleteProvince(p);
    }
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
    final action = await showActionSheet(
      context,
      title: '${c['nameAr']}',
      actions: const [
        SheetAction('rename', 'تعديل الاسم', Icons.edit_outlined),
        SheetAction('delete', 'حذف المدينة', Icons.delete_outline_rounded, danger: true),
      ],
    );
    if (!mounted) return;
    if (action == 'rename') await _renameCity(c);
    if (action == 'delete') await _deleteCity(c);
  }

  // ───────── الواجهة ─────────

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final totalCities = _provinces.fold<int>(0, (s, p) => s + _cityCount(p));
    final noImage = _provinces.where((p) => !_hasImage(p)).length;
    final noCities = _provinces.where((p) => _cityCount(p) == 0).length;
    return StaffPage(
      title: 'المحافظات والمدن',
      subtitle: _loading ? null : '${fmtCount(_provinces.length)} محافظة · ${fmtCount(totalCities)} مدينة',
      bottom: catalogBusyBar(_busy),
      onRefresh: _load,
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _addProvince,
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('محافظة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      slivers: [
        if (_loading) ...[
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  const Expanded(child: SkeletonBox(height: 104)),
                ],
              ]),
            ),
          ),
          const SkeletonSliver(count: 6, height: 82),
        ] else if (_error != null && _provinces.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: CatalogErrorView(message: _error!, onRetry: _load))
        else ...[
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: Row(
                children: [
                  Expanded(
                    child: KpiTile(
                      label: 'محافظات',
                      value: fmtCount(_provinces.length),
                      icon: Icons.map_outlined,
                      color: placeShiftEvening,
                      onTap: () => setState(() => _filter = 'ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiTile(
                      label: 'مدن',
                      value: fmtCount(totalCities),
                      icon: Icons.location_city_outlined,
                      color: placeBrass,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiTile(
                      label: 'بلا صورة',
                      value: fmtCount(noImage),
                      icon: Icons.hide_image_outlined,
                      color: placeWarning,
                      alert: noImage > 0,
                      onTap: () => setState(() => _filter = 'NO_IMAGE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_canWrite) const SliverToBoxAdapter(child: ReadOnlyBanner()),
          SliverToBoxAdapter(
            child: CatalogSearchField(
              controller: _search,
              hint: 'ابحث عن محافظة أو مدينة…',
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChipsRow(
              options: const ['ALL', 'NO_IMAGE', 'NO_CITIES'],
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
              labelBuilder: (v) => switch (v) {
                'NO_IMAGE' => 'بلا صورة ($noImage)',
                'NO_CITIES' => 'بلا مدن ($noCities)',
                _ => 'كل المحافظات',
              },
            ),
          ),
          if (_provinces.isEmpty)
            SliverToBoxAdapter(
              child: EmptyView(
                icon: Icons.map_outlined,
                title: 'لا توجد محافظات بعد',
                subtitle: 'أضف أول محافظة لتظهر في نماذج الأماكن',
                actionLabel: _canWrite ? 'إضافة محافظة' : null,
                onAction: _canWrite ? _addProvince : null,
              ),
            )
          else if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyView(icon: Icons.search_off_rounded, title: 'لا نتائج مطابقة', subtitle: 'جرّب اسماً آخر أو غيّر الفلتر'),
            )
          else
            SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final (p, cities, cityHit) = visible[i];
                return Pad(bottom: 0, child: _provinceCard(p, cities, cityHit));
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 72)),
        ],
      ],
    );
  }

  Widget _provinceCard(Map<String, dynamic> p, List<Map<String, dynamic>> cities, bool cityHit) {
    final id = '${p['id']}';
    final open = cityHit || _expanded.contains(id);
    final count = _cityCount(p);
    final image = p['imageUrl']?.toString();
    final uploading = _uploadingId == id;
    final r = BorderRadius.circular(StaffRadius.lg);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: r,
        border: Border.all(color: open ? placeGold.withValues(alpha: .45) : placeLine),
      ),
      child: Material(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                lightTap();
                setState(() => open ? _expanded.remove(id) : _expanded.add(id));
              },
              onLongPress: _canWrite ? () => _provinceActions(p) : null,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetImage(url: image, radius: StaffRadius.md, icon: Icons.landscape_outlined),
                          if (uploading)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(StaffRadius.md),
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
                          Text('${p['nameAr'] ?? '—'}', style: catalogTitleStyle.copyWith(fontSize: 15)),
                          if ('${p['nameEn'] ?? ''}'.isNotEmpty && p['nameEn'] != p['nameAr'])
                            Text('${p['nameEn']}', textDirection: TextDirection.ltr, style: catalogSubtitleStyle),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              StatusChip(
                                count == 0 ? 'بلا مدن' : '$count مدينة',
                                color: count == 0 ? placeInk3 : placeSuccess,
                                dense: true,
                              ),
                              if (image == null || image.isEmpty)
                                const StatusChip('بلا صورة', color: placeWarning, dense: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_canWrite)
                      IconButton(
                        tooltip: 'إجراءات',
                        onPressed: () => _provinceActions(p),
                        icon: const Icon(Icons.more_horiz_rounded, color: placeInk2),
                      ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Padding(
                        padding: EdgeInsetsDirectional.only(end: 8),
                        child: Icon(Icons.expand_more_rounded, color: placeInk3),
                      ),
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
                color: placePaper.withValues(alpha: .6),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cityHit ? 'مدن مطابقة للبحث' : 'المدن',
                      style: catalogMetaStyle,
                    ),
                    const SizedBox(height: 8),
                    if (cities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('لا مدن في هذه المحافظة بعد', style: catalogSubtitleStyle),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in cities)
                          InputChip(
                            label: Text('${c['nameAr']}'),
                            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: placeLine),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.sm)),
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
                            backgroundColor: placeGoldSoft,
                            side: BorderSide(color: placeBrass.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.sm)),
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
      ),
    );
  }
}
