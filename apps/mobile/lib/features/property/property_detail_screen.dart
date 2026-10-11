import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../auth/auth_controller.dart';
import '../chat/call_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/data/recent_viewed.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/world_ui.dart';
import '../home/home_editorial.dart' show SectionHead;
import 'place_experience_ui.dart';
import 'shift_calendar_ui.dart';
import 'place_booking_card.dart';

import 'media_gallery.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/widgets/directions_sheet.dart';
import '../../shared/widgets/vibes_map.dart';
import 'share_card.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_graphics.dart';

/// ═══════════════════════════════════════════════════════════
/// صفحة المكان — بلون عالم المكان نفسه:
///   • معرض أفقي غامر يذوب في الصفحة بحافة منحنية.
///   • ترويسة: شارات العالم، الاسم، العنوان، وبطاقة أبرز الأرقام.
///   • شريط أقسام مثبّت يقفز إلى أي قسم ويتتبّع موضعك.
///   • أقسام بعناوين تحريرية موحّدة مع الرئيسية.
///   • شريط حجز عائم بزر متدرّج.
/// ═══════════════════════════════════════════════════════════

String _placeLine(Property property) {
  final city = property.cityName?.trim() ?? '';
  final province = property.provinceName?.trim() ?? '';
  final address = property.address?.trim() ?? '';
  return [
    if (address.isNotEmpty) address,
    if (city.isNotEmpty && !address.contains(city)) city,
    if (province.isNotEmpty && province != city) province,
  ].join(' · ');
}

final _bookingCardKeys = <String, GlobalKey<PlaceBookingCardState>>{};

const _starGold = Color(0xFFF5B301);

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(id));

    return property.when(
      loading: () => const _PropertySkeleton(),
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
        return _PropertyPage(property: p);
      },
    );
  }
}

/// أقسام الصفحة التي يقفز إليها شريط الأقسام.
enum _Anchor { booking, prices, amenities, about, location, reviews }

extension on _Anchor {
  String get label => switch (this) {
    _Anchor.booking => 'الحجز',
    _Anchor.prices => 'الأسعار',
    _Anchor.amenities => 'المزايا',
    _Anchor.about => 'عن المكان',
    _Anchor.location => 'الموقع',
    _Anchor.reviews => 'التقييمات',
  };
}

class _PropertyPage extends ConsumerStatefulWidget {
  const _PropertyPage({required this.property});

  final Property property;

  @override
  ConsumerState<_PropertyPage> createState() => _PropertyPageState();
}

