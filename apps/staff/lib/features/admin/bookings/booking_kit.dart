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
import '../../../widgets/kit.dart';
import '../../chat_room.dart';

/// ═══════════════════════════════════════════════════════════
/// أدوات مشتركة لمكتب الحجوزات: بيانات، تواريخ، حالات، وبطاقات
/// وأوراق سفلية مبنية على مكوّنات «VIBES مكتب» (kit.dart).
/// ═══════════════════════════════════════════════════════════

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

/// «اليوم» / «غداً» / «أمس» أو اسم اليوم والتاريخ.
String relativeDayLabel(DateTime d) {
  final today = dayOnly(DateTime.now());
  final diff = dayOnly(d).difference(today).inDays;
  return switch (diff) {
    0 => 'اليوم',
    1 => 'غداً',
    -1 => 'أمس',
    _ => fmtDay(d),
  };
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
      'PENDING' => placeWarning,
      'AWAITING_PAYMENT' => placeBrass,
      'CONFIRMED' => placeSuccess,
      'COMPLETED' => placeInfo,
      'CANCELLED' => placeInk3,
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

String statusHint(String? raw) => switch (raw) {
      'PENDING' => 'ينتظر مراجعة الفريق',
      'AWAITING_PAYMENT' => 'بانتظار وصول الدفع',
      'CONFIRMED' => 'الموعد محجوز ومؤكد',
      'COMPLETED' => 'تمت الزيارة وأُغلق الحجز',
      'CANCELLED' => 'أُلغي وتحرّر الموعد',
      'DISPUTED' => 'نزاع مفتوح قيد المراجعة',
      _ => '',
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

IconData shiftIcon(String? raw) => switch (raw) {
      'MORNING' => Icons.wb_sunny_rounded,
      'EVENING' => Icons.nights_stay_rounded,
      _ => Icons.calendar_view_day_rounded,
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

/// معرّف حساب الزبون (للمحادثة) إن وُجد.
String? guestUserId(Map row) {
  final id = (asMap(row['user'])?['id'] ?? row['userId'])?.toString();
  return (id == null || id.isEmpty) ? null : id;
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
  HapticFeedback.selectionClick();
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final uri = Uri.parse(digits.startsWith('964') ? 'tel:+$digits' : 'tel:$digits');
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) showToast(context, 'تعذّر فتح الاتصال', error: true);
}

/// فتح محادثة الزبون (يتطلب `inbox.read` ومعرّف حساب).
Future<void> openGuestChat(BuildContext context, Map row) async {
  final id = guestUserId(row);
  if (id == null || !Session.can('inbox.read')) return;
  HapticFeedback.selectionClick();
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChatRoomScreen(
      contactUserId: id,
      contactName: guestName(row),
      contactPhone: guestPhone(row),
    ),
  ));
}

String mediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http') ? url : '$apiBase$url';
}

const _cairo = 'Cairo';
const _mont = 'Montserrat';

// ───────────────────────── حالات العرض (slivers) ─────────────────────────

/// حالات تحميل / خطأ / فراغ كـ slivers جاهزة لـ [StaffPage].
List<Widget> asyncSlivers({
  required bool loading,
  required String? error,
  required bool isEmpty,
  required Future<void> Function() onRetry,
  required List<Widget> slivers,
  IconData emptyIcon = Icons.event_busy_rounded,
  String emptyTitle = 'لا توجد بيانات',
  String? emptySubtitle,
  String? emptyActionLabel,
  VoidCallback? onEmptyAction,
  double skeletonHeight = 118,
  int skeletonCount = 5,
}) {
  if (loading) return [SkeletonSliver(count: skeletonCount, height: skeletonHeight)];
  if (error != null) return [SliverToBoxAdapter(child: ErrorPanel(message: error, onRetry: onRetry))];
  if (isEmpty) {
    return [
      SliverToBoxAdapter(
        child: EmptyView(
          icon: emptyIcon,
          title: emptyTitle,
          subtitle: emptySubtitle,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
      ),
    ];
  }
  return slivers;
}

/// جسم قابل للسحب للتحديث مع حالات تحميل / خطأ / فراغ (لقوائم غير sliver).
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
      body = [
        for (var i = 0; i < 4; i++) const Pad(top: 0, bottom: 10, child: SkeletonBox(height: 110)),
      ];
    } else if (error != null) {
      body = [ErrorPanel(message: error!, onRetry: onRefresh)];
    } else if (isEmpty) {
      body = [EmptyView(icon: Icons.inbox_outlined, title: emptyTitle, subtitle: emptySubtitle)];
    } else {
      body = children;
    }
    return RefreshIndicator(
      color: placeGold,
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
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: placeDanger.withValues(alpha: .08), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 32, color: placeDanger),
          ),
          const SizedBox(height: 14),
          const Text('تعذّر التحميل', style: TextStyle(fontFamily: _cairo, fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: _cairo, fontSize: 13, color: placeInk2, height: 1.5)),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 4, StaffSpace.page, 8),
      child: loading
          ? const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('تحميل المزيد'),
            ),
    );
  }
}

