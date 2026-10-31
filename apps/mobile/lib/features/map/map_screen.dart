import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/map_constants.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/directions_sheet.dart';
import '../../shared/widgets/vibes_map.dart';
import '../../shared/widgets/world_ui.dart';
import '../home/home_sections.dart';
import 'map_ui.dart';

/// ═══════════════════════════════════════════════════════════
/// الخريطة — بلون العالم وبأسماء عربية:
///   • شريط بحث عائم وفلاتر عوالم بعدّاد لكل عالم ومحافظات.
///   • دبابيس صور بحلقة متدرّجة وكبسولة سعر؛ المحدد يتوهّج.
///   • بطاقات أفقية متزامنة مع الخريطة: سحب البطاقة يطير بالكاميرا
///     إلى مكانها، ولمس الدبوس يقلّب البطاقات إليه.
///   • لوحة تحكم: الطبقة، موقعي، عرض الكل.
/// ═══════════════════════════════════════════════════════════

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialType, this.initialPropertyId});

  /// FARM | HALL | DECORATION
  final String? initialType;
  final String? initialPropertyId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapCtrl = VibesMapController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _cards = PageController(viewportFraction: .86);

  bool _showMap = true;
  String? _selectedId;
  String? _type;
  String? _provinceFilter;
  MapLayer _layer = MapLayer.standard;
  String _query = '';
  bool _initialFocusDone = false;

  /// التقليب البرمجي للبطاقات (من لمس دبوس) لا يعيد تحريك الكاميرا.
  bool _cardsDriven = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initialType?.toUpperCase();
    if (t == 'FARM' || t == 'HALL' || t == 'DECORATION') _type = t;
    _selectedId = widget.initialPropertyId;
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _cards.dispose();
    super.dispose();
  }

  /// لا نسخة ليلية من outdoors؛ طبقة الاستكشاف ليلاً خريطة طرق داكنة.
  static const _exploreNightStyleUri =
      'mapbox://styles/mapbox/navigation-night-v1';

  /// تتبع المظهر: VibesMapView يعيد تحميل الستايل حين تتغيّر القيمة.
  String get _styleUri => switch (_layer) {
    MapLayer.standard =>
      Appearance.isDark ? MapConstants.darkStyleUri : MapConstants.styleUri,
    MapLayer.explore =>
      Appearance.isDark ? _exploreNightStyleUri : MapConstants.exploreStyleUri,
    MapLayer.satellite => MapConstants.satelliteStyleUri,
  };

  WorldPalette get _palette =>
      _type != null ? WorldPalette.forType(_type) : context.world;

  VibesMapTint _tintFor(WorldPalette p) => VibesMapTint(
    land: Color.lerp(const Color(0xFFF6F5F1), p.canvasTint, .45)!,
    water: Color.lerp(const Color(0xFFC6DCEC), p.accentLight, .10)!,
    green: Color.lerp(const Color(0xFFDDEBD3), p.canvasTint, .25)!,
    building: Color.lerp(const Color(0xFFE9E6DF), p.canvasTint, .5)!,
  );

  bool _matchesType(Property p) =>
      _type == null || p.type.name.toUpperCase() == _type;

  List<Property> _filtered(
    List<Property> list, {
    bool applyProvince = true,
    bool applyType = true,
  }) {
    var out = applyType ? list.where(_matchesType).toList() : list;
    if (applyProvince && _provinceFilter != null) {
      out = out
          .where(
            (p) =>
                p.provinceName == _provinceFilter ||
                p.cityName == _provinceFilter,
          )
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                (p.cityName ?? '').toLowerCase().contains(q) ||
                (p.provinceName ?? '').toLowerCase().contains(q) ||
                (p.cityName ?? '').tr.toLowerCase().contains(q) ||
                (p.provinceName ?? '').tr.toLowerCase().contains(q),
          )
          .toList();
    }
    return out;
  }

  List<String> _topProvinces(List<Property> mappable) {
    final counts = <String, int>{};
    for (final p in mappable) {
      final name = p.provinceName ?? p.cityName;
      if (name == null || name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((e) => e.key).toList();
  }

  void _setType(String? t) {
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      _provinceFilter = null;
      _selectedId = null;
    });
    if (_cards.hasClients) _cards.jumpToPage(0);
  }

  void _clearFilters() => setState(() {
    _type = null;
    _provinceFilter = null;
    _query = '';
    _search.clear();
    _selectedId = null;
  });

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider(null));
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final palette = _palette;

    final list = properties.valueOrNull ?? const <Property>[];
    final filtered = _filtered(list);
    final mappable = filtered
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();
    final selected = mappable.where((p) => p.id == _selectedId).firstOrNull;

    // عدّادات العوالم (بعد البحث والمحافظة، قبل فلتر النوع)
    final forCounts = _filtered(
      list,
      applyType: false,
    ).where((p) => p.latitude != null && p.longitude != null);
    final counts = {
      null: forCounts.length,
      for (final s in HomeSection.values)
        s.typeFilter: forCounts
            .where((p) => p.type.name.toUpperCase() == s.typeFilter)
            .length,
    };
    final provinces = _topProvinces(
      _filtered(
        list,
        applyProvince: false,
      ).where((p) => p.latitude != null && p.longitude != null).toList(),
    );

    if (!_initialFocusDone &&
        _showMap &&
        _selectedId != null &&
        selected != null) {
      _initialFocusDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapCtrl.flyToLatLng(
          selected.latitude!,
          selected.longitude!,
          zoom: 14.8,
        );
        final i = mappable.indexOf(selected);
        if (i >= 0 && _cards.hasClients) _cards.jumpToPage(i);
      });
    }

    final header = _MapHeader(
      palette: palette,
      onDark: false,
      showMap: _showMap,
      search: _search,
      searchFocus: _searchFocus,
      query: _query,
      onQuery: (v) => setState(() {
        _query = v;
        _selectedId = null;
      }),
      onClearQuery: () => setState(() {
        _query = '';
        _search.clear();
      }),
      onToggleView: () {
        HapticFeedback.selectionClick();
        _searchFocus.unfocus();
        setState(() => _showMap = !_showMap);
      },
      type: _type,
      counts: counts,
      onType: _setType,
      provinces: provinces.length > 1 ? provinces : const [],
      province: _provinceFilter,
      onProvince: (v) => setState(() {
        _provinceFilter = v;
        _selectedId = null;
      }),
    );

    // ── وضع القائمة ──
    if (!_showMap) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayFor(darkBackground: Appearance.isDark),
        child: ColoredBox(
          color: palette.canvas,
          child: Column(
            children: [
              SizedBox(height: top + 8),
              header,
              Expanded(
                child: MapPlacesListView(
                  properties: filtered,
                  mappableCount: mappable.length,
                  loading: properties.isLoading,
                  errorMessage: properties.hasError
                      ? maisonError(properties.error!)
                      : null,
                  onRetry: () => ref.invalidate(propertiesProvider(null)),
                  hasFilters:
                      _type != null ||
                      _query.isNotEmpty ||
                      _provinceFilter != null,
                  onClearFilters: _clearFilters,
                  onShowOnMap: (p) {
                    setState(() {
                      _showMap = true;
                      _selectedId = p.id;
                      _initialFocusDone = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── وضع الخريطة ──
    const cardsHeight = 132.0;
    final headerHeight = provinces.isEmpty ? 116.0 : 160.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(
        darkBackground: Appearance.isDark || _layer == MapLayer.satellite,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VibesMapView(
            controller: _mapCtrl,
            styleUri: _styleUri,
            tint: Appearance.isDark ? null : _tintFor(palette),
            pitch: _layer == MapLayer.satellite ? 42 : 0,
            fitBounds: mappable.isNotEmpty,
            focusCluster: mappable.isNotEmpty && _query.isEmpty,
            fitMarkers: _fitMarkersForCamera(mappable),
            flyToSelection: false,
            zoom: mappable.length == 1 ? 13.5 : 5.8,
            centerLat: mappable.firstOrNull?.latitude,
            centerLng: mappable.firstOrNull?.longitude,
            padding: EdgeInsets.fromLTRB(
              40,
              top + headerHeight + 12,
              40,
              bottom + cardsHeight + 40,
            ),
            markers: [for (final p in mappable) _markerFor(p)],
            selectedId: _selectedId,
            onMarkerTap: (m) => _pickFromMap(m.id, mappable),
            onMapTap: () {
              _searchFocus.unfocus();
              if (_selectedId != null) setState(() => _selectedId = null);
            },
          ),

          // ظل علوي خفيف يمنح الشريط العائم عمقاً
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 90,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.canvas.withValues(alpha: .85),
                      palette.canvas.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (mappable.isEmpty)
            Center(
              child: MapEmptyState(
                loading: properties.isLoading,
                hasFilters:
                    _type != null ||
                    _query.isNotEmpty ||
                    _provinceFilter != null,
                onClear: _clearFilters,
              ),
            ),

          Positioned(top: top + 8, left: 0, right: 0, child: header),

          // لوحة التحكم
          PositionedDirectional(
            end: 14,
            top: top + headerHeight + 14,
            child: _ControlDock(
              palette: palette,
              layer: _layer,
              onLayer: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _layer = switch (_layer) {
                    MapLayer.standard => MapLayer.explore,
                    MapLayer.explore => MapLayer.satellite,
                    MapLayer.satellite => MapLayer.standard,
                  };
                });
              },
              onLocate: _goToMyLocation,
              onFitAll: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedId = null);
                _mapCtrl.fitToMarkers();
              },
            ),
          ),

          // البطاقات المتزامنة
          if (mappable.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottom + 14,
              height: cardsHeight,
              child: PageView.builder(
                controller: _cards,
                itemCount: mappable.length,
                padEnds: true,
                onPageChanged: (i) {
                  if (_cardsDriven) return;
                  HapticFeedback.selectionClick();
                  final p = mappable[i];
                  setState(() => _selectedId = p.id);
                  _mapCtrl.flyToLatLng(p.latitude!, p.longitude!, zoom: 14.6);
                },
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _PlaceCard(
                    property: mappable[i],
                    selected: mappable[i].id == _selectedId,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// لمس دبوس: تحديد، طيران واحد للكاميرا، وتقليب البطاقات إليه.
  Future<void> _pickFromMap(String id, List<Property> mappable) async {
    HapticFeedback.selectionClick();
    final i = mappable.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final p = mappable[i];
    setState(() => _selectedId = id);
    _mapCtrl.flyToLatLng(p.latitude!, p.longitude!, zoom: 14.6);
    if (_cards.hasClients) {
      _cardsDriven = true;
      await _cards.animateToPage(
        i,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      _cardsDriven = false;
    }
  }

  Future<void> _goToMyLocation() async {
    HapticFeedback.selectionClick();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فعّل صلاحية الموقع من إعدادات الجهاز'.tr),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      await _mapCtrl.flyToLatLng(pos.latitude, pos.longitude, zoom: 13.2);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر تحديد موقعك حالياً'.tr),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  VibesMapMarker _markerFor(Property p) {
    final world = WorldPalette.forType(p.type.name);
    return VibesMapMarker(
      id: p.id,
      latitude: p.latitude!,
      longitude: p.longitude!,
      imageUrl: p.coverUrl,
      label: _shortPrice(_fromPrice(p)),
      accent: world.accent,
      accentLight: world.accentLight,
      photoPin: true,
    );
  }

  /// بلا فلتر نوع: التأطير الأولي على أكثف تجمّع للمزارع.
  List<VibesMapMarker> _fitMarkersForCamera(List<Property> visible) {
    if (visible.isEmpty) return const [];
    var focus = visible;
    if (_type == null) {
      final farms = visible.where((p) => p.type == PropertyType.farm).toList();
      if (farms.isNotEmpty) focus = farms;
    }
    return focus.map(_markerFor).toList();
  }
}

num _fromPrice(Property p) {
  final prices = <num>[
    p.pricePerDay,
    if (p.priceMorningShift != null) p.priceMorningShift!,
    if (p.priceEveningShift != null) p.priceEveningShift!,
  ].where((v) => v > 0).toList()..sort();
  return prices.isEmpty ? p.pricePerDay : prices.first;
}

/// «250 ألف» / «1.5 مليون» — مختصر للدبابيس.
String _shortPrice(num v) {
  if (v <= 0) return '';
  if (v >= 1000000) {
    final m = v / 1000000;
    return '{n} مليون'.trArgs({
      'n': m == m.roundToDouble() ? m.toInt() : m.toStringAsFixed(1),
    });
  }
  if (v >= 1000) return '{n} ألف'.trArgs({'n': (v / 1000).round()});
  return '${v.round()}';
}

// ═══════════════════════════════════════════════════════════
// الرأس العائم — بحث + تبديل العرض + فلاتر
// ═══════════════════════════════════════════════════════════

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.palette,
    required this.onDark,
    required this.showMap,
    required this.search,
    required this.searchFocus,
    required this.query,
    required this.onQuery,
    required this.onClearQuery,
    required this.onToggleView,
    required this.type,
    required this.counts,
    required this.onType,
    required this.provinces,
    required this.province,
    required this.onProvince,
  });

  final WorldPalette palette;
  final bool onDark;
  final bool showMap;
  final TextEditingController search;
  final FocusNode searchFocus;
  final String query;
  final ValueChanged<String> onQuery;
  final VoidCallback onClearQuery;
  final VoidCallback onToggleView;
  final String? type;
  final Map<String?, int> counts;
  final ValueChanged<String?> onType;
  final List<String> provinces;
  final String? province;
  final ValueChanged<String?> onProvince;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _Round(
                icon: Icons.arrow_back_rounded,
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
                  decoration: BoxDecoration(
                    color: Vibes.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: .16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .10),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: palette.accentDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: search,
                          focusNode: searchFocus,
                          onChanged: onQuery,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Vibes.ink,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintText: 'ابحث عن مكان أو مدينة'.tr,
                            hintStyle: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Vibes.inkTertiary,
                            ),
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onClearQuery,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 19,
                            color: Vibes.inkSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Round(
                icon: showMap ? Icons.view_agenda_outlined : Icons.map_outlined,
                tooltip: showMap ? 'عرض كقائمة'.tr : 'عرض على الخريطة'.tr,
                onTap: onToggleView,
                filled: true,
                palette: palette,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _WorldFilter(
                label: 'الكل'.tr,
                count: counts[null] ?? 0,
                selected: type == null,
                palette: palette,
                onTap: () => onType(null),
              ),
              for (final s in HomeSection.values) ...[
                const SizedBox(width: 8),
                _WorldFilter(
                  label: s.label,
                  icon: s.icon,
                  count: counts[s.typeFilter] ?? 0,
                  selected: type == s.typeFilter,
                  palette: s.palette,
                  onTap: () =>
                      onType(type == s.typeFilter ? null : s.typeFilter),
                ),
              ],
            ],
          ),
        ),
        if (provinces.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _ProvinceChip(
                  label: 'كل المحافظات'.tr,
                  selected: province == null,
                  palette: palette,
                  onTap: () => onProvince(null),
                ),
                for (final p in provinces) ...[
                  const SizedBox(width: 6),
                  _ProvinceChip(
                    label: p.tr,
                    selected: province == p,
                    palette: palette,
                    onTap: () => onProvince(province == p ? null : p),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.palette,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final WorldPalette? palette;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = palette ?? context.world;
    final child = PressScale(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled ? p.fill : null,
          color: filled ? null : Vibes.surface,
          border: filled
              ? null
              : Border.all(color: p.accent.withValues(alpha: .16)),
          boxShadow: [
            BoxShadow(
              color: filled
                  ? p.glow.withValues(alpha: .35)
                  : Colors.black.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: filled ? p.onAccent : Vibes.ink),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _WorldFilter extends StatelessWidget {
  const _WorldFilter({
    required this.label,
    required this.count,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.icon,
  });

  final String label;
  final int count;
  final bool selected;
  final WorldPalette palette;
  final VoidCallback onTap;
  final VibesCategory? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? palette.onAccent : Vibes.ink;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 8, 0),
        decoration: BoxDecoration(
          gradient: selected ? palette.fill : null,
          color: selected ? null : Vibes.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : palette.accent.withValues(alpha: .18),
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? palette.glow.withValues(alpha: .35)
                  : Colors.black.withValues(alpha: .07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              VibesCategoryIcon(
                category: icon!,
                size: 15,
                color: selected ? fg : palette.accentDeep,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? themed(
                        Colors.white.withValues(alpha: .25),
                        palette.onAccent.withValues(alpha: .14),
                      )
                    : palette.accentFaint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? fg : palette.accentDeep,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvinceChip extends StatelessWidget {
  const _ProvinceChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final WorldPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? palette.accentDeep
              : Vibes.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : palette.accent.withValues(alpha: .14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.place_outlined,
              size: 13,
              color: selected
                  ? themed(Colors.white, palette.onAccent)
                  : palette.accentDeep,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? themed(Colors.white, palette.onAccent)
                    : Vibes.ink,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// لوحة التحكم
// ═══════════════════════════════════════════════════════════

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.palette,
    required this.layer,
    required this.onLayer,
    required this.onLocate,
    required this.onFitAll,
  });

  final WorldPalette palette;
  final MapLayer layer;
  final VoidCallback onLayer;
  final VoidCallback onLocate;
  final VoidCallback onFitAll;

  @override
  Widget build(BuildContext context) {
    final layerLabel = switch (layer) {
      MapLayer.standard => 'عادية'.tr,
      // ليلاً تكون طبقة الاستكشاف خريطة طرق داكنة لا تضاريس.
      MapLayer.explore => Appearance.isDark ? 'طرق'.tr : 'تضاريس'.tr,
      MapLayer.satellite => 'قمر صناعي'.tr,
    };
    final layerIcon = switch (layer) {
      MapLayer.standard => Icons.layers_outlined,
      MapLayer.explore =>
        Appearance.isDark ? Icons.alt_route_rounded : Icons.terrain_rounded,
      MapLayer.satellite => Icons.satellite_alt_rounded,
    };
    Widget btn(IconData icon, VoidCallback onTap, {String? label}) =>
        PressScale(
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: label == null ? 48 : 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: palette.accentDeep),
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 3, right: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Vibes.inkSecondary,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
    Widget divider() => Container(
      width: 26,
      height: 1,
      color: palette.accent.withValues(alpha: .14),
    );

    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(layerIcon, onLayer, label: layerLabel),
          divider(),
          btn(Icons.my_location_rounded, onLocate),
          divider(),
          btn(Icons.zoom_out_map_rounded, onFitAll),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بطاقة المكان — أفقية بصورة وسعر، تفتح صفحة المكان
// ═══════════════════════════════════════════════════════════

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.property, required this.selected});

  final Property property;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = WorldPalette.forType(property.type.name);
    final cover = property.coverUrl;
    final where = [
      (property.cityName ?? property.provinceName ?? '').tr,
      if (property.capacity > 0) 'حتى {n} ضيف'.trN(property.capacity),
    ].where((s) => s.isNotEmpty).join(' · ');
    final unit = property.type == PropertyType.decoration
        ? 'د.ع للخدمة'.tr
        : property.supportsShifts
        ? 'د.ع للفترة'.tr
        : 'د.ع لليوم'.tr;
    // الإنجليزية أعرض: السعر فوق الوحدة، وزر الاتجاهات أيقونة فقط.
    final priceText = Text(
      formatIqdShort(_fromPrice(property)),
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Vibes.ink,
      ),
    );
    final unitStyle = TextStyle(
      fontFamily: VibesFont.ui,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      color: p.accentDeep,
    );

    return PressScale(
      onTap: () => context.push('/property/${property.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Vibes.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? p.accent
                : themed(p.accent.withValues(alpha: .10), Vibes.hairline),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? p.glow.withValues(alpha: .30)
                  : Colors.black.withValues(alpha: .12),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 116,
                height: double.infinity,
                child: cover != null
                    ? VibesNetImage(
                        url: cover,
                        fit: BoxFit.cover,
                        memCacheWidth: 360,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(gradient: p.nightfall),
                        child: Center(
                          child: VibesCategoryIcon(
                            category: p.world.icon,
                            size: 30,
                            color: p.accentLight,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          property.typeLabelAr,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: p.accentDeep,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (property.ratingCount > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFF5B301),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          property.ratingAvg.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Vibes.ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Vibes.ink,
                      height: 1.3,
                    ),
                  ),
                  if (where.isNotEmpty)
                    Text(
                      where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Vibes.inkSecondary,
                      ),
                    ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: I18n.isEn
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment:
                                        AlignmentDirectional.centerStart,
                                    child: priceText,
                                  ),
                                  Text(
                                    unit,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: unitStyle,
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  priceText,
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      unit,
                                      maxLines: 1,
                                      style: unitStyle,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (property.latitude != null &&
                          property.longitude != null)
                        PressScale(
                          onTap: () => showDirectionsSheet(
                            context,
                            lat: property.latitude!,
                            lng: property.longitude!,
                            name: property.name,
                          ),
                          child: Container(
                            height: 32,
                            padding: EdgeInsets.symmetric(
                              horizontal: I18n.isEn ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: p.fill,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_rounded,
                                  size: 16,
                                  color: p.onAccent,
                                  semanticLabel: 'اتجاهات'.tr,
                                ),
                                if (!I18n.isEn) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'اتجاهات'.tr,
                                    style: TextStyle(
                                      fontFamily: VibesFont.ui,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: p.onAccent,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
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
