import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../models/models.dart';
import 'vibes_graphics.dart';
import '../../core/utils/vibes_net_image.dart';

/// ═══════════════════════════════════════════════════════════
/// مكوّنات العوالم المشتركة — تُستخدم في كل الشاشات فتبقى اللغة
/// البصرية واحدة: زر متدرج بلون العالم، رأس صفحة بجوّ العالم،
/// حالة فراغ أنيقة، شارة حالة، وتنسيق السعر بالدينار.
/// ═══════════════════════════════════════════════════════════

String formatIqdShort(num value) {
  final fixed = value.round();
  final str = fixed.abs().toString();
  final buf = StringBuffer(fixed < 0 ? '-' : '');
  for (var i = 0; i < str.length; i++) {
    buf.write(str[i]);
    final remaining = str.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buf.write(',');
  }
  return buf.toString();
}

/// زر رئيسي بتدرج العالم وتوهّجه.
class WorldButton extends StatelessWidget {
  const WorldButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.loading = false,
    this.height = 56,
    this.palette,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final double height;

  /// لوحة مخصّصة (مثلاً لون عالم المكان) — وإلا لوحة الثيم.
  final WorldPalette? palette;

  @override
  Widget build(BuildContext context) {
    final p = palette ?? context.world;
    final enabled = onTap != null && !loading;
    return PressScale(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? .5 : 1,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: p.fill,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled ? p.glowShadow : const [],
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: p.onAccent,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: p.onAccent),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: p.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// زر ثانوي بحدّ ناعم بلون العالم.
class WorldGhostButton extends StatelessWidget {
  const WorldGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height = 52,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final fg = onDark ? Colors.white : p.accentDeep;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: .1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onDark
                ? Colors.white.withValues(alpha: .24)
                : p.accent.withValues(alpha: .35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رأس صفحة بجوّ العالم — عنوان كبير ووصف وإجراء اختياري،
/// فوق سماء ليلية منحنية الحافة السفلية.
class WorldPageHeader extends StatelessWidget {
  const WorldPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: WorldAtmosphere(
        palette: p,
        night: true,
        intensity: 1.2,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            top + 12,
            16,
            bottom == null ? 26 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (showBack) ...[
                    WorldGlassIcon(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: .72),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: 18), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

/// أيقونة زجاجية دائرية فوق الخلفيات الليلية.
class WorldGlassIcon extends StatelessWidget {
  const WorldGlassIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .12),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Icon(icon, size: size * .46, color: Colors.white),
      ),
    );
  }
}

/// تبويبات كبسولية فوق الخلفية الليلية — للفلاتر.
class WorldPillTabs extends StatelessWidget {
  const WorldPillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.counts,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: i == index ? p.accentDeep : Colors.white,
                          ),
                        ),
                      ),
                      if (counts != null && counts![i] > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: i == index
                                ? p.accent
                                : Colors.white.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${counts![i]}',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: i == index ? p.onAccent : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// حالة فراغ — أيقونة داخل هالة بلون العالم، عنوان، وصف، وزر.
class WorldEmpty extends StatelessWidget {
  const WorldEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [p.accentSoft, p.accent.withValues(alpha: 0)],
              ),
            ),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: p.accent.withValues(alpha: .25)),
                  boxShadow: [
                    BoxShadow(
                      color: p.glow.withValues(alpha: .18),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(icon, size: 28, color: p.accentDeep),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Vibes.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Vibes.inkSecondary,
                height: 1.6,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: WorldButton(
                label: actionLabel!,
                onTap: onAction,
                height: 50,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// شارة حالة ملوّنة.
class WorldStatusChip extends StatelessWidget {
  const WorldStatusChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// هيكل تحميل لامع بلون العالم.
class WorldSkeleton extends StatefulWidget {
  const WorldSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 12,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<WorldSkeleton> createState() => _WorldSkeletonState();
}

class _WorldSkeletonState extends State<WorldSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = -1.5 + _c.value * 3;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [
                p.accentFaint,
                p.accent.withValues(alpha: .16),
                p.accentFaint,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// غلاف المكان — الصورة إن وُجدت، وإلا بديل أنيق: ليل عالم المكان
/// بأيقونته الكبيرة الخافتة وأيقونة صغيرة واضحة في المنتصف.
class PropertyCover extends StatelessWidget {
  const PropertyCover({
    super.key,
    required this.property,
    this.iconSize = 40,
    this.memCacheWidth,
  });

  final Property property;
  final double iconSize;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = property.coverUrl;
    if (url != null && url.isNotEmpty) {
      return VibesNetImage(
        url: url,
        fit: BoxFit.cover,
        memCacheWidth: memCacheWidth,
      );
    }
    final p = WorldPalette.forType(property.type.name);
    final icon = switch (property.type) {
      PropertyType.farm => VibesCategory.farm,
      PropertyType.hall => VibesCategory.hall,
      PropertyType.decoration => VibesCategory.decoration,
    };
    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.nightfall),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              end: -iconSize * .6,
              bottom: -iconSize * .7,
              child: Opacity(
                opacity: .10,
                child: VibesCategoryIcon(
                  category: icon,
                  size: iconSize * 3.4,
                  color: Colors.white,
                ),
              ),
            ),
            Center(
              child: Container(
                width: iconSize * 1.7,
                height: iconSize * 1.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                  border: Border.all(
                    color: p.accentLight.withValues(alpha: .35),
                  ),
                ),
                child: Center(
                  child: VibesCategoryIcon(
                    category: icon,
                    size: iconSize,
                    color: p.accentLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