// ───────────────────────── عناصر واجهة ─────────────────────────

/// صف معلومة بأيقونة: عنوان ثابت العرض + قيمة + عنصر اختياري على الطرف.
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.label, required this.value, this.ltr = false, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final bool ltr;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Icon(icon, size: 18, color: placeInk3),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(fontFamily: _cairo, fontSize: 13, fontWeight: FontWeight.w600, color: placeInk2)),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: TextAlign.start,
              style: const TextStyle(fontFamily: _cairo, fontSize: 13.5, fontWeight: FontWeight.w800, color: placeInk),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// عنوان قسم صغير (متوافق مع الواجهة السابقة) — بأسلوب [SectionHeader].
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 18, StaffSpace.page, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontFamily: _cairo, fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// بطاقة قسم بعنوان وأيقونة ومحتوى — بديل موحّد لـ FormSection داخل شاشات الحجوزات.
class BookingSection extends StatelessWidget {
  const BookingSection({super.key, required this.title, required this.children, this.icon, this.subtitle, this.trailing, this.color = placeBrass});

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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                      Text(title, style: const TextStyle(fontFamily: _cairo, fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                      if (subtitle != null)
                        Text(subtitle!, style: const TextStyle(fontFamily: _cairo, fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.status, this.dense = true});
  final String? status;
  final bool dense;

  @override
  Widget build(BuildContext context) => StatusChip(statusLabel(status), color: statusColor(status), dense: dense);
}

/// شارة الشفت بلونه وأيقونته.
class BookingShiftChip extends StatelessWidget {
  const BookingShiftChip({super.key, required this.shift, this.short = true});
  final String? shift;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final color = shiftColor(shift);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(shiftIcon(shift), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            short ? shiftShort(shift) : shiftLabel(shift),
            style: TextStyle(fontFamily: _cairo, fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// زر أيقونة دائري بمساحة لمس 48.
class RoundIconAction extends StatelessWidget {
  const RoundIconAction({super.key, required this.icon, required this.onTap, this.color = placeInk, this.tooltip, this.filled = false});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Material(
          color: filled ? color : color.withValues(alpha: .1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: filled ? Colors.white : color)),
          ),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// بطاقة حجز موحّدة للقوائم: الزبون، المكان، الموعد والشفت، الحالة، السعر،
/// واتصال/محادثة بضغطة واحدة.
class BookingRowCard extends StatelessWidget {
  const BookingRowCard({
    super.key,
    required this.row,
    required this.onTap,
    this.onLongPress,
    this.selectable = false,
    this.selected = false,
    this.showContact = true,
    this.padding = const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 10),
  });

  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectable;
  final bool selected;
  final bool showContact;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final property = asMap(row['property']);
    final payment = asMap(row['payment']);
    final city = asMap(property?['city'])?['nameAr']?.toString();
    final phone = guestPhone(row);
    final name = guestName(row);
    final status = row['status']?.toString();
    final canChat = Session.can('inbox.read') && guestUserId(row) != null;
    final r = BorderRadius.circular(StaffRadius.lg);

    return Padding(
      padding: padding,
      child: Material(
        color: selected ? placeGoldSoft : Colors.white,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: selected ? placeGold : placeLine, width: selected ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectable)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10, top: 8),
                          child: Icon(
                            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: selected ? placeBrass : placeInk3,
                            size: 24,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: Avatar(name, size: 42),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: _cairo, fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                BookingStatusPill(status: status),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(placeTypeIcon(property?['type']?.toString()), size: 15, color: placeBrass),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    [property?['name']?.toString() ?? 'مكان محذوف', ?city].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: _cairo, fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(icon: Icons.event_rounded, text: fmtRange(row['startDate'], row['endDate'])),
                      BookingShiftChip(shift: row['shift']?.toString()),
                      if (row['origin'] == 'EXTERNAL') const StatusChip('خارجي', color: placeShiftEvening, dense: true),
                      if (row['guests'] != null) _Meta(icon: Icons.people_alt_outlined, text: '${row['guests']} ضيف'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: placeLineSoft),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
                  child: Row(
                    children: [
                      Text(
                        formatIqd(row['totalPrice']),
                        style: const TextStyle(fontFamily: _cairo, fontSize: 15, fontWeight: FontWeight.w900, color: placeInk),
                      ),
                      if (payment != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: StatusChip(
                              paymentStatusAr(payment['status']?.toString()),
                              color: paymentStatusColor(payment['status']?.toString()),
                              dense: true,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (showContact && !selectable && phone != null)
                        RoundIconAction(icon: Icons.call_rounded, color: placeSuccess, tooltip: 'اتصال', onTap: () => callPhone(context, phone)),
                      if (showContact && !selectable && canChat)
                        RoundIconAction(icon: Icons.chat_rounded, color: placeInfo, tooltip: 'محادثة', onTap: () => openGuestChat(context, row)),
                      if (!showContact || selectable || (phone == null && !canChat))
                        const SizedBox(height: 48, child: Icon(Icons.chevron_left_rounded, color: placeInk3)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: placeInk2),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: _cairo, fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// مرشّح شرائح أفقي (حالات/أنواع) مع عدّادات اختيارية.
class SegmentFilter<T> extends StatelessWidget {
  const SegmentFilter({
    super.key,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.onChanged,
    this.countOf,
    this.colorOf,
  });

  final List<T> options;
  final T value;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final int? Function(T)? countOf;
  final Color? Function(T)? colorOf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final on = o == value;
          final count = countOf?.call(o);
          final dot = colorOf?.call(o);
          return Center(
            child: Material(
              color: on ? placeInk : Colors.white,
              shape: StadiumBorder(side: BorderSide(color: on ? placeInk : placeLine)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  if (on) return;
                  HapticFeedback.selectionClick();
                  onChanged(o);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dot != null) ...[
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: on ? Colors.white : dot, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          labelOf(o),
                          style: TextStyle(fontFamily: _cairo, fontSize: 13, fontWeight: FontWeight.w800, color: on ? Colors.white : placeInk),
                        ),
                        if (count != null && count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: on ? Colors.white.withValues(alpha: .18) : placePaper,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              count > 999 ? '999+' : '$count',
                              style: TextStyle(fontFamily: _mont, fontSize: 11, fontWeight: FontWeight.w800, color: on ? Colors.white : placeInk2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// حقل بحث موحّد (بحث حيّ داخل الشاشة).
class BookingSearchField extends StatelessWidget {
  const BookingSearchField({super.key, required this.controller, required this.hint, required this.onChanged, this.onClear, this.busy = false, this.trailing});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool busy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontFamily: _cairo, fontWeight: FontWeight.w700, color: placeInk),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: busy
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
                    )
                  : controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح',
                          onPressed: () {
                            controller.clear();
                            onClear?.call();
                          },
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// شريط إجراءات سفلي ثابت (أزرار رئيسية) مع هامش الأمان.
class BookingActionBar extends StatelessWidget {
  const BookingActionBar({super.key, required this.children, this.top});
  final List<Widget> children;
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
        boxShadow: [BoxShadow(color: Color(0x0F0F1B2D), blurRadius: 16, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 10, StaffSpace.page, 10 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (top != null) ...[top!, const SizedBox(height: 10)],
          Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// زر داخل [BookingActionBar] مع حالة انشغال.
class BarButton extends StatelessWidget {
  const BarButton({super.key, required this.label, required this.onPressed, this.icon, this.primary = true, this.busy = false, this.danger = false, this.flex = 1});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool busy;
  final bool danger;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final content = busy
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: primary ? Colors.white : placeInk))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 6)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          );
    final action = busy ? null : onPressed;
    return Expanded(
      flex: flex,
      child: SizedBox(
        height: 52,
        child: primary
            ? FilledButton(
                style: FilledButton.styleFrom(backgroundColor: danger ? placeDanger : placeInk, padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: action,
                child: content,
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: danger ? placeDanger : placeInk,
                  side: BorderSide(color: danger ? placeDanger.withValues(alpha: .4) : placeLine),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: action,
                child: content,
              ),
      ),
    );
  }
}

/// صفحة [StaffPage] مع شريط سفلي ثابت اختياري.
Widget withBottomBar(Widget page, Widget? bar) {
  if (bar == null) return page;
  return Scaffold(body: page, bottomNavigationBar: bar);
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
    final r = BorderRadius.circular(StaffRadius.md);
    return Material(
      color: Colors.white,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(borderRadius: r, border: Border.all(color: date == null ? placeLine : placeGold.withValues(alpha: .6))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 20, color: date == null ? placeInk3 : placeBrass),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontFamily: _cairo, fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk2)),
                        Text(
                          date == null ? 'اختر التاريخ' : DateFormat('EEE d MMM yyyy', 'ar').format(date!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: _cairo, fontSize: 14, fontWeight: FontWeight.w800, color: date == null ? placeInk3 : placeInk),
                        ),
                      ],
                    ),
                  ),
                  if (date != null && onClear != null)
                    IconButton(tooltip: 'مسح', onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18))
                  else
                    const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.expand_more_rounded, color: placeInk3)),
                ],
              ),
            ),
          ),
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

/// عدّاد (+/-) بأزرار 48.
class DaysStepper extends StatelessWidget {
  const DaysStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 60, this.label = 'عدد الأيام', this.icon = Icons.date_range_rounded});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? tap) => SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            onPressed: tap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    tap();
                  },
            style: IconButton.styleFrom(backgroundColor: tap == null ? placeLineSoft : placePaper),
            icon: Icon(i, size: 20, color: tap == null ? placeInk3 : placeInk),
          ),
        );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.md),
        border: Border.all(color: placeLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: placeInk3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontFamily: _cairo, fontSize: 13.5, fontWeight: FontWeight.w800, color: placeInk2)),
          ),
          btn(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: _mont, fontSize: 17, fontWeight: FontWeight.w800, color: placeInk),
            ),
          ),
          btn(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

/// اختيار الشفت حسب ما يدعمه المكان (شرائح متساوية).
class ShiftChooser extends StatelessWidget {
  const ShiftChooser({super.key, required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(StaffRadius.md)),
      child: Row(
        children: [
          for (final s in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (s == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(s);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 48,
                  decoration: BoxDecoration(
                    color: s == value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(StaffRadius.sm),
                    boxShadow: s == value ? staffCardShadow : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(shiftIcon(s), size: 17, color: s == value ? shiftColor(s) : placeInk3),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          shiftShort(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: _cairo, fontSize: 13, fontWeight: FontWeight.w800, color: s == value ? placeInk : placeInk2),
                        ),
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
        color: placeInk3,
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: placeGold)),
            SizedBox(width: 10),
            Expanded(
              child: Text('جارٍ حساب السعر والتحقق من التوفر…', style: TextStyle(fontFamily: _cairo, fontWeight: FontWeight.w700, color: placeInk2)),
            ),
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
              child: Text(error!, style: const TextStyle(fontFamily: _cairo, fontWeight: FontWeight.w800, color: placeDanger)),
            ),
          ],
        ),
      );
    }
    final q = quote;
    if (q == null) {
      return const _QuoteShell(
        color: placeInk3,
        child: Row(
          children: [
            Icon(Icons.price_change_outlined, color: placeInk3),
            SizedBox(width: 10),
            Expanded(
              child: Text('أكمل الاختيارات لعرض السعر والتوفر', style: TextStyle(fontFamily: _cairo, fontWeight: FontWeight.w700, color: placeInk2)),
            ),
          ],
        ),
      );
    }
    final available = q['available'] == true;
    final total = asNum(q['totalPrice']) ?? 0;
    final original = asNum(q['originalTotal']);
    final discount = asNum(q['discount']) ?? 0;
    final diff = compareTo == null ? null : total - compareTo!;
    final tone = available ? placeSuccess : placeDanger;
    return _QuoteShell(
      color: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(icon: available ? Icons.event_available_rounded : Icons.event_busy_rounded, color: tone, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  available ? 'متاح للحجز' : 'غير متاح — يتعارض مع حجز قائم في نفس اليوم/الشفت',
                  style: TextStyle(fontFamily: _cairo, fontWeight: FontWeight.w900, color: tone),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(formatIqd(total), style: const TextStyle(fontFamily: _cairo, fontSize: 24, fontWeight: FontWeight.w900, color: placeInk, height: 1.2)),
              if (discount > 0 && original != null)
                Text(
                  formatIqd(original),
                  style: const TextStyle(fontFamily: _cairo, color: placeInk3, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              BookingShiftChip(shift: q['shift']?.toString()),
              StatusChip(daysLabel((asNum(q['nights']) ?? 1).toInt()), color: placeInk, dense: true),
              if ((asNum(q['capacity']) ?? 0) > 0) StatusChip('السعة ${q['capacity']}', color: placeInk2, dense: true),
              if (discount > 0) StatusChip('خصم ${formatIqd(discount)} (${q['couponCode'] ?? ''})', color: placeSuccess, dense: true),
              if (diff != null && diff != 0)
                StatusChip(
                  diff > 0 ? 'زيادة ${formatIqd(diff)}' : 'نقص ${formatIqd(-diff)}',
                  color: diff > 0 ? placeWarning : placeSuccess,
                  dense: true,
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
        color: color == placeInk3 ? Colors.white : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: color == placeInk3 ? placeLine : color.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

/// تنبيه سطري ملوّن.
class HintBanner extends StatelessWidget {
  const HintBanner({super.key, required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(StaffRadius.md)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontFamily: _cairo, fontSize: 12.5, fontWeight: FontWeight.w700, color: color, height: 1.45))),
        ],
      ),
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
    useSafeArea: true,
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
      itemBuilder: (row) => _PickRow(
        leading: IconBox(icon: placeTypeIcon(row['type']?.toString()), color: placeBrass, size: 42),
        title: row['name']?.toString() ?? '—',
        subtitle: [
          placeTypeLabel(row['type']?.toString()),
          if (asMap(row['city'])?['nameAr'] != null) asMap(row['city'])!['nameAr'].toString(),
          if (row['pricePerDay'] != null) formatIqd(row['pricePerDay']),
        ].join(' · '),
      ),
    ),
  );
}

