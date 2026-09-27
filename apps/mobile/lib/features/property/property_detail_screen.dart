import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';
import '../chat/call_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/data/recent_viewed.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'day_price_strip.dart';
import 'availability_calendar.dart';

import 'media_gallery.dart';
import 'share_card.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/atelier_widgets.dart';
import '../../shared/widgets/property_card.dart';

/// ═══════════════════════════════════════════════════════════
/// صفحة المكان — رأس بارالاكس يذوب في المحتوى
/// معرض غامر، مزايا، أسعار أيام، خريطة، تقييمات، وشريط حجز زجاجي
/// ═══════════════════════════════════════════════════════════

String _placeLine(Property property) {
  final city = property.cityName?.trim() ?? '';
  final province = property.provinceName?.trim() ?? '';
  final address = property.address?.trim() ?? '';
  return [
    if (address.isNotEmpty) address,
    if (province.isNotEmpty && province != city) province,
  ].join(' · ');
}

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(id));
    final availability = ref.watch(availabilityProvider((id: id, month: null)));
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.valueOrNull?.any((p) => p.id == id) ?? false;

    return property.when(
      loading: () => Scaffold(
        backgroundColor: VibesTheme.canvasOf(context),
        body: const Padding(
          padding: EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            children: [
              ShimmerBox(height: 320, radius: VibesRadius.xl),
              SizedBox(height: 18),
              ShimmerBox(height: 28, radius: VibesRadius.md),
              SizedBox(height: 10),
              ShimmerBox(height: 16, radius: VibesRadius.sm),
              SizedBox(height: 22),
              ShimmerBox(height: 120, radius: VibesRadius.lg),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorCanvas(
          message: maisonError(e),
          onRetry: () => ref.invalidate(propertyDetailProvider(id)),
        ),
      ),
      data: (p) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(recentViewedProvider.notifier).record(p);
        });
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
                    expandedHeight: 400,
                    pinned: true,
                    leading: MaisonGlassIcon(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    actions: [
                      MaisonGlassIcon(
                        icon: Icons.ios_share_rounded,
                        onTap: () => _shareAsCard(context, p),
                      ),
                      MaisonGlassIcon(
                        icon: isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        active: isFav,
                        onTap: () async {
                          if (!ref.read(authControllerProvider).loggedIn) {
                            final ok = await context.push<bool>('/login');
                            if (ok != true || !context.mounted) return;
                            if (!ref.read(authControllerProvider).loggedIn) {
                              return;
                            }
                          }
                          ref.read(favoritesProvider.notifier).toggle(p);
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: 'property-hero-${p.id}',
                        child: MediaGallery(items: p.media, height: 400),
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
                                  MaisonKicker(
                                    [p.typeLabelAr, p.cityName ?? '']
                                        .where((s) => s.toString().isNotEmpty)
                                        .join('  ·  '),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    p.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  const ArcFlourish(width: 36),
                                  if (_placeLine(p).isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      _placeLine(p),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: VibesTheme.textTertiaryOf(
                                              context,
                                            ),
                                            height: 1.5,
                                          ),
                                    ),
                                  ],
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
                        const SizedBox(height: 16),
                        _DecisionPanel(
                          property: p,
                          availableDays: dayPrices
                              .where(
                                (day) =>
                                    !day.isPast &&
                                    !day.isBooked &&
                                    !day.isBlocked,
                              )
                              .length,
                          onBook: () => context.push('/book/${p.id}'),
                        ),

                        const SizedBox(height: 24),
                        const ScallopDivider(),
                        const SizedBox(height: 20),
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
                          VibesCard(
                            child: AvailabilityCalendar(
                              days: dayPrices.take(42).toList(),
                              selectedShift: ShiftType.full,
                              onDayTap: (day) {
                                final date = day.date;
                                final key =
                                    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                context.push('/book/${p.id}?date=$key');
                              },
                            ),
                          ),
                        ],

                        // المزايا
                        if (p.amenities.isNotEmpty ||
                            p.amenityNames.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const ScallopDivider(),
                          const SizedBox(height: 20),
                          const SectionHeader('المرافق والمزايا'),
                          _AmenitiesGrid(property: p),
                        ],

                        // الوصف
                        if (p.description.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('عن المكان'),
                          Text(
                            p.description,
                            style: Theme.of(context).textTheme.bodyMedium
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
                        if (p.providerName != null || p.phone != null) ...[
                          const SizedBox(height: 26),
                          const SectionHeader('المالك'),
                          _HostCard(property: p),
                          if (p.providerId != null) ...[
                            const SizedBox(height: 10),
                            _FollowRow(providerId: p.providerId!),
                          ],
                          const SizedBox(height: 10),
                          _SaveToCollectionRow(propertyId: p.id),
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

                        const SizedBox(height: 26),
                        _SimilarPlaces(propertyId: p.id),
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

Future<void> _shareAsCard(BuildContext context, dynamic p) async {
  final cardKey = GlobalKey();
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MaisonSheetHandle(),
          Text(
            'مشاركة كبطاقة',
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ShareablePropertyCard(key: cardKey, property: p as dynamic),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: VibesButton(
              label: 'مشاركة الصورة',
              icon: Icons.share_rounded,
              onPressed: () async {
                Navigator.pop(sheetContext);
                await sharePropertyAsImage(sheetContext, cardKey, p);
              },
            ),
          ),
        ],
      ),
    ),
  );
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
        MaisonSoftChip(
          label: property.typeLabelAr as String,
          leading: Icon(
            Icons.home_work_outlined,
            size: 14,
            color: TypeColors.of((property.type as PropertyType).name),
          ),
        ),
        if (property.capacity > 0)
          MaisonSoftChip(
            label: 'حتى ${property.capacity} ضيف',
            leading: const Icon(
              Icons.groups_outlined,
              size: 14,
              color: Vibes.teal,
            ),
          ),
        if (property.ratingCount > 0)
          MaisonSoftChip(
            label: '${property.ratingAvg} تقييم',
            leading: const Icon(
              Icons.star_rounded,
              size: 14,
              color: Vibes.teal,
            ),
          ),
      ],
    );
  }
}

