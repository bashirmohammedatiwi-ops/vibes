import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/net_image.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/kit.dart';
import '../../widgets/ui.dart';
import 'property_editor.dart';
import 'property_media.dart';
import 'property_pricing.dart';

/// صفحة المكان: معرض، حالة، إحصاءات، وكل أدوات التحكم (تعديل، وسائط، أسعار، اعتماد، تكرار، حذف).
class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;
  String? _error;
  bool _changed = false;
  final _page = PageController();
  int _pageIndex = 0;

  bool get _canWrite => Session.can('properties.write');
  bool get _canModerate => Session.can('properties.moderate');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      _p = await Api.map('/api/staff/properties/${widget.propertyId}/full');
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _push(Widget page) async {
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (result == true) _changed = true;
    // أي عودة قد تكون غيّرت الوسائط/الأسعار
    _changed = true;
    if (mounted) _load(silent: true);
  }

  Future<void> _setStatus(String status) async {
    String? reason;
    if (status == 'REJECTED' || status == 'SUSPENDED') {
      reason = await promptText(context, title: 'سبب القرار');
      if (reason == null) return;
    }
    try {
      await Api.send(
        '/api/staff/properties/${widget.propertyId}/status',
        method: 'POST',
        body: {'status': status, if (reason != null) 'reason': reason},
      );
      _changed = true;
      if (mounted) showToast(context, 'تم تحديث الحالة');
      await _load(silent: true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _duplicate() async {
    final ok = await confirmDialog(
      context,
      title: 'تكرار المكان؟',
      message: 'ستُنشأ نسخة مسودة بنفس البيانات والمزايا وقواعد الأسعار (والوسائط كروابط).',
      confirmLabel: 'تكرار',
    );
    if (!ok) return;
    try {
      final copy = await Api.map('/api/staff/properties/${widget.propertyId}/duplicate', method: 'POST', body: {});
      _changed = true;
      if (!mounted) return;
      showToast(context, 'تم إنشاء النسخة');
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: '${copy['id']}')));
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'حذف المكان نهائياً؟',
      message: 'سيُحذف المكان مع وسائطه وقواعده. لا يمكن حذف مكان لديه حجوزات (علّقه بدلاً من ذلك).',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.send('/api/staff/properties/${widget.propertyId}', method: 'DELETE');
      if (!mounted) return;
      showToast(context, 'تم حذف المكان');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  List<Map<String, dynamic>> get _gallery {
    final media = (_p?['media'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return media.where((m) => m['type'] == 'IMAGE' || m['type'] == 'PANORAMA').toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: _loading
            ? _skeleton()
            : _error != null
            ? Scaffold(
                appBar: AppBar(leading: BackButton(onPressed: () => Navigator.of(context).pop(_changed))),
                body: Center(
                  child: EmptyView(
                    icon: Icons.cloud_off_rounded,
                    title: 'تعذّر تحميل المكان',
                    subtitle: _error,
                    actionLabel: 'إعادة المحاولة',
                    onAction: _load,
                  ),
                ),
              )
            : _content(),
      ),
    );
  }

  Widget _skeleton() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(StaffSpace.page),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 44),
          SkeletonBox(height: 230),
          SizedBox(height: 14),
          Align(alignment: AlignmentDirectional.centerStart, child: SkeletonBox(height: 28, width: 220, radius: 8)),
          SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerStart, child: SkeletonBox(height: 18, width: 160, radius: 8)),
          SizedBox(height: 16),
          SkeletonBox(height: 76),
          SizedBox(height: 12),
          SkeletonBox(height: 220),
        ],
      ),
    );
  }

  Widget _content() {
    final p = _p!;
    final media = (p['media'] as List? ?? []);
    final status = p['status']?.toString();
    final gallery = _gallery;
    final city = p['city'];
    final cityName = city is Map ? city['nameAr']?.toString() ?? '' : '';
    final provinceName = (city is Map && city['province'] is Map) ? city['province']['nameAr']?.toString() ?? '' : '';
    final counts = p['_count'] is Map ? p['_count'] as Map : const {};
    final amenityLinks = (p['amenityLinks'] as List? ?? []);
    final name = p['name']?.toString() ?? '';
    final reason = p['rejectionReason']?.toString() ?? '';

    return RefreshIndicator(
      color: placeGold,
      onRefresh: () => _load(silent: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: placePaper,
            foregroundColor: placeInk,
            surfaceTintColor: Colors.transparent,
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            leading: BackButton(onPressed: () => Navigator.of(context).pop(_changed)),
          ),
          // المعرض داخل الصفحة (لا داخل الشريط المنهار) — السحب الأفقي للصور
          // والعمودي للصفحة لا يتعارضان، والضغط يفتح عارضاً بملء الشاشة.
          SliverToBoxAdapter(
            child: Pad(
              top: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(StaffRadius.lg),
                child: SizedBox(
                  height: 240,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (gallery.isEmpty)
                        Container(
                          color: placeLineSoft,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(placeTypeIcon(p['type']?.toString()), size: 44, color: placeInk3),
                              const SizedBox(height: 6),
                              const Text(
                                'لا صور بعد',
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk3),
                              ),
                            ],
                          ),
                        )
                      else
                        PageView.builder(
                          controller: _page,
                          itemCount: gallery.length,
                          onPageChanged: (i) => setState(() => _pageIndex = i),
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    _GalleryViewer(urls: [for (final m in gallery) (m['url'] ?? m['thumbnailUrl']).toString()], initial: i),
                              ),
                            ),
                            child: NetImage(url: (gallery[i]['url'] ?? gallery[i]['thumbnailUrl'])?.toString(), radius: 0),
                          ),
                        ),
                      if (gallery.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < gallery.length && i < 12; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                    width: i == _pageIndex ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == _pageIndex ? Colors.white : Colors.white54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (gallery.isNotEmpty)
                        PositionedDirectional(
                          top: 10,
                          end: 10,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: const Color(0x8C0F1B2D), borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_out_map_rounded, size: 13, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_pageIndex + 1}/${gallery.length}',
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── الاسم والحالة ──
          SliverToBoxAdapter(
            child: Pad(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: placeInk,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: StatusChip(placeStatusLabel(status), color: placeStatusColor(status)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(placeTypeIcon(p['type']?.toString()), size: 16, color: placeInk3),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          [placeTypeLabel(p['type']?.toString()), cityName, provinceName].where((e) => e.isNotEmpty).join(' · '),
                          style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty && (status == 'REJECTED' || status == 'SUSPENDED'))
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: placeDanger.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(StaffRadius.md),
                        border: Border.all(color: placeDanger.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: placeDanger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'السبب: $reason',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: placeDanger,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── أرقام سريعة ──
          SliverToBoxAdapter(
            child: Pad(
              child: Row(
                children: [
                  StatTile(label: 'السعر / يوم', value: formatIqd(p['pricePerDay'])),
                  const SizedBox(width: 8),
                  StatTile(label: 'الحجوزات', value: '${counts['bookings'] ?? 0}', accent: placeInfo),
                  const SizedBox(width: 8),
                  StatTile(label: 'التقييم', value: '${p['ratingAvg'] ?? 0}', accent: placeBrass),
                ],
              ),
            ),
          ),
          // ── الاعتماد ──
          if (_canModerate)
            SliverToBoxAdapter(
              child: FormSection(
                title: 'الاعتماد والنشر',
                subtitle: status == 'APPROVED' ? 'المكان منشور ويظهر للزبائن' : 'المكان غير ظاهر للزبائن حالياً',
                icon: Icons.verified_rounded,
                children: [
                  Row(
                    children: [
                      if (status != 'APPROVED')
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: placeSuccess),
                            onPressed: () => _setStatus('APPROVED'),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(status == 'SUSPENDED' ? 'إعادة نشر' : 'اعتماد ونشر'),
                          ),
                        ),
                      if (status != 'SUSPENDED') ...[
                        if (status != 'APPROVED') const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _setStatus('SUSPENDED'),
                            icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                            label: const Text('تعليق'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (status == 'PENDING')
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: placeDanger),
                      onPressed: () => _setStatus('REJECTED'),
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('رفض مع ذكر السبب'),
                    ),
                ],
              ),
            ),
          // ── إدارة المكان ──
          const SliverToBoxAdapter(child: SectionHeader('إدارة المكان')),
          SliverToBoxAdapter(
            child: Pad(
              child: TileGroup(
                children: [
                  if (_canWrite)
                    TaskTile(
                      icon: Icons.edit_note_rounded,
                      title: 'تعديل البيانات',
                      subtitle: 'الاسم، الموقع، الأسعار، السعة، المزايا',
                      color: placeInfo,
                      onTap: () => _push(PropertyEditorScreen(property: p)),
                    ),
                  TaskTile(
                    icon: Icons.perm_media_rounded,
                    title: _canWrite ? 'الوسائط' : 'عرض الوسائط',
                    subtitle: '${media.length} ملف · صور وفيديو وريلز و360°',
                    color: placeShiftEvening,
                    trailing: _Trail('${media.length}'),
                    onTap: () => _push(PropertyMediaScreen(propertyId: widget.propertyId, propertyName: name)),
                  ),
                  if (_canWrite)
                    TaskTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'الأسعار والتوفر',
                      subtitle: 'مواسم، أسعار خاصة، وحظر أيام',
                      color: placeSuccess,
                      onTap: () => _push(PropertyPricingScreen(propertyId: widget.propertyId, propertyName: name)),
                    ),
                  if (_canWrite)
                    TaskTile(
                      icon: Icons.copy_all_rounded,
                      title: 'تكرار المكان',
                      subtitle: 'نسخة مسودة جاهزة للتعديل',
                      color: placeBrass,
                      onTap: _duplicate,
                    ),
                ],
              ),
            ),
          ),
          // ── التفاصيل ──
          SliverToBoxAdapter(
            child: FormSection(
              title: 'التفاصيل',
              icon: Icons.info_outline_rounded,
              children: [
                Column(
                  children: _divided([
                    InfoRow(icon: Icons.groups_rounded, label: 'السعة', value: '${p['capacity'] ?? 0} شخص'),
                    if (p['weekendPrice'] != null)
                      InfoRow(icon: Icons.weekend_rounded, label: 'نهاية الأسبوع', value: formatIqd(p['weekendPrice'])),
                    if (p['priceMorningShift'] != null)
                      InfoRow(icon: Icons.wb_sunny_rounded, label: 'الشفت الصباحي', value: formatIqd(p['priceMorningShift'])),
                    if (p['priceEveningShift'] != null)
                      InfoRow(icon: Icons.nights_stay_rounded, label: 'الشفت المسائي', value: formatIqd(p['priceEveningShift'])),
                    if ((p['phone']?.toString() ?? '').isNotEmpty)
                      InfoRow(icon: Icons.phone_rounded, label: 'الهاتف', value: '${p['phone']}'),
                    if ((p['address']?.toString() ?? '').isNotEmpty)
                      InfoRow(icon: Icons.location_on_rounded, label: 'العنوان', value: '${p['address']}'),
                    if (p['provider'] is Map)
                      InfoRow(icon: Icons.storefront_rounded, label: 'المزوّد', value: '${(p['provider'] as Map)['businessName'] ?? ''}'),
                  ]),
                ),
                if ((p['description']?.toString() ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(StaffRadius.md)),
                    child: Text(
                      '${p['description']}',
                      style: const TextStyle(fontFamily: 'Cairo', height: 1.65, color: placeInk, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          if (amenityLinks.isNotEmpty)
            SliverToBoxAdapter(
              child: FormSection(
                title: 'المزايا',
                subtitle: '${amenityLinks.length} ميزة',
                icon: Icons.checklist_rounded,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final link in amenityLinks)
                        if (link is Map && link['amenity'] is Map)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: placePaper,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: placeLine),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, size: 14, color: placeSuccess),
                                const SizedBox(width: 4),
                                Text(
                                  '${(link['amenity'] as Map)['nameAr']}',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          if (_canWrite)
            SliverToBoxAdapter(
              child: Pad(
                top: 8,
                bottom: 32,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: placeDanger,
                    side: BorderSide(color: placeDanger.withValues(alpha: .35)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المكان نهائياً'),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  static List<Widget> _divided(List<Widget> rows) => [
    for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1, color: placeLineSoft), rows[i]],
  ];
}

class _Trail extends StatelessWidget {
  const _Trail(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w700, color: placeInk3),
        ),
        const Icon(Icons.chevron_left_rounded, color: placeInk3),
      ],
    );
  }
}

/// عارض الصور بملء الشاشة: سحب بين الصور وتكبير بإصبعين.
class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${_index + 1} / ${widget.urls.length}')),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: staffNetworkImage(
              widget.urls[i],
              fit: BoxFit.contain,
              px: 1440,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
