import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../compare/compare_feature.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/property_card.dart';

/// ═══════════════════════════════════════════════════════════
/// الرئيسية — تحية مسرحية، بانرات، تصنيفات، أقسام أنيقة
/// ═══════════════════════════════════════════════════════════

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'طاب يومك';
    return 'مساء النور';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // الهيرو السينمائي — بانرات بملء العرض بتلاشي سفلي + تحية وبحث
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            collapsedHeight: 68,
            backgroundColor: VibesTheme.canvasOf(context),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: _CinematicHero(greeting: _greeting()),
            ),
          ),

          // شريط الوصول السريع: خريطة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GestureDetector(
                onTap: () => context.push('/map'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: VibesTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(VibesRadius.md),
                    border: Border.all(color: VibesTheme.hairlineOf(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, size: 18, color: GoldColors.gold),
                      const SizedBox(width: 10),
                      Text(
                        'استعرض الأماكن على الخريطة',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_left_rounded,
                          size: 18,
                          color: VibesTheme.textTertiaryOf(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // التصنيفات — بطاقات بصور
          const SliverToBoxAdapter(child: _CategoriesSection()),
          // مميز
          const SliverToBoxAdapter(child: _FeaturedSection()),
          // الأعلى تقييماً
          const SliverToBoxAdapter(child: _TopRatedSection()),
          // كل الأماكن
          const _AllPropertiesSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// الهيرو السينمائي — دوّار بملء العرض مع تعتيم متدرج وتحية فوقه
class _CinematicHero extends StatelessWidget {
  const _CinematicHero({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final banners = ref.watch(bannersProvider);

        return banners.maybeWhen(
          data: (list) {
            if (list.isEmpty) {
              // بلا بانرات — خلفية هادئة والبحث فقط
              return _HeaderFallback(greeting: greeting);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: list.length,
                  // دوران تلقائي هادئ كل 5 ثوانٍ
                  onPageChanged: (_) {},
                  itemBuilder: (context, i) {
                    final banner = list[i];
                    return GestureDetector(
                      onTap: () {
                        final link = banner.linkUrl;
                        if (link != null &&
                            link.startsWith('/search') &&
                            link.contains('type=')) {
                          context.push(link);
                        }
                      },
                      child: CachedNetworkImage(
                        imageUrl: banner.imageUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: VibesMotion.slow,
                      ),
                    );
                  },
                ),
                // تعتيم سينمائي من الأسفل للقراءة
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [.30, .72, 1],
                        colors: [
                          Colors.black.withValues(alpha: .30),
                          VibesTheme.canvasOf(context).withValues(alpha: .55),
                          VibesTheme.canvasOf(context),
                        ],
                      ),
                    ),
                  ),
                ),
                // المحتوى فوق الهيرو
                _HeaderContent(greeting: greeting, onTopOfImage: true),
              ],
            );
          },
          orElse: () => _HeaderFallback(greeting: greeting),
        );
      },
    );
  }
}

