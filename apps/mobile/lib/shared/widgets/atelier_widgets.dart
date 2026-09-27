import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'maison_shapes.dart';
import 'vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// مكتبة Atelier — مكونات التصميم المتقدمة
/// نجوم ذهبية متدرجة · شارات ملونة · زجاج حقيقي · ترويسات
/// ═══════════════════════════════════════════════════════════

/// نجوم موحّدة مع GoldRatingBar — نحاس واحد في كل التدفقات
class AtelierStars extends StatelessWidget {
  const AtelierStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.onChanged,
    this.showValue = false,
    this.reviewCount,
  });

  final double rating;
  final double size;
  final ValueChanged<double>? onChanged;
  final bool showValue;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    return GoldRatingBar(
      rating: rating,
      size: size,
      onChanged: onChanged,
      showValue: showValue,
      reviewCount: reviewCount,
    );
  }
}

/// شارة ملونة ناعمة — للحالات والأنواع
class AtelierBadge extends StatelessWidget {
  const AtelierBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: .10),
        shape: RoundedRectangleBorder(
          borderRadius: Folio.compact,
          side: BorderSide(color: color.withValues(alpha: .22)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, color: color),
          if (icon != null) ...[
            const SizedBox(width: 5),
            Icon(icon, size: 12, color: color),
          ] else
            const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر زجاجي حقيقي فوق الصور — blur + أبيض شفاف
class AtelierGlassButton extends StatelessWidget {
  const AtelierGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: Folio.shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              color: active
                  ? Vibes.coral.withValues(alpha: .72)
                  : Colors.white.withValues(alpha: .18),
              shape: RoundedRectangleBorder(
                borderRadius: Folio.radius,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: active ? .4 : .25),
                ),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}

/// ترويسة قسم جديدة — عنوان ضخم + خيط زمردي قصير + رابط اختياري
class AtelierSection extends StatelessWidget {
  const AtelierSection(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 18, color: Vibes.coral),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 14),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Vibes.inkTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Vibes.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// صف معلومات بخط منقّط — كقوائم الكتب الفاخرة
class AtelierInfoRow extends StatelessWidget {
  const AtelierInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Vibes.inkSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DotLeaderPainter(color: Vibes.hairlineStrong),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DotLeaderPainter extends CustomPainter {
  const _DotLeaderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // نقاط دائرية 1.5px كل 8px
    for (var x = 1.0; x < size.width; x += 8) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotLeaderPainter old) => old.color != color;
}

/// أفاتار حرفي — بأربع أشكال (دائرة/مربع/زمردي/عسلي)
class AtelierAvatar extends StatelessWidget {
  const AtelierAvatar({
    super.key,
    required this.letter,
    this.size = 40,
    this.honey = false,
  });

  final String letter;
  final double size;
  final bool honey;

  @override
  Widget build(BuildContext context) {
    final color = honey ? Vibes.honey : Vibes.coral;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: Folio.compact,
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
