import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'day_price_strip.dart';
import 'availability_calendar.dart';
import 'media_gallery.dart';

/// ═══════════════════════════════════════════════════════════
/// صفحة المكان — رأس بارالاكس يذوب في المحتوى
/// معرض غامر، مزايا، أسعار أيام، خريطة، تقييمات، وشريط حجز زجاجي
/// ═══════════════════════════════════════════════════════════

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(id));
    final availability = ref.watch(
      availabilityProvider((id: id, month: null)),
    );
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.value?.any((p) => p.id == id) ?? false;

    return property.when(
      loading: () => Scaffold(
        backgroundColor: VibesTheme.canvasOf(context),
        body: const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(propertyDetailProvider(id)),
        ),
      ),
      data: (p) {
        final dayPrices = availability.value?.dayPrices ?? [];

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // رأس البارالاكس — المعرض يذوب عند التمرير
                  SliverAppBar(
                    expandedHeight: 330,
                    pinned: true,
                    leading: _RoundIconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    actions: [
                      _RoundIconBtn(
                        icon: Icons.ios_share_rounded,
                        onTap: () => Share.share(
                          '${p.name} — اكتشفها على تطبيق VIBES',
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RoundIconBtn(
                        icon: isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        golden: isFav,
                        onTap: () => ref
                            .read(favoritesProvider.notifier)
                            .toggle(p),
                      ),
                      const SizedBox(width: 10),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: 'property-hero-${p.id}',
                        child: MediaGallery(items: p.media, height: 330),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // العنوان والنوع
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    [
                                      p.cityName ?? '',
                                      p.provinceName ?? '',
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              VibesTheme.textTertiaryOf(context),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                GoldRatingBar(
                                  rating: p.ratingAvg.toDouble(),
                                  size: 15,
                                  showValue: true,
                                  reviewCount: p.ratingCount,
                                ),
                              ],
                            ),
                          ],
                        ).animate().fadeIn(duration: VibesMotion.slow),

                        const SizedBox(height: 16),
                        _InfoChipsRow(property: p),

                        // الأسعار
                        const SizedBox(height: 26),
                        const SectionHeader('الأسعار'),
                        _PricesCard(property: p),

                        // أسعار الأيام القادمة
                        if (dayPrices.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SectionHeader(
                            'أسعار الأيام القادمة',
                            subtitle: 'تتغير حسب المواسم والقواعد',
                          ),
                          DayPriceStrip(days: dayPrices.take(21).toList()),
                        ],

                        // تقويم التوفر الشهري
                        if (dayPrices.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SectionHeader(
                            'التوفر والأسعار',
                            subtitle: 'المحجوز والمغلق معطّلان',
                          ),
                          AvailabilityCalendar(
                            days: dayPrices.take(42).toList(),
                            selectedShift: ShiftType.full,
                          ),
                        ],

                        // المزايا
                        if (p.amenities.isNotEmpty ||
                            p.amenityNames.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('المرافق والمزايا'),
                          _AmenitiesGrid(property: p),
                        ],

                        // الوصف
                        if (p.description.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('عن المكان'),
                          Text(
                            p.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  height: 1.9,
                                  color: VibesTheme.textSecondaryOf(context),
                                ),
                          ),
                        ],

                        // القواعد
                        if ((p.rules ?? '').isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('قواعد المكان'),
                          _RulesCard(rules: p.rules!),
                        ],

                        // الموقع
                        if (p.latitude != null && p.longitude != null) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('الموقع'),
                          _LocationCard(property: p),
                        ],

                        // المالك
                        if (p.providerName != null ||
                            p.phone != null) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('المالك'),
                          _HostCard(property: p),
                        ],

                        // التقييمات
                        const SizedBox(height: 26),
                        SectionHeader(
                          'التقييمات',
                          subtitle: p.ratingCount > 0
                              ? '${p.ratingCount} تقييماً'
                              : null,
                        ),
                        _ReviewsSection(propertyId: p.id),
                      ]),
                    ),
                  ),
                ],
              ),

              // الشريط السفلي الزجاجي — السعر + الحجز
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BookingBar(property: p),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({
    required this.icon,
    required this.onTap,
    this.golden = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool golden;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .38),
          shape: BoxShape.circle,
          border: Border.all(
            color: golden
                ? GoldColors.gold.withValues(alpha: .7)
                : Colors.white24,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: golden ? GoldColors.gold : Colors.white,
        ),
      ),
    );
  }
}

