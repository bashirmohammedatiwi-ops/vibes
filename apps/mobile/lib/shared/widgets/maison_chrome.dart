import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import 'maison_shapes.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VibesMotion.base,
        curve: VibesMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: ShapeDecoration(
          color: VibesTheme.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.chrome,
            side: BorderSide(
              color: active
                  ? Vibes.teal.withValues(alpha: .45)
                  : VibesTheme.hairlineOf(context),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Container(width: 3, height: 3, color: Vibes.teal),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: active
                    ? VibesTheme.textPrimaryOf(context)
                    : VibesTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تبويبات تحريرية بخط سفلي واضح
class MaisonSegmented extends StatelessWidget {
  const MaisonSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VibesTheme.hairlineOf(context)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: i == index
                                  ? VibesTheme.brandOf(context)
                                  : VibesTheme.textTertiaryOf(context),
                            ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: VibesMotion.fast,
                        height: 1.5,
                        width: double.infinity,
                        color: i == index ? Vibes.teal : Colors.transparent,
                      ),
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
                  ? Vibes.coral.withValues(alpha: .78)
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
    final dark = VibesTheme.isDark(context);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: VibesTheme.washOf(context)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: dark
                    ? const _NightPaperPainter()
                    : _VibesPaperPainter(
                        ink: Vibes.coral.withValues(alpha: .055),
                        copper: Vibes.teal.withValues(alpha: .07),
                      ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _VibesPaperPainter extends CustomPainter {
  const _VibesPaperPainter({required this.ink, required this.copper});

  final Color ink;
  final Color copper;

  @override
  void paint(Canvas canvas, Size size) {
    final thinInk = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fineCopper = Paint()
      ..color = copper
      ..strokeWidth = 1;

    // شعار V هندسي خافت — بلا شبكة تزيينية.
    final mark = Path()
      ..moveTo(size.width * .61, -18)
      ..lineTo(size.width * .74, -18)
      ..lineTo(size.width * .55, size.height * .30)
      ..lineTo(size.width * .46, size.height * .30)
      ..close();
    canvas.drawPath(mark, Paint()..color = ink);
    canvas.drawPath(mark, thinInk);

    final lowerMark = Path()
      ..moveTo(-20, size.height * .76)
      ..lineTo(60, size.height * .76)
      ..lineTo(14, size.height + 20)
      ..lineTo(-20, size.height + 20)
      ..close();
    canvas.drawPath(lowerMark, Paint()..color = copper);

    // علامات تسجيل دقيقة تكرر لغة المطبوعات.
    for (final point in [
      Offset(size.width - 26, 94),
      Offset(30, size.height - 140),
      Offset(size.width - 52, size.height - 40),
    ]) {
      final diamond = Path()
        ..moveTo(point.dx, point.dy - 4)
        ..lineTo(point.dx + 4, point.dy)
        ..lineTo(point.dx, point.dy + 4)
        ..lineTo(point.dx - 4, point.dy)
        ..close();
      canvas.drawPath(diamond, fineCopper);
    }
  }

  @override
  bool shouldRepaint(covariant _VibesPaperPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.copper != copper;
}

/// ترويسة صفحة تحريرية — عنوان + خط نحاسي + رجوع اختياري
class MaisonPageHeader extends StatelessWidget {
  const MaisonPageHeader({
    super.key,
    required this.title,
    this.kicker,
    this.onBack,
    this.trailing,
    this.safe = true,
  });

  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 8 : 20, 12, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  MaisonKicker(kicker!),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (trailing == null) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const ArcFlourish(width: 28),
            ),
          ] else ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
    return safe ? SafeArea(bottom: false, child: row) : row;
  }
}

/// مجموعة إعدادات — لوحة واحدة بدل بطاقات متفرقة
class MaisonMenuGroup extends StatelessWidget {
  const MaisonMenuGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      shadows: VibesTheme.cardOf(context),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 52),
                child: Divider(
                  height: 1,
                  color: VibesTheme.hairlineOf(context),
                ),
              ),
          ],
        ],
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: VibesTheme.brandOf(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_left_rounded,
                  color: VibesTheme.textTertiaryOf(context),
                  size: 20,
                ),
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
    final tint = color ?? VibesTheme.brandOf(context);
    return FolioPanel(
      color: background ?? VibesTheme.surfaceOf(context),
      borderColor: VibesTheme.hairlineOf(context),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.42, color: tint),
      ),
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

