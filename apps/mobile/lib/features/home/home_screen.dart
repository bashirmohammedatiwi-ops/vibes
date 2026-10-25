import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/perf/perf.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/recent_viewed.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/world_glyphs.dart';
import '../../shared/widgets/world_ui.dart';
import '../auth/auth_controller.dart';
import '../booking/booking_providers.dart';
import 'home_editorial.dart';
import '../concierge/nadeem_config.dart';
import 'home_layout.dart';
import 'home_sections.dart';

/// ═══════════════════════════════════════════════════════════
/// الرئيسية — «بوابة العوالم»
///   • مسرح سينمائي: صورة حقيقية من العالم الحالي بتكبير بطيء،
///     مغطاة بليل العالم، عنوان كبير، مبدّل عوالم بمؤشر منزلق،
///     وكبسولة بحث. اسحب المسرح أفقياً للانتقال بين العوالم.
///   • عند التمرير ينكمش المسرح إلى شريط بمبدّل مصغّر.
///   • كل قسم يتبع العالم: المحتوى يتلاشى وينزلق عند التبديل،
///     والألوان تتحول مع الثيم.
///   • لغة بطاقات واحدة: بطاقة العرض الكبرى، بطاقة السكة،
///     والبطاقة العريضة — نفس الزوايا والظلال والخطوط.
/// ═══════════════════════════════════════════════════════════

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _compact = ValueNotifier<double>(0);

  /// مقدار السحب فوق أعلى الصفحة — تملؤه خلفية العالم الملوّنة.
  final _overscroll = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    PerfProbe.run(_scroll);
  }

  void _onScroll() {
    // الشريط المصغّر يظهر حين يختفي العنوان الكبير
    final t = ((_scroll.offset - 150) / 60).clamp(0.0, 1.0);
    if (t != _compact.value) _compact.value = t;
    final o = (-_scroll.offset).clamp(0.0, 600.0);
    if (o != _overscroll.value) _overscroll.value = o;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _compact.dispose();
    _overscroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final layout = homeLayoutNow(ref);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Stack(
          children: [
            // خلفية ملوّنة تملأ فراغ السحب فوق أعلى الصفحة فقط
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _overscroll,
                builder: (context, o, _) => o <= 0
                    ? const SizedBox.shrink()
                    : Container(
                        height: o + 40,
                        decoration: BoxDecoration(gradient: _heroGradient(p)),
                      ),
              ),
            ),
            RefreshIndicator(
              color: p.accent,
              edgeOffset: top + 20,
              onRefresh: () async {
                ref.invalidate(homeLayoutProvider);
                ref.invalidate(bannersProvider);
                ref.invalidate(spotlightsProvider);
                ref.invalidate(newPropertiesProvider('FARM'));
                ref.invalidate(newPropertiesProvider('HALL'));
                ref.invalidate(newPropertiesProvider('DECORATION'));
                ref.invalidate(featuredPropertiesProvider);
                ref.invalidate(topRatedPropertiesProvider);
                ref.invalidate(propertiesProvider(null));
                ref.invalidate(myBookingsProvider);
                ref.invalidate(conversationsUnreadProvider);
                ref.invalidate(notificationsUnreadProvider);
                ref.invalidate(offersProvider);
                ref.invalidate(publicCouponsProvider);
                ref.invalidate(followingProvidersProvider);
                ref.invalidate(locationsProvider);
              },
              child: CustomScrollView(
                controller: _scroll,
                cacheExtent: 1000,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: _HeroHeader()),
                  // الأقسام تُبنى بكسل — فقط ما يقترب من الشاشة يُبنى ويُرسم
                  DecoratedSliver(
                    decoration: BoxDecoration(color: p.canvas),
                    // الأقسام وترتيبها من لوحة التحكم (الصفحة الرئيسية)
                    sliver: SliverList.list(
                      children: [
                        for (final key in layout.body)
                          if (_bodySection(key) case final w?) w,
                      ],
                    ),
                  ),
                  SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: ColoredBox(
                          color: p.canvas,
                          child: const SizedBox(height: 1),
                        ),
                      ),
                      if (layout.shows('allPlaces')) const _AllPlacesSection(),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: p.canvas,
                      child: Column(
                        children: [
                          if (layout.shows('footer')) const _HomeFooter(),
                          SizedBox(height: 118 + bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // الشريط المصغّر عند التمرير
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _compact,
                builder: (context, t, _) => t == 0
                    ? const SizedBox.shrink()
                    : Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, -12 * (1 - t)),
                          child: const _CompactBar(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

LinearGradient _heroGradient(WorldPalette p) => LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [
    Color.lerp(p.accent, p.accentDeep, .25)!,
    p.accentDeep,
    Color.lerp(p.accentDeep, p.night, .45)!,
  ],
  stops: const [0, .55, 1],
);

// ═══════════════════════════════════════════════════════════
// أدوات مشتركة
// ═══════════════════════════════════════════════════════════

String _greeting() {
  final h = DateTime.now().hour;
  if (h >= 4 && h < 12) return 'صباح الخير';
  if (h >= 12 && h < 17) return 'نهارك سعيد';
  return 'مساء الخير';
}

void _selectWorld(WidgetRef ref, HomeSection world) {
  if (ref.read(homeSectionProvider) == world) return;
  worldSwitchHaptic();
  ref.read(homeSectionProvider.notifier).state = world;
}

/// «مكان واحد / مكانان / 5 أماكن / 12 مكاناً».
String _placesCount(int n) {
  if (n == 1) return 'مكان واحد';
  if (n == 2) return 'مكانان';
  if (n >= 3 && n <= 10) return '$n أماكن';
  return '$n مكاناً';
}

/// المحافظة المختارة من رأس الرئيسية — (الاسم، المعرّف) أو لا شيء = كل العراق.
final homeProvinceProvider = StateProvider<({String name, String slug})?>(
  (ref) => null,
);

bool _inWorld(Property p, HomeSection s) =>
    p.type.name.toUpperCase() == s.typeFilter;

/// أقل سعر معروض للمكان — الشفت الأرخص إن وُجد.
num _fromPrice(Property p) {
  final prices = <num>[
    p.pricePerDay,
    if (p.priceMorningShift != null) p.priceMorningShift!,
    if (p.priceEveningShift != null) p.priceEveningShift!,
  ].where((v) => v > 0).toList();
  if (prices.isEmpty) return p.pricePerDay;
  prices.sort();
  return prices.first;
}

String _priceUnit(Property p) {
  if (p.type == PropertyType.decoration) return 'للخدمة';
  return p.supportsShifts ? 'للفترة' : 'لليوم';
}

String _placeWhere(Property p) => [
  p.cityName ?? p.provinceName ?? '',
  if (p.capacity > 0) 'حتى ${p.capacity} ضيف',
].where((s) => s.isNotEmpty).join(' · ');

const _arMonthsShort = [
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

/// يبدّل محتوى القسم بتلاشٍ وانزلاق ناعم عند تغيير العالم.
/// المحتوى الخارج يحتفظ بعالمه القديم حتى يختفي.
class _WorldFade extends ConsumerWidget {
  const _WorldFade({required this.builder});

  final Widget Function(HomeSection section) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(section), child: builder(section)),
    );
  }
}

/// رأس قسم موحّد — عنوان واضح، سطر وصف، وزر «الكل».
class _Head extends StatelessWidget {
  const _Head(this.title, {this.subtitle, this.onMore});

  final String title;
  final String? subtitle;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionHead(
        title: title,
        subtitle: subtitle,
        actionLabel: onMore == null ? null : 'الكل',
        onAction: onMore,
      ),
    );
  }
}

