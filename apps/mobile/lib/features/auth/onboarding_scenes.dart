import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home/home_sections.dart';

/// ═══════════════════════════════════════════════════════════
/// مشاهد الترحيب المرسومة — لوحة لكل عالم، بلا صور:
///   المزارع  → غروب، تلال، نخيل، مسبح يتموّج، وطيور
///   القاعات  → قوس قاعة، ثريا تتلألأ، سجادة، وورد
///   التزيين  → سلسلة أضواء، كوشة ورد، بالونات تتمايل، وقصاصات
/// [t] زمن حلقي 0..1 للحركة الهادئة، و[offset] موضع اللوحة أثناء
/// السحب (-1..1) لعمق بارالاكس بين الطبقات.
/// ═══════════════════════════════════════════════════════════

CustomPainter onboardingScene(HomeSection s, double t, double offset) =>
    switch (s) {
      HomeSection.farm => _FarmScene(t, offset),
      HomeSection.hall => _HallScene(t, offset),
      HomeSection.decoration => _DecorScene(t, offset),
    };

double _wave(double t, [double phase = 0]) =>
    math.sin((t + phase) * math.pi * 2);

abstract class _Scene extends CustomPainter {
  _Scene(this.t, this.offset);

  final double t;
  final double offset;

  /// إزاحة طبقة بعمق [depth] (0 بعيد … 1 قريب).
  void layer(Canvas canvas, double depth, Size size, void Function() draw) {
    canvas.save();
    canvas.translate(offset * size.width * .18 * depth, 0);
    draw();
    canvas.restore();
  }

  void sparkle(Canvas canvas, Offset c, double r, Color color) {
    final k = r * .26;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _Scene old) =>
      old.t != t || old.offset != offset;
}

// ── المزارع ──────────────────────────────────────────────────

class _FarmScene extends _Scene {
  _FarmScene(super.t, super.offset);

