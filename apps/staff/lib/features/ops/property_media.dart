import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/kit.dart';
import '../../widgets/ui.dart';
import '../../core/net_image.dart';

/// مدير وسائط المكان: صور، فيديو، ريلز (استكشف)، وصور 360°.
/// رفع متتابع بشريط تقدّم، سحب لإعادة الترتيب، غلاف، وصف، حذف، وإعادة معالجة الفيديو.
class PropertyMediaScreen extends StatefulWidget {
  const PropertyMediaScreen({super.key, required this.propertyId, required this.propertyName});

  final String propertyId;
  final String propertyName;

  @override
  State<PropertyMediaScreen> createState() => _PropertyMediaScreenState();
}

enum _UpState { queued, uploading, failed }

class _Upload {
  _Upload({required this.path, required this.name, required this.kind, this.ratio});

  final String path;
  final String name;
  final String kind; // media | reel | panorama
  final String? ratio;
  _UpState state = _UpState.queued;
  double progress = 0;
  String? error;
}

const _maxVideoMb = 200;

class _PropertyMediaScreenState extends State<PropertyMediaScreen> {
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _items = [];
  final List<_Upload> _uploads = [];
  String _filter = 'ALL';
  bool _reorderMode = false;
  bool _loading = true;
  String? _error;
  bool _pumping = false;
  Timer? _poll;

