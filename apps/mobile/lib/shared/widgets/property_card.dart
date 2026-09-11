import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/compare/compare_feature.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import 'vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// بطاقة المكان الأنيقة — صورة بزاوية ناعمة + معلومات
/// "بطاقة Hero" تنقل صورتها لصفحة التفاصيل
/// ═══════════════════════════════════════════════════════════

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
  });

  final Property property;
  final bool heroEnabled;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool compact;

  /// زر اختيار للمقارنة (شاشات الاكتشاف)
  final bool showCompare;
  final ValueChanged<Property>? onSelectCompare;

  String get _heroTag => 'property-hero-${property.id}';

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;

    final image = Hero(
      tag: heroEnabled ? _heroTag : 'no-hero-${property.id}',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VibesRadius.lg),
        ),
        child: cover != null
            ? CachedNetworkImage(
                imageUrl: cover,
                height: compact ? 140.0 : 190,
                width: double.infinity,
                fit: BoxFit.cover,
                fadeInDuration: VibesMotion.base,
                errorWidget: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );

    return VibesCard(
      onTap: () => context.push('/property/${property.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              image,
              // تدرج سفلي خافت لعمق هادئ
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(VibesRadius.lg),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .22),
                      ],
                    ),
                  ),
                ),
              ),
              // شارة النوع — شريحة زجاجية
              Positioned(
                top: 10,
                right: 10,
                child: _TypeBadge(label: property.typeLabelAr),
              ),
              // التقييم
              if (property.ratingCount > 0)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: _GlassChip(
                    child: GoldRatingBar(
                      rating: property.ratingAvg.toDouble(),
                      size: 12,
                      showValue: true,
                      reviewCount: property.ratingCount,
                    ),
                  ),
                ),
              // المفضلة إن فعّلها المستدعي
              if (onFavorite != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: FavoriteHeart(
                    active: isFavorite,
                    onToggle: onFavorite!,
                    size: 18,
                  ),
                ),
              // اختيار للمقارنة
              if (showCompare && onSelectCompare != null)
                Positioned(
                  top: onFavorite != null ? 58 : 8,
                  left: 8,
                  child: _CompareToggle(
                    property: property,
                    onSelect: onSelectCompare!,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    property.cityName ?? '',
                    if (property.capacity > 0) '${property.capacity} ضيف',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VibesTheme.textTertiaryOf(context),
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PriceText(property.pricePerDay, compact: true),
                    const Spacer(),
                    if (property.supportsShifts)
                      Text(
                        'شفتات متاحة',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: GoldColors.gold.withValues(alpha: .8),
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        height: compact ? 140.0 : 190,
        color: VibesTheme.surfaceHighOf(context),
        child: Icon(
          Icons.home_work_outlined,
          size: 42,
          color: VibesTheme.textTertiaryOf(context),
        ),
      );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(VibesRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .40),
        borderRadius: BorderRadius.circular(VibesRadius.pill),
      ),
      child: child,
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// البطاقة المميزة الأفقية — لقسم "مميز" بتمرير أفقي
/// ═══════════════════════════════════════════════════════════

class FeaturedPropertyCard extends StatelessWidget {
  const FeaturedPropertyCard({
    super.key,
    required this.property,
    this.width = 280,
    this.onFavorite,
    this.isFavorite = false,
  });

  final Property property;
  final double width;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;

    return SizedBox(
      width: width,
      child: VibesCard(
        onTap: () => context.push('/property/${property.id}'),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'property-hero-${property.id}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(VibesRadius.lg),
                    ),
                    child: cover != null
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            height: 150,
                            width: width,
                            fit: BoxFit.cover,
                            fadeInDuration: VibesMotion.base,
                          )
                        : Container(
                            height: 150,
                            color: VibesTheme.surfaceHighOf(context),
                          ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: GoldColors.gradient,
                      borderRadius: BorderRadius.circular(VibesRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: GoldColors.onGold),
                        const SizedBox(width: 3),
                        Text(
                          'مميز',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: GoldColors.onGold,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${property.cityName ?? ''} · ${property.provinceName ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                        ),
                  ),
                  const SizedBox(height: 10),
                  PriceText(property.pricePerDay),
                ],
              ),
            ),
          ],
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
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? GoldColors.gold : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? GoldColors.goldLight : Colors.white24,
          ),
        ),
        child: Icon(
          selected ? Icons.check_rounded : Icons.compare_arrows_rounded,
          size: 15,
          color: selected ? GoldColors.onGold : Colors.white,
        ),
      ),
    );
  }
}