/// كبسولة بيضاء صغيرة فوق الصور — للتقييم والشارات.
class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.label, this.icon, this.iconColor});

  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? Vibes.ink),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Vibes.ink,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

const _starGold = Color(0xFFF5B301);

/// صورة المكان أو بديل أنيق بلون عالمه.
class _Cover extends StatelessWidget {
  const _Cover({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) =>
      PropertyCover(property: property, iconSize: 40, memCacheWidth: 720);
}

/// زر المفضلة — زجاجي فوق الصور، يطلب الدخول عند الحاجة.
class _FavButton extends ConsumerWidget {
  const _FavButton({required this.property, this.size = 38});

  final Property property;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav =
        ref
            .watch(favoritesProvider)
            .valueOrNull
            ?.any((f) => f.id == property.id) ??
        false;
    return PressScale(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (!ref.read(authControllerProvider).loggedIn) {
          final ok = await context.push<bool>('/login');
          if (ok != true || !context.mounted) return;
          if (!ref.read(authControllerProvider).loggedIn) return;
        }
        ref.read(favoritesProvider.notifier).toggle(property);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFav ? Colors.white : Colors.black.withValues(alpha: .30),
          border: Border.all(
            color: Colors.white.withValues(alpha: isFav ? 1 : .28),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isFav),
            size: size * .48,
            color: isFav ? const Color(0xFFE11D48) : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الرأس — قسم ملوّن بلون العالم بزخارف دوّامية، الموقع والصورة،
// وعنوان من سطرين؛ تعلوه ورقة بيضاء منحنية فيها البحث والعوالم
// والبنر وبطاقة «أقرب مكان».
// ═══════════════════════════════════════════════════════════

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    final p = context.world;
    final top = MediaQuery.paddingOf(context).top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(gradient: _heroGradient(p)),
      child: Stack(
        children: [
          // الزخارف
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SwirlPainter(Colors.white)),
            ),
          ),
          PositionedDirectional(
            end: -34,
            top: top + 34,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Opacity(
                  key: ValueKey(section),
                  opacity: .12,
                  child: WorldGlyph(
                    section: section,
                    size: 190,
                    primary: Colors.white,
                    secondary: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: top + 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _ScrollFade(
                  distance: 120,
                  lift: .25,
                  child: _HeroTopRow(),
                ),
              ),
              const SizedBox(height: 22),
              _ScrollFade(
                distance: 170,
                lift: .4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 460),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, .2),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.topStart,
                      children: [...previous, ?current],
                    ),
                    child: _Headline(key: ValueKey(section), section: section),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _Sheet(),
            ],
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({super.key, required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final (a, b) = switch (section) {
      HomeSection.farm => ('احجز مزرعتك', 'ليومٍ لا يُنسى.'),
      HomeSection.hall => ('اختر قاعتك', 'لليلة العمر.'),
      HomeSection.decoration => ('زيّن مناسبتك', 'بأجمل التفاصيل.'),
    };
    const style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 31,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.22,
      letterSpacing: -.3,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$a\n'),
          TextSpan(
            text: b,
            style: style.copyWith(color: Colors.white.withValues(alpha: .58)),
          ),
        ],
      ),
      style: style,
    );
  }
}

class _HeroTopRow extends ConsumerWidget {
  const _HeroTopRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final first = (user?.name ?? '').trim().split(' ').first;
    final notifUnread = ref.watch(notificationsUnreadProvider).valueOrNull ?? 0;
    final chatUnread = ref.watch(conversationsUnreadProvider).valueOrNull ?? 0;
    final province = ref.watch(homeProvinceProvider);

    return Row(
      children: [
        // الموقع
        PressScale(
          onTap: () => _pickProvince(context),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .55),
                    width: 1.4,
                  ),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    first.isEmpty ? _greeting() : '${_greeting()}، $first',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: .75),
                      height: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        province?.name ?? 'كل العراق',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _HeroIcon(
          icon: Icons.chat_bubble_outline_rounded,
          dot: chatUnread > 0,
          onTap: () {
            ref.invalidate(conversationsUnreadProvider);
            context.push('/conversations');
          },
        ),
        const SizedBox(width: 8),
        _HeroIcon(
          icon: Icons.notifications_none_rounded,
          dot: notifUnread > 0,
          onTap: () {
            ref.invalidate(notificationsUnreadProvider);
            context.push('/notifications');
          },
        ),
        const SizedBox(width: 10),
        // الصورة — أو الشعار الأبيض الصافي للزائر
        PressScale(
          onTap: () => context.go('/profile'),
          child: first.isEmpty
              ? const SizedBox(
                  width: 44,
                  height: 48,
                  child: VibesLogo.mark(size: 44, color: Colors.white),
                )
              : Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: context.world.canvasTint,
                      child: Center(
                        child: Text(
                          first.characters.first,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: context.world.accentDeep,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.onTap, this.dot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .14),
          border: Border.all(color: Colors.white.withValues(alpha: .28)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            if (dot)
              const PositionedDirectional(
                top: 9,
                end: 10,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD166),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// زخرفة دوّامية — حلقات عريضة شفافة تمنح القسم الملوّن عمقاً.
class _SwirlPainter extends CustomPainter {
  _SwirlPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: .07);
    paint.strokeWidth = 38;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * .05, 40), radius: 150),
      .2,
      3.6,
      false,
      paint,
    );
    paint.strokeWidth = 26;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * .78, 230), radius: 95),
      3.4,
      4.2,
      false,
      paint,
    );
    paint
      ..strokeWidth = 14
      ..color = color.withValues(alpha: .05);
    canvas.drawCircle(Offset(size.width * .35, 300), 60, paint);
  }

  @override
  bool shouldRepaint(_SwirlPainter old) => old.color != color;
}

/// الورقة البيضاء — مقبض صغير، بحث، العوالم، البنر، وأقرب مكان.
class _Sheet extends ConsumerWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final section = ref.watch(homeSectionProvider);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDFE3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SearchField(section: section),
          ),
          const _SheetTitle('اختر عالمك'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _WorldTiles(),
          ),
          const SizedBox(height: 22),
          for (final key in homeLayoutNow(ref).header)
            ...switch (key) {
              'banners' => const [
                _Reveal(order: 0, child: _BannerCarousel()),
                SizedBox(height: 18),
              ],
              'nearest' => const [_Reveal(order: 1, child: _NearestCard())],
              'quickLinks' => const [_Reveal(order: 2, child: _QuickRail())],
              'destinations' => [
                _WorldFade(builder: (s) => _PopularDestinations(section: s)),
              ],
              _ => const <Widget>[],
            },
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Vibes.ink,
          height: 1.2,
        ),
      ),
    );
  }
}

