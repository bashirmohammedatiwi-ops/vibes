import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// VIBES Graphics — رسومات الهوية المتجهية والحركة الاحترافية
/// مونوغرام مرسوم · قصاصات احتفال · عدّادات · لمسات ضغط
/// ═══════════════════════════════════════════════════════════

/// مونوغرام VIBES المتجهي — دبوس موقع يحيط بحرف V،
/// مرسوم بخطوط نحاسية مستديرة الأطراف كما في الهوية الرسمية.
class VibesMonogram extends StatelessWidget {
  const VibesMonogram({
    super.key,
    this.size = 64,
    Color? color,
    this.strokeWidth,
    this.progress = 1,
    this.showV = true,
  }) : _color = color;

  final double size;
  final Color? _color;
  Color get color => _color ?? Vibes.teal;
  final double? strokeWidth;

  /// 0→1 لميزانية «الرسم الحي» — 1 يعني مكتمل.
  final double progress;
  final bool showV;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MonogramPainter(
        color: color,
        stroke: strokeWidth ?? (size / 9.5).clamp(1.6, 5.0),
        progress: progress.clamp(0.0, 1.0),
        showV: showV,
      ),
    );
  }
}

class _MonogramPainter extends CustomPainter {
  const _MonogramPainter({
    required this.color,
    required this.stroke,
    required this.progress,
    required this.showV,
  });

  final Color color;
  final double stroke;
  final double progress;
  final bool showV;

  @override
  void paint(Canvas canvas, Size size) {
    final pin = Path();
    final v = Path();
    final cx = size.width / 2;
    final r = size.width * 0.34;
    final cy = size.height * 0.36;

    // الدبوس: نصف دائرة علوي يهبط بنعومة إلى قمة مدببة
    pin.moveTo(cx - r, cy);
    pin.arcTo(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi,
      math.pi,
      false,
    );
    pin.cubicTo(
      cx + r,
      cy + r * 0.92,
      cx + r * 0.28,
      size.height * 0.80,
      cx,
      size.height,
    );
    pin.cubicTo(
      cx - r * 0.28,
      size.height * 0.80,
      cx - r,
      cy + r * 0.92,
      cx - r,
      cy,
    );

    // الحرف V داخل الدبوس — النصف السفلي يلمّح إلى مسار الرحلة
    v.moveTo(cx - r * 0.52, cy - r * 0.42);
    v.lineTo(cx, cy + r * 0.62);
    v.lineTo(cx + r * 0.52, cy - r * 0.42);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // توزيع الميزانية: 62% للدبوس ثم 38% للحرف
    final pinBudget = showV ? 0.62 : 1.0;
    _drawPartial(canvas, pin, paint, (progress / pinBudget).clamp(0.0, 1.0));
    if (showV && progress > pinBudget) {
      _drawPartial(
        canvas,
        v,
        paint,
        ((progress - pinBudget) / (1 - pinBudget)).clamp(0.0, 1.0),
      );
    }
  }

  void _drawPartial(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MonogramPainter old) =>
      old.color != color ||
      old.progress != progress ||
      old.stroke != stroke ||
      old.showV != showV;
}

/// مونوغرام يُرسم ذاتياً مرة واحدة — لبوابات الدخول والنجاح.
class MonogramDraw extends StatefulWidget {
  const MonogramDraw({
    super.key,
    this.size = 96,
    Color? color,
    this.duration = const Duration(milliseconds: 1400),
    this.onDone,
  }) : _color = color;

  final double size;
  final Color? _color;
  Color get color => _color ?? Vibes.teal;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<MonogramDraw> createState() => _MonogramDrawState();
}

class _MonogramDrawState extends State<MonogramDraw>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _controller.value = 1;
      widget.onDone?.call();
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        return VibesMonogram(
          size: widget.size,
          color: widget.color,
          progress: t,
        );
      },
    );
  }
}

