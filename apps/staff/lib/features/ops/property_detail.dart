import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
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
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: '${copy['id']}')),
      );
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
            ? const Center(child: CircularProgressIndicator(color: placeBrass))
            : _error != null
                ? SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: placeInk2)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                        ],
                      ),
                    ),
                  )
                : _content(),
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

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: placePaper,
            foregroundColor: placeInk,
            leading: BackButton(onPressed: () => Navigator.of(context).pop(_changed)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (gallery.isEmpty)
                    Container(
                      color: placeInk.withValues(alpha: 0.06),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined, size: 48, color: placeInk2),
                    )
                  else
                    PageView.builder(
                      controller: _page,
                      itemCount: gallery.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (context, i) => NetImage(
                        url: (gallery[i]['url'] ?? gallery[i]['thumbnailUrl'])?.toString(),
                        radius: 0,
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Colors.transparent, Colors.transparent, Color(0x55000000)],
                        stops: [0, 0.3, 0.7, 1],
                      ),
                    ),
                  ),
                  if (gallery.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
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
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900, color: placeInk),
                        ),
                      ),
                      StatusPill(label: placeStatusLabel(status), color: placeStatusColor(status)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [placeTypeLabel(p['type']?.toString()), cityName, provinceName].where((e) => e.isNotEmpty).join(' · '),
                    style: const TextStyle(color: placeInk2, fontWeight: FontWeight.w600),
                  ),
                  if ((p['rejectionReason']?.toString() ?? '').isNotEmpty && (status == 'REJECTED' || status == 'SUSPENDED'))
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: placeDanger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'السبب: ${p['rejectionReason']}',
                        style: const TextStyle(color: placeDanger, fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  StatTile(label: 'السعر / يوم', value: formatIqd(p['pricePerDay'])),
                  const SizedBox(width: 8),
                  StatTile(label: 'الحجوزات', value: '${counts['bookings'] ?? 0}'),
                  const SizedBox(width: 8),
                  StatTile(label: 'التقييم', value: '${p['ratingAvg'] ?? 0}'),
                ],
              ),
            ),
          ),
          if (_canWrite)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      title: 'تعديل البيانات',
                      subtitle: 'كل خصائص المكان',
                      onTap: () => _push(PropertyEditorScreen(property: p)),
                    ),
                    _ActionTile(
                      icon: Icons.perm_media_outlined,
                      title: 'الوسائط',
                      subtitle: '${media.length} ملف · صور وفيديو وريلز و360°',
                      onTap: () => _push(PropertyMediaScreen(propertyId: widget.propertyId, propertyName: name)),
                    ),
                    _ActionTile(
                      icon: Icons.payments_outlined,
                      title: 'الأسعار والتوفر',
                      subtitle: 'مواسم وحظر أيام',
                      onTap: () => _push(PropertyPricingScreen(propertyId: widget.propertyId, propertyName: name)),
                    ),
                    _ActionTile(
                      icon: Icons.copy_all_outlined,
                      title: 'تكرار المكان',
                      subtitle: 'نسخة مسودة جاهزة للتعديل',
                      onTap: _duplicate,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () => _push(PropertyMediaScreen(propertyId: widget.propertyId, propertyName: name)),
                  icon: const Icon(Icons.perm_media_outlined),
                  label: Text('عرض الوسائط (${media.length})'),
                ),
              ),
            ),
          if (_canModerate)
            SliverToBoxAdapter(
              child: FormSection(
                title: 'الاعتماد والنشر',
                icon: Icons.verified_outlined,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status != 'APPROVED')
                        FilledButton.icon(
                          onPressed: () => _setStatus('APPROVED'),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(status == 'SUSPENDED' ? 'إعادة نشر' : 'اعتماد ونشر'),
                        ),
                      if (status == 'PENDING')
                        OutlinedButton(onPressed: () => _setStatus('REJECTED'), child: const Text('رفض')),
                      if (status != 'SUSPENDED')
                        OutlinedButton(onPressed: () => _setStatus('SUSPENDED'), child: const Text('تعليق')),
                    ],
                  ),
                ],
              ),
            ),
          SliverToBoxAdapter(
            child: FormSection(
              title: 'التفاصيل',
              icon: Icons.info_outline,
              children: [
                _InfoRow('السعة', '${p['capacity'] ?? 0} شخص'),
                if (p['weekendPrice'] != null) _InfoRow('سعر نهاية الأسبوع', formatIqd(p['weekendPrice'])),
                if (p['priceMorningShift'] != null) _InfoRow('الصباحي', formatIqd(p['priceMorningShift'])),
                if (p['priceEveningShift'] != null) _InfoRow('المسائي', formatIqd(p['priceEveningShift'])),
                if ((p['phone']?.toString() ?? '').isNotEmpty) _InfoRow('الهاتف', '${p['phone']}'),
                if ((p['address']?.toString() ?? '').isNotEmpty) _InfoRow('العنوان', '${p['address']}'),
                if (p['provider'] is Map)
                  _InfoRow('المزوّد', '${(p['provider'] as Map)['businessName'] ?? ''}'),
                if ((p['description']?.toString() ?? '').isNotEmpty)
                  Text(
                    '${p['description']}',
                    style: const TextStyle(height: 1.6, color: placeInk, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          if (amenityLinks.isNotEmpty)
            SliverToBoxAdapter(
              child: FormSection(
                title: 'المزايا',
                icon: Icons.checklist_rounded,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final link in amenityLinks)
                        if (link is Map && link['amenity'] is Map)
                          Chip(
                            label: Text('${(link['amenity'] as Map)['nameAr']}'),
                            backgroundColor: placePaper,
                            side: const BorderSide(color: placeLine),
                            labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700),
                            visualDensity: VisualDensity.compact,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          if (_canWrite)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: TextButton.icon(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: placeDanger),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المكان'),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: placeLine),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: placeBrass.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: placeBrass, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 13.5, color: placeInk)),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: placeInk2, height: 1.25),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: placeInk2, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: placeInk, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
      ],
    );
  }
}
