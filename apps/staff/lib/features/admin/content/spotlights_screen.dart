import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'content_common.dart';

/// الأماكن المميزة (Spotlights) في الصفحة الرئيسية: صورة + مكان مرتبط + ارتفاع البطاقة.
/// القراءة متاحة للجميع؛ الكتابة تتطلب `content.write`.
class AdminSpotlightsScreen extends StatefulWidget {
  const AdminSpotlightsScreen({super.key});

  @override
  State<AdminSpotlightsScreen> createState() => _AdminSpotlightsScreenState();
}

class _AdminSpotlightsScreenState extends State<AdminSpotlightsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  bool get _canWrite => Session.can('content.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      _rows = asMapList(await Api.list('/api/admin/spotlights'));
      _error = null;
    } catch (e) {
      if (silent && _rows.isNotEmpty) {
        if (mounted) showToast(context, '$e', error: true);
      } else {
        _rows = [];
        _error = '$e';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Map<String, dynamic> row, bool value) async {
    final id = '${row['id']}';
    final prev = row['isActive'] == true;
    setState(() {
      row['isActive'] = value;
      _busy.add(id);
    });
    try {
      await Api.send('/api/admin/spotlights/$id', method: 'PATCH', body: {'isActive': value});
      if (mounted) showToast(context, value ? 'تم التفعيل' : 'تم الإيقاف');
    } catch (e) {
      row['isActive'] = prev;
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final name = asMap(row['property'])['name'] ?? row['title'] ?? '';
    final ok = await confirmDialog(
      context,
      title: 'حذف العنصر المميز؟',
      message: 'سيُزال «$name» من الواجهة الرئيسية.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    strongTap();
    final index = _rows.indexOf(row);
    setState(() => _rows.remove(row));
    try {
      await Api.send('/api/admin/spotlights/${row['id']}', method: 'DELETE');
      if (mounted) showToast(context, 'تم الحذف');
    } catch (e) {
      if (mounted) {
        setState(() => _rows.insert(index.clamp(0, _rows.length), row));
        showToast(context, '$e', error: true);
      }
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    lightTap();
    final before = [..._rows];
    setState(() {
      final item = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, item);
    });
    try {
      final futures = <Future<dynamic>>[];
      for (var i = 0; i < _rows.length; i++) {
        if (asInt(_rows[i]['sortOrder'], -1) != i) {
          futures.add(Api.send('/api/admin/spotlights/${_rows[i]['id']}', method: 'PATCH', body: {'sortOrder': i}));
        }
      }
      await Future.wait(futures);
      for (var i = 0; i < _rows.length; i++) {
        _rows[i]['sortOrder'] = i;
      }
      if (mounted) {
        setState(() {});
        showToast(context, 'تم تغيير الترتيب');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _rows = before);
        showToast(context, '$e', error: true);
        _load(silent: true);
      }
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? row]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SpotlightEditorScreen(spotlight: row, nextSortOrder: _rows.length)),
    );
    if (saved == true && mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _rows.where((r) => r['isActive'] == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('الأماكن المميزة')),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('عنصر مميز', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      body: Column(
        children: [
          MaisonHeader(
            title: 'مميزة الرئيسية',
            subtitle: _loading ? 'جارٍ التحميل…' : '${_rows.length} عنصر · $activeCount فعّال',
          ),
          if (!_canWrite)
            const ReadOnlyNotice(message: 'عرض فقط — للتعديل اطلب صلاحية «إضافة وتعديل البانرات والمميزة».')
          else if (_rows.length > 1)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(
                'اسحب من المقبض ⋮⋮ لتغيير الترتيب',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
              ),
            ),
          Expanded(
            child: ContentListBody(
              loading: _loading,
              error: _error,
              isEmpty: _rows.isEmpty,
              onRefresh: () => _load(silent: true),
              emptyTitle: 'لا توجد عناصر مميزة',
              emptySubtitle: _canWrite ? 'أضف مكاناً ليظهر في واجهة التطبيق' : null,
              child: _canWrite
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      buildDefaultDragHandles: false,
                      itemCount: _rows.length,
                      onReorder: _reorder,
                      proxyDecorator: (child, _, _) => Material(color: Colors.transparent, elevation: 6, child: child),
                      itemBuilder: (context, i) => _SpotlightCard(
                        key: ValueKey(_rows[i]['id']),
                        row: _rows[i],
                        index: i,
                        canWrite: true,
                        busy: _busy.contains('${_rows[i]['id']}'),
                        onToggle: (v) => _toggle(_rows[i], v),
                        onEdit: () => _openEditor(_rows[i]),
                        onDelete: () => _delete(_rows[i]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _rows.length,
                      itemBuilder: (context, i) => _SpotlightCard(row: _rows[i], index: i, canWrite: false, busy: false),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    super.key,
    required this.row,
    required this.index,
    required this.canWrite,
    required this.busy,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> row;
  final int index;
  final bool canWrite;
  final bool busy;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final active = row['isActive'] == true;
    final property = asMap(row['property']);
    final title = row['title']?.toString() ?? '';
    final type = property['type']?.toString();
    final height = asInt(row['height'], 176);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canWrite ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 92 * (height / 176).clamp(0.8, 1.3),
                child: Opacity(
                  opacity: active ? 1 : 0.45,
                  child: NetImage(url: resolveMediaUrl(row['imageUrl']), radius: 14, icon: placeTypeIcon(type)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['name']?.toString() ?? 'مكان محذوف',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15.5, color: placeInk),
                    ),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(
                          label: active ? 'فعّال' : 'موقوف',
                          color: active ? placeSuccess : placeInk2,
                        ),
                        StatusPill(label: placeTypeLabel(type), color: placeBrass, icon: placeTypeIcon(type)),
                        StatusPill(label: 'ارتفاع $height', color: placeShiftEvening, icon: Icons.height_rounded),
                        StatusPill(label: '#${index + 1}', color: placeInk),
                      ],
                    ),
                    if (canWrite)
                      Row(
                        children: [
                          CardAction(icon: Icons.edit_outlined, tooltip: 'تعديل', onTap: onEdit),
                          CardAction(icon: Icons.delete_outline_rounded, tooltip: 'حذف', onTap: onDelete, color: placeDanger),
                          const Spacer(),
                          busy
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass)),
                                )
                              : Switch.adaptive(value: active, activeTrackColor: placeBrass, onChanged: onToggle),
                        ],
                      ),
                  ],
                ),
              ),
              if (canWrite)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.drag_indicator_rounded, color: placeInk2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// إضافة/تعديل عنصر مميز — كل حقول AdminSpotlightDto.
