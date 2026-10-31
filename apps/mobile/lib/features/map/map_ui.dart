import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../home/home_sections.dart';
import '../property/place_experience_ui.dart';

enum MapListSort { featured, priceLow, topRated }

enum MapLayer { standard, explore, satellite }

const Color mapInk = Color(0xFF141C2B);
const Color mapInk2 = Color(0xFF5A6678);
const Color mapLine = Color(0xFFE4E9F0);
const Color mapPaper = Color(0xFFF6F7F9);
const Color mapBrass = Color(0xFFA5813A);

List<BoxShadow> mapElev({double o = 1}) => [
  BoxShadow(
    color: Color.fromRGBO(20, 28, 43, 0.06 * o),
    blurRadius: 10,
    offset: const Offset(0, 3),
  ),
  BoxShadow(
    color: Color.fromRGBO(20, 28, 43, 0.1 * o),
    blurRadius: 32,
    offset: const Offset(0, 14),
  ),
];

/// لوحة علوية موحّدة: عنوان تحريري + بحث + فلاتر.
class MapHud extends StatelessWidget {
  const MapHud({
    super.key,
    required this.count,
    required this.showMap,
    required this.onToggle,
    required this.search,
    required this.searchFocus,
    required this.query,
    required this.onClearQuery,
    required this.onQueryChanged,
    required this.type,
    required this.onTypeChanged,
    required this.provinces,
    required this.provinceFilter,
    required this.onProvinceChanged,
    this.listSurface = false,
  });

  final int count;
  final bool showMap;
  final ValueChanged<bool> onToggle;
  final TextEditingController search;
  final FocusNode searchFocus;
  final String query;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onQueryChanged;
  final String? type;
  final ValueChanged<String?> onTypeChanged;
  final List<String> provinces;
  final String? provinceFilter;
  final ValueChanged<String?> onProvinceChanged;
  final bool listSurface;

  @override
  Widget build(BuildContext context) {
    // بلا ضبابية فوق الخريطة (تُعاد كل إطار أثناء تحريكها وتثقل الأجهزة)،
    // لذا خلفية أكثف تحفظ وضوح النص.
    final shellColor = listSurface
        ? Colors.white.withValues(alpha: 0.96)
        : mapInk.withValues(alpha: 0.78);
    final shellBorder = listSurface
        ? mapLine
        : Colors.white.withValues(alpha: 0.28);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: shellColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: shellBorder),
            boxShadow: [
              BoxShadow(
                color: mapInk.withValues(alpha: listSurface ? 0.06 : 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _MapGlassIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.maybePop(context),
                      light: listSurface,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: search,
                          focusNode: searchFocus,
                          onChanged: onQueryChanged,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: mapInk,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'ابحث…',
                            hintStyle: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: mapInk2.withValues(alpha: 0.7),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: mapInk2,
                            ),
                            suffixIcon: query.isNotEmpty
                                ? GestureDetector(
                                    onTap: onClearQuery,
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: mapInk2,
                                    ),
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: mapBrass.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _MapModeToggle(
                      showMap: showMap,
                      onToggle: onToggle,
                      light: listSurface,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 28,
                  child: _MapFilterRail(
                    type: type,
                    onTypeChanged: onTypeChanged,
                    provinces: provinces,
                    provinceFilter: provinceFilter,
                    onProvinceChanged: onProvinceChanged,
                    light: listSurface,
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

class _MapGlassIconBtn extends StatelessWidget {
  const _MapGlassIconBtn({
    required this.icon,
    required this.onTap,
    this.light = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: light ? mapPaper : Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: light ? mapInk : Colors.white),
        ),
      ),
    );
  }
}

class _MapModeToggle extends StatelessWidget {
  const _MapModeToggle({
    required this.showMap,
    required this.onToggle,
    this.light = false,
  });

  final bool showMap;
  final ValueChanged<bool> onToggle;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: light ? mapPaper : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: light ? mapLine : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeBtn(Icons.map_rounded, showMap, () => onToggle(true)),
          _modeBtn(Icons.view_list_rounded, !showMap, () => onToggle(false)),
        ],
      ),
    );
  }

  Widget _modeBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? (light ? mapInk : Colors.white.withValues(alpha: 0.95))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active
              ? (light ? Colors.white : mapInk)
              : (light ? mapInk2 : Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}