  bool get _canWrite => Session.can('properties.write');
  String get _base => '/api/staff/properties/${widget.propertyId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rows = await Api.list('$_base/media');
      _items = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _error = null;
    } catch (e) {
      if (!silent) _error = '$e';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _syncPolling();
  }

  void _syncPolling() {
    final busy = _items.any((m) => m['status'] == 'PROCESSING' || m['status'] == 'UPLOADING');
    if (busy && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
    } else if (!busy) {
      _poll?.cancel();
      _poll = null;
    }
  }

  // ───────── الاختيار والرفع ─────────

  Future<void> _showAddSheet() async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إضافة وسائط',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk),
              ),
              const Text(
                'يُرفع كل ملف بالتتابع مع شريط تقدّم — يمكنك متابعة العمل.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _AddTile(Icons.photo_library_outlined, 'صور من المعرض', 'عدة صور دفعة واحدة', () => Navigator.pop(context, 'images')),
                  _AddTile(Icons.photo_camera_outlined, 'التقاط صورة', 'من الكاميرا مباشرة', () => Navigator.pop(context, 'camera')),
                  _AddTile(Icons.videocam_outlined, 'فيديو', 'يظهر في صفحة المكان', () => Navigator.pop(context, 'video')),
                  _AddTile(Icons.smart_display_outlined, 'ريل', 'فيديو عمودي لتبويب الاستكشاف', () => Navigator.pop(context, 'reel')),
                  _AddTile(Icons.threesixty_rounded, 'صورة 360°', 'بانوراما كاملة غامرة', () => Navigator.pop(context, 'panorama')),
                  _AddTile(Icons.movie_creation_outlined, 'تصوير فيديو', 'من الكاميرا مباشرة', () => Navigator.pop(context, 'videocam')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      switch (action) {
        case 'images':
          {
            final files = await _picker.pickMultiImage(imageQuality: 90, maxWidth: 2800);
            _enqueue([for (final f in files) _Upload(path: f.path, name: f.name, kind: 'media')]);
          }
        case 'camera':
          {
            final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 2800);
            if (f != null) _enqueue([_Upload(path: f.path, name: f.name, kind: 'media')]);
          }
        case 'video':
        case 'videocam':
          {
            final f = await _picker.pickVideo(source: action == 'video' ? ImageSource.gallery : ImageSource.camera);
            if (f != null) await _enqueueVideo(f, reel: false);
          }
        case 'reel':
          {
            final f = await _picker.pickVideo(source: ImageSource.gallery);
            if (f != null) await _enqueueVideo(f, reel: true);
          }
        case 'panorama':
          {
            // بلا ضغط/تصغير: صورة 360° تحتاج دقتها كاملة
            final f = await _picker.pickImage(source: ImageSource.gallery);
            if (f != null) _enqueue([_Upload(path: f.path, name: f.name, kind: 'panorama')]);
          }
      }
    } catch (e) {
      if (mounted) showToast(context, 'تعذّر فتح المعرض/الكاميرا: $e', error: true);
    }
  }

  Future<void> _enqueueVideo(XFile file, {required bool reel}) async {
    final sizeMb = (await File(file.path).length()) / (1024 * 1024);
    if (!mounted) return;
    if (sizeMb > _maxVideoMb) {
      showToast(context, 'حجم الفيديو ${sizeMb.round()}MB يتجاوز الحد المسموح ($_maxVideoMb MB)', error: true);
      return;
    }
    final ratio = await _askRatio(reel ? '9:16' : 'auto');
    if (ratio == null || !mounted) return;
    _enqueue([_Upload(path: file.path, name: file.name, kind: reel ? 'reel' : 'media', ratio: ratio)]);
  }

  Future<String?> _askRatio(String initial) {
    var selected = initial;
    const options = ['auto', '9:16', '16:9', '1:1', '4:3'];
    String label(String r) => r == 'auto' ? 'تلقائي' : r;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'نسبة عرض الفيديو',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يُجهَّز الفيديو تلقائياً (نسخة 720p وملصق) ويُقصّ على النسبة المختارة.',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
                ),
                const SizedBox(height: 14),
                ChoicePills<String>(options: options, value: selected, labelOf: label, onChanged: (v) => setLocal(() => selected = v)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('رفع الفيديو')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _enqueue(List<_Upload> files) {
    if (files.isEmpty) return;
    setState(() => _uploads.addAll(files));
    _pump();
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (mounted) {
        final next = _uploads.where((u) => u.state == _UpState.queued).toList();
        if (next.isEmpty) break;
        await _runUpload(next.first);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runUpload(_Upload u) async {
    setState(() {
      u.state = _UpState.uploading;
      u.progress = 0;
      u.error = null;
    });
    try {
      await Api.uploadFile(
        '$_base/media',
        u.path,
        fields: {'kind': u.kind, if (u.ratio != null) 'targetRatio': u.ratio!},
        onProgress: (p) {
          if (!mounted) return;
          if (p - u.progress >= 0.01 || p >= 1) setState(() => u.progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _uploads.remove(u));
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        u.state = _UpState.failed;
        u.error = '$e';
      });
    }
  }

  void _retry(_Upload u) {
    setState(() => u.state = _UpState.queued);
    _pump();
  }

  // ───────── إجراءات العناصر ─────────

  Future<void> _reorder(List<Map<String, dynamic>> visible, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    setState(() => _items = visible);
    try {
      await Api.send(
        '$_base/media/reorder',
        method: 'PATCH',
        body: {
          'mediaIds': [for (final m in visible) m['id']],
        },
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'تعذّر حفظ الترتيب: $e', error: true);
        _load(silent: true);
      }
    }
  }

  Future<void> _setPrimary(Map<String, dynamic> m) async {
    try {
      await Api.send('$_base/media/${m['id']}/primary', method: 'PATCH', body: {});
      if (mounted) showToast(context, 'تم تعيين الصورة كغلاف');
      await _load(silent: true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _editCaption(Map<String, dynamic> m) async {
    final controller = TextEditingController(text: m['caption']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.xl)),
        title: const Text(
          'وصف الملف',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'وصف قصير يظهر مع الصورة/الفيديو'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await Api.send('/api/staff/media/${m['id']}', method: 'PATCH', body: {'caption': value, 'altText': value});
      await _load(silent: true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _reprocess(Map<String, dynamic> m) async {
    final ratio = await _askRatio(m['type'] == 'REEL' ? '9:16' : 'auto');
    if (ratio == null) return;
    try {
      await Api.send('/api/staff/media/${m['id']}/reprocess', method: 'POST', body: {'targetRatio': ratio});
      if (mounted) showToast(context, 'بدأت إعادة المعالجة');
      await _load(silent: true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الملف؟',
      message: 'سيُحذف نهائياً من المكان ومن السيرفر ولا يمكن التراجع.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.send('/api/staff/media/${m['id']}', method: 'DELETE');
      if (mounted) showToast(context, 'تم الحذف');
      await _load(silent: true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _openPreview(Map<String, dynamic> m) async {
    final type = m['type']?.toString();
    if (type == 'VIDEO' || type == 'REEL') {
      final url = m['url']?.toString();
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImagePreview(url: m['url']?.toString(), is360: type == 'PANORAMA'),
      ),
    );
  }

  // ───────── البناء ─────────

  int _count(String type) => type == 'ALL' ? _items.length : _items.where((m) => m['type'] == type).length;

  List<Map<String, dynamic>> get _visible => _filter == 'ALL' ? [..._items] : _items.where((m) => m['type'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final canReorder = _canWrite && _filter == 'ALL' && _items.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_reorderMode ? 'ترتيب الوسائط' : 'الوسائط'),
            Text(
              _reorderMode ? 'اسحب المقبض لتغيير الترتيب' : widget.propertyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
            ),
          ],
        ),
        actions: [
          if (canReorder)
            _reorderMode
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                      onPressed: () => setState(() => _reorderMode = false),
                      child: const Text('تم'),
                    ),
                  )
                : IconButton(
                    tooltip: 'إعادة الترتيب',
                    icon: const Icon(Icons.swap_vert_rounded),
                    onPressed: () => setState(() => _reorderMode = true),
                  ),
        ],
      ),
      floatingActionButton: _canWrite && !_reorderMode
          ? FloatingActionButton.extended(
              onPressed: _showAddSheet,
              backgroundColor: placeInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text(
                'إضافة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: Column(
        children: [
          if (!_reorderMode)
            FilterChipsRow(
              options: const ['ALL', 'IMAGE', 'VIDEO', 'REEL', 'PANORAMA'],
              selected: _filter,
              labelBuilder: (t) => '${_filterLabel(t)} · ${_count(t)}',
              onSelected: (v) => setState(() => _filter = v),
            ),
          Expanded(
            child: _loading
                ? GridView.count(
                    padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, StaffSpace.page),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .82,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(6, (_) => const SkeletonBox(height: double.infinity)),
                  )
                : _error != null
                ? Center(
                    child: EmptyView(
                      icon: Icons.cloud_off_rounded,
                      title: 'تعذّر تحميل الوسائط',
                      subtitle: _error,
                      actionLabel: 'إعادة المحاولة',
                      onAction: _load,
                    ),
                  )
                : RefreshIndicator(color: placeGold, onRefresh: () => _load(silent: true), child: _buildList(visible)),
          ),
        ],
      ),
    );
  }

  String _filterLabel(String t) => switch (t) {
    'ALL' => 'الكل',
    'IMAGE' => 'صور',
    'VIDEO' => 'فيديو',
    'REEL' => 'ريلز',
    'PANORAMA' => '360°',
    _ => t,
  };

  Widget _buildList(List<Map<String, dynamic>> visible) {
    final panel = _uploadsPanel();
    if (visible.isEmpty && _uploads.isEmpty) {
      return ListView(
        children: [
          EmptyView(
            icon: Icons.perm_media_outlined,
            title: _filter == 'ALL' ? 'لا وسائط بعد' : 'لا عناصر في هذا القسم',
            subtitle: _canWrite ? 'ارفع الصور والفيديو والريلز وصور 360° — أول صورة تصبح الغلاف.' : null,
            actionLabel: _canWrite ? 'إضافة وسائط' : null,
            onAction: _canWrite ? _showAddSheet : null,
          ),
        ],
      );
    }
    // وضع الترتيب: قائمة قابلة للسحب (عرض «الكل» فقط)
    if (_reorderMode && _filter == 'ALL' && _canWrite) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 32),
        buildDefaultDragHandles: false,
        header: panel,
        itemCount: visible.length,
        onReorder: (o, n) => _reorder(visible, o, n),
        itemBuilder: (context, i) => _MediaCard(
          key: ValueKey(visible[i]['id']),
          item: visible[i],
          canWrite: _canWrite,
          dragIndex: i,
          position: i + 1,
          onTap: () => _openPreview(visible[i]),
          onSetPrimary: () => _setPrimary(visible[i]),
          onCaption: () => _editCaption(visible[i]),
          onReprocess: () => _reprocess(visible[i]),
          onDelete: () => _delete(visible[i]),
        ),
      );
    }
    // العرض العادي: شبكة بطاقات
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 0),
          sliver: SliverToBoxAdapter(child: panel),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .82,
            ),
            delegate: SliverChildBuilderDelegate(childCount: visible.length, (context, i) {
              final m = visible[i];
              return _MediaTile(
                key: ValueKey(m['id']),
                item: m,
                canWrite: _canWrite,
                onTap: () => _openPreview(m),
                onSetPrimary: () => _setPrimary(m),
                onCaption: () => _editCaption(m),
                onReprocess: () => _reprocess(m),
                onDelete: () => _delete(m),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _uploadsPanel() {
    if (_uploads.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: placeGold.withValues(alpha: 0.45)),
        boxShadow: staffCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBox(icon: Icons.cloud_upload_rounded, color: placeBrass, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'جارٍ الرفع (${_uploads.length})',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w900, color: placeInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final u in _uploads)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(_kindIcon(u.kind), size: 20, color: placeInk2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk),
                        ),
                        const SizedBox(height: 4),
                        if (u.state == _UpState.failed)
                          Text(u.error ?? 'فشل الرفع', maxLines: 2, style: const TextStyle(fontSize: 11.5, color: placeDanger))
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: u.state == _UpState.queued ? null : (u.progress >= 1 ? null : u.progress),
                              minHeight: 6,
                              color: placeGold,
                              backgroundColor: placeLineSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (u.state == _UpState.failed) ...[
                    IconButton(
                      tooltip: 'إعادة المحاولة',
                      onPressed: () => _retry(u),
                      icon: const Icon(Icons.refresh_rounded, color: placeInk),
                    ),
                    IconButton(
                      tooltip: 'إلغاء',
                      onPressed: () => setState(() => _uploads.remove(u)),
                      icon: const Icon(Icons.close_rounded, color: placeInk2),
                    ),
                  ] else
                    Text(
                      u.state == _UpState.queued ? 'بالانتظار' : '${(u.progress * 100).round()}%',
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

IconData _kindIcon(String kind) => switch (kind) {
  'reel' => Icons.smart_display_outlined,
  'panorama' => Icons.threesixty_rounded,
  _ => Icons.perm_media_outlined,
};

class _AddTile extends StatelessWidget {
  const _AddTile(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      radius: StaffRadius.md,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconBox(icon: icon, color: placeBrass, size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14, color: placeInk),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk2),
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    super.key,
    required this.item,
    required this.canWrite,
    required this.onTap,
    required this.onSetPrimary,
    required this.onCaption,
    required this.onReprocess,
    required this.onDelete,
    this.dragIndex,
    this.position,
  });

  final Map<String, dynamic> item;
  final bool canWrite;
  final int? dragIndex;
  final int? position;
  final VoidCallback onTap;
  final VoidCallback onSetPrimary;
  final VoidCallback onCaption;
  final VoidCallback onReprocess;
  final VoidCallback onDelete;

  String get _type => item['type']?.toString() ?? 'IMAGE';
  String get _status => item['status']?.toString() ?? 'READY';

  String? get _thumb {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = item[k]?.toString() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    return switch (_type) {
      'VIDEO' || 'REEL' => pick(['posterUrl', 'thumbnailUrl']),
      _ => pick(['thumbnailUrl', 'url']),
    };
  }

  (String, IconData, Color) get _badge => switch (_type) {
    'VIDEO' => ('فيديو', Icons.videocam_rounded, placeShiftEvening),
    'REEL' => ('ريل', Icons.smart_display_rounded, const Color(0xFFDB2777)),
    'PANORAMA' => ('360°', Icons.threesixty_rounded, placeSuccess),
    _ => ('صورة', Icons.image_rounded, placeInk2),
  };

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _badge;
    final processing = _status == 'PROCESSING' || _status == 'UPLOADING';
    final failed = _status == 'FAILED' || _status == 'REJECTED';
    final progress = (item['processingProgress'] as num?)?.toDouble();
    final caption = item['caption']?.toString() ?? '';
    final isVideo = _type == 'VIDEO' || _type == 'REEL';
    final primary = item['isPrimary'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: primary ? placeGold : placeLine, width: primary ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (position != null)
                SizedBox(
                  width: 26,
                  child: Text(
                    '$position',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w800, color: placeInk3),
                  ),
                ),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: _thumb, radius: 14, icon: isVideo ? Icons.movie_outlined : Icons.image_outlined),
                    if (isVideo && !processing && !failed)
                      const Center(
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0x99000000),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    if (processing)
                      Container(
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(label: label, color: color, icon: icon),
                        if (primary) const StatusPill(label: 'الغلاف', color: placeBrass, icon: Icons.star_rounded),
                        if (processing)
                          StatusPill(label: progress != null ? 'معالجة ${progress.round()}%' : 'قيد المعالجة', color: placeShiftMorning),
                        if (failed) const StatusPill(label: 'فشلت المعالجة', color: placeDanger, icon: Icons.error_outline),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption.isEmpty ? 'بدون وصف' : caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: caption.isEmpty ? placeInk2 : placeInk,
                      ),
                    ),
                    if (failed && (item['processingError']?.toString() ?? '').isNotEmpty)
                      Text(
                        item['processingError'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: placeDanger),
                      ),
                  ],
                ),
              ),
              if (canWrite) ...[
                _mediaMenu(
                  type: _type,
                  primary: primary,
                  isVideo: isVideo,
                  onSetPrimary: onSetPrimary,
                  onCaption: onCaption,
                  onReprocess: onReprocess,
                  onDelete: onDelete,
                ),
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: const SizedBox(width: 44, height: 48, child: Icon(Icons.drag_indicator_rounded, color: placeInk2)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _mediaMenu({
  required String type,
  required bool primary,
  required bool isVideo,
  required VoidCallback onSetPrimary,
  required VoidCallback onCaption,
  required VoidCallback onReprocess,
  required VoidCallback onDelete,
  Color iconColor = placeInk2,
}) {
  return PopupMenuButton<String>(
    tooltip: 'خيارات',
    icon: Icon(Icons.more_vert_rounded, color: iconColor),
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.md)),
    onSelected: (v) {
      switch (v) {
        case 'primary':
          onSetPrimary();
        case 'caption':
          onCaption();
        case 'reprocess':
          onReprocess();
        case 'delete':
          onDelete();
      }
    },
    itemBuilder: (context) => [
      if (type == 'IMAGE' && !primary) const PopupMenuItem(value: 'primary', child: _MenuRow(Icons.star_outline_rounded, 'تعيين كغلاف')),
      const PopupMenuItem(value: 'caption', child: _MenuRow(Icons.edit_outlined, 'تعديل الوصف')),
      if (isVideo) const PopupMenuItem(value: 'reprocess', child: _MenuRow(Icons.refresh_rounded, 'إعادة المعالجة')),
      const PopupMenuItem(value: 'delete', child: _MenuRow(Icons.delete_outline_rounded, 'حذف', danger: true)),
    ],
  );
}