class _PropertyPageState extends ConsumerState<_PropertyPage> {
  final _scroll = ScrollController();
  final _keys = {for (final a in _Anchor.values) a: GlobalKey()};
  final _active = ValueNotifier<_Anchor>(_Anchor.booking);
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_track);
  }

  @override
  void dispose() {
    _scroll.removeListener(_track);
    _scroll.dispose();
    _active.dispose();
    super.dispose();
  }

  double get _pinnedEdge =>
      MediaQuery.paddingOf(context).top +
      kToolbarHeight +
      _AnchorTabsDelegate.height;

  void _track() {
    if (_jumping) return;
    final edge = _pinnedEdge + 40;
    _Anchor? current;
    for (final a in _Anchor.values) {
      final box = _keys[a]!.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= edge) current = a;
    }
    current ??= _Anchor.booking;
    if (_active.value != current) _active.value = current;
  }

  Future<void> _jumpTo(_Anchor a) async {
    final box = _keys[a]!.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    HapticFeedback.selectionClick();
    _active.value = a;
    _jumping = true;
    final top = box.localToGlobal(Offset.zero).dy;
    final target = (_scroll.offset + top - _pinnedEdge - 12).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeInOutCubic,
    );
    _jumping = false;
  }

  Future<void> _toggleFavorite() async {
    if (!ref.read(authControllerProvider).loggedIn) {
      final ok = await context.push<bool>('/login');
      if (ok != true || !mounted) return;
      if (!ref.read(authControllerProvider).loggedIn) return;
    }
    HapticFeedback.lightImpact();
    ref.read(favoritesProvider.notifier).toggle(widget.property);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final world = context.world;
    final availability = ref.watch(
      availabilityProvider((id: p.id, month: null)),
    );
    final dayPrices = availability.value?.dayPrices ?? const <DayPricing>[];
    final isFav =
        ref.watch(favoritesProvider).valueOrNull?.any((f) => f.id == p.id) ??
        false;
    final bookingKey = _bookingCardKeys.putIfAbsent(
      p.id,
      GlobalKey<PlaceBookingCardState>.new,
    );
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = math.min(width * .86, 440.0);

    final hasAmenities = p.amenities.isNotEmpty || p.amenityNames.isNotEmpty;
    final hasAbout = p.description.isNotEmpty || (p.rules ?? '').isNotEmpty;
    final hasLocation = p.latitude != null && p.longitude != null;
    final anchors = <_Anchor>[
      _Anchor.booking,
      _Anchor.prices,
      if (hasAmenities) _Anchor.amenities,
      if (hasAbout) _Anchor.about,
      if (hasLocation) _Anchor.location,
      _Anchor.reviews,
    ];

    Widget anchor(_Anchor a, Widget child) =>
        KeyedSubtree(key: _keys[a], child: child);
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
    Widget head(String title, {String? subtitle}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionHead(
        title: title,
        subtitle: subtitle,
        padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
      ),
    );

    return Scaffold(
      backgroundColor: world.canvas,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _HeroAppBar(
                property: p,
                height: heroHeight,
                scroll: _scroll,
                isFav: isFav,
                onFav: _toggleFavorite,
                onShare: () => _shareAsCard(context, p),
                onSave: () => _pickCollection(context, ref, p.id),
              ),
              SliverToBoxAdapter(child: _TitleBlock(property: p)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _AnchorTabsDelegate(
                  anchors: anchors,
                  active: _active,
                  onTap: _jumpTo,
                  palette: world,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 130 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      anchor(
                        _Anchor.booking,
                        pad(
                          PlaceBookingCard(
                            key: bookingKey,
                            property: p,
                            accent: world.accent,
                            dayPrices: dayPrices,
                          ).animate().fadeIn(duration: VibesMotion.slow),
                        ),
                      ),
                      anchor(
                        _Anchor.prices,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            head(
                              'أسعار الأسبوع',
                              subtitle: 'اضغط أي سعر لتبدأ الحجز بذلك اليوم',
                            ),
                            pad(
                              PlaceWeeklyPriceTable(
                                property: p,
                                accent: world.accent,
                                onBookDay: (weekday, shift) =>
                                    _bookWeekday(p, dayPrices, weekday, shift),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p.reels.isNotEmpty) ...[
                        head(
                          'جولات سريعة',
                          subtitle: 'شاهد المكان بالفيديو قبل أن تحجز',
                        ),
                        _PropertyReelsStrip(reels: p.reels),
                      ],
                      if (hasAmenities)
                        anchor(
                          _Anchor.amenities,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              head(
                                'ما يقدّمه المكان',
                                subtitle:
                                    '${p.amenities.isNotEmpty ? p.amenities.length : p.amenityNames.length} ميزة',
                              ),
                              pad(_AmenitiesGrid(property: p)),
                            ],
                          ),
                        ),
                      if (hasAbout)
                        anchor(
                          _Anchor.about,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              head('عن المكان'),
                              if (p.description.isNotEmpty)
                                pad(_ExpandableText(text: p.description)),
                              if ((p.rules ?? '').isNotEmpty) ...[
                                const SizedBox(height: 18),
                                pad(_RulesCard(rules: p.rules!)),
                              ],
                            ],
                          ),
                        ),
                      if (hasLocation)
                        anchor(
                          _Anchor.location,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              head('أين ستكون'),
                              pad(_LocationCard(property: p)),
                            ],
                          ),
                        ),
                      if (p.providerName != null ||
                          p.phone != null ||
                          p.providerId != null) ...[
                        head('المضيف'),
                        pad(_HostCard(property: p)),
                      ],
                      anchor(
                        _Anchor.reviews,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            head('ماذا قال الضيوف'),
                            _ReviewsSection(property: p),
                          ],
                        ),
                      ),
                      _SimilarPlaces(propertyId: p.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BookingBar(
              property: p,
              dayPrices: dayPrices,
              onBook: () {
                final card = bookingKey.currentState;
                if (card != null) {
                  card.openWizard();
                } else {
                  context.push(placeBookPath(p.id));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// يفتح الحجز على أول تاريخ قادم يطابق اليوم المختار من جدول الأسبوع.
  void _bookWeekday(
    Property p,
    List<DayPricing> dayPrices,
    int weekday,
    ShiftType shift,
  ) {
    DateTime findNext(int weekday) {
      var d = DateTime.now();
      for (var i = 0; i < 8; i++) {
        if (d.weekday == weekday) return d;
        d = d.add(const Duration(days: 1));
      }
      return DateTime.now();
    }

    final next = findNext(weekday);
    final available = dayPrices.any(
      (day) =>
          day.date.year == next.year &&
          day.date.month == next.month &&
          day.date.day == next.day &&
          !day.isPast &&
          !day.isShiftOccupied(shift) &&
          !day.isBlocked &&
          day.priceFor(shift) > 0,
    );
    context.push(
      placeBookPath(p.id, date: available ? next : null, shift: shift),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الرأس — معرض غامر وشريط علوي يتحوّل عند التمرير
// ═══════════════════════════════════════════════════════════

class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({
    required this.property,
    required this.height,
    required this.scroll,
    required this.isFav,
    required this.onFav,
    required this.onShare,
    required this.onSave,
  });

  final Property property;
  final double height;
  final ScrollController scroll;
  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final top = MediaQuery.paddingOf(context).top;
    final range = math.max(1.0, height - kToolbarHeight - top);
    final hero = _PropertyHero(property: property);

    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final t = ((offset - range * .55) / (range * .45)).clamp(0.0, 1.0);
        return SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: height,
          backgroundColor: world.canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          systemOverlayStyle: overlayFor(darkBackground: t < .5),
          leadingWidth: 62,
          leading: Center(
            child: _BarIcon(
              icon: Icons.arrow_back_rounded,
              t: t,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          titleSpacing: 4,
          title: Opacity(
            opacity: t,
            child: Text(
              property.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Vibes.ink,
              ),
            ),
          ),
          actions: [
            _BarIcon(icon: Icons.ios_share_rounded, t: t, onTap: onShare),
            const SizedBox(width: 8),
            _BarIcon(icon: Icons.bookmark_add_outlined, t: t, onTap: onSave),
            const SizedBox(width: 8),
            _BarIcon(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              t: t,
              active: isFav,
              onTap: onFav,
            ),
            const SizedBox(width: 14),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: hero,
          ),
        );
      },
    );
  }
}

/// أيقونة الشريط العلوي — زجاج داكن فوق الصورة، بيضاء عند الانكماش.
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.t,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final double t;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final fg = active
        ? const Color(0xFFE11D48)
        : Color.lerp(Colors.white, Vibes.ink, t)!;
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active && t < .5
              ? Colors.white
              : Color.lerp(
                  Colors.black.withValues(alpha: .32),
                  Colors.white,
                  t,
                ),
          border: Border.all(
            color: Color.lerp(
              Colors.white.withValues(alpha: .24),
              world.accent.withValues(alpha: .18),
              t,
            )!,
          ),
          boxShadow: t > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06 * t),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }
}

