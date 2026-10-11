import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/world_theme.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../home/home_sections.dart';

/// ═══════════════════════════════════════════════════════════
/// الترحيب — ثلاث لوحات، لكل عالم سماؤه:
/// السحب بين اللوحات يمزج الألوان لحظياً (لا قفزات)، الصورة داخل
/// قوس معماري بعمق بارالاكس، والزر يقول «ابدأ بالمزارع/القاعات/…»
/// فيفتح التطبيق مباشرة على العالم الذي أعجبك.
/// ═══════════════════════════════════════════════════════════
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide(
    this.world,
    this.image,
    this.kicker,
    this.title,
    this.body,
    this.points,
  );
  final HomeSection world;
  final String image;
  final String kicker;
  final String title;
  final String body;
  final List<(IconData, String)> points;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  static const _slides = [
    _Slide(
      HomeSection.farm,
      'https://images.unsplash.com/photo-1519972064555-542444e71b54?w=1080&q=80',
      'المزارع',
      'يومٌ كامل\nتحت الشمس',
      'مسابح وجلسات عائلية وإطلالات خضراء — احجز شفتك الصباحي أو المسائي في ثوانٍ.',
      [
        (Icons.wb_sunny_outlined, 'صباحي أو مسائي'),
        (Icons.pool_outlined, 'مسابح وألعاب'),
        (Icons.family_restroom_outlined, 'للعائلات'),
      ],
    ),
    _Slide(
      HomeSection.hall,
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1080&q=80',
      'القاعات',
      'ليلة العمر\nتستحق قاعة',
      'قاعات أعراس ومناسبات بجولات 360° وفيديو حقيقي — شاهدها كأنك فيها قبل أن تحجز.',
      [
        (Icons.threesixty_rounded, 'جولات 360°'),
        (Icons.groups_2_outlined, 'سعات كبيرة'),
        (Icons.verified_outlined, 'أسعار واضحة'),
      ],
    ),
    _Slide(
      HomeSection.decoration,
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=1080&q=80',
      'التزيين',
      'تفاصيل\nتصنع الفرح',
      'كوش وورد وإضاءة — فرق تزيين محترفة تحوّل مناسبتك إلى لوحة لا تُنسى.',
      [
        (Icons.local_florist_outlined, 'ورد وكوش'),
        (Icons.light_outlined, 'إضاءة'),
        (Icons.auto_awesome_outlined, 'تصاميم خاصة'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.hasClients) setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  WorldPalette get _palette {
    final i = _page.floor().clamp(0, _slides.length - 1);
    final j = (i + 1).clamp(0, _slides.length - 1);
    return WorldPalette.lerp(
      _slides[i].world.palette,
      _slides[j].world.palette,
      _page - i,
    );
  }

  int get _index => _page.round().clamp(0, _slides.length - 1);

  Future<void> _start(HomeSection world) async {
    HapticFeedback.mediumImpact();
    ref.read(homeSectionProvider.notifier).state = world;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) context.go('/home');
  }

  void _next() {
    HapticFeedback.selectionClick();
    _controller.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final slide = _slides[_index];
    final isLast = _index == _slides.length - 1;
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: p.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── السماء الممزوجة لحظياً ──
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    p.nightHigh,
                    p.night,
                    Color.lerp(p.night, Colors.black, .5)!,
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
            ),
            Positioned(
              top: -size.width * .4,
              left: -size.width * .2,
              child: Container(
                width: size.width * 1.2,
                height: size.width * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      p.accentLight.withValues(alpha: .30),
                      p.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // ── اللوحات ──
            PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              itemBuilder: (context, i) =>
                  _SlideView(slide: _slides[i], offset: _page - i),
            ),
            // ── الرأس: الشعار + تخطٍّ ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    const VibesLogo.mark(size: 30, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text(
                      'VIBEES',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (!isLast)
                      TextButton(
                        onPressed: () => _start(slide.world),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: .8),
                        ),
                        child: const Text('تخطٍّ'),
                      ),
                  ],
                ),
              ),
            ),
            // ── الأسفل: المؤشر والأزرار ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _slides.length; i++)
                            Builder(
                              builder: (context) {
                                final d = (1 - (_page - i).abs()).clamp(
                                  0.0,
                                  1.0,
                                );
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: 8 + 22 * d,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: Color.lerp(
                                      Colors.white.withValues(alpha: .25),
                                      p.accentLight,
                                      d,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _GlowButton(
                              label: 'ابدأ ب${slide.kicker}',
                              palette: p,
                              onTap: () => _start(slide.world),
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(width: 12),
                            _RoundNext(onTap: _next),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'يمكنك التنقّل بين العوالم الثلاثة في أي وقت',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .55),
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
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.offset});

  final _Slide slide;

  /// -1..1 — موضع اللوحة بالنسبة للمركز (للبارالاكس).
  final double offset;

  @override
  Widget build(BuildContext context) {
    final p = slide.world.palette;
    final size = MediaQuery.sizeOf(context);
    final visible = (1 - offset.abs()).clamp(0.0, 1.0);
    final archH = size.height * .44;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الصورة داخل قوس معماري ──
            Transform.translate(
              offset: Offset(offset * 40, 0),
              child: SizedBox(
                height: archH,
                width: double.infinity,
                child: ClipPath(
                  clipper: const _ArchClipper(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.translate(
                        offset: Offset(offset * -90, 0),
                        child: Transform.scale(
                          scale: 1.18,
                          child: CachedNetworkImage(
                            imageUrl: slide.image,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 300),
                            placeholder: (_, __) =>
                                ColoredBox(color: p.nightHigh),
                            errorWidget: (_, __, ___) =>
                                ColoredBox(color: p.nightHigh),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              p.night.withValues(alpha: .55),
                            ],
                            stops: const [.55, 1],
                          ),
                        ),
                      ),
                      // شارة العالم أسفل القوس
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VibesCategoryIcon(
                                category: slide.world.icon,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                slide.kicker,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
            ),
            const SizedBox(height: 26),
            // ── العنوان والنص ──
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 70, 0),
                child: Text(
                  slide.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 110, 0),
                child: Text(
                  slide.body,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.7,
                    color: Colors.white.withValues(alpha: .76),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 150, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (icon, label) in slide.points)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: p.accentLight.withValues(alpha: .35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 15, color: p.accentLight),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );
  }
}

/// قوس معماري — أعلى نصف دائري وجوانب مستقيمة وقاعدة بزوايا ناعمة.
class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper();

  @override
  Path getClip(Size size) {
    final r = size.width / 2;
    const base = 22.0;
    final archTop = r.clamp(0.0, size.height * .6);
    return Path()
      ..moveTo(0, archTop)
      ..arcToPoint(
        Offset(size.width, archTop),
        radius: Radius.elliptical(r, archTop),
      )
      ..lineTo(size.width, size.height - base)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - base,
        size.height,
      )
      ..lineTo(base, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - base)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final WorldPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: palette.fill,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette.glow.withValues(alpha: .5),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: palette.onAccent,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: palette.onAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundNext extends StatelessWidget {
  const _RoundNext({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .1),
          border: Border.all(color: Colors.white.withValues(alpha: .3)),
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
