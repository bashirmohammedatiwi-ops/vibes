import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/compare/compare_feature.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import 'card_dimensions.dart';
import 'maison_shapes.dart';
import 'vibes_editorial.dart';
import 'vibes_graphics.dart';
import 'vibes_widgets.dart';
import '../../features/home/home_sections.dart' show accentForType;
import '../../core/perf/perf.dart';

// ── بطاقات VIBES — أبعاد دقيقة، طبقات واضحة، لمسة تحريرية ──

BorderRadius get _cardRadius => BorderRadius.circular(CardDims.radius);

String _propertyKicker(PropertyType type) => switch (type) {
  PropertyType.hall => 'قاعة أعراس',
  PropertyType.decoration => 'تزيين',
  PropertyType.farm => 'مزرعة',
};

String _propertyMeta(Property property) => [
  property.cityName ?? property.provinceName ?? '',
  if (property.isWinter) '❄️ شتوية',
  if (property.hasIndoorPool) '🏊 مسبح مغلق',
  if (property.capacity > 0) '${property.capacity} ضيف',
  if (property.ratingCount > 0) '★ ${property.ratingAvg.toStringAsFixed(1)}',
].where((part) => part.isNotEmpty).join('  ·  ');

VibesCategory _categoryFor(PropertyType type) => switch (type) {
  PropertyType.hall => VibesCategory.hall,
  PropertyType.decoration => VibesCategory.decoration,
  PropertyType.farm => VibesCategory.farm,
};

class _WorldKicker extends StatelessWidget {
  const _WorldKicker({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final accent = accentForType(property.type.name);
    final onAccent = switch (property.type) {
      PropertyType.farm => Vibes.onTeal,
      PropertyType.hall => Vibes.onCoral,
      PropertyType.decoration => Colors.white,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VibesCategoryIcon(
            category: _categoryFor(property.type),
            size: 12,
            color: onAccent,
          ),
          const SizedBox(width: 4),
          Text(
            _propertyKicker(property.type),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPhoto extends StatelessWidget {
  const _CardPhoto({
    required this.property,
    required this.heroTag,
    this.aspectRatio = CardDims.listingAspect,
    this.inset = CardDims.inset,
    this.fullBleed = false,
    this.borderRadius,
    this.onFavorite,
    this.isFavorite = false,
    this.showCompare = false,
    this.onSelectCompare,
    this.rank,
  });

  final Property property;
  final String heroTag;
  final double aspectRatio;
  final double inset;
  final bool fullBleed;
  final BorderRadius? borderRadius;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool showCompare;
  final ValueChanged<Property>? onSelectCompare;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;
    final accent = accentForType(property.type.name);

    Widget image = cover != null
        ? VibesNetImage(url: cover, fit: BoxFit.cover)
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.08),
                  VibesTheme.surfaceHighOf(context),
                ],
              ),
            ),
            child: Center(
              child: VibesCategoryIcon(
                category: _categoryFor(property.type),
                size: 40,
                color: accent.withValues(alpha: 0.5),
              ),
            ),
          );
    image = Hero(tag: heroTag, child: image);

    final radius = borderRadius ?? BorderRadius.zero;

