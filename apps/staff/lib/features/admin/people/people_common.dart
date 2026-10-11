import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';

/// أدوات مشتركة لشاشات «الناس والمال» (الزبائن، المزودون، المدفوعات، النزاعات).

// ───────────────────────── تنسيق ─────────────────────────

String errorText(Object e) => e is ApiException ? e.message : 'تعذّر الاتصال — تحقّق من الشبكة';

String buildPath(String path, Map<String, Object?> query) {
  final parts = <String>[];
  query.forEach((key, value) {
    if (value == null) return;
    final v = '$value'.trim();
    if (v.isEmpty) return;
    parts.add('$key=${Uri.encodeQueryComponent(v)}');
  });
  return parts.isEmpty ? path : '$path?${parts.join('&')}';
}

DateTime? parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse('$raw')?.toLocal();
}

String fmtDate(dynamic raw) {
  final d = parseDate(raw);
  return d == null ? '—' : DateFormat('d MMM yyyy', 'ar').format(d);
}

String fmtDateTime(dynamic raw) {
  final d = parseDate(raw);
  return d == null ? '—' : DateFormat('d MMM yyyy · HH:mm', 'ar').format(d);
}

/// تاريخ يومي (startDate/endDate مخزّنة كـ Date فقط — لا نحوّلها للتوقيت المحلي).
String fmtDay(dynamic raw) {
  if (raw == null) return '—';
  final d = DateTime.tryParse('$raw');
  return d == null ? '—' : DateFormat('EEE d MMM', 'ar').format(d);
}

String relativeAr(dynamic raw) {
  final d = parseDate(raw);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
  return DateFormat('d MMM', 'ar').format(d);
}

/// رابط مطلق للوسائط (الإثباتات قد تُخزَّن بمسار نسبي).
String? absUrl(dynamic raw) {
  final u = raw?.toString();
  if (u == null || u.isEmpty) return null;
  if (u.startsWith('http')) return u;
  return u.startsWith('/') ? '$apiBase$u' : '$apiBase/$u';
}

int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String, dynamic> asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

String nonEmpty(dynamic v, [String fallback = '—']) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

// ───────────────────────── تسميات ─────────────────────────

String roleLabel(String? role) => switch (role) {
      'CUSTOMER' => 'زبون',
      'PROVIDER' => 'مزود',
      'STAFF' => 'موظف',
      'ADMIN' => 'مدير',
      _ => role ?? '—',
    };

Color roleColor(String? role) => switch (role) {
      'PROVIDER' => placeBrass,
      'STAFF' => placeShiftEvening,
      'ADMIN' => placeInk,
      _ => const Color(0xFF2563EB),
    };

String kycLabel(String? kyc, {bool verified = false}) {
  if (verified) return 'موثّق';
  return switch (kyc) {
    'PENDING' => 'بانتظار التوثيق',
    'VERIFIED' => 'موثّق',
    'REJECTED' => 'مرفوض',
    'UNVERIFIED' => 'غير موثّق',
    _ => kyc ?? '—',
  };
}

Color kycColor(String? kyc, {bool verified = false}) {
  if (verified) return placeSuccess;
  return switch (kyc) {
    'PENDING' => placeShiftMorning,
    'VERIFIED' => placeSuccess,
    'REJECTED' => placeDanger,
    _ => placeInk2,
  };
}

String methodLabel(String? m) => switch (m) {
      'MANUAL' => 'تحويل يدوي',
      'ZAIN_CASH' => 'زين كاش',
      'QI_CARD' => 'كي كارد',
      _ => m ?? '—',
    };

IconData methodIcon(String? m) => switch (m) {
      'ZAIN_CASH' => Icons.phone_iphone_rounded,
      'QI_CARD' => Icons.credit_card_rounded,
      _ => Icons.account_balance_outlined,
    };

String bookingStatusLabel(String? s) => switch (s) {
      'PENDING' => 'بانتظار التأكيد',
      'AWAITING_PAYMENT' => 'بانتظار الدفع',
      'CONFIRMED' => 'مؤكد',
      'COMPLETED' => 'مكتمل',
      'CANCELLED' => 'ملغى',
      'DISPUTED' => 'نزاع',
      _ => s ?? '—',
    };

