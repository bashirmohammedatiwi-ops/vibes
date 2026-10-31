import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/utils/vibes_net_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// مقارنة الأماكن — اختر 2 إلى 4 أماكن وقارن جنباً إلى جنب
/// ═══════════════════════════════════════════════════════════

final compareSelectionProvider =
    StateNotifierProvider<CompareSelectionController, List<Property>>(
      (ref) => CompareSelectionController(),
    );

class CompareSelectionController extends StateNotifier<List<Property>> {
  CompareSelectionController() : super(const []);

  static const int maxItems = 4;

  bool isSelected(String id) => state.any((p) => p.id == id);
  bool get isFull => state.length >= maxItems;

  void toggle(Property property) {
    if (isSelected(property.id)) {
      state = state.where((p) => p.id != property.id).toList();
    } else if (!isFull) {
      state = [...state, property];
    }
  }

  void clear() => state = const [];
}

/// شريط المقارنة السفلي — يظهر عند اختيار مكان واحد فأكثر
class CompareBar extends ConsumerWidget {
  const CompareBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(compareSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VibesTheme.canvasOf(context).withValues(alpha: .96),
        border: Border(top: BorderSide(color: Vibes.teal, width: 2)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // صور مصغرة للاختيار
              ...selection
                  .take(4)
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MaisonThumb(url: p.coverUrl, size: 42),
                          PositionedDirectional(
                            top: -6,
                            end: -6,
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(compareSelectionProvider.notifier)
                                  .toggle(p),
                              child: FolioPanel(
                                color: VibesTheme.surfaceOf(context),
                                borderColor: VibesTheme.hairlineOf(context),
                                radius: Folio.compact,
                                child: Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 10,
                                    color: Vibes.inkSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const Spacer(),
              Text(
                '${selection.length}/4',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: VibesTheme.textTertiaryOf(context),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: VibesButton(
                  label: 'قارن'.tr,
                  small: true,
                  expanded: false,
                  onPressed: () => context.push('/compare'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشة المقارنة: أعمدة متساوية تملأ الشاشة، والأفضل في كل صف مميّز.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  bool _onlyDifferences = false;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(compareSelectionProvider);
    // القوائم قد لا تحمل كل التفاصيل، فنكمل من صفحة المكان متى وصلت.
    final places = [
      for (final p in selection)
        ref.watch(propertyDetailProvider(p.id)).valueOrNull ?? p,
    ];

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'مقارنة الأماكن'.tr,
              onBack: () => context.pop(),
              trailing: selection.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () =>
                          ref.read(compareSelectionProvider.notifier).clear(),
                      child: Text('مسح'.tr),
                    ),
            ),
            Expanded(
              child: places.isEmpty
                  ? const _CompareEmpty()
                  : _CompareBody(
                      places: places,
                      onlyDifferences: _onlyDifferences,
                      onToggleDifferences: (v) =>
                          setState(() => _onlyDifferences = v),
                    ),
            ),
            if (places.isNotEmpty) _BookBar(places: places),
          ],
        ),
      ),
    );
  }
}

class _CompareEmpty extends StatelessWidget {
  const _CompareEmpty();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 74,
              height: 96,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: i == 1 ? Vibes.tealMint : Vibes.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: i == 1 ? Vibes.teal : Vibes.hairline),
              ),
              child: Icon(
                i == 1 ? Icons.emoji_events_rounded : Icons.home_work_outlined,
                color: i == 1 ? Vibes.teal : Vibes.inkTertiary,
              ),
            ),
        ],
      ),
      const SizedBox(height: 22),
      Text(
        'قارن قبل أن تحجز'.tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Vibes.ink,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'اختر من 2 إلى 4 أماكن لترى الأرخص والأعلى تقييماً والأوسع، وكل الفروق بينها.'
            .tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Vibes.inkSecondary,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 20),
      VibesButton(
        label: 'ابحث عن أماكن'.tr,
        onPressed: () => context.push('/search'),
      ),
    ],
  );
}