    final photo = Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: radius, child: image),
        if (fullBleed)
          ClipRRect(
            borderRadius: radius,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1],
                  colors: [Colors.transparent, Color(0x8C000000)],
                ),
              ),
            ),
          ),
        if (!fullBleed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00A5813A),
                    Color(0xD9A5813A),
                    Color(0x00A5813A),
                  ],
                ),
              ),
            ),
          ),
        if (property.featured && !fullBleed)
          PositionedDirectional(
            top: 10,
            end: 10,
            child: RibbonChip(label: 'مميّز', color: accent),
          ),
        if (rank != null)
          PositionedDirectional(
            top: fullBleed ? 12 : 10,
            start: fullBleed ? 12 : 10,
            child: _RankBadge(rank: rank!),
          ),
        if (onFavorite != null)
          PositionedDirectional(
            top: fullBleed ? 48 : 44,
            end: fullBleed ? 12 : 10,
            child: _GuardedHeart(active: isFavorite, onToggle: onFavorite!),
          ),
        if (showCompare && onSelectCompare != null)
          PositionedDirectional(
            top: fullBleed ? 12 : 10,
            end: fullBleed ? 12 : 10,
            child: _CompareToggle(
              property: property,
              onSelect: onSelectCompare!,
            ),
          ),
      ],
    );

    if (fullBleed) return photo;

    return AspectRatio(aspectRatio: aspectRatio, child: photo);
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Brand.brassLight, Brand.brass]),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Brand.brass.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.property,
    required this.accent,
    this.compact = false,
    this.showChevron = true,
  });

  final Property property;
  final Color accent;
  final bool compact;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final place = property.cityName ?? property.provinceName ?? '';
    final guests = property.capacity > 0 ? '${property.capacity} ضيف' : '';
    final meta = [place, guests].where((s) => s.isNotEmpty).join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _propertyKicker(property.type),
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFA5813A),
                  height: 1,
                ),
              ),
              const Spacer(),
              if (property.ratingCount > 0) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: Color(0xFFC4A15A),
                ),
                const SizedBox(width: 3),
                Text(
                  property.ratingAvg.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF141C2B),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            property.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: Color(0xFF141C2B),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  meta.isEmpty ? property.typeLabelAr : meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C6778),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                PriceText.format(property.pricePerDay),
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF141C2B),
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 1),
                child: Text(
                  'د.ع',
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5C6778),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بطاقة قائمة — 4:3 صورة + جسم 92px
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.heroEnabled = true,
    this.onFavorite,
    this.isFavorite = false,
    this.compact = false,
    this.showCompare = false,
    this.onSelectCompare,
    this.heroNamespace = 'main',
  });

  final Property property;
  final bool heroEnabled;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool compact;
  final bool showCompare;
  final ValueChanged<Property>? onSelectCompare;
  final String heroNamespace;

  String get _heroTag => heroNamespace == 'main'
      ? 'property-hero-${property.id}'
      : 'property-hero-$heroNamespace-${property.id}';

  @override
  Widget build(BuildContext context) {
    final worldAccent = accentForType(property.type.name);

    if (compact) {
      return _CompactPropertyCard(
        property: property,
        accent: worldAccent,
        heroTag: heroEnabled ? _heroTag : 'property-static-${property.id}',
        onTap: () => context.push('/property/${property.id}'),
      );
    }

    // RepaintBoundary: بطاقات القوائم لا تعاد رسمها عند تمرير القائمة —
    // تحسين ملموس في سلاسة التمرير للقوائم الطويلة.
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label:
            '${property.name}، ${property.typeLabelAr} في ${property.cityName ?? ''}، السعر ${PriceText.format(property.pricePerDay)} دينار لليوم',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4E9F0)),
            boxShadow: Perf.shadows(const [
              BoxShadow(
                color: Color(0x12141C2B),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ]),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/property/${property.id}'),
              customBorder: RoundedRectangleBorder(borderRadius: _cardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CardPhoto(
                    property: property,
                    heroTag: heroEnabled
                        ? _heroTag
                        : 'property-static-${property.id}',
                    aspectRatio: CardDims.listingAspect,
                    onFavorite: onFavorite,
                    isFavorite: isFavorite,
                    showCompare: showCompare,
                    onSelectCompare: onSelectCompare,
                  ),
                  _CardBody(property: property, accent: worldAccent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة أفقية مضغوطة — للخريطة والقوائم الكثيفة
class _CompactPropertyCard extends StatelessWidget {
  const _CompactPropertyCard({
    required this.property,
    required this.accent,
    required this.heroTag,
    required this.onTap,
  });

  final Property property;
  final Color accent;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;

    return Container(
      height: CardDims.compactHeight,
      decoration: editorialCardShell(context, accent: accent),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(CardDims.insetSm),
            child: Row(
              children: [
                Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: CardDims.compactThumb,
                      height: CardDims.compactThumbHeight,
                      child: cover != null
                          ? VibesNetImage(url: cover, fit: BoxFit.cover)
                          : ColoredBox(
                              color: accent.withValues(alpha: 0.12),
                              child: Center(
                                child: VibesCategoryIcon(
                                  category: _categoryFor(property.type),
                                  size: 28,
                                  color: accent,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WorldKicker(property: property),
                      const SizedBox(height: 2),
                      Text(
                        property.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _propertyMeta(property),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: BrassPriceChip(
                          amount: property.pricePerDay,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// لوحة مختارات — 252×336 (3:4)
class FeaturedPropertyCard extends StatelessWidget {
  const FeaturedPropertyCard({
    super.key,
    required this.property,
    this.width = CardDims.homeRailWidth,
    this.aspect = CardDims.homeRailAspect,
    this.index,
    this.onFavorite,
    this.isFavorite = false,
    this.heroNamespace = 'featured',
  });

  static const double plateWidth = CardDims.featuredWidth;
  static const double captionHeight = 136;

  static double heightFor(
    double width, [
    double aspect = CardDims.homeRailAspect,
  ]) => width / aspect + captionHeight;
  static double get plateHeight => heightFor(CardDims.homeRailWidth);

  final Property property;
  final double width;
  final double aspect;
  final int? index;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final String heroNamespace;

  @override
  Widget build(BuildContext context) {
    final place = _propertyMeta(property);
    final cover = property.coverUrl;
    final accent = accentForType(property.type.name);
    final photoH = width / aspect;

    return SizedBox(
      width: width,
      height: photoH + captionHeight,
      child: Semantics(
        button: true,
        label: index == null
            ? property.name
            : '${index! + 1}. ${property.name}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Vibes.hairline),
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/property/${property.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: photoH,
                    width: width,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        cover != null
                            ? Hero(
                                tag:
                                    'property-hero-$heroNamespace-${property.id}',
                                child: VibesNetImage(
                                  url: cover,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : ColoredBox(
                                color: accent.withValues(alpha: 0.12),
                                child: Center(
                                  child: VibesCategoryIcon(
                                    category: _categoryFor(property.type),
                                    size: 36,
                                    color: accent,
                                  ),
                                ),
                              ),
                        if (isFavorite || onFavorite != null)
                          PositionedDirectional(
                            top: 8,
                            end: 8,
                            child: GestureDetector(
                              onTap: onFavorite == null
                                  ? null
                                  : () => onFavorite!(!isFavorite),
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: isFavorite ? Vibes.mapple : Vibes.ink,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WorldKicker(property: property),
                        const SizedBox(height: 8),
                        Text(
                          property.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: Vibes.ink,
                              ),
                        ),
                        if (place.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Vibes.inkSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        BrassPriceChip(
                          amount: property.pricePerDay,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة قاعة — 308×192 (16:10)
class HallPropertyCard extends StatelessWidget {
  const HallPropertyCard({
    super.key,
    required this.property,
    this.width = CardDims.hallWidth,
    this.heroNamespace = 'hall',
  });

  static const double photoAspect = CardDims.hallAspect;

  static double heightFor(double width) => CardDims.hallHeight(width);

  final Property property;
  final double width;
  final String heroNamespace;

  @override
  Widget build(BuildContext context) {
    final accent = accentForType(property.type.name);
    final place = _propertyMeta(property);

    return SizedBox(
      width: width,
      height: CardDims.hallHeight(width),
      child: EditorialFrame(
        accent: accent,
        radius: CardDims.radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/property/${property.id}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CardPhoto(
                  property: property,
                  heroTag: 'property-hero-$heroNamespace-${property.id}',
                  fullBleed: true,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.22, 0.58, 1],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.38),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.15),
                            accent,
                            Brand.brass,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: BrassPriceChip(
                    amount: property.pricePerDay,
                    onDark: true,
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          VibesCategoryIcon(
                            category: VibesCategory.hall,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'قاعة أعراس',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const Spacer(),
                          if (property.ratingCount > 0)
                            Text(
                              '★ ${property.ratingAvg.toStringAsFixed(1)}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        property.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                      ),
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareToggle extends ConsumerWidget {
  const _CompareToggle({required this.property, required this.onSelect});

  final Property property;
  final ValueChanged<Property> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref
        .watch(compareSelectionProvider)
        .any((p) => p.id == property.id);
    return GestureDetector(
      onTap: () {
        onSelect(property);
        HapticFeedback.selectionClick();
      },
      child: FolioPanel(
        color: selected ? Vibes.coral : const Color(0xE6FFFFFF),
        borderColor: selected ? Vibes.coral : Vibes.hairline,
        radius: Folio.compact,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            selected ? Icons.check_rounded : Icons.compare_arrows_rounded,
            size: 15,
            color: selected ? Colors.white : Vibes.ink,
          ),
        ),
      ),
    );
  }
}

class _GuardedHeart extends ConsumerWidget {
  const _GuardedHeart({required this.active, required this.onToggle});

  final bool active;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FavoriteHeart(
      active: active,
      size: 17,
      onToggle: (next) async {
        if (!ref.read(authControllerProvider).loggedIn) {
          final ok = await context.push<bool>('/login');
          if (ok != true || !context.mounted) return;
          if (!ref.read(authControllerProvider).loggedIn) return;
        }
        onToggle(next);
      },
    );
  }
}
