import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/api.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';

/// أدوات مشتركة لشاشات المحتوى والتسويق (بانرات، مميزة، كوبونات، تقييمات، منشورات).

/// يحوّل رابطاً نسبياً (/media/..) إلى رابط كامل على خادم الـ API.
String? resolveMediaUrl(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) return '$apiBase$s';
  return s;
}

Map<String, dynamic> asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

int asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? double.tryParse('$v')?.toInt() ?? fallback;
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v')?.toLocal();
}

String formatDay(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy', 'ar').format(d);

String formatStamp(dynamic raw) {
  final d = parseDate(raw);
  if (d == null) return '';
  return DateFormat('d MMM yyyy · HH:mm', 'ar').format(d);
}

/// «منذ ...» مختصر.
String relativeAr(dynamic raw) {
  final d = parseDate(raw);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
  if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
  return formatDay(d);
}

String personLabel(dynamic user) {
  final u = asMap(user);
  final name = u['name']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;
  final phone = u['phone']?.toString().trim() ?? '';
  return phone.isNotEmpty ? phone : 'مستخدم';
}

/// شريط تنبيه «عرض فقط» حين تنقص صلاحية الكتابة.
class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: placeBrass.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: placeBrass.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 18, color: placeBrass),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// جسم قائمة قابل للسحب للتحديث مع حالات التحميل/الخطأ/الفراغ.
class ContentListBody extends StatelessWidget {
  const ContentListBody({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.onRefresh,
    required this.emptyTitle,
    required this.child,
    this.emptySubtitle,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String? emptySubtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: placeBrass,
      onRefresh: onRefresh,
      child: loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 140), Center(child: CircularProgressIndicator(color: placeBrass))],
            )
          : error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(title: 'تعذّر التحميل', subtitle: error),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ),
                  ],
                )
              : isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [const SizedBox(height: 60), EmptyState(title: emptyTitle, subtitle: emptySubtitle)],
                    )
                  : child,
    );
  }
}

/// زر «تحميل المزيد» أسفل القوائم المرقّمة.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key, required this.hasMore, required this.loading, required this.onLoadMore, this.total});

  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;
  final int? total;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            total != null ? 'المجموع: $total' : '',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass))
            : OutlinedButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('تحميل المزيد'),
              ),
      ),
    );
  }
}

/// حقل بحث موحّد مع زر مسح ومهلة (debounce).
class ContentSearchField extends StatefulWidget {
  const ContentSearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<ContentSearchField> createState() => _ContentSearchFieldState();
}