class _PropertyHero extends StatelessWidget {
  const _PropertyHero({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (property.media.isNotEmpty)
          Hero(
            tag: 'property-hero-main-${property.id}',
            flightShuttleBuilder:
                (flightContext, animation, direction, fromContext, toContext) {
                  final toHero = toContext.widget as Hero;
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.25, 1, curve: Curves.easeOut),
                    ),
                    child: toHero.child,
                  );
                },
            child: MediaGallery(
              items: property.media,
              height: 300,
              bottomInset: 26,
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(gradient: world.nightfall),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -40,
                  bottom: -30,
                  child: Opacity(
                    opacity: .12,
                    child: VibesCategoryIcon(
                      category: _categoryOf(property),
                      size: 260,
                      color: Colors.white,
                    ),
                  ),
                ),
                Center(
                  child: VibesCategoryIcon(
                    category: _categoryOf(property),
                    size: 72,
                    color: world.accentLight,
                  ),
                ),
              ],
            ),
          ),
        // ظل علوي لقراءة الأيقونات
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .3],
                colors: [
                  Colors.black.withValues(alpha: .38),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // الحافة المنحنية — بداية الورقة
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: world.canvas,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

VibesCategory _categoryOf(Property p) => switch (p.type) {
  PropertyType.farm => VibesCategory.farm,
  PropertyType.hall => VibesCategory.hall,
  PropertyType.decoration => VibesCategory.decoration,
};

// ═══════════════════════════════════════════════════════════
// الترويسة — الشارات، الاسم، العنوان، وأبرز الأرقام
// ═══════════════════════════════════════════════════════════

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final world = context.world;
    final line = _placeLine(p);
    return Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(
                    label: p.typeLabelAr,
                    leading: VibesCategoryIcon(
                      category: _categoryOf(p),
                      size: 13,
                      color: world.accentDeep,
                    ),
                    filled: true,
                  ),
                  if (p.featured)
                    _Tag(
                      label: 'مختار من VIBEES',
                      leading: Icon(
                        Icons.workspace_premium_rounded,
                        size: 14,
                        color: world.accentDeep,
                      ),
                    ),
                  if (p.isNew)
                    const _Tag(
                      label: 'وصل حديثاً',
                      leading: Icon(
                        Icons.fiber_new_rounded,
                        size: 15,
                        color: Color(0xFF0E9F6E),
                      ),
                    ),
                  if (p.supportsShifts)
                    _Tag(
                      label: 'صباحي ومسائي',
                      leading: Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: world.accentDeep,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                p.name,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                  height: 1.2,
                  letterSpacing: -.3,
                ),
              ),
              if (line.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: world.accentDeep,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Vibes.inkSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _HighlightsCard(property: p),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 420.ms)
        .slideY(begin: .04, end: 0, curve: Curves.easeOutCubic);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.leading, this.filled = false});

  final String label;
  final Widget leading;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      decoration: BoxDecoration(
        color: filled ? world.accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: world.accent.withValues(alpha: filled ? .0 : .18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: filled ? world.accentDeep : Vibes.ink,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة أبرز الأرقام — التقييم، السعة، والحجوزات.
class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final world = context.world;
    final cells = <Widget>[
      p.ratingCount > 0
          ? _Stat(
              icon: Icons.star_rounded,
              iconColor: _starGold,
              value: p.ratingAvg.toStringAsFixed(1),
              label: '${p.ratingCount} تقييم',
            )
          : _Stat(
              icon: Icons.auto_awesome_rounded,
              iconColor: world.accent,
              value: 'جديد',
              label: 'بانتظار أول تقييم',
            ),
      if (p.capacity > 0)
        _Stat(
          icon: Icons.groups_rounded,
          iconColor: world.accentDeep,
          value: '${p.capacity}',
          label: 'ضيف كحد أقصى',
        ),
      if (p.bookingsCount > 0)
        _Stat(
          icon: Icons.verified_rounded,
          iconColor: const Color(0xFF0E9F6E),
          value: '${p.bookingsCount}',
          label: 'حجز ناجح',
        )
      else if (p.viewCount > 0)
        _Stat(
          icon: Icons.visibility_outlined,
          iconColor: world.accentDeep,
          value: '${p.viewCount}',
          label: 'مشاهدة',
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: world.accent.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: world.glow.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: world.accent.withValues(alpha: .12),
                ),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Vibes.ink,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Vibes.inkSecondary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// شريط الأقسام المثبّت
// ═══════════════════════════════════════════════════════════

class _AnchorTabsDelegate extends SliverPersistentHeaderDelegate {
  _AnchorTabsDelegate({
    required this.anchors,
    required this.active,
    required this.onTap,
    required this.palette,
  });

  static const height = 58.0;

  final List<_Anchor> anchors;
  final ValueNotifier<_Anchor> active;
  final ValueChanged<_Anchor> onTap;
  final WorldPalette palette;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _AnchorTabs(
      anchors: anchors,
      active: active,
      onTap: onTap,
      raised: overlapsContent,
    );
  }

  @override
  bool shouldRebuild(_AnchorTabsDelegate old) =>
      old.anchors.length != anchors.length || old.palette != palette;
}

class _AnchorTabs extends StatefulWidget {
  const _AnchorTabs({
    required this.anchors,
    required this.active,
    required this.onTap,
    required this.raised,
  });

  final List<_Anchor> anchors;
  final ValueNotifier<_Anchor> active;
  final ValueChanged<_Anchor> onTap;
  final bool raised;

  @override
  State<_AnchorTabs> createState() => _AnchorTabsState();
}

class _AnchorTabsState extends State<_AnchorTabs> {
  late final Map<_Anchor, GlobalKey> _chipKeys = {
    for (final a in _Anchor.values) a: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_reveal);
  }

  @override
  void didUpdateWidget(_AnchorTabs old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      old.active.removeListener(_reveal);
      widget.active.addListener(_reveal);
    }
  }

  @override
  void dispose() {
    widget.active.removeListener(_reveal);
    _tabsScroll.dispose();
    super.dispose();
  }

  final _tabsScroll = ScrollController();

  /// يُظهر الشريحة النشطة بتحريك الشريط الأفقي وحده — لا الصفحة.
  /// (Scrollable.ensureVisible يحرّك كل الأسلاف فيعيد الصفحة للأعلى.)
  void _reveal() {
    final ro = _chipKeys[widget.active.value]?.currentContext
        ?.findRenderObject();
    if (ro == null || !_tabsScroll.hasClients) return;
    _tabsScroll.position.ensureVisible(
      ro,
      alignment: .5,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: world.canvas,
        border: Border(
          bottom: BorderSide(
            color: widget.raised
                ? world.accent.withValues(alpha: .12)
                : Colors.transparent,
          ),
        ),
        boxShadow: widget.raised
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: ValueListenableBuilder<_Anchor>(
        valueListenable: widget.active,
        builder: (context, active, _) {
          return ListView.separated(
            controller: _tabsScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: widget.anchors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final a = widget.anchors[i];
              final on = a == active;
              return GestureDetector(
                key: _chipKeys[a],
                onTap: () => widget.onTap(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: on ? world.fill : null,
                    color: on ? null : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: on
                          ? Colors.transparent
                          : world.accent.withValues(alpha: .16),
                    ),
                  ),
                  child: Text(
                    a.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: on ? world.onAccent : Vibes.inkSecondary,
                      height: 1.2,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
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

/// شريط جولات سريعة — بطاقات ريلز عمودية (9:16) تُقرأ الفيديو عند
/// اللمس (HLS من Bunny CDN). لمسة عابرة تعرض الفيديو؛ السحب يتنقل.
class _PropertyReelsStrip extends StatelessWidget {
  const _PropertyReelsStrip({required this.reels});

  final List<MediaItem> reels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: reels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _ReelPreviewCard(media: reels[i]),
      ),
    );
  }
}

class _ReelPreviewCard extends StatefulWidget {
  const _ReelPreviewCard({required this.media});

  final MediaItem media;

  @override
  State<_ReelPreviewCard> createState() => _ReelPreviewCardState();
}

class _ReelPreviewCardState extends State<_ReelPreviewCard> {
  VideoPlayerController? _video;
  bool _failed = false;

  Future<void> _prime() async {
    if (_video != null || _failed) return;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.playbackUrl),
    );
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
      await c.play();
      await c.pause();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  void _release() {
    _video?.pause();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    return GestureDetector(
      onTap: () {
        // فتح في نافذة ريل ملء الشاشة
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            opaque: false,
            transitionDuration: VibesMotion.slow,
            pageBuilder: (_, __, ___) => _ReelFullscreen(media: m),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      // تحميل الفيديو عند اللمس الطويل — تجربة استكشاف خفيفة
      onLongPressStart: (_) => _prime(),
      onLongPressEnd: (_) => _release(),
      child: Container(
        width: 180,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: VibesTheme.surfaceHighOf(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_video != null && _video!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video!.value.size.width,
                  height: _video!.value.size.height,
                  child: VideoPlayer(_video!),
                ),
              )
            else if (m.posterUrl != null)
              VibesNetImage(url: m.posterUrl!, fit: BoxFit.cover)
            else
              Container(color: Vibes.teal.withValues(alpha: 0.08)),

            // تدرج سفلي + معلومات
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1],
                  colors: [Colors.transparent, Color(0xCC0E1B2C)],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.durationSec != null ? '${m.durationSec} ث' : 'شاهد',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
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

/// ريل ملء الشاشة من صفحة المكان — تشغيل تلقائي بصوت.
class _ReelFullscreen extends StatefulWidget {
  const _ReelFullscreen({required this.media});

  final MediaItem media;

  @override
  State<_ReelFullscreen> createState() => _ReelFullscreenState();
}

class _ReelFullscreenState extends State<_ReelFullscreen> {
  VideoPlayerController? _video;
  bool _failed = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.playbackUrl),
    );
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
      await c.play();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_video != null && _video!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _video!.value.aspectRatio,
                child: VideoPlayer(_video!),
              ),
            )
          else if (_failed)
            const Center(
              child: Text(
                'تعذّر تشغيل الفيديو',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            widget.media.posterUrl != null
                ? VibesNetImage(url: widget.media.posterUrl!, fit: BoxFit.cover)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),

          // نقرة: تشغيل/إيقاف
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                final v = _video;
                if (v == null) return;
                v.value.isPlaying ? v.pause() : v.play();
                setState(() {});
              },
              child: const SizedBox.expand(),
            ),
          ),

          // إغلاق
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // كتم/تفعيل الصوت
          if (_video != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  final v = _video!;
                  setState(() => _muted = !_muted);
                  v.setVolume(_muted ? 0 : 1);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// المزايا — شبكة عمودين، والباقي في ورقة كاملة
// ═══════════════════════════════════════════════════════════

List<(String?, String)> _amenityItems(Property p) => p.amenities.isNotEmpty
    ? [for (final a in p.amenities) (a.icon, a.nameAr)]
    : [for (final n in p.amenityNames) (null, n)];

class _AmenitiesGrid extends StatelessWidget {
  const _AmenitiesGrid({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final items = _amenityItems(property);
    final shown = items.take(8).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in shown)
                  SizedBox(
                    width: w,
                    child: _AmenityTile(icon: e.$1, label: e.$2),
                  ),
              ],
            ),
            if (items.length > shown.length) ...[
              const SizedBox(height: 14),
              WorldGhostButton(
                label: 'عرض كل المزايا (${items.length})',
                icon: Icons.grid_view_rounded,
                onTap: () => _showAllAmenities(context, items),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AmenityTile extends StatelessWidget {
  const _AmenityTile({required this.icon, required this.label});

  final String? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: world.accent.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: world.accentFaint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: (icon ?? '').isNotEmpty
                  ? Text(icon!, style: const TextStyle(fontSize: 16))
                  : Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: world.accentDeep,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Vibes.ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAllAmenities(
  BuildContext context,
  List<(String?, String)> items,
) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final world = context.world;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MaisonSheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                  child: Text(
                    'كل المزايا · ${items.length}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: world.accentDeep,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      20 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _AmenityTile(icon: items[i].$1, label: items[i].$2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// الوصف والقواعد
// ═══════════════════════════════════════════════════════════

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  bool get _long =>
      widget.text.length > 220 || '\n'.allMatches(widget.text).length > 4;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    const style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Vibes.inkSecondary,
      height: 1.85,
    );
    if (!_long) return Text(widget.text, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Text(widget.text, style: style)
              : ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.6, 1],
                    colors: [Colors.black, Colors.transparent],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Text(
                    widget.text,
                    maxLines: 5,
                    overflow: TextOverflow.clip,
                    style: style,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        PressScale(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? 'عرض أقل' : 'اقرأ المزيد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: world.accentDeep,
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: world.accentDeep,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules});

  final String rules;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final items = rules
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: world.accent.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 18, color: world.accentDeep),
              const SizedBox(width: 8),
              const Text(
                'قواعد المكان',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final rule in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: world.accentFaint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: world.accentDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Vibes.inkSecondary,
                        height: 1.6,
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

// ═══════════════════════════════════════════════════════════
// الموقع
// ═══════════════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final lat = property.latitude ?? 33.3152;
    final lng = property.longitude ?? 44.3661;
    final place = (property.address ?? '').trim().isNotEmpty
        ? property.address!.trim()
        : (property.cityName ?? 'الموقع على الخريطة');
    final openMap = () => context.push(
      '/map?id=${property.id}&type=${property.type.name.toUpperCase()}',
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: world.accent.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: world.glow.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // خريطة حقيقية بأسماء عربية ودبوس المكان
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: VibesMapView(
                    markers: [
                      VibesMapMarker(
                        id: property.id,
                        latitude: lat,
                        longitude: lng,
                        imageUrl: property.coverUrl,
                        accent: world.accent,
                        accentLight: world.accentLight,
                        photoPin: true,
                      ),
                    ],
                    centerLat: lat,
                    centerLng: lng,
                    zoom: 14.2,
                    interactive: false,
                    flyToSelection: false,
                    tint: VibesMapTint(
                      land: Color.lerp(
                        const Color(0xFFF6F5F1),
                        world.canvasTint,
                        .45,
                      )!,
                      water: Color.lerp(
                        const Color(0xFFC6DCEC),
                        world.accentLight,
                        .10,
                      )!,
                      green: Color.lerp(
                        const Color(0xFFDDEBD3),
                        world.canvasTint,
                        .25,
                      )!,
                      building: Color.lerp(
                        const Color(0xFFE9E6DF),
                        world.canvasTint,
                        .5,
                      )!,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: openMap,
                  ),
                ),
                PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: PressScale(
                    onTap: openMap,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_full_rounded,
                            size: 14,
                            color: world.accentDeep,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'تكبير الخريطة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Vibes.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: world.accentFaint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: world.accentDeep,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Vibes.ink,
                              height: 1.4,
                            ),
                          ),
                          Text(
                            [property.cityName, property.provinceName]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .toSet()
                                .join(' · '),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Vibes.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: WorldButton(
                        label: 'الاتجاهات',
                        icon: Icons.directions_rounded,
                        height: 50,
                        onTap: () => showDirectionsSheet(
                          context,
                          lat: lat,
                          lng: lng,
                          name: property.name,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: WorldGhostButton(
                        label: 'مشاركة',
                        icon: Icons.ios_share_rounded,
                        height: 50,
                        onTap: () => Share.share(
                          '${property.name}\n${placeMapLink(lat, lng)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'افتح الموقع في Google Maps أو Waze أو أي تطبيق خرائط لديك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Vibes.inkTertiary,
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

// ═══════════════════════════════════════════════════════════
// المضيف
// ═══════════════════════════════════════════════════════════

class _HostCard extends ConsumerWidget {
  const _HostCard({required this.property});

  final Property property;

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri.parse('$scheme$value');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool following,
  ) async {
    final providerId = property.providerId!;
    if (!ref.read(authControllerProvider).loggedIn) {
      final ok = await context.push<bool>('/login');
      if (ok != true || !context.mounted) return;
      if (!ref.read(authControllerProvider).loggedIn) return;
    }
    HapticFeedback.selectionClick();
    final client = ref.read(apiClientProvider);
    try {
      if (following) {
        await client.delete('/api/follows/$providerId');
      } else {
        await client.post('/api/follows/$providerId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(maisonError(e))));
      }
    }
    ref.invalidate(followStatusProvider(providerId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = context.world;
    final name = property.providerName ?? 'مضيف المكان';
    final phone = property.whatsapp ?? property.phone;
    final providerId = property.providerId;
    final follow = providerId == null
        ? null
        : ref.watch(followStatusProvider(providerId)).valueOrNull;
    final initial = name.trim().isNotEmpty ? name.trim().characters.first : 'م';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: world.accent.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: world.glow.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: providerId == null
                ? null
                : () => context.push('/providers/$providerId'),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: world.fill,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: world.canvasTint,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: world.accentDeep,
                              ),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: -2,
                        end: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0E9F6E),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Vibes.ink,
                        ),
                      ),
                      const Text(
                        'مضيف موثّق · يرد عادة خلال ساعة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Vibes.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (providerId != null)
                  Icon(Icons.chevron_left_rounded, color: world.accentDeep),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: world.canvas,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _HostStat(
                      value: '${follow?.followers ?? property.followersCount}',
                      label: 'متابع',
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: world.accent.withValues(alpha: .14),
                  ),
                  Expanded(
                    child: _HostStat(
                      value: '${property.bookingsCount}',
                      label: 'حجز',
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: world.accent.withValues(alpha: .14),
                  ),
                  Expanded(
                    child: _HostStat(
                      value: property.ratingCount > 0
                          ? property.ratingAvg.toStringAsFixed(1)
                          : '—',
                      label: 'التقييم',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (providerId != null)
                Expanded(
                  child: (follow?.following ?? false)
                      ? WorldGhostButton(
                          label: 'تتابعه',
                          icon: Icons.check_rounded,
                          height: 46,
                          onTap: () => _toggleFollow(context, ref, true),
                        )
                      : WorldButton(
                          label: 'متابعة',
                          icon: Icons.person_add_alt_1_rounded,
                          height: 46,
                          onTap: () => _toggleFollow(context, ref, false),
                        ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              _CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => openPropertyChat(ref, context, property.id),
              ),
              const SizedBox(width: 8),
              _CircleAction(
                icon: Icons.call_outlined,
                onTap: () => startCall(ref, context, propertyId: property.id),
              ),
              if (phone != null) ...[
                const SizedBox(width: 8),
                _CircleAction(
                  icon: Icons.forum_rounded,
                  tint: const Color(0xFF16A34A),
                  onTap: () => _launch(
                    'https://wa.me/',
                    phone.replaceFirst(RegExp(r'^\+'), ''),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HostStat extends StatelessWidget {
  const _HostStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Vibes.ink,
            height: 1.2,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Vibes.inkSecondary,
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap, this.tint});

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final c = tint ?? world.accentDeep;
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: .09),
          border: Border.all(color: c.withValues(alpha: .18)),
        ),
        child: Icon(icon, size: 20, color: c),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// التقييمات — ملخص بتوزيع النجوم وسكة بطاقات
// ═══════════════════════════════════════════════════════════

class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = context.world;
    final reviews = ref.watch(propertyReviewsProvider(property.id));

    return reviews.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: WorldSkeleton(height: 120, radius: 22),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: world.accent.withValues(alpha: .12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: world.accentFaint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_outline_rounded,
                      color: world.accentDeep,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لا تقييمات بعد',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Vibes.ink,
                          ),
                        ),
                        Text(
                          'احجز وكن أول من يشارك تجربته هنا',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Vibes.inkSecondary,
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

        final avg = list.fold<num>(0, (a, r) => a + r.rating) / list.length;
        final counts = {
          for (var s = 1; s <= 5; s++)
            s: list.where((r) => r.rating.round() == s).length,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: world.accent.withValues(alpha: .12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: world.glow.withValues(alpha: .08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Vibes.ink,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GoldRatingBar(rating: avg.toDouble(), size: 14),
                        const SizedBox(height: 4),
                        Text(
                          '${list.length} تقييم موثّق',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Vibes.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          for (var s = 5; s >= 1; s--)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.5,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    child: Text(
                                      '$s',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Vibes.inkSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: counts[s]! / list.length,
                                        minHeight: 6,
                                        backgroundColor: world.accentFaint,
                                        color: s >= 4
                                            ? world.accent
                                            : world.accentLight,
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
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: list.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _ReviewCard(review: list[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  Widget build(BuildContext context) {
    final world = context.world;
    final name = (review.userName ?? '').trim().isEmpty
        ? 'ضيف VIBEES'
        : review.userName!.trim();
    final date = review.createdAt;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: world.accent.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: world.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.characters.first,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: world.accentDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                      ),
                    ),
                    if (date != null)
                      Text(
                        '${_months[date.month - 1]} ${date.year}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Vibes.inkTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              GoldRatingBar(rating: review.rating.toDouble(), size: 12),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              review.comment.isNotEmpty
                  ? review.comment
                  : 'قيّم المكان دون تعليق',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.65,
                color: review.comment.isNotEmpty
                    ? Vibes.inkSecondary
                    : Vibes.inkTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// شريط الحجز العائم
// ═══════════════════════════════════════════════════════════

class _BookingBar extends ConsumerWidget {
  const _BookingBar({
    required this.property,
    required this.dayPrices,
    required this.onBook,
  });

  final Property property;
  final List<DayPricing> dayPrices;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = context.world;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final unit = property.type == PropertyType.decoration
        ? 'للخدمة'
        : property.supportsShifts
        ? 'للفترة'
        : 'لليلة';

    return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottom),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: world.accent.withValues(alpha: .14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: world.glow.withValues(alpha: .12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showPlaceDayPricingSheet(
                      context: context,
                      property: property,
                      days: dayPrices,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'يبدأ من',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Vibes.inkTertiary,
                            height: 1.2,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: PlaceFullPriceText(
                                  placeReferencePrice(property, dayPrices),
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'د.ع',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: world.accentDeep,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$unit · جدول الأسعار',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: world.accentDeep,
                            decoration: TextDecoration.underline,
                            decorationColor: world.accent.withValues(alpha: .4),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _CircleAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () => openPropertyChat(ref, context, property.id),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 148,
                  child: WorldButton(
                    label: 'احجز الآن',
                    icon: Icons.event_available_rounded,
                    height: 52,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onBook();
                    },
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .slideY(
          begin: 1,
          end: 0,
          delay: 250.ms,
          duration: 520.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn();
  }
}

// ═══════════════════════════════════════════════════════════
// هيكل التحميل
// ═══════════════════════════════════════════════════════════

class _PropertySkeleton extends StatelessWidget {
  const _PropertySkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: context.world.canvas,
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          WorldSkeleton(height: math.min(width * .86, 440.0), radius: 0),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorldSkeleton(height: 26, width: 140, radius: 999),
                SizedBox(height: 14),
                WorldSkeleton(height: 30),
                SizedBox(height: 10),
                WorldSkeleton(height: 16, width: 220),
                SizedBox(height: 20),
                WorldSkeleton(height: 78, radius: 22),
                SizedBox(height: 20),
                WorldSkeleton(height: 220, radius: 24),
              ],
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: SectionHead(
                title: 'أماكن قد تعجبك',
                subtitle: 'من نفس النوع والمدينة أو مختارات مميزة',
                padding: EdgeInsets.fromLTRB(20, 38, 20, 0),
              ),
            ),
            SizedBox(
              height: FeaturedPropertyCard.plateHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, i) => FeaturedPropertyCard(
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
