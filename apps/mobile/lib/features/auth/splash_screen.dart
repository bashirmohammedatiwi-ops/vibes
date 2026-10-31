import 'dart:async';
import '../../core/theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_mode/app_mode_controller.dart';
import '../../core/utils/data_warmup.dart';
import '../../features/home/home_sections.dart';
import '../../shared/widgets/vibes_map.dart';
import 'auth_controller.dart';
import 'vibes_logo_geometry.dart';

/// ═══════════════════════════════════════════════════════════
/// الافتتاحية — «لوغو مورف» مسطّح على خلفية بيضاء (~2.8 ثانية):
///   ١. ثلاث نقاط بألوان العوالم (مزارع ذهبي، قاعات أزرق، تزيين وردي) تقفز
///      بالتتابع ثم تلتفّ وتندمج في نقطة كحلية واحدة — العوالم الثلاثة في VIBES.
///   ٢. تتحوّل (Morph) إلى هيئة الدبوس الخارجية وتتمدد للأسفل كقطرة.
///   ٣. ينفتح الفراغ الداخلي فيكتمل شريط الشعار الرسمي تماماً.
///   ٤. استقرار نابضي (ميل وانضغاط خفيفان)، ثم يرتفع الشعار.
///   ٥. حروف VIBES الأصلية تصعد من خلف قناع حرفاً حرفاً، ثم الشعار الفرعي.
/// الشكل مأخوذ من الشعار الرسمي حرفياً (vibes_logo_geometry.dart).
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
    duration: const Duration(milliseconds: 3900),
  )..forward();

  bool _sealed = false;

  @override
  void initState() {
    super.initState();
    _t.addListener(() {
      // لمسة اهتزاز لحظة اكتمال الشعار
      if (!_sealed && _t.value >= _T.complete) {
        _sealed = true;
        HapticFeedback.lightImpact();
      }
    });
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
    // ننتظر اكتمال المشهد نفسه (لا مؤقتاً مستقلاً) — على أي جهاز وأي سرعة
    final done = Completer<void>();
    if (_t.isCompleted) {
      done.complete();
    } else {
      _t.addStatusListener((s) {
        if (s == AnimationStatus.completed && !done.isCompleted) {
          done.complete();
        }
      });
    }
    await Future.any([
      done.future,
      Future<void>.delayed(const Duration(milliseconds: 6000)),
    ]);
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

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final w = (size.width * .30).clamp(104.0, 150.0);
            final h = w * kLogoAspect;
            return AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = reduce ? 1.0 : _t.value;
                final rise = _T.ease(t, .74, .87, Curves.easeInOutCubic);
                final exit = _T.ease(t, .975, 1, Curves.easeIn);
                final cy = size.height * .45 - h * .34 * rise;
                final wordW = w * 1.36;
                final wordTop = size.height * .45 - h * .34 + h / 2 + h * .22;

                return Opacity(
                  opacity: 1 - exit,
                  child: Transform.scale(
                    // دفع كاميرا بطيء طوال المشهد + خروج ناعم
                    scale: 1 + .025 * t + .03 * exit,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const MapWarmup(),
                        Positioned(
                          left: size.width / 2 - w,
                          top: cy - h,
                          width: w * 2,
                          height: h * 2,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _MorphPainter(t: t, w: w, h: h),
                            ),
                          ),
                        ),
                        Positioned(
                          top: wordTop,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              _Wordmark(t: t, width: wordW),
                              SizedBox(height: h * .17),
                              _Tagline(t: t),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

const _navy = Color(0xFF1B3857);

/// المحور الزمني 0→1.
abstract final class _T {
  static const complete = .66;

  static double raw(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  static double ease(
    double t,
    double a,
    double b, [
    Curve curve = Curves.easeOutCubic,
  ]) => curve.transform(raw(t, a, b));
}

/// منحنى نابضي ناعم (تجاوز بسيط ثم استقرار).
const _spring = Cubic(.34, 1.45, .64, 1);
const _springSoft = Cubic(.3, 1.22, .6, 1);

// ═══════════════════════════════════════════════════════════
// تحويل الأشكال: نقطة → دبوس → الشعار الكامل
// ═══════════════════════════════════════════════════════════

/// يعيد أخذ عيّنات من مضلّع مغلق بعدد ثابت من النقاط على طوله.
List<Offset> _resample(List<double> flat, int n) {
  final pts = [
    for (var i = 0; i + 1 < flat.length; i += 2) Offset(flat[i], flat[i + 1]),
  ];
  final seg = <double>[];
  var total = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final d = (pts[(i + 1) % pts.length] - pts[i]).distance;
    seg.add(d);
    total += d;
  }
  final out = <Offset>[];
  var i = 0;
  var acc = 0.0;
  for (var k = 0; k < n; k++) {
    final target = total * k / n;
    while (acc + seg[i] < target && i < pts.length - 1) {
      acc += seg[i];
      i++;
    }
    final f = seg[i] == 0 ? 0.0 : (target - acc) / seg[i];
    out.add(Offset.lerp(pts[i], pts[(i + 1) % pts.length], f)!);
  }
  return out;
}

double _signedArea(List<Offset> p) {
  var a = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[(i + 1) % p.length];
    a += p[i].dx * q.dy - q.dx * p[i].dy;
  }
  return a / 2;
}

Offset _centroid(List<Offset> p) =>
    p.fold(Offset.zero, (s, e) => s + e) / p.length.toDouble();

/// دائرة بنفس عدد النقاط واتجاه الدوران ونقطة البداية — ليتحوّل الشكل بسلاسة.
List<Offset> _circleLike(List<Offset> shape, Offset c, double r) {
  final dir = _signedArea(shape) >= 0 ? 1.0 : -1.0;
  final a0 = math.atan2(shape.first.dy - c.dy, shape.first.dx - c.dx);
  return [
    for (var k = 0; k < shape.length; k++)
      c +
          Offset(
                math.cos(a0 + dir * 2 * math.pi * k / shape.length),
                math.sin(a0 + dir * 2 * math.pi * k / shape.length),
              ) *
              r,
  ];
}

class _Shapes {
  _Shapes()
    : outer = _resample(kLogoOuter, 220),
      inner = _resample(kLogoInner, 220) {
    head = const Offset(.5, .36);
    innerC = _centroid(inner);
    // نسبة العرض للارتفاع: الإحداثيات مطبّعة (x على العرض، y على الارتفاع)
    outerStart = _circleLike(
      [for (final p in outer) Offset(p.dx, p.dy * kLogoAspect)],
      Offset(head.dx, head.dy * kLogoAspect),
      .17,
    ).map((p) => Offset(p.dx, p.dy / kLogoAspect)).toList();
    innerStart = _circleLike(
      [for (final p in inner) Offset(p.dx, p.dy * kLogoAspect)],
      Offset(innerC.dx, innerC.dy * kLogoAspect),
      .004,
    ).map((p) => Offset(p.dx, p.dy / kLogoAspect)).toList();
  }

  final List<Offset> outer;
  final List<Offset> inner;
  late final Offset head;
  late final Offset innerC;
  late final List<Offset> outerStart;
  late final List<Offset> innerStart;

  static final instance = _Shapes();
}

const _worldColors = [Color(0xFFC89844), Color(0xFF315879), Color(0xFFED5477)];

class _MorphPainter extends CustomPainter {
  _MorphPainter({required this.t, required this.w, required this.h});

  final double t;
  final double w;
  final double h;

  static ui.PathMetric? _ribbon;
  static Rect? _ribbonFor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = _Shapes.instance;
    final o = Offset((size.width - w) / 2, (size.height - h) / 2);
    Offset map(Offset p) => o + Offset(p.dx * w, p.dy * h);
    final head = map(s.head);

    _ripples(canvas, head);
    _confetti(canvas, head);
    _worldDots(canvas, head, size);

    // ١. النقطة الكحلية تولد من اندماج العوالم
    final pop = _T.ease(t, .325, .42, _spring);
    if (pop <= 0) return;
    // تحضير (Anticipation): انضغاط قبل التمدد
    final antic = math.sin(_T.raw(t, .40, .46) * math.pi);
    // ٢. تحوّل إلى الدبوس
    final morph = _T.ease(t, .43, .58, Curves.easeInOutCubic);
    // ٣. انفتاح الفراغ الداخلي
    final open = _T.ease(t, .53, .68, _springSoft);
    // ٤. استقرار نابضي متخامد
    final settle = _T.raw(t, .62, .88);
    final wobble = settle > 0
        ? math.sin(settle * math.pi * 3) * math.pow(1 - settle, 2)
        : 0.0;

    final stretch = math.sin(morph * math.pi) * .09;
    final squash = wobble * .05;

    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(-wobble * .09);
    canvas.scale(
      pop * (1 - stretch * .6 + squash + antic * .14),
      pop * (1 + stretch - squash - antic * .16),
    );
    canvas.translate(-head.dx, -head.dy);

    final path = Path()..fillType = PathFillType.evenOdd;
    path.addPolygon([
      for (var i = 0; i < s.outer.length; i++)
        map(Offset.lerp(s.outerStart[i], s.outer[i], morph)!),
    ], true);
    if (open > 0) {
      path.addPolygon([
        for (var i = 0; i < s.inner.length; i++)
          map(Offset.lerp(s.innerStart[i], s.inner[i], open)!),
      ], true);
    }

    // ظل ناعم يكبر كأن الشعار يستقر على سطح
    final lift = _T.ease(t, .55, .85);
    if (lift > 0) {
      canvas.drawPath(
        path.shift(Offset(0, 4 + 6 * lift)),
        Paint()
          ..color = _navy.withValues(alpha: .12 * lift)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawPath(path, Paint()..color = _navy);

    // ٥. خط ضوء يجري على مسار الشريط الحقيقي — توقيع الاكتمال
    final trace = _T.raw(t, .66, .84);
    if (trace > 0 && trace < 1 && open >= .98) {
      final rib = _ribbonPath(map, o);
      final e = Curves.easeInOutCubic.transform(trace) * 1.28;
      final headLen = rib.length * e.clamp(0.0, 1.0);
      final tailLen = rib.length * (e - .26).clamp(0.0, 1.0);
      if (headLen > tailLen) {
        canvas.save();
        canvas.clipPath(path);
        canvas.drawPath(
          rib.extractPath(tailLen, headLen),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * .05
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..shader = ui.Gradient.linear(
              rib.getTangentForOffset(tailLen)!.position,
              rib.getTangentForOffset(headLen)!.position,
              [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .95),
              ],
            ),
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  ui.PathMetric _ribbonPath(Offset Function(Offset) map, Offset o) {
    final key = Rect.fromLTWH(o.dx, o.dy, w, h);
    if (_ribbon == null || _ribbonFor != key) {
      final pts = [
        for (var i = 0; i + 1 < kLogoRibbonMain.length; i += 2)
          map(Offset(kLogoRibbonMain[i], kLogoRibbonMain[i + 1])),
      ];
      _ribbon = (Path()..addPolygon(pts, false)).computeMetrics().first;
      _ribbonFor = key;
    }
    return _ribbon!;
  }

  /// موضع نقطة العالم i عند زمن x (لرسم النقطة وذيلها).
  (Offset, double)? _dotAt(int i, double x, Offset head, Size size) {
    final fall0 = i * .035;
    if (x < fall0) return null;
    final dx = (i - 1) * w * .72;
    var y = 0.0;
    // سقوط بجاذبية ثم ارتداد صغير
    final f = _T.raw(x, fall0, fall0 + .10);
    if (f < 1) {
      final top = -(size.height * .5);
      y = top * (1 - f * f);
    } else {
      final b = _T.raw(x, fall0 + .10, fall0 + .15);
      y = -w * .16 * 4 * b * (1 - b);
    }
    // قفزة الموجة بالتتابع
    final hop = _T.raw(x, .17 + i * .025, .23 + i * .025);
    y -= w * .22 * math.sin(hop * math.pi);
    // التفاف حلزوني نحو المركز
    final conv = _T.ease(x, .245, .34, Curves.easeInCubic);
    final a = conv * math.pi * 1.1;
    final base = Offset(dx, y);
    final rot = Offset(
      base.dx * math.cos(a) - base.dy * math.sin(a),
      base.dx * math.sin(a) + base.dy * math.cos(a),
    );
    return (head + rot * (1 - conv), conv);
  }

  void _worldDots(Canvas canvas, Offset head, Size size) {
    if (t >= .345) return;
    final r = w * .11;
    for (var i = 0; i < 3; i++) {
      final now = _dotAt(i, t, head, size);
      if (now == null) continue;
      final (pos, conv) = now;
      final color = Color.lerp(_worldColors[i], _navy, conv)!;
      // ذيل حركة أثناء الالتفاف
      if (conv > 0) {
        for (var j = 5; j >= 1; j--) {
          final past = _dotAt(i, t - j * .012, head, size);
          if (past == null) continue;
          canvas.drawCircle(
            past.$1,
            r * (1 - .45 * past.$2) * (1 - j * .12),
            Paint()..color = color.withValues(alpha: .22 * (1 - j / 6)),
          );
        }
      }
      // انضغاط عند الارتطام بالأرض
      final land = i * .035 + .10;
      final d = (t - land) / .012;
      final k = math.exp(-d * d);
      final fall = _T.raw(t, i * .035, land);
      final stretchY = fall < 1 ? 1 + .25 * fall : 1.0;
      canvas.save();
      canvas.translate(pos.dx, pos.dy + r * .35 * k);
      canvas.scale(
        (1 + .45 * k) * (fall < 1 ? 1 - .1 * fall : 1),
        (1 - .38 * k) * stretchY,
      );
      canvas.drawCircle(
        Offset.zero,
        r * (1 - .45 * conv),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  /// حلقتا تموّج عند الاندماج.
  void _ripples(Canvas canvas, Offset head) {
    for (final (a, b) in const [(.34, .58), (.375, .64)]) {
      final q = _T.raw(t, a, b);
      if (q <= 0 || q >= 1) continue;
      final e = Curves.easeOutCubic.transform(q);
      canvas.drawCircle(
        head,
        w * (.2 + 1.5 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - q) + .4
          ..color = _navy.withValues(alpha: .20 * (1 - q)),
      );
    }
  }

  /// قصاصات احتفال مسطّحة بألوان العوالم تنطلق من نقطة الاندماج.
  void _confetti(Canvas canvas, Offset head) {
    final q = _T.raw(t, .34, .62);
    if (q <= 0 || q >= 1) return;
    final e = Curves.easeOutCubic.transform(q);
    for (var j = 0; j < 12; j++) {
      final rnd = math.Random(j * 131 + 7);
      final ang = j * math.pi * 2 / 12 + rnd.nextDouble() * .4;
      final speed = w * (.9 + .7 * rnd.nextDouble());
      final pos =
          head +
          Offset(math.cos(ang), math.sin(ang)) * speed * e +
          Offset(0, w * .55 * q * q);
      final alpha = (1 - math.pow(q, 1.6)).toDouble();
      final paint = Paint()
        ..color = _worldColors[j % 3].withValues(alpha: alpha);
      final sz = w * (.03 + .025 * rnd.nextDouble()) * (1 - .3 * q);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(q * 6 + j);
      if (j.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: sz * 2.2, height: sz),
            Radius.circular(sz / 2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, sz * .6, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MorphPainter old) =>
      old.t != t || old.w != w || old.h != h;
}

// ═══════════════════════════════════════════════════════════
// حروف VIBES الأصلية تصعد من خلف قناع
// ═══════════════════════════════════════════════════════════

/// حدود كل حرف في wordmark_gold.png (نسبة من العرض).
const _letters = [
  (0.0, 0.2178),
  (0.2653, 0.3644),
  (0.4158, 0.5802),
  (0.6337, 0.804),
  (0.8653, 1.0),
];

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.t, required this.width});

  final double t;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 98 / 505;
    final image = Image.asset(
      'assets/brand/wordmark_gold.png',
      width: width,
      height: height,
      filterQuality: FilterQuality.high,
      color: _navy,
      colorBlendMode: BlendMode.srcIn,
    );
    return SizedBox(
      width: width,
      height: height,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            for (var i = 0; i < _letters.length; i++)
              Builder(
                builder: (context) {
                  final start = .77 + i * .025;
                  final e = _T.ease(t, start, start + .12, _springSoft);
                  final (x0, x1) = _letters[i];
                  return Positioned(
                    left: width * x0 - 1,
                    width: width * (x1 - x0) + 2,
                    top: 0,
                    height: height,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: width,
                        maxWidth: width,
                        child: Transform.translate(
                          offset: Offset(
                            -width * x0 + 1,
                            height * 1.05 * (1 - e),
                          ),
                          child: image,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final s in HomeSection.values) ...[
          if (s.index > 0) const SizedBox(width: 18),
          Builder(
            builder: (context) {
              final at = .80 + s.index * .028;
              final dot = _T.ease(t, at, at + .07, _spring);
              final word = _T.ease(t, at + .015, at + .09);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // النقاط الملونة تعود — العوالم الثلاثة داخل VIBES
                  Transform.scale(
                    scale: dot,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _worldColors[s.index],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Opacity(
                    opacity: word,
                    child: Transform.translate(
                      offset: Offset(6 * (1 - word), 0),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                          color: Color(0xFF5E6672),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
