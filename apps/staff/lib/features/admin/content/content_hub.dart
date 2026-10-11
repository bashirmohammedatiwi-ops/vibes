import 'package:flutter/material.dart';

import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/api.dart';
import '../../../widgets/kit.dart';
import 'content_common.dart';
import 'banners_screen.dart';
import 'coupons_screen.dart';
import 'reviews_screen.dart';
import 'social_screen.dart';
import 'spotlights_screen.dart';

/// قسم من أقسام المحتوى والتسويق — يظهر إن امتلك الموظف أي صلاحية من [anyOf].
class ContentSection {
  const ContentSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.anyOf,
    required this.builder,
    this.group = 'storefront',
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> anyOf;
  final WidgetBuilder builder;

  /// مجموعة العرض في الواجهة: storefront | marketing | moderation.
  final String group;

  bool get visible => anyOf.any(Session.can);
}

/// كل أقسام المحتوى والتسويق مع صلاحيات ظهورها.
final List<ContentSection> contentSections = [
  ContentSection(
    id: 'banners',
    title: 'البانرات',
    subtitle: 'إعلانات أعلى التطبيق',
    icon: Icons.view_carousel_outlined,
    color: placeBrass,
    anyOf: const ['content.write', 'content.moderate'],
    builder: (_) => const AdminBannersScreen(),
  ),
  ContentSection(
    id: 'spotlights',
    title: 'الأماكن المميزة',
    subtitle: 'بطاقات الواجهة الرئيسية',
    icon: Icons.auto_awesome_outlined,
    color: placeShiftEvening,
    anyOf: const ['content.write', 'content.moderate'],
    builder: (_) => const AdminSpotlightsScreen(),
  ),
  ContentSection(
    id: 'coupons',
    title: 'الكوبونات',
    subtitle: 'أكواد الخصم وشروطها',
    icon: Icons.local_offer_outlined,
    color: placeSuccess,
    anyOf: const ['coupons.read'],
    builder: (_) => const AdminCouponsScreen(),
    group: 'marketing',
  ),
  ContentSection(
    id: 'reviews',
    title: 'التقييمات',
    subtitle: 'إخفاء وإظهار وحذف',
    icon: Icons.star_outline_rounded,
    color: placeShiftMorning,
    anyOf: const ['reviews.moderate'],
    builder: (_) => const AdminReviewsScreen(),
    group: 'moderation',
  ),
  ContentSection(
    id: 'social',
    title: 'منشورات التجارب',
    subtitle: 'البلاغات والإشراف',
    icon: Icons.photo_library_outlined,
    color: placeDanger,
    anyOf: const ['reviews.moderate'],
    builder: (_) => const AdminSocialScreen(),
    group: 'moderation',
  ),
];

List<ContentSection> visibleContentSections() => contentSections.where((s) => s.visible).toList();

/// كل صلاحيات قسم المحتوى — لإظهار مدخل الشاشة نفسها في الواجهة الأم.
const contentHubPermissions = <String>['content.write', 'content.moderate', 'coupons.read', 'coupons.write', 'reviews.moderate'];

bool get hasContentHubAccess => visibleContentSections().isNotEmpty;

/// مدخل «المحتوى والتسويق».
class ContentHubScreen extends StatefulWidget {
  const ContentHubScreen({super.key});

  @override
  State<ContentHubScreen> createState() => _ContentHubScreenState();
}

class _ContentHubScreenState extends State<ContentHubScreen> {
  // مؤشرات حيّة — null = غير متاحة (لا صلاحية أو فشل التحميل).
  int? _bannersActive;
  int? _bannersTotal;
  int? _spotlightsActive;
  int? _spotlightsTotal;
  int? _couponsActive;
  int? _reportedPosts;
  int? _hiddenReviews;
  bool _loaded = false;

  bool get _content => Session.can('content.write') || Session.can('content.moderate');
  bool get _coupons => Session.can('coupons.read');
  bool get _moderate => Session.can('reviews.moderate');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int?> _total(String path) async {
    try {
      return asInt((await Api.map(path))['total']);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _list(String path) async {
    try {
      return asMapList(await Api.list(path));
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final banners = _content ? _list('/api/admin/banners') : Future.value(null);
    final spotlights = _content ? _list('/api/admin/spotlights') : Future.value(null);
    final coupons = _coupons ? _total('/api/admin/coupons?page=1&pageSize=1&activeOnly=true') : Future.value(null);
    final reported = _moderate ? _total('/api/admin/social?page=1&pageSize=1&status=REPORTED') : Future.value(null);
    final hidden = _moderate ? _total('/api/admin/reviews?page=1&pageSize=1&visible=false') : Future.value(null);
    final b = await banners;
    final s = await spotlights;
    final c = await coupons;
    final r = await reported;
    final h = await hidden;
    if (!mounted) return;
    setState(() {
      _bannersTotal = b?.length;
      _bannersActive = b?.where((e) => e['isActive'] == true).length;
      _spotlightsTotal = s?.length;
      _spotlightsActive = s?.where((e) => e['isActive'] == true).length;
      _couponsActive = c;
      _reportedPosts = r;
      _hiddenReviews = h;
      _loaded = true;
    });
  }

  Future<void> _open(ContentSection s) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: s.builder));
    if (mounted) _load();
  }