class _MapFilterRail extends StatelessWidget {
  const _MapFilterRail({
    required this.type,
    required this.onTypeChanged,
    required this.provinces,
    required this.provinceFilter,
    required this.onProvinceChanged,
    this.light = false,
  });

  final String? type;
  final ValueChanged<String?> onTypeChanged;
  final List<String> provinces;
  final String? provinceFilter;
  final ValueChanged<String?> onProvinceChanged;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final item in [
          (null, 'الكل', accentForType('FARM')),
          ('FARM', 'مزارع', accentForType('FARM')),
          ('HALL', 'قاعات', accentForType('HALL')),
          ('DECORATION', 'تزيين', accentForType('DECORATION')),
        ])
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: _FilterPill(
              label: item.$2,
              accent: item.$3,
              active: type == item.$1,
              compact: true,
              glass: !light,
              onTap: () {
                HapticFeedback.selectionClick();
                onTypeChanged(item.$1);
              },
            ),
          ),
        if (provinces.isNotEmpty) ...[
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsetsDirectional.only(end: 5, top: 5),
            color: light ? mapLine : Colors.white.withValues(alpha: 0.25),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: _FilterPill(
              label: 'العراق',
              accent: Brand.sapphire,
              active: provinceFilter == null,
              compact: true,
              glass: !light,
              onTap: () => onProvinceChanged(null),
            ),
          ),
          for (final name in provinces)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: _FilterPill(
                label: name,
                accent: Brand.sapphire,
                active: provinceFilter == name,
                compact: true,
                glass: !light,
                onTap: () => onProvinceChanged(name),
              ),
            ),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.accent,
    required this.active,
    required this.onTap,
    this.compact = false,
    this.glass = false,
  });

  final String label;
  final Color accent;
  final bool active;
  final VoidCallback onTap;
  final bool compact;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 14,
          vertical: compact ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: active
              ? accent
              : glass
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(compact ? 999 : 12),
          border: Border.all(
            color: active
                ? accent
                : glass
                ? Colors.white.withValues(alpha: 0.22)
                : mapLine,
            width: active ? 1.2 : 1,
          ),
          boxShadow: active && !glass
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w800,
            color: active
                ? Colors.white
                : glass
                ? Colors.white.withValues(alpha: 0.92)
                : mapInk,
          ),
        ),
      ),
    );
  }
}

class MapControlDock extends StatelessWidget {
  const MapControlDock({
    super.key,
    required this.layer,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.onFitAll,
    required this.onCycleLayer,
  });