/// حقل البحث — رمادي ناعم، وتلميحات تتبدّل كل ثلاث ثوانٍ بأمثلة حقيقية.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.section});

  final HomeSection section;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  Timer? _timer;
  int _hint = 0;

  static const _hints = {
    HomeSection.farm: [
      'ابحث عن مزرعة…',
      'مزرعة بمسبح في بغداد',
      'شفت مسائي لعائلتك',
      'مزرعة تتسع لـ 50 ضيفاً',
    ],
    HomeSection.hall: [
      'ابحث عن قاعة…',
      'قاعة أعراس لـ 400 ضيف',
      'قاعة بجولة 360°',
      'قاعة خطوبة أنيقة',
    ],
    HomeSection.decoration: [
      'ابحث عن خدمة تزيين…',
      'كوشة عرس فاخرة',
      'زينة عيد ميلاد',
      'تنسيق ورد طبيعي',
    ],
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      setState(() => _hint = (_hint + 1) % _hints[widget.section]!.length);
    });
  }

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (old.section != widget.section) _hint = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final province = ref.watch(homeProvinceProvider);
    final hint = _hints[widget.section]![_hint];
    final query =
        'type=${widget.section.typeFilter}${province == null ? '' : '&province=${province.slug}'}';
    return PressScale(
      onTap: () => context.push('/search?$query'),
      child: Container(
        height: 56,
        padding: const EdgeInsetsDirectional.only(start: 18, end: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Vibes.ink, size: 23),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, .8),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    province == null || _hint != 0
                        ? hint
                        : '${hint.replaceAll('…', '')} في ${province.name}',
                    key: ValueKey(
                      '${widget.section.name}-$_hint-${province?.slug}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Vibes.inkTertiary,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded, color: p.accentDeep, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// يتلاشى ويصعد مع تمرير الصفحة — يمنح الرأس عمقاً عند النزول.
class _ScrollFade extends StatelessWidget {
  const _ScrollFade({
    required this.distance,
    required this.lift,
    required this.child,
  });

  final double distance;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;
    return AnimatedBuilder(
      animation: position,
      builder: (context, child) {
        final o = position.hasPixels
            ? position.pixels.clamp(0.0, distance * 2)
            : 0.0;
        final t = (o / distance).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(offset: Offset(0, o * lift), child: child),
        );
      },
      child: child,
    );
  }
}

/// ورقة المحافظات — كل العراق أو محافظة بعينها مع عدد أماكن العالم الحالي.
Future<void> _pickProvince(BuildContext context) {
  final theme = Theme.of(context);
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Theme(data: theme, child: const _ProvinceSheet()),
  );
}