/// قصاصات احتفال بألوان الهوية — نحاس وياقوت ومابل ولبن،
/// مستطيلات ومعينات (لغة الأشكال) تتساقط وتدور ثم تخبو.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.pieces = 42,
    this.duration = const Duration(milliseconds: 2600),
    this.origin = const Alignment(0, -0.55),
    this.spread = 0.75,
  });

  final int pieces;
  final Duration duration;
  final Alignment origin;

  /// عرض التوزيع الأفقي — 1 يعني كامل العرض.
  final double spread;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _pieces = const [];
      return;
    }
    final rng = math.Random(7);
    final palette = [
      Vibes.teal,
      Vibes.tealBright,
      Vibes.coral,
      Vibes.mapple,
      Brand.milkJug,
    ];
    _pieces = List.generate(widget.pieces, (i) {
      return _Piece(
        x: (rng.nextDouble() * 2 - 1) * widget.spread,
        delay: rng.nextDouble() * 0.25,
        speed: 0.55 + rng.nextDouble() * 0.55,
        drift: (rng.nextDouble() * 2 - 1) * 0.18,
        spin: (rng.nextDouble() * 2 - 1) * 6,
        size: 4 + rng.nextDouble() * 5,
        color: palette[i % palette.length],
        diamond: rng.nextBool(),
      );
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pieces.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          pieces: _pieces,
          progress: _controller,
          origin: widget.origin,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.diamond,
  });

  final double x; // -1..1 نسبي
  final double delay; // 0..0.25
  final double speed;
  final double drift;
  final double spin; // دورات
  final double size;
  final Color color;
  final bool diamond;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.origin,
  });

  final List<_Piece> pieces;
  final Animation<double> progress;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final ox = size.width / 2 + origin.x * size.width / 2;
    final oy = size.height / 2 + origin.y * size.height / 2;

    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;

      // مسار قوسي: صعود سريع ثم سقوط، مع انجراف جانبي
      final rise = math.sin(local * math.pi) * 0.16;
      final fall = local * local;
      final dy = (-rise + fall * 1.15) * size.height * p.speed * 0.6;
      final dx = (p.x * size.width * 0.5) + p.drift * local * size.width;

      // خفوت في الربع الأخير
      final fade = local > 0.75 ? (1 - local) / 0.25 : 1.0;
      final paint = Paint()..color = p.color.withValues(alpha: fade);

      final angle = p.spin * local * math.pi;
      canvas.save();
      canvas.translate(ox + dx, oy + dy);
      canvas.rotate(angle);
      if (p.diamond) {
        final r = p.size * 0.7;
        final path = Path()
          ..moveTo(0, -r)
          ..lineTo(r, 0)
          ..lineTo(0, r)
          ..lineTo(-r, 0)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

/// عدّاد أرقام متصاعد — لبطاقات الإحصاء والملخصات المالية.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.formatter,
  });

  final num value;
  final TextStyle? style;
  final Duration duration;
  final String Function(num)? formatter;

  static String _groupThousands(num v) {
    final fixed = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < fixed.length; i++) {
      buf.write(fixed[i]);
      final remaining = fixed.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = value.toDouble();
    String format(num v) => formatter?.call(v) ?? _groupThousands(v);

    if (reduce) {
      return Text(format(value), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// تنبيه VIBES — شريط ليلي بسكة نحاسية وأيقونة دلالية،
/// يظهر ويرتفع بمنحنى الهوية. بديل رفيع لـ Snackbar النظامي.
enum VibesToastType { success, danger, info, message }

void showVibesToast(
  BuildContext context,
  String message, {
  VibesToastType type = VibesToastType.info,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2600),
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: _VibesToastCard(message: message, type: type),
    ),
  );
}

class _VibesToastCard extends StatelessWidget {
  const _VibesToastCard({required this.message, required this.type});

  final String message;
  final VibesToastType type;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (type) {
      VibesToastType.success => (Vibes.success, Icons.check_circle_rounded),
      VibesToastType.danger => (Vibes.danger, Icons.error_rounded),
      VibesToastType.message => (Vibes.teal, Icons.chat_bubble_rounded),
      VibesToastType.info => (Vibes.coral, Icons.info_rounded),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Brand.midnight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(8),
            bottomLeft: Radius.circular(10),
          ),
        ),
        shadows: VibesTheme.floatOf(context),
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(8),
              bottomLeft: Radius.circular(10),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(width: 3.5, height: 54, color: color),
            const SizedBox(width: 12),
            Icon(icon, size: 19, color: color.withValues(alpha: .95)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Brand.milkJug,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

/// أيقونات التصنيف المتجهية — مزرعة/قاعة/تزيين بلغة خطوط الهوية،
/// بديل أدق وأرقى من أيقونات Material العامة في البطاقات والدبابيس.
enum VibesCategory { farm, hall, decoration }

class VibesCategoryIcon extends StatelessWidget {
  const VibesCategoryIcon({
    super.key,
    required this.category,
    this.size = 28,
    Color? color,
    this.strokeWidth,
  }) : _color = color;

  final VibesCategory category;
  final double size;
  final Color? _color;
  Color get color => _color ?? Vibes.teal;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CategoryIconPainter(
        category: category,
        color: color,
        stroke: strokeWidth ?? (size / 8).clamp(1.4, 3.2),
      ),
    );
  }
}