  final MapLayer layer;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final VoidCallback onFitAll;
  final VoidCallback onCycleLayer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: RepaintBoundary(
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: mapElev(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapIconBtn(icon: Icons.add_rounded, onTap: onZoomIn),
              const _DockDivider(),
              _MapIconBtn(icon: Icons.remove_rounded, onTap: onZoomOut),
              const _DockDivider(),
              _MapIconBtn(
                icon: Icons.my_location_rounded,
                onTap: onLocate,
                tint: Brand.sapphire,
              ),
              const _DockDivider(),
              _MapIconBtn(icon: Icons.fit_screen_rounded, onTap: onFitAll),
              const _DockDivider(),
              _MapIconBtn(
                icon: switch (layer) {
                  MapLayer.standard => Icons.map_outlined,
                  MapLayer.explore => Icons.terrain_rounded,
                  MapLayer.satellite => Icons.satellite_alt_rounded,
                },
                onTap: onCycleLayer,
                tint: mapBrass,
                label: switch (layer) {
                  MapLayer.standard => 'خريطة',
                  MapLayer.explore => 'تضاريس',
                  MapLayer.satellite => 'قمر',
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  const _DockDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Container(height: 1, color: mapLine),
    );
  }
}

class _MapIconBtn extends StatelessWidget {
  const _MapIconBtn({
    required this.icon,
    required this.onTap,
    this.tint,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 52,
          height: label != null ? 48 : 42,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: tint ?? mapInk),
              if (label != null) ...[
                const SizedBox(height: 2),
                Text(
                  label!,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: mapInk2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MapPlaceRail extends StatelessWidget {
  const MapPlaceRail({
    super.key,
    required this.scrollController,
    required this.properties,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final List<Property> properties;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: mapBrass,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'أماكن قريبة',
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: mapInk,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 186,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: properties.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = properties[i];
              final accent = accentForType(p.type.name);
              final place = p.cityName ?? p.provinceName ?? '';
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(p.id);
                },
                child: Container(
                  width: 164,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: mapElev(o: 1.05),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (p.coverUrl != null)
                        VibesNetImage(url: p.coverUrl!, fit: BoxFit.cover)
                      else
                        ColoredBox(color: accent.withValues(alpha: 0.25)),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.35, 1],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 88),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                '${placeFullPrice(p.pricePerDay)} د.ع',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: mapInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.typeLabelAr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: accent.withValues(alpha: 0.95),
                              ),
                            ),
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                                color: Colors.white,
                              ),
                            ),
                            if (place.isNotEmpty)
                              Text(
                                place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MapSelectedCard extends StatelessWidget {
  const MapSelectedCard({
    super.key,
    required this.property,
    required this.onClose,
  });

  final Property property;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = accentForType(property.type.name);
    final place = property.cityName ?? property.provinceName ?? '';
    final amenities = property.amenityNames.take(3).toList();
    final desc = property.description.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: mapLine.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: mapInk.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 196,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (property.coverUrl != null)
                    VibesNetImage(url: property.coverUrl!, fit: BoxFit.cover)
                  else
                    ColoredBox(color: accent.withValues(alpha: 0.2)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 4, color: mapBrass),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _MapBadge(
                      label: property.typeLabelAr,
                      background: accent,
                      foreground: Colors.white,
                    ),
                  ),
                  if (property.featured)
                    const Positioned(
                      top: 12,
                      right: 52,
                      child: _MapBadge(
                        label: 'مختار',
                        background: mapBrass,
                        foreground: Colors.white,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _MapCloseBtn(onTap: onClose),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: mapInk,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 16, color: accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: mapInk2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (property.capacity > 0)
                        _MapStatChip(
                          icon: Icons.groups_rounded,
                          label: '${property.capacity} ضيف',
                          tint: accent,
                        ),
                      if (property.ratingCount > 0)
                        _MapStatChip(
                          icon: Icons.star_rounded,
                          label:
                              '${property.ratingAvg.toStringAsFixed(1)} (${property.ratingCount})',
                          tint: Brand.brassDeep,
                        ),
                      if (property.bookingsCount > 0)
                        _MapStatChip(
                          icon: Icons.event_available_rounded,
                          label: '${property.bookingsCount} حجز',
                          tint: mapInk2,
                        ),
                    ],
                  ),
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final a in amenities)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: mapPaper,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: mapLine),
                                ),
                                child: Text(
                                  a,
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: mapInk2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: mapInk2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: mapPaper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mapLine),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'يبدأ من',
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: mapInk2,
                              ),
                            ),
                            PlaceFullPriceText(property.pricePerDay, size: 22),
                            const SizedBox(height: 2),
                            Text(
                              'د.ع / يوم',
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: mapInk2,
                              ),
                            ),
                            if (property.supportsShifts &&
                                ((property.priceMorningShift ?? 0) > 0 ||
                                    (property.priceEveningShift ?? 0) > 0)) ...[
                              const SizedBox(height: 8),
                              Text(
                                [
                                  if ((property.priceMorningShift ?? 0) > 0)
                                    'صباح ${placeFullPrice(property.priceMorningShift!)}',
                                  if ((property.priceEveningShift ?? 0) > 0)
                                    'مساء ${placeFullPrice(property.priceEveningShift!)}',
                                ].join(' · '),
                                maxLines: 2,
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: mapInk2,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () =>
                              context.push(placeBookPath(property.id)),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'احجز',
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/property/${property.id}'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('صفحة المكان الكاملة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mapInk,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: mapLine),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: mapElev(o: 0.35),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _MapCloseBtn extends StatelessWidget {
  const _MapCloseBtn({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: RepaintBoundary(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
            ),
            child: const Icon(Icons.close_rounded, size: 20, color: mapInk),
          ),
        ),
      ),
    );
  }
}