/// منتقي زبون من `/api/admin/users` (يتطلب `users.read`).
Future<Map<String, dynamic>?> pickCustomer(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
        final name = (row['name']?.toString().isNotEmpty ?? false) ? row['name'].toString() : 'بدون اسم';
        return _PickRow(
          leading: Avatar(name, size: 42),
          title: name,
          subtitle: [row['phone']?.toString() ?? '', if (count != null) '$count حجز'].join(' · '),
          trailing: row['isActive'] == false ? const StatusChip('معطّل', color: placeDanger, dense: true) : null,
        );
      },
    ),
  );
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.leading, required this.title, required this.subtitle, this.trailing});
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page, vertical: 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: _cairo, fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: _cairo, fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_left_rounded, color: placeInk3),
        ],
      ),
    );
  }
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
    final height = MediaQuery.sizeOf(context).height * 0.8;
    final tooShort = _controller.text.trim().length < widget.minChars;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(StaffSpace.page, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(fontFamily: _cairo, fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
                  ),
                  IconButton(tooltip: 'إغلاق', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page),
              child: BookingSearchField(
                controller: _controller,
                hint: widget.hint,
                busy: _loading,
                onChanged: (v) {
                  setState(() {});
                  _debounce.run(() => _run(v));
                },
                onClear: () => _run(''),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: _cairo, color: placeDanger, fontWeight: FontWeight.w700)),
                      ),
                    )
                  : _rows.isEmpty
                      ? (_loading
                          ? ListView(
                              padding: const EdgeInsets.only(top: 4),
                              children: [for (var i = 0; i < 5; i++) const Pad(bottom: 8, child: SkeletonBox(height: 58, radius: StaffRadius.md))],
                            )
                          : EmptyView(
                              icon: tooShort ? Icons.keyboard_rounded : Icons.search_off_rounded,
                              title: tooShort ? 'اكتب حرفين على الأقل للبحث' : 'لا نتائج',
                            ))
                      : ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
                          itemBuilder: (context, i) => InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context, _rows[i]);
                            },
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