/// تسمية تحريرية صغيرة بتتبع حروف — فوق العناوين والحقول
class MaisonKicker extends StatelessWidget {
  const MaisonKicker(
    this.label, {
    super.key,
    this.color = Vibes.teal,
    this.light = false,
  });

  final String label;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 3, height: 3, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: light ? Colors.white70 : color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
            const IgnorePointer(
              child: CustomPaint(painter: _NightPaperPainter()),
            ),
            const Positioned(
              top: -40,
              left: -20,
              child: VibesLogo.mark(
                size: 220,
                color: Colors.white,
                opacity: .10,
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _NightPaperPainter extends CustomPainter {
  const _NightPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final margin = Paint()
      ..color = const Color(0x18F6F1E6)
      ..strokeWidth = 1;
    final brass = Paint()
      ..color = const Color(0x55C89844)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawLine(Offset(18, 0), Offset(18, size.height), margin);
    canvas.drawLine(
      Offset(size.width - 18, 0),
      Offset(size.width - 18, size.height),
      margin,
    );

    final v = Path()
      ..moveTo(size.width * .58, -24)
      ..lineTo(size.width * .78, -24)
      ..lineTo(size.width * .52, size.height * .34)
      ..lineTo(size.width * .38, size.height * .34)
      ..close();
    canvas.drawPath(v, Paint()..color = const Color(0x14F6F1E6));
    canvas.drawPath(v, brass);

    final lower = Path()
      ..moveTo(-28, size.height * .78)
      ..lineTo(72, size.height * .78)
      ..lineTo(18, size.height + 28)
      ..lineTo(-28, size.height + 28)
      ..close();
    canvas.drawPath(lower, Paint()..color = const Color(0x18C89844));

    void bracket(Offset origin, {required bool flipX, required bool flipY}) {
      final dx = flipX ? -1.0 : 1.0;
      final dy = flipY ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(origin.dx + 16 * dx, origin.dy)
        ..lineTo(origin.dx, origin.dy)
        ..lineTo(origin.dx, origin.dy + 16 * dy);
      canvas.drawPath(path, brass);
      canvas.drawRect(
        Rect.fromCenter(center: origin, width: 2.5, height: 2.5),
        Paint()..color = const Color(0x99E0B568),
      );
    }

    bracket(const Offset(28, 72), flipX: false, flipY: false);
    bracket(Offset(size.width - 28, 108), flipX: true, flipY: false);
    bracket(Offset(36, size.height - 120), flipX: false, flipY: true);
    bracket(
      Offset(size.width - 32, size.height - 48),
      flipX: true,
      flipY: true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            topLeft: Radius.circular(8),
            topRight: Radius.circular(18),
          ),
        ),
        shadows: VibesTheme.floatOf(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ColoredBox(
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
  if (text.isEmpty) return 'تعذّر إكمال الطلب. حاول مرة أخرى.';
  if (text.contains('Exception') || text.contains('Error:')) {
    return 'تعذّر إكمال الطلب. حاول مرة أخرى.';
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
              children: [
                const MaisonSheetHandle(),
                child,
              ],
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
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  bool destructive = false,
}) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: const Color(0x661B3857),
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
                            label: cancelLabel,
                            ghost: true,
                            small: true,
                            onPressed: () => Navigator.of(ctx).pop(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VibesButton(
                            label: confirmLabel,
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
          scale: Tween<double>(begin: 0.97, end: 1).animate(
            CurvedAnimation(parent: anim, curve: VibesMotion.curve),
          ),
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
  String confirmLabel = 'حفظ',
  String cancelLabel = 'إلغاء',
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: const Color(0x661B3857),
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
                    MaisonField(
                      label: hint ?? 'النص',
                      controller: controller,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: VibesButton(
                            label: cancelLabel,
                            ghost: true,
                            small: true,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VibesButton(
                            label: confirmLabel,
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
