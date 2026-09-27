import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/compare/compare_feature.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import 'maison_shapes.dart';
import 'vibes_widgets.dart';

/// بطاقة مكان — لوحة 16:10 + شريط بيانات محكم
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
    final cover = property.coverUrl;
    final kicker = switch (property.type) {
      PropertyType.hall => 'قاعة أعراس',
      PropertyType.decoration => 'تزيين',
      PropertyType.farm => 'مزرعة',
    };
    final meta = [
      property.cityName ?? property.provinceName ?? '',
      if (property.capacity > 0) '${property.capacity} ضيف',
      if (property.ratingCount > 0) property.ratingAvg.toStringAsFixed(1),
    ].where((part) => part.isNotEmpty).join('  ·  ');

    return Semantics(
      button: true,
      label:
          '${property.name}، ${property.typeLabelAr} في ${property.cityName ?? ''}، السعر ${PriceText.format(property.pricePerDay)} دينار لليوم',
      child: FolioPanel(
        railColor: property.featured ? Vibes.teal : null,
        shadows: VibesTheme.cardOf(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/property/${property.id}'),
            customBorder: Folio.shape,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: compact ? 16 / 9 : Folio.listingPhoto,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      () {
                        final image = cover != null
                            ? VibesNetImage(url: cover, fit: BoxFit.cover)
                            : ColoredBox(
                                color: VibesTheme.surfaceHighOf(context),
                                child: Icon(
                                  Icons.home_work_outlined,
                                  size: 36,
                                  color: VibesTheme.textTertiaryOf(context),
                                ),
                              );
                        if (!heroEnabled) return image;
                        return Hero(tag: _heroTag, child: image);
                      }(),
                      const Positioned.fill(
                        child: PlateCorners(inset: 8, arm: 11),
                      ),
                      if (onFavorite != null)
                        PositionedDirectional(
                          top: 10,
                          start: 10,
                          child: _GuardedHeart(
                            active: isFavorite,
                            onToggle: onFavorite!,
                          ),
                        ),
                      if (showCompare && onSelectCompare != null)
                        PositionedDirectional(
                          top: onFavorite != null ? 52 : 10,
                          start: 10,
                          child: _CompareToggle(
                            property: property,
                            onSelect: onSelectCompare!,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 1.5,
                  child: ColoredBox(color: Vibes.teal),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compact ? 8 : 10,
                    16,
                    compact ? 8 : 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kicker,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Vibes.teal,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriceText(property.pricePerDay, compact: true),
                        ],
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

/// مختارات أفقية — لوحة عمودية 3:4 بصورة كاملة وتعليق فوقها
class FeaturedPropertyCard extends StatelessWidget {
  const FeaturedPropertyCard({
    super.key,
    required this.property,
    this.width = plateWidth,
    this.index,
    this.onFavorite,
    this.isFavorite = false,
    this.heroNamespace = 'featured',
  });

  static const double plateWidth = 220;
  static const double photoAspect = 16 / 10;
  static const double captionHeight = 64;
  static double heightFor(double width) => width / photoAspect + captionHeight;
  static double get plateHeight => heightFor(plateWidth);

  final Property property;
  final double width;
  final int? index;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final String heroNamespace;

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;
    final place = [
      property.cityName ?? property.provinceName ?? '',
      if (property.capacity > 0) '${property.capacity} ضيف',
    ].where((part) => part.isNotEmpty).join('  ·  ');

    return SizedBox(
      width: width,
      height: heightFor(width),
      child: FolioPanel(
        shadows: VibesTheme.cardOf(context),
        color: VibesTheme.surfaceOf(context),
        borderColor: VibesTheme.hairlineOf(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/property/${property.id}'),
            customBorder: Folio.shape,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'property-hero-$heroNamespace-${property.id}',
                        child: cover != null
                            ? VibesNetImage(url: cover, fit: BoxFit.cover)
                            : ColoredBox(
                                color: VibesTheme.surfaceHighOf(context),
                              ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, .72, 1],
                            colors: [
                              Color(0x14000000),
                              Color(0x00000000),
                              Color(0x330F2138),
                            ],
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: PlateCorners(inset: 8, arm: 11),
                      ),
                      if (onFavorite != null)
                        PositionedDirectional(
                          top: 10,
                          start: 10,
                          child: _GuardedHeart(
                            active: isFavorite,
                            onToggle: onFavorite!,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 1,
                  child: ColoredBox(color: Vibes.teal),
                ),
                SizedBox(
                  height: captionHeight - 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          property.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: VibesTheme.textTertiaryOf(context),
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PriceText(property.pricePerDay, compact: true),
                          ],
                        ),
                      ],
                    ),
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

/// بطاقة قاعة — صورة عريضة كلوحة مناسبة، وتعليق بورقة دعوة
class HallPropertyCard extends StatelessWidget {
  const HallPropertyCard({
    super.key,
    required this.property,
    this.width = 292,
    this.heroNamespace = 'hall',
  });

  static const double photoAspect = 16 / 9;
  static const double captionHeight = 84;
  static const double ruleHeight = 5;

  static double heightFor(double width) =>
      width / photoAspect + ruleHeight + captionHeight;

  final Property property;
  final double width;
  final String heroNamespace;

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;
    final place = [
      property.cityName ?? property.provinceName ?? '',
      if (property.capacity > 0) '${property.capacity} ضيف',
    ].where((part) => part.isNotEmpty).join('  ·  ');

    return SizedBox(
      width: width,
      height: heightFor(width),
      child: FolioPanel(
        shadows: VibesTheme.cardOf(context),
        color: VibesTheme.surfaceOf(context),
        borderColor: VibesTheme.hairlineOf(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/property/${property.id}'),
            customBorder: Folio.shape,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'property-hero-$heroNamespace-${property.id}',
                        child: cover != null
                            ? VibesNetImage(url: cover, fit: BoxFit.cover)
                            : const ColoredBox(color: VibesDark.canvas),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, .55, 1],
                            colors: [
                              Color(0x220F2138),
                              Color(0x00000000),
                              Color(0x590F2138),
                            ],
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: PlateCorners(inset: 10, arm: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 1.5,
                  child: ColoredBox(color: Vibes.teal),
                ),
                const SizedBox(height: 3),
                const SizedBox(
                  height: 0.5,
                  child: ColoredBox(color: Vibes.teal),
                ),
                SizedBox(
                  height: captionHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قاعة أعراس',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Vibes.teal,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          property.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: VibesTheme.textTertiaryOf(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PriceText(property.pricePerDay, compact: true),
                          ],
                        ),
                      ],
                    ),
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
