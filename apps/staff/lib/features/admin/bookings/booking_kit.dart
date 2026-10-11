import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/shift.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';

/// أدوات مشتركة لمكتب الحجوزات (لوحة الإدارة على الهاتف).

// ───────────────────────── صلاحيات ─────────────────────────

bool get canReadBookings => Session.can('bookings.read');
bool get canWriteBookings => Session.can('bookings.write');

// ───────────────────────── أخطاء وبيانات ─────────────────────────

String errorText(Object e) => e is ApiException ? e.message : 'تعذّر الاتصال بالخادم، حاول مجدداً';

/// عناصر استجابة مُرقّمة `{items,total,page,pageSize,totalPages}`.
List<Map<String, dynamic>> pagedItems(dynamic data) {
  final raw = data is Map ? data['items'] : data;
  if (raw is! List) return const [];
  return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
}

int pagedTotalPages(dynamic data) => data is Map ? ((data['totalPages'] as num?)?.toInt() ?? 1) : 1;
int pagedTotal(dynamic data) => data is Map ? ((data['total'] as num?)?.toInt() ?? 0) : 0;

String buildQuery(Map<String, String?> params) {
  final clean = <String, String>{
    for (final e in params.entries)
      if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!.trim(),
  };
  if (clean.isEmpty) return '';
  return '?${Uri(queryParameters: clean).query}';
}

Map<String, dynamic>? asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

num? asNum(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

// ───────────────────────── تواريخ ─────────────────────────

/// تاريخ الحجز يُخزَّن كتاريخ فقط (منتصف الليل UTC) — نأخذ مكوّنات التاريخ دون تحويل المنطقة.
DateTime? parseDay(dynamic raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse('$raw');
  if (parsed == null) return null;
  // قيم UTC تُقرأ بمكوّناتها (لا تحويل للمحلي)، والنصوص "yyyy-MM-dd" تُقرأ كما هي.
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? parseStamp(dynamic raw) => raw == null ? null : DateTime.tryParse('$raw')?.toLocal();

String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String fmtDay(DateTime d) => DateFormat('EEEE d MMMM', 'ar').format(d);
String fmtShortDay(DateTime d) => DateFormat('d MMM', 'ar').format(d);
String fmtStamp(dynamic raw) {
  final d = parseStamp(raw);
  return d == null ? '—' : DateFormat('d MMM yyyy · HH:mm', 'ar').format(d);
}

/// عدد الأيام بين البداية والنهاية (النهاية حصرية كما في الخادم).
int dayCount(DateTime start, DateTime end) {
  final n = DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  return n < 1 ? 1 : n;
}

String daysLabel(int n) => switch (n) {
      1 => 'يوم واحد',
      2 => 'يومان',
      _ when n <= 10 => '$n أيام',
      _ => '$n يوماً',
    };

String fmtRange(dynamic startRaw, dynamic endRaw) {
  final s = parseDay(startRaw);
  final e = parseDay(endRaw);
  if (s == null) return '—';
  if (e == null) return fmtDay(s);
  final days = dayCount(s, e);
  if (days <= 1) return fmtDay(s);
  final last = e.subtract(const Duration(days: 1));
  return '${fmtShortDay(s)} – ${fmtShortDay(last)} · ${daysLabel(days)}';
}

// ───────────────────────── حالات ─────────────────────────

const allBookingStatuses = ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'DISPUTED'];

String statusLabel(String? raw) => raw == 'DISPUTED' ? 'نزاع' : bookingStatusAr(raw);

Color statusColor(String? raw) => switch (raw) {
      'PENDING' => placeShiftMorning,
      'AWAITING_PAYMENT' => placeBrass,
      'CONFIRMED' => placeSuccess,
      'COMPLETED' => const Color(0xFF2563EB),
      'CANCELLED' => placeInk2,
      'DISPUTED' => placeDanger,
      _ => placeInk2,
    };

IconData statusIcon(String? raw) => switch (raw) {
      'PENDING' => Icons.hourglass_top_rounded,
      'AWAITING_PAYMENT' => Icons.payments_outlined,
      'CONFIRMED' => Icons.verified_outlined,
      'COMPLETED' => Icons.task_alt_rounded,
      'CANCELLED' => Icons.block_rounded,
      'DISPUTED' => Icons.gavel_rounded,
      _ => Icons.circle_outlined,
    };

String originLabel(String? raw) => switch (raw) {
      'EXTERNAL' => 'حجز خارجي',
      'PLATFORM' => 'المنصة',
      _ => raw ?? '—',
    };

String paymentMethodAr(String? raw) => switch (raw) {
      'MANUAL' => 'يدوي / نقدي',
      'ZAIN_CASH' => 'زين كاش',
      'QI_CARD' => 'كي كارد',
      _ => raw ?? '—',
    };

String shiftShort(String? raw) => switch (raw) {
      'MORNING' => 'صباحي',
      'EVENING' => 'مسائي',
      _ => 'يوم كامل',
    };

/// الشفتات التي يقبلها المكان حسب وضع الحجز (مطابق لمنطق الخادم).
List<String> shiftsForProperty(Map? property) {
  final type = property?['type']?.toString();
  var mode = property?['bookingMode']?.toString();
  if (mode != 'FULL_DAY' && mode != 'SHIFTS' && mode != 'HYBRID') {
    mode = type == 'FARM' ? 'HYBRID' : 'FULL_DAY';
  }
  return switch (mode) {
    'FULL_DAY' => const ['FULL'],
    'SHIFTS' => const ['MORNING', 'EVENING'],
    _ => const ['FULL', 'MORNING', 'EVENING'],
  };
}

String guestName(Map row) {
  final user = asMap(row['user']);
  final name = (user?['name'] ?? row['guestName'])?.toString();
  return (name == null || name.trim().isEmpty) ? 'زبون بدون اسم' : name;
}

String? guestPhone(Map row) {
  final user = asMap(row['user']);
  final phone = (user?['phone'] ?? row['guestPhone'])?.toString();
  return (phone == null || phone.isEmpty) ? null : phone;
}

/// تطبيع رقم عراقي إلى 9647XXXXXXXXX (مطابق للوحة الويب).
String normalizeIraqiPhone(String raw) {
  var d = raw
      .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}')
      .replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('0') && d.length >= 10) {
    d = '964${d.substring(1)}';
  } else if (d.startsWith('7') && d.length == 10) {
    d = '964$d';
  }
  return d;
}

