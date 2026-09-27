import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../compare/compare_feature.dart';

/// ═══════════════════════════════════════════════════════════
/// البحث — فلاتر حقيقية (نوع/سعة/سعر/فرز) بورقة سفلية أنيقة
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
  });

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
      sort == null;

  int get count => [
    type != null,
    cityId != null,
    province != null,
    capacity > 0,
    minPrice > 0,
    maxPrice > 0,
    sort != null,
  ].where((b) => b).length;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialType, this.initialProvince});

  final String? initialType;
  final String? initialProvince;

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

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _filters = SearchFilters(
      type: widget.initialType,
      province: widget.initialProvince,
    );
    if (widget.initialType != null) {
      _filters.type = widget.initialType;
    }
    _search();
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
          _filters.province == null) {
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
          pageSize: 40,
        );
      }

      // فلاتر محلية دقيقة (سعة/سعر) — القائمة العامة تدعم الأساسيات
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
        return true;
      }).toList();

      // فرز إضافي محلي
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = maisonError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.text.isNotEmpty || !_filters.isEmpty;

    return Scaffold(
      bottomNavigationBar: const CompareBar(),
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'بحث',
              kicker: 'مكان أو محافظة',
              onBack: () => context.pop(),
              trailing: _results == null
                  ? null
                  : Text(
                      '${_results!.length} نتيجة',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Vibes.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: FolioPanel(
                radius: Folio.chrome,
                borderColor: VibesTheme.hairlineOf(context),
                railColor: Vibes.teal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Vibes.teal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          onChanged: _onQueryChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: VibesTheme.textPrimaryOf(context),
                              ),
                          decoration: const InputDecoration(
                            hintText: 'اسم المكان',
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _provinceMenu()),
                      const SizedBox(width: 8),
                      Expanded(child: _typeMenu()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _sortMenu()),
                      const SizedBox(width: 8),
                      Expanded(child: _capacityMenu()),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults(context, hasQuery)),
          ],
        ),
      ),
    );
  }

  Widget _provinceMenu() {
    final cities = ref.watch(locationsProvider).valueOrNull ?? const [];
    final provinces = <String, String>{};
    for (final city in cities) {
      final slug = city.provinceSlug;
      if (slug != null && slug.isNotEmpty && city.provinceName.isNotEmpty) {
        provinces[slug] = city.provinceName;
      }
    }
    final entries = provinces.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final selected = entries
        .where((e) => e.key == _filters.province)
        .map((e) => e.value)
        .firstOrNull;
    return _MenuField(
      label: 'المحافظة',
      value: selected ?? 'كل المحافظات',
      options: [
        (null, 'كل المحافظات'),
        for (final entry in entries) (entry.key, entry.value),
      ],
      onSelected: (value) {
        setState(() {
          _filters.province = value;
          _filters.cityId = null;
        });
        _search();
      },
    );
  }

  Widget _typeMenu() {
    const options = [
      (null, 'كل الأنواع'),
      ('FARM', 'مزارع'),
      ('HALL', 'قاعات'),
      ('DECORATION', 'تزيين'),
    ];
    final label = options
        .where((o) => o.$1 == _filters.type)
        .map((o) => o.$2)
        .firstOrNull;
    return _MenuField(
      label: 'النوع',
      value: label ?? 'كل الأنواع',
      options: options,
      onSelected: (value) {
        setState(() => _filters.type = value);
        _search();
      },
    );
  }

  Widget _sortMenu() {
    const options = [
      (null, 'الأحدث'),
      ('price_asc', 'الأقل سعراً'),
      ('price_desc', 'الأعلى سعراً'),
      ('rating', 'الأعلى تقييماً'),
    ];
    final label = options
        .where((o) => o.$1 == _filters.sort)
        .map((o) => o.$2)
        .firstOrNull;
    return _MenuField(
      label: 'الترتيب',
      value: label ?? 'الأحدث',
      options: options,
      onSelected: (value) {
        setState(() => _filters.sort = value);
        _search();
      },
    );
  }

  Widget _capacityMenu() {
    const options = [
      (0, 'أي سعة'),
      (50, '٥٠ ضيفاً فأكثر'),
      (100, '١٠٠ ضيف فأكثر'),
      (200, '٢٠٠ ضيف فأكثر'),
      (400, '٤٠٠ ضيف فأكثر'),
    ];
    final label = options
        .where((o) => o.$1 == _filters.capacity)
        .map((o) => o.$2)
        .firstOrNull;
    return _MenuField(
      label: 'السعة',
      value: label ?? 'أي سعة',
      options: options.map((o) => ('${o.$1}', o.$2)).toList(),
      onSelected: (value) {
        setState(() => _filters.capacity = int.tryParse(value ?? '') ?? 0);
        _search();
      },
    );
  }

  Widget _buildResults(BuildContext context, bool hasQuery) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ShimmerBox(height: 240, radius: VibesRadius.lg),
          ),
        ),
      );
    }

    if (_error != null) {
      return ErrorCanvas(message: _error!, onRetry: _search);
    }

    final results = _results;

    if (results == null) return const SizedBox.shrink();

    if (results.isEmpty) {
      return EmptyCanvas(
        icon: Icons.search_off_rounded,
        title: hasQuery ? 'لا نتائج مطابقة' : 'ابدأ البحث',
        subtitle: hasQuery
            ? 'جرّب محافظة أخرى أو نوعاً مختلفاً'
            : 'اختر محافظة أو اكتب اسم المكان',
      );
    }

    return RefreshIndicator(
      color: Vibes.teal,
      onRefresh: _search,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: results.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child:
              PropertyCard(
                    property: results[i],
                    heroNamespace: 'search',
                    showCompare: true,
                    isFavorite:
                        ref
                            .watch(favoritesProvider)
                            .valueOrNull
                            ?.any((p) => p.id == results[i].id) ??
                        false,
                    onFavorite: (_) =>
                        ref.read(favoritesProvider.notifier).toggle(results[i]),
                    onSelectCompare: (p) =>
                        ref.read(compareSelectionProvider.notifier).toggle(p),
                  )
                  .animate(delay: Duration(milliseconds: i * 40))
                  .fadeIn(duration: VibesMotion.slow)
                  .slideY(
                    begin: .03,
                    end: 0,
                    duration: VibesMotion.slow,
                    curve: VibesMotion.curve,
                  ),
        ),
      ),
    );
  }
}

class _MenuField extends StatelessWidget {
  const _MenuField({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<(String?, String)> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: VibesTheme.textTertiaryOf(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        FolioPanel(
          radius: Folio.chrome,
          borderColor: VibesTheme.hairlineOf(context),
          child: InkWell(
            onTap: () => _open(context),
            customBorder: Folio.chromeShape,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Vibes.teal,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        origin & box.size,
        Offset.zero & overlay.size,
      ),
      color: VibesTheme.surfaceOf(context),
      items: [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 42,
            child: Text(
              options[i].$2,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
    if (picked == null) return;
    onSelected(options[picked].$1);
  }
}

