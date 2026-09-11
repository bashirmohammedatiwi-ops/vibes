import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/property_card.dart';
import '../compare/compare_feature.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// البحث — فلاتر حقيقية (نوع/سعة/سعر/فرز) بورقة سفلية أنيقة
/// ═══════════════════════════════════════════════════════════

class SearchFilters {
  SearchFilters({
    this.type,
    this.capacity = 0,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.sort,
  });

  String? type;
  int capacity;
  num minPrice;
  num maxPrice;
  String? sort;

  bool get isEmpty =>
      type == null &&
      capacity == 0 &&
      minPrice == 0 &&
      maxPrice == 0 &&
      sort == null;

  int get count =>
      [
        type != null,
        capacity > 0,
        minPrice > 0,
        maxPrice > 0,
        sort != null,
      ].where((b) => b).length;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialType});

  final String? initialType;

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
    _filters = SearchFilters(type: widget.initialType);
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
      final results = await fetchProperties(
        client,
        q: _query.text.trim().isNotEmpty ? _query.text.trim() : null,
        type: _filters.type,
        sort: _filters.sort,
        pageSize: 40,
      );

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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FiltersSheet(
        filters: _filters,
        onApply: (filters) {
          Navigator.pop(context);
          setState(() => _filters = filters);
          _search();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.text.isNotEmpty || !_filters.isEmpty;

    return Scaffold(
      bottomNavigationBar: const CompareBar(),
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: TextField(
            controller: _query,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو المدينة…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              fillColor: Colors.transparent,
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          Stack(
            alignment: AlignmentDirectional.topStart,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openFilters,
              ),
              if (_filters.count > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: GoldColors.gradient,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_filters.count}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: GoldColors.onGold,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildResults(context, hasQuery),
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
            ? 'جرّب تعديل الفلاتر أو كلمات بحث مختلفة'
            : 'اكتب في شريط البحث أو استخدم الفلاتر لإيجاد مكانك المثالي',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: results.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PropertyCard(
          property: results[i],
          showCompare: true,
          onSelectCompare: (p) => ref
              .read(compareSelectionProvider.notifier)
              .toggle(p),
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
    );
  }
}


/// ═════ ورقة الفلاتر ═════

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.filters, required this.onApply});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onApply;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final SearchFilters _filters;

  static const _types = [
    (null, 'الكل'),
    ('FARM', 'مزارع'),
    ('HALL', 'قاعات'),
    ('DECORATION', 'تزيين'),
  ];

  static const _sorts = [
    (null, 'الأحدث'),
    ('price_asc', 'الأقل سعراً'),
    ('price_desc', 'الأعلى سعراً'),
    ('rating', 'الأعلى تقييماً'),
  ];

  @override
  void initState() {
    super.initState();
    _filters = SearchFilters(
      type: widget.filters.type,
      capacity: widget.filters.capacity,
      minPrice: widget.filters.minPrice,
      maxPrice: widget.filters.maxPrice,
      sort: widget.filters.sort,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الفلاتر',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 22),

            _label('النوع'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final active = _filters.type == t.$1;
                return _FilterChipButton(
                  label: t.$2,
                  active: active,
                  onTap: () => setState(() => _filters.type = t.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _label('الترتيب'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sorts.map((s) {
                final active = _filters.sort == s.$1;
                return _FilterChipButton(
                  label: s.$2,
                  active: active,
                  onTap: () => setState(() => _filters.sort = s.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _label('الحد الأدنى للسعة'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 50, 100, 200, 400].map((c) {
                final active = _filters.capacity == c;
                return _FilterChipButton(
                  label: c == 0 ? 'أي سعة' : '$c+ ضيف',
                  active: active,
                  onTap: () => setState(() => _filters.capacity = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _label('نطاق السعر (لليوم)'),
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    hint: 'من',
                    value: _filters.minPrice > 0
                        ? _filters.minPrice.toString()
                        : '',
                    onChanged: (v) =>
                        setState(() => _filters.minPrice = num.tryParse(v) ?? 0),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.remove, size: 16),
                ),
                Expanded(
                  child: _PriceField(
                    hint: 'إلى',
                    value: _filters.maxPrice > 0
                        ? _filters.maxPrice.toString()
                        : '',
                    onChanged: (v) =>
                        setState(() => _filters.maxPrice = num.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: VibesButton(
                    label: 'مسح الفلاتر',
                    ghost: true,
                    onPressed: () {
                      setState(() {
                        _filters
                          ..type = null
                          ..capacity = 0
                          ..minPrice = 0
                          ..maxPrice = 0
                          ..sort = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: VibesButton(
                    label: 'عرض النتائج',
                    onPressed: () => widget.onApply(_filters),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VibesMotion.fast,
        curve: VibesMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? GoldColors.gradient : null,
          color: active ? null : VibesTheme.surfaceHighOf(context),
          borderRadius: BorderRadius.circular(VibesRadius.pill),
          border: active
              ? null
              : Border.all(color: VibesTheme.hairlineOf(context)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? GoldColors.onGold : VibesTheme.textSecondaryOf(context),
              ),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