class _ProvinceSheet extends ConsumerWidget {
  const _ProvinceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final section = ref.watch(homeSectionProvider);
    final selected = ref.watch(homeProvinceProvider);
    final cities =
        ref.watch(locationsProvider).valueOrNull ?? const <CityOption>[];
    final props =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    final provinces = <String, ({String name, String slug})>{};
    for (final c in cities) {
      final slug = c.provinceSlug;
      if (slug != null && slug.isNotEmpty && c.provinceName.isNotEmpty) {
        provinces[slug] = (name: c.provinceName, slug: slug);
      }
    }
    int countFor(String name) => props
        .where((x) => x.provinceName == name && _inWorld(x, section))
        .length;
    final list = provinces.values.toList()
      ..sort((a, b) => countFor(b.name).compareTo(countFor(a.name)));
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget row({
      required String title,
      required int count,
      required bool on,
      required VoidCallback onTap,
      IconData icon = Icons.location_on_outlined,
    }) {
      return PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: on ? p.accentSoft : const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? p.accent : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: on ? p.accentDeep : Vibes.inkSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Vibes.ink,
                  ),
                ),
              ),
              Text(
                count > 0 ? _placesCount(count) : 'لا أماكن بعد',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? p.accentDeep : Vibes.inkTertiary,
                ),
              ),
              if (on) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, size: 20, color: p.accent),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDFE3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'أين تبحث؟',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Vibes.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'اختر محافظة ليبحث البحث فيها مباشرة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
              children: [
                row(
                  title: 'كل العراق',
                  icon: Icons.public_rounded,
                  count: props.where((x) => _inWorld(x, section)).length,
                  on: selected == null,
                  onTap: () {
                    ref.read(homeProvinceProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                ),
                for (final pr in list)
                  row(
                    title: pr.name,
                    count: countFor(pr.name),
                    on: selected?.slug == pr.slug,
                    onTap: () {
                      ref.read(homeProvinceProvider.notifier).state = pr;
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «اعثر على أقرب مكان» — بطاقة داكنة بخريطة مصغّرة وسهم.
class _NearestCard extends ConsumerWidget {
  const _NearestCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final section = ref.watch(homeSectionProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: PressScale(
        onTap: () => context.push('/map?type=${section.typeFilter}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          height: 96,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: p.nightfall,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: p.night.withValues(alpha: .25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 112,
                  height: double.infinity,
                  child: CustomPaint(painter: _MiniMapPainter(p.accent)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  switch (section) {
                    HomeSection.farm => 'اعثر على أقرب\nمزرعة إليك',
                    HomeSection.hall => 'اعثر على أقرب\nقاعة إليك',
                    HomeSection.decoration => 'اعثر على أقرب\nفريق تزيين',
                  },
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: p.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: p.onAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// خريطة مصغّرة مرسومة — طرق بيضاء ونهر ودبوس بلون العالم.
class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDEFF2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * .72)
        ..quadraticBezierTo(w * .4, h * .55, w * .62, h * .8)
        ..quadraticBezierTo(w * .8, h, w, h * .86),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = const Color(0xFFC9DDEB),
    );
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    canvas.drawLine(Offset(w * .2, 0), Offset(w * .32, h), road);
    canvas.drawLine(Offset(0, h * .3), Offset(w, h * .22), road);
    canvas.drawLine(
      Offset(w * .7, 0),
      Offset(w * .55, h),
      road..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(0, h * .55),
      Offset(w, h * .5),
      road..strokeWidth = 1.6,
    );
    final c = Offset(w * .5, h * .42);
    canvas.drawCircle(c, 13, Paint()..color = accent.withValues(alpha: .22));
    final pin = Path()
      ..moveTo(c.dx, c.dy + 9)
      ..quadraticBezierTo(c.dx - 9, c.dy - 1, c.dx - 7, c.dy - 6)
      ..arcToPoint(Offset(c.dx + 7, c.dy - 6), radius: const Radius.circular(8))
      ..quadraticBezierTo(c.dx + 9, c.dy - 1, c.dx, c.dy + 9)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFF1E2430));
    canvas.drawCircle(
      Offset(c.dx, c.dy - 3.5),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => old.accent != accent;
}

/// مبدّل العوالم — لوحة بيضاء واحدة ومؤشر متدرّج ينزلق بين العوالم
/// بحركة متصلة؛ الأيقونة والاسم يتلوّنان تدريجياً مع وصول المؤشر.
/// اللمس أو السحب الأفقي على اللوحة يبدّل العالم.
class _WorldTiles extends ConsumerWidget {
  const _WorldTiles();

  static const _duration = Duration(milliseconds: 560);
  static const _curve = Curves.easeOutQuart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(homeSectionProvider);
    final all =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    final p = current.palette;

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 220) return;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final step = (v < 0 ? 1 : -1) * (rtl ? -1 : 1);
        final next = (current.index + step).clamp(
          0,
          HomeSection.values.length - 1,
        );
        _selectWorld(ref, HomeSection.values[next]);
      },
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / HomeSection.values.length;
            return Stack(
              children: [
                // المؤشر المنزلق — كبسولة بلون العالم مع لمعة علوية
                AnimatedPositionedDirectional(
                  duration: _duration,
                  curve: _curve,
                  start: current.index * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: AnimatedContainer(
                    duration: _duration,
                    curve: _curve,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [p.accent, p.accentDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: p.glow.withValues(alpha: .26),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.white.withValues(alpha: .18),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final s in HomeSection.values)
                        Expanded(
                          child: _WorldSegment(
                            section: s,
                            active: s == current,
                            count: all.where((x) => _inWorld(x, s)).length,
                            onTap: () => _selectWorld(ref, s),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorldSegment extends StatelessWidget {
  const _WorldSegment({
    required this.section,
    required this.active,
    required this.count,
    required this.onTap,
  });

  final HomeSection section;
  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = section.palette;
    return Semantics(
      button: true,
      selected: active,
      label: section.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!active) HapticFeedback.selectionClick();
          onTap();
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: active ? 1 : 0),
          duration: _WorldTiles._duration,
          curve: _WorldTiles._curve,
          builder: (context, t, _) {
            final primary = Color.lerp(p.accentDeep, Colors.white, t)!;
            final secondary = Color.lerp(
              p.accent,
              Colors.white.withValues(alpha: .7),
              t,
            )!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // الأيقونة مرسومة بلا إطار — بلون عالمها، وبيضاء عند الاختيار
                    Transform.scale(
                      scale: 1 + .06 * t,
                      child: WorldGlyph(
                        section: section,
                        size: 32,
                        primary: primary,
                        secondary: secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.label,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color.lerp(Vibes.ink, Colors.white, t),
                            height: 1.15,
                          ),
                        ),
                        if (count > 0)
                          Text(
                            _placesCount(count),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color.lerp(
                                Vibes.inkTertiary,
                                Colors.white.withValues(alpha: .82),
                                t,
                              ),
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// مبدّل مصغّر على اللون — كبسولات زجاجية، والمختارة بيضاء.
class _WorldSwitcher extends ConsumerWidget {
  const _WorldSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(homeSectionProvider);
    return Row(
      children: [
        for (final s in HomeSection.values) ...[
          if (s.index > 0) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectWorld(ref, s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                height: 40,
                decoration: BoxDecoration(
                  color: s == current
                      ? Colors.white
                      : Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: s == current ? 1 : .25,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WorldGlyph(
                      section: s,
                      size: 21,
                      primary: s == current
                          ? s.palette.accentDeep
                          : Colors.white,
                      secondary: s == current
                          ? s.palette.accentLight
                          : Colors.white.withValues(alpha: .6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: s == current
                            ? s.palette.accentDeep
                            : Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// الشريط المصغّر — يظهر عند التمرير بلون العالم: مبدّل وبحث.
class _CompactBar extends ConsumerWidget {
  const _CompactBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final current = ref.watch(homeSectionProvider);
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 12),
      decoration: BoxDecoration(
        gradient: _heroGradient(p),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: p.glow.withValues(alpha: .3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(child: _WorldSwitcher()),
          const SizedBox(width: 8),
          _HeroIcon(
            icon: Icons.search_rounded,
            onTap: () => context.push('/search?type=${current.typeFilter}'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الخدمات — كبسولات خفيفة بأيقونة واسم
// ═══════════════════════════════════════════════════════════

class _QuickRail extends ConsumerWidget {
  const _QuickRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final section = ref.watch(homeSectionProvider);
    final offers = ref.watch(offersProvider).valueOrNull?.length ?? 0;
    final coupons = ref.watch(publicCouponsProvider).valueOrNull?.length ?? 0;
    final nadeem = nadeemConfigNow(ref);
    final layout = homeLayoutNow(ref);
    final items = <(IconData, String, String, int)>[
      if (layout.link('map'))
        (Icons.map_rounded, 'الخريطة', '/map?type=${section.typeFilter}', 0),
      if (layout.link('offers'))
        (Icons.local_offer_rounded, 'العروض', '/offers', offers),
      if (layout.link('coupons'))
        (Icons.confirmation_number_rounded, 'الكوبونات', '/coupons', coupons),
      if (nadeem.showOnHome && nadeem.enabled)
        (Icons.auto_awesome_rounded, nadeem.name, '/nadeem', 0),
      if (layout.link('experiences'))
        (Icons.celebration_rounded, 'التجارب', '/experiences', 0),
      if (layout.link('compare'))
        (Icons.compare_arrows_rounded, 'المقارنة', '/compare', 0),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = items[i];
          return PressScale(
            onTap: () => context.push(item.$3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsetsDirectional.fromSTEB(5, 0, 12, 0),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, size: 15, color: p.accentDeep),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Vibes.ink,
                      height: 1.2,
                    ),
                  ),
                  if (item.$4 > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الحجز الجاري — تذكرة ليلية بلون عالم المكان المحجوز
// ═══════════════════════════════════════════════════════════

class _ContinueBookingSection extends ConsumerWidget {
  const _ContinueBookingSection();

  String _when(DateTime start) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.dateOnly(start).difference(today).inDays;
    if (days < 0) return 'جارٍ الآن';
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غداً';
    if (days == 2) return 'بعد يومين';
    if (days <= 10) return 'بعد $days أيام';
    return 'بعد $days يوماً';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final b = active;
        final p = WorldPalette.forType(b.propertyType);
        final needsPayment = b.status == BookingStatus.awaitingPayment;
        final status = switch (b.status) {
          BookingStatus.awaitingPayment => 'بانتظار الدفع',
          BookingStatus.pending => 'بانتظار تأكيد المضيف',
          _ => 'حجز مؤكد',
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: PressScale(
            onTap: () => context.push('/booking/${b.id}'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: p.nightfall,
                borderRadius: BorderRadius.circular(24),
                boxShadow: p.glowShadow,
              ),
              child: Row(
                children: [
                  // كتلة التاريخ
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .18),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${b.startDate.day}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          _arMonthsShort[b.startDate.month - 1],
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: .75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          needsPayment
                              ? 'أكمل الدفع لتأكيد حجزك'
                              : '${_when(b.startDate)} · $status',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: needsPayment
                                ? const Color(0xFFFFC27A)
                                : p.accentLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.propertyName ?? 'حجزك',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        if ((b.cityName ?? '').isNotEmpty)
                          Text(
                            b.cityName!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: .62),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: needsPayment
                          ? const Color(0xFFFFC27A)
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      needsPayment
                          ? Icons.payments_rounded
                          : Icons.chevron_left_rounded,
                      size: 20,
                      color: needsPayment
                          ? const Color(0xFF5A3200)
                          : p.accentDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// مختارات العالم — بطاقات عرض كبرى
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// الوجهات — بطاقات طولية بصور المحافظات
// ═══════════════════════════════════════════════════════════

class _PopularDestinations extends ConsumerWidget {
  const _PopularDestinations({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);
    final properties =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];

    return locations.maybeWhen(
      data: (cities) {
        final unique =
            <String, ({String name, String slug, String? imageUrl})>{};
        for (final city in cities) {
          final slug = city.provinceSlug;
          if (slug != null && slug.isNotEmpty && city.provinceName.isNotEmpty) {
            unique[slug] = (
              name: city.provinceName,
              slug: slug,
              imageUrl: city.provinceImageUrl,
            );
          }
        }
        if (unique.isEmpty) return const SizedBox.shrink();
        int countFor(String name) => properties
            .where((p) => p.provinceName == name && _inWorld(p, section))
            .length;
        final provinces = unique.values.toList()
          ..sort((a, b) => countFor(b.name).compareTo(countFor(a.name)));

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: provinces.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = provinces[i];
                return _DestinationTile(
                  section: section,
                  name: d.name,
                  slug: d.slug,
                  count: countFor(d.name),
                  imageUrl: d.imageUrl,
                );
              },
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.section,
    required this.name,
    required this.slug,
    required this.count,
    this.imageUrl,
  });

  final HomeSection section;
  final String name;
  final String slug;
  final int count;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final p = section.palette;
    return PressScale(
      onTap: () =>
          context.push('/search?province=$slug&type=${section.typeFilter}'),
      child: Container(
        width: 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: p.glow.withValues(alpha: .14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                VibesNetImage(
                  url: imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(gradient: p.nightfall),
                  child: Align(
                    alignment: const Alignment(0, -.35),
                    child: Icon(
                      Icons.location_city_rounded,
                      size: 34,
                      color: p.accentLight.withValues(alpha: .7),
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [.35, 1],
                    colors: [Colors.transparent, p.night.withValues(alpha: .9)],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 10,
                end: 10,
                bottom: 9,
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
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: count > 0
                            ? p.accent
                            : Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 0 ? _placesCount(count) : '—',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: count > 0 ? p.onAccent : Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بنرات الدار — بطاقة نظيفة بنص سفلي وسهم دائري، ونقاط هادئة تحتها.
// ═══════════════════════════════════════════════════════════

class _BannerCarousel extends ConsumerStatefulWidget {
  const _BannerCarousel();

  @override
  ConsumerState<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<_BannerCarousel> {
  final _page = PageController(viewportFraction: .9);
  int _index = 0;
  bool _synced = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
    ref.listenManual<HomeSection>(homeSectionProvider, (_, next) {
      final i = _indexFor(next);
      if (i < 0 || i == _index || !_page.hasClients) return;
      _page.animateToPage(
        i,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _advance());
  }

  int _indexFor(HomeSection s) {
    final banners = ref.read(bannersProvider).valueOrNull ?? const <Banner>[];
    return banners.indexWhere(
      (b) => (b.linkUrl ?? '').contains('type=${s.typeFilter}'),
    );
  }

  void _advance() {
    final count = ref.read(bannersProvider).valueOrNull?.length ?? 0;
    if (!mounted || count < 2 || !_page.hasClients) return;
    if (!TickerMode.valuesOf(context).enabled || !isAppResumed) return;
    _page.animateToPage(
      (_index + 1) % count,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider).valueOrNull ?? const <Banner>[];
    final width = MediaQuery.sizeOf(context).width;
    final height = width * .9 * .52;
    final p = context.world;
    if (banners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: WorldSkeleton(height: height, radius: 26),
      );
    }
    if (!_synced) {
      _synced = true;
      final i = _indexFor(ref.read(homeSectionProvider));
      if (i > 0) {
        _index = i;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_page.hasClients) _page.jumpToPage(i);
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                if (n.dragDetails != null) _restart();
                return false;
              },
              child: PageView.builder(
                controller: _page,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _BannerCard(banner: banners[i], index: i, page: _page),
              ),
            ),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? p.accent : const Color(0xFFDADDE2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.index,
    required this.page,
  });

  final Banner banner;
  final int index;
  final PageController page;

  double _delta() {
    if (!page.hasClients || !page.position.haveDimensions) return 0;
    return ((page.page ?? 0) - index).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final link = banner.linkUrl;
    final tappable =
        link != null && link.startsWith('/') && !link.startsWith('//');

    return AnimatedBuilder(
      animation: page,
      builder: (context, child) =>
          Transform.scale(scale: 1 - _delta().abs() * .05, child: child),
      child: PressScale(
        onTap: tappable ? () => context.push(link) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: page,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_delta() * 44 * (rtl ? -1 : 1), 0),
                  child: Transform.scale(scale: 1.16, child: child),
                ),
                child: VibesNetImage(url: banner.imageUrl, fit: BoxFit.cover),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.38, 1],
                    colors: [Colors.transparent, Color(0xC7000000)],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 20,
                end: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (banner.title.isNotEmpty)
                            Text(
                              banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          if (banner.subtitle.isNotEmpty)
                            Text(
                              banner.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: .82),
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (tappable) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 19,
                          color: Vibes.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// السكك — بطاقة السكة الموحّدة
// ═══════════════════════════════════════════════════════════

const _railCardWidth = 264.0;
const _railImageHeight = 165.0;
const _railHeight = 262.0;

class _RailCard extends StatelessWidget {
  const _RailCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final where = _placeWhere(property);
    return PressScale(
      onTap: () => context.push('/property/${property.id}'),
      child: SizedBox(
        width: _railCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: _railImageHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: WorldPalette.forType(
                      property.type.name,
                    ).glow.withValues(alpha: .14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(property: property),
                    if (property.isNew ||
                        property.isWinter ||
                        property.hasIndoorPool)
                      PositionedDirectional(
                        top: 12,
                        start: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (property.isNew)
                              const _WhitePill(
                                label: 'جديد',
                                icon: Icons.fiber_new_rounded,
                                iconColor: Color(0xFF0E9F6E),
                              ),
                            if (property.isWinter) ...[
                              if (property.isNew) const SizedBox(height: 6),
                              const _WhitePill(
                                label: 'شتوية',
                                icon: Icons.ac_unit_rounded,
                                iconColor: Color(0xFF0284C7),
                              ),
                            ],
                            if (property.hasIndoorPool) ...[
                              if (property.isNew || property.isWinter)
                                const SizedBox(height: 6),
                              const _WhitePill(
                                label: 'مسبح مغلق',
                                icon: Icons.pool_rounded,
                                iconColor: Color(0xFF0D9488),
                              ),
                            ],
                          ],
                        ),
                      ),
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: _FavButton(property: property, size: 36),
                    ),
                    if (property.ratingCount > 0)
                      PositionedDirectional(
                        bottom: 12,
                        start: 12,
                        child: _WhitePill(
                          label:
                              '${property.ratingAvg.toStringAsFixed(1)} (${property.ratingCount})',
                          icon: Icons.star_rounded,
                          iconColor: _starGold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Vibes.ink,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    where.isEmpty ? property.typeLabelAr : where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Vibes.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PriceLine(property: property),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.property});

  final Property property;
  static const size = 15.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatIqdShort(_fromPrice(property)),
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: Vibes.ink,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'د.ع · ${_priceUnit(property)}',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Vibes.inkTertiary,
          ),
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.items});

  final List<Property> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _railHeight,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const _RailSnapPhysics(
          parent: BouncingScrollPhysics(),
          itemExtent: _railCardWidth + 14,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _RailCard(property: items[i]),
      ),
    );
  }
}

class _NewArrivals extends ConsumerWidget {
  const _NewArrivals({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fresh =
        ref.watch(newPropertiesProvider(section.typeFilter)).valueOrNull ??
        const <Property>[];
    if (fresh.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Head(
          section.railTitle,
          subtitle: section.railSubtitle,
          onMore: () => context.push('/search?type=${section.typeFilter}'),
        ),
        _Rail(items: fresh),
      ],
    );
  }
}

/// «مزارع شتوية» — تظهر في عالم المزارع فقط عند وجود مزارع مفعّل لها الخيار.
class _WinterFarmsSection extends ConsumerWidget {
  const _WinterFarmsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    final winter = [
      for (final p in all)
        if (p.type == PropertyType.farm && p.isWinter) p,
    ]..sort((a, b) => (b.hasIndoorPool ? 1 : 0) - (a.hasIndoorPool ? 1 : 0));
    if (winter.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(
            'مزارع شتوية ❄️',
            subtitle: 'دافئة ومجهّزة للشتاء — بعضها بمسبح مغلق',
            onMore: () => context.push('/search?winter=true'),
          ),
          _Rail(items: winter.take(12).toList()),
        ],
      ),
    );
  }
}

class _RecentlyViewedSection extends ConsumerWidget {
  const _RecentlyViewedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentViewedProvider);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Head('شاهدتها مؤخراً', subtitle: 'عُد إلى ما لفت انتباهك'),
        _Rail(items: recent),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// تذكرة الكوبون — حواف مثقوبة وخط متقطع
// ═══════════════════════════════════════════════════════════

class _CouponTicket extends ConsumerWidget {
  const _CouponTicket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(publicCouponsProvider).valueOrNull ?? const [];
    if (coupons.isEmpty) return const SizedBox.shrink();
    final p = context.world;
    final coupon = coupons.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: PressScale(
        onTap: () => context.push('/coupons'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: p.glowShadow,
          ),
          child: ClipPath(
            clipper: const _TicketClipper(cut: .74),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              height: 92,
              decoration: BoxDecoration(gradient: p.nightfall),
              child: CustomPaint(
                painter: _TicketDashPainter(
                  cut: .74,
                  color: Colors.white.withValues(alpha: .28),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 74,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          18,
                          0,
                          12,
                          0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: p.fill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.confirmation_number_rounded,
                                color: p.onAccent,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'خصم فوري بكوبون',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: p.accentLight,
                                    ),
                                  ),
                                  Text(
                                    coupon.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  if (coupon.description.isNotEmpty)
                                    Text(
                                      coupon.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: .7,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 26,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.redeem_rounded,
                            color: Colors.white.withValues(alpha: .9),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coupons.length > 1
                                ? '+${coupons.length - 1} أخرى'
                                : 'استخدمه',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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
      ),
    );
  }
}

/// شكل التذكرة — زوايا ناعمة وثقبان نصف دائريان عند خط القطع.
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.cut});

  /// موضع خط القطع من بداية الاتجاه (0..1).
  final double cut;

  @override
  Path getClip(Size size) {
    const r = 22.0;
    const notch = 11.0;
    final x = size.width * (1 - cut); // في RTL البداية يمين
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)),
      );
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: notch));
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_TicketClipper old) => old.cut != cut;
}

class _TicketDashPainter extends CustomPainter {
  const _TicketDashPainter({required this.cut, required this.color});

  final double cut;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (1 - cut);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    var y = 16.0;
    while (y < size.height - 16) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 5), paint);
      y += 10;
    }
  }

  @override
  bool shouldRepaint(_TicketDashPainter old) =>
      old.cut != cut || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// الأعلى تقييماً — قائمة مرقّمة أنيقة
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// الشريط السينمائي — لقطات تتحرك وحدها وتتوقف عند اللمس
// ═══════════════════════════════════════════════════════════

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

  static const _gap = 12.0;
  static const _speed = 26.0;
  static const _frameWidth = 260.0;
  static const _frameHeight = 168.0;

  @override
  void initState() {
    super.initState();
    _reel = createTicker(_onTick)..start();
  }

  List<HomeSpotlight> _visible(
    List<HomeSpotlight> list,
    HomeSection section,
    List<Property> properties,
  ) {
    final types = {for (final p in properties) p.id: p.type.name.toUpperCase()};
    final filtered = list
        .where((s) => types[s.propertyId] == section.typeFilter)
        .toList();
    return filtered.isNotEmpty ? filtered : list;
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || _hold || !_scroll.hasClients || !isAppResumed)
      return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    var next = _scroll.offset + dt * _speed;
    if (next >= max) next = 0;
    _scroll.jumpTo(next);
  }

  @override
  void dispose() {
    _reel.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(homeSectionProvider);
    final spotlights = ref.watch(spotlightsProvider);
    final properties =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    return spotlights.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final frames = _visible(list, section, properties);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Head(
              'لقطات من أماكننا',
              subtitle: 'المس أي لقطة لزيارة المكان',
            ),
            SizedBox(
              height: _frameHeight,
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
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, i) {
                    final item = frames[i];
                    final caption = item.title.isNotEmpty
                        ? item.title
                        : item.propertyName;
                    return RepaintBoundary(
                      child: PressScale(
                        onTap: () =>
                            context.push('/property/${item.propertyId}'),
                        child: SizedBox(
                          width: _frameWidth,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VibesNetImage(
                                  url: item.imageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 640,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [.4, 1],
                                      colors: [
                                        Colors.transparent,
                                        Color(0xB30E1B2C),
                                      ],
                                    ),
                                  ),
                                ),
                                PositionedDirectional(
                                  bottom: 12,
                                  start: 14,
                                  end: 14,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: .2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.chevron_left_rounded,
                                          size: 18,
                                          color: Colors.white,
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
                    );
                  },
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

// ═══════════════════════════════════════════════════════════
// أتابعهم — حلقات بتدرج العالم
// ═══════════════════════════════════════════════════════════

class _FollowingProvidersStrip extends ConsumerWidget {
  const _FollowingProvidersStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();
    final following = ref.watch(followingProvidersProvider).valueOrNull ?? [];
    if (following.isEmpty) return const SizedBox.shrink();
    final p = context.world;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Head(
          'مضيفون تتابعهم',
          subtitle: 'جديدهم أولاً بأول',
          onMore: () => context.push('/following'),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: following.length.clamp(0, 12),
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final f = following[i];
              final initial = f.displayName.trim().isEmpty
                  ? 'م'
                  : f.displayName.trim().substring(0, 1);
              return PressScale(
                onTap: () => context.push('/providers/${f.id}'),
                child: SizedBox(
                  width: 70,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              p.accent,
                              p.accentLight,
                              p.accentDeep,
                              p.accent,
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: f.avatar != null
                                ? VibesNetImage(
                                    url: f.avatar!,
                                    width: 60,
                                    height: 60,
                                    memCacheWidth: 120,
                                  )
                                : ColoredBox(
                                    color: p.accentFaint,
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: p.accentDeep,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        f.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Vibes.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// كل أماكن العالم — بطاقات عريضة
// ═══════════════════════════════════════════════════════════

class _AllPlacesSection extends ConsumerWidget {
  const _AllPlacesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    final properties = ref.watch(propertiesProvider(null));

    return properties.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorldSkeleton(width: 140, height: 22),
              const SizedBox(height: 16),
              for (var i = 0; i < 2; i++) ...[
                const WorldSkeleton(height: 260, radius: 28),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: ErrorCanvas(
          message: maisonError(e),
          onRetry: () => ref.invalidate(propertiesProvider(null)),
        ),
      ),
      data: (raw) {
        final list = raw.where((p) => _inWorld(p, section)).toList();
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _Head(
                'كل ${section.label}',
                subtitle: list.isEmpty
                    ? null
                    : '${_placesCount(list.length)} بانتظارك',
                onMore: list.isEmpty
                    ? null
                    : () => context.push('/search?type=${section.typeFilter}'),
              ),
            ),
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: WorldEmpty(
                  icon: Icons.explore_outlined,
                  title: 'لا ${section.label} بعد',
                  subtitle:
                      'نضيف أماكن جديدة كل أسبوع — جرّب عالماً آخر أو تصفّح الخريطة',
                  actionLabel: 'افتح الخريطة',
                  onAction: () => context.push('/map'),
                ),
              )
            else
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => RepaintBoundary(
                  child: HomePlaceCard(
                    key: ValueKey(list[i].id),
                    property: list[i],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الخاتمة
// ═══════════════════════════════════════════════════════════

class _HomeFooter extends ConsumerWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: p.accent.withValues(alpha: .2))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: VibesLogo.lockup(height: 92),
              ),
              Expanded(child: Divider(color: p.accent.withValues(alpha: .2))),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'مزارع · قاعات · تزيين — مناسبتك كلها في مكان واحد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Vibes.inkSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'صُنع بحب في العراق',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Vibes.inkTertiary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.favorite_rounded, size: 13, color: p.accent),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// خطّط لمناسبتك — كل مناسبة تجمع العوالم التي تحتاجها
// ═══════════════════════════════════════════════════════════

class _Occasion {
  const _Occasion(this.title, this.icon, this.line, this.worlds);

  final String title;
  final IconData icon;
  final String line;

  /// العوالم بالترتيب الذي تُجهَّز به المناسبة.
  final List<HomeSection> worlds;
}

const _occasions = [
  _Occasion('عرس', Icons.diamond_outlined, 'ليلة العمر من القاعة إلى الكوشة', [
    HomeSection.hall,
    HomeSection.decoration,
  ]),
  _Occasion(
    'خطوبة',
    Icons.volunteer_activism_outlined,
    'بداية الحكاية بأجمل تفاصيلها',
    [HomeSection.hall, HomeSection.decoration],
  ),
  _Occasion('عيد ميلاد', Icons.cake_outlined, 'زينة ومكان يليق بالفرحة', [
    HomeSection.decoration,
    HomeSection.farm,
  ]),
  _Occasion(
    'تجمّع عائلي',
    Icons.family_restroom_rounded,
    'مسبح وجلسات ويوم كامل للعائلة',
    [HomeSection.farm],
  ),
  _Occasion('حفل تخرّج', Icons.school_outlined, 'احتفل بإنجازك مع من تحب', [
    HomeSection.hall,
    HomeSection.decoration,
  ]),
  _Occasion('سهرة', Icons.nightlife_rounded, 'شفت مسائي وأجواء لا تُنسى', [
    HomeSection.farm,
    HomeSection.decoration,
  ]),
];

class _OccasionsSection extends StatelessWidget {
  const _OccasionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Head(
          'خطّط لمناسبتك',
          subtitle: 'اختر المناسبة ونجمع لك كل ما تحتاجه',
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _occasions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _OccasionTile(occasion: _occasions[i]),
          ),
        ),
      ],
    );
  }
}

class _OccasionTile extends StatelessWidget {
  const _OccasionTile({required this.occasion});

  final _Occasion occasion;

  @override
  Widget build(BuildContext context) {
    final p = occasion.worlds.first.palette;
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        _showOccasionSheet(context, occasion);
      },
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          gradient: p.nightfall,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: p.glow.withValues(alpha: .22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // هالة ضوء ونقش كبير خافت
            PositionedDirectional(
              end: -26,
              top: -26,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      p.accentLight.withValues(alpha: .45),
                      p.accentLight.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: -10,
              bottom: -14,
              child: Icon(
                occasion.icon,
                size: 86,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                    child: Icon(occasion.icon, size: 19, color: p.accentLight),
                  ),
                  const Spacer(),
                  Text(
                    occasion.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      for (var i = 0; i < occasion.worlds.length; i++) ...[
                        if (i > 0)
                          Text(
                            ' + ',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: .6),
                            ),
                          ),
                        VibesCategoryIcon(
                          category: occasion.worlds[i].icon,
                          size: 12,
                          color: occasion.worlds[i].palette.accentLight,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          occasion.worlds[i].label,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: .78),
                          ),
                        ),
                      ],
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

/// ورقة المناسبة — خطوات التجهيز، كل خطوة عالم بعدد أماكنه.
Future<void> _showOccasionSheet(BuildContext context, _Occasion occasion) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Theme(
      data: theme,
      child: _OccasionSheet(occasion: occasion),
    ),
  );
}

class _OccasionSheet extends ConsumerWidget {
  const _OccasionSheet({required this.occasion});

  final _Occasion occasion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = occasion.worlds.first.palette;
    final all =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس بليل العالم
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            decoration: BoxDecoration(gradient: p.nightfall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: p.fill,
                        boxShadow: p.glowShadow,
                      ),
                      child: Icon(occasion.icon, color: p.onAccent, size: 25),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'جهّز ${occasion.title}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            occasion.line,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: .75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  occasion.worlds.length > 1
                      ? '${occasion.worlds.length} خطوات بسيطة'
                      : 'خطوة واحدة',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Vibes.inkTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < occasion.worlds.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _OccasionStep(
                    step: i + 1,
                    world: occasion.worlds[i],
                    count: all
                        .where((x) => _inWorld(x, occasion.worlds[i]))
                        .length,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(
                        '/search?type=${occasion.worlds[i].typeFilter}',
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                WorldButton(
                  label: 'ابدأ بـ${occasion.worlds.first.label}',
                  icon: Icons.arrow_back_rounded,
                  palette: p,
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectWorldFromContext(context, occasion.worlds.first);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// يبدّل عالم الرئيسية من خارج شجرة Consumer (من الورقة).
void _selectWorldFromContext(BuildContext context, HomeSection world) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(homeSectionProvider) == world) return;
  worldSwitchHaptic();
  container.read(homeSectionProvider.notifier).state = world;
}

class _OccasionStep extends StatelessWidget {
  const _OccasionStep({
    required this.step,
    required this.world,
    required this.count,
    required this.onTap,
  });

  final int step;
  final HomeSection world;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = world.palette;
    final what = switch (world) {
      HomeSection.hall => 'اختر القاعة',
      HomeSection.farm => 'اختر المزرعة',
      HomeSection.decoration => 'اختر فريق التزيين',
    };
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.canvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.accent.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: VibesCategoryIcon(
                  category: world.icon,
                  size: 22,
                  color: p.accentDeep,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخطوة $step',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: p.accentDeep,
                    ),
                  ),
                  Text(
                    what,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Vibes.ink,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    switch (count) {
                      0 => 'تصفّح الأماكن المتاحة',
                      1 => 'مكان واحد متاح للحجز',
                      2 => 'مكانان متاحان للحجز',
                      _ => '${_placesCount(count)} متاحة للحجز',
                    },
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Vibes.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: p.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: p.onAccent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// لماذا VIBES — شريط الثقة
// ═══════════════════════════════════════════════════════════

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    const items = [
      (
        Icons.verified_user_outlined,
        'مضيفون موثّقون',
        'نراجع كل مكان قبل نشره',
      ),
      (Icons.lock_outline_rounded, 'دفع آمن', 'لا تُخصم أي رسوم قبل التأكيد'),
      (Icons.bolt_rounded, 'تأكيد سريع', 'رد المضيف خلال وقت قصير'),
      (Icons.support_agent_rounded, 'دعم دائم', 'فريقنا معك قبل الحجز وبعده'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Head('لماذا VIBES', subtitle: 'احجز وأنت مطمئن'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: p.accent.withValues(alpha: .12)),
              boxShadow: [
                BoxShadow(
                  color: p.glow.withValues(alpha: .08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var r = 0; r < 2; r++)
                  Row(
                    children: [
                      for (var c = 0; c < 2; c++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: p.accentFaint,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    items[r * 2 + c].$1,
                                    size: 20,
                                    color: p.accentDeep,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        items[r * 2 + c].$2,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Vibes.ink,
                                          height: 1.3,
                                        ),
                                      ),
                                      Text(
                                        items[r * 2 + c].$3,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Vibes.inkSecondary,
                                          height: 1.4,
                                        ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// شريط خلفية بصبغة العالم — يكسر رتابة الصفحة ويمنح القسم حضوراً.
class _Band extends StatelessWidget {
  const _Band({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        padding: const EdgeInsets.only(bottom: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              p.canvasTint.withValues(alpha: .0),
              p.canvasTint,
              p.canvasTint.withValues(alpha: .0),
            ],
            stops: const [0, .5, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// ظهور متتابع عند الفتح — تلاشٍ وصعود خفيف مرة واحدة، يحترم
/// تفضيل تقليل الحركة.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  /// تُعرض حركة الظهور مرة واحدة في الجلسة — الأقسام تُبنى بكسل وتُعاد
  /// إنشاؤها عند الرجوع إليها بالتمرير، فلا نعيد الحركة كل مرة.
  static final _shown = <int>{};

  @override
  void initState() {
    super.initState();
    if (_shown.contains(widget.order)) {
      _c.value = 1;
      return;
    }
    _shown.add(widget.order);
    Future.delayed(Duration(milliseconds: 90 * widget.order), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Perf.animationsOn(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(_t),
        child: widget.child,
      ),
    );
  }
}

/// فيزياء سكك الرئيسية — كل قفزة توقف بطاقة كاملة عند الحافة.
class _RailSnapPhysics extends ScrollPhysics {
  const _RailSnapPhysics({super.parent, required this.itemExtent});

  final double itemExtent;

  @override
  _RailSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _RailSnapPhysics(
      parent: buildParent(ancestor),
      itemExtent: itemExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final pixels = position.pixels;
    if (pixels < position.minScrollExtent ||
        pixels > position.maxScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }
    final lead = velocity.abs() > 90 ? velocity.sign : 0.0;
    double target;
    if (lead == 0) {
      target = (pixels / itemExtent).roundToDouble() * itemExtent;
    } else {
      final page = (pixels / itemExtent).floorToDouble();
      target = (lead > 0 ? page + 1 : page) * itemExtent;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - pixels).abs() < .5) return null;
    return ScrollSpringSimulation(
      spring,
      pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// قسم المحتوى المطابق لمفتاح لوحة التحكم — null للأقسام التي تُبنى خارج القائمة.
Widget? _bodySection(String key) => switch (key) {
  'continueBooking' => const _ContinueBookingSection(),
  'editorsPicks' => const _Reveal(order: 3, child: EditorsPicks()),
  'occasions' => const _OccasionsSection(),
  'newArrivals' => _WorldFade(builder: (s) => _NewArrivals(section: s)),
  'winterFarms' => _WorldFade(
    builder: (s) => s == HomeSection.farm
        ? const _WinterFarmsSection()
        : const SizedBox.shrink(),
  ),
  'coupon' => const _CouponTicket(),
  'topRated' => const _Band(child: TopRatedEditorial()),
  'spotlights' => const _SpotlightStrip(),
  'map' => const Padding(
    padding: EdgeInsets.only(top: 18),
    child: MapPreviewCard(),
  ),
  'recentlyViewed' => const _RecentlyViewedSection(),
  'following' => const _FollowingProvidersStrip(),
  'trust' => const _TrustStrip(),
  _ => null,
};