  ContentSection? _section(String id) {
    for (final s in visibleContentSections()) {
      if (s.id == id) return s;
    }
    return null;
  }

  int? _countFor(String id) => switch (id) {
    'social' => _reportedPosts,
    _ => null,
  };

  String _subtitleFor(ContentSection s) {
    String? live;
    switch (s.id) {
      case 'banners':
        if (_bannersTotal != null) live = '$_bannersTotal بانر · $_bannersActive فعّال';
      case 'spotlights':
        if (_spotlightsTotal != null) live = '$_spotlightsTotal عنصر · $_spotlightsActive فعّال';
      case 'coupons':
        if (_couponsActive != null) live = '$_couponsActive كوبون مفعّل';
      case 'reviews':
        if (_hiddenReviews != null && _hiddenReviews! > 0) live = '$_hiddenReviews تقييم مخفي';
      case 'social':
        if (_reportedPosts != null && _reportedPosts! > 0) live = '$_reportedPosts بلاغ بانتظار المراجعة';
    }
    return live ?? s.subtitle;
  }

  Widget _kpi({
    required String label,
    required int? value,
    required IconData icon,
    required Color color,
    required String sectionId,
    bool alertWhenPositive = false,
  }) {
    final s = _section(sectionId);
    return KpiTile(
      label: label,
      value: value == null ? (_loaded ? '—' : '…') : '$value',
      icon: icon,
      color: color,
      alert: alertWhenPositive && (value ?? 0) > 0,
      onTap: s == null ? null : () => _open(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = visibleContentSections();
    const groups = <(String, String, String)>[
      ('moderation', 'الإشراف', 'ما ينشره الزبائن ويحتاج مراجعة'),
      ('storefront', 'واجهة التطبيق', 'إعلانات وبطاقات الصفحة الرئيسية'),
      ('marketing', 'التسويق', 'أكواد الخصم وشروطها'),
    ];
    final kpis = <Widget>[
      if (_moderate)
        _kpi(
          label: 'بلاغات المنشورات',
          value: _reportedPosts,
          icon: Icons.flag_rounded,
          color: placeDanger,
          sectionId: 'social',
          alertWhenPositive: true,
        ),
      if (_moderate)
        _kpi(
          label: 'تقييمات مخفية',
          value: _hiddenReviews,
          icon: Icons.visibility_off_rounded,
          color: placeShiftMorning,
          sectionId: 'reviews',
        ),
      if (_content)
        _kpi(label: 'بانرات فعّالة', value: _bannersActive, icon: Icons.view_carousel_rounded, color: placeBrass, sectionId: 'banners'),
      if (_content)
        _kpi(
          label: 'مميزة فعّالة',
          value: _spotlightsActive,
          icon: Icons.auto_awesome_rounded,
          color: placeShiftEvening,
          sectionId: 'spotlights',
        ),
      if (_coupons)
        _kpi(label: 'كوبونات مفعّلة', value: _couponsActive, icon: Icons.local_offer_rounded, color: placeSuccess, sectionId: 'coupons'),
    ];

    return StaffPage(
      title: 'المحتوى والتسويق',
      subtitle: 'كل ما يراه الزبون: إعلانات، مميزة، خصومات، تقييمات ومنشورات',
      onRefresh: _load,
      slivers: [
        if (sections.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              title: 'لا أقسام متاحة',
              subtitle: 'اطلب من المشرف صلاحيات المحتوى أو الكوبونات أو التقييمات',
            ),
          )
        else ...[
          if (kpis.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: kpis,
              ),
            ),
          for (final g in groups)
            if (sections.any((s) => s.group == g.$1)) ...[
              SliverToBoxAdapter(
                child: SectionHeader(g.$2, subtitle: g.$3, count: g.$1 == 'moderation' ? _reportedPosts : null),
              ),
              SliverToBoxAdapter(
                child: Pad(
                  bottom: 0,
                  child: TileGroup(
                    children: [
                      for (final s in sections.where((s) => s.group == g.$1))
                        TaskTile(
                          icon: s.icon,
                          title: s.title,
                          subtitle: _subtitleFor(s),
                          color: s.color,
                          count: _countFor(s.id),
                          onTap: () => _open(s),
                        ),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ],
    );
  }
}
