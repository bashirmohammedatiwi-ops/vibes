import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/world_ui.dart';
import '../../core/utils/saved_searches.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/card_dimensions.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../compare/compare_feature.dart';
import '../home/home_sections.dart';
import '../property/place_experience_ui.dart';

/// تعبئة «المحدد»: حبر عميق نهاراً ونحاس ليلاً، وما يُقرأ فوقها.
Color get _selectedFill => themed(const Color(0xFF141C2B), Brand.brassLight);
Color get _onSelectedFill => themed(Colors.white, Brand.midnight);

/// ما يُقرأ فوق لون العالم الممتلئ (الألوان فاتحة ليلاً).
Color get _onAccentFill => themed(Colors.white, Brand.midnight);

Color get _shadowInk => themed(const Color(0xFF141C2B), Colors.black);

/// ═══════════════════════════════════════════════════════════
/// البحث — لغة التصميم الجديدة: أبيض نظيف، حبر عميق، نحاس.
/// فلاتر مباشرة بلا لوحات متداخلة، ونتائج بأسعار كاملة.
/// ═══════════════════════════════════════════════════════════

class SearchFilters {
  SearchFilters({
    this.type,
    this.cityId,
    this.province,
    this.capacity = 0,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.sort,
    this.winter = false,
    this.indoorPool = false,
  });

  /// مزارع شتوية فقط.
  bool winter;

  /// مسبح مغلق فقط.
  bool indoorPool;

  String? type;
  String? cityId;
  String? province;
  int capacity;
  num minPrice;
  num maxPrice;
  String? sort;

  bool get isEmpty =>
      type == null &&
      cityId == null &&
      province == null &&
      capacity == 0 &&
      minPrice == 0 &&
      maxPrice == 0 &&
      sort == null &&
      !winter &&
      !indoorPool;