  void _palm(
    Canvas canvas,
    Offset base,
    double h,
    Color trunk,
    Color leaf,
    double sway,
  ) {
    final top = Offset(base.dx + h * .16 + sway, base.dy - h);
    final trunkPath = Path()
      ..moveTo(base.dx - h * .035, base.dy)
      ..quadraticBezierTo(
        base.dx + h * .02,
        base.dy - h * .5,
        top.dx - h * .02,
        top.dy,
      )
      ..lineTo(top.dx + h * .02, top.dy)
      ..quadraticBezierTo(
        base.dx + h * .07,
        base.dy - h * .5,
        base.dx + h * .035,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunkPath, Paint()..color = trunk);
    // حلقات الجذع
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 7; i++) {
      final f = i / 7;
      final p = Offset.lerp(base, top, f)!;
      canvas.drawLine(p.translate(-h * .03, 0), p.translate(h * .03, -1), ring);
    }
    // السعف
    final leafPaint = Paint()..color = leaf;
    for (final a in [-2.7, -2.15, -1.6, -1.0, -.45, .1]) {
      final angle = a + sway * .01;
      final len = h * (.42 + .06 * math.cos(a * 3));
      final tip = top + Offset(math.cos(angle), math.sin(angle)) * len;
      final droop = Offset(0, len * .32);
      final ctrl = top + (tip - top) * .5 - droop * .2;
      final normal = Offset(-(tip - top).dy, (tip - top).dx) / len * h * .07;
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            (ctrl + normal).dx,
            (ctrl + normal).dy,
            tip.dx,
            tip.dy + droop.dy * .5,
          )
          ..quadraticBezierTo(
            (ctrl - normal).dx,
            (ctrl - normal).dy + droop.dy * .4,
            top.dx,
            top.dy,
          )
          ..close(),
        leafPaint,
      );
    }
    // جوز
    canvas.drawCircle(top.translate(-3, 5), h * .03, Paint()..color = trunk);
    canvas.drawCircle(top.translate(4, 6), h * .03, Paint()..color = trunk);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // السماء
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4E0), Color(0xFFFFDDA8), Color(0xFFF6BE7C)],
          stops: [0, .55, 1],
        ).createShader(Offset.zero & size),
    );
    // الشمس بهالة تتنفس
    layer(canvas, .15, size, () {
      final c = Offset(w * .7, h * .36);
      final pulse = 1 + .05 * _wave(t);
      canvas.drawCircle(
        c,
        w * .26 * pulse,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF1C9).withValues(alpha: .9),
              const Color(0xFFFFE2A0).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: w * .26 * pulse)),
      );
      canvas.drawCircle(c, w * .11, Paint()..color = const Color(0xFFFFC768));
    });
    // طيور
    layer(canvas, .3, size, () {
      final bird = Paint()
        ..color = const Color(0xFF8D6324).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final (x, y, ph) in [(.22, .2, 0.0), (.3, .15, .3), (.4, .23, .6)]) {
        final dx = w * (x + .04 * _wave(t, ph));
        final dy = h * y + 3 * _wave(t * 2, ph);
        final flap = 4 + 2 * _wave(t * 4, ph);
        canvas.drawPath(
          Path()
            ..moveTo(dx - 7, dy - flap * .4)
            ..quadraticBezierTo(dx - 3, dy - flap, dx, dy)
            ..quadraticBezierTo(dx + 3, dy - flap, dx + 7, dy - flap * .4),
          bird,
        );
      }
    });
    // التلة البعيدة
    layer(canvas, .35, size, () {
      canvas.drawPath(
        Path()
          ..moveTo(-w * .2, h * .66)
          ..quadraticBezierTo(w * .25, h * .5, w * .62, h * .62)
          ..quadraticBezierTo(w * .9, h * .7, w * 1.2, h * .58)
          ..lineTo(w * 1.2, h)
          ..lineTo(-w * .2, h)
          ..close(),
        Paint()..color = const Color(0xFFD9C58F),
      );
    });
    // النخيل
    layer(canvas, .6, size, () {
      final sway = 3 * _wave(t);
      _palm(
        canvas,
        Offset(w * .2, h * .76),
        h * .48,
        const Color(0xFF8D6324),
        const Color(0xFF6E8B3D),
        sway,
      );
      _palm(
        canvas,
        Offset(w * .33, h * .78),
        h * .34,
        const Color(0xFFA0743A),
        const Color(0xFF86A24E),
        sway * .8,
      );
      _palm(
        canvas,
        Offset(w * .86, h * .75),
        h * .4,
        const Color(0xFF8D6324),
        const Color(0xFF6E8B3D),
        sway * 1.1,
      );
    });
    // التلة القريبة والمسبح
    layer(canvas, 1, size, () {
      canvas.drawPath(
        Path()
          ..moveTo(-w * .2, h * .8)
          ..quadraticBezierTo(w * .4, h * .7, w * 1.2, h * .8)
          ..lineTo(w * 1.2, h)
          ..lineTo(-w * .2, h)
          ..close(),
        Paint()..color = const Color(0xFFC8A867),
      );
      final pool = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * .56, h * .88),
          width: w * .42,
          height: h * .1,
        ),
        Radius.circular(h * .05),
      );
      canvas.drawRRect(
        pool.inflate(4),
        Paint()..color = const Color(0xFFFFF4E0),
      );
      canvas.drawRRect(
        pool,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF7CD3E3), Color(0xFF3FA9C2)],
          ).createShader(pool.outerRect),
      );
      final ripple = Paint()
        ..color = Colors.white.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final y = pool.top + pool.height * (.3 + i * .22);
        final shift = w * .03 * _wave(t, i * .3);
        canvas.drawLine(
          Offset(pool.left + pool.width * (.2 + i * .1) + shift, y),
          Offset(pool.left + pool.width * (.42 + i * .1) + shift, y),
          ripple,
        );
      }
    });
  }
}

