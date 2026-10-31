import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import 'maison_shapes.dart';
import 'vibes_graphics.dart';
import 'vibes_widgets.dart';

/// شريحة فلتر هندسية — بلا كبسولات مبالغ فيها
class MaisonChip extends StatelessWidget {
  const MaisonChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VibesMotion.base,
        curve: VibesMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? p.fill : null,
          color: active
              ? null
              : themed(const Color(0xFFF4F5F7), VibesDark.surfaceMuted),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: active ? p.onAccent : VibesTheme.textSecondaryOf(context),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// تبويبات كapsule — مؤشر متحرك مثل مبدّل العوالم
class MaisonSegmented extends StatelessWidget {
  const MaisonSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.accent,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? Vibes.teal;
    // ليلاً التعبئة فاتحة غالباً، فالنص فوقها حبر ليلي لا أبيض.
    final selectedInk = themed(
      Colors.white,
      bar.computeLuminance() > .3 ? VibesDark.onTeal : Colors.white,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VibesTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VibesTheme.hairlineOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabW = constraints.maxWidth / labels.length;
            return SizedBox(
              height: 40,
              child: Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: VibesMotion.base,
                    curve: Curves.easeOutCubic,
                    start: index * tabW,
                    width: tabW,
                    top: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: bar,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onChanged(i),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: AnimatedDefaultTextStyle(
                                    duration: VibesMotion.fast,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: i == index
                                              ? selectedInk
                                              : VibesTheme.textSecondaryOf(
                                                  context,
                                                ),
                                        ),
                                    child: Text(
                                      labels[i],
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// أيقونة زجاجية فوق الصور
class MaisonGlassIcon extends StatelessWidget {
  const MaisonGlassIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: Folio.shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(6),
            decoration: ShapeDecoration(
              color: active
                  ? Vibes.mapple.withValues(alpha: .82)
                  : Colors.white.withValues(alpha: .2),
              shape: RoundedRectangleBorder(
                borderRadius: Folio.radius,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: active ? .45 : .28),
                ),
              ),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// صورة مصغرة بزوايا معمارية
class MaisonThumb extends StatelessWidget {
  const MaisonThumb({super.key, this.url, this.size = 64, this.fallback});

  final String? url;
  final double size;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: VibesTheme.surfaceHighOf(context),
      borderColor: Colors.transparent,
      clip: true,
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? VibesNetImage(
                url: url!,
                width: size,
                height: size,
                memCacheWidth: (size * 2).round().clamp(64, 256),
                memCacheHeight: (size * 2).round().clamp(64, 256),
              )
            : fallback ??
                  Icon(
                    Icons.home_work_rounded,
                    color: VibesTheme.textTertiaryOf(context),
                  ),
      ),
    );
  }
}

/// خلفية عاجية بهوية VIBES مرسومة دائماً:
/// ختم V كبير وخطوط معمارية خافتة، لا دوائر أو موجات.
class MaisonWash extends StatelessWidget {
  const MaisonWash({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (VibesTheme.isDark(context)) {
      return ColoredBox(color: VibesDark.canvas, child: child);
    }
    return ColoredBox(color: context.world.canvas, child: child);
  }
}

/// ترويسة صفحة — شريط لوني + عنوان + رجوع اختياري
class MaisonPageHeader extends StatelessWidget {
  const MaisonPageHeader({
    super.key,
    required this.title,
    this.kicker,
    this.onBack,
    this.trailing,
    this.safe = true,
    this.accent,
  });

  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool safe;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final tint = accent ?? p.accentDeep;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (onBack != null) ...[
            PressScale(
              onTap: onBack,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themed(const Color(0xFFF2F3F5), VibesDark.surfaceMuted),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Vibes.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kicker != null)
                  Text(
                    kicker!,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: tint,
                      height: 1.3,
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: VibesTheme.textPrimaryOf(context),
                    height: 1.25,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    return safe ? SafeArea(bottom: false, child: row) : row;
  }
}

/// بطاقة قائمة موحّدة — زوايا 18، شريط لوني اختياري
class SurfaceListCard extends StatelessWidget {
  const SurfaceListCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  final bool highlighted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bar = accent ?? context.world.accent;
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: highlighted
                ? bar.withValues(alpha: 0.08)
                : VibesTheme.surfaceOf(context),
            borderRadius: radius,
            border: Border.all(
              color: highlighted
                  ? bar.withValues(alpha: 0.28)
                  : context.world.accent.withValues(alpha: .10),
            ),
            boxShadow: VibesTheme.cardOf(context),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (accent != null)
                  SizedBox(
                    width: 4,
                    child: DecoratedBox(decoration: BoxDecoration(color: bar)),
                  ),
                Expanded(
                  child: Padding(padding: padding, child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مجموعة إعدادات — لوحة واحدة بدل بطاقات متفرقة
class MaisonMenuGroup extends StatelessWidget {
  const MaisonMenuGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: VibesTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.accent.withValues(alpha: .10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 64),
                  child: Divider(height: 1, color: p.accent.withValues(alpha: .08)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// صف قائمة تحريري داخل مجموعة
class MaisonMenuRow extends StatelessWidget {
  const MaisonMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: p.accentFaint, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: p.accentDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: VibesTheme.textPrimaryOf(context),
                ),
              ),
            ),
            trailing ?? Icon(I18n.isEn ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: p.accentDeep.withValues(alpha: .6), size: 20),
          ],
        ),
      ),
    );
  }
}

/// بئر أيقونة معمارية — للقوائم والتواصل
class MaisonIconWell extends StatelessWidget {
  const MaisonIconWell({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.world.accentDeep;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? context.world.accentFaint,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, size: size * 0.46, color: tint),
    );
  }
}