// ───────────────────────── أوراق سفلية ─────────────────────────

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
    useSafeArea: true,
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
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: const TextStyle(fontFamily: _cairo, fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontFamily: _cairo, fontSize: 13, color: placeInk2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            TileGroup(
              children: [
                for (final s in widget.options)
                  _StatusOption(
                    status: s,
                    selected: _status == s,
                    current: s == widget.current,
                    onTap: s == widget.current ? null : () => setState(() => _status = s),
                  ),
              ],
            ),
            if (marksPaid) ...[
              const SizedBox(height: 10),
              const HintBanner(icon: Icons.info_outline_rounded, text: 'سيُعتبر الدفع «مدفوعاً» تلقائياً عند التأكيد أو الإكمال.', color: placeInfo),
            ],
            if (cancelling) ...[
              const SizedBox(height: 10),
              const HintBanner(icon: Icons.warning_amber_rounded, text: 'الإلغاء يحرّر التاريخ ويُشعر الزبون والمزوّد.', color: placeDanger),
            ],
            const SizedBox(height: 12),
            StaffField(
              controller: _note,
              label: cancelling ? 'سبب الإلغاء' : 'ملاحظة إدارية (اختياري)',
              hint: 'تُضاف إلى ملاحظات الحجز',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: cancelling ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
                onPressed: _status == null ? null : () => Navigator.pop(context, StatusChangeResult(_status!, _note.text.trim())),
                child: Text(_status == null ? 'اختر الحالة' : 'تطبيق: ${statusLabel(_status)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({required this.status, required this.selected, required this.current, required this.onTap});
  final String status;
  final bool selected;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        color: selected ? color.withValues(alpha: .06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            IconBox(icon: statusIcon(status), color: current ? placeInk3 : color, size: 40, filled: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel(status),
                    style: TextStyle(fontFamily: _cairo, fontSize: 14.5, fontWeight: FontWeight.w800, color: current ? placeInk3 : placeInk),
                  ),
                  Text(
                    current ? 'الحالة الحالية' : statusHint(status),
                    style: const TextStyle(fontFamily: _cairo, fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? color : (current ? placeLine : placeInk3),
            ),
          ],
        ),
      ),
    );
  }
}

