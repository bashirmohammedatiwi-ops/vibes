import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// VIBES Maison — نظام أشكال «الماسة الزمردية»
/// وحدة عضوية واحدة (المعين) تسري في كل التطبيق
/// ═══════════════════════════════════════════════════════════

/// 1) المعين الزمردي — علامة التطبيق (صلب/مفرغ/نشط)
class EmeraldDiamond extends StatelessWidget {
  const EmeraldDiamond({
    super.key,
    this.size = 16,
    this.filled = false,
    this.active = false,
  });

  final double size;
  final bool filled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Vibes.coralBright : Vibes.coral;
    return CustomPaint(
      size: Size.square(size),
      painter: _DiamondPainter(
        color: color,
        filled: filled,
        strokeWidth: size >= 32 ? 1.2 : 1.0,
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  final Color color;
  final bool filled;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? ui.PaintingStyle.fill : ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter old) =>
      old.color != color || old.filled != filled;
}

/// 2) شريط بقطع زوايا 45° — السفلي والزر (شخصية معمارية)
class ChamferedBar extends StatelessWidget {
  const ChamferedBar({super.key, required this.child, this.chamfer = 10});

  final Widget child;
  final double chamfer;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChamferPainter(
        color: VibesTheme.surfaceOf(context),
        borderColor: VibesTheme.hairlineOf(context),
        chamfer: chamfer,
      ),
      child: child,
    );
  }
}

class _ChamferPainter extends CustomPainter {
  const _ChamferPainter({
    required this.color,
    required this.borderColor,
    required this.chamfer,
  });

  final Color color;
  final Color borderColor;
  final double chamfer;

  @override
  bool shouldRepaint(covariant _ChamferPainter old) =>
      old.color != color || old.borderColor != borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(chamfer, 0)
      ..lineTo(size.width - chamfer, 0)
      ..lineTo(size.width, chamfer)
      ..lineTo(size.width, size.height - chamfer)
      ..lineTo(size.width - chamfer, size.height)
      ..lineTo(chamfer, size.height)
      ..lineTo(0, size.height - chamfer)
      ..lineTo(0, chamfer)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }
}