  int get count => [
    type != null,
    cityId != null,
    province != null,
    capacity > 0,
    minPrice > 0,
    maxPrice > 0,
    sort != null,
    winter,
    indoorPool,
  ].where((b) => b).length;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialType,
    this.initialProvince,
    this.initialWinter = false,
    this.initialIndoorPool = false,
  });

  final String? initialType;
  final String? initialProvince;
  final bool initialWinter;
  final bool initialIndoorPool;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _query;
  late SearchFilters _filters;
  Timer? _debounce;

  List<Property>? _results;
  bool _loading = false;
  String? _error;
  List<SavedSearch> _saved = [];

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _filters = SearchFilters(
      type: (widget.initialWinter || widget.initialIndoorPool)
          ? 'FARM'
          : widget.initialType,
      province: widget.initialProvince,
      winter: widget.initialWinter,
      indoorPool: widget.initialIndoorPool,
    );
    _loadSaved();
    _search();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedSearchStore.load();
    if (mounted) setState(() => _saved = saved);
  }

  void _applySaved(SavedSearch saved) {
    setState(() {
      _query.text = saved.query;
      _filters = SearchFilters(
        type: saved.type,
        cityId: saved.cityId,
        province: saved.province,
        capacity: saved.capacity,
        minPrice: saved.minPrice,
        maxPrice: saved.maxPrice,
        sort: saved.sort,
      );
    });
    _search();
  }

  Future<void> _removeSaved(SavedSearch saved) async {
    final next = await SavedSearchStore.remove(saved.signature);
    if (mounted) setState(() => _saved = next);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final q = _query.text.trim();
      var results = <Property>[];

      if (q.isNotEmpty &&
          _filters.cityId == null &&
          _filters.province == null &&
          !_filters.winter &&
          !_filters.indoorPool) {
        try {
          final data = await client.get(
            '/api/search',
            queryParameters: {
              'q': q,
              if (_filters.type != null) 'type': _filters.type,
            },
          );
          final list = data is List ? data : const [];
          results = list
              .whereType<Map<String, dynamic>>()
              .map(Property.fromJson)
              .toList();
        } catch (_) {
          results = const [];
        }
      }

      if (results.isEmpty) {
        results = await fetchProperties(
          client,
          q: q.isNotEmpty ? q : null,
          type: _filters.type,
          cityId: _filters.cityId,
          province: _filters.province,
          sort: _filters.sort,
          winter: _filters.winter ? true : null,
          indoorPool: _filters.indoorPool ? true : null,
          pageSize: 100,
        );
      }

      final filtered = results.where((p) {
        if (_filters.capacity > 0 && p.capacity < _filters.capacity) {
          return false;
        }
        if (_filters.minPrice > 0 && p.pricePerDay < _filters.minPrice) {
          return false;
        }
        if (_filters.maxPrice > 0 && p.pricePerDay > _filters.maxPrice) {
          return false;
        }
        if (_filters.winter && !p.isWinter) return false;
        if (_filters.indoorPool && !p.hasIndoorPool) return false;
        return true;
      }).toList();

      switch (_filters.sort) {
        case 'price_asc':
          filtered.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
          break;
        case 'price_desc':
          filtered.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
          break;
        case 'rating':
          filtered.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
          break;
      }

      if (!mounted) return;
      setState(() {
        _results = filtered;
        _loading = false;
      });

      final snapshot = SavedSearch(
        query: q,
        type: _filters.type,
        province: _filters.province,
        cityId: _filters.cityId,
        capacity: _filters.capacity,
        minPrice: _filters.minPrice,
        maxPrice: _filters.maxPrice,
        sort: _filters.sort,
      );
      if (!snapshot.isEmpty && filtered.isNotEmpty) {
        final next = await SavedSearchStore.save(snapshot);
        if (mounted) setState(() => _saved = next);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = maisonError(e);
        _loading = false;
      });
    }
  }

  HomeSection? get _activeSection => switch (_filters.type) {
    'FARM' => HomeSection.farm,
    'HALL' => HomeSection.hall,
    'DECORATION' => HomeSection.decoration,
    _ => null,
  };

  Color get _accent => _palette.accent;

  /// لوحة العالم المختار في البحث — أو عالم التطبيق الحالي.
  WorldPalette get _palette => _activeSection?.palette ?? context.world;

  void _setType(String? type) {
    HapticFeedback.selectionClick();
    setState(() {
      _filters.type = type;
      // فلاتر المزارع فقط — تُلغى عند اختيار نوع آخر
      if (type != null && type != 'FARM') {
        _filters.winter = false;
        _filters.indoorPool = false;
      }
    });
    _search();
  }

  /// مزارع شتوية / مسبح مغلق — اختيار أي منهما يحصر البحث بالمزارع.
  void _toggleFarmFeature({bool? winter, bool? indoorPool}) {
    HapticFeedback.selectionClick();
    setState(() {
      if (winter != null) _filters.winter = winter;
      if (indoorPool != null) _filters.indoorPool = indoorPool;
      if (_filters.winter || _filters.indoorPool) _filters.type = 'FARM';
    });
    _search();
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _filters = SearchFilters();
      _query.clear();
    });
    _search();
  }

  Future<void> _openFilterSheet() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Vibes.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Theme(
        data: applyWorld(Theme.of(context), _palette),
        child: _FilterSheet(
          filters: _filters,
          onApply: (next) {
            setState(() => _filters = next);
            _search();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.text.isNotEmpty || !_filters.isEmpty;

    final palette = _palette;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 420),
      data: applyWorld(Theme.of(context), palette),
      child: Scaffold(
        backgroundColor: palette.canvas,
        bottomNavigationBar: const CompareBar(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── الرأس + البحث ──
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // صف الرجوع + العنوان
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: themed(
                                const Color(0xFFF2F3F5),
                                VibesDark.surfaceMuted,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: placeInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'استكشف الأماكن'.tr,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: placeInk,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: 250.ms,
                          child: _loading
                              ? SizedBox(
                                  key: const ValueKey('loading'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _accent,
                                  ),
                                )
                              : (_results?.length ?? 0) > 0
                              ? Container(
                                  key: const ValueKey('count'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${_results!.length}',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _accent,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('none')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // حقل البحث — البطل
                    _SearchBar(
                      controller: _query,
                      accent: _accent,
                      filterCount: _filters.count,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _search(),
                      onFilterTap: _openFilterSheet,
                      onClear: () {
                        _query.clear();
                        _onQueryChanged('');
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── فلاتر النوع ──
            _TypeFilterRow(selected: _filters.type, onSelected: _setType),
            if (_filters.type == null || _filters.type == 'FARM')
              _FarmFeatureRow(
                winter: _filters.winter,
                indoorPool: _filters.indoorPool,
                onWinter: (v) => _toggleFarmFeature(winter: v),
                onIndoorPool: (v) => _toggleFarmFeature(indoorPool: v),
              ),

            // ── الفلاتر النشطة ──
            if (_filters.count > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _ActiveFiltersRow(
                  filters: _filters,
                  onClear: _clearFilters,
                  onEdit: _openFilterSheet,
                ),
              ),

            Expanded(child: _buildResults(context, hasQuery)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, bool hasQuery) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const ShimmerBox(width: 140, height: 18, radius: 6),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: ShimmerBox(height: 220, radius: 16),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ErrorCanvas(message: _error!, onRetry: _search);
    }

    final results = _results;

    if (results == null || (results.isEmpty && !hasQuery)) {
      return _SearchDiscover(
        saved: _saved,
        onPick: (type, province) {
          setState(() {
            _filters.type = type;
            _filters.province = province;
            _filters.cityId = null;
          });
          _search();
        },
        onApplySaved: _applySaved,
        onRemoveSaved: _removeSaved,
      );
    }

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          WorldEmpty(
            icon: Icons.search_off_rounded,
            title: 'لا نتائج مطابقة'.tr,
            subtitle: 'جرّب محافظة أخرى أو وسّع الميزانية أو عدّل الفلاتر'.tr,
            actionLabel: 'تعديل الفلاتر'.tr,
            onAction: _openFilterSheet,
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _search,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        cacheExtent: 800,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        itemCount: results.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 14, start: 4),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'النتائج'.tr,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: placeInk,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _filters.isEmpty ? 'الكل'.tr : 'مطابقة لفلاترك'.tr,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                    ),
                  ),
                ],
              ),
            );
          }
          final item = results[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: CardDims.gap),
            child: PropertyCard(
              property: item,
              heroNamespace: 'search',
              showCompare: true,
              isFavorite:
                  ref
                      .watch(favoritesProvider)
                      .valueOrNull
                      ?.any((p) => p.id == item.id) ??
                  false,
              onFavorite: (_) =>
                  ref.read(favoritesProvider.notifier).toggle(item),
              onSelectCompare: (p) =>
                  ref.read(compareSelectionProvider.notifier).toggle(p),
            ),
          );
        },
      ),
    );
  }
}