class _InfoChipsRow extends StatelessWidget {
  const _InfoChipsRow({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
          icon: Icons.home_work_outlined,
          label: property.typeLabelAr as String,
        ),
        if (property.capacity > 0)
          _InfoChip(
            icon: Icons.groups_outlined,
            label: 'حتى ${property.capacity} ضيف',
          ),
        _InfoChip(
          icon: Icons.visibility_outlined,
          label: '${property.viewCount} مشاهدة',
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: VibesTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(VibesRadius.pill),
        border: Border.all(color: VibesTheme.hairlineOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: GoldColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: VibesTheme.textSecondaryOf(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context) {
    final supportsShifts = property.supportsShifts as bool;
    final labels = property.shiftLabels as ({String morning, String evening});

    return VibesCard(
      child: Column(
        children: [
          _PriceRow(
            label: supportsShifts ? 'اليوم الكامل' : 'السعر لليوم',
            time: supportsShifts
                ? '${labels.morning.split(' – ').first} – ${labels.evening.split(' – ').last}'
                : null,
            amount: property.pricePerDay as num,
            featured: true,
          ),
          if (supportsShifts) ...[
            Divider(
              height: 1,
              color: VibesTheme.hairlineOf(context),
            ),
            _PriceRow(
              label: 'الشفت الصباحي',
              time: labels.morning,
              amount: property.priceMorningShift as num?,
            ),
            Divider(
              height: 1,
              color: VibesTheme.hairlineOf(context),
            ),
            _PriceRow(
              label: 'الشفت المسائي',
              time: labels.evening,
              amount: property.priceEveningShift as num?,
            ),
          ],
          if (property.weekendPrice != null) ...[
            Divider(
              height: 1,
              color: VibesTheme.hairlineOf(context),
            ),
            _PriceRow(
              label: 'نهاية الأسبوع (جمعة وسبت)',
              amount: property.weekendPrice as num,
              featured: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.time,
    this.featured = false,
  });

  final String label;
  final num? amount;
  final String? time;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    time!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (amount != null) PriceText(amount!, compact: !featured),
        ],
      ),
    );
  }
}

class _AmenitiesGrid extends StatelessWidget {
  const _AmenitiesGrid({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context) {
    final amenities = property.amenities as List;
    final names = property.amenityNames as List<String>;

    if (amenities.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: amenities.map<Widget>((a) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VibesTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(VibesRadius.md),
              border: Border.all(color: VibesTheme.hairlineOf(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((a.icon as String?)?.isNotEmpty == true) ...[
                  Text(a.icon!, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                ],
                Text(
                  a.nameAr,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // احتياط — الأسماء القديمة
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: names.map<Widget>((name) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: VibesTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(VibesRadius.md),
            border: Border.all(color: VibesTheme.hairlineOf(context)),
          ),
          child: Text(
            name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      }).toList(),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules});

  final String rules;

  @override
  Widget build(BuildContext context) {
    final items =
        rules.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return VibesCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: GoldColors.gold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.6,
                            color: VibesTheme.textSecondaryOf(context),
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context) {
    return VibesCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(VibesRadius.lg),
            ),
            child: Container(
              height: 140,
              color: VibesTheme.surfaceHighOf(context),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 42,
                    color: GoldColors.gold,
                  ),
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: VibesTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(VibesRadius.pill),
                        border:
                            Border.all(color: VibesTheme.hairlineOf(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined,
                              size: 13, color: GoldColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            'افتح في الخرائط',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    (property.address as String?)?.isNotEmpty == true
                        ? property.address as String
                        : '${property.cityName ?? ''} — الموقع على الخريطة',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textSecondaryOf(context),
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

class _HostCard extends StatelessWidget {
  const _HostCard({required this.property});

  final dynamic property;

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri.parse('$scheme$value');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = property.providerName as String? ?? 'مالك المكان';
    final phone =
        (property.whatsapp as String?) ?? (property.phone as String?);

    return VibesCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: GoldColors.gradient,
            ),
            child: Icon(
              Icons.person_rounded,
              color: GoldColors.onGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (phone != null)
                  Text(
                    'للتواصل والاستفسار',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                        ),
                  ),
              ],
            ),
          ),
          if (phone != null) ...[
            GestureDetector(
              onTap: () => _launch('tel:', phone),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VibesTheme.surfaceHighOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: VibesTheme.hairlineOf(context)),
                ),
                child: Icon(Icons.call_outlined,
                    size: 18, color: VibesTheme.textSecondaryOf(context)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _launch(
                'https://wa.me/',
                phone.replaceFirst(RegExp(r'^\+'), ''),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C9A7A).withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4C9A7A).withValues(alpha: .3),
                  ),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: Color(0xFF4C9A7A)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(propertyReviewsProvider(propertyId));

    return reviews.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: GoldColors.gold, strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return VibesCard(
            child: Center(
              child: Text(
                'لا تقييمات بعد — كن أول من يقيّم بعد زيارتك',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(context),
                    ),
              ),
            ),
          );
        }

        return Column(
          children: list.take(4).map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VibesCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GoldRatingBar(rating: r.rating.toDouble(), size: 13),
                        const Spacer(),
                        Text(
                          r.userName ?? 'ضيف VIBES',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                  ),
                        ),
                      ],
                    ),
                    if (r.comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.comment,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  height: 1.7,
                                  color: VibesTheme.textSecondaryOf(context),
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: VibesTheme.surfaceOf(context).withValues(alpha: .92),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(VibesRadius.xl)),
        border: Border(
          top: BorderSide(color: VibesTheme.hairlineOf(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يبدأ من',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(context),
                    ),
              ),
              PriceText(property.pricePerDay as num),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 170,
            child: VibesButton(
              label: 'احجز الآن',
              icon: Icons.calendar_month_rounded,
              onPressed: () => context.push('/book/${property.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