class _CategoryIconPainter extends CustomPainter {
  const _CategoryIconPainter({
    required this.category,
    required this.color,
    required this.stroke,
  });

  final VibesCategory category;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;

    switch (category) {
      case VibesCategory.farm:
        _farm(canvas, w, h, paint);
      case VibesCategory.hall:
        _hall(canvas, w, h, paint);
      case VibesCategory.decoration:
        _decoration(canvas, w, h, paint);
    }
  }

  /// مزرعة — حظيرة بسقف مائل وباب، وشجرة صغيرة إلى الجانب
  void _farm(Canvas canvas, double w, double h, Paint paint) {
    final house = Path()
      ..moveTo(w * .14, h * .52)
      ..lineTo(w * .14, h * .88)
      ..lineTo(w * .58, h * .88)
      ..lineTo(w * .58, h * .52)
      // سقف مائل
      ..moveTo(w * .06, h * .54)
      ..lineTo(w * .36, h * .20)
      ..lineTo(w * .66, h * .54)
      // الباب
      ..moveTo(w * .28, h * .88)
      ..lineTo(w * .28, h * .66)
      ..lineTo(w * .44, h * .66)
      ..lineTo(w * .44, h * .88);
    canvas.drawPath(house, paint);

    // شجرة: جذع + تاج دائري
    canvas.drawLine(Offset(w * .78, h * .88), Offset(w * .78, h * .62), paint);
    canvas.drawCircle(Offset(w * .78, h * .48), w * .15, paint);
  }

  /// قاعة — قوس أعراس بهالة نجمية: قوس كبير وتحته ثلاث أعمدة
  void _hall(Canvas canvas, double w, double h, Paint paint) {
    final arch = Path()
      // القوس
      ..moveTo(w * .18, h * .88)
      ..lineTo(w * .18, h * .48)
      ..cubicTo(w * .18, h * .14, w * .82, h * .14, w * .82, h * .48)
      ..lineTo(w * .82, h * .88)
      // أعمدة داخلية
      ..moveTo(w * .36, h * .88)
      ..lineTo(w * .36, h * .60)
      ..moveTo(w * .50, h * .88)
      ..lineTo(w * .50, h * .56)
      ..moveTo(w * .64, h * .88)
      ..lineTo(w * .64, h * .60);
    canvas.drawPath(arch, paint);

    // نجمة صغيرة فوق القوس — تاج القاعة
    final star = Path()
      ..moveTo(w * .50, h * .02)
      ..lineTo(w * .53, h * .09)
      ..lineTo(w * .60, h * .10)
      ..lineTo(w * .55, h * .15)
      ..lineTo(w * .56, h * .22)
      ..lineTo(w * .50, h * .19)
      ..lineTo(w * .44, h * .22)
      ..lineTo(w * .45, h * .15)
      ..lineTo(w * .40, h * .10)
      ..lineTo(w * .47, h * .09)
      ..close();
    canvas.drawPath(star, paint);
  }

  /// تزيين — غصن زهور منحنٍ بثمهرة ووريقتين
  void _decoration(Canvas canvas, double w, double h, Paint paint) {
    final branch = Path()
      // الساق المنحنية
      ..moveTo(w * .50, h * .92)
      ..cubicTo(w * .38, h * .72, w * .38, h * .52, w * .50, h * .34)
      ..cubicTo(w * .56, h * .24, w * .62, h * .18, w * .62, h * .10);
    canvas.drawPath(branch, paint);

    // ورقة يسرى
    final leafL = Path()
      ..moveTo(w * .46, h * .62)
      ..cubicTo(w * .28, h * .60, w * .22, h * .48, w * .20, h * .38)
      ..cubicTo(w * .38, h * .40, w * .46, h * .48, w * .46, h * .62)
      ..close();
    canvas.drawPath(leafL, paint);

    // ورقة يمنى
    final leafR = Path()
      ..moveTo(w * .52, h * .50)
      ..cubicTo(w * .66, h * .46, w * .72, h * .36, w * .76, h * .26)
      ..cubicTo(w * .60, h * .30, w * .52, h * .38, w * .52, h * .50)
      ..close();
    canvas.drawPath(leafR, paint);

    // ثمرة زهرة أعلى الساق
    final bloom = Path()
      ..moveTo(w * .62, h * .10)
      ..lineTo(w * .70, h * .16)
      ..lineTo(w * .62, h * .22)
      ..lineTo(w * .54, h * .16)
      ..close();
    canvas.drawPath(bloom, paint);
  }

  @override
  bool shouldRepaint(covariant _CategoryIconPainter old) =>
      old.category != category || old.color != color || old.stroke != stroke;
}

