import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/world_theme.dart';
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

/// الإنجليزية أعرض من العربية: يصغر النص ليتسع للزر بدل أن يُقص.
Widget _fitEnglish(Widget text) =>
    I18n.isEn ? FittedBox(fit: BoxFit.scaleDown, child: text) : text;

class _VibesButtonState extends State<VibesButton> {
  bool _hovering = false;
  bool _pressed = false;

  void _tap() {
    if (widget.onPressed == null || widget.loading) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.small ? 42.0 : 56.0;
    const shape = Folio.shape;

    final label = Text(
      widget.label,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: widget.small ? 13 : null,
        color: widget.ghost ? context.world.accentDeep : context.world.onAccent,
      ),
    );

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
                    : context.world.onAccent,
              ),
            ),
          )
        else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: widget.small ? 16 : 19,
            color: widget.ghost
                ? context.world.accentDeep
                : context.world.onAccent,
          ),
          const SizedBox(width: VibesSpacing.sm),
        ],
        // بلا عرض محدد (زر مضغوط داخل صف) لا يصح تمديد النص
        if (widget.expanded) Flexible(child: _fitEnglish(label)) else label,
      ],
    );

    if (widget.ghost) {
      return GestureDetector(
        onTap: widget.loading ? null : _tap,
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
                color: _hovering ? context.world.accentFaint : Vibes.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  side: BorderSide(
                    color: context.world.accent.withValues(
                      alpha: _hovering ? .6 : .32,
                    ),
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
            child: DecoratedBox(
              // الظل خارج Material حتى لا يُقص مربعاً حول الزر
              decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                shadows: [
                  BoxShadow(
                    color: context.world.glow.withValues(
                      alpha: _pressed || _hovering ? .42 : .28,
                    ),
                    blurRadius: _pressed || _hovering ? 26 : 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: ShapeDecoration(
                    gradient: context.world.fill,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                  child: InkWell(
                    onTap: widget.loading ? null : _tap,
                    customBorder: shape,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                      child: SizedBox(
                        height: height,
                        child: Column(
                          children: [
                            // بلا عرض محدد لا يصح خط اللمعة بعرض لا نهائي
                            if (widget.expanded)
                              const ColoredBox(
                                color: Color(0x66FFFFFF),
                                child: SizedBox(height: 1.2, width: double.infinity),
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
    final radius = BorderRadius.circular(20);
    final p = context.world;
    return Container(
      decoration: BoxDecoration(
        color: VibesTheme.surfaceOf(context),
        borderRadius: radius,
        border: Border.all(
          color: featured
              ? p.accent.withValues(alpha: 0.4)
              : p.accent.withValues(alpha: .10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: featured
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: p.fill),
                        ),
                      ),
                      Expanded(
                        child: Padding(padding: padding, child: child),
                      ),
                    ],
                  ),
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// رأس قسم — عنوان تحريري + شريط لوني + وصف
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.subtitle,
    this.accent,
    this.brand = false,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? accent;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? context.world.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (brand) ...[
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerEnd,
                                end: AlignmentDirectional.centerStart,
                                colors: [bar.withValues(alpha: 0.25), bar],
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'VIBES',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: bar,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  height: 1,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.4,
                          ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
                colors: [
                  bar.withValues(alpha: 0.45),
                  bar.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
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
          _PulsingDot(color: color, size: compact ? 6.0 : 7.0),
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

/// نقطة حالة نابضة — هالة تتنفس مرة كل دورة ثم تسكن، معزولة
/// طباعياً وتتحول لساكنة مع تقليل الحركة.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _repeating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repeating) return;
    _repeating = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_pulse.isAnimating) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          // موجة واحدة في النصف الأول ثم سكون — أدنى كلفة ممكنة
          final wave = Curves.easeOut.transform((t * 2).clamp(0.0, 1.0));
          final haloAlpha = (1 - wave) * 0.45;
          return SizedBox(
            width: widget.size * 2.4,
            height: widget.size * 2.4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (haloAlpha > 0)
                  Container(
                    width: widget.size * (1 + wave),
                    height: widget.size * (1 + wave),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: haloAlpha),
                      shape: BoxShape.circle,
                    ),
                  ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        },
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.radius < 10 ? widget.radius : widget.radius + 6,
            ),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 + 4 * t, 0),
              end: Alignment(1 - 2 + 4 * t, 0),
              colors: [
                context.world.accentFaint,
                context.world.accent.withValues(alpha: .16),
                context.world.accentFaint,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// حالة فارغة أنيقة — طابع متحرك: أيقونة داخل إطار معيني متوهج
/// تحيط به شرارات صغيرة تظهر مرة واحدة
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
                _EmptyStamp(icon: icon),
                const SizedBox(height: VibesSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: VibesTheme.textPrimaryOf(context),
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

/// طابع الحالة الفارغة — دائرة ناعمة
class _EmptyStamp extends StatelessWidget {
  const _EmptyStamp({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [p.accentSoft, p.accent.withValues(alpha: 0)],
        ),
      ),
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Vibes.surface,
            border: Border.all(color: p.accent.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                color: p.glow.withValues(alpha: .18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 30, color: p.accentDeep),
        ),
      ),
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
                  ? Vibes.mapple
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
    this.ink,
  });

  final num amount;
  final bool compact;
  final bool onDark;

  /// لون موحّد للرقم والوحدة فوق تعبئة ملوّنة — يتجاوز الألوان الافتراضية.
  final Color? ink;

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
            color:
                ink ??
                (amount == 0
                    ? (onDark
                          ? Colors.white54
                          : VibesTheme.textTertiaryOf(context))
                    : (onDark || VibesTheme.isDark(context)
                          ? Vibes.tealBright
                          : Vibes.honeyDeep)),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'د.ع'.tr,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                ink?.withValues(alpha: .75) ??
                (onDark ? Colors.white70 : VibesTheme.textTertiaryOf(context)),
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
      title: 'تعذّر الاتصال'.tr,
      subtitle: message,
      action: onRetry != null
          ? VibesButton(
              label: 'إعادة المحاولة'.tr,
              small: true,
              ghost: true,
              onPressed: onRetry,
            )
          : null,
    );
  }
}

/// شارة «قريباً» للمحافظات التي لم تُضف إليها أماكن بعد.
class ComingSoonPill extends StatelessWidget {
  const ComingSoonPill({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Brand.brassLight, Brand.brass]),
      borderRadius: BorderRadius.circular(99),
      boxShadow: [
        BoxShadow(
          color: Brand.brass.withValues(alpha: .35),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      'قريباً'.tr,
      style: TextStyle(
        fontFamily: VibesFont.ui,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        color: Brand.midnight,
        height: 1.35,
      ),
    ),
  );
}