class _CompareBody extends StatelessWidget {
  const _CompareBody({
    required this.places,
    required this.onlyDifferences,
    required this.onToggleDifferences,
  });

  final List<Property> places;
  final bool onlyDifferences;
  final ValueChanged<bool> onToggleDifferences;

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups(places);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        _PlaceHeaders(places: places),
        if (places.length == 1) ...[
          const SizedBox(height: 14),
          _Hint(text: 'أضف مكاناً آخر على الأقل لتبدأ المقارنة'.tr),
        ] else ...[
          if (places.map((p) => p.type).toSet().length > 1) ...[
            const SizedBox(height: 10),
            _Hint(text: 'تقارن أنواعاً مختلفة من الأماكن'.tr),
          ],
          const SizedBox(height: 14),
          _Verdict(places: places),
          const SizedBox(height: 12),
          _DifferencesSwitch(
            value: onlyDifferences,
            onChanged: onToggleDifferences,
          ),
        ],
        for (final group in groups)
          if (_visibleRows(group).isNotEmpty) ...[
            const SizedBox(height: 18),
            _GroupTitle(icon: group.icon, title: group.title),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Vibes.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Vibes.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, row) in _visibleRows(group).indexed)
                    _AttributeRow(row: row, showDivider: i > 0),
                ],
              ),
            ),
          ],
      ],
    );
  }

  List<_Row> _visibleRows(_Group group) => onlyDifferences
      ? group.rows.where((r) => r.differs).toList()
      : group.rows;
}

List<_Group> _buildGroups(List<Property> places) {
  String money(num? v) => v == null || v <= 0
      ? '—'
      : '{amount} د.ع'.trArgs({'amount': PriceText.format(v)});
  String yesNo(bool v) => v ? '✓' : '—';

  final amenityNames = <String, String>{};
  for (final p in places) {
    for (final a in p.amenities) {
      amenityNames[a.id] = a.nameAr;
    }
  }
  final amenities = amenityNames.entries.toList()
    ..sort((a, b) {
      int owners(String id) =>
          places.where((p) => p.amenities.any((x) => x.id == id)).length;
      return owners(b.key).compareTo(owners(a.key));
    });

  final hasShifts = places.any(
    (p) => (p.priceMorningShift ?? 0) > 0 || (p.priceEveningShift ?? 0) > 0,
  );
  final hasWeekend = places.any((p) => (p.weekendPrice ?? 0) > 0);

  return [
    _Group(Icons.payments_outlined, 'الأسعار'.tr, [
      _Row.numeric(
        'اليوم الكامل'.tr,
        places.map((p) => p.pricePerDay).toList(),
        money,
        lowerIsBetter: true,
      ),
      if (hasWeekend)
        _Row.numeric(
          'نهاية الأسبوع'.tr,
          places.map((p) => p.weekendPrice ?? 0).toList(),
          money,
          lowerIsBetter: true,
        ),
      if (hasShifts) ...[
        _Row.numeric(
          'الشفت الصباحي'.tr,
          places.map((p) => p.priceMorningShift ?? 0).toList(),
          money,
          lowerIsBetter: true,
        ),
        _Row.numeric(
          'الشفت المسائي'.tr,
          places.map((p) => p.priceEveningShift ?? 0).toList(),
          money,
          lowerIsBetter: true,
        ),
      ],
    ]),
    _Group(Icons.star_outline_rounded, 'التقييم'.tr, [
      _Row.numeric(
        'التقييم'.tr,
        places.map((p) => p.ratingCount > 0 ? p.ratingAvg : 0).toList(),
        (v) => v <= 0 ? 'جديد'.tr : '★ ${v.toStringAsFixed(1)}',
      ),
      _Row.numeric(
        'عدد التقييمات'.tr,
        places.map((p) => p.ratingCount).toList(),
        (v) => '$v',
      ),
    ]),
    _Group(Icons.place_outlined, 'المكان'.tr, [
      _Row.text('النوع'.tr, places.map((p) => p.typeLabelAr.tr).toList()),
      _Row.text(
        'المدينة'.tr,
        places.map((p) => (p.cityName ?? '—').tr).toList(),
      ),
      _Row.text(
        'المحافظة'.tr,
        places.map((p) => (p.provinceName ?? '—').tr).toList(),
      ),
      _Row.numeric(
        'السعة'.tr,
        places.map((p) => p.capacity).toList(),
        (v) => v <= 0 ? '—' : '{n} ضيف'.trN(v),
      ),
      _Row.text(
        'الحجز'.tr,
        places
            .map((p) => p.supportsShifts ? 'شفتات'.tr : 'يوم كامل'.tr)
            .toList(),
      ),
    ]),
    _Group(Icons.photo_library_outlined, 'الاستعراض'.tr, [
      _Row.flags(
        'جولة 360°'.tr,
        places
            .map((p) => p.media.any((m) => m.kind == MediaKind.panorama))
            .toList(),
        yesNo,
      ),
      _Row.flags(
        'فيديو'.tr,
        places.map((p) => p.firstVideo != null).toList(),
        yesNo,
      ),
    ]),
    if (amenities.isNotEmpty)
      _Group(Icons.checklist_rounded, 'المزايا'.tr, [
        _Row.numeric(
          'عدد المزايا'.tr,
          places.map((p) => p.amenities.length).toList(),
          (v) => '$v',
        ),
        for (final a in amenities)
          _Row.flags(
            a.value.tr,
            places.map((p) => p.amenities.any((x) => x.id == a.key)).toList(),
            yesNo,
          ),
      ]),
  ];
}