/// غلاف ضغط لمسي — ينكمش قليلاً عند اللمس ويهتز هزة خفيفة.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = true);
              HapticFeedback.selectionClick();
            },
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && widget.enabled ? 0.96 : 1,
        duration: VibesMotion.fast,
        curve: VibesMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// انفجار قلب بالنقر المزدوج — توقيع التطبيقات الاجتماعية الراقية.
/// قلب Mapple كبير يتوسع ويخبو، تحيطه قصاصات هوية صغيرة.
class HeartBurst extends StatefulWidget {
  const HeartBurst({
    super.key,
    required this.trigger,
    this.size = 96,
    Color? color,
  }) : _color = color;

  /// يزيد كل مرة ليعاد إطلاق الانفجار.
  final int trigger;
  final double size;
  final Color? _color;
  Color get color => _color ?? Vibes.mapple;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _last = 0;

  @override
  void didUpdateWidget(covariant HeartBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != _last) {
      _last = widget.trigger;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _controller.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (disabled || t == 0 || t >= 1) return const SizedBox.shrink();

          final popIn = Curves.easeOutBack.transform(
            (t / 0.45).clamp(0.0, 1.0),
          );
          final fadeOut = t < 0.62 ? 1.0 : (1 - t) / 0.38;
          final s = widget.size * popIn;

          return Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: s,
                color: widget.color.withValues(alpha: fadeOut.clamp(0.0, 1.0)),
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 24),
                ],
              ),
              for (var i = 0; i < 6; i++)
                () {
                  final angle = (i / 6) * math.pi * 2 + 0.4;
                  final travel = 14 + 34 * Curves.easeOutCubic.transform(t);
                  final dot = 3.4 * (1 - t) + 1;
                  return Transform.translate(
                    offset: Offset(
                      math.cos(angle) * travel,
                      math.sin(angle) * travel,
                    ),
                    child: Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: dot,
                        height: dot,
                        color: i.isEven
                            ? Vibes.teal.withValues(alpha: fadeOut)
                            : Colors.white.withValues(alpha: fadeOut * .8),
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}
