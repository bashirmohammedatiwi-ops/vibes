import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import 'content_common.dart';

/// البانرات: الإعلانات أعلى التطبيق — عرض، ترتيب بالسحب، تفعيل، إضافة/تعديل، حذف.
/// القراءة متاحة للجميع؛ الكتابة تتطلب `content.write`.
class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
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
      _rows = asMapList(await Api.list('/api/admin/banners'));
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
      await Api.send('/api/admin/banners/$id', method: 'PATCH', body: {'isActive': value});
      if (mounted) showToast(context, value ? 'تم تفعيل البانر' : 'تم إيقاف البانر');
    } catch (e) {
      row['isActive'] = prev;
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف البانر؟',
      message: 'سيختفي «${row['title'] ?? ''}» من التطبيق نهائياً.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    strongTap();
    final index = _rows.indexOf(row);
    setState(() => _rows.remove(row));
    try {
      await Api.send('/api/admin/banners/${row['id']}', method: 'DELETE');
      if (mounted) showToast(context, 'تم حذف البانر');
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
          futures.add(Api.send('/api/admin/banners/${_rows[i]['id']}', method: 'PATCH', body: {'sortOrder': i}));
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
      MaterialPageRoute(builder: (_) => BannerEditorScreen(banner: row, nextSortOrder: _rows.length)),
    );
    if (saved == true && mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _rows.where((r) => r['isActive'] == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('البانرات')),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('بانر جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            )
          : null,
      body: Column(
        children: [
          MaisonHeader(
            title: 'إعلانات الواجهة',
            subtitle: _loading ? 'جارٍ التحميل…' : '${_rows.length} بانر · $activeCount فعّال',
          ),
          if (!_canWrite)
            const ReadOnlyNotice(message: 'عرض فقط — لإضافة أو تعديل البانرات اطلب صلاحية «إضافة وتعديل البانرات والمميزة».')
          else if (_rows.length > 1)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(
                'اسحب من المقبض ⋮⋮ لتغيير ترتيب الظهور في التطبيق',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
              ),
            ),
          Expanded(
            child: ContentListBody(
              loading: _loading,
              error: _error,
              isEmpty: _rows.isEmpty,
              onRefresh: () => _load(silent: true),
              emptyTitle: 'لا توجد بانرات',
              emptySubtitle: _canWrite ? 'أضف أول بانر ليظهر أعلى التطبيق' : null,
              child: _canWrite
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      buildDefaultDragHandles: false,
                      itemCount: _rows.length,
                      onReorder: _reorder,
                      proxyDecorator: (child, _, _) => Material(color: Colors.transparent, elevation: 6, child: child),
                      itemBuilder: (context, i) => _BannerCard(
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
                      itemBuilder: (context, i) => _BannerCard(
                        row: _rows[i],
                        index: i,
                        canWrite: false,
                        busy: false,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
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
    final title = row['title']?.toString() ?? '';
    final subtitle = row['subtitle']?.toString() ?? '';
    final link = row['linkUrl']?.toString() ?? '';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(opacity: active ? 1 : 0.45, child: NetImage(url: resolveMediaUrl(row['imageUrl']), radius: 14)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 12,
                      end: 12,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
                        child: Text('#${index + 1}',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12, color: placeInk)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusPill(
                    label: active ? 'فعّال' : 'موقوف',
                    color: active ? placeSuccess : placeInk2,
                    icon: active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link.isEmpty ? 'بدون رابط' : link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: link.isEmpty ? null : TextDirection.ltr,
                      textAlign: TextAlign.start,
                      style: const TextStyle(fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canWrite) ...[
                    CardAction(icon: Icons.edit_outlined, tooltip: 'تعديل', onTap: onEdit),
                    CardAction(icon: Icons.delete_outline_rounded, tooltip: 'حذف', onTap: onDelete, color: placeDanger),
                    busy
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass)),
                          )
                        : Switch.adaptive(value: active, activeTrackColor: placeBrass, onChanged: onToggle),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.drag_indicator_rounded, color: placeInk2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// إضافة/تعديل بانر — كل حقول AdminBannerDto.
class BannerEditorScreen extends StatefulWidget {
  const BannerEditorScreen({super.key, this.banner, this.nextSortOrder = 0});

  final Map<String, dynamic>? banner;
  final int nextSortOrder;

  @override
  State<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends State<BannerEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _link = TextEditingController();
  final _sort = TextEditingController();
  String? _imageUrl;
  bool _active = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.banner != null;

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    if (b != null) {
      _title.text = b['title']?.toString() ?? '';
      _subtitle.text = b['subtitle']?.toString() ?? '';
      _link.text = b['linkUrl']?.toString() ?? '';
      _sort.text = '${asInt(b['sortOrder'])}';
      _imageUrl = b['imageUrl']?.toString();
      _active = b['isActive'] != false;
    } else {
      _sort.text = '${widget.nextSortOrder}';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _link.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showToast(context, 'أكمل الحقول المطلوبة بالأحمر', error: true);
      return;
    }
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      showToast(context, 'ارفع صورة البانر أولاً', error: true);
      return;
    }
    setState(() => _saving = true);
    final link = _link.text.trim();
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'imageUrl': _imageUrl,
      'sortOrder': parseNumber(_sort.text)?.round() ?? 0,
      'isActive': _active,
      if (link.isNotEmpty) 'linkUrl': link,
      if (link.isEmpty && _isEdit) 'linkUrl': null,
    };
    try {
      if (_isEdit) {
        await Api.send('/api/admin/banners/${widget.banner!['id']}', method: 'PATCH', body: body);
      } else {
        await Api.send('/api/admin/banners', method: 'POST', body: body);
      }
      if (!mounted) return;
      showToast(context, _isEdit ? 'تم حفظ البانر' : 'تمت إضافة البانر');
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
      title: 'حذف البانر؟',
      message: 'لا يمكن التراجع عن الحذف.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await Api.send('/api/admin/banners/${widget.banner!['id']}', method: 'DELETE');
      if (!mounted) return;
      showToast(context, 'تم حذف البانر');
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
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDiscard(context);
        if (leave && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'تعديل البانر' : 'بانر جديد'),
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
                title: 'الصورة',
                subtitle: 'يفضّل صورة عرضية بنسبة 16:7 تقريباً',
                icon: Icons.image_outlined,
                children: [
                  ContentImageField(
                    url: _imageUrl,
                    aspectRatio: 16 / 7,
                    onChanged: (url) => setState(() {
                      _imageUrl = url;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              FormSection(
                title: 'النص',
                icon: Icons.title_rounded,
                children: [
                  StaffField(
                    controller: _title,
                    label: 'العنوان الرئيسي',
                    validator: (v) => requiredValidator(v, 'أضف العنوان الرئيسي'),
                  ),
                  StaffField(controller: _subtitle, label: 'العنوان الفرعي (اختياري)', maxLines: 2),
                ],
              ),
              FormSection(
                title: 'الرابط والظهور',
                icon: Icons.link_rounded,
                children: [
                  StaffField(
                    controller: _link,
                    label: 'رابط عند الضغط (اختياري)',
                    hint: 'https://… أو /farms/slug',
                    ltr: true,
                    keyboard: TextInputType.url,
                    validator: linkValidator,
                  ),
                  StaffField(
                    controller: _sort,
                    label: 'ترتيب الظهور',
                    helper: 'الأصغر يظهر أولاً',
                    keyboard: TextInputType.number,
                    digitsOnly: true,
                  ),
                  ToggleRow(
                    title: 'فعّال',
                    subtitle: 'يظهر في التطبيق فور الحفظ',
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
          label: _isEdit ? 'حفظ التعديلات' : 'إضافة البانر',
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
