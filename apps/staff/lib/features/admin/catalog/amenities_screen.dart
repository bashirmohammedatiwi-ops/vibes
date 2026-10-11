import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'catalog_common.dart';

const _types = ['FARM', 'HALL', 'DECORATION'];

String _categoryLabel(String? raw) {
  final c = raw?.trim() ?? '';
  if (c.isEmpty || c == 'general') return 'عام';
  return c;
}

/// كتالوج مزايا الأماكن — مجمّعة حسب الفئة، مع فلترة بالنوع والبحث.
class AmenitiesScreen extends StatefulWidget {
  const AmenitiesScreen({super.key});

  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _type = 'ALL';
  String _status = 'ALL';
  String _q = '';
  bool _busy = false;

  bool get _canWrite => Session.can('amenities.write');

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
      if (_items.isEmpty) _loading = true;
    });
    try {
      final rows = await Api.list('/api/admin/amenities');
      if (!mounted) return;
      setState(() {
        _items = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  List<String> _appliesTo(Map<String, dynamic> a) => (a['appliesTo'] as List? ?? []).map((e) => '$e').toList();

  List<MapEntry<String, List<Map<String, dynamic>>>> get _grouped {
    final q = _q.toLowerCase();
    final map = <String, List<Map<String, dynamic>>>{};
    for (final a in _items) {
      if (_type != 'ALL' && !_appliesTo(a).contains(_type)) continue;
      if (_status == 'ACTIVE' && a['isActive'] == false) continue;
      if (_status == 'INACTIVE' && a['isActive'] != false) continue;
      if (q.isNotEmpty &&
          !'${a['nameAr'] ?? ''}'.toLowerCase().contains(q) &&
          !'${a['nameEn'] ?? ''}'.toLowerCase().contains(q)) {
        continue;
      }
      map.putIfAbsent(_categoryLabel(a['category']?.toString()), () => []).add(a);
    }
    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  List<String> get _categories {
    final set = <String>{};
    for (final a in _items) {
      set.add(_categoryLabel(a['category']?.toString()));
    }
    return set.toList()..sort();
  }

  Future<void> _openEditor([Map<String, dynamic>? amenity]) async {
    if (!_canWrite) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AmenityEditorScreen(amenity: amenity, categories: _categories)),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> a) async {
    final next = a['isActive'] == false;
    setState(() => _busy = true);
    try {
      await Api.send('/api/admin/amenities/${a['id']}', method: 'PATCH', body: {'isActive': next});
      if (mounted) showToast(context, next ? 'تم تفعيل الميزة' : 'تم تعطيل الميزة');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final used = a['_count'] is Map ? asNum(a['_count']['properties']).toInt() : 0;
    if (used > 0) {
      final disable = await confirmDialog(
        context,
        title: 'لا يمكن الحذف',
        message: 'الميزة مستخدمة في $used مكاناً. يمكنك تعطيلها بدلاً من الحذف لتختفي من النماذج.',
        confirmLabel: a['isActive'] == false ? 'حسناً' : 'تعطيل',
      );
      if (disable && a['isActive'] != false) await _toggleActive(a);
      return;
    }
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'حذف الميزة',
      message: 'سيتم حذف «${a['nameAr']}» نهائياً.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.send('/api/admin/amenities/${a['id']}', method: 'DELETE');
      if (mounted) showToast(context, 'تم حذف الميزة');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final active = _items.where((a) => a['isActive'] != false).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مزايا الأماكن'),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('ميزة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const CatalogLoadingView()
            : _error != null && _items.isEmpty
                ? CatalogErrorView(message: _error!, onRetry: _load)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            StatTile(label: 'كل المزايا', value: fmtCount(_items.length)),
                            const SizedBox(width: 10),
                            StatTile(label: 'مفعّلة', value: fmtCount(active), accent: placeSuccess),
                            const SizedBox(width: 10),
                            StatTile(label: 'فئات', value: fmtCount(_categories.length), accent: placeBrass),
                          ],
                        ),
                      ),
                      if (!_canWrite) const ReadOnlyBanner(),
                      CatalogSearchField(
                        controller: _search,
                        hint: 'ابحث عن ميزة…',
                        onChanged: (v) => setState(() => _q = v.trim()),
                      ),
                      FilterChipsRow(
                        options: const ['ALL', ..._types],
                        selected: _type,
                        onSelected: (v) => setState(() => _type = v),
                        labelBuilder: (v) => v == 'ALL' ? 'كل الأنواع' : placeTypeLabel(v),
                      ),
                      FilterChipsRow(
                        options: const ['ALL', 'ACTIVE', 'INACTIVE'],
                        selected: _status,
                        onSelected: (v) => setState(() => _status = v),
                        labelBuilder: (v) => switch (v) {
                          'ACTIVE' => 'المفعّلة',
                          'INACTIVE' => 'المعطّلة',
                          _ => 'كل الحالات',
                        },
                      ),
                      if (_items.isEmpty)
                        const EmptyState(title: 'لا توجد مزايا بعد', subtitle: 'أضف أول ميزة لتظهر في نماذج الأماكن')
                      else if (grouped.isEmpty)
                        const EmptyState(title: 'لا نتائج مطابقة', subtitle: 'غيّر الفلتر أو كلمة البحث')
                      else
                        for (final g in grouped) ...[
                          SectionLabel(g.key, trailing: '${g.value.length} ميزة'),
                          for (final a in g.value) _tile(a),
                        ],
                    ],
                  ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> a) {
    final inactive = a['isActive'] == false;
    final icon = '${a['icon'] ?? ''}'.trim();
    final used = a['_count'] is Map ? asNum(a['_count']['properties']).toInt() : 0;
    final types = _appliesTo(a);
    return Opacity(
      opacity: inactive ? 0.62 : 1,
      child: CatalogCard(
        onTap: _canWrite ? () => _openEditor(a) : null,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: placeBrass.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: icon.isEmpty
                  ? const Icon(Icons.sell_outlined, color: placeBrass)
                  : Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a['nameAr'] ?? '—'}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
                  ),
                  if ('${a['nameEn'] ?? ''}'.isNotEmpty)
                    Text(
                      '${a['nameEn']}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2),
                    ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (inactive) const StatusPill(label: 'معطّلة', color: placeDanger),
                      if (a['isSystem'] == true) const StatusPill(label: 'نظامية', color: placeShiftEvening),
                      if (types.isEmpty)
                        const StatusPill(label: 'كل الأنواع', color: placeInk2)
                      else
                        for (final t in types) StatusPill(label: placeTypeLabel(t), color: placeInk, icon: placeTypeIcon(t)),
                      StatusPill(label: 'في $used مكان', color: placeBrass),
                    ],
                  ),
                ],
              ),
            ),
            if (_canWrite)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: placeInk2),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      _openEditor(a);
                    case 'toggle':
                      _toggleActive(a);
                    case 'delete':
                      _delete(a);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'toggle', child: Text(inactive ? 'تفعيل' : 'تعطيل')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: placeDanger))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// نموذج إضافة/تعديل ميزة — كل حقول AdminAmenityDto.