/// مقبض ورقة سفلية — شريط مستطيل دقيق
class MaisonSheetHandle extends StatelessWidget {
  const MaisonSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Center(
        child: SizedBox(
          width: 42,
          height: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VibesTheme.hairlineStrongOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريحة مرفق أنيقة
class MaisonSoftChip extends StatelessWidget {
  const MaisonSoftChip({super.key, required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: VibesTheme.hairlineOf(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// تسمية — شارة pill أنيقة فوق العناوين
class MaisonKicker extends StatelessWidget {
  const MaisonKicker(
    this.label, {
    super.key,
    Color? color,
    this.light = false,
  }) : _color = color;

  final String label;
  final Color? _color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = _color ?? context.world.accentDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: light
              ? Colors.white.withValues(alpha: 0.28)
              : color.withValues(alpha: 0.0),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: light ? Colors.white.withValues(alpha: 0.92) : color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// خلفية Midnight معمارية لشاشات الدخول والسبلاش
class MaisonNightWash extends StatelessWidget {
  const MaisonNightWash({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF162C46), VibesDark.canvas, Color(0xFF0A1828)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PositionedDirectional(
              top: -20,
              end: -10,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: VibesLogo.mark(size: 220, color: Colors.white),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

/// لوحة دعوة ترسو من الأسفل — بديل بطاقة SaaS العائمة
class MaisonInviteDock extends StatelessWidget {
  const MaisonInviteDock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: VibesTheme.canvasOf(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
          ),
        ),
        shadows: VibesTheme.floatOf(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: Vibes.teal,
            child: SizedBox(height: 2, width: double.infinity),
          ),
          child,
        ],
      ),
    );
  }
}

/// حقل إدخال معماري — تسمية فوق الإطار، بلا مظهر Material الافتراضي
class MaisonField extends StatelessWidget {
  const MaisonField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefix,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.maxLength,
    this.maxLines = 1,
    this.focusNode,
    this.textDirection,
    this.fieldDirection,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final int maxLines;
  final FocusNode? focusNode;
  final TextDirection? textDirection;
  final TextDirection? fieldDirection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: VibesTheme.textSecondaryOf(context),
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        FolioPanel(
          radius: Folio.chrome,
          color: VibesTheme.surfaceOf(context),
          borderColor: VibesTheme.hairlineStrongOf(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Directionality(
              textDirection: fieldDirection ?? Directionality.of(context),
              child: Row(
                children: [
                  if (prefix != null) ...[
                    prefix!,
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsetsDirectional.only(
                        start: 12,
                        end: 12,
                      ),
                      color: VibesTheme.hairlineOf(context),
                    ),
                  ],
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      onSubmitted: onSubmitted,
                      maxLength: maxLength,
                      maxLines: maxLines,
                      textDirection: textDirection,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: VibesTheme.textPrimaryOf(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String maisonError(Object error) {
  final text = error.toString().trim();

  // أخطاء الشبكة — رسائل مفهومة تحدد المشكلة والسبيل.
  final lower = text.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed host lookup') ||
      lower.contains('name or service not known') ||
      lower.contains('connection timed out') ||
      lower.contains('timed out') ||
      lower.contains('err_name_not_resolved') ||
      lower.contains('err_internet_disconnected') ||
      lower.contains('err_connection_refused')) {
    return 'لا اتصال بالإنترنت — تحقق من الشبكة وحاول مجدداً'.tr;
  }
  if (lower.contains('handshake') || lower.contains('certificate')) {
    return 'تعذّر تأمين الاتصال بالخادم — حاول لاحقاً'.tr;
  }

  if (text.isEmpty) return 'تعذّر إكمال الطلب. حاول مرة أخرى.'.tr;
  if (text.contains('Exception') || text.contains('Error:')) {
    return 'تعذّر إكمال الطلب. حاول مرة أخرى.'.tr;
  }
  return text;
}

Future<T?> showMaisonSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: VibesTheme.surfaceOf(ctx),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(12),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const MaisonSheetHandle(), child],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> showMaisonConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final confirmText = confirmLabel ?? 'تأكيد'.tr;
  final cancelText = cancelLabel ?? 'إلغاء'.tr;
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelText,
    barrierColor: themed(const Color(0x661B3857), const Color(0x99000000)),
    transitionDuration: VibesMotion.base,
    pageBuilder: (ctx, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: Colors.transparent,
            child: FolioPanel(
              color: VibesTheme.surfaceOf(ctx),
              shadows: VibesTheme.floatOf(ctx),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VibesTheme.textPrimaryOf(ctx),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textSecondaryOf(ctx),
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: VibesButton(
                            label: cancelText,
                            ghost: true,
                            small: true,
                            onPressed: () => Navigator.of(ctx).pop(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VibesButton(
                            label: confirmText,
                            small: true,
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.97,
            end: 1,
          ).animate(CurvedAnimation(parent: anim, curve: VibesMotion.curve)),
          child: child,
        ),
      );
    },
  );
  return ok ?? false;
}

Future<String?> showMaisonPrompt({
  required BuildContext context,
  required String title,
  String? message,
  String? initial,
  String? hint,
  String? confirmLabel,
  String? cancelLabel,
}) {
  final confirmText = confirmLabel ?? 'حفظ'.tr;
  final cancelText = cancelLabel ?? 'إلغاء'.tr;
  final controller = TextEditingController(text: initial ?? '');
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelText,
    barrierColor: themed(const Color(0x661B3857), const Color(0x99000000)),
    transitionDuration: VibesMotion.base,
    pageBuilder: (ctx, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: Colors.transparent,
            child: FolioPanel(
              color: VibesTheme.surfaceOf(ctx),
              shadows: VibesTheme.floatOf(ctx),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VibesTheme.textPrimaryOf(ctx),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: VibesTheme.textSecondaryOf(ctx),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    MaisonField(label: hint ?? 'النص'.tr, controller: controller),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: VibesButton(
                            label: cancelText,
                            ghost: true,
                            small: true,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VibesButton(
                            label: confirmText,
                            small: true,
                            onPressed: () =>
                                Navigator.of(ctx).pop(controller.text.trim()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