class _MapStatChip extends StatelessWidget {
  const _MapStatChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: mapInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// قائمة الاستكشاف — واجهة تحريرية كاملة (وضع «قائمة» في الخريطة).
class MapPlacesListView extends StatefulWidget {
  const MapPlacesListView({
    super.key,
    required this.properties,
    required this.mappableCount,
    required this.loading,
    this.errorMessage,
    this.onRetry,
    required this.hasFilters,
    required this.onClearFilters,
    required this.onShowOnMap,
  });

  final List<Property> properties;
  final int mappableCount;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final ValueChanged<Property> onShowOnMap;

  @override
  State<MapPlacesListView> createState() => _MapPlacesListViewState();
}

class _MapPlacesListViewState extends State<MapPlacesListView> {
  MapListSort _sort = MapListSort.featured;

  List<Property> _sorted(List<Property> items) {
    final out = [...items];
    switch (_sort) {
      case MapListSort.featured:
        out.sort((a, b) {
          if (a.featured != b.featured) return a.featured ? -1 : 1;
          final r = b.ratingAvg.compareTo(a.ratingAvg);
          if (r != 0) return r;
          return a.name.compareTo(b.name);
        });
      case MapListSort.priceLow:
        out.sort((a, b) {
          final p = a.pricePerDay.compareTo(b.pricePerDay);
          if (p != 0) return p;
          return a.name.compareTo(b.name);
        });
      case MapListSort.topRated:
        out.sort((a, b) {
          final r = b.ratingAvg.compareTo(a.ratingAvg);
          if (r != 0) return r;
          return b.ratingCount.compareTo(a.ratingCount);
        });
    }
    return out;
  }

  Map<String, List<Property>> _sections(List<Property> sorted) {
    if (sorted.length < 4) {
      return {'النتائج': sorted};
    }
    final groups = <String, List<Property>>{};
    for (final p in sorted) {
      final key = p.provinceName ?? p.cityName ?? 'أماكن أخرى';
      groups.putIfAbsent(key, () => []).add(p);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));
    return {for (final k in keys) k: groups[k]!};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: ShimmerBox(height: 132, radius: 20),
        ),
      );
    }

    if (widget.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _MapListMessageCard(
            icon: Icons.cloud_off_rounded,
            title: 'تعذّر تحميل الأماكن',
            subtitle: widget.errorMessage!,
            actionLabel: 'إعادة المحاولة',
            onAction: widget.onRetry,
          ),
        ),
      );
    }

    if (widget.properties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _MapListMessageCard(
            icon: Icons.travel_explore_rounded,
            title: widget.hasFilters ? 'لا نتائج مطابقة' : 'لا أماكن بعد',
            subtitle: widget.hasFilters
                ? 'جرّب توسيع البحث أو مسح الفلاتر'
                : 'ستظهر المزارع والقاعات هنا فور إضافتها',
            actionLabel: widget.hasFilters ? 'مسح الفلاتر' : null,
            onAction: widget.hasFilters ? widget.onClearFilters : null,
          ),
        ),
      );
    }

    final sorted = _sorted(widget.properties);
    final sections = _sections(sorted);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _MapListHero(
            properties: widget.properties,
            onMap: widget.mappableCount,
            sort: _sort,
            onSortChanged: (s) {
              HapticFeedback.selectionClick();
              setState(() => _sort = s);
            },
          ),
        ),
      ),
    ];

    var indexOffset = 0;
    for (final entry in sections.entries) {
      final items = entry.value;
      final startIndex = indexOffset;
      indexOffset += items.length;

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _MapListSectionHeader(title: entry.key, count: items.length),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = items[i];
              return _MapListTile(
                property: p,
                index: startIndex + i + 1,
                onTap: () => context.push('/property/${p.id}'),
                onShowOnMap: p.latitude != null && p.longitude != null
                    ? () {
                        HapticFeedback.selectionClick();
                        widget.onShowOnMap(p);
                      }
                    : null,
              );
            },
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8ECF2), mapPaper, Colors.white],
        ),
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: slivers,
      ),
    );
  }
}

class _MapListHero extends StatelessWidget {
  const _MapListHero({
    required this.properties,
    required this.onMap,
    required this.sort,
    required this.onSortChanged,
  });