Color bookingStatusColor(String? s) => switch (s) {
      'CONFIRMED' => placeSuccess,
      'COMPLETED' => const Color(0xFF2563EB),
      'PENDING' => placeShiftMorning,
      'AWAITING_PAYMENT' => const Color(0xFFB45309),
      'CANCELLED' => placeInk2,
      'DISPUTED' => placeDanger,
      _ => placeInk2,
    };

String requestStatusLabel(String? s) => switch (s) {
      'PENDING' => 'قيد المراجعة',
      'APPROVED' => 'مقبول',
      'REJECTED' => 'مرفوض',
      'CANCELLED' => 'ملغى',
      _ => s ?? '—',
    };

Color requestStatusColor(String? s) => switch (s) {
      'APPROVED' => placeSuccess,
      'REJECTED' => placeDanger,
      'PENDING' => placeShiftMorning,
      _ => placeInk2,
    };

// ───────────────────────── اتصال ─────────────────────────

Future<void> callPhone(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) return;
  HapticFeedback.selectionClick();
  final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}');
  try {
    if (!await launchUrl(uri)) throw Exception();
  } catch (_) {
    if (context.mounted) showToast(context, 'تعذّر فتح الاتصال', error: true);
  }
}

Future<void> openWhatsApp(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) return;
  HapticFeedback.selectionClick();
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  // 07xxxxxxxxx → 9647xxxxxxxxx
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0') && digits.length == 11) digits = '964${digits.substring(1)}';
  final uri = Uri.parse('https://wa.me/$digits');
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception();
  } catch (_) {
    if (context.mounted) showToast(context, 'تعذّر فتح واتساب', error: true);
  }
}

/// زرّا اتصال وواتساب صغيران.
class PhoneButtons extends StatelessWidget {
  const PhoneButtons({super.key, required this.phone, this.compact = false});

  final String? phone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = phone;
    if (p == null || p.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIcon(icon: Icons.call_rounded, color: placeSuccess, onTap: () => callPhone(context, p), size: compact ? 40 : 44),
        const SizedBox(width: 6),
        _RoundIcon(icon: Icons.chat_rounded, color: const Color(0xFF16A34A), onTap: () => openWhatsApp(context, p), size: compact ? 40 : 44),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.onTap, this.size = 40});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.48, color: color)),
      ),
    );
  }
}

/// زر إجراء عريض بأيقونة (اتصال / واتساب / محادثة …).
class ActionChipButton extends StatelessWidget {
  const ActionChipButton({super.key, required this.icon, required this.label, required this.onTap, this.color = placeInk});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Column(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── عناصر واجهة ─────────────────────────

/// صف تفاصيل: عنوان — قيمة (بنمط InfoRow في kit) مع دعم LTR وعنصر طرفي.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.ltr = false, this.valueColor, this.trailing, this.icon});
  final String label;
  final String value;
  final bool ltr;
  final Color? valueColor;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: placeInk3), const SizedBox(width: 10)],
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: placeInk2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: ltr ? TextAlign.left : TextAlign.end,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w800, color: valueColor ?? placeInk),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// بطاقة قسم في صفحة تفاصيل: عنوان بأيقونة + محتوى، بهامش الصفحة.
class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.title, required this.children, this.icon, this.subtitle, this.trailing, this.color = placeInk});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Pad(
      child: StaffCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[IconBox(icon: icon!, color: color, size: 34), const SizedBox(width: 10)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                      if (subtitle != null)
                        Text(subtitle!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// نص هاتف باتجاه LTR.
class PhoneText extends StatelessWidget {
  const PhoneText(this.phone, {super.key, this.style});
  final String? phone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      phone ?? '',
      textDirection: TextDirection.ltr,
      style: style ?? const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
    );
  }
}

/// حالة خطأ مع زر إعادة المحاولة.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
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
            decoration: BoxDecoration(color: placeDanger.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 34, color: placeDanger),
          ),
          const SizedBox(height: 14),
          const Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, height: 1.5)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