class SpotlightEditorScreen extends StatefulWidget {
  const SpotlightEditorScreen({super.key, this.spotlight, this.nextSortOrder = 0});

  final Map<String, dynamic>? spotlight;
  final int nextSortOrder;

  @override
  State<SpotlightEditorScreen> createState() => _SpotlightEditorScreenState();
}

class _SpotlightEditorScreenState extends State<SpotlightEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _sort = TextEditingController();
  String? _imageUrl;
  String? _propertyId;
  String? _propertyName;
  String? _propertyType;
  double _height = 176;
  bool _active = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.spotlight != null;

  @override
  void initState() {
    super.initState();
    final s = widget.spotlight;
    if (s != null) {
      _title.text = s['title']?.toString() ?? '';
      _sort.text = '${asInt(s['sortOrder'])}';
      _imageUrl = s['imageUrl']?.toString();
      _propertyId = s['propertyId']?.toString();
      final p = asMap(s['property']);
      _propertyName = p['name']?.toString();
      _propertyType = p['type']?.toString();
      _height = asInt(s['height'], 176).clamp(140, 280).toDouble();
      _active = s['isActive'] != false;
    } else {
      _sort.text = '${widget.nextSortOrder}';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickProperty() async {
    final picked = await pickProperty(context);
    if (picked == null || !mounted) return;
    setState(() {
      _propertyId = picked.id;
      _propertyName = picked.name;
      _propertyType = picked.type;
      _dirty = true;
      if ((_imageUrl == null || _imageUrl!.isEmpty) && picked.cover != null) {
        _imageUrl = picked.cover;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showToast(context, 'أكمل الحقول المطلوبة', error: true);
      return;
    }
    if (_propertyId == null) {
      showToast(context, 'اختر المكان المرتبط', error: true);
      return;
    }
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      showToast(context, 'ارفع صورة أولاً', error: true);
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'imageUrl': _imageUrl,
      'propertyId': _propertyId,
      'height': _height.round(),
      'sortOrder': parseNumber(_sort.text)?.round() ?? 0,
      'isActive': _active,
    };
    try {
      if (_isEdit) {
        await Api.send('/api/admin/spotlights/${widget.spotlight!['id']}', method: 'PATCH', body: body);
      } else {
        await Api.send('/api/admin/spotlights', method: 'POST', body: body);
      }
      if (!mounted) return;
      showToast(context, _isEdit ? 'تم الحفظ' : 'أُضيف العنصر المميز');
      _dirty = false;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'حذف العنصر المميز؟',
      message: 'لا يمكن التراجع عن الحذف.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await Api.send('/api/admin/spotlights/${widget.spotlight!['id']}', method: 'DELETE');
      if (!mounted) return;
      showToast(context, 'تم الحذف');
      _dirty = false;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = resolveMediaUrl(_imageUrl);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDiscard(context);
        if (leave && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'تعديل المميز' : 'عنصر مميز جديد'),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: 'حذف',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, color: placeDanger),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: _touch,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            children: [
              FormSection(
                title: 'المكان المرتبط',
                subtitle: 'يفتح المكان عند الضغط على البطاقة',
                icon: placeTypeIcon(_propertyType),
                children: [
                  PropertyPickerField(
                    label: 'المكان',
                    name: _propertyName,
                    onPick: _pickProperty,
                  ),
                  StaffField(
                    controller: _title,
                    label: 'عنوان مخصص (اختياري)',
                    hint: 'يُستخدم اسم المكان إن تُرك فارغاً',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              FormSection(
                title: 'الصورة',
                subtitle: 'تُعبأ تلقائياً بغلاف المكان ويمكن تغييرها',
                icon: Icons.image_outlined,
                children: [
                  ContentImageField(
                    url: _imageUrl,
                    aspectRatio: 4 / 3,
                    onChanged: (url) => setState(() {
                      _imageUrl = url;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              FormSection(
                title: 'ارتفاع البطاقة',
                subtitle: 'بين 140 و 280 — الافتراضي 176',
                icon: Icons.height_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _height,
                          min: 140,
                          max: 280,
                          divisions: 35,
                          activeColor: placeBrass,
                          label: '${_height.round()}',
                          onChanged: (v) => setState(() {
                            _height = v;
                            _dirty = true;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${_height.round()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 150,
                      height: _height * 0.75,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: placeInk.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetImage(url: previewUrl, radius: 16),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                                colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 10,
                            end: 10,
                            bottom: 8,
                            child: Text(
                              _title.text.trim().isNotEmpty ? _title.text.trim() : (_propertyName ?? 'معاينة'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              FormSection(
                title: 'الظهور',
                icon: Icons.visibility_outlined,
                children: [
                  StaffField(
                    controller: _sort,
                    label: 'ترتيب الظهور',
                    helper: 'الأصغر يظهر أولاً',
                    keyboard: TextInputType.number,
                    digitsOnly: true,
                  ),
                  ToggleRow(
                    title: 'فعّال',
                    subtitle: 'يظهر في الواجهة الرئيسية',
                    value: _active,
                    onChanged: (v) => setState(() {
                      _active = v;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          label: _isEdit ? 'حفظ التعديلات' : 'إضافة',
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