/// 3) فاصل المجلات — خط 0.5px ينتهي بمعين 3px
class DiamondDivider extends StatelessWidget {
  const DiamondDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsetsDirectional.only(end: 8),
            transform: Matrix4.rotationZ(0.785398), // 45°
            color: Vibes.coral,
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: VibesTheme.hairlineOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4) صف قائمة المحتويات — تسمية ····· قيمة
class DottedLeaderRow extends StatelessWidget {
  const DottedLeaderRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: ts.bodySmall?.copyWith(
              color: VibesTheme.textTertiaryOf(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                return Row(
                  children: List.generate(
                    (c.maxWidth / 6).floor(),
                    (_) => Expanded(
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: 3),
                        height: 0.5,
                        color: VibesTheme.hairlineOf(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: ts.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: VibesTheme.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5) خيط زمردي ينمو — بديل spinners
class ThreadProgress extends StatelessWidget {
  const ThreadProgress({super.key, this.width = 120});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 1.5,
      child: LinearProgressIndicator(
        minHeight: 1.5,
        backgroundColor: VibesTheme.hairlineOf(context),
        valueColor: const AlwaysStoppedAnimation(Vibes.teal),
      ),
    );
  }
}

/// 6) خيط المعصم — علامة «مميز» فوق الصورة
class WristLine extends StatelessWidget {
  const WristLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 2,
      decoration: BoxDecoration(
        color: Vibes.coral,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// 7) دبوس الخريطة — مستطيل معماري + السعر
class DiamondPin extends StatelessWidget {
  const DiamondPin({super.key, required this.price, this.selected = false});

  final String price;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MaisonSquircle(
          radius: 28,
          color: selected ? Vibes.coral : VibesTheme.surfaceOf(context),
          borderColor: selected
              ? Colors.white.withValues(alpha: .35)
              : Vibes.coral.withValues(alpha: .45),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? .28 : .16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PetalMark(
                  size: 6,
                  color: selected ? Colors.white : Vibes.coral,
                ),
                const SizedBox(width: 4),
                Text(
                  price,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Vibes.coral,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected ? Vibes.coral : VibesTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Vibes.coral.withValues(alpha: .5)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 8) زر المجوهرات — بزوايا مشطوفة
class OctagonButton extends StatefulWidget {
  const OctagonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.small = false,
    this.ghost = false,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool small;
  final bool ghost;
  final bool loading;
  final bool expanded;

  @override
  State<OctagonButton> createState() => _OctagonButtonState();
}

class _OctagonButtonState extends State<OctagonButton> {
  @override
  Widget build(BuildContext context) {
    final height = widget.small ? 42.0 : 56.0;

    return GestureDetector(
      child: AnimatedOpacity(
        opacity: widget.onPressed == null ? 0.45 : 1,
        duration: VibesMotion.fast,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: height,
            decoration: ShapeDecoration(
              color: widget.ghost ? Colors.transparent : Vibes.coral,
              shape: RoundedRectangleBorder(
                borderRadius: Folio.radius,
                side: widget.ghost
                    ? const BorderSide(color: Vibes.coral, width: 1.4)
                    : BorderSide.none,
              ),
              shadows: widget.ghost
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x441B3857),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
            ),
            child: InkWell(
              onTap: widget.loading ? null : widget.onPressed,
              customBorder: Folio.shape,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.small ? 14 : 22,
                ),
                child: Center(
                  child: widget.loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation(
                              widget.ghost ? Vibes.coral : Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: widget.ghost
                                    ? Vibes.coralBright
                                    : Colors.white,
                              ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChamferShape extends ShapeBorder {
  const _ChamferShape(this.chamfer);

  final double chamfer;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(1), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return ui.Path()
      ..moveTo(rect.left + chamfer, rect.top)
      ..lineTo(rect.right - chamfer, rect.top)
      ..lineTo(rect.right, rect.top + chamfer)
      ..lineTo(rect.right, rect.bottom - chamfer)
      ..lineTo(rect.right - chamfer, rect.bottom)
      ..lineTo(rect.left + chamfer, rect.bottom)
      ..lineTo(rect.left, rect.bottom - chamfer)
      ..lineTo(rect.left, rect.top + chamfer)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _ChamferShape(chamfer * t);
}

/// 9) رقم بمعين مفرغ — استمارات الحجز
class NumberedDiamond extends StatelessWidget {
  const NumberedDiamond({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: Vibes.coralFill,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 10) علامة النجاح — معين يتحول دائرة تُرسم + ✓
class DrawnCheckmark extends StatefulWidget {
  const DrawnCheckmark({super.key, this.size = 90});

  final double size;

  @override
  State<DrawnCheckmark> createState() => _DrawnCheckmarkState();
}

class _DrawnCheckmarkState extends State<DrawnCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

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
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _DrawnCheckPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _DrawnCheckPainter extends CustomPainter {
  const _DrawnCheckPainter({required this.progress});

  final double progress;

  @override
  bool shouldRepaint(covariant _DrawnCheckPainter old) =>
      old.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Vibes.coralBright
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = ui.StrokeCap.round;

    // المرحلة 1 (0→0.5): معين يتحول دائرة (رسم دائرة تدريجياً)
    final circleProgress = (progress / 0.5).clamp(0.0, 1.0);
    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.width / 2 - 4,
        ),
        -1.5708, // من الأعلى
        6.2832 * circleProgress,
        false,
        paint,
      );
    }

    // المرحلة 2 (0.5→1): علامة ✓
    final checkProgress = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (checkProgress > 0) {
      final c = size.center(Offset.zero);
      final p1 = Offset(c.dx - size.width * 0.18, c.dy + size.height * 0.02);
      final p2 = Offset(c.dx - size.width * 0.04, c.dy + size.height * 0.16);
      final p3 = Offset(c.dx + size.width * 0.20, c.dy - size.height * 0.14);

      final path = ui.Path()..moveTo(p1.dx, p1.dy);
      if (checkProgress < 0.5) {
        final t = checkProgress * 2;
        path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final t = (checkProgress - 0.5) * 2;
        path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
      }
      canvas.drawPath(path, paint);
    }
  }
}

/// إطار تحريري موحّد — قطع معماري خفيف بلا كبسولات
abstract final class Folio {
  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(12),
    bottomRight: Radius.circular(8),
    bottomLeft: Radius.circular(10),
  );

  static const BorderRadius compact = BorderRadius.only(
    topLeft: Radius.circular(5),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(5),
    bottomLeft: Radius.circular(7),
  );

  /// قطع معماري للحقول والأزرار القصيرة — زاوية حادة تمنع قراءة الكبسولة
  static const BorderRadius chrome = BorderRadius.only(
    topLeft: Radius.circular(0),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(0),
    bottomLeft: Radius.circular(6),
  );

  /// صورة بطاقة القائمة — 16:10 تحريرية
  static const double listingPhoto = 16 / 10;

  /// ختم تصنيف/محافظة — 3:4 عمودي
  static const double stamp = 3 / 4;

  static const RoundedRectangleBorder shape = RoundedRectangleBorder(
    borderRadius: radius,
  );

  static const RoundedRectangleBorder compactShape = RoundedRectangleBorder(
    borderRadius: compact,
  );

  static const RoundedRectangleBorder chromeShape = RoundedRectangleBorder(
    borderRadius: chrome,
  );
}

class FolioPanel extends StatelessWidget {
  const FolioPanel({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.shadows,
    this.clip = true,
    this.railColor,
    this.radius,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final bool clip;
  final Color? railColor;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: radius ?? Folio.radius,
      side: BorderSide(color: borderColor ?? VibesTheme.hairlineOf(context)),
    );
    Widget content = child;
    if (railColor != null) {
      content = Stack(
        children: [
          child,
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(width: 3, child: ColoredBox(color: railColor!)),
          ),
        ],
      );
    }
    final box = DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? VibesTheme.surfaceOf(context),
        shape: shape,
        shadows: shadows,
      ),
      child: content,
    );
    if (!clip) return box;
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: box,
    );
  }
}

class MaisonSquircle extends StatelessWidget {
  const MaisonSquircle({
    super.key,
    required this.child,
    this.radius = 48,
    this.color,
    this.borderColor,
    this.shadows,
    this.clip = true,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: color,
      borderColor: borderColor ?? Colors.transparent,
      shadows: shadows,
      clip: clip,
      child: child,
    );
  }
}

/// علامة معمارية — مربع صغير بزاوية حادة، بلا دوائر
class PetalMark extends StatelessWidget {
  const PetalMark({
    super.key,
    this.size = 10,
    this.color = Vibes.coral,
    this.filled = true,
  });

  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.18),
          topRight: Radius.circular(1),
          bottomRight: Radius.circular(size * 0.18),
          bottomLeft: Radius.circular(size * 0.18),
        ),
      ),
    );
  }
}