  final List<Property> properties;
  final int onMap;
  final MapListSort sort;
  final ValueChanged<MapListSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final total = properties.length;
    final farms = properties.where((p) => p.type == PropertyType.farm).length;
    final halls = properties.where((p) => p.type == PropertyType.hall).length;
    final deco = properties
        .where((p) => p.type == PropertyType.decoration)
        .length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: mapElev(o: 0.9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: mapBrass),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دليل الأماكن',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          color: mapInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اسحب الخريطة واكتشف ما حولك',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: mapInk2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: mapInk,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    total.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: mapPaper,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _MapTypeStat(
                  label: 'مزارع',
                  count: farms,
                  color: accentForType('FARM'),
                ),
                const SizedBox(width: 8),
                _MapTypeStat(
                  label: 'قاعات',
                  count: halls,
                  color: accentForType('HALL'),
                ),
                const SizedBox(width: 8),
                _MapTypeStat(
                  label: 'تزيين',
                  count: deco,
                  color: accentForType('DECORATION'),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MapSortChip(
                    label: 'مختارة',
                    active: sort == MapListSort.featured,
                    onTap: () => onSortChanged(MapListSort.featured),
                  ),
                  _MapSortChip(
                    label: 'الأقل سعراً',
                    active: sort == MapListSort.priceLow,
                    onTap: () => onSortChanged(MapListSort.priceLow),
                  ),
                  _MapSortChip(
                    label: 'الأعلى تقييماً',
                    active: sort == MapListSort.topRated,
                    onTap: () => onSortChanged(MapListSort.topRated),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTypeStat extends StatelessWidget {
  const _MapTypeStat({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mapLine),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: mapInk,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSortChip extends StatelessWidget {
  const _MapSortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? mapInk : mapPaper,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? mapInk : mapLine),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : mapInk2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapListSectionHeader extends StatelessWidget {
  const _MapListSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: mapBrass,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: mapInk,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: mapLine),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: mapInk2,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapListTile extends StatelessWidget {
  const _MapListTile({
    required this.property,
    required this.index,
    required this.onTap,
    this.onShowOnMap,
  });

  final Property property;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final accent = accentForType(property.type.name);
    final place = property.cityName ?? property.provinceName ?? '';
    final hasMap = onShowOnMap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 132,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: mapLine),
            boxShadow: mapElev(o: 0.65),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Row(
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              index.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: mapBrass,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                property.typeLabelAr,
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ),
                            if (property.featured) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: mapBrass,
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: mapInk2.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            color: mapInk,
                          ),
                        ),
                        const Spacer(),
                        if (place.isNotEmpty)
                          Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: mapInk2,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: mapPaper,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    placeFullPrice(property.pricePerDay),
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: mapInk,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'د.ع',
                                    style: TextStyle(
                                      fontFamily: VibesFont.ui,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: mapInk2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (property.ratingCount > 0) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Brand.brassDeep,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                property.ratingAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: mapInk,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 108,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (property.coverUrl != null)
                        VibesNetImage(
                          url: property.coverUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        ColoredBox(color: accent.withValues(alpha: 0.2)),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      if (hasMap)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onShowOnMap!();
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 1.5),
                                boxShadow: mapElev(o: 0.35),
                              ),
                              child: Icon(
                                Icons.map_rounded,
                                size: 17,
                                color: accent,
                              ),
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
      ),
    );
  }
}

class _MapListMessageCard extends StatelessWidget {
  const _MapListMessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: mapLine),
        boxShadow: mapElev(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: mapBrass),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: mapInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: mapInk2,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: mapInk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MapEmptyState extends StatelessWidget {
  const MapEmptyState({
    super.key,
    required this.loading,
    required this.hasFilters,
    required this.onClear,
  });

  final bool loading;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mapLine),
        boxShadow: mapElev(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            loading ? Icons.hourglass_top_rounded : Icons.map_outlined,
            size: 44,
            color: mapBrass,
          ),
          const SizedBox(height: 12),
          Text(
            loading
                ? 'جاري تحميل الخريطة…'
                : hasFilters
                ? 'لا نتائج مطابقة'
                : 'لا مواقع بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: mapInk,
            ),
          ),
          if (hasFilters && !loading) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onClear, child: const Text('مسح الفلاتر')),
          ],
        ],
      ),
    );
  }
}