class _Group {
  const _Group(this.icon, this.title, this.rows);

  final IconData icon;
  final String title;
  final List<_Row> rows;
}

class _Row {
  const _Row(this.label, this.values, this.best, {this.positive});

  /// قيمة رقمية: الأفضل هو الأعلى، أو الأقل إذا طُلب، ولا يُميَّز عند التعادل.
  factory _Row.numeric(
    String label,
    List<num> values,
    String Function(num) format, {
    bool lowerIsBetter = false,
  }) {
    final known = values.where((v) => v > 0).toList();
    var best = <int>{};
    if (known.toSet().length > 1) {
      final target = lowerIsBetter
          ? known.reduce((a, b) => a < b ? a : b)
          : known.reduce((a, b) => a > b ? a : b);
      best = {
        for (final (i, v) in values.indexed)
          if (v == target) i,
      };
    }
    return _Row(label, values.map(format).toList(), best);
  }

  factory _Row.text(String label, List<String> values) =>
      _Row(label, values, const {});

  factory _Row.flags(
    String label,
    List<bool> values,
    String Function(bool) format,
  ) => _Row(label, values.map(format).toList(), const {}, positive: values);

  final String label;
  final List<String> values;
  final Set<int> best;
  final List<bool>? positive;

  bool get differs => values.toSet().length > 1;
}

class _PlaceHeaders extends ConsumerWidget {
  const _PlaceHeaders({required this.places});

  final List<Property> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdd = places.length < CompareSelectionController.maxItems;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in places.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PlaceHeader(
                property: p,
                onRemove: () =>
                    ref.read(compareSelectionProvider.notifier).toggle(p),
              ),
            ),
          ],
          if (canAdd) ...[
            const SizedBox(width: 8),
            Expanded(child: _AddSlot(places: places)),
          ],
        ],
      ),
    );
  }
}