/// ورقة إدخال نص (ملاحظة/سبب) موحّدة. تُرجع النص بعد التشذيب أو null عند الإلغاء.
Future<String?> showTextSheet(
  BuildContext context, {
  required String title,
  String label = 'النص',
  String? hint,
  String initial = '',
  String confirmLabel = 'حفظ',
  bool danger = false,
  int maxLines = 4,
  String? subtitle,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showStaffSheet<String>(
    context,
    title: title,
    child: Builder(
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (subtitle != null) ...[
              Text(subtitle, style: const TextStyle(fontFamily: _cairo, fontSize: 13, color: placeInk2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: maxLines,
              style: const TextStyle(fontFamily: _cairo, fontWeight: FontWeight.w600, color: placeInk),
              decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: true),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(height: 52, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع'))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: danger ? FilledButton.styleFrom(backgroundColor: placeDanger) : null,
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: Text(confirmLabel),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  return result;
}

/// عرض صورة (إثبات دفع…) بملء الشاشة مع تكبير.
void showImageViewer(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InteractiveViewer(
            child: AspectRatio(aspectRatio: 3 / 4, child: NetImage(url: url, fit: BoxFit.contain, radius: 0, icon: Icons.receipt_outlined)),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: IconButton(
              tooltip: 'إغلاق',
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
