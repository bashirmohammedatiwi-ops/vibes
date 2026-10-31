import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_glyphs.dart';
import '../home/home_sections.dart';
import 'auth_controller.dart';
import 'onboarding_scenes.dart';

/// ═══════════════════════════════════════════════════════════
/// الترحيب — ثلاث لوحات مرسومة بلا صور، لكل عالم مشهده الحيّ:
/// غروب المزارع، قوس القاعة وثرياها، وكوشة التزيين وبالوناتها.
/// السحب يمزج ألوان العوالم لحظياً وطبقات المشهد تتحرك بعمق،
/// والزر «ابدأ بالمزارع/القاعات/…» يفتح التطبيق على العالم المختار.
/// ═══════════════════════════════════════════════════════════
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide(this.world, this.kicker, this.title, this.body, this.points);
  final HomeSection world;
  final String kicker;
  final String title;
  final String body;
  final List<(IconData, String)> points;
}

Color get _ink => themed(const Color(0xFF0F1B2D), Vibes.ink);
Color get _ink2 => themed(const Color(0xFF5B6576), Vibes.inkSecondary);
Color get _chipLine => themed(const Color(0xFFE6E8EC), Vibes.hairline);
Color get _dotOff => themed(const Color(0xFFDDE0E5), Vibes.hairlineStrong);

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();
  double _page = 0;

  static const _slides = [
    _Slide(
      HomeSection.farm,
      'المزارع', // i18n-ok
      'يومٌ كامل\nتحت الشمس', // i18n-ok
      'مسابح وجلسات عائلية وإطلالات خضراء — احجز شفتك الصباحي أو المسائي في ثوانٍ.', // i18n-ok
      [
        (Icons.wb_sunny_rounded, 'صباحي أو مسائي'), // i18n-ok
        (Icons.pool_rounded, 'مسابح وألعاب'), // i18n-ok
        (Icons.family_restroom_rounded, 'للعائلات'), // i18n-ok
      ],
    ),
    _Slide(
      HomeSection.hall,
      'القاعات', // i18n-ok
      'ليلة العمر\nتستحق قاعة', // i18n-ok
      'قاعات أعراس ومناسبات بجولات 360° وفيديو حقيقي — شاهدها كأنك فيها قبل أن تحجز.', // i18n-ok
      [
        (Icons.threesixty_rounded, 'جولات 360°'), // i18n-ok
        (Icons.groups_2_rounded, 'سعات كبيرة'), // i18n-ok
        (Icons.verified_rounded, 'أسعار واضحة'), // i18n-ok
      ],
    ),
    _Slide(
      HomeSection.decoration,
      'التزيين', // i18n-ok
      'تفاصيل\nتصنع الفرح', // i18n-ok
      'كوش وورد وإضاءة — فرق تزيين محترفة تحوّل مناسبتك إلى لوحة لا تُنسى.', // i18n-ok
      [
        (Icons.local_florist_rounded, 'ورد وكوش'), // i18n-ok
        (Icons.light_rounded, 'إضاءة'), // i18n-ok
        (Icons.auto_awesome_rounded, 'تصاميم خاصة'), // i18n-ok
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
    _clock.dispose();
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
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final slide = _slides[_index];
    final isLast = _index == _slides.length - 1;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (Appearance.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Vibes.canvas,
                systemNavigationBarIconBrightness: Appearance.isDark
                    ? Brightness.light
                    : Brightness.dark,
              ),
      child: Scaffold(
        backgroundColor: Vibes.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── خلفية فاتحة بلمسة لون العالم ──
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.canvasTint, p.canvas, Vibes.canvas],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
            // ── اللوحات ──
            PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              itemBuilder: (context, i) => AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => _SlideView(
                  slide: _slides[i],
                  offset: _page - i,
                  t: reduce ? 0 : _clock.value,
                ),
              ),
            ),
            // ── الرأس: الشعار + تخطٍّ ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 20, 0),
                  child: Row(
                    children: [
                      Appearance.isDark
                          ? VibesLogo.mark(size: 28, color: Vibes.ink)
                          : const VibesLogo.brand(size: 28),
                      const SizedBox(width: 9),
                      Text(
                        I18n.appName,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: I18n.isEn ? 4 : 0,
                          color: _ink,
                        ),
                      ),
                      const Spacer(),
                      // اختيار اللغة من أول شاشة — يعيد تشغيل الواجهة باللغة الأخرى
                      PressScale(
                        onTap: () => ref
                            .read(prefsControllerProvider.notifier)
                            .setLocale(I18n.isEn ? 'ar' : 'en'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Vibes.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _chipLine),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language_rounded,
                                size: 15,
                                color: _ink2,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                I18n.isEn ? 'العربية' : 'English', // i18n-ok
                                style: TextStyle(
                                  fontFamily: I18n.isEn
                                      ? 'Cairo'
                                      : 'Montserrat',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _ink2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: isLast ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: isLast,
                          child: PressScale(
                            onTap: () => _start(slide.world),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Vibes.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _chipLine),
                              ),
                              child: Text(
                                'تخطٍّ'.tr,
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _ink2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _slides.length; i++)
                            Builder(
                              builder: (context) {
                                final d = (1 - (_page - i).abs()).clamp(
                                  0.0,
                                  1.0,
                                );
                                return Container(
                                  margin: const EdgeInsetsDirectional.only(
                                    end: 6,
                                  ),
                                  width: 8 + 22 * d,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: d > .05
                                        ? LinearGradient(
                                            colors: [
                                              Color.lerp(_dotOff, p.accent, d)!,
                                              Color.lerp(
                                                _dotOff,
                                                p.accentDeep,
                                                d,
                                              )!,
                                            ],
                                          )
                                        : null,
                                    color: _dotOff,
                                  ),
                                );
                              },
                            ),
                          const Spacer(),
                          Text(
                            '${_index + 1} / ${_slides.length}',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _ink2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _GlowButton(
                              label: 'ابدأ ب{world}'.trArgs({
                                'world': slide.kicker.tr,
                              }),
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
                        'يمكنك التنقّل بين العوالم الثلاثة في أي وقت'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _ink2,
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
  const _SlideView({
    required this.slide,
    required this.offset,
    required this.t,
  });

  final _Slide slide;

  /// -1..1 — موضع اللوحة بالنسبة للمركز (للبارالاكس).
  final double offset;

  /// زمن حلقي لحركة المشهد.
  final double t;

  @override
  Widget build(BuildContext context) {
    final p = slide.world.palette;
    final size = MediaQuery.sizeOf(context);
    // البارالاكس يتبع اتجاه السحب: اللوحات تتقدم عكس العربية في الإنجليزية
    final offset = I18n.isEn ? -this.offset : this.offset;
    final visible = (1 - offset.abs()).clamp(0.0, 1.0);
    final sceneH = (size.height * .4).clamp(240.0, 380.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 62, 20, 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── المشهد المرسوم ── يتقلّص ليتسع النص على كل الشاشات
            Flexible(
              child: Transform.translate(
                offset: Offset(offset * 30, 0),
                child: Transform.scale(
                  scale: 1 - .06 * offset.abs(),
                  child: Container(
                    height: sceneH,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: p.glow.withValues(alpha: .28),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: onboardingScene(slide.world, t, offset),
                          ),
                        ),
                        // إطار داخلي رفيع يمنح المشهد طابع اللوحة
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .45),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ── شارة العالم ──
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 50, 0),
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 12, 5),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Vibes.surface,
                          shape: BoxShape.circle,
                        ),
                        child: WorldGlyph(
                          section: slide.world,
                          size: 20,
                          primary: p.accentDeep,
                          secondary: p.accent,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        slide.kicker.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: p.accentDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 80, 0),
                child: Text(
                  slide.title.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: _ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 110, 0),
                child: Text(
                  slide.body.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                    color: _ink2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: visible,
              child: Transform.translate(
                offset: Offset(offset * 140, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (icon, label) in slide.points)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Vibes.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themed(
                              const Color(0xFFEDEEF1),
                              Vibes.hairline,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 15, color: p.accentDeep),
                            const SizedBox(width: 6),
                            Text(
                              label.tr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _ink,
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: palette.onAccent,
                ),
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
          color: Vibes.surface,
          border: Border.all(color: _chipLine),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.arrow_forward_rounded, color: _ink, size: 24),
      ),
    );
  }
}