class _DecisionPanel extends StatelessWidget {
  const _DecisionPanel({
    required this.property,
    required this.availableDays,
    required this.onBook,
  });

  final dynamic property;
  final int availableDays;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final availabilityCopy = availableDays > 0
        ? '$availableDays يوماً متاحاً قريباً'
        : 'تحقق من التواريخ المتاحة';
    return FolioPanel(
      color: VibesDark.canvas,
      borderColor: Vibes.teal.withValues(alpha: .45),
      railColor: Vibes.teal,
      shadows: Vibes.card,
      child: Stack(
        children: [
          const PositionedDirectional(
            end: 14,
            top: 10,
            child: IgnorePointer(
              child: Opacity(
                opacity: .1,
                child: CrestSeal(size: 62, color: Vibes.tealBright),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جاهز لمناسبتك؟',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Vibes.canvas,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        availabilityCopy,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Vibes.canvas.withValues(alpha: .72),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${PriceText.format(property.pricePerDay)} د.ع / اليوم',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Vibes.tealBright,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: onBook,
                    style: FilledButton.styleFrom(
                      backgroundColor: Vibes.teal,
                      foregroundColor: VibesDark.canvas,
                      minimumSize: const Size(92, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('احجز الآن'),
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

class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context) {
    final supportsShifts = property.supportsShifts as bool;
    final labels = property.shiftLabels as ({String morning, String evening});

    // وثيقة الأسعار — صفوف منقّطة راقية
    return VibesCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          AtelierInfoRow(
            label: supportsShifts ? 'اليوم الكامل' : 'السعر لليوم',
            value: '${PriceText.format(property.pricePerDay as num)} د.ع',
          ),
          if (supportsShifts) ...[
            AtelierInfoRow(
              label: 'الشفت الصباحي',
              value: property.priceMorningShift != null
                  ? '${PriceText.format(property.priceMorningShift as num)} د.ع'
                  : '—',
            ),
            AtelierInfoRow(
              label: 'الشفت المسائي',
              value: property.priceEveningShift != null
                  ? '${PriceText.format(property.priceEveningShift as num)} د.ع'
                  : '—',
            ),
            AtelierInfoRow(
              label: 'الأوقات',
              value: '${labels.morning} / ${labels.evening}',
            ),
          ],
          if (property.weekendPrice != null)
            AtelierInfoRow(
              label: 'نهاية الأسبوع',
              value: '${PriceText.format(property.weekendPrice as num)} د.ع',
            ),
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
          return MaisonSoftChip(
            label: a.nameAr as String,
            leading: (a.icon as String?)?.isNotEmpty == true
                ? Text(a.icon!, style: const TextStyle(fontSize: 15))
                : const PetalMark(size: 6),
          );
        }).toList(),
      );
    }

    // احتياط — الأسماء القديمة
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: names.map<Widget>((name) {
        return MaisonSoftChip(label: name, leading: const PetalMark(size: 6));
      }).toList(),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules});

  final String rules;

  @override
  Widget build(BuildContext context) {
    final items = rules.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return VibesCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: PetalMark(size: 6),
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
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    ((property.latitude as num?) ?? 33.3152).toDouble(),
                    ((property.longitude as num?) ?? 44.3661).toDouble(),
                  ),
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: ~InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vibes.vibes',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          ((property.latitude as num?) ?? 33.3152).toDouble(),
                          ((property.longitude as num?) ?? 44.3661).toDouble(),
                        ),
                        width: 40,
                        height: 40,
                        child: const VibesLogo.mark(
                          size: 36,
                          color: Vibes.coral,
                        ),
                      ),
                    ],
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
    final phone = (property.whatsapp as String?) ?? (property.phone as String?);

    return VibesCard(
      onTap: property.providerId != null
          ? () => context.push('/providers/${property.providerId}')
          : null,
      child: Row(
        children: [
          const FolioPanel(
            color: Vibes.surface,
            borderColor: Color(0x66C89844),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: VibesLogo.mark(size: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
              child: const MaisonIconWell(
                icon: Icons.call_outlined,
                size: 40,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _launch(
                'https://wa.me/',
                phone.replaceFirst(RegExp(r'^\+'), ''),
              ),
              child: const MaisonIconWell(
                icon: Icons.chat_bubble_outline_rounded,
                color: Vibes.teal,
                size: 40,
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
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ShimmerBox(height: 72, radius: VibesRadius.md),
            SizedBox(height: 8),
            ShimmerBox(height: 72, radius: VibesRadius.md),
          ],
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
                          r.userName ?? 'ضيف VIBEES',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: VibesTheme.textTertiaryOf(context),
                              ),
                        ),
                      ],
                    ),
                    if (r.comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.comment,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _BookingBar extends ConsumerWidget {
  const _BookingBar({required this.property});

  final dynamic property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: VibesTheme.canvasOf(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(8),
          ),
        ),
        shadows: VibesTheme.floatOf(context),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(height: 3, child: ColoredBox(color: Vibes.teal)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(context).padding.bottom + 14,
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    PriceText(property.pricePerDay as num),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 170,
                      child: VibesButton(
                        label: 'احجز الآن',
                        icon: Icons.calendar_month_rounded,
                        onPressed: () => context.push('/book/${property.id}'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuietLink(
                          label: 'راسل',
                          onTap: () => openPropertyChat(
                            ref,
                            context,
                            property.id as String,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _QuietLink(
                          label: 'اتصل',
                          onTap: () => startCall(
                            ref,
                            context,
                            propertyId: property.id as String,
                          ),
                        ),
                      ],
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
}

class _QuietLink extends StatelessWidget {
  const _QuietLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Vibes.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FollowRow extends ConsumerWidget {
  const _FollowRow({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(followStatusProvider(providerId));
    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (value) {
        return VibesCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.following
                      ? 'تتابع هذا المالك · ${value.followers} متابع'
                      : '${value.followers} يتابعون هذا المالك',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (!ref.read(authControllerProvider).loggedIn) {
                    final ok = await context.push<bool>('/login');
                    if (ok != true || !context.mounted) return;
                    if (!ref.read(authControllerProvider).loggedIn) return;
                  }
                  final client = ref.read(apiClientProvider);
                  if (value.following) {
                    await client.delete('/api/follows/$providerId');
                  } else {
                    await client.post('/api/follows/$providerId');
                  }
                  ref.invalidate(followStatusProvider(providerId));
                },
                child: Text(value.following ? 'إلغاء المتابعة' : 'متابعة'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SaveToCollectionRow extends ConsumerWidget {
  const _SaveToCollectionRow({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VibesCard(
      onTap: () => _pickCollection(context, ref, propertyId),
      child: Row(
        children: [
          const MaisonIconWell(icon: Icons.bookmark_add_outlined, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'حفظ في قائمة',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: VibesTheme.textTertiaryOf(context),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickCollection(
  BuildContext context,
  WidgetRef ref,
  String propertyId,
) async {
  if (!ref.read(authControllerProvider).loggedIn) {
    final ok = await context.push<bool>('/login');
    if (ok != true || !context.mounted) return;
    if (!ref.read(authControllerProvider).loggedIn) return;
  }
  final collections = ref.read(collectionsProvider).valueOrNull ?? [];
  if (collections.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أنشئ قائمة أولاً من المفضلة')),
    );
    return;
  }
  final note = TextEditingController();
  final chosen = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaisonSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: MaisonField(
                label: 'ملاحظة اختيارية',
                controller: note,
                hint: 'لماذا حفظت هذا المكان؟',
              ),
            ),
            for (final col in collections)
              ListTile(
                title: Text(col.name),
                subtitle: Text('${col.itemCount} مكان'),
                onTap: () => Navigator.pop(ctx, col.id),
              ),
          ],
        ),
      ),
    ),
  );
  final itemNote = note.text.trim();
  note.dispose();
  if (chosen == null) return;
  try {
    await ref
        .read(apiClientProvider)
        .post(
          '/api/collections/$chosen/items',
          body: {
            'propertyId': propertyId,
            if (itemNote.isNotEmpty) 'note': itemNote,
          },
        );
    ref.invalidate(collectionsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أُضيف المكان إلى القائمة')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }
}

class _SimilarPlaces extends ConsumerWidget {
  const _SimilarPlaces({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(similarPropertiesProvider(propertyId));
    return similar.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              'أماكن مشابهة',
              subtitle: 'نفس النوع والمدينة أو مختارات مميزة',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: FeaturedPropertyCard.plateHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    FeaturedPropertyCard(
                      property: list[i],
                      index: i,
                      heroNamespace: 'similar',
                    ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