class AmenityEditorScreen extends StatefulWidget {
  const AmenityEditorScreen({super.key, this.amenity, this.categories = const []});

  final Map<String, dynamic>? amenity;
  final List<String> categories;

  @override
  State<AmenityEditorScreen> createState() => _AmenityEditorScreenState();
}

class _AmenityEditorScreenState extends State<AmenityEditorScreen> {
  static const _emojiSuggestions = [
    '🏊', '📶', '❄️', '🔥', '🅿️', '🍖', '🛝', '⚽', '🎤', '🎶', //
    '🛋️', '🛏️', '🚿', '🍳', '☕', '📺', '🎮', '🌳', '💡', '🧯',
    '🕌', '👶', '♿', '🔒', '📷', '🪑', '🎂', '💐', '🎈', '✨',
  ];

  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _icon = TextEditingController();
  final _category = TextEditingController();
  final _slug = TextEditingController();
  final _sort = TextEditingController();
  final Set<String> _applies = {};
  bool _active = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.amenity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.amenity;
    if (a != null) {
      _nameAr.text = '${a['nameAr'] ?? ''}';
      _nameEn.text = '${a['nameEn'] ?? ''}';
      _icon.text = '${a['icon'] ?? ''}';
      _category.text = _categoryLabel(a['category']?.toString());
      _slug.text = '${a['slug'] ?? ''}';
      _sort.text = '${asNum(a['sortOrder']).toInt()}';
      _applies.addAll((a['appliesTo'] as List? ?? []).map((e) => '$e'));
      _active = a['isActive'] != false;
    } else {
      _category.text = 'عام';
      _sort.text = '0';
    }
    for (final c in [_nameAr, _nameEn, _icon, _category, _slug, _sort]) {
      c.addListener(_touch);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameAr, _nameEn, _icon, _category, _slug, _sort]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Map<String, dynamic> _payload() {
    final body = <String, dynamic>{
      'nameAr': _nameAr.text.trim(),
      'nameEn': _nameEn.text.trim(),
      'icon': _icon.text.trim(),
      'category': _category.text.trim().isEmpty ? 'عام' : _category.text.trim(),
      'appliesTo': _types.where(_applies.contains).toList(),
      'sortOrder': (parseNumber(_sort.text) ?? 0).round(),
      'isActive': _active,
    };
    final slug = _slug.text.trim();
    if (slug.isNotEmpty) body['slug'] = slug;
    final a = widget.amenity;
    if (a == null) return body;
    // تعديل: نرسل الحقول المتغيّرة فقط.
    final original = <String, dynamic>{
      'nameAr': '${a['nameAr'] ?? ''}',
      'nameEn': '${a['nameEn'] ?? ''}',
      'icon': '${a['icon'] ?? ''}',
      'category': _categoryLabel(a['category']?.toString()),
      'appliesTo': _types.where((t) => (a['appliesTo'] as List? ?? []).map((e) => '$e').contains(t)).toList(),
      'sortOrder': asNum(a['sortOrder']).toInt(),
      'isActive': a['isActive'] != false,
      'slug': '${a['slug'] ?? ''}',
    };
    final diff = <String, dynamic>{};
    body.forEach((k, v) {
      final o = original[k];
      final same = v is List && o is List ? v.join(',') == o.join(',') : v == o;
      if (!same) diff[k] = v;
    });
    return diff;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      showToast(context, 'راجع الحقول المطلوبة', error: true);
      return;
    }
    final body = _payload();
    if (_isEdit && body.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await Api.send('/api/admin/amenities/${widget.amenity!['id']}', method: 'PATCH', body: body);
      } else {
        await Api.send('/api/admin/amenities', method: 'POST', body: body);
      }
      if (!mounted) return;
      showToast(context, _isEdit ? 'تم تحديث الميزة' : 'تمت إضافة الميزة');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return true;
    return confirmDialog(
      context,
      title: 'تجاهل التعديلات؟',
      message: 'لديك تغييرات غير محفوظة.',
      confirmLabel: 'تجاهل',
      danger: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = {'عام', ...widget.categories}.toList();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'تعديل ميزة' : 'ميزة جديدة')),
        bottomNavigationBar: BottomActionBar(
          label: _isEdit ? 'حفظ التعديلات' : 'إضافة الميزة',
          busy: _saving,
          onPressed: _save,
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              FormSection(
                title: 'الاسم والأيقونة',
                icon: Icons.sell_outlined,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StaffField(
                          controller: _nameAr,
                          label: 'الاسم بالعربية',
                          hint: 'مثال: مسبح',
                          validator: (v) => requiredValidator(v, 'اسم الميزة مطلوب'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 86,
                        child: TextFormField(
                          controller: _icon,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22),
                          decoration: const InputDecoration(labelText: 'أيقونة', hintText: '🏊'),
                        ),
                      ),
                    ],
                  ),
                  StaffField(controller: _nameEn, label: 'الاسم بالإنجليزية', hint: 'Swimming pool', ltr: true),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojiSuggestions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final e = _emojiSuggestions[i];
                        final sel = _icon.text.trim() == e;
                        return GestureDetector(
                          onTap: () {
                            lightTap();
                            _icon.text = e;
                            setState(() {});
                          },
                          child: Container(
                            width: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel ? placeBrass.withValues(alpha: 0.18) : placePaper,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: sel ? placeBrass : placeLine),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              FormSection(
                title: 'التصنيف',
                icon: Icons.category_outlined,
                subtitle: 'الفئة تجمع المزايا في النماذج والتطبيق',
                children: [
                  StaffField(controller: _category, label: 'الفئة', hint: 'عام، تقنيات، خدمات…'),
                  if (cats.length > 1)
                    ChoicePills<String>(
                      options: cats,
                      value: _category.text.trim(),
                      labelOf: (c) => c,
                      onChanged: (c) {
                        _category.text = c;
                        setState(() {});
                      },
                    ),
                  const Text(
                    'تظهر لأنواع الأماكن (اتركها كلها غير محددة لتظهر للجميع)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _types)
                        FilterChip(
                          avatar: Icon(placeTypeIcon(t), size: 17, color: _applies.contains(t) ? Colors.white : placeInk2),
                          label: Text(placeTypeLabel(t)),
                          selected: _applies.contains(t),
                          showCheckmark: false,
                          selectedColor: placeInk,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: _applies.contains(t) ? placeInk : placeLine),
                          labelStyle: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            color: _applies.contains(t) ? Colors.white : placeInk,
                          ),
                          onSelected: (v) {
                            lightTap();
                            setState(() {
                              v ? _applies.add(t) : _applies.remove(t);
                              _dirty = true;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
              FormSection(
                title: 'العرض',
                icon: Icons.tune_rounded,
                children: [
                  StaffField(
                    controller: _sort,
                    label: 'الترتيب',
                    helper: 'الأصغر يظهر أولاً داخل الفئة',
                    keyboard: TextInputType.number,
                    digitsOnly: true,
                    validator: (v) {
                      final n = parseNumber(v);
                      if (n == null) return null;
                      return n < 0 ? 'قيمة غير صالحة' : null;
                    },
                  ),
                  ToggleRow(
                    title: 'مفعّلة',
                    subtitle: 'المعطّلة لا تظهر في نماذج الأماكن الجديدة',
                    value: _active,
                    onChanged: (v) => setState(() {
                      _active = v;
                      _dirty = true;
                    }),
                  ),
                  StaffField(
                    controller: _slug,
                    label: 'المعرّف (slug)',
                    ltr: true,
                    helper: _isEdit ? 'فريد — غيّره بحذر' : 'اختياري — يُولّد تلقائياً من الاسم',
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (_isEdit && t.isEmpty) return 'المعرّف مطلوب';
                      if (t.contains(' ')) return 'بدون مسافات';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