class _ContentSearchFieldState extends State<ContentSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => widget.onChanged(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextField(
        controller: _controller,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    _debounce?.cancel();
                    setState(() {});
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// اختيار صورة ورفعها عبر /api/media/upload (نفس مسار لوحة الإدارة) مع معاينة ونسبة تقدّم.
class ContentImageField extends StatefulWidget {
  const ContentImageField({
    super.key,
    required this.url,
    required this.onChanged,
    this.aspectRatio = 16 / 9,
    this.enabled = true,
    this.hint = 'اضغط لاختيار صورة',
  });

  final String? url;
  final ValueChanged<String> onChanged;
  final double aspectRatio;
  final bool enabled;
  final String hint;

  @override
  State<ContentImageField> createState() => _ContentImageFieldState();
}

class _ContentImageFieldState extends State<ContentImageField> {
  final _picker = ImagePicker();
  double? _progress;

  bool get _uploading => _progress != null;

  Future<void> _pick() async {
    if (!widget.enabled || _uploading) return;
    lightTap();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: placeInk),
                title: const Text('من المعرض', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: placeInk),
                title: const Text('التقاط بالكاميرا', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    XFile? file;
    try {
      file = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 2400);
    } catch (e) {
      if (mounted) showToast(context, 'تعذّر فتح المعرض/الكاميرا', error: true);
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _progress = 0);
    try {
      final res = await Api.uploadFile(
        '/api/media/upload',
        file.path,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final url = res is Map ? res['url']?.toString() : null;
      if (url == null || url.isEmpty) throw ApiException('لم يُرجع الخادم رابط الصورة');
      widget.onChanged(url);
      if (mounted) showToast(context, 'تم رفع الصورة');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(widget.url);
    return GestureDetector(
      onTap: _pick,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: placePaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: placeLine),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                NetImage(url: url, radius: 16)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 36, color: placeInk2.withValues(alpha: 0.6)),
                    const SizedBox(height: 6),
                    Text(
                      widget.hint,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2),
                    ),
                  ],
                ),
              if (url != null && widget.enabled && !_uploading)
                PositionedDirectional(
                  bottom: 10,
                  end: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: placeInk.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 5),
                        Text('تغيير الصورة',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              if (_uploading)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: CircularProgressIndicator(
                          value: (_progress ?? 0) > 0 ? _progress : null,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جارٍ الرفع ${((_progress ?? 0) * 100).round()}%',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: Colors.white),
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

/// المكان المختار: {id, name, type, cover}.
class PickedProperty {
  const PickedProperty({required this.id, required this.name, this.type, this.cover});

  final String id;
  final String name;
  final String? type;
  final String? cover;
}

/// اختيار مكان معتمد عبر البحث في القائمة العامة (/api/properties) — لا يحتاج صلاحية إضافية.
Future<PickedProperty?> pickProperty(BuildContext context) {
  return showModalBottomSheet<PickedProperty>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _PropertyPickerSheet(),
  );
}

class _PropertyPickerSheet extends StatefulWidget {
  const _PropertyPickerSheet();

  @override
  State<_PropertyPickerSheet> createState() => _PropertyPickerSheetState();
}

class _PropertyPickerSheetState extends State<_PropertyPickerSheet> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final params = ['pageSize=40', if (_q.isNotEmpty) 'q=${Uri.encodeQueryComponent(_q)}'];
      final data = await Api.map('/api/properties?${params.join('&')}');
      if (seq != _seq) return;
      _rows = asMapList(data['items']);
      _error = null;
    } catch (e) {
      if (seq != _seq) return;
      _rows = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: placeLine, borderRadius: BorderRadius.circular(4))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('اختر المكان', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
              ),
            ),
            ContentSearchField(
              hint: 'ابحث باسم المكان',
              onChanged: (v) {
                _q = v;
                _load();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: placeBrass))
                  : _error != null
                      ? EmptyState(title: 'تعذّر التحميل', subtitle: _error)
                      : _rows.isEmpty
                          ? const EmptyState(title: 'لا نتائج', subtitle: 'تظهر هنا الأماكن المعتمدة فقط')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _rows.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final row = _rows[i];
                                final media = asMapList(row['media']);
                                final cover = media.isNotEmpty ? resolveMediaUrl(media.first['url']) : null;
                                final city = asMap(row['city'])['nameAr']?.toString() ?? '';
                                final type = row['type']?.toString();
                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.pop(
                                    context,
                                    PickedProperty(
                                      id: '${row['id']}',
                                      name: row['name']?.toString() ?? '',
                                      type: type,
                                      cover: cover,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: placeLine),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 56, height: 56, child: NetImage(url: cover, radius: 12, icon: placeTypeIcon(type))),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row['name']?.toString() ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk),
                                              ),
                                              Text(
                                                [placeTypeLabel(type), city].where((e) => e.isNotEmpty).join(' · '),
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_left_rounded, color: placeInk2),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حقل اختيار مكان داخل نموذج.
class PropertyPickerField extends StatelessWidget {
  const PropertyPickerField({
    super.key,
    required this.label,
    required this.name,
    required this.onPick,
    this.onClear,
    this.enabled = true,
    this.placeholder = 'اضغط لاختيار مكان',
  });

  final String label;
  final String? name;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final bool enabled;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final has = name != null && name!.isNotEmpty;
    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: has && onClear != null && enabled
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClear)
              : const Icon(Icons.unfold_more_rounded),
        ),
        child: Text(
          has ? name! : placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: has ? FontWeight.w700 : FontWeight.w500,
            color: has ? placeInk : placeInk2,
          ),
        ),
      ),
    );
  }
}

/// حقل تاريخ قابل للمسح.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.enabled = true, this.firstDate});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final DateTime? firstDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 2);
    var initial = value ?? now;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: value != null && enabled
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => onChanged(null))
              : null,
        ),
        child: Text(
          value == null ? 'بدون' : formatDay(value),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: value == null ? FontWeight.w500 : FontWeight.w700,
            color: value == null ? placeInk2 : placeInk,
          ),
        ),
      ),
    );
  }
}

/// زر أيقونة صغير ملوّن لبطاقات القوائم.
class CardAction extends StatelessWidget {
  const CardAction({super.key, required this.icon, required this.tooltip, required this.onTap, this.color = placeInk2});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: onTap == null ? placeLine : color),
    );
  }
}

/// سؤال «هل تريد المغادرة دون حفظ؟».
Future<bool> confirmDiscard(BuildContext context) => confirmDialog(
      context,
      title: 'تجاهل التعديلات؟',
      message: 'لديك تغييرات غير محفوظة. هل تريد المغادرة دون حفظ؟',
      confirmLabel: 'مغادرة',
      danger: true,
    );

/// التحقق من الرابط: فارغ، أو يبدأ بـ / ، أو http(s)://
String? linkValidator(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty || s.startsWith('/')) return null;
  final uri = Uri.tryParse(s);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) return null;
  return 'الرابط يجب أن يبدأ بـ https:// أو /';
}
