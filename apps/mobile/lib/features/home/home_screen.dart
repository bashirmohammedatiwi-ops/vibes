import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/data/recent_viewed.dart';
import '../auth/auth_controller.dart';
import '../booking/booking_providers.dart';
import '../compare/compare_feature.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/property_card.dart';

/// ═══════════════════════════════════════════════════════════
/// الرئيسية — تحية مسرحية، بانرات، تصنيفات، أقسام أنيقة
/// ═══════════════════════════════════════════════════════════

class HomeScreen extends ConsumerWidget {
  // تحديث بالإسقاط + سحب للتحديث
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'طاب يومك';
    return 'مساء النور';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).user?.name;
    final greeting = name != null && name.trim().isNotEmpty
        ? '${_greeting()}، ${name.trim()}'
        : _greeting();

    final topInset = MediaQuery.paddingOf(context).top;
    final coverHeight = (MediaQuery.sizeOf(context).width / 2.15).clamp(
      156.0,
      210.0,
    );
    // SliverAppBar يضيف ارتفاع شريط الحالة بنفسه. لا نكرره هنا.
    const bar = 32.0;

    return MaisonWash(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: Vibes.teal,
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(spotlightsProvider);
          ref.invalidate(newPropertiesProvider('FARM'));
          ref.invalidate(newPropertiesProvider('HALL'));
          ref.invalidate(featuredPropertiesProvider);
          ref.invalidate(topRatedPropertiesProvider);
          ref.invalidate(propertiesProvider(null));
          ref.invalidate(myBookingsProvider);
          ref.invalidate(conversationsUnreadProvider);
          ref.invalidate(notificationsUnreadProvider);
          ref.invalidate(offersProvider);
          ref.invalidate(publicCouponsProvider);
          ref.invalidate(followingProvidersProvider);
        },
        child: CustomScrollView(
          cacheExtent: 720,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: coverHeight,
              collapsedHeight: bar,
              toolbarHeight: 0,
              backgroundColor: VibesTheme.canvasOf(context),
              surfaceTintColor: Colors.transparent,
              flexibleSpace: _MaisonCover(
                greeting: greeting,
                expanded: coverHeight + topInset,
                collapsed: bar + topInset,
              ),
            ),
            const SliverToBoxAdapter(child: _ProvincesSection()),
            const SliverToBoxAdapter(child: _SpotlightStrip()),
            const SliverToBoxAdapter(
              child: _FreshRail(
                title: 'مزارع جديدة',
                subtitle: 'أضيفت حديثاً إلى الضيافة',
                type: 'FARM',
                namespace: 'new-farms',
              ),
            ),
            const SliverToBoxAdapter(
              child: _FreshRail(
                title: 'قاعات جديدة',
                subtitle: 'قاعات دخلت الدار هذا الموسم',
                type: 'HALL',
                namespace: 'new-halls',
              ),
            ),
            const SliverToBoxAdapter(child: _SearchPlate()),
            const SliverToBoxAdapter(child: _NadeemInvitation()),
            const SliverToBoxAdapter(child: _LeadStory()),
            const SliverToBoxAdapter(child: _ContinueBookingSection()),
            const SliverToBoxAdapter(child: _CategoriesSection()),
            const SliverToBoxAdapter(child: _FeaturedSection()),
            const SliverToBoxAdapter(child: _RecentlyViewedSection()),
            const SliverToBoxAdapter(child: _TopRatedSection()),
            const SliverToBoxAdapter(child: _HouseNotes()),
            const SliverToBoxAdapter(child: _PublicCouponsStrip()),
            const SliverToBoxAdapter(child: _FollowingProvidersStrip()),
            const _AllPropertiesSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    ),
    );
  }
}

/// غلاف المجلة — صورة كاملة، ثم شريط ورقي عند الطي
class _MaisonCover extends StatelessWidget {
  const _MaisonCover({
    required this.greeting,
    required this.expanded,
    required this.collapsed,
  });