class _HeaderFallback extends StatelessWidget {
  const _HeaderFallback({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) =>
      _HeaderContent(greeting: greeting, onTopOfImage: false);
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({required this.greeting, this.onTopOfImage = false});

  final String greeting;
  final bool onTopOfImage;

  @override
  Widget build(BuildContext context) {
    final light = onTopOfImage
        ? Colors.white
        : VibesTheme.textPrimaryOf(context);
    final light2 = onTopOfImage
        ? Colors.white70
        : VibesTheme.textTertiaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting —',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: light2,
                ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'مكان مناسبتك',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w300,
                      color: light,
                    ),
              ),
              ShaderMask(
                shaderCallback: (b) =>
                    GoldColors.textGradient.createShader(b),
                child: Text(
                  ' يبدأ هنا',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/search'),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: VibesTheme.surfaceOf(context).withValues(
                  alpha: onTopOfImage ? .92 : 1,
                ),
                borderRadius: BorderRadius.circular(VibesRadius.pill),
                border: Border.all(color: VibesTheme.hairlineOf(context)),
                boxShadow: onTopOfImage
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .22),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 20, color: VibesTheme.textTertiaryOf(context)),
                  const SizedBox(width: 10),
                  Text(
                    'ابحث عن مزرعة، قاعة، تزيين…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                        ),
                  ),
                  const Spacer(),
                  Icon(Icons.tune_rounded,
                      size: 19, color: GoldColors.gold.withValues(alpha: .85)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// التصنيفات الثلاثة — أيقونات رفيعة بخط ذهبي
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  @override
  Widget build(BuildContext context) {
    // تصنيفات بصور غلاف من الأماكن المميزة عند توفرها
    return Consumer(
      builder: (context, ref, _) {
        final featured = ref.watch(featuredPropertiesProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: SizedBox(
            height: 88,
            child: Row(
              children: [
                _ImageCategoryCard(
                  label: 'مزارع',
                  type: 'FARM',
                  imageUrl: featured.maybeWhen(
                    data: (list) => list
                        .where((p) => p.type == PropertyType.farm)
                        .firstOrNull
                        ?.coverUrl,
                    orElse: () => null,
                  ),
                ),
                const SizedBox(width: 10),
                _ImageCategoryCard(
                  label: 'قاعات',
                  type: 'HALL',
                  imageUrl: featured.maybeWhen(
                    data: (list) => list
                        .where((p) => p.type == PropertyType.hall)
                        .firstOrNull
                        ?.coverUrl,
                    orElse: () => null,
                  ),
                ),
                const SizedBox(width: 10),
                _ImageCategoryCard(
                  label: 'تزيين',
                  type: 'DECORATION',
                  imageUrl: featured.maybeWhen(
                    data: (list) => list
                        .where((p) => p.type == PropertyType.decoration)
                        .firstOrNull
                        ?.coverUrl,
                    orElse: () => null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VibesRadius.lg),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: VibesTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(VibesRadius.lg),
            border: Border.all(color: VibesTheme.hairlineOf(context)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 26, color: GoldColors.gold),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: VibesTheme.textPrimaryOf(context),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قسم عام — عنوان + محتوى أفقي
class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final featured = ref.watch(featuredPropertiesProvider);
        return featured.maybeWhen(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 26),
              child: Column(
                children: [
                  SectionHeader('مميز', subtitle: 'اختيارات VIBES المميزة')
                      .animate()
                      .fadeIn(),
                  SizedBox(
                    height: 265,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) =>
                          FeaturedPropertyCard(property: list[i]),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _TopRatedSection extends StatelessWidget {
  const _TopRatedSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final top = ref.watch(topRatedPropertiesProvider);
        return top.maybeWhen(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
              child: Column(
                children: [
                  const SectionHeader('الأعلى تقييماً'),
                  ...list.take(3).map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PropertyCard(property: p, compact: true),
                        ),
                      ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _AllPropertiesSection extends StatelessWidget {
  const _AllPropertiesSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final properties = ref.watch(propertiesProvider(null));

        return properties.when(
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerBox(
                        height: 240, radius: VibesRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: ErrorCanvas(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(propertiesProvider(null)),
            ),
          ),
          data: (list) => SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                i == 0 ? 26 : 0,
                20,
                14,
              ),
              child: PropertyCard(
                property: list[i],
                showCompare: true,
                onSelectCompare: (p) => ref
                    .read(compareSelectionProvider.notifier)
                    .toggle(p),
                isFavorite: ref
                    .watch(favoritesProvider)
                    .value
                    ?.any((p) => p.id == list[i].id) ??
                    false,
                onFavorite: (_) => ref
                    .read(favoritesProvider.notifier)
                    .toggle(list[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// بطاقة تصنيف بصورة — تمرير للبحث المفلتر
class _ImageCategoryCard extends StatelessWidget {
  const _ImageCategoryCard({
    required this.label,
    required this.type,
    this.imageUrl,
  });

  final String label;
  final String type;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push('/search?type=$type'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VibesRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: VibesMotion.base,
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: GoldColors.gradient,
                  ),
                  child: const SizedBox.expand(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .45),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
