import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';

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

/// عنوان يوم لتجميع القوائم الزمنية: اليوم / أمس / التاريخ.
String dayHeaderAr(dynamic raw) {
  final d = parseDate(raw);
  if (d == null) return 'بدون تاريخ';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  if (d.year == now.year) return DateFormat('EEEE d MMMM', 'ar').format(d);
  return DateFormat('d MMMM yyyy', 'ar').format(d);
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

/// أنماط نصية موحّدة لصفوف القوائم.
const catalogTitleStyle = TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk);
const catalogSubtitleStyle = TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2);
const catalogMetaStyle = TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk3);

/// شريط تقدّم رفيع أسفل رأس الصفحة أثناء تنفيذ إجراء.
PreferredSizeWidget? catalogBusyBar(bool busy) => busy
    ? const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: LinearProgressIndicator(minHeight: 2, color: placeGold, backgroundColor: Colors.transparent),
      )
    : null;

/// حالة الخطأ مع زر إعادة المحاولة — تُوضع داخل SliverFillRemaining أو أي حاوية.
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: placeDanger.withValues(alpha: .08), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 34, color: placeDanger),
          ),
          const SizedBox(height: 14),
          const Text(
            'تعذّر التحميل',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

/// هيكل تحميل (عمود من مستطيلات نابضة) — للحاويات غير الـ sliver.
class CatalogLoadingView extends StatelessWidget {
  const CatalogLoadingView({super.key, this.count = 5, this.height = 76});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SkeletonBox(height: height),
          ],
        ],
      ),
    );
  }
}

/// شريط "عرض فقط" عند غياب صلاحية التعديل.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key, this.text = 'عرض فقط — ليست لديك صلاحية التعديل في هذا القسم'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: placeGoldSoft,
          borderRadius: BorderRadius.circular(StaffRadius.md),
          border: Border.all(color: placeBrass.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const IconBox(icon: Icons.visibility_outlined, color: placeBrass, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط تنبيه ملوّن (مثل وضع الصيانة) قابل للضغط اختيارياً.
class CatalogAlertBanner extends StatelessWidget {
  const CatalogAlertBanner({super.key, required this.text, required this.icon, this.color = placeDanger, this.onTap});

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pad(
      top: 4,
      bottom: 8,
      child: StaffCard(
        onTap: onTap,
        color: color.withValues(alpha: .06),
        borderColor: color.withValues(alpha: .3),
        radius: StaffRadius.md,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconBox(icon: icon, color: color, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ),
            if (onTap != null) Icon(Icons.chevron_left_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

/// حقل بحث مستدير بطابع الـ kit.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(StaffRadius.md),
      borderSide: const BorderSide(color: placeLine),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: placeInk3),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: placeGold, width: 1.4)),
            prefixIcon: const Icon(Icons.search_rounded, color: placeInk2),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح',
                    icon: const Icon(Icons.close_rounded, size: 18, color: placeInk2),
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

/// سطر صغير يلخّص عدد النتائج مع عنصر اختياري على الطرف.
class CatalogResultsLine extends StatelessWidget {
  const CatalogResultsLine({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page + 4, 0, StaffSpace.page, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Expanded(child: Text(text, style: catalogSubtitleStyle.copyWith(fontWeight: FontWeight.w800))),
            ?trailing,
          ],
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk, fontWeight: FontWeight.w800),
            ),
          ),
          if (value.isNotEmpty)
            IconButton(
              tooltip: 'نسخ',
              icon: const Icon(Icons.copy_rounded, size: 16, color: placeInk3),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                showToast(context, 'تم النسخ');
              },
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// خيار في ورقة إجراءات سفلية.
class SheetAction {
  const SheetAction(this.value, this.label, this.icon, {this.danger = false, this.enabled = true});

  final String value;
  final String label;
  final IconData icon;
  final bool danger;
  final bool enabled;
}

/// ورقة إجراءات سفلية موحّدة تعيد قيمة الخيار المختار.
Future<String?> showActionSheet(BuildContext context, {required String title, required List<SheetAction> actions}) {
  return showStaffSheet<String>(
    context,
    title: title,
    child: SingleChildScrollView(
      child: TileGroup(
        children: [
          for (final a in actions)
            Opacity(
              opacity: a.enabled ? 1 : .45,
              child: TaskTile(
                icon: a.icon,
                title: a.label,
                color: a.danger ? placeDanger : placeInk,
                onTap: a.enabled ? () => Navigator.of(context).pop(a.value) : null,
                trailing: const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    ),
  );
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
    useSafeArea: true,
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
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
              if (widget.subtitle != null)
                Text(widget.subtitle!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: placeInk2)),
              const SizedBox(height: 16),
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
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
