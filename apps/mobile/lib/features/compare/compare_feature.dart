import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// مقارنة الأماكن — اختر 2 إلى 4 أماكن وقارن جنباً إلى جنب
/// Mobile-first: صفوف سمات قابلة للتمرير الأفقي بدل جدول تقليدي
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
                          Positioned(
                            top: -6,
                            left: -6,
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(compareSelectionProvider.notifier)
                                  .toggle(p),
                              child: FolioPanel(
                                color: VibesTheme.surfaceOf(context),
                                borderColor: VibesTheme.hairlineOf(context),
                                radius: Folio.compact,
                                child: const Padding(
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
                  label: 'قارن',
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

/// شاشة المقارنة — صفوف سمات بتمرير أفقي للبطاقات
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(compareSelectionProvider);

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'مقارنة الأماكن',
              onBack: () => context.pop(),
              trailing: selection.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () =>
                          ref.read(compareSelectionProvider.notifier).clear(),
                      child: const Text('مسح'),
                    ),
            ),
            Expanded(
              child: selection.isEmpty
                  ? const EmptyCanvas(
                      icon: Icons.compare_arrows_rounded,
                      title: 'لا أماكن مختارة',
                      subtitle: 'اختر من 2 إلى 4 أماكن من القوائم ثم اضغط قارن',
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        // صف الهوية — بطاقات المكان
                        SizedBox(
                          height: 236,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: selection.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) =>
                                _CompareHeaderCard(property: selection[i]),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionHeader('السمات'),
                        _CompareRow(
                          label: 'السعر لليوم',
                          values: selection
                              .map(
                                (p) => '${PriceText.format(p.pricePerDay)} د.ع',
                              )
                              .toList(),
                          highlight: true,
                        ),
                        _CompareRow(
                          label: 'التقييم',
                          values: selection
                              .map(
                                (p) => p.ratingCount > 0
                                    ? '★ ${p.ratingAvg.toStringAsFixed(1)} (${p.ratingCount})'
                                    : 'جديد',
                              )
                              .toList(),
                        ),
                        _CompareRow(
                          label: 'السعة',
                          values: selection
                              .map((p) => '${p.capacity} ضيف')
                              .toList(),
                        ),
                        _CompareRow(
                          label: 'النوع',
                          values: selection.map((p) => p.typeLabelAr).toList(),
                        ),
                        _CompareRow(
                          label: 'الموقع',
                          values: selection
                              .map(
                                (p) =>
                                    '${p.cityName ?? '—'} · ${p.provinceName ?? ''}',
                              )
                              .toList(),
                        ),
                        _CompareRow(
                          label: 'الشفتات',
                          values: selection
                              .map(
                                (p) => p.supportsShifts ? 'متاحة' : 'يوم كامل',
                              )
                              .toList(),
                        ),
                        _CompareRow(
                          label: 'جولة 360°',
                          values: selection
                              .map(
                                (p) =>
                                    p.media.any(
                                      (m) => m.kind == MediaKind.panorama,
                                    )
                                    ? 'متوفرة'
                                    : '—',
                              )
                              .toList(),
                        ),
                        _CompareRow(
                          label: 'المزايا',
                          values: selection
                              .map((p) => '${p.amenities.length} ميزة')
                              .toList(),
                        ),
                        _CompareRow(
                          label: 'فيديو',
                          values: selection
                              .map((p) => p.firstVideo != null ? 'متوفر' : '—')
                              .toList(),
                          isLast: true,
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

class _CompareHeaderCard extends StatelessWidget {
  const _CompareHeaderCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: VibesCard(
        onTap: () => context.push('/property/${property.id}'),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: property.coverUrl != null
                  ? Image.network(
                      property.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          Container(color: VibesTheme.surfaceHighOf(context)),
                    )
                  : Container(
                      color: VibesTheme.surfaceHighOf(context),
                      child: Icon(
                        Icons.home_work_outlined,
                        color: VibesTheme.textTertiaryOf(context),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: VibesButton(
                      label: 'احجز هذا',
                      small: true,
                      onPressed: () => context.push('/book/${property.id}'),
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

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.values,
    this.highlight = false,
    this.isLast = false,
  });

  final String label;
  final List<String> values;
  final bool highlight;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: ShapeDecoration(
        color: highlight ? Vibes.coralMint : null,
        shape: RoundedRectangleBorder(
          borderRadius: isLast
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                )
              : Folio.compact,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: highlight
                  ? Vibes.coral
                  : VibesTheme.textTertiaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 22),
              itemBuilder: (context, i) => SizedBox(
                width: 150,
                child: Text(
                  values[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: VibesTheme.textPrimaryOf(context),
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