Future<void> callPhone(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final uri = Uri.parse(digits.startsWith('964') ? 'tel:+$digits' : 'tel:$digits');
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) showToast(context, 'تعذّر فتح الاتصال', error: true);
}

String mediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http') ? url : '$apiBase$url';
}

// ───────────────────────── حالات العرض ─────────────────────────

/// جسم قابل للسحب للتحديث مع حالات تحميل / خطأ / فراغ.
class AsyncList extends StatelessWidget {
  const AsyncList({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.onRefresh,
    required this.children,
    this.emptyTitle = 'لا توجد بيانات',
    this.emptySubtitle,
    this.header = const [],
    this.padding = const EdgeInsets.only(bottom: 32),
    this.controller,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final List<Widget> header;
  final String emptyTitle;
  final String? emptySubtitle;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final List<Widget> body;
    if (loading) {
      body = const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: placeBrass)),
      ];
    } else if (error != null) {
      body = [ErrorPanel(message: error!, onRetry: onRefresh)];
    } else if (isEmpty) {
      body = [EmptyState(title: emptyTitle, subtitle: emptySubtitle)];
    } else {
      body = children;
    }
    return RefreshIndicator(
      color: placeBrass,
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [...header, ...body],
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 46, color: placeDanger.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          const Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: placeInk2)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

/// زر "تحميل المزيد" في نهاية القوائم المرقّمة.
class LoadMoreTile extends StatelessWidget {
  const LoadMoreTile({super.key, required this.hasMore, required this.loading, required this.onPressed});
  final bool hasMore;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: loading
          ? const Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass)),
            )
          : OutlinedButton(onPressed: onPressed, child: const Text('تحميل المزيد')),
    );
  }
}

// ───────────────────────── عناصر واجهة ─────────────────────────