/// ── حقل البحث — بطاقة بيضاء بارزة بنفس لغة صفحة المكان ──
class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.accent,
    required this.filterCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilterTap,
    required this.onClear,
  });

  final TextEditingController controller;
  final Color accent;
  final int filterCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTap;
  final VoidCallback onClear;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _focus = FocusNode();
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
    widget.controller.addListener(() {
      if (mounted) {
        setState(() => _hasText = widget.controller.text.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? widget.accent : placeLine,
          width: _focused ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _shadowInk.withValues(alpha: _focused ? 0.08 : 0.05),
            blurRadius: _focused ? 20 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // زر البحث الدائري
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _focused ? widget.accent : placePaper,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 19,
              color: _focused ? _onAccentFill : placeInk2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: placeInk,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو المدينة…'.tr,
                hintStyle: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: placeInk2.withValues(alpha: 0.55),
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          // مسح النص
          if (_hasText)
            GestureDetector(
              onTap: widget.onClear,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: placePaper,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: placeInk2,
                ),
              ),
            ),
          const SizedBox(width: 6),
          // زر الفلاتر بشارة العدد
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.filterCount > 0 ? widget.accent : placePaper,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: widget.filterCount > 0 ? _onAccentFill : placeInk2,
                  ),
                  if (widget.filterCount > 1)
                    PositionedDirectional(
                      top: 7,
                      start: 7,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: Vibes.surface,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 6,
                          backgroundColor: widget.accent,
                          child: Text(
                            '${widget.filterCount}',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: _onAccentFill,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
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

/// ── فلاتر النوع — بطاقات بيضاء بحدود عالمها ──
class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _TypeChip(
            label: 'الكل'.tr,
            accent: placeInk,
            icon: null,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...HomeSection.values.map(
            (section) => Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: _TypeChip(
                label: section.label,
                accent: accentForType(section.typeFilter),
                icon: section.icon,
                selected: selected == section.typeFilter,
                onTap: () => onSelected(section.typeFilter),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// صف خصائص المزارع: مزارع شتوية ومسبح مغلق (مفاتيح تشغيل/إيقاف).
class _FarmFeatureRow extends StatelessWidget {
  const _FarmFeatureRow({
    required this.winter,
    required this.indoorPool,
    required this.onWinter,
    required this.onIndoorPool,
  });

  final bool winter;
  final bool indoorPool;
  final ValueChanged<bool> onWinter;
  final ValueChanged<bool> onIndoorPool;

  @override
  Widget build(BuildContext context) {
    Widget chip(
      String emoji,
      String label,
      bool on,
      ValueChanged<bool> tap,
      Color color,
    ) {
      return GestureDetector(
        onTap: () => tap(!on),
        child: AnimatedContainer(
          duration: VibesMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: .12) : Vibes.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on ? color : placeLine,
              width: on ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: on ? color : placeInk,
                ),
              ),
              if (on) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded, size: 15, color: color),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(
              '❄️',
              'مزارع شتوية'.tr,
              winter,
              onWinter,
              themed(const Color(0xFF0284C7), const Color(0xFF7DD3FC)),
            ),
            const SizedBox(width: 8),
            chip(
              '🏊',
              'مسبح مغلق'.tr,
              indoorPool,
              onIndoorPool,
              themed(const Color(0xFF0D9488), const Color(0xFF5EEAD4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final VibesCategory? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VibesMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? accent : Vibes.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? accent : placeLine,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              VibesCategoryIcon(
                category: icon!,
                size: 15,
                color: selected ? _onAccentFill : accent,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? _onAccentFill : placeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── شارات الفلاتر النشطة ──
class _ActiveFiltersRow extends StatelessWidget {
  const _ActiveFiltersRow({
    required this.filters,
    required this.onClear,
    required this.onEdit,
  });

  final SearchFilters filters;
  final VoidCallback onClear;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filters.winter) {
      chips.add(_FilterPill(label: '❄️ مزارع شتوية'.tr, onTap: onEdit));
    }
    if (filters.indoorPool) {
      chips.add(_FilterPill(label: '🏊 مسبح مغلق'.tr, onTap: onEdit));
    }
    if (filters.province != null) {
      chips.add(_FilterPill(label: filters.province!.tr, onTap: onEdit));
    }
    if (filters.sort != null) {
      final sortLabel = switch (filters.sort) {
        'price_asc' => 'الأقل سعراً'.tr,
        'price_desc' => 'الأعلى سعراً'.tr,
        'rating' => 'الأعلى تقييماً'.tr,
        _ => 'الأحدث'.tr,
      };
      chips.add(_FilterPill(label: sortLabel, onTap: onEdit));
    }
    if (filters.capacity > 0) {
      chips.add(
        _FilterPill(
          label: '{n}+ ضيف'.trArgs({'n': filters.capacity}),
          onTap: onEdit,
        ),
      );
    }
    if (filters.maxPrice > 0) {
      chips.add(
        _FilterPill(
          label: 'حتى {price} د.ع'.trArgs({
            'price': placeFullPrice(filters.maxPrice),
          }),
          onTap: onEdit,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => chips[i],
            ),
          ),
        ),
        TextButton(
          onPressed: onClear,
          child: Text(
            'مسح'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: placeBrass,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: placeBrass.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: placeBrass.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12, color: placeBrass),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: placeBrass,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── لوحة الاكتشاف قبل البحث ──
class _SearchDiscover extends ConsumerWidget {
  const _SearchDiscover({
    required this.saved,
    required this.onPick,
    required this.onApplySaved,
    required this.onRemoveSaved,
  });

  final List<SavedSearch> saved;
  final void Function(String? type, String? province) onPick;
  final ValueChanged<SavedSearch> onApplySaved;
  final ValueChanged<SavedSearch> onRemoveSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // ترويسة تحريرية
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: placeBrass,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ابدأ الاكتشاف'.tr,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: placeInk,
              ),
            ),
          ],
        ).animate().fadeIn(),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 11),
          child: Text(
            'اختر نوع المكان أو محافظة — أو ابحث بالاسم'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: placeInk2,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // بطاقات الأنواع الثلاثة — كبيرة وجميلة
        Row(
          children: [
            for (final section in HomeSection.values) ...[
              Expanded(
                child: _DiscoverTypeCard(
                  section: section,
                  onTap: () => onPick(section.typeFilter, null),
                ),
              ),
              if (section != HomeSection.decoration) const SizedBox(width: 10),
            ],
          ],
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, end: 0),

        // المحافظات
        _ProvinceGrid(onPick: onPick),

        // بحوث سابقة
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: placeInk,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'بحوثك السابقة'.tr,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: placeInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...saved.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SavedSearchRow(
                saved: s,
                onApply: () => onApplySaved(s),
                onRemove: () => onRemoveSaved(s),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// بطاقة نوع — أيقونة كبيرة + اسم + لون عالمها.
class _DiscoverTypeCard extends StatelessWidget {
  const _DiscoverTypeCard({required this.section, required this.onTap});

  final HomeSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentForType(section.typeFilter);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Vibes.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: placeLine),
          boxShadow: [
            BoxShadow(
              color: _shadowInk.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: VibesCategoryIcon(
                category: section.icon,
                size: 22,
                color: accent,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                section.label,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شبكة المحافظات — رقائق بيضاء أنيقة.
class _ProvinceGrid extends ConsumerWidget {
  const _ProvinceGrid({required this.onPick});

  final void Function(String? type, String? province) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider).valueOrNull ?? const [];
    final provinces = <String, String>{};
    final open = <String>{};
    for (final city in locations) {
      final slug = city.provinceSlug;
      if (slug != null && slug.isNotEmpty && city.provinceName.isNotEmpty) {
        provinces[slug] = city.provinceName;
        if (city.provinceOpenFor(null)) open.add(slug);
      }
    }
    final entries = provinces.entries.toList()
      ..sort((a, b) => a.value.tr.compareTo(b.value.tr));

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'تصفح بالمحافظة'.tr,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: placeInk,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final province in entries)
              GestureDetector(
                onTap: open.contains(province.key)
                    ? () => onPick(null, province.key)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Vibes.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: placeLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: placeBrass.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        province.value.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: open.contains(province.key)
                              ? placeInk
                              : placeInk2,
                        ),
                      ),
                      if (!open.contains(province.key)) ...[
                        const SizedBox(width: 6),
                        const ComingSoonPill(),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ).animate().fadeIn(delay: 180.ms),
      ],
    );
  }
}

class _SavedSearchRow extends StatelessWidget {
  const _SavedSearchRow({
    required this.saved,
    required this.onApply,
    required this.onRemove,
  });

  final SavedSearch saved;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onApply,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 14, 10),
        decoration: BoxDecoration(
          color: Vibes.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: placeLine),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: placePaper,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 17,
                color: placeInk2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                saved.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: placeInk,
                  height: 1.3,
                ),
              ),
            ),
            IconButton(
              tooltip: 'حذف'.tr,
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, size: 17, color: placeInk2),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── ورقة الفلاتر — خيارات مباشرة بلا لوحات متداخلة ──
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.filters, required this.onApply});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onApply;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _province;
  late String? _sort;
  late int _capacity;
  late num _maxPrice;

  @override
  void initState() {
    super.initState();
    _province = widget.filters.province;
    _sort = widget.filters.sort;
    _capacity = widget.filters.capacity;
    _maxPrice = widget.filters.maxPrice;
  }

  void _apply() {
    final next = SearchFilters(
      type: widget.filters.type,
      cityId: _province != widget.filters.province
          ? null
          : widget.filters.cityId,
      province: _province,
      capacity: _capacity,
      minPrice: widget.filters.minPrice,
      maxPrice: _maxPrice,
      sort: _sort,
      winter: widget.filters.winter,
      indoorPool: widget.filters.indoorPool,
    );
    widget.onApply(next);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(locationsProvider).valueOrNull ?? const [];
    final provinces = <String, String>{};
    final openProvinces = <String>{};
    for (final city in cities) {
      final slug = city.provinceSlug;
      if (slug != null && slug.isNotEmpty && city.provinceName.isNotEmpty) {
        provinces[slug] = city.provinceName;
        if (city.provinceOpenFor(null)) openProvinces.add(slug);
      }
    }
    final entries = provinces.entries.toList()
      ..sort((a, b) => a.value.tr.compareTo(b.value.tr));

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مقبض + عنوان
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: placeLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              'الفلاتر'.tr,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: placeInk,
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── المحافظة — شبكة بطاقات ──
                  _FilterSection(
                    icon: Icons.location_on_outlined,
                    title: 'المحافظة'.tr,
                    trailing: _ClearSectionButton(
                      visible: _province != null,
                      onTap: () => setState(() => _province = null),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in entries)
                          _ProvinceTile(
                            name: e.value.tr,
                            selected: _province == e.key,
                            available: openProvinces.contains(e.key),
                            onTap: () => setState(
                              () =>
                                  _province = _province == e.key ? null : e.key,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── الميزانية — سلايدر حقيقي ──
                  _FilterSection(
                    icon: Icons.payments_outlined,
                    title: 'الميزانية'.tr,
                    trailing: _ClearSectionButton(
                      visible: _maxPrice > 0,
                      onTap: () => setState(() => _maxPrice = 0),
                    ),
                    child: _BudgetSlider(
                      value: _maxPrice,
                      onChanged: (v) => setState(() => _maxPrice = v),
                    ),
                  ),

                  // ── السعة — بطاقات بأيقونات ──
                  _FilterSection(
                    icon: Icons.groups_outlined,
                    title: 'السعة'.tr,
                    trailing: _ClearSectionButton(
                      visible: _capacity > 0,
                      onTap: () => setState(() => _capacity = 0),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (v, label, icon) in const [
                          (50, '50+', Icons.group_rounded),
                          (100, '100+', Icons.groups_rounded),
                          (200, '200+', Icons.groups_2_rounded),
                          (400, '400+', Icons.diversity_3_rounded),
                        ])
                          _CapacityTile(
                            label: label,
                            icon: icon,
                            selected: _capacity == v,
                            onTap: () => setState(
                              () => _capacity = _capacity == v ? 0 : v,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── الترتيب ──
                  _FilterSection(
                    icon: Icons.sort_rounded,
                    title: 'الترتيب'.tr,
                    child: Column(
                      children: [
                        for (final (v, label, icon, desc) in [
                          (
                            null,
                            'الأحدث'.tr,
                            Icons.new_releases_outlined,
                            'أحدث الأماكن المضافة'.tr,
                          ),
                          (
                            'price_asc',
                            'الأقل سعراً'.tr,
                            Icons.trending_down_rounded,
                            'ابدأ من الأرخص'.tr,
                          ),
                          (
                            'price_desc',
                            'الأعلى سعراً'.tr,
                            Icons.trending_up_rounded,
                            'الفخم أولاً'.tr,
                          ),
                          (
                            'rating',
                            'الأعلى تقييماً'.tr,
                            Icons.star_outline_rounded,
                            'اختيارات الضيوف'.tr,
                          ),
                        ])
                          _SortTile(
                            label: label,
                            icon: icon,
                            description: desc,
                            selected: _sort == v,
                            onTap: () => setState(() => _sort = v),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // زر التطبيق
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedFill,
                  foregroundColor: _onSelectedFill,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _apply,
                child: Text(
                  'تطبيق الفلاتر'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// قسم فلتر — أيقونة + عنوان + زر مسح خاص.
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: placeBrass.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: placeBrass),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: placeInk,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _ClearSectionButton extends StatelessWidget {
  const _ClearSectionButton({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: visible
          ? GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: placePaper,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: placeLine),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 12, color: placeInk2),
                    SizedBox(width: 3),
                    Text(
                      'إلغاء'.tr,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: placeInk2,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// بطاقة محافظة — اسم + أيقونة، قابلة للإلغاء بالنقر مجدداً.
class _ProvinceTile extends StatelessWidget {
  const _ProvinceTile({
    required this.name,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!available) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Vibes.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Vibes.inkTertiary,
              ),
            ),
            const SizedBox(width: 6),
            const ComingSoonPill(),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _selectedFill : Vibes.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _selectedFill : placeLine),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _selectedFill.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.location_on_rounded : Icons.location_on_outlined,
              size: 14,
              color: selected
                  ? _brassSoftColor
                  : placeBrass.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? _onSelectedFill : placeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color get _brassSoftColor => themed(const Color(0xFFE4C88A), Brand.midnight);

/// بطاقة سعة — رقم كبير + أيقونة.
class _CapacityTile extends StatelessWidget {
  const _CapacityTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _selectedFill : Vibes.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _selectedFill : placeLine),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: selected ? _brassSoftColor : placeInk2),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? _onSelectedFill : placeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سلايدر الميزانية — نطاق 0 إلى 1.5 مليون بخطوات 50 ألف.
class _BudgetSlider extends StatelessWidget {
  const _BudgetSlider({required this.value, required this.onChanged});

  final num value;
  final ValueChanged<num> onChanged;

  static const double _max = 1500000;
  static const double _step = 50000;

  String _label(num v) {
    if (v <= 0) return 'بدون حد'.tr;
    if (v >= _max) return 'أي سعر'.tr;
    if (v >= 1000000) {
      final m = v / 1000000;
      return 'حتى {n} مليون'.trArgs({
        'n': m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1),
      });
    }
    return 'حتى {price} د.ع'.trArgs({'price': placeFullPrice(v)});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // القيمة الحالية — كبيرة وواضحة
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: placePaper,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: Text(
                _label(value),
                key: ValueKey(value),
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: placeInk,
                ),
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: placeBrass,
            inactiveTrackColor: placeLine,
            thumbColor: Vibes.surface,
            thumbShape: const _BrassThumbShape(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.toDouble().clamp(0, _max),
            min: 0,
            max: _max,
            divisions: (_max / _step).round(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        // علامات مرجعية
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final mark in ['0', '500 ألف'.tr, '1 مليون'.tr, 'الكل'.tr])
                Text(
                  mark,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: placeInk2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// إبهام نحاسي بحد أبيض — لمسة فاخرة للسلايدر.
class _BrassThumbShape extends SliderComponentShape {
  const _BrassThumbShape();

  @override
  Size getPreferredSize(bool enabled, bool isDiscrete) => const Size.square(22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // هالة ناعمة
    canvas.drawCircle(
      center,
      13,
      Paint()..color = placeBrass.withValues(alpha: 0.18),
    );
    // قرص أبيض بحد نحاسي
    canvas.drawCircle(center, 10, Paint()..color = Vibes.surface);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = placeBrass,
    );
    // نقطة نحاسية بالمنتصف
    canvas.drawCircle(center, 3.5, Paint()..color = placeBrass);
  }
}

/// بطاقة ترتيب — أيقونة + اسم + وصف + راديو.
class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.label,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _selectedFill : Vibes.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _selectedFill : placeLine),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? _onSelectedFill.withValues(alpha: 0.12)
                    : placePaper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? _brassSoftColor : placeInk2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: selected ? _onSelectedFill : placeInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? _onSelectedFill.withValues(alpha: 0.65)
                          : placeInk2,
                    ),
                  ),
                ],
              ),
            ),
            // راديو
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _brassSoftColor : placeLine,
                  width: selected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