/// بطاقة وسائط في الشبكة: صورة مربعة مع شارات، ووصف وقائمة خيارات.
class _MediaTile extends _MediaCard {
  const _MediaTile({
    super.key,
    required super.item,
    required super.canWrite,
    required super.onTap,
    required super.onSetPrimary,
    required super.onCaption,
    required super.onReprocess,
    required super.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _badge;
    final processing = _status == 'PROCESSING' || _status == 'UPLOADING';
    final failed = _status == 'FAILED' || _status == 'REJECTED';
    final progress = (item['processingProgress'] as num?)?.toDouble();
    final caption = item['caption']?.toString() ?? '';
    final isVideo = _type == 'VIDEO' || _type == 'REEL';
    final primary = item['isPrimary'] == true;
    final r = BorderRadius.circular(StaffRadius.lg);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: r,
        border: Border.all(color: primary ? placeGold : placeLine, width: primary ? 1.5 : 1),
        boxShadow: staffCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: _thumb, radius: 0, icon: isVideo ? Icons.movie_outlined : Icons.image_outlined),
                    if (isVideo && !processing && !failed)
                      const Center(
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0x8C0F1B2D),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    if (processing)
                      Container(
                        color: const Color(0x8C0F1B2D),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                            const SizedBox(height: 6),
                            Text(
                              progress != null ? 'معالجة ${progress.round()}%' : 'قيد المعالجة',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    if (failed)
                      Container(
                        color: placeDanger.withValues(alpha: .55),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.white),
                            Text(
                              'فشلت المعالجة',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: _OnImage(
                        child: StatusPill(label: label, color: color, icon: icon),
                      ),
                    ),
                    if (primary)
                      const PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: _OnImage(
                          child: StatusPill(label: 'الغلاف', color: placeBrass, icon: Icons.star_rounded),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        caption.isEmpty ? 'بدون وصف' : caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: caption.isEmpty ? placeInk3 : placeInk,
                        ),
                      ),
                    ),
                    if (canWrite)
                      _mediaMenu(
                        type: _type,
                        primary: primary,
                        isVideo: isVideo,
                        onSetPrimary: onSetPrimary,
                        onCaption: onCaption,
                        onReprocess: onReprocess,
                        onDelete: onDelete,
                      )
                    else
                      const SizedBox(width: 12),
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

class _OnImage extends StatelessWidget {
  const _OnImage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(999)),
      child: child,
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? placeDanger : placeInk;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url, required this.is360});

  final String? url;
  final bool is360;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(is360 ? 'صورة 360°' : 'معاينة')),
      body: url == null
          ? const SizedBox.shrink()
          : InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: staffNetworkImage(
                  url!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
    );
  }
}
