import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';

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
        _RoundIcon(icon: Icons.call_rounded, color: placeSuccess, onTap: () => callPhone(context, p), size: compact ? 34 : 40),
        const SizedBox(width: 6),
        _RoundIcon(icon: Icons.chat_rounded, color: const Color(0xFF16A34A), onTap: () => openWhatsApp(context, p), size: compact ? 34 : 40),
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

/// صف معلومة: عنوان — قيمة.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.ltr = false, this.valueColor, this.trailing});
  final String label;
  final String value;
  final bool ltr;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2)),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: ltr ? TextDirection.ltr : null,
            textAlign: TextAlign.start,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w800, color: valueColor ?? placeInk),
          ),
        ),
        ?trailing,
      ],
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
      style: style ?? const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 46, color: placeInk2.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: placeInk)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: placeInk2)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

/// بطاقة قائمة موحّدة قابلة للنقر.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.child, this.onTap, this.onLongPress, this.selected = false, this.highlight});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: selected ? placeBrass.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? placeBrass : (highlight ?? placeLine),
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

/// حقل بحث بتأخير (debounce).
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.onChanged, this.hint = 'بحث', this.initial = '', this.autofocus = false});
  final ValueChanged<String> onChanged;
  final String hint;
  final String initial;
  final bool autofocus;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _c,
        autofocus: widget.autofocus,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _debounce?.cancel();
          widget.onChanged(v.trim());
        },
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, color: placeInk2),
          suffixIcon: _c.text.isEmpty
              ? null
              : IconButton(
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, height: 1.5)),
            ],
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
            FilledButton(
              style: widget.danger ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(context, _c.text.trim());
              },
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
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
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: placeBrass)),
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

class PagedListController {
  _PagedListState? _state;
  Future<void> reload() => _state?._reload() ?? Future.value();
  List<Map<String, dynamic>> get items => _state?._items ?? const [];
  void replaceWhere(bool Function(Map<String, dynamic>) test, Map<String, dynamic>? next) => _state?._replace(test, next);
}

/// قائمة بتحميل لا نهائي + سحب للتحديث + حالات تحميل/فراغ/خطأ.
class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptySubtitle,
    this.controller,
    this.header,
    this.onLoaded,
    this.bottomPadding = 32,
  });

  final Future<PageResult> Function(int page) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> item, int index) itemBuilder;
  final String emptyTitle;
  final String? emptySubtitle;
  final PagedListController? controller;
  final Widget? header;
  final void Function(PageResult first)? onLoaded;
  final double bottomPadding;

  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _reload();
  }

  @override
  void didUpdateWidget(covariant PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final res = await widget.fetch(1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = 1;
        _totalPages = res.totalPages;
        _loading = false;
      });
      widget.onLoaded?.call(res);
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
      final res = await widget.fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(res.items);
        _page += 1;
        _totalPages = res.totalPages;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _replace(bool Function(Map<String, dynamic>) test, Map<String, dynamic>? next) {
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

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final children = <Widget>[?header];
    if (_loading) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 90),
        child: Center(child: CircularProgressIndicator(color: placeBrass)),
      ));
    } else if (_error != null) {
      children.add(ErrorRetry(message: _error!, onRetry: _reload));
    } else if (_items.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(title: widget.emptyTitle, subtitle: widget.emptySubtitle),
      ));
    }
    final showItems = !_loading && _error == null && _items.isNotEmpty;
    final extra = children.length;
    final count = extra + (showItems ? _items.length + 1 : 0);

    return RefreshIndicator(
      color: placeBrass,
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 320) _more();
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 4, bottom: widget.bottomPadding),
          itemCount: count,
          itemBuilder: (context, i) {
            if (i < extra) return children[i];
            final idx = i - extra;
            if (idx == _items.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass))),
                );
              }
              if (_page >= _totalPages && _items.length > 8) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('— نهاية القائمة —', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2))),
                );
              }
              return const SizedBox(height: 8);
            }
            return widget.itemBuilder(context, _items[idx], idx);
          },
        ),
      ),
    );
  }
}

/// عنوان قسم صغير داخل صفحة التفاصيل.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// شريط تنبيه ملوّن.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.text, this.color = placeShiftMorning, this.icon = Icons.info_outline_rounded, this.onTap, this.title});
  final String? title;
  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(title!, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: color)),
                      Text(text, style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: color, height: 1.5)),
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
  const FilterBar({super.key, required this.groups});
  final List<FilterGroup> groups;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      if (g > 0) {
        children.add(Container(width: 1, height: 22, color: placeLine, margin: const EdgeInsets.symmetric(horizontal: 6)));
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
            visualDensity: VisualDensity.compact,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              group.onSelected(o);
            },
            selectedColor: placeInk,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: sel ? Colors.white : placeInk, fontWeight: FontWeight.w700),
            side: BorderSide(color: sel ? placeInk : placeLine),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ));
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: children),
    );
  }
}
