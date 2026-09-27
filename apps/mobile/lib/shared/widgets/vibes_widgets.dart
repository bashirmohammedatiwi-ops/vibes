import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import 'maison_shapes.dart';

/// ═══════════════════════════════════════════════════════════
/// VIBES — أزرار معمارية، بطاقات مجلة، حالات واضحة
/// ═══════════════════════════════════════════════════════════

/// الزر الذهبي — تدرج شامبانيا بلمعة حريرية تعبر عند التحويم
class VibesButton extends StatefulWidget {
  const VibesButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.small = false,
    this.ghost = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool small;
  final bool ghost;
  final bool expanded;

  @override
  State<VibesButton> createState() => _VibesButtonState();
}

class _VibesButtonState extends State<VibesButton> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.small ? 42.0 : 56.0;
    const shape = Folio.shape;

    final child = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                widget.ghost
                    ? VibesTheme.brandOf(context)
                    : VibesTheme.onActionOf(context),
              ),
            ),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.small ? 16 : 19),
          const SizedBox(width: VibesSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: widget.small ? 13 : null,
              color: widget.ghost ? null : VibesTheme.onActionOf(context),
            ),
          ),
        ),
      ],
    );

    if (widget.ghost) {
      return GestureDetector(
        onTap: widget.loading ? null : widget.onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedOpacity(
            opacity: widget.onPressed == null ? 0.45 : 1,
            duration: VibesMotion.fast,
            child: AnimatedContainer(
              duration: VibesMotion.fast,
              curve: VibesMotion.curve,
              height: height,
              padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 20),
              decoration: ShapeDecoration(
                color: _hovering
                    ? VibesTheme.surfaceHighOf(context)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: Folio.chrome,
                  side: BorderSide(
                    color: _hovering
                        ? Vibes.teal
                        : VibesTheme.hairlineStrongOf(context),
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovering ? 1.02 : 1),
          duration: VibesMotion.fast,
          curve: VibesMotion.curve,
          child: AnimatedOpacity(
            opacity: widget.onPressed == null ? 0.5 : 1,
            duration: VibesMotion.fast,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: ShapeDecoration(
                  gradient: VibesTheme.buttonOf(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: Folio.chrome,
                    side: const BorderSide(
                      color: Color(0x99C89844),
                      width: 1.1,
                    ),
                  ),
                  shadows: _pressed || _hovering
                      ? const [
                          BoxShadow(
                            color: Color(0x661B3857),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Color(0x33C89844),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x3D1B3857),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: InkWell(
                  onTap: widget.loading ? null : widget.onPressed,
                  customBorder: shape,
                  child: SizedBox(
                    height: height,
                    child: Column(
                      children: [
                        const ColoredBox(
                          color: Vibes.tealBright,
                          child: SizedBox(height: 1.5, width: double.infinity),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.small ? 14 : 20,
                            ),
                            child: Center(child: child),
                          ),
                        ),
                      ],
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

/// بطاقة أنيقة — سطح بحد شعري وظل طبقي ناعم
class VibesCard extends StatelessWidget {
  const VibesCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VibesSpacing.lg),
    this.onTap,
    this.glass = false,
    this.featured = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool glass;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: featured
          ? Vibes.teal.withValues(alpha: .45)
          : VibesTheme.hairlineOf(context),
      shadows: Vibes.card,
      railColor: featured ? Vibes.teal : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: Folio.shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// رأس قسم — عنوان + خط ذهبي قصير أنيق
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const ArcFlourish(width: 28),
                    if (subtitle != null) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: VibesTheme.textTertiaryOf(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// شريحة حالة — نقطة ملونة وظيفية + نص (بلا ألوان زينة)
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.0 : 12,
        vertical: compact ? 3.0 : 5,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: Folio.compact,
          side: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط تقييم بالنجوم الذهبية — للعرض والكتابة
class GoldRatingBar extends StatelessWidget {
  const GoldRatingBar({
    super.key,
    this.rating = 0,
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
    Widget star(int index) {
      final value = index + 1;
      final filled = rating >= value;
      final half = !filled && rating > index;

      final icon = filled
          ? Icons.star_rounded
          : half
          ? Icons.star_half_rounded
          : Icons.star_outline_rounded;

      final star = Icon(icon, size: size, color: Vibes.teal);

      if (onChanged == null) return star;
      return GestureDetector(
        onTap: () => onChanged!(value.toDouble()),
        child: star,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0 && onChanged != null) const SizedBox(width: 2),
          star(i),
        ],
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: VibesTheme.textPrimaryOf(context),
            ),
          ),
          if (reviewCount != null)
            Text(
              ' ($reviewCount)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
              ),
            ),
        ],
      ],
    );
  }
}

/// هيكل تحميل متحرك حقيقي — مسح ضوئي ناعم بألوان حبرية
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: widget.radius < 10 ? Folio.compact : Folio.radius,
            ),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 + 4 * t, 0),
              end: Alignment(1 - 2 + 4 * t, 0),
              colors: [
                VibesTheme.surfaceHighOf(context),
                Vibes.coralMint,
                VibesTheme.surfaceHighOf(context),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// حالة فارغة أنيقة — أيقونة رفيعة داخل دائرة ذهبية خافتة
class EmptyCanvas extends StatelessWidget {
  const EmptyCanvas({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
          child: Padding(
            padding: const EdgeInsets.all(VibesSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FolioPanel(
                  color: VibesTheme.surfaceOf(context),
                  borderColor: VibesTheme.hairlineOf(context),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Column(
                      children: [
                        const ColoredBox(
                          color: Vibes.teal,
                          child: SizedBox(height: 1.5, width: double.infinity),
                        ),
                        Expanded(
                          child: Center(
                            child: Icon(
                              icon,
                              size: 34,
                              color: VibesTheme.brandOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: VibesSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: VibesSpacing.sm),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(context),
                      height: 1.6,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: VibesSpacing.lg),
                  action!,
                ],
              ],
            ),
          ),
        )
        .animate(
          // إمكانية وصول: بلا حركة عند تفعيل تقليلها بالنظام
          autoPlay: !MediaQuery.maybeDisableAnimationsOf(context)!,
        )
        .fadeIn(duration: VibesMotion.slow)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: VibesMotion.slow,
          curve: VibesMotion.curve,
        );
  }
}

/// لقطة المفضلة — قلب بنبضة ذهبية عند التنشيط
class FavoriteHeart extends StatefulWidget {
  const FavoriteHeart({
    super.key,
    required this.active,
    required this.onToggle,
    this.size = 24,
  });

  final bool active;
  final ValueChanged<bool> onToggle;
  final double size;

  @override
  State<FavoriteHeart> createState() => _FavoriteHeartState();
}

class _FavoriteHeartState extends State<FavoriteHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handle() {
    final next = !widget.active;
    if (next) _pulse.forward(from: 0);
    widget.onToggle(next);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handle,
        child: ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 1.08,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.08,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 55,
          ),
        ]).animate(_pulse),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VibesTheme.surfaceOf(context).withValues(alpha: 0.92),
            borderRadius: Folio.radius,
            border: Border.all(color: VibesTheme.hairlineOf(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              widget.active
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              size: widget.size,
              color: widget.active
                  ? Vibes.coral
                  : VibesTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// تنسيق السعر بأناقة — أرقام كبيرة ذهبية + وحدة صغيرة
class PriceText extends StatelessWidget {
  const PriceText(
    this.amount, {
    super.key,
    this.compact = false,
    this.onDark = false,
  });

  final num amount;
  final bool compact;
  final bool onDark;

  static String format(num value) {
    final fixed = value.round();
    final str = fixed.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      buf.write(str[i]);
      final remaining = str.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          format(amount),
          style: style?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: amount == 0
                ? (onDark
                      ? Colors.white54
                      : VibesTheme.textTertiaryOf(context))
                : (onDark || VibesTheme.isDark(context)
                      ? Vibes.tealBright
                      : Vibes.coral),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'د.ع',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: onDark ? Colors.white70 : VibesTheme.textTertiaryOf(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// خطأ شبكة أنيق مع إعادة محاولة
class ErrorCanvas extends StatelessWidget {
  const ErrorCanvas({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyCanvas(
      icon: Icons.wifi_off_rounded,
      title: 'تعذّر الاتصال',
      subtitle: message,
      action: onRetry != null
          ? VibesButton(
              label: 'إعادة المحاولة',
              small: true,
              ghost: true,
              onPressed: onRetry,
            )
          : null,
    );
  }
}