// ── القاعات ──────────────────────────────────────────────────

class _HallScene extends _Scene {
  _HallScene(super.t, super.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const gold = Color(0xFFE0B568);
    // سماء ليلية
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14284A), Color(0xFF26457A), Color(0xFF3B5E96)],
        ).createShader(Offset.zero & size),
    );
    // نجوم
    layer(canvas, .1, size, () {
      final rnd = math.Random(7);
      for (var i = 0; i < 26; i++) {
        final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * .55);
        final tw = (_wave(t * 2, rnd.nextDouble()) + 1) / 2;
        canvas.drawCircle(
          p,
          .6 + rnd.nextDouble() * 1.2,
          Paint()..color = Colors.white.withValues(alpha: .25 + .6 * tw),
        );
      }
    });
    // القوس والأعمدة
    layer(canvas, .5, size, () {
      final archW = w * .62;
      final left = (w - archW) / 2;
      final top = h * .2;
      final bottom = h * .86;
      final outer = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, top + archW / 2)
        ..arcToPoint(
          Offset(left + archW, top + archW / 2),
          radius: Radius.circular(archW / 2),
        )
        ..lineTo(left + archW, bottom)
        ..close();
      canvas.drawPath(outer, Paint()..color = const Color(0xFFFBF3E4));
      // الفتحة الداخلية المضيئة
      final inset = archW * .13;
      final innerW = archW - inset * 2;
      final inner = Path()
        ..moveTo(left + inset, bottom)
        ..lineTo(left + inset, top + inset + innerW / 2)
        ..arcToPoint(
          Offset(left + inset + innerW, top + inset + innerW / 2),
          radius: Radius.circular(innerW / 2),
        )
        ..lineTo(left + inset + innerW, bottom)
        ..close();
      canvas.drawPath(
        inner,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -.2),
            radius: .9,
            colors: [Color(0xFFFFE9B8), Color(0xFFE7B865), Color(0xFFB98235)],
          ).createShader(inner.getBounds()),
      );
      // خط ذهبي على القوس
      canvas.drawPath(
        Path()
          ..moveTo(left + inset * .45, bottom)
          ..lineTo(left + inset * .45, top + archW / 2)
          ..arcToPoint(
            Offset(left + archW - inset * .45, top + archW / 2),
            radius: Radius.circular(archW / 2 - inset * .45),
          )
          ..lineTo(left + archW - inset * .45, bottom),
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // الثريا
      final cx = w / 2;
      final chainTop = top + inset;
      final sway = 2 * _wave(t);
      final hub = Offset(cx + sway, chainTop + innerW * .32);
      canvas.drawLine(
        Offset(cx, chainTop),
        hub,
        Paint()
          ..color = const Color(0xFF8D6324)
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(
        hub,
        innerW * .34,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .55),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: hub, radius: innerW * .34)),
      );
      final armW = innerW * .4;
      final arm = Paint()
        ..color = const Color(0xFF8D6324)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      // طبقتان من الأذرع
      for (final (tier, k) in [(0.0, 1.0), (armW * .34, .62)]) {
        canvas.drawPath(
          Path()
            ..moveTo(hub.dx - armW * k, hub.dy + tier)
            ..quadraticBezierTo(
              hub.dx,
              hub.dy + tier + armW * .5 * k,
              hub.dx + armW * k,
              hub.dy + tier,
            ),
          arm,
        );
      }
      canvas.drawLine(hub, hub.translate(0, armW * .5), arm);
      for (final (tier, k, n) in [(0.0, 1.0, 3), (armW * .34, .62, 2)]) {
        for (var i = -n; i <= n; i++) {
          final f = i / n;
          final x = hub.dx + armW * k * f;
          final y = hub.dy + tier + armW * .25 * k * (1 - f * f);
          final drop = (10 + 8 * (1 - f.abs())) * k + 4;
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + drop),
            Paint()
              ..color = Colors.white.withValues(alpha: .9)
              ..strokeWidth = 1.1,
          );
          final tw = (_wave(t * 3, i * .17 + tier) + 1) / 2;
          canvas.drawCircle(
            Offset(x, y + drop + 3),
            7,
            Paint()
              ..color = Colors.white.withValues(alpha: .35 * tw)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          sparkle(
            canvas,
            Offset(x, y + drop + 3),
            3.4 + 2 * tw,
            Colors.white.withValues(alpha: .8 + .2 * tw),
          );
          // شموع
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y - 5), width: 3.4, height: 8),
              const Radius.circular(1.5),
            ),
            Paint()..color = const Color(0xFFFFF4D6),
          );
          canvas.drawCircle(
            Offset(x, y - 11),
            2.2 + .6 * tw,
            Paint()..color = const Color(0xFFFFD25E),
          );
        }
      }
    });
    // السجادة والورد
    layer(canvas, 1, size, () {
      canvas.drawRect(
        Rect.fromLTRB(0, h * .86, w, h),
        Paint()..color = const Color(0xFF0F2138),
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * .41, h * .86)
          ..lineTo(w * .59, h * .86)
          ..lineTo(w * .74, h)
          ..lineTo(w * .26, h)
          ..close(),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB0384F), Color(0xFF8A2238)],
          ).createShader(Rect.fromLTRB(0, h * .86, w, h)),
      );
      for (final side in [-1, 1]) {
        final bx = w / 2 + side * w * .36;
        for (var i = 0; i < 5; i++) {
          final c = Offset(
            bx + side * (i % 2) * 8 - side * i * 3,
            h * .84 - i * 9,
          );
          canvas.drawCircle(
            c,
            9 - i * .8,
            Paint()..color = const Color(0xFF4F7A4A),
          );
          canvas.drawCircle(
            c.translate(2, -2),
            3.6 - i * .3,
            Paint()
              ..color = i.isEven
                  ? const Color(0xFFF7D6DF)
                  : const Color(0xFFFFFFFF),
          );
        }
      }
      // بريق عائم
      for (final (x, y, ph) in [
        (.16, .3, 0.0),
        (.84, .22, .4),
        (.88, .5, .7),
      ]) {
        final tw = (_wave(t * 2, ph) + 1) / 2;
        sparkle(
          canvas,
          Offset(w * x, h * y),
          3 + 3 * tw,
          gold.withValues(alpha: .5 + .5 * tw),
        );
      }
    });
  }
}