/// بطاقة قائمة موحّدة قابلة للنقر (بيضاء، زوايا 20، حدود رفيعة).
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.child, this.onTap, this.onLongPress, this.selected = false, this.highlight});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(StaffRadius.lg);
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 10),
      child: Material(
        color: selected ? placeGoldSoft : Colors.white,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          onLongPress: onLongPress,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(
                color: selected ? placeGold : (highlight ?? placeLine),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// محتوى صف قائمة قياسي: عنصر بادئ، عنوان، وصف، شارات، وعنصر طرفي.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.titleBadge,
    this.subtitle,
    this.subtitleWidget,
    this.chips = const [],
    this.trailing,
    this.chevron = false,
  });
  final Widget leading;
  final String title;
  final Widget? titleBadge;
  final String? subtitle;
  final Widget? subtitleWidget;
  final List<Widget> chips;
  final Widget? trailing;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk),
                    ),
                  ),
                  if (titleBadge != null) ...[const SizedBox(width: 4), titleBadge!],
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
                ),
              ?subtitleWidget,
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: chips),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (chevron) ...[const SizedBox(width: 4), const Icon(Icons.chevron_left_rounded, color: placeInk3)],
      ],
    );
  }
}

/// نص بيانات ثانوي (تاريخ/مبلغ) على طرف الصف.
class MetaText extends StatelessWidget {
  const MetaText(this.text, {super.key, this.color = placeInk3, this.strong = false});
  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: strong ? 14 : 11.5,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          color: strong ? placeInk : color,
        ),
      );
}

/// حقل بحث بتأخير (debounce).
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.onChanged,
    this.hint = 'بحث',
    this.initial = '',
    this.autofocus = false,
    this.padding = const EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 0),
  });
  final ValueChanged<String> onChanged;
  final String hint;
  final String initial;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  /// حشوة الحقل عند تثبيته أسفل رأس [PagedStaffPage].
  static const barPadding = EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 4);

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => widget.onChanged(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(StaffRadius.md),
      borderSide: const BorderSide(color: placeLine),
    );
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _c,
        autofocus: widget.autofocus,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _debounce?.cancel();
          widget.onChanged(v.trim());
        },
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: placeInk),
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: const BorderSide(color: placeGold, width: 1.5)),
          prefixIcon: const Icon(Icons.search_rounded, color: placeInk2),
          suffixIcon: _c.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _c.clear();
                    _changed('');
                  },
                ),
        ),
      ),
    );
  }
}

/// ورقة سفلية بحقل إدخال (مع قيمة أولية وتحقق).
Future<String?> showInputSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String label = '',
  String initial = '',
  String hint = '',
  String confirmLabel = 'حفظ',
  bool required = false,
  int minLength = 0,
  int maxLines = 1,
  bool danger = false,
  TextInputType? keyboard,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
    builder: (_) => _InputSheet(
      title: title,
      subtitle: subtitle,
      label: label,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      required: required,
      minLength: minLength,
      maxLines: maxLines,
      danger: danger,
      keyboard: keyboard,
    ),
  );
}

class _InputSheet extends StatefulWidget {
  const _InputSheet({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.required,
    required this.minLength,
    required this.maxLines,
    required this.danger,
    required this.keyboard,
  });
  final String title;
  final String? subtitle;
  final String label;
  final String initial;
  final String hint;
  final String confirmLabel;
  final bool required;
  final int minLength;
  final int maxLines;
  final bool danger;
  final TextInputType? keyboard;

  @override
  State<_InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<_InputSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(widget.title, subtitle: widget.subtitle),
            StaffField(
              controller: _c,
              label: widget.label,
              hint: widget.hint,
              maxLines: widget.maxLines,
              keyboard: widget.keyboard,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (widget.required && t.isEmpty) return 'هذا الحقل مطلوب';
                if (t.isNotEmpty && t.length < widget.minLength) return 'اكتب ${widget.minLength} أحرف على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: widget.danger ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(context, _c.text.trim());
                },
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// غلاف محتوى الأوراق السفلية: هامش موحّد + مقبض + مراعاة لوحة المفاتيح.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const SheetHandle(), Flexible(child: SingleChildScrollView(child: child))],
      ),
    );
  }
}

/// عنوان ورقة سفلية مع وصف اختياري.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: placeLine, borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

/// شريط سفلي ثابت بإطار موحّد (نفس مظهر BottomActionBar) لمحتوى مخصّص.
class ActionBarShell extends StatelessWidget {
  const ActionBarShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 12, StaffSpace.page, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
        boxShadow: [BoxShadow(color: Color(0x120F1B2D), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: child,
    );
  }
}

