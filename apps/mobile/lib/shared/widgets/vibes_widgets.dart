import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// VIBES Élégance — مكتبة الويدجت الأساسية
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

  @override
  Widget build(BuildContext context) {
    final height = widget.small ? 40.0 : 52.0;
    final radius = BorderRadius.circular(
      widget.small ? VibesRadius.sm : VibesRadius.md,
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
                widget.ghost ? GoldColors.gold : GoldColors.onGold,
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
                  color: widget.ghost ? null : GoldColors.onGold,
                ),
          ),
        ),
      ],
    );

    if (widget.ghost) {
      // نسخة شبحية — حد شعري ونص ذهبي
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: VibesMotion.fast,
          curve: VibesMotion.curve,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 20),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _hovering ? GoldColors.gold : GoldColors.goldSoft,
              width: 1,
            ),
            color: _hovering ? GoldColors.goldSoft : Colors.transparent,
          ),
          child: child,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.015 : 1,
        duration: VibesMotion.fast,
        curve: VibesMotion.curve,
        child: AnimatedOpacity(
          opacity: widget.onPressed == null ? 0.5 : 1,
          duration: VibesMotion.fast,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: GoldColors.gradient,
                borderRadius: radius,
                boxShadow: _hovering
                    ? [
                        const BoxShadow(
                          color: Color(0x40C9A96A),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : [
                        const BoxShadow(
                          color: Color(0x26C9A96A),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: InkWell(
                onTap: widget.loading ? null : widget.onPressed,
                borderRadius: radius,
                child: Container(
                  height: height,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.small ? 14 : 20,
                  ),
                  alignment: Alignment.center,
                  child: child,
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: VibesMotion.base,
      curve: VibesMotion.curve,
      decoration: BoxDecoration(
        color: glass
            ? VibesTheme.surfaceOf(context).withValues(alpha: 0.7)
            : VibesTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(VibesRadius.lg),
        border: Border.all(color: VibesTheme.hairlineOf(context)),
        boxShadow: [
          BoxShadow(
            color: VibesTheme.isDark(context)
                ? Colors.black.withValues(alpha: 0.28)
                : const Color(0x0D101114),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VibesRadius.lg),
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
      padding: const EdgeInsets.only(bottom: VibesSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(width: VibesSpacing.sm),
                    // الخط الذهبي القصير — توقيع الهوية
                    Container(
                      width: 22,
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: GoldColors.gradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textTertiaryOf(context),
                        ),
                  ),
                ],
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VibesRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

      final star = Icon(icon, size: size, color: GoldColors.gold);

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

/// صندوق Shimmer ذهبي خافت — هيكل تحميل أنيق
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = VibesTheme.isDark(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dark
              ? [
                  InkColors.surfaceHigh,
                  const Color(0xFF2E2A20), // لمسة ذهبية خافتة
                  InkColors.surfaceHigh,
                ]
              : [
                  PorcelainColors.surfaceHigh,
                  const Color(0xFFF2EBDD), // لمسة ذهبية خافتة
                  PorcelainColors.surfaceHigh,
                ],
        ),
      ),
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
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GoldColors.goldSoft,
                border: Border.all(color: GoldColors.gold.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 34, color: GoldColors.gold),
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
    ).animate().fadeIn(duration: VibesMotion.slow).slideY(
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
    duration: const Duration(milliseconds: 450),
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
            tween: Tween(begin: 1.0, end: 1.35)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.35, end: 0.92)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 30,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: Curves.elasticOut)),
            weight: 30,
          ),
        ]).animate(_pulse),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VibesTheme.surfaceOf(context).withValues(alpha: 0.75),
            border: Border.all(color: VibesTheme.hairlineOf(context)),
          ),
          child: Icon(
            widget.active
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            size: widget.size,
            color: widget.active ? GoldColors.gold : VibesTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

/// تنسيق السعر بأناقة — أرقام كبيرة ذهبية + وحدة صغيرة
class PriceText extends StatelessWidget {
  const PriceText(this.amount, {super.key, this.compact = false});

  final num amount;
  final bool compact;

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
            color: GoldColors.gold,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'د.ع',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// خطأ شبكة أنيق مع إعادة محاولة
class ErrorCanvas extends StatelessWidget {
  const ErrorCanvas({
    super.key,
    required this.message,
    this.onRetry,
  });

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
