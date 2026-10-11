import 'package:flutter/material.dart';

import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/ui.dart';
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
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> anyOf;
  final WidgetBuilder builder;

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
  ),
  ContentSection(
    id: 'reviews',
    title: 'التقييمات',
    subtitle: 'إخفاء وإظهار وحذف',
    icon: Icons.star_outline_rounded,
    color: placeShiftMorning,
    anyOf: const ['reviews.moderate'],
    builder: (_) => const AdminReviewsScreen(),
  ),
  ContentSection(
    id: 'social',
    title: 'منشورات التجارب',
    subtitle: 'البلاغات والإشراف',
    icon: Icons.photo_library_outlined,
    color: placeDanger,
    anyOf: const ['reviews.moderate'],
    builder: (_) => const AdminSocialScreen(),
  ),
];

List<ContentSection> visibleContentSections() => contentSections.where((s) => s.visible).toList();

/// كل صلاحيات قسم المحتوى — لإظهار مدخل الشاشة نفسها في الواجهة الأم.
const contentHubPermissions = <String>[
  'content.write',
  'content.moderate',
  'coupons.read',
  'coupons.write',
  'reviews.moderate',
];

bool get hasContentHubAccess => visibleContentSections().isNotEmpty;

/// مدخل «المحتوى والتسويق».
class ContentHubScreen extends StatelessWidget {
  const ContentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = visibleContentSections();
    return Scaffold(
      appBar: AppBar(title: const Text('المحتوى والتسويق')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const MaisonHeader(
            title: 'واجهة التطبيق',
            subtitle: 'كل ما يراه الزبون: إعلانات، مميزة، خصومات، تقييمات ومنشورات',
          ),
          const SizedBox(height: 8),
          if (sections.isEmpty)
            const EmptyState(
              title: 'لا أقسام متاحة',
              subtitle: 'اطلب من المشرف صلاحيات المحتوى أو الكوبونات أو التقييمات',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final width = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final s in sections) SizedBox(width: width, child: _SectionTile(section: s)),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});

  final ContentSection section;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          lightTap();
          Navigator.of(context).push(MaterialPageRoute(builder: section.builder));
        },
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: placeLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(section.icon, color: section.color, size: 22),
              ),
              const Spacer(),
              Text(
                section.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15, color: placeInk),
              ),
              Text(
                section.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