class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.label, required this.value, this.ltr = false, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final bool ltr;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: placeInk2),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2)),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: ltr ? TextDirection.ltr : null,
            textAlign: TextAlign.start,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w800, color: placeInk),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
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

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: statusLabel(status), color: statusColor(status), icon: statusIcon(status));
}

/// بطاقة حجز موحّدة للقوائم (القائمة المتقدّمة، التقويم …).
class BookingRowCard extends StatelessWidget {
  const BookingRowCard({
    super.key,
    required this.row,
    required this.onTap,
    this.onLongPress,
    this.selectable = false,
    this.selected = false,
  });

  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final property = asMap(row['property']);
    final payment = asMap(row['payment']);
    final city = asMap(property?['city'])?['nameAr']?.toString();
    final phone = guestPhone(row);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Material(
        color: selected ? placeBrass.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? placeBrass : placeLine, width: selected ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectable) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: selected ? placeBrass : placeInk2.withValues(alpha: 0.5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              property?['name']?.toString() ?? 'مكان محذوف',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BookingStatusPill(status: row['status']?.toString()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [guestName(row), ?phone].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Meta(icon: Icons.event_outlined, text: fmtRange(row['startDate'], row['endDate'])),
                          ShiftBadge(shift: row['shift']?.toString()),
                          if (row['origin'] == 'EXTERNAL') const StatusPill(label: 'خارجي', color: placeShiftEvening),
                          if (city != null) _Meta(icon: Icons.place_outlined, text: city),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatIqd(row['totalPrice']),
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: placeInk),
                          ),
                          if (payment != null)
                            StatusPill(
                              label: paymentStatusAr(payment['status']?.toString()),
                              color: paymentStatusColor(payment['status']?.toString()),
                            ),
                          if (row['guests'] != null)
                            _Meta(icon: Icons.people_outline, text: '${row['guests']} ضيف'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Icon(icon, size: 14, color: placeInk2),
          ),
        ),
        TextSpan(text: text),
      ]),
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk2),
    );
  }
}

/// خانة تاريخ قابلة للنقر.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.date, required this.onTap, this.onClear});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: date != null && onClear != null
              ? IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18))
              : const Icon(Icons.event_outlined, size: 19),
        ),
        child: Text(
          date == null ? 'اختر' : DateFormat('EEE d MMM yyyy', 'ar').format(date!),
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: date == null ? placeInk2 : placeInk),
        ),
      ),
    );
  }
}

Future<DateTime?> pickDay(BuildContext context, {DateTime? initial, DateTime? first}) {
  final now = DateTime.now();
  final firstDate = first ?? DateTime(now.year - 2);
  var init = initial ?? now;
  if (init.isBefore(firstDate)) init = firstDate;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: firstDate,
    lastDate: DateTime(now.year + 3),
  );
}

/// عدّاد أيام (+/-).
class DaysStepper extends StatelessWidget {
  const DaysStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 60, this.label = 'عدد الأيام'});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: placeLine),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk2)),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 17, fontWeight: FontWeight.w800, color: placeInk),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// اختيار الشفت حسب ما يدعمه المكان.
class ShiftChooser extends StatelessWidget {
  const ShiftChooser({super.key, required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ChoicePills<String>(
      options: options,
      value: value,
      labelOf: shiftLabel,
      iconOf: (s) => switch (s) {
        'MORNING' => Icons.wb_sunny_outlined,
        'EVENING' => Icons.nights_stay_outlined,
        _ => Icons.calendar_view_day_outlined,
      },
      onChanged: onChanged,
    );
  }
}

/// بطاقة عرض السعر (quote) — تتضمّن حالة التوفر والتعارض.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.quote, required this.loading, this.error, this.compareTo});
  final Map<String, dynamic>? quote;
  final bool loading;
  final String? error;

