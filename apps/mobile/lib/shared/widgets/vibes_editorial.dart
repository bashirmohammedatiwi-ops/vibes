import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// VIBES Editorial — طبقة تصميم فاخرة مشتركة
/// ═══════════════════════════════════════════════════════════

const editorialRadius = 12.0;

BorderRadius get editorialShape => BorderRadius.circular(editorialRadius);

/// إطار بطاقة تحريري — حدود متدرجة وظل نحاسي
BoxDecoration editorialCardShell(BuildContext context, {Color? accent}) {
  final glow = accent ?? Vibes.teal;
  return BoxDecoration(
    color: VibesTheme.surfaceOf(context),
    borderRadius: editorialShape,
    border: Border.all(color: glow.withValues(alpha: 0.14)),
    boxShadow: Vibes.card,
  );
}

/// حاوية بحد متدرج — إطار فاخر حول أي عنصر
class EditorialFrame extends StatelessWidget {
  const EditorialFrame({
    super.key,
    required this.accent,
    required this.child,
    this.radius = editorialRadius,
    this.padding = 1.5,
  });

  final Color accent;
  final Widget child;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: accent.withValues(alpha: 0.28),
        boxShadow: Vibes.card,
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - padding),
          child: child,
        ),
      ),
    );
  }
}

/// لوحة زجاجية — للتعليقات فوق الصور
class EditorialGlass extends StatelessWidget {
  const EditorialGlass({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.radius = 8.0,
    this.dark = false,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  final double radius;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? Vibes.teal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? Colors.black.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : bar.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// شريحة سعر نحاسية — توقيع الهوية
class BrassPriceChip extends StatelessWidget {
  const BrassPriceChip({
    super.key,
    required this.amount,
    this.onDark = false,
    this.compact = true,
  });

  final num amount;
  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: onDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Brand.brassLight, Brand.brass],
              ),
        color: onDark ? Colors.white.withValues(alpha: 0.96) : null,
        border: Border.all(
          color: onDark
              ? Brand.brass.withValues(alpha: 0.35)
              : Brand.brassDeep.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Brand.brass.withValues(alpha: onDark ? 0.2 : 0.32),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 5 : 7,
        ),
        child: PriceText(amount, compact: compact, onDark: onDark),
      ),
    );
  }
}

/// حاجب تحريري — نص صغير فوق العناوين
class EditorialEyebrow extends StatelessWidget {
  const EditorialEyebrow({super.key, required this.label, this.accent});

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? Vibes.teal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [bar.withValues(alpha: 0.3), bar]),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: bar,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// علامة زخرفية نحاسية — للزوايا والترحيب
class EditorialMark extends StatelessWidget {
  const EditorialMark({super.key, this.size = 48, this.accent});

  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? Vibes.teal;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(bar)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final r = size.width * 0.42;
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.38), r, fill);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.38), r, paint);

    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.88),
      Offset(size.width * 0.52, size.height * 0.88),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.88),
      Offset(size.width * 0.08, size.height * 0.52),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
