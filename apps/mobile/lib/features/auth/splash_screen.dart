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
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_map.dart';
import 'auth_controller.dart';

/// ═══════════════════════════════════════════════════════════
/// الافتتاحية — مشهد سينمائي واحد مدته ~2.4 ثانية:
///   ١. الليل يتنفس، وحلقة ضوء ترسم نفسها حول الشعار.
///   ٢. الشعار يولد من الضوء، واسم الدار يتكشّف حرفاً حرفاً.
///   ٣. السماء تعبر العوالم الثلاثة: نحاس المزارع ← ياقوت القاعات
///      ← ورديّ التزيين، وكل عالم يضيء أيقونته أثناء عبوره.
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

  /// لوحة السماء عبر الزمن: مزرعة → قاعة → تزيين.
  WorldPalette _sky(double t) {
    // الثلث الأول ثابت على النحاس ثم عبور متصل
    final s = ((t - .30) / .70).clamp(0.0, 1.0);
    if (s < .5) {
      return WorldPalette.lerp(
        WorldPalette.farm,
        WorldPalette.hall,
        Curves.easeInOut.transform(s * 2),
      );
    }
    return WorldPalette.lerp(
      WorldPalette.hall,
      WorldPalette.decoration,
      Curves.easeInOut.transform((s - .5) * 2),
    );
  }

  /// أي عالم يضيء الآن.
  int _activeWorld(double t) {
    final s = ((t - .30) / .70).clamp(0.0, 1.0);
    if (s < .30) return 0;
    if (s < .72) return 1;
    return 2;
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
      value: overlayFor(darkBackground: true),
      child: Scaffold(
        backgroundColor: WorldPalette.farm.night,
        body: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final t = reduce ? 1.0 : _t.value;
            final sky = _sky(t);
            final ring = _interval(t, 0, .38);
            final logo = _interval(t, .10, .42, Curves.easeOutBack);
            final wordmark = _interval(t, .28, .60);
            final tagline = _interval(t, .40, .70);
            final worlds = _interval(t, .45, .80);
            final active = _activeWorld(t);

            return Stack(
              fit: StackFit.expand,
              children: [
                const MapWarmup(),
                // ── السماء ──
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sky.nightHigh,
                        sky.night,
                        Color.lerp(sky.night, Colors.black, .45)!,
                      ],
                      stops: const [0, .55, 1],
                    ),
                  ),
                ),
                // ── هالة ضوء خلف الشعار ──
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HaloPainter(
                      color: sky.accentLight,
                      t: t,
                      strength: ring,
                    ),
                  ),
                ),
                // ── نجوم/غبار ضوئي خافت ──
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DustPainter(t: t, color: sky.accentLight),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      // ── الشعار داخل حلقة الضوء ──
                      SizedBox(
                        width: 196,
                        height: 196,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size.square(196),
                              painter: _RingPainter(
                                progress: ring,
                                color: sky.accentLight,
                                spin: t,
                              ),
                            ),
                            Opacity(
                              opacity: logo.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: .7 + .3 * logo,
                                child: const VibesLogo.mark(
                                  size: 84,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 34),
                      // ── اسم الدار يتكشّف حرفاً حرفاً ──
                      _Wordmark(progress: wordmark, color: sky.accentLight),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: tagline,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - tagline)),
                          child: Text(
                            'مزارع · قاعات · تزيين — بلمسة واحدة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .4,
                              color: Colors.white.withValues(alpha: .72),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      // ── العوالم الثلاثة ──
                      Opacity(
                        opacity: worlds,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - worlds)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final s in HomeSection.values) ...[
                                if (s.index > 0)
                                  Container(
                                    width: 22,
                                    height: 1,
                                    color: Colors.white.withValues(alpha: .18),
                                  ),
                                _WorldBead(section: s, lit: s.index == active),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // ── شريط تقدّم شعري ──
                      SizedBox(
                        width: 120,
                        height: 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              Container(
                                color: Colors.white.withValues(alpha: .10),
                              ),
                              FractionallySizedBox(
                                widthFactor: t,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [sky.accent, sky.accentLight],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
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

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _letters = 'VIBEES';

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
                    offset: Offset(0, 14 * (1 - e)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5),
                      child: Text(
                        _letters[i],
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 34,
                          fontWeight: FontWeight.w300,
                          height: 1,
                          color: Color.lerp(Colors.white, color, .35),
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

class _WorldBead extends StatelessWidget {
  const _WorldBead({required this.section, required this.lit});

  final HomeSection section;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final p = section.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: lit ? 16 : 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: lit
            ? p.accent.withValues(alpha: .28)
            : Colors.white.withValues(alpha: .05),
        border: Border.all(
          color: lit
              ? p.accentLight.withValues(alpha: .9)
              : Colors.white.withValues(alpha: .14),
        ),
        boxShadow: lit
            ? [BoxShadow(color: p.glow.withValues(alpha: .5), blurRadius: 22)]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VibesCategoryIcon(
            category: section.icon,
            size: 16,
            color: lit ? Colors.white : Colors.white.withValues(alpha: .55),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: lit
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: 7),
                    child: Text(
                      section.label,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// حلقة ضوء ترسم نفسها ثم تدور ببطء، بذيل متلاشٍ.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.spin,
  });

  final double progress;
  final Color color;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // الحلقة الأساسية الخافتة
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .08 * progress),
    );

    // قوس الضوء المتحرك
    final sweep = math.pi * 2 * progress * .82;
    final start = -math.pi / 2 + spin * math.pi * 1.2;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + math.max(sweep, .001),
          colors: [color.withValues(alpha: 0), color.withValues(alpha: .95)],
          transform: GradientRotation(0),
        ).createShader(rect),
    );

    // رأس القوس — نقطة ضوء
    if (progress > .05) {
      final a = start + sweep;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      canvas.drawCircle(p, 3, Paint()..color = color);
      canvas.drawCircle(
        p,
        10,
        Paint()
          ..color = color.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.spin != spin;
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.color, required this.t, required this.strength});

  final Color color;
  final double t;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .40);
    final r = size.width * (.75 + .05 * math.sin(t * math.pi * 2));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .22 * strength),
            color.withValues(alpha: .06 * strength),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.color != color || old.t != t || old.strength != strength;
}

/// غبار ضوئي — نقاط ثابتة المواقع تومض بأطوار مختلفة.
class _DustPainter extends CustomPainter {
  _DustPainter({required this.t, required this.color});

  final double t;
  final Color color;

  static final _points = List.generate(36, (i) {
    final r = math.Random(i * 7919 + 13);
    return (
      r.nextDouble(),
      r.nextDouble(),
      r.nextDouble(),
      .6 + r.nextDouble() * 1.2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, phase, radius) in _points) {
      final tw = (math.sin((t * 2 + phase) * math.pi * 2) + 1) / 2;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            color,
            .5,
          )!.withValues(alpha: .08 + tw * .22),
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t || old.color != color;
}