  /// السعر الحالي (لإظهار الفرق عند إعادة الجدولة).
  final num? compareTo;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _QuoteShell(
        color: placeInk2,
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: placeBrass)),
            SizedBox(width: 10),
            Text('جارٍ حساب السعر والتحقق من التوفر…', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2)),
          ],
        ),
      );
    }
    if (error != null) {
      return _QuoteShell(
        color: placeDanger,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: placeDanger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(error!, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeDanger)),
            ),
          ],
        ),
      );
    }
    final q = quote;
    if (q == null) {
      return const _QuoteShell(
        color: placeInk2,
        child: Text('أكمل الاختيارات لعرض السعر والتوفر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2)),
      );
    }
    final available = q['available'] == true;
    final total = asNum(q['totalPrice']) ?? 0;
    final original = asNum(q['originalTotal']);
    final discount = asNum(q['discount']) ?? 0;
    final diff = compareTo == null ? null : total - compareTo!;
    return _QuoteShell(
      color: available ? placeSuccess : placeDanger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(available ? Icons.event_available_rounded : Icons.event_busy_rounded, color: available ? placeSuccess : placeDanger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  available ? 'متاح للحجز' : 'غير متاح — يتعارض مع حجز قائم في نفس اليوم/الشفت',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: available ? placeSuccess : placeDanger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                formatIqd(total),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900, color: placeInk),
              ),
              if (discount > 0 && original != null)
                Text(
                  formatIqd(original),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: placeInk2,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ShiftBadge(shift: q['shift']?.toString()),
              StatusPill(label: daysLabel((asNum(q['nights']) ?? 1).toInt()), color: placeInk),
              if ((asNum(q['capacity']) ?? 0) > 0) StatusPill(label: 'السعة ${q['capacity']}', color: placeInk2),
              if (discount > 0) StatusPill(label: 'خصم ${formatIqd(discount)} (${q['couponCode'] ?? ''})', color: placeSuccess),
              if (diff != null && diff != 0)
                StatusPill(
                  label: diff > 0 ? 'زيادة ${formatIqd(diff)}' : 'نقص ${formatIqd(-diff)}',
                  color: diff > 0 ? placeShiftMorning : placeSuccess,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteShell extends StatelessWidget {
  const _QuoteShell({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

/// مُنفّذ تأخير بسيط للبحث / عرض السعر.
class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 400)]);
  final Duration delay;
  Timer? _timer;
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

// ───────────────────────── منتقيات ─────────────────────────

/// منتقي مكان: يستخدم `/api/admin/properties` عند توفر `properties.read`،
/// وإلا البحث العام `/api/admin/search` (يتطلب `bookings.read`).
Future<Map<String, dynamic>?> pickProperty(BuildContext context, {bool approvedOnly = true}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _SearchSheet(
      title: 'اختر المكان',
      hint: 'ابحث باسم المكان',
      minChars: Session.can('properties.read') ? 0 : 2,
      search: (q) async {
        if (Session.can('properties.read')) {
          final data = await Api.send('/api/admin/properties${buildQuery({
            'q': q,
            'status': approvedOnly ? 'APPROVED' : null,
            'pageSize': '30',
          })}');
          return pagedItems(data);
        }
        final data = await Api.map('/api/admin/search${buildQuery({'q': q})}');
        final rows = [
          for (final e in (data['properties'] as List? ?? const []))
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        return approvedOnly ? rows.where((r) => r['status'] == 'APPROVED').toList() : rows;
      },
      itemBuilder: (row) => ListTile(
        leading: CircleAvatar(
          backgroundColor: placeBrass.withValues(alpha: 0.12),
          child: Icon(placeTypeIcon(row['type']?.toString()), color: placeBrass, size: 20),
        ),
        title: Text(row['name']?.toString() ?? '—', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            placeTypeLabel(row['type']?.toString()),
            if (asMap(row['city'])?['nameAr'] != null) asMap(row['city'])!['nameAr'].toString(),
            if (row['pricePerDay'] != null) formatIqd(row['pricePerDay']),
          ].join(' · '),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        ),
      ),
    ),
  );
}

