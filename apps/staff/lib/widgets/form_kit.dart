import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

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
      'PENDING' => placeShiftMorning,
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message, style: const TextStyle(color: placeInk2, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// صورة شبكية بإطار مستدير وحالات تحميل/فشل أنيقة.
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    this.radius = 14,
    this.fit = BoxFit.cover,
    this.icon = Icons.image_outlined,
  });

  final String? url;
  final double radius;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: placeInk.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Icon(icon, color: placeInk2.withValues(alpha: 0.5), size: 28),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (u == null || u.isEmpty)
          ? placeholder
          : Image.network(
              u,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: placeInk.withValues(alpha: 0.04),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass),
                  ),
                );
              },
            ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
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
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsetsDirectional.only(end: 10),
                  decoration: BoxDecoration(
                    color: placeBrass.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: placeBrass),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: placeInk,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: placeInk2,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
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
      textDirection: ltr ? TextDirection.ltr : null,
      textAlign: ltr ? TextAlign.left : TextAlign.start,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: placeInk),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        suffixIcon: suffix,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

/// اختيار واحد بأزرار شبه كبسولات (للنوع / وضع الحجز …).
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.iconOf,
  });

  final List<T> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(option);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: value == option ? placeInk : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: value == option ? placeInk : placeLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconOf?.call(option) != null) ...[
                    Icon(
                      iconOf!(option),
                      size: 17,
                      color: value == option ? Colors.white : placeInk2,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    labelOf(option),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: value == option ? Colors.white : placeInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// مفتاح تبديل بصف أنيق.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2),
                ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeColor: placeBrass,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
        ),
      ],
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
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
      ),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onSecondary,
                child: Text(secondaryLabel!),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

String? requiredValidator(String? v, [String message = 'هذا الحقل مطلوب']) =>
    (v == null || v.trim().isEmpty) ? message : null;

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