  final String greeting;
  final double expanded;
  final double collapsed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final span = (expanded - collapsed).clamp(1.0, 2000.0);
        final collapse = (1 - ((height - collapsed) / span)).clamp(0.0, 1.0);
        final bannerFade = (1 - collapse / 0.7).clamp(0.0, 1.0);
        final headerFade = ((collapse - 0.18) / 0.46).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: bannerFade,
              child: Consumer(
                builder: (context, ref, _) {
                  final banners = ref.watch(bannersProvider);
                  return banners.maybeWhen(
                    data: (list) {
                      if (list.isEmpty) {
                        return _HeaderFallback(greeting: greeting);
                      }
                      return _HeroCarousel(
                        greeting: greeting,
                        banners: list,
                        drift: collapse,
                      );
                    },
                    orElse: () => _HeaderFallback(greeting: greeting),
                  );
                },
              ),
            ),
            IgnorePointer(
              ignoring: headerFade < 0.6,
              child: Opacity(
                opacity: headerFade,
                child: const _CollapsedMasthead(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollapsedMasthead extends StatelessWidget {
  const _CollapsedMasthead();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VibesTheme.canvasOf(context),
        border: const Border(
          bottom: BorderSide(color: Vibes.teal, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                const VibesLogo.mark(size: 18),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VIBEES',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VibesTheme.brandOf(context),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const SizedBox(
                      width: 18,
                      height: 1,
                      child: ColoredBox(color: Vibes.teal),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/search'),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'بحث',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Vibes.teal,
                        height: 1,
                      ),
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

class _HeaderFallback extends StatelessWidget {
  const _HeaderFallback({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MaisonNightWash(child: SizedBox.expand()),
        _HeaderContent(greeting: greeting, onTopOfImage: true),
      ],
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({required this.greeting, this.onTopOfImage = false});

  final String greeting;
  final bool onTopOfImage;

  String _mastheadDate() {
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}  ·  ${now.day}/${now.month}';
  }

  @override
  Widget build(BuildContext context) {
    final light = onTopOfImage
        ? Colors.white
        : VibesTheme.textPrimaryOf(context);
    final light2 = onTopOfImage
        ? Colors.white.withValues(alpha: .72)
        : VibesTheme.textTertiaryOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 220 || constraints.maxWidth < 260) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MaisonKicker(
                'VIBEES',
                light: onTopOfImage,
                color: onTopOfImage ? Vibes.tealBright : Vibes.teal,
              ),
              const SizedBox(height: 14),
              Text(
                greeting,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: light2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'وين مناسبتك؟',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  height: 1.05,
                  color: light,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'مزارع وقاعات وتزيين، في العراق',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: light2,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _mastheadDate(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: light2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const ArcFlourish(width: 42, color: Vibes.tealBright),
            ],
          ),
        );
      },
    );
  }
}

class _SearchPlate extends StatelessWidget {
  const _SearchPlate();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/search'),
        child: FolioPanel(
          radius: Folio.chrome,
          color: VibesTheme.surfaceOf(context),
          borderColor: VibesTheme.hairlineOf(context),
          shadows: VibesTheme.cardOf(context),
          railColor: Vibes.teal,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 22, color: Vibes.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إلى أين؟',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Vibes.teal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مزرعة، قاعة، أو مدينة',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: VibesTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'بحث',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: VibesTheme.brandOf(context),
                    fontWeight: FontWeight.w800,
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

class _NadeemInvitation extends StatelessWidget {
  const _NadeemInvitation();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/nadeem'),
          customBorder: Folio.chromeShape,
          child: FolioPanel(
            railColor: Vibes.teal,
            shadows: VibesTheme.cardOf(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const CrestSeal(size: 22, color: Vibes.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نديم',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ستة أسئلة، ثم الأماكن التي تليق بمناسبتك',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: VibesTheme.textTertiaryOf(context),
                                height: 1.45,
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
      ),
    );
  }
}

class _LeadStory extends StatelessWidget {
  const _LeadStory();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final featured = ref.watch(featuredPropertiesProvider);
        return featured.maybeWhen(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            final property = list.first;
            final cover = property.coverUrl;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    'افتتاحية الأسبوع',
                    subtitle: 'مكان واحد، قبل أن تتصفح البقية',
                  ),
                  GestureDetector(
                    onTap: () => context.push('/property/${property.id}'),
                    child: FolioPanel(
                      shadows: VibesTheme.cardOf(context),
                      color: VibesTheme.surfaceOf(context),
                      borderColor: VibesTheme.hairlineOf(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (cover != null)
                                  VibesNetImage(url: cover, fit: BoxFit.cover)
                                else
                                  const ColoredBox(color: VibesDark.canvas),
                                const Positioned.fill(
                                  child: PlateCorners(inset: 10, arm: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 1,
                            child: ColoredBox(color: Vibes.teal),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property.type == PropertyType.hall
                                      ? 'قاعة أعراس'
                                      : property.typeLabelAr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        property.cityName ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: VibesTheme.textTertiaryOf(
                                                context,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    PriceText(
                                      property.pricePerDay,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// سطر ثانوي بعد القصص — بلا ترقيم
class _HouseNotes extends StatelessWidget {
  const _HouseNotes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Row(
        children: [
          _NoteLink(label: 'الخريطة', onTap: () => context.push('/map')),
          const _NoteDot(),
          _NoteLink(label: 'العروض', onTap: () => context.push('/offers')),
          const _NoteDot(),
          _NoteLink(label: 'التجارب', onTap: () => context.push('/experiences')),
        ],
      ),
    );
  }
}

class _NoteDot extends StatelessWidget {
  const _NoteDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(color: Vibes.teal),
      ),
    );
  }
}

class _NoteLink extends StatelessWidget {
  const _NoteLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: VibesTheme.brandOf(context),
        ),
      ),
    );
  }
}

class _PublicCouponsStrip extends ConsumerWidget {
  const _PublicCouponsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(publicCouponsProvider).valueOrNull ?? [];
    if (coupons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: FolioPanel(
        color: VibesTheme.surfaceOf(context),
        borderColor: VibesTheme.hairlineOf(context),
        railColor: Vibes.teal,
        child: InkWell(
          onTap: () => context.push('/coupons'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Text(
                  coupons.first.code,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VibesTheme.brandOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    coupons.first.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  coupons.length > 1 ? '${coupons.length}' : 'كوبون',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Vibes.teal,
                    fontWeight: FontWeight.w800,
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

class _FollowingProvidersStrip extends ConsumerWidget {
  const _FollowingProvidersStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();
    final following = ref.watch(followingProvidersProvider).valueOrNull ?? [];
    if (following.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'أتابعهم',
            action: GestureDetector(
              onTap: () => context.push('/following'),
              child: Text(
                'الكل',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Vibes.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: following.length.clamp(0, 12),
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = following[i];
                return SizedBox(
                  width: 88,
                  child: InkWell(
                    onTap: () => context.push('/providers/${p.id}'),
                    customBorder: Folio.shape,
                    child: Column(
                      children: [
                        FolioPanel(
                          color: VibesTheme.surfaceOf(context),
                          borderColor: VibesTheme.hairlineOf(context),
                          clip: true,
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: p.avatar != null
                                ? VibesNetImage(
                                    url: p.avatar!,
                                    width: 52,
                                    height: 52,
                                    memCacheWidth: 104,
                                  )
                                : Center(
                                    child: Text(
                                      p.displayName.trim().isEmpty
                                          ? 'م'
                                          : p.displayName.trim().substring(
                                              0,
                                              1,
                                            ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: VibesTheme.brandOf(context),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueBookingSection extends StatelessWidget {
  const _ContinueBookingSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final bookings = ref.watch(myBookingsProvider);
        return bookings.maybeWhen(
          data: (list) {
            Booking? active;
            for (final item in list) {
              if (item.status == BookingStatus.pending ||
                  item.status == BookingStatus.awaitingPayment ||
                  item.status == BookingStatus.confirmed) {
                active = item;
                break;
              }
            }
            if (active == null) return const SizedBox.shrink();
            final current = active;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: VibesCard(
                onTap: () => context.push('/booking/${current.id}'),
                child: Row(
                  children: [
                    const MaisonIconWell(
                      icon: Icons.event_available_rounded,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.status == BookingStatus.awaitingPayment
                                ? 'أكمل دفع حجزك'
                                : 'حجزك مستمر',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${current.propertyName ?? 'مكان'} · ${current.statusLabelAr}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: VibesTheme.textTertiaryOf(context),
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _RecentlyViewedSection extends StatelessWidget {
  const _RecentlyViewedSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final recent = ref.watch(recentViewedProvider);
        if (recent.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  'شاهدتها مؤخراً',
                  subtitle: 'أكمل من حيث توقفت',
                ),
              ),
              SizedBox(
                height: FeaturedPropertyCard.heightFor(248),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => FeaturedPropertyCard(
                    property: recent[i],
                    index: i,
                    width: 248,
                    heroNamespace: 'recent',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  @override
  Widget build(BuildContext context) {
    // تصنيفات بصور غلاف من الأماكن المميزة عند توفرها
    return Consumer(
      builder: (context, ref, _) {
        final featured = ref.watch(featuredPropertiesProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            children: [
              const SectionHeader(
                'ثلاث تجارب',
                subtitle: 'مزرعة، قاعة، أو تزيين',
              ),
              SizedBox(
                height: 236,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _ImageCategoryCard(
                        label: 'مزارع',
                        type: 'FARM',
                        imageUrl: featured.maybeWhen(
                          data: (list) => list
                              .where((p) => p.type == PropertyType.farm)
                              .firstOrNull
                              ?.coverUrl,
                          orElse: () => null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: _ImageCategoryCard(
                              label: 'قاعات',
                              type: 'HALL',
                              imageUrl: featured.maybeWhen(
                                data: (list) => list
                                    .where((p) => p.type == PropertyType.hall)
                                    .firstOrNull
                                    ?.coverUrl,
                                orElse: () => null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _ImageCategoryCard(
                              label: 'تزيين',
                              type: 'DECORATION',
                              imageUrl: featured.maybeWhen(
                                data: (list) => list
                                    .where(
                                      (p) => p.type == PropertyType.decoration,
                                    )
                                    .firstOrNull
                                    ?.coverUrl,
                                orElse: () => null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// تصنيفات المحافظات — ديناميكية من بيانات المواقع الفعلية
class _ProvincesSection extends ConsumerWidget {
  const _ProvincesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);
    final properties =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];

    return locations.maybeWhen(
      data: (cities) {
        final unique = <String, ({String name, String slug})>{};
        for (final city in cities) {
          final slug = city.provinceSlug;
          if (slug != null && slug.isNotEmpty && city.provinceName.isNotEmpty) {
            unique[slug] = (name: city.provinceName, slug: slug);
          }
        }

        final provinces = unique.values.toList()
          ..sort((a, b) {
            final aCount = properties
                .where((p) => p.provinceName == a.name)
                .length;
            final bCount = properties
                .where((p) => p.provinceName == b.name)
                .length;
            final byCount = bCount.compareTo(aCount);
            return byCount != 0 ? byCount : a.name.compareTo(b.name);
          });

        if (provinces.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  'المحافظات',
                  subtitle: 'اختر الوجهة قبل أن تختار المكان',
                ),
              ),
              SizedBox(
                height: 136,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: provinces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final province = provinces[index];
                    final matches = properties
                        .where((p) => p.provinceName == province.name)
                        .toList();
                    return _ProvinceCard(
                      name: province.name,
                      slug: province.slug,
                      count: matches.length,
                      imageUrl: matches.firstOrNull?.coverUrl,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({
    required this.name,
    required this.slug,
    required this.count,
    this.imageUrl,
  });

  final String name;
  final String slug;
  final int count;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search?province=$slug'),
      child: SizedBox(
        width: 248,
        height: 136,
        child: FolioPanel(
          color: VibesTheme.surfaceOf(context),
          borderColor: VibesTheme.hairlineOf(context),
          shadows: VibesTheme.cardOf(context),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      VibesNetImage(url: imageUrl!, fit: BoxFit.cover)
                    else
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Color(0xFF1E3A56), VibesDark.canvas],
                          ),
                        ),
                      ),
                    const Positioned.fill(
                      child: PlateCorners(inset: 8, arm: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 1.5,
                child: ColoredBox(color: Vibes.teal),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'محافظة',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Vibes.teal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        count > 0 ? '$count أماكن' : 'استكشف الوجهة',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreshRail extends ConsumerWidget {
  const _FreshRail({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.namespace,
  });

  final String title;
  final String subtitle;
  final String type;
  final String namespace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fresh = ref.watch(newPropertiesProvider(type));
    return fresh.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(title, subtitle: subtitle),
              ),
              SizedBox(
                height: type == 'HALL'
                    ? HallPropertyCard.heightFor(292)
                    : FeaturedPropertyCard.heightFor(220),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => type == 'HALL'
                      ? HallPropertyCard(
                          property: list[i],
                          heroNamespace: namespace,
                        )
                      : FeaturedPropertyCard(
                          property: list[i],
                          width: 220,
                          heroNamespace: namespace,
                        ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SpotlightStrip extends ConsumerStatefulWidget {
  const _SpotlightStrip();

  @override
  ConsumerState<_SpotlightStrip> createState() => _SpotlightStripState();
}

class _SpotlightStripState extends ConsumerState<_SpotlightStrip>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _reel;
  Duration? _lastTick;
  bool _hold = false;

  static const _gap = 8.0;
  static const _speed = 36.0;

  @override
  void initState() {
    super.initState();
    _reel = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || _hold || !_scroll.hasClients) return;
    final count = ref.read(spotlightsProvider).valueOrNull?.length ?? 0;
    if (count < 2) return;
    final loop = count * (_frameWidth + _gap);
    if (loop <= 0) return;
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    var next = _scroll.offset + dt * _speed;
    if (next >= loop) next -= loop;
    _scroll.jumpTo(next);
  }

  double get _frameWidth {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.78).clamp(240.0, 340.0);
  }

  @override
  void dispose() {
    _reel.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotlights = ref.watch(spotlightsProvider);
    return spotlights.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final height = list.first.height.toDouble().clamp(150.0, 190.0);
        final frameWidth = _frameWidth;
        final frames = list.length < 2 ? list : [...list, ...list];
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  'أماكن مميزة',
                  subtitle: 'شريط ثابت، وكل صورة تفتح مكانها',
                ),
              ),
              SizedBox(
                height: height,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notice) {
                    if (notice is ScrollStartNotification &&
                        notice.dragDetails != null) {
                      _hold = true;
                    } else if (notice is ScrollEndNotification) {
                      _hold = false;
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: frames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: _gap),
                    itemBuilder: (context, i) {
                      final item = frames[i];
                      final caption = item.title.isNotEmpty
                          ? item.title
                          : item.propertyName;
                      return SizedBox(
                        width: frameWidth,
                        height: height,
                        child: FolioPanel(
                          clip: true,
                          borderColor: Vibes.teal.withValues(alpha: .45),
                          child: GestureDetector(
                            onTap: () =>
                                context.push('/property/${item.propertyId}'),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VibesNetImage(
                                  url: item.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x00000000),
                                        Color(0x00000000),
                                        Color(0xC00F2138),
                                      ],
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _FilmPerforation(),
                                ),
                                const Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: _FilmPerforation(),
                                ),
                                Positioned(
                                  right: 14,
                                  left: 14,
                                  bottom: 16,
                                  child: Text(
                                    caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _FilmPerforation extends StatelessWidget {
  const _FilmPerforation();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC0F2138),
      child: SizedBox(
        height: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            9,
            (_) => const SizedBox(
              width: 8,
              height: 5,
              child: ColoredBox(color: Vibes.tealBright),
            ),
          ),
        ),
      ),
    );
  }
}

/// قسم عام — عنوان + محتوى أفقي
class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final featured = ref.watch(featuredPropertiesProvider);
        return featured.maybeWhen(
          data: (list) {
            final rest = list.length > 1 ? list.sublist(1) : const <Property>[];
            if (rest.isEmpty) return const SizedBox.shrink();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              for (final property in rest.take(4)) {
                final url = property.coverUrl;
                if (url == null) continue;
                precacheImage(CachedNetworkImageProvider(url), context);
              }
            });
            return Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(
                      'بقية المختارات',
                      subtitle: 'أماكن أخرى لهذه الأيام',
                    ),
                  ),
                  SizedBox(
                    height: FeaturedPropertyCard.heightFor(248),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: rest.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => FeaturedPropertyCard(
                        property: rest[i],
                        index: i,
                        width: 248,
                        heroNamespace: 'picks',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _TopRatedSection extends StatelessWidget {
  const _TopRatedSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final top = ref.watch(topRatedPropertiesProvider);
        return top.maybeWhen(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                children: [
                  const SectionHeader(
                    'محبوبة الضيوف',
                    subtitle: 'الأعلى تقييماً من تجارب حقيقية',
                  ),
                  ...list.take(3).map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PropertyCard(
                        property: p,
                        compact: true,
                        heroNamespace: 'top',
                        heroEnabled: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _AllPropertiesSection extends StatelessWidget {
  const _AllPropertiesSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final properties = ref.watch(propertiesProvider(null));

        return properties.when(
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerBox(height: 320, radius: VibesRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: ErrorCanvas(
              message: maisonError(e),
              onRetry: () => ref.invalidate(propertiesProvider(null)),
            ),
          ),
          data: (list) {
            final favIds = {
              for (final p
                  in ref.watch(favoritesProvider).valueOrNull ??
                      const <Property>[])
                p.id,
            };
            return SliverList.builder(
              itemCount: list.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(20, 30, 20, 4),
                    child: SectionHeader(
                      'المجموعة',
                      subtitle: 'كل الأماكن الجاهزة للحجز',
                    ),
                  );
                }
                final property = list[i - 1];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: PropertyCard(
                    property: property,
                    showCompare: true,
                    onSelectCompare: (p) =>
                        ref.read(compareSelectionProvider.notifier).toggle(p),
                    isFavorite: favIds.contains(property.id),
                    onFavorite: (_) =>
                        ref.read(favoritesProvider.notifier).toggle(property),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// بطاقة تصنيف بصورة — تمرير للبحث المفلتر
class _ImageCategoryCard extends StatelessWidget {
  const _ImageCategoryCard({
    required this.label,
    required this.type,
    this.imageUrl,
  });

  final String label;
  final String type;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search?type=$type'),
      child: FolioPanel(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  VibesNetImage(url: imageUrl!, fit: BoxFit.cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: Vibes.coralFill),
                    child: const SizedBox.expand(),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .45),
                      ],
                    ),
                  ),
                ),
                const PlateCorners(inset: 8, arm: 14),
                Positioned(
                  right: 12,
                  left: 12,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ArcFlourish(width: 28, color: Vibes.tealBright),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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

/// كاروسيل يدور تلقائياً كل 5 ثوانٍ — يتوقف عند اللمس
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({
    required this.greeting,
    required this.banners,
    this.drift = 0,
  });

  final String greeting;
  final List<Banner> banners;
  final double drift;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final list = widget.banners;
    return Stack(
      fit: StackFit.expand,
      children: [
        _AutoCarousel(
          count: list.length,
          onChanged: (i) => setState(() => _index = i),
          builder: (context, i) {
            final banner = list[i];
            return GestureDetector(
              onTap: () {
                final link = banner.linkUrl;
                if (link != null &&
                    link.startsWith('/') &&
                    !link.startsWith('//')) {
                  context.push(link);
                }
              },
              child: ColoredBox(
                color: VibesDark.canvas,
                child: Transform.translate(
                  offset: Offset(0, widget.drift * 42),
                  child: Transform.scale(
                    scale: 1.12,
                    child: VibesNetImage(
                      url: banner.imageUrl,
                      fit: BoxFit.cover,
                      fade: VibesMotion.slow,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .42, .68, 1],
                colors: [
                  Color(0x330F2138),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x66101828),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 22,
          bottom: 16,
          child: Row(
            children: List.generate(list.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: VibesMotion.fast,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 3,
                height: active ? 2 : 3,
                color: active
                    ? Vibes.tealBright
                    : Colors.white.withValues(alpha: .55),
              );
            }),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: Vibes.teal,
            child: SizedBox(height: 1.5),
          ),
        ),
        Opacity(
          opacity: (1 - widget.drift * 1.2).clamp(0.0, 1.0),
          child: _HeaderContent(greeting: widget.greeting, onTopOfImage: true),
        ),
      ],
    );
  }
}

class _AutoCarousel extends StatefulWidget {
  const _AutoCarousel({
    required this.count,
    required this.builder,
    this.onChanged,
  });

  final int count;
  final Widget Function(BuildContext, int) builder;
  final ValueChanged<int>? onChanged;

  @override
  State<_AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<_AutoCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled || !isAppResumed)
        return;
      if (!_controller.hasClients || widget.count < 2) return;
      final next = (_current + 1) % widget.count;
      _controller.animateToPage(
        next,
        duration: VibesMotion.slow,
        curve: VibesMotion.curve,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.count,
      onPageChanged: (i) {
        setState(() => _current = i);
        widget.onChanged?.call(i);
      },
      itemBuilder: (context, i) => widget.builder(context, i),
    );
  }
}