/// منتقي زبون من `/api/admin/users` (يتطلب `users.read`).
Future<Map<String, dynamic>?> pickCustomer(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _SearchSheet(
      title: 'اختر الزبون',
      hint: 'ابحث بالاسم أو رقم الهاتف',
      minChars: 0,
      search: (q) async {
        final data = await Api.send('/api/admin/users${buildQuery({'q': q, 'role': 'CUSTOMER', 'pageSize': '30'})}');
        return pagedItems(data);
      },
      itemBuilder: (row) {
        final count = asMap(row['_count'])?['bookings'];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: placeInk.withValues(alpha: 0.06),
            child: const Icon(Icons.person_outline_rounded, color: placeInk),
          ),
          title: Text(
            (row['name']?.toString().isNotEmpty ?? false) ? row['name'].toString() : 'بدون اسم',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [row['phone']?.toString() ?? '', if (count != null) '$count حجز'].join(' · '),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
          trailing: row['isActive'] == false ? const StatusPill(label: 'معطّل', color: placeDanger) : null,
        );
      },
    ),
  );
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({
    required this.title,
    required this.hint,
    required this.search,
    required this.itemBuilder,
    this.minChars = 0,
  });

  final String title;
  final String hint;
  final int minChars;
  final Future<List<Map<String, dynamic>>> Function(String q) search;
  final Widget Function(Map<String, dynamic> row) itemBuilder;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  final _debounce = Debouncer(const Duration(milliseconds: 350));
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.minChars == 0) _run('');
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    if (q.trim().length < widget.minChars) {
      setState(() {
        _rows = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.search(q.trim());
      if (!mounted || seq != _seq) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() => _error = errorText(e));
    }
    if (mounted && seq == _seq) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: placeLine, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: widget.minChars > 0,
                onChanged: (v) => _debounce.run(() => _run(v)),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: placeDanger)))
                  : _rows.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.trim().length < widget.minChars
                                ? 'اكتب حرفين على الأقل للبحث'
                                : (_loading ? '' : 'لا نتائج'),
                            style: const TextStyle(fontFamily: 'Cairo', color: placeInk2),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                          itemBuilder: (context, i) => InkWell(
                            onTap: () => Navigator.pop(context, _rows[i]),
                            child: widget.itemBuilder(_rows[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ورقة سفلية لاختيار حالة جديدة مع سبب/ملاحظة اختيارية.
class StatusChangeResult {
  const StatusChangeResult(this.status, this.note);
  final String status;
  final String note;
}

Future<StatusChangeResult?> showStatusSheet(
  BuildContext context, {
  required List<String> options,
  String? current,
  String title = 'تغيير حالة الحجز',
  String? subtitle,
}) {
  return showModalBottomSheet<StatusChangeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _StatusSheet(options: options, current: current, title: title, subtitle: subtitle),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.options, required this.title, this.current, this.subtitle});
  final List<String> options;
  final String? current;
  final String title;
  final String? subtitle;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  String? _status;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cancelling = _status == 'CANCELLED';
    final marksPaid = _status == 'CONFIRMED' || _status == 'COMPLETED';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900)),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: const TextStyle(fontFamily: 'Cairo', color: placeInk2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.options)
                ChoiceChip(
                  avatar: Icon(statusIcon(s), size: 16, color: _status == s ? Colors.white : statusColor(s)),
                  label: Text(statusLabel(s)),
                  selected: _status == s,
                  onSelected: s == widget.current ? null : (_) => setState(() => _status = s),
                  selectedColor: statusColor(s),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: _status == s ? Colors.white : (s == widget.current ? placeInk2 : placeInk),
                  ),
                  side: const BorderSide(color: placeLine),
                ),
            ],
          ),
          if (marksPaid) ...[
            const SizedBox(height: 10),
            const _Hint(icon: Icons.info_outline_rounded, text: 'سيُعتبر الدفع «مدفوعاً» تلقائياً عند التأكيد أو الإكمال.', color: placeShiftEvening),
          ],
          if (cancelling) ...[
            const SizedBox(height: 10),
            const _Hint(icon: Icons.warning_amber_rounded, text: 'الإلغاء يحرّر التاريخ ويُشعر الزبون والمزوّد.', color: placeDanger),
          ],
          const SizedBox(height: 12),
          StaffField(
            controller: _note,
            label: cancelling ? 'سبب الإلغاء' : 'ملاحظة إدارية (اختياري)',
            hint: 'تُضاف إلى ملاحظات الحجز',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: cancelling ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
            onPressed: _status == null ? null : () => Navigator.pop(context, StatusChangeResult(_status!, _note.text.trim())),
            child: Text(_status == null ? 'اختر الحالة' : 'تطبيق: ${statusLabel(_status)}'),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }
}