/// خط نحاسي قصير تحت العناوين — مربع تسجيل ثم شعرة
class ArcFlourish extends StatelessWidget {
  const ArcFlourish({super.key, this.width = 46, this.color = Vibes.teal});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 6),
      painter: _RulePainter(color),
    );
  }
}

class _RulePainter extends CustomPainter {
  const _RulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mark = Paint()..color = color;
    canvas.drawRect(const Rect.fromLTWH(0, 1.5, 3, 3), mark);
    canvas.drawRect(
      Rect.fromLTWH(7, 2.5, (size.width - 7).clamp(0, size.width), 1),
      mark,
    );
  }

  @override
  bool shouldRepaint(covariant _RulePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// فاصل تحريري — نفس علامة التسجيل ثم خط شعري
class ScallopDivider extends StatelessWidget {
  const ScallopDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 3, color: Vibes.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: VibesTheme.hairlineOf(context)),
        ),
      ],
    );
  }
}

/// زوايا لوحة على الصورة — علامتان فقط، بلا إطار مغلق
class PlateCorners extends StatelessWidget {
  const PlateCorners({
    super.key,
    this.color = const Color(0xD9FFFFFF),
    this.inset = 10,
    this.arm = 18,
  });

  final Color color;
  final double inset;
  final double arm;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PlateCornerPainter(color: color, inset: inset, arm: arm),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PlateCornerPainter extends CustomPainter {
  const _PlateCornerPainter({
    required this.color,
    required this.inset,
    required this.arm,
  });

  final Color color;
  final double inset;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final mark = Paint()..color = color;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin + Offset(dx, 0), stroke);
      canvas.drawLine(origin, origin + Offset(0, dy), stroke);
      canvas.drawRect(
        Rect.fromCenter(center: origin, width: 2.5, height: 2.5),
        mark,
      );
    }

    corner(Offset(inset, inset), arm, arm);
    corner(
      Offset(size.width - inset, size.height - inset),
      -arm,
      -arm,
    );
  }

  @override
  bool shouldRepaint(covariant _PlateCornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.inset != inset ||
      oldDelegate.arm != arm;
}