// ── التزيين ──────────────────────────────────────────────────

class _DecorScene extends _Scene {
  _DecorScene(super.t, super.offset);

  void _balloon(Canvas canvas, Offset c, double r, Color color, Offset anchor) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + r * 1.15)
        ..quadraticBezierTo(
          (c.dx + anchor.dx) / 2 + 8,
          (c.dy + anchor.dy) / 2,
          anchor.dx,
          anchor.dy,
        ),
      Paint()
        ..color = const Color(0xFFB24A6B).withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final rect = Rect.fromCenter(center: c, width: r * 2, height: r * 2.3);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          colors: [Color.lerp(color, Colors.white, .45)!, color],
        ).createShader(rect),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 3, c.dy + r * 1.2)
        ..lineTo(c.dx + 3, c.dy + r * 1.2)
        ..lineTo(c.dx, c.dy + r * 1.08)
        ..close(),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * .38, -r * .5),
        width: r * .32,
        height: r * .5,
      ),
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3F6), Color(0xFFFFDCE6), Color(0xFFF8C4D3)],
        ).createShader(Offset.zero & size),
    );
    // سلسلة الأضواء
    layer(canvas, .2, size, () {
      final wire = Path()
        ..moveTo(-10, h * .1)
        ..quadraticBezierTo(w * .5, h * .3, w + 10, h * .1);
      canvas.drawPath(
        wire,
        Paint()
          ..color = const Color(0xFF8A2E4F).withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final metric = wire.computeMetrics().first;
      for (var i = 1; i < 12; i++) {
        final pos = metric
            .getTangentForOffset(metric.length * i / 12)!
            .position;
        final on = (_wave(t * 3, i * .19) + 1) / 2;
        canvas.drawCircle(
          pos.translate(0, 6),
          9,
          Paint()
            ..color = const Color(0xFFFFE08A).withValues(alpha: .25 * on)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          pos.translate(0, 6),
          3.2,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFF2C7),
              const Color(0xFFFFD25E),
              on,
            )!,
        );
      }
    });
    // الكوشة: قوس ورد ومنصة
    layer(canvas, .55, size, () {
      final c = Offset(w * .55, h * .78);
      final r = w * .3;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      const flowers = [
        Color(0xFFE85C86),
        Color(0xFFFFFFFF),
        Color(0xFFF6A9BE),
        Color(0xFFE0B568),
      ];
      for (var i = 0; i <= 14; i++) {
        final a = math.pi + math.pi * i / 14;
        final p = c + Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawCircle(p, 6.5, Paint()..color = const Color(0xFF6F9A63));
        canvas.drawCircle(
          p.translate(i.isEven ? 3 : -3, -2),
          5.6,
          Paint()..color = flowers[i % flowers.length],
        );
        canvas.drawCircle(
          p.translate(i.isEven ? 3 : -3, -2),
          1.6,
          Paint()..color = const Color(0xFFFFE08A),
        );
      }
      // المنصة والكرسيان
      final stage = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, 6), width: r * 1.7, height: 14),
        const Radius.circular(7),
      );
      canvas.drawRRect(stage, Paint()..color = const Color(0xFFFFFFFF));
      for (final dx in [-r * .28, r * .28]) {
        final seat = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(dx, -14), width: 24, height: 30),
          const Radius.circular(10),
        );
        canvas.drawRRect(seat, Paint()..color = const Color(0xFFE0B568));
        canvas.drawRRect(
          seat.deflate(3),
          Paint()..color = const Color(0xFFFFF4E0),
        );
      }
    });
    // البالونات
    layer(canvas, .85, size, () {
      final anchor = Offset(w * .17, h * .95);
      final bob = 5 * _wave(t);
      _balloon(
        canvas,
        Offset(w * .12, h * .42 + bob),
        20,
        const Color(0xFFE85C86),
        anchor,
      );
      _balloon(
        canvas,
        Offset(w * .24, h * .34 - bob),
        22,
        const Color(0xFFE0B568),
        anchor,
      );
      _balloon(
        canvas,
        Offset(w * .2, h * .55 + bob * .6),
        17,
        const Color(0xFFF6A9BE),
        anchor,
      );
    });
    // أرضية وقصاصات
    layer(canvas, 1, size, () {
      canvas.drawRect(
        Rect.fromLTRB(0, h * .9, w, h),
        Paint()..color = const Color(0xFFF1B3C5),
      );
      final rnd = math.Random(3);
      const colors = [Color(0xFFE85C86), Color(0xFFE0B568), Color(0xFFFFFFFF)];
      for (var i = 0; i < 16; i++) {
        final x = rnd.nextDouble() * w;
        final speed = .6 + rnd.nextDouble() * .6;
        final y = ((t * speed + rnd.nextDouble()) % 1) * h * .9;
        canvas.save();
        canvas.translate(x + 6 * _wave(t, i * .1), y);
        canvas.rotate(t * math.pi * 4 * speed + i);
        canvas.drawRect(
          const Rect.fromLTWH(-2.5, -1.2, 5, 2.4),
          Paint()..color = colors[i % 3].withValues(alpha: .85),
        );
        canvas.restore();
      }
    });
  }
}
