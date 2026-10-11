import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_mode/app_mode_controller.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/data_warmup.dart';
import '../../features/home/home_sections.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_map.dart';
import '../../shared/widgets/world_glyphs.dart';
import 'auth_controller.dart';

/// ═══════════════════════════════════════════════════════════
/// الافتتاحية — مشهد عاجيّ أنيق مدته ~2.4 ثانية:
///   ١. حلقات ذهبية دقيقة تتفتح، ووهج العوالم الثلاثة يسبح بهدوء.
///   ٢. الشعار يولد بلمعة ذهبية عابرة، واسم VIBES يتكشّف حرفاً حرفاً.
///   ٣. أيقونات المزارع والقاعات والتزيين تدخل مداراً حول الشعار.
/// البيانات تُسخَّن بالتوازي فتفتح الرئيسية بلا انتظار.
/// ═══════════════════════════════════════════════════════════
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DataWarmup.warm(ref);
    });
    _route();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 2450));
    if (!mounted) return;

    var auth = ref.read(authControllerProvider);
    var waited = 0;
    while (!auth.ready && waited < 2500) {
      await Future.delayed(const Duration(milliseconds: 120));
      waited += 120;
      if (!mounted) return;
      auth = ref.read(authControllerProvider);
    }

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;
    if (!mounted) return;
    // العودة إلى آخر عالم تصفّحه المستخدم
    final last = prefs.getString('last_world');
    for (final s in HomeSection.values) {
      if (s.name == last) ref.read(homeSectionProvider.notifier).state = s;
    }

    final state = ref.read(authControllerProvider);
    if (!state.loggedIn) {
      context.go(onboarded ? '/home' : '/onboarding');
    } else if (state.isProvider) {
      await ref.read(appModeProvider.notifier).ensureLoaded();
      if (!mounted) return;
      final mode = ref.read(appModeProvider);
      context.go(mode == AppExperienceMode.guest ? '/home' : '/provider');
    } else {
      context.go('/home');
    }
    // أداة تطوير فقط: --dart-define=DEV_ROUTE=/property/<id> تفتح شاشة مباشرة
    const devRoute = String.fromEnvironment('DEV_ROUTE');
    if (devRoute.isNotEmpty && mounted) context.push(devRoute);
    // أداة تطوير فقط: --dart-define=DEV_TOUR=/a,/b يفتح الشاشات تباعاً للمراجعة
    const devTour = String.fromEnvironment('DEV_TOUR');
    if (devTour.isNotEmpty) {
      final router = GoRouter.of(context);
      for (final route in devTour.split(',')) {
        await Future<void>.delayed(const Duration(seconds: 7));
        router.push(route);
        await Future<void>.delayed(const Duration(seconds: 7));
        if (router.canPop()) router.pop();
      }
    }
  }

  double _interval(
    double t,
    double a,
    double b, [
    Curve curve = Curves.easeOutCubic,
  ]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _ivory,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _ivory,
        body: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final t = reduce ? 1.0 : _t.value;
            final rings = _interval(t, 0, .55);
            final logo = _interval(t, .06, .40, Curves.easeOutBack);
            final shine = _interval(t, .30, .75, Curves.easeInOut);
            final orbit = _interval(t, .28, .70);
            final wordmark = _interval(t, .36, .70);
            final tagline = _interval(t, .52, .82);

            return Stack(
              fit: StackFit.expand,
              children: [
                const MapWarmup(),
                // ── وهج العوالم الثلاثة يسبح بهدوء ──
                Positioned.fill(child: CustomPaint(painter: _AuroraPainter(t))),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // حلقات ذهبية دقيقة تتفتح للخارج
                            CustomPaint(
                              size: const Size.square(260),
                              painter: _GuillochePainter(
                                progress: rings,
                                spin: t,
                              ),
                            ),
                            // العوالم في مدار حول الشعار
                            for (final s in HomeSection.values)
                              _OrbitGlyph(
                                section: s,
                                t: t,
                                appear: ((orbit - s.index * .18) / .64).clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),
                            // الشعار مع لمعة ذهبية عابرة
                            Opacity(
                              opacity: logo.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: .78 + .22 * logo,
                                child: ShaderMask(
                                  blendMode: BlendMode.srcATop,
                                  shaderCallback: (r) => LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.transparent,
                                      _gold.withValues(alpha: .85),
                                      Colors.transparent,
                                    ],
                                    stops: [
                                      (shine * 1.6 - .5).clamp(0.0, 1.0),
                                      (shine * 1.6 - .3).clamp(0.0, 1.0),
                                      (shine * 1.6 - .1).clamp(0.0, 1.0),
                                    ],
                                  ).createShader(r),
                                  child: const VibesLogo.brand(size: 92),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      _Wordmark(progress: wordmark),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: tagline,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - tagline)),
                          child: const Text(
                            'مناسبتك تبدأ من هنا',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5B6576),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      Opacity(
                        opacity: tagline,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final s in HomeSection.values) ...[
                              if (s.index > 0)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: _gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                s.label,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: s.palette.accentDeep,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ── خيط تقدّم ذهبي ──
                      SizedBox(
                        width: 120,
                        height: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              Container(color: const Color(0xFFEFE7D8)),
                              FractionallySizedBox(
                                widthFactor: t,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_gold, Color(0xFF8D6324)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
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

const _ivory = Color(0xFFFFFDF9);
const _gold = Color(0xFFC89844);
const _navy = Color(0xFF1B3857);

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.progress});

  final double progress;

  static const _letters = 'VIBES';

  @override
  Widget build(BuildContext context) {
    final n = _letters.length;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            Builder(
              builder: (context) {
                final start = i / (n + 2);
                final local = ((progress - start) / (3 / (n + 2))).clamp(
                  0.0,
                  1.0,
                );
                final e = Curves.easeOutCubic.transform(local);
                return Opacity(
                  opacity: e,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - e)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Text(
                        _letters[i],
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          height: 1,
                          color: _navy,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// أيقونة عالم في دائرة بيضاء تدور ببطء على مدار الشعار.
class _OrbitGlyph extends StatelessWidget {
  const _OrbitGlyph({
    required this.section,
    required this.t,
    required this.appear,
  });

  final HomeSection section;
  final double t;
  final double appear;

  @override
  Widget build(BuildContext context) {
    final p = section.palette;
    final e = Curves.easeOutBack.transform(appear);
    final angle =
        -math.pi / 2 + section.index * math.pi * 2 / 3 + t * math.pi * .35;
    final r = 104 + 14 * (1 - appear);
    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
      child: Opacity(
        opacity: appear,
        child: Transform.scale(
          scale: .6 + .4 * e,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: p.accent.withValues(alpha: .25)),
              boxShadow: [
                BoxShadow(
                  color: p.glow.withValues(alpha: .25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: WorldGlyph(
              section: section,
              size: 30,
              primary: p.accentDeep,
              secondary: p.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// حلقات متحدة المركز رفيعة (طابع النقش الفاخر) تتفتح وتدور ببطء.
class _GuillochePainter extends CustomPainter {
  _GuillochePainter({required this.progress, required this.spin});

  final double progress;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 5; i++) {
      final f = ((progress - i * .12) / .5).clamp(0.0, 1.0);
      if (f <= 0) continue;
      final r = maxR * (.44 + i * .13) * (.85 + .15 * f);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 2 ? 1.1 : .7
        ..color = _gold.withValues(alpha: (.30 - i * .045) * f);
      if (i.isOdd) {
        // حلقة منقّطة تدور
        final dots = 48 + i * 12;
        for (var k = 0; k < dots; k++) {
          final a = k / dots * math.pi * 2 + spin * (i == 1 ? .8 : -.6);
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * r,
            .9,
            Paint()..color = paint.color,
          );
        }
      } else {
        final sweep = math.pi * 2 * f;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2 + spin * .5,
          sweep,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GuillochePainter old) =>
      old.progress != progress || old.spin != spin;
}

/// وهج ناعم بألوان العوالم الثلاثة يتحرك ببطء على العاج.
class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final blobs = [
      (
        Offset(w * (.15 + .05 * math.sin(t * 4)), h * .22),
        WorldPalette.farm.accent,
      ),
      (
        Offset(w * (.88 - .05 * math.cos(t * 3)), h * .42),
        WorldPalette.hall.accent,
      ),
      (
        Offset(w * (.3 + .06 * math.sin(t * 3 + 1)), h * .8),
        WorldPalette.decoration.accent,
      ),
    ];
    for (final (c, color) in blobs) {
      final r = w * .7;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .13), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