/// مستوى معماري خلف الشعارات — مستطيل مائل بدل الهالة الدائرية
class BloomOrb extends StatelessWidget {
  const BloomOrb({super.key, required this.color, this.size = 160});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.12,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: color, shape: Folio.shape),
          child: SizedBox(width: size, height: size * 0.58),
        ),
      ),
    );
  }
}

/// شعار VIBEES الرسمي — العلامة أو القفل الكامل مع الكلمة
class VibesLogo extends StatelessWidget {
  const VibesLogo.mark({
    super.key,
    this.size = 48,
    this.color,
    this.opacity = 1,
  }) : lockup = false,
       height = null;

  const VibesLogo.lockup({
    super.key,
    this.height = 132,
    this.color,
    this.opacity = 1,
  }) : lockup = true,
       size = null;

  final bool lockup;
  final double? size;
  final double? height;
  final Color? color;
  final double opacity;

  static const markAsset = 'assets/brand/logo_mark_white.png';
  static const lockupAsset = 'assets/brand/logo_lockup.png';
  static const goldMarkAsset = 'assets/brand/logo_mark_gold.png';

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      lockup
          ? (color == null ? lockupAsset : markAsset)
          : (color == null ? goldMarkAsset : markAsset),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    Widget child = color == null
        ? image
        : ColorFiltered(
            colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
            child: image,
          );

    if (opacity < 1) {
      child = Opacity(opacity: opacity, child: child);
    }

    if (lockup && color == null) {
      return SizedBox(height: height, child: child);
    }
    if (lockup) {
      return SizedBox(height: height, child: child);
    }
    return SizedBox(width: size, height: size, child: child);
  }
}

/// علامة VIBEES الرسمية — دبوس الموقع، يُلوَّن حسب السياق
class CrestSeal extends StatelessWidget {
  const CrestSeal({super.key, this.size = 72, this.color = Vibes.coral});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return VibesLogo.mark(size: size, color: color);
  }
}

/// قص معماري أسفل الهيرو — شطف حاد بدل الموجة
class WaveClipper extends CustomClipper<Path> {
  const WaveClipper();

  @override
  Path getClip(Size size) {
    const cut = 18.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// شارة تحريرية فوق الصور — مستطيل حاد بلا زينة
class RibbonChip extends StatelessWidget {
  const RibbonChip({super.key, required this.label, this.color = Vibes.coral});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: .94),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(2),
            bottomRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
          side: BorderSide(color: Colors.white.withValues(alpha: .22)),
        ),
        shadows: [
          BoxShadow(
            color: color.withValues(alpha: .28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