/// زر شريط سفلي بارتفاع 50 (ممتلئ أو محدد) بلون اختياري.
class BarButton extends StatelessWidget {
  const BarButton({super.key, required this.label, required this.onPressed, this.icon, this.color, this.outlined = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);
    final Widget button;
    if (outlined) {
      final style = OutlinedButton.styleFrom(
        foregroundColor: color,
        side: color == null ? null : BorderSide(color: color!.withValues(alpha: 0.6)),
      );
      button = icon == null
          ? OutlinedButton(style: style, onPressed: onPressed, child: text)
          : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 19), label: text);
    } else {
      final style = color == null ? null : FilledButton.styleFrom(backgroundColor: color);
      button = icon == null
          ? FilledButton(style: style, onPressed: onPressed, child: text)
          : FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 19), label: text);
    }
    return SizedBox(height: 50, child: button);
  }
}

/// تنفيذ إجراء مع رسالة نجاح/خطأ موحّدة. يُرجع true عند النجاح.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (context.mounted && success != null) showToast(context, success);
    HapticFeedback.mediumImpact();
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, errorText(e), error: true);
    return false;
  }
}

/// حوار انشغال أثناء تنفيذ عملية حساسة.
Future<T?> withBusy<T>(BuildContext context, Future<T> Function() task) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(StaffRadius.lg)),
          child: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: placeGold)),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

// ───────────────────────── قائمة مُرقّمة ─────────────────────────

class PageResult {
  PageResult({required this.items, required this.total, required this.totalPages, required this.raw});
  final List<Map<String, dynamic>> items;
  final int total;
  final int totalPages;
  final Map<String, dynamic> raw;
}

Future<PageResult> fetchPage(String path, Map<String, Object?> query, {int page = 1, int pageSize = 20}) async {
  final data = await Api.send(buildPath(path, {...query, 'page': page, 'pageSize': pageSize}));
  if (data is List) {
    final items = asMapList(data);
    return PageResult(items: items, total: items.length, totalPages: 1, raw: const {});
  }
  final map = asMap(data);
  return PageResult(
    items: asMapList(map['items']),
    total: asInt(map['total']),
    totalPages: asInt(map['totalPages']) == 0 ? 1 : asInt(map['totalPages']),
    raw: map,
  );
}

abstract class _PagedHost {
  Future<void> reloadList();
  List<Map<String, dynamic>> get listItems;
  void replaceItem(bool Function(Map<String, dynamic>) test, Map<String, dynamic>? next);
}

class PagedListController {
  _PagedHost? _state;
  Future<void> reload() => _state?.reloadList() ?? Future.value();
  List<Map<String, dynamic>> get items => _state?.listItems ?? const [];
  void replaceWhere(bool Function(Map<String, dynamic>) test, Map<String, dynamic>? next) => _state?.replaceItem(test, next);
}

/// منطق التحميل المرقّم المشترك بين [PagedList] و[PagedStaffPage].
mixin _PagedLogic<T extends StatefulWidget> on State<T> implements _PagedHost {
  Future<PageResult> Function(int page) get pagedFetch;
  void Function(PageResult first)? get pagedOnLoaded;
  PagedListController? get pagedController;

  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  void _bind() => pagedController?._state = this;

  void _rebind(PagedListController? old) {
    if (old == pagedController) return;
    if (old?._state == this) old?._state = null;
    _bind();
  }

  void _unbind() {
    if (pagedController?._state == this) pagedController?._state = null;
  }

  @override
  List<Map<String, dynamic>> get listItems => _items;

  @override
  Future<void> reloadList() => _reload();

  /// إعادة التحميل من البداية؛ [reset] يمسح العناصر ويُظهر الهياكل (عند تغيير الفلاتر).
  Future<void> _reload({bool reset = false}) async {
    final gen = ++_generation;
    setState(() {
      if (reset) {
        _items.clear();
        _page = 0;
        _totalPages = 1;
        _loadingMore = false;
      }
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final res = await pagedFetch(1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = 1;
        _totalPages = res.totalPages;
        _loading = false;
      });
      pagedOnLoaded?.call(res);
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
        _items.clear();
      });
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _loading || _page >= _totalPages) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final res = await pagedFetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(res.items);
        _page += 1;
        _totalPages = res.totalPages;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
    if (mounted && gen == _generation) setState(() => _loadingMore = false);
  }

  @override
  void replaceItem(bool Function(Map<String, dynamic>) test, Map<String, dynamic>? next) {
    setState(() {
      final i = _items.indexWhere(test);
      if (i < 0) return;
      if (next == null) {
        _items.removeAt(i);
      } else {
        _items[i] = next;
      }
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 320) _more();
    return false;
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold))),
      );
    }
    if (_page >= _totalPages && _items.length > 8) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('— نهاية القائمة —', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk3))),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// قائمة بتحميل لا نهائي + سحب للتحديث + حالات تحميل (هياكل)/فراغ/خطأ.
