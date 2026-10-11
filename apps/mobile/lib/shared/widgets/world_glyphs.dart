import 'package:flutter/material.dart';

import '../../features/home/home_sections.dart';

/// ═══════════════════════════════════════════════════════════
/// أيقونات العوالم المرسومة — رسم ثنائي اللون (أساسي + ثانوي) على
/// شبكة 48×48، حادّ بأي حجم:
///   المزارع  → نخلة وشمس وتلّة
///   القاعات  → خاتما زفاف متشابكان بماسة وبريق
///   التزيين  → بالونان بخيوط وبريق
/// ═══════════════════════════════════════════════════════════

class WorldGlyph extends StatelessWidget {
  const WorldGlyph({
    super.key,
    required this.section,
    required this.primary,
    required this.secondary,
    this.size = 44,
  });

  final HomeSection section;
  final Color primary;
  final Color secondary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: switch (section) {
          HomeSection.farm => _FarmPainter(primary, secondary),
          HomeSection.hall => _HallPainter(primary, secondary),
          HomeSection.decoration => _DecorPainter(primary, secondary),
        },
      ),
    );
  }
}

abstract class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.primary, this.secondary);

  final Color primary;
  final Color secondary;

  Paint fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  void draw(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    draw(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.primary != primary || old.secondary != secondary;
}

/// نخلة بسعفات منحنية وجوزتين، شمس، وتلّة.
class _FarmPainter extends _GlyphPainter {
  _FarmPainter(super.primary, super.secondary);

  @override
  void draw(Canvas canvas) {
    // الشمس
    canvas.drawCircle(const Offset(36, 11), 6, fill(secondary));
    // التلّة
    canvas.drawPath(
      Path()
        ..moveTo(3, 44)
        ..quadraticBezierTo(15, 34, 27, 38)
        ..quadraticBezierTo(37, 41, 45, 37)
        ..lineTo(45, 44)
        ..close(),
      fill(secondary.withValues(alpha: .75)),
    );
    // الجذع
    canvas.drawPath(
      Path()
        ..moveTo(19.5, 40)
        ..quadraticBezierTo(18.5, 28, 23.5, 18.5),
      stroke(primary, 3.4),
    );
    // السعف
    Path leaf(Offset tip, Offset c1, Offset c2) => Path()
      ..moveTo(23.5, 18)
      ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, 23.5, 18)
      ..close();
    final p = fill(primary);
    canvas.drawPath(
      leaf(const Offset(7, 20), const Offset(12, 9), const Offset(16, 20)),
      p,
    );
    canvas.drawPath(
      leaf(
        const Offset(10.5, 29),
        const Offset(12.5, 18),
        const Offset(19.5, 24),
      ),
      p,
    );
    canvas.drawPath(
      leaf(const Offset(40, 21), const Offset(35, 9), const Offset(31, 20)),
      p,
    );
    canvas.drawPath(
      leaf(
        const Offset(36.5, 30),
        const Offset(35, 19),
        const Offset(27.5, 24),
      ),
      p,
    );
    canvas.drawPath(
      leaf(const Offset(25, 5), const Offset(18, 8), const Offset(29, 11)),
      p,
    );
    // جوزتان
    canvas.drawCircle(const Offset(21.6, 21.2), 1.9, fill(secondary));
    canvas.drawCircle(const Offset(25.4, 21.6), 1.9, fill(secondary));
  }
}

/// خاتما زفاف متشابكان، ماسة على الثاني، ولمعات بريق.
class _HallPainter extends _GlyphPainter {
  _HallPainter(super.primary, super.secondary);

  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final k = r * .28;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
        ..close(),
      paint,
    );
  }

  @override
  void draw(Canvas canvas) {
    const a = Offset(18.5, 30.5);
    const b = Offset(29.5, 30.5);
    const r = 10.0;
    final ringA = stroke(primary, 3.4);
    final ringB = stroke(secondary, 3.4);
    // الخاتمان المتشابكان
    canvas.drawCircle(a, r, ringA);
    canvas.drawCircle(b, r, ringB);
    // تشابك: قوس من الخاتم الأول يمرّ فوق الثاني
    canvas.drawArc(
      Rect.fromCircle(center: a, radius: r),
      -0.15,
      1.05,
      false,
      ringA,
    );
    // الماسة فوق الخاتم الثاني
    final gem = Path()
      ..moveTo(25.2, 15.6)
      ..lineTo(27.4, 12.4)
      ..lineTo(31.6, 12.4)
      ..lineTo(33.8, 15.6)
      ..lineTo(29.5, 21)
      ..close();
    canvas.drawPath(gem, fill(primary));
    canvas.drawPath(
      Path()
        ..moveTo(25.2, 15.6)
        ..lineTo(33.8, 15.6)
        ..moveTo(28.4, 12.4)
        ..lineTo(27.6, 15.6)
        ..lineTo(29.5, 21),
      stroke(secondary, .9),
    );
    // بريق
    _sparkle(canvas, const Offset(10, 13), 4.2, fill(secondary));
    _sparkle(canvas, const Offset(40.5, 9.5), 3, fill(primary));
    _sparkle(canvas, const Offset(41, 21), 1.8, fill(secondary));
  }
}

/// بالونان بخيوط متموّجة، لمعة، وشرائط بريق.
class _DecorPainter extends _GlyphPainter {
  _DecorPainter(super.primary, super.secondary);

  void _balloon(Canvas canvas, Offset c, double rx, double ry, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
      paint,
    );
    // العقدة
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 1.8, c.dy + ry + 2)
        ..lineTo(c.dx, c.dy + ry - .8)
        ..lineTo(c.dx + 1.8, c.dy + ry + 2)
        ..close(),
      paint,
    );
  }

  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close(),
      paint,
    );
  }

  @override
  void draw(Canvas canvas) {
    final p = fill(primary);
    final s = fill(secondary);
    // الخيوط
    final string = stroke(primary.withValues(alpha: .85), 1.4);
    canvas.drawPath(
      Path()
        ..moveTo(18, 29)
        ..quadraticBezierTo(15, 34, 19, 37)
        ..quadraticBezierTo(23, 40, 22.5, 45),
      string,
    );
    canvas.drawPath(
      Path()
        ..moveTo(31, 31)
        ..quadraticBezierTo(33, 36, 28.5, 39)
        ..quadraticBezierTo(24.5, 42, 23.5, 45),
      string,
    );
    // البالونان
    _balloon(canvas, const Offset(31, 20.5), 7.5, 9, s);
    _balloon(canvas, const Offset(18, 17), 8.5, 10.5, p);
    // لمعة
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(14.8, 12.5),
        width: 3.4,
        height: 5.4,
      ),
      fill(Colors.white.withValues(alpha: .55)),
    );
    // بريق
    _sparkle(canvas, const Offset(40.5, 8), 4.2, s);
    _sparkle(canvas, const Offset(6.5, 31), 2.8, p);
    _sparkle(canvas, const Offset(41, 36), 2.4, p);
  }
}