class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader({required this.property, required this.onRemove});

  final Property property;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/property/${property.id}'),
    child: Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Vibes.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.1,
                child: property.coverUrl != null
                    ? VibesNetImage(
                        url: property.coverUrl!,
                        width: double.infinity,
                        fallback: ColoredBox(color: Vibes.surfaceMuted),
                      )
                    : ColoredBox(
                        color: Vibes.surfaceMuted,
                        child: Icon(
                          Icons.home_work_outlined,
                          color: Vibes.inkTertiary,
                        ),
                      ),
              ),
              PositionedDirectional(
                top: 5,
                end: 5,
                child: Semantics(
                  button: true,
                  label: 'إزالة من المقارنة'.tr,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
            child: Text(
              property.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Vibes.ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.places});

  final List<Property> places;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () =>
        context.push('/search?type=${places.first.type.name.toUpperCase()}'),
    child: Container(
      decoration: BoxDecoration(
        color: Vibes.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Vibes.hairlineStrong),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: Vibes.teal, size: 26),
          const SizedBox(height: 6),
          Text(
            'أضف مكاناً'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Vibes.inkSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// الخلاصة: من يربح في أهم أربعة معايير.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.places});

  final List<Property> places;

  Property? _winner(num Function(Property) score, {bool lowest = false}) {
    final known = places.where((p) => score(p) > 0).toList();
    if (known.map(score).toSet().length < 2) return null;
    known.sort(
      (a, b) =>
          lowest ? score(a).compareTo(score(b)) : score(b).compareTo(score(a)),
    );
    return known.first;
  }

  @override
  Widget build(BuildContext context) {
    final verdicts = [
      (
        Icons.savings_outlined,
        'الأوفر سعراً'.tr,
        _winner((p) => p.pricePerDay, lowest: true),
      ),
      (
        Icons.star_rounded,
        'الأعلى تقييماً'.tr,
        _winner((p) => p.ratingCount > 0 ? p.ratingAvg : 0),
      ),
      (Icons.groups_rounded, 'الأكبر سعة'.tr, _winner((p) => p.capacity)),
      (
        Icons.auto_awesome_rounded,
        'الأكثر مزايا'.tr,
        _winner((p) => p.amenities.length),
      ),
    ].where((v) => v.$3 != null).toList();
    if (verdicts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: Vibes.midnightFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الخلاصة'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          for (final v in verdicts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(v.$1, size: 17, color: Brand.brassLight),
                  const SizedBox(width: 8),
                  Text(
                    v.$2,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .78),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      v.$3!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DifferencesSwitch extends StatelessWidget {
  const _DifferencesSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.filter_list_rounded, size: 18, color: Vibes.inkSecondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'الاختلافات فقط'.tr,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Vibes.ink,
          ),
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Vibes.teal),
      const SizedBox(width: 7),
      Text(
        title,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Vibes.ink,
        ),
      ),
    ],
  );
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.row, required this.showDivider});

  final _Row row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
    decoration: BoxDecoration(
      border: showDivider
          ? Border(top: BorderSide(color: Vibes.hairline))
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Vibes.inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, value) in row.values.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _ValueCell(
                  value: value,
                  best: row.best.contains(i),
                  positive: row.positive?[i],
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.value, required this.best, this.positive});

  final String value;
  final bool best;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    if (positive != null) {
      return Center(
        child: Icon(
          positive! ? Icons.check_circle_rounded : Icons.remove_rounded,
          size: 19,
          color: positive! ? Vibes.success : Vibes.inkTertiary,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: best ? Vibes.tealMint : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 12,
          fontWeight: best ? FontWeight.w900 : FontWeight.w700,
          color: best ? Vibes.honeyDeep : Vibes.ink,
          height: 1.3,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: VibesFont.ui,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Vibes.inkSecondary,
    ),
  );
}

/// زر حجز تحت كل عمود، ثابت في الأسفل.
class _BookBar extends StatelessWidget {
  const _BookBar({required this.places});

  final List<Property> places;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Vibes.surface,
      border: Border(top: BorderSide(color: Vibes.hairline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            for (final (i, p) in places.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () => context.push('/book/${p.id}'),
                  child: Text(
                    'احجز'.tr,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