/// للاستخدام داخل جسم شاشة أو ورقة سفلية؛ للصفحات الكاملة استخدم [PagedStaffPage].
class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.controller,
    this.header,
    this.onLoaded,
    this.bottomPadding = 32,
    this.skeletonHeight = 76,
  });

  final Future<PageResult> Function(int page) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> item, int index) itemBuilder;
  final String emptyTitle;
  final String? emptySubtitle;
  final IconData emptyIcon;
  final PagedListController? controller;
  final Widget? header;
  final void Function(PageResult first)? onLoaded;
  final double bottomPadding;
  final double skeletonHeight;

  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> with _PagedLogic<PagedList> {
  @override
  Future<PageResult> Function(int page) get pagedFetch => widget.fetch;
  @override
  void Function(PageResult first)? get pagedOnLoaded => widget.onLoaded;
  @override
  PagedListController? get pagedController => widget.controller;

  @override
  void initState() {
    super.initState();
    _bind();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebind(oldWidget.controller);
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final children = <Widget>[?header];
    if (_loading) {
      for (var i = 0; i < 6; i++) {
        children.add(Pad(bottom: 10, child: SkeletonBox(height: widget.skeletonHeight)));
      }
    } else if (_error != null) {
      children.add(ErrorRetry(message: _error!, onRetry: _reload));
    } else if (_items.isEmpty) {
      children.add(EmptyView(icon: widget.emptyIcon, title: widget.emptyTitle, subtitle: widget.emptySubtitle));
    }
    final showItems = !_loading && _error == null && _items.isNotEmpty;
    final extra = children.length;
    final count = extra + (showItems ? _items.length + 1 : 0);

    return RefreshIndicator(
      color: placeGold,
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.only(top: 8, bottom: widget.bottomPadding),
          itemCount: count,
          itemBuilder: (context, i) {
            if (i < extra) return children[i];
            final idx = i - extra;
            if (idx == _items.length) return _footer();
            return widget.itemBuilder(context, _items[idx], idx);
          },
        ),
      ),
    );
  }
}

/// صفحة قائمة كاملة بنمط [StaffPage]: رأس كبير، بحث وشرائح فلترة مثبّتة،
/// هياكل تحميل، حالة فارغة، تحميل لا نهائي وسحب للتحديث.
/// غيّر [resetKey] عند تغيير البحث/الفلاتر لإعادة التحميل من البداية.
class PagedStaffPage extends StatefulWidget {
  const PagedStaffPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBack,
    this.search,
    this.filters,
    this.listHeader,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.controller,
    this.onLoaded,
    this.resetKey,
    this.floatingActionButton,
    this.bottomBar,
    this.skeletonHeight = 86,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool? showBack;

  /// حقل البحث (عادة [SearchBox] بحشوة [SearchBox.barPadding]) — مثبّت أسفل الرأس.
  final Widget? search;

  /// شريط الفلاتر (عادة [FilterBar]) — مثبّت أسفل البحث.
  final Widget? filters;

  /// عنصر فوق القائمة (تنبيهات، عدد النتائج…).
  final Widget? listHeader;

  final Future<PageResult> Function(int page) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> item, int index) itemBuilder;
  final String emptyTitle;
  final String? emptySubtitle;
  final IconData emptyIcon;
  final PagedListController? controller;
  final void Function(PageResult first)? onLoaded;
  final Object? resetKey;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final double skeletonHeight;

  static const searchHeight = 60.0;
  static const filtersHeight = 52.0;

  @override
  State<PagedStaffPage> createState() => _PagedStaffPageState();
}

