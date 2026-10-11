import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';

/// أدوات مشتركة لشاشات الإعداد (المواقع، المزايا، الإعدادات، التقارير، النشاط).

final _count = NumberFormat('#,###', 'ar');

/// تحويل آمن لأي قيمة (رقم، نص Decimal من Prisma …) إلى رقم.
num asNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('${v ?? ''}') ?? 0;
}

String fmtCount(dynamic v) => _count.format(asNum(v).round());

/// اختصار للمحاور والبطاقات: 1.2 م / 350 ألف.
String fmtCompact(num n) {
  final a = n.abs();
  if (a >= 1000000000) return '${_trim(n / 1000000000)} مليار';
  if (a >= 1000000) return '${_trim(n / 1000000)} م';
  if (a >= 1000) return '${_trim(n / 1000)} ألف';
  return n.round().toString();
}

String _trim(num n) {
  final s = n.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime? parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse('$raw')?.toLocal();
}

String fmtDateTime(dynamic raw) {
  final d = parseDate(raw);
  if (d == null) return '—';
  return DateFormat('d MMM yyyy · HH:mm', 'ar').format(d);
}

String fmtShortDate(DateTime d) => DateFormat('d MMM', 'ar').format(d);

String relativeTimeAr(dynamic raw) {
  final d = parseDate(raw);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
  return DateFormat('d MMM', 'ar').format(d);
}

/// مولّد معرّف (slug) مطابق للوحة الويب: أحرف لاتينية/عربية وأرقام وشرطات.
String slugify(String text) {
  final s = text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^\w؀-ۿ-]'), '');
  final cut = s.length > 48 ? s.substring(0, 48) : s;
  return cut.isEmpty ? 'item' : cut;
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// حالة الخطأ مع زر إعادة المحاولة — قابلة للسحب للتحديث.
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.cloud_off_rounded, size: 52, color: placeInk2.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text(
          'تعذّر التحميل',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, height: 1.5),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ),
      ],
    );
  }
}

/// تحميل أولي داخل قائمة (يسمح بالسحب للتحديث).
class CatalogLoadingView extends StatelessWidget {
  const CatalogLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 160),
        Center(child: CircularProgressIndicator(color: placeBrass)),
      ],
    );
  }
}

/// شريط "عرض فقط" عند غياب صلاحية التعديل.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key, this.text = 'عرض فقط — ليست لديك صلاحية التعديل في هذا القسم'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: placeBrass.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: placeBrass.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 18, color: placeBrass),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل بحث مستدير.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, color: placeInk2),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// عنوان قسم صغير داخل القوائم.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w900, color: placeInk),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2),
            ),
        ],
      ),
    );
  }
}

/// بطاقة بيضاء موحّدة.
class CatalogCard extends StatelessWidget {
  const CatalogCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.margin});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: placeLine),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// صف معلومة قابلة للنسخ.
class CopyRow extends StatelessWidget {
  const CopyRow({super.key, required this.label, required this.value, this.ltr = true});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value.isEmpty ? '—' : value,
            textDirection: ltr ? TextDirection.ltr : null,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk, fontWeight: FontWeight.w700),
          ),
        ),
        if (value.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 16, color: placeInk2),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              showToast(context, 'تم النسخ');
            },
          ),
      ],
    );
  }
}

/// ورقة سفلية بنموذج بسيط (اسم عربي + إنجليزي …) تعيد القيم عند الحفظ.
Future<Map<String, String>?> showNameSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String nameAr = '',
  String nameEn = '',
  String confirmLabel = 'حفظ',
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _NameSheet(
      title: title,
      subtitle: subtitle,
      nameAr: nameAr,
      nameEn: nameEn,
      confirmLabel: confirmLabel,
    ),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.subtitle,
    required this.nameAr,
    required this.nameEn,
    required this.confirmLabel,
  });

  final String title;
  final String? subtitle;
  final String nameAr;
  final String nameEn;
  final String confirmLabel;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _form = GlobalKey<FormState>();
  late final _ar = TextEditingController(text: widget.nameAr);
  late final _en = TextEditingController(text: widget.nameEn);

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {'nameAr': _ar.text.trim(), 'nameEn': _en.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: placeLine, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2)),
            const SizedBox(height: 14),
            StaffField(
              controller: _ar,
              label: 'الاسم بالعربية',
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'الاسم مطلوب';
                if (t.length < 2) return 'الاسم قصير جداً';
                return null;
              },
            ),
            const SizedBox(height: 12),
            StaffField(
              controller: _en,
              label: 'الاسم بالإنجليزية (اختياري)',
              ltr: true,
              helper: 'يُستخدم الاسم العربي إن تُرك فارغاً',
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
          ],
        ),
      ),
    );
  }
}
