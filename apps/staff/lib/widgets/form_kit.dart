import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/net_image.dart';

/// أدوات واجهة مشتركة لشاشات إدارة الأماكن (نموذج، وسائط، تسعير).

String placeTypeLabel(String? type) => switch (type) {
  'FARM' => 'مزرعة',
  'HALL' => 'قاعة',
  'DECORATION' => 'تزيين',
  _ => type ?? '—',
};

IconData placeTypeIcon(String? type) => switch (type) {
  'FARM' => Icons.grass_rounded,
  'HALL' => Icons.celebration_outlined,
  'DECORATION' => Icons.auto_awesome_outlined,
  _ => Icons.place_outlined,
};

String placeStatusLabel(String? status) => switch (status) {
  'DRAFT' => 'مسودة',
  'PENDING' => 'بانتظار الاعتماد',
  'APPROVED' => 'معتمد',
  'REJECTED' => 'مرفوض',
  'SUSPENDED' => 'معلّق',
  _ => status ?? '—',
};

Color placeStatusColor(String? status) => switch (status) {
  'APPROVED' => placeSuccess,
  'PENDING' => placeWarning,
  'REJECTED' => placeDanger,
  'SUSPENDED' => const Color(0xFFB45309),
  _ => placeInk2,
};

/// رسالة عائمة موحّدة.
void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? placeDanger : placeInk,
        margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.page),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.md)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              size: 20,
              color: error ? Colors.white : placeGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.xl)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: (danger ? placeDanger : placeBrass).withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded, color: danger ? placeDanger : placeBrass, size: 26),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, height: 1.55),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: danger ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// صورة شبكية بإطار مستدير وحالات تحميل/فشل أنيقة.
class NetImage extends StatelessWidget {
  const NetImage({super.key, required this.url, this.radius = 14, this.fit = BoxFit.cover, this.icon = Icons.image_outlined});

  final String? url;
  final double radius;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [placeLineSoft, placeLine],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: placeInk3, size: 28),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (u == null || u.isEmpty)
          ? placeholder
          : StaffSizedImage(
              url: u,
              fit: fit,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(color: placeLineSoft);
              },
            ),
    );
  }
}

/// شارة حالة صغيرة (نقطة أو أيقونة + نص).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// بطاقة قسم في النموذج: أيقونة + عنوان + محتوى.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children, this.icon, this.subtitle});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: placeLine),
        boxShadow: staffCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                if (icon != null)
                  Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    decoration: BoxDecoration(color: placeGoldSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 20, color: placeBrass),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: placeInk2,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: placeLineSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل نصي موحّد.
class StaffField extends StatelessWidget {
  const StaffField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboard,
    this.maxLines = 1,
    this.validator,
    this.suffix,
    this.ltr = false,
    this.digitsOnly = false,
    this.onChanged,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final bool ltr;
  final bool digitsOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : 1,
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: validator == null ? null : AutovalidateMode.onUserInteraction,
      textDirection: ltr ? TextDirection.ltr : null,
      textAlign: ltr ? TextAlign.left : TextAlign.start,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w700, color: placeInk),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        errorMaxLines: 2,
        helperStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk3, height: 1.4),
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk3, fontWeight: FontWeight.w500),
        suffixIcon: suffix,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

/// اختيار واحد بأزرار شبه كبسولات (للنوع / وضع الحجز …).
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({super.key, required this.options, required this.value, required this.onChanged, required this.labelOf, this.iconOf});

  final List<T> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [for (final option in options) _pill(option, value == option)]);
  }

  Widget _pill(T option, bool selected) {
    final r = BorderRadius.circular(StaffRadius.md);
    final icon = iconOf?.call(option);
    return Material(
      color: selected ? placeInk : Colors.white,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(option);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: selected ? placeInk : placeLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: selected ? placeGold : placeInk2), const SizedBox(width: 7)],
              Text(
                labelOf(option),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : placeInk),
              ),
              if (selected) ...[const SizedBox(width: 6), const Icon(Icons.check_rounded, size: 16, color: placeGold)],
            ],
          ),
        ),
      ),
    );
  }
}

/// مفتاح تبديل بصف أنيق.
class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(StaffRadius.sm),
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w800, color: placeInk),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, height: 1.4),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: value,
              activeTrackColor: placeSuccess,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط سفلي ثابت بزر رئيسي (حفظ …) مع حالة انشغال.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 12, StaffSpace.page, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
        boxShadow: [BoxShadow(color: Color(0x120F1B2D), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(onPressed: busy ? null : onSecondary, child: Text(secondaryLabel!)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: busy ? null : onPressed,
                child: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : Text(label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? requiredValidator(String? v, [String message = 'هذا الحقل مطلوب']) => (v == null || v.trim().isEmpty) ? message : null;

double? parseNumber(String? raw) {
  if (raw == null) return null;
  final cleaned = raw
      .trim()
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll('٫', '.')
      .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