class _PagedStaffPageState extends State<PagedStaffPage> with _PagedLogic<PagedStaffPage> {
  @override
  Future<PageResult> Function(int page) get pagedFetch => widget.fetch;
  @override
  void Function(PageResult first)? get pagedOnLoaded => widget.onLoaded;
  @override
  PagedListController? get pagedController => widget.controller;

  @override
  void initState() {
    super.initState();
    _bind();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PagedStaffPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebind(oldWidget.controller);
    if (oldWidget.resetKey != widget.resetKey) {
      _reload(reset: true);
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  PreferredSizeWidget? _bottom() {
    final search = widget.search;
    final filters = widget.filters;
    if (search == null && filters == null) return null;
    final h = (search == null ? 0.0 : PagedStaffPage.searchHeight) + (filters == null ? 0.0 : PagedStaffPage.filtersHeight);
    return PreferredSize(
      preferredSize: Size.fromHeight(h),
      child: SizedBox(
        height: h,
        child: Column(
          children: [
            if (search != null) SizedBox(height: PagedStaffPage.searchHeight, child: search),
            if (filters != null) SizedBox(height: PagedStaffPage.filtersHeight, child: Align(alignment: AlignmentDirectional.centerStart, child: filters)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listHeader = widget.listHeader;
    final slivers = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 10)),
      if (listHeader != null) SliverToBoxAdapter(child: listHeader),
      if (_loading)
        SkeletonSliver(count: 6, height: widget.skeletonHeight)
      else if (_error != null)
        SliverToBoxAdapter(child: ErrorRetry(message: _error!, onRetry: _reload))
      else if (_items.isEmpty)
        SliverToBoxAdapter(child: EmptyView(icon: widget.emptyIcon, title: widget.emptyTitle, subtitle: widget.emptySubtitle))
      else ...[
        SliverList.builder(
          itemCount: _items.length,
          itemBuilder: (context, i) => widget.itemBuilder(context, _items[i], i),
        ),
        SliverToBoxAdapter(child: _footer()),
      ],
      if (widget.floatingActionButton != null) const SliverToBoxAdapter(child: SizedBox(height: 72)),
    ];
    return Scaffold(
      bottomNavigationBar: widget.bottomBar,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: StaffPage(
          title: widget.title,
          subtitle: widget.subtitle,
          actions: widget.actions,
          leading: widget.leading,
          showBack: widget.showBack,
          bottom: _bottom(),
          onRefresh: _reload,
          floatingActionButton: widget.floatingActionButton,
          slivers: slivers,
        ),
      ),
    );
  }
}

/// عنوان قسم داخل صفحة التفاصيل (بنمط SectionHeader في kit) مع عنصر طرفي.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.count});
  final String text;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 18, StaffSpace.page, 10),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk)),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 8),
            CountBadge(count!, color: placeInk2),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// شريط تنبيه ملوّن.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.text, this.color = placeWarning, this.icon = Icons.info_outline_rounded, this.onTap, this.title});
  final String? title;
  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(StaffRadius.md);
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 10),
      child: Material(
        color: color.withValues(alpha: 0.07),
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: r, border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Row(
              children: [
                IconBox(icon: icon, color: color, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(title!, style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w900, color: color)),
                      Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w600, color: placeInk2, height: 1.5)),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_left_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مجموعة شرائح فلترة مدمجة (عدة مجموعات في صف واحد قابل للتمرير).
class FilterGroup {
  const FilterGroup({required this.options, required this.selected, required this.onSelected, required this.labelOf});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String Function(String) labelOf;
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.groups, this.padding = const EdgeInsets.fromLTRB(StaffSpace.page, 6, StaffSpace.page, 4)});
  final List<FilterGroup> groups;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      if (g > 0) {
        children.add(Container(width: 1, height: 22, color: placeLine, margin: const EdgeInsetsDirectional.only(start: 2, end: 8)));
      }
      final group = groups[g];
      for (final o in group.options) {
        final sel = group.selected == o;
        children.add(Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: ChoiceChip(
            label: Text(group.labelOf(o)),
            selected: sel,
            showCheckmark: false,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              group.onSelected(o);
            },
            selectedColor: placeInk,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: sel ? Colors.white : placeInk, fontWeight: FontWeight.w800),
            side: BorderSide(color: sel ? placeInk : placeLine),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ));
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(children: children),
    );
  }
}
