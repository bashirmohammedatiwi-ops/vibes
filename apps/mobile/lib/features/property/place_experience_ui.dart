import '../../core/theme/world_theme.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../shared/models/models.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../home/home_sections.dart';
import 'shift_calendar_ui.dart';

Color get placeInk => themed(const Color(0xFF141C2B), VibesDark.ink);
Color get placeInk2 => themed(const Color(0xFF5A6678), VibesDark.inkSecondary);
Color get placeLine => themed(const Color(0xFFE4E9F0), VibesDark.hairline);
Color get placePaper => themed(const Color(0xFFF6F7F9), VibesDark.surfaceMuted);
Color get placeBrass => themed(const Color(0xFFA5813A), Brand.brassLight);
Color get placeWarn => themed(const Color(0xFFB45309), VibesDark.warning);
Color get placeSuccess => themed(const Color(0xFF15803D), VibesDark.success);

/// ظل البطاقات: حبر خفيف نهاراً، وأسود ليلاً حتى لا يتحول الحبر الفاتح إلى هالة.
Color placeShadow(double alpha) => themed(
  const Color(0xFF141C2B).withValues(alpha: alpha),
  Colors.black.withValues(alpha: .28),
);

String placeDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _arMonths = [
  'كانون الثاني', // i18n-ok
  'شباط', // i18n-ok
  'آذار', // i18n-ok
  'نيسان', // i18n-ok
  'أيار', // i18n-ok
  'حزيران', // i18n-ok
  'تموز', // i18n-ok
  'آب', // i18n-ok
  'أيلول', // i18n-ok
  'تشرين الأول', // i18n-ok
  'تشرين الثاني', // i18n-ok
  'كانون الأول', // i18n-ok
];

String placeFormatDateShort(DateTime d) {
  final otherYear = d.year != DateTime.now().year;
  if (I18n.isEn) {
    return DateFormat(otherYear ? 'MMM d, y' : 'MMM d', 'en').format(d);
  }
  final y = otherYear ? ' ${d.year}' : '';
  return '${d.day} ${_arMonths[d.month - 1]}$y';
}

String placeFormatDateRange(DateTime start, DateTime endExclusive) {
  final nights = endExclusive.difference(start).inDays;
  if (nights <= 1) return placeFormatDateShort(start);
  final last = endExclusive.subtract(const Duration(days: 1));
  return '${placeFormatDateShort(start)} — ${placeFormatDateShort(last)}';
}

/// تسمية الوصول/المغادرة حسب الفترة (للملخص العملي).
({String arrival, String departure}) placeStayTimelineLabels(
  Property property,
  ShiftType shift,
  DateTime start,
  DateTime endExclusive,
) {
  final labels = property.shiftLabels;
  final departDay = endExclusive; // exclusive = يوم المغادرة
  switch (shift) {
    case ShiftType.morning:
      return (
        arrival: '${placeFormatDateShort(start)} · ${labels.morning}',
        departure: '{date} · نهاية الصباحي'.trArgs({
          'date': placeFormatDateShort(departDay),
        }),
      );
    case ShiftType.evening:
      return (
        arrival: '${placeFormatDateShort(start)} · ${labels.evening}',
        departure: '{date} · صباح اليوم التالي'.trArgs({
          'date': placeFormatDateShort(departDay),
        }),
      );
    case ShiftType.full:
      final nights = endExclusive.difference(start).inDays;
      if (nights <= 1) {
        return (
          arrival: '{date} · يوم كامل'.trArgs({
            'date': placeFormatDateShort(start),
          }),
          departure: '{date} · مغادرة تلقائية'.trArgs({
            'date': placeFormatDateShort(departDay),
          }),
        );
      }
      return (
        arrival: '{date} · وصول'.trArgs({'date': placeFormatDateShort(start)}),
        departure: '{date} · مغادرة'.trArgs({
          'date': placeFormatDateShort(departDay),
        }),
      );
  }
}

ShiftType placeDefaultShift(Property property) =>
    property.supportsShifts ? ShiftType.full : ShiftType.full;

String placeShiftHintLabel(Property property, ShiftType shift) {
  switch (shift) {
    case ShiftType.morning:
      return property.shiftLabels.morning;
    case ShiftType.evening:
      return property.shiftLabels.evening;
    case ShiftType.full:
      return 'يوم كامل'.tr;
  }
}

ShiftType? placeShiftFromQuery(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  switch (raw.trim().toUpperCase()) {
    case 'MORNING':
      return ShiftType.morning;
    case 'EVENING':
      return ShiftType.evening;
    case 'FULL':
      return ShiftType.full;
    default:
      return null;
  }
}

/// مسار الحجز مع تاريخ وشفت اختياريين.
typedef PlaceDayBookHandler = void Function(DayPricing day, ShiftType shift);

/// أول سعر متاح قادم (أو سعر المكان الافتراضي).
num placeReferencePrice(
  Property property,
  List<DayPricing> days, {
  ShiftType shift = ShiftType.full,
}) {
  for (final day in days) {
    if (day.isPast || day.isBlocked || day.isShiftOccupied(shift)) continue;
    final v = switch (shift) {
      ShiftType.morning => day.morning,
      ShiftType.evening => day.evening,
      ShiftType.full => day.full,
    };
    if (v > 0) return v;
  }
  return switch (shift) {
    ShiftType.morning => property.priceMorningShift ?? property.pricePerDay,
    ShiftType.evening => property.priceEveningShift ?? property.pricePerDay,
    ShiftType.full => property.pricePerDay,
  };
}

String placeBookPath(String propertyId, {DateTime? date, ShiftType? shift}) {
  final params = <String, String>{};
  if (date != null) params['date'] = placeDateKey(date);
  if (shift != null) params['shift'] = shift.name.toUpperCase();
  if (params.isEmpty) return '/book/$propertyId';
  return Uri(path: '/book/$propertyId', queryParameters: params).toString();
}

/// سعر كامل بفواصل — بدون اختصار (K/M).
String placeFullPrice(num value) {
  final fixed = value.round();
  final str = fixed.toString();
  final buf = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    buf.write(str[i]);
    final remaining = str.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buf.write(',');
  }
  return buf.toString();
}

class PlaceFullPriceText extends StatelessWidget {
  const PlaceFullPriceText(
    this.amount, {
    super.key,
    this.size = 18,
    this.muted = false,
    this.unit = true,
  });

  final num amount;
  final double size;
  final bool muted;
  final bool unit;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: placeFullPrice(amount),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: muted ? placeInk2 : placeInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (unit)
            TextSpan(
              text: ' د.ع'.tr,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w700,
                color: placeInk2,
              ),
            ),
        ],
      ),
    );
  }
}

/// جدول الأسعار الأسبوعي الثابت — أسماء الأيام فقط (بلا تواريخ).
/// تصميم مميز: عمود أيام + أعمدة صباح/مساء/يوم كامل حسب الدعم.
class PlaceWeeklyPriceTable extends StatelessWidget {
  const PlaceWeeklyPriceTable({
    super.key,
    required this.property,
    required this.accent,
    this.onBookDay,
  });

  final Property property;
  final Color accent;
  final void Function(int weekday, ShiftType shift)? onBookDay;

  static List<(String, String, bool)> get _dayNames => [
    ('الأحد'.tr, 'أحد'.tr, false),
    ('الإثنين'.tr, 'إثن'.tr, false),
    ('الثلاثاء'.tr, 'ثلا'.tr, false),
    ('الأربعاء'.tr, 'أرب'.tr, false),
    ('الخميس'.tr, 'خمي'.tr, false),
    ('الجمعة'.tr, 'جمع'.tr, true),
    ('السبت'.tr, 'سبت'.tr, true),
  ];

  @override
  Widget build(BuildContext context) {
    final shifts = property.supportsShifts;

    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: placeLine),
        boxShadow: [
          BoxShadow(
            color: placeShadow(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // رأس الجدول — شريط بلون عالم المكان
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'اليوم'.tr,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: placeInk,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    shifts ? 'يوم كامل'.tr : 'السعر'.tr,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: placeInk,
                    ),
                  ),
                ),
                if (shifts) ...[
                  Expanded(
                    flex: 4,
                    child: Text(
                      'صباح'.tr,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: placeShiftMorning,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'مساء'.tr,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: placeShiftEvening,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // الصفوف — 7 أيام
          for (var i = 0; i < 7; i++) ...[
            _weekRow(shifts, i),
            if (i < 6)
              Padding(
                padding: EdgeInsetsDirectional.only(start: 12),
                child: Divider(height: 1, color: placeLine),
              ),
          ],

          // تذييل — أوقات الشفتات
          if (shifts) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              color: placePaper,
              child: Text(
                'الصباح {morning} · المساء {evening}'.trArgs({
                  'morning': property.shiftLabels.morning,
                  'evening': property.shiftLabels.evening,
                }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: placeInk2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekRow(bool shifts, int index) {
    final (full, short, weekend) = _dayNames[index];
    // عمود اليوم ضيق مع الشفتات: الإنجليزية تأخذ الصيغة القصيرة.
    final name = I18n.isEn && shifts ? short : full;
    final dayColor = weekend ? placeBrass : placeInk;
    final fullPrice = weekend
        ? (property.weekendPrice ?? property.pricePerDay)
        : property.pricePerDay;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // اسم اليوم + نقطة العطلة
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: weekend ? placeBrass : accent.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: dayColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _cell(
            fullPrice,
            weekend,
            () => onBookDay?.call(index == 0 ? 7 : index, ShiftType.full),
          ),
          if (shifts) ...[
            _cell(
              property.priceMorningShift ?? 0,
              weekend,
              () => onBookDay?.call(index == 0 ? 7 : index, ShiftType.morning),
            ),
            _cell(
              property.priceEveningShift ?? 0,
              weekend,
              () => onBookDay?.call(index == 0 ? 7 : index, ShiftType.evening),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(num price, bool weekend, VoidCallback onTap) {
    final enabled = price > 0 && onBookDay != null;
    return Expanded(
      flex: 4,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onTap();
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: price > 0
                  ? Text(
                      placeFullPrice(price),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11.5,
                        fontWeight: weekend ? FontWeight.w900 : FontWeight.w800,
                        color: weekend ? placeBrass : placeInk,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )
                  : Text(
                      '—',
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontWeight: FontWeight.w700,
                        color: placeInk2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlaceSectionHeader extends StatelessWidget {
  const PlaceSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: placeBrass,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: placeInk,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// أسعار أساسية: يوم كامل، شفتات، عطلة.
class PlaceBasePricingCard extends StatelessWidget {
  const PlaceBasePricingCard({
    super.key,
    required this.property,
    required this.accent,
  });

  final Property property;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final shifts = property.supportsShifts;
    final labels = property.shiftLabels;

    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
        boxShadow: [
          BoxShadow(
            color: placeShadow(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 3, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                _priceRow(
                  label: shifts ? 'اليوم الكامل'.tr : 'سعر اليوم'.tr,
                  amount: property.pricePerDay,
                  highlight: true,
                ),
                if (shifts) ...[
                  const SizedBox(height: 8),
                  _priceRow(
                    label: 'الشفت الصباحي'.tr,
                    sub: labels.morning,
                    amount: property.priceMorningShift,
                  ),
                  const SizedBox(height: 8),
                  _priceRow(
                    label: 'الشفت المسائي'.tr,
                    sub: labels.evening,
                    amount: property.priceEveningShift,
                  ),
                ],
                if (property.weekendPrice != null) ...[
                  const SizedBox(height: 8),
                  _priceRow(
                    label: 'نهاية الأسبوع (مرجع)'.tr,
                    amount: property.weekendPrice,
                  ),
                ],
              ],
            ),
          ),
          if (shifts)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: placePaper,
              child: Text(
                'يمكنك حجز صباح أو مساء أو يوم كامل — الأسعار أدناه لكل خيار.'.tr,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: placeInk2,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceRow({
    required String label,
    String? sub,
    required num? amount,
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: highlight ? 14 : 13,
                  fontWeight: FontWeight.w800,
                  color: placeInk,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: placeInk2,
                  ),
                ),
            ],
          ),
        ),
        if (amount != null && amount > 0)
          PlaceFullPriceText(amount, size: highlight ? 17 : 15)
        else
          Text(
            '—',
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontWeight: FontWeight.w700,
              color: placeInk2,
            ),
          ),
      ],
    );
  }
}

/// سطر مرجعي للأسعار في مسار الحجز — بدون تكرار بطاقة صفحة المكان.
class PlaceBookingReferencePrices extends StatelessWidget {
  const PlaceBookingReferencePrices({
    super.key,
    required this.property,
    required this.accent,
    this.onOpenTable,
  });

  final Property property;
  final Color accent;
  final VoidCallback? onOpenTable;

  @override
  Widget build(BuildContext context) {
    final shifts = property.supportsShifts;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: placeLine),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shifts ? 'مرجع: يوم كامل'.tr : 'سعر اليوم'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: placeInk2,
                  ),
                ),
                PlaceFullPriceText(property.pricePerDay, size: 16),
              ],
            ),
          ),
          if (onOpenTable != null)
            TextButton(onPressed: onOpenTable, child: Text('جدول الأيام'.tr)),
        ],
      ),
    );
  }
}

/// جدول أسعار الأيام — أعمدة حسب الشفتات.
class PlaceDayPricingTable extends StatelessWidget {
  const PlaceDayPricingTable({
    super.key,
    required this.days,
    required this.supportsShifts,
    this.maxRows = 10,
    this.selectedShift = ShiftType.full,
    this.onDayBook,
  });

  final List<DayPricing> days;
  final bool supportsShifts;
  final int maxRows;
  final ShiftType selectedShift;
  final PlaceDayBookHandler? onDayBook;

  static final _dateFmt = I18n.isEn
      ? DateFormat('MMM d', 'en')
      : DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final visible = days.take(maxRows).toList();

    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _headerRow(supportsShifts),
          Divider(height: 1, color: placeLine),
          for (var i = 0; i < visible.length; i++) ...[
            _dayRow(visible[i], supportsShifts),
            if (i < visible.length - 1) Divider(height: 1, color: placeLine),
          ],
          if (onDayBook != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Text(
                supportsShifts
                    ? 'اضغط على السعر (يوم كامل / صباح / مساء) للحجز'.tr
                    : 'اضغط على أي يوم متاح للانتقال إلى الحجز'.tr,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: placeInk2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerRow(bool shifts) {
    return Container(
      color: placePaper,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'اليوم'.tr,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: placeInk2,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              shifts ? 'يوم كامل'.tr : 'السعر'.tr,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: placeInk2,
              ),
            ),
          ),
          if (shifts) ...[
            Expanded(
              flex: 4,
              child: Text(
                'صباح'.tr,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: placeInk2,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                'مساء'.tr,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: placeInk2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayRow(DayPricing day, bool shifts) {
    final rowMuted = day.isPast || day.isBlocked;
    final weekend =
        day.date.weekday == DateTime.friday ||
        day.date.weekday == DateTime.saturday;
    final markers = day.calendarOccupancyMarkers(hybrid: shifts);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Opacity(
        opacity: rowMuted ? 0.45 : 1,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateFmt.format(day.date),
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: weekend ? placeBrass : placeInk,
                    ),
                  ),
                  if (rowMuted)
                    Text(
                      day.isBlocked ? 'مغلق'.tr : 'انتهى'.tr,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: placeInk2,
                      ),
                    )
                  else if (markers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: PlaceShiftStripeRow(shifts: markers, height: 3),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: _bookablePriceCell(
                day: day,
                shift: ShiftType.full,
                amount: day.full,
                disabled: rowMuted,
                highlighted: shifts && selectedShift == ShiftType.full,
              ),
            ),
            if (shifts) ...[
              Expanded(
                flex: 4,
                child: _bookablePriceCell(
                  day: day,
                  shift: ShiftType.morning,
                  amount: day.morning,
                  disabled: rowMuted,
                  highlighted: selectedShift == ShiftType.morning,
                ),
              ),
              Expanded(
                flex: 4,
                child: _bookablePriceCell(
                  day: day,
                  shift: ShiftType.evening,
                  amount: day.evening,
                  disabled: rowMuted,
                  highlighted: selectedShift == ShiftType.evening,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookablePriceCell({
    required DayPricing day,
    required ShiftType shift,
    required num amount,
    required bool disabled,
    required bool highlighted,
  }) {
    final shiftBlocked = day.isShiftOccupied(shift);
    final canBook =
        !disabled && !shiftBlocked && onDayBook != null && amount > 0;
    final accent = placeShiftColor(shift);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        color: highlighted
            ? accent.withValues(alpha: 0.14)
            : shiftBlocked
            ? accent.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: canBook
              ? () {
                  HapticFeedback.selectionClick();
                  onDayBook!(day, shift);
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: shiftBlocked
                ? PlaceShiftBadge(shift: shift, compact: true)
                : _cellPrice(amount, accent: accent),
          ),
        ),
      ),
    );
  }

  Widget _cellPrice(num v, {Color? accent}) {
    accent ??= placeInk;
    if (v <= 0) {
      return Text(
        '—',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: placeInk2,
        ),
      );
    }
    return Text(
      placeFullPrice(v),
      textAlign: TextAlign.end,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: accent,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

Future<void> showPlaceDayPricingSheet({
  required BuildContext context,
  required Property property,
  required List<DayPricing> days,
  ShiftType selectedShift = ShiftType.full,
  PlaceDayBookHandler? onDayBook,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Vibes.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: placeLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: PlaceSectionHeader(
                    title: 'جدول الأسعار'.tr,
                    subtitle: property.name,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      PlaceBasePricingCard(
                        property: property,
                        accent: accentForType(property.type.name),
                      ),
                      const SizedBox(height: 16),
                      PlaceDayPricingTable(
                        days: days,
                        supportsShifts: property.supportsShifts,
                        maxRows: days.length,
                        selectedShift: selectedShift,
                        onDayBook: onDayBook,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// بطاقة قرار سريع — سعر واضح + حجز.
class PlaceQuickBookBanner extends StatelessWidget {
  const PlaceQuickBookBanner({
    super.key,
    required this.property,
    required this.accent,
    required this.availableDays,
    required this.onBook,
    required this.onSeePrices,
    this.referencePrice,
  });

  final Property property;
  final Color accent;
  final int availableDays;
  final VoidCallback onBook;
  final VoidCallback onSeePrices;
  final num? referencePrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: Appearance.isDark
              ? const [VibesDark.surfaceMuted, VibesDark.surface]
              : [placeInk, placeInk.withValues(alpha: 0.92)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'احجز بخطوات بسيطة'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            availableDays > 0
                ? (availableDays == 1
                          ? '{n} يوم متاحة قريباً'.tr
                          : '{n} أيام متاحة قريباً'.tr)
                      .trN(availableDays)
                : 'تحقق من التوفر في التقويم'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'يبدأ من'.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          text: placeFullPrice(
                            referencePrice ?? property.pricePerDay,
                          ),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                              text: ' د.ع'.tr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onSeePrices,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'جدول الأسعار'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: themed(Colors.white, context.world.onAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'احجز'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// خطوة في مسار الحجز.
class PlaceBookingStep extends StatelessWidget {
  const PlaceBookingStep({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    this.completed = false,
  });

  final int index;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: placeLine),
        boxShadow: [
          BoxShadow(
            color: placeShadow(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed ? accent : placePaper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: completed ? accent : placeLine,
                    width: 1.5,
                  ),
                ),
                child: completed
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: themed(Colors.white, context.world.onAccent),
                      )
                    : Text(
                        '$index',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: placeInk,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: placeInk2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class PlaceQuoteSummaryCard extends StatelessWidget {
  const PlaceQuoteSummaryCard({
    super.key,
    required this.quoting,
    required this.error,
    required this.nights,
    required this.total,
    required this.discount,
    required this.hint,
  });

  final bool quoting;
  final String? error;
  final int? nights;
  final num? total;
  final num discount;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: placePaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: placeLine),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ملخص السعر'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: placeInk,
            ),
          ),
          const SizedBox(height: 10),
          if (quoting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (error != null)
            Text(
              error!,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: placeWarn,
              ),
            )
          else if (total != null) ...[
            if (nights != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (nights == 1 ? '{n} ليلة'.tr : '{n} ليالٍ'.tr).trN(nights!),
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                    ),
                  ),
                  if (discount > 0)
                    Text(
                      'خصم {amount} د.ع'.trArgs({
                        'amount': placeFullPrice(discount),
                      }),
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: placeSuccess,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: placeInk,
                  ),
                ),
                PlaceFullPriceText(total!, size: 20),
              ],
            ),
          ] else
            Text(
              hint,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: placeInk2,
              ),
            ),
        ],
      ),
    );
  }
}

/// مؤشر تقدم الحجز — 3 خطوات بسيطة.
class PlaceBookingProgress extends StatelessWidget {
  const PlaceBookingProgress({
    super.key,
    required this.labels,
    required this.currentIndex,
  });

  final List<String> labels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i <= currentIndex ? placeInk : placePaper,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i <= currentIndex ? placeInk : placeLine,
                    ),
                  ),
                  child: i < currentIndex
                      ? Icon(Icons.check, size: 14, color: placeOnFill)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: i <= currentIndex ? placeOnFill : placeInk2,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: i <= currentIndex ? placeInk : placeInk2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// اختيار الشفت — صباح / مساء / يوم كامل.
class PlaceShiftSelector extends StatelessWidget {
  const PlaceShiftSelector({
    super.key,
    required this.property,
    required this.accent,
    required this.selected,
    required this.onChanged,
  });

  final Property property;
  final Color accent;
  final ShiftType selected;
  final ValueChanged<ShiftType> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!property.supportsShifts) return const SizedBox.shrink();
    final labels = property.shiftLabels;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _shiftChip(
          'صباح'.tr,
          labels.morning,
          property.priceMorningShift,
          ShiftType.morning,
        ),
        _shiftChip(
          'مساء'.tr,
          labels.evening,
          property.priceEveningShift,
          ShiftType.evening,
        ),
        if (property.supportsFullDay)
          _shiftChip('يوم كامل'.tr, null, property.pricePerDay, ShiftType.full),
      ],
    );
  }

  Widget _shiftChip(String title, String? time, num? price, ShiftType type) {
    final active = selected == type;
    final tint = placeShiftColor(type);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? tint : Vibes.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? tint : tint.withValues(alpha: .35),
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: tint.withValues(alpha: .22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? placeOnFill : tint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: active ? placeOnFill : placeInk,
                    ),
                  ),
                ),
              ],
            ),
            if (time != null)
              Text(
                time,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? placeOnFill.withValues(alpha: 0.85)
                      : placeInk2,
                ),
              ),
            if (price != null && price > 0) ...[
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '{amount} د.ع'.trArgs({'amount': placeFullPrice(price)}),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: active ? placeOnFill : placeInk,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlaceCalendarLegend extends StatelessWidget {
  const PlaceCalendarLegend({super.key, this.selectedShift});

  final ShiftType? selectedShift;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PlaceShiftLegendRow(includeSelection: false),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _dot(
              'عطلة نهاية الأسبوع'.tr,
              themed(const Color(0xFFE8F5F0), VibesDark.tealMint),
              placeBrass,
            ),
            _dot('مغلق من المضيف'.tr, placePaper, placeInk2),
            if (selectedShift != null)
              _dot(
                'الشفت المختار'.tr,
                placeShiftColor(selectedShift!).withValues(alpha: .12),
                placeShiftColor(selectedShift!),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dot(String label, Color fill, Color border) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: placeInk2,
          ),
        ),
      ],
    );
  }
}

/// تقويم التوفر — الشفت يُدار من القسم الموحّد أعلاه.
class PlaceAvailabilityBlock extends StatelessWidget {
  const PlaceAvailabilityBlock({
    super.key,
    required this.shift,
    required this.calendar,
  });

  final ShiftType shift;
  final Widget Function(ShiftType shift) calendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaceCalendarLegend(selectedShift: shift),
        const SizedBox(height: 12),
        calendar(shift),
      ],
    );
  }
}

/// أسعار + جدول + تقويم — شفت واحد مشترك.
class PlacePricingAvailabilitySection extends StatefulWidget {
  const PlacePricingAvailabilitySection({
    super.key,
    required this.property,
    required this.accent,
    required this.days,
    required this.onBookDay,
    required this.buildCalendar,
  });

  final Property property;
  final Color accent;
  final List<DayPricing> days;
  final PlaceDayBookHandler onBookDay;
  final Widget Function(ShiftType shift) buildCalendar;

  @override
  State<PlacePricingAvailabilitySection> createState() =>
      _PlacePricingAvailabilitySectionState();
}

class _PlacePricingAvailabilitySectionState
    extends State<PlacePricingAvailabilitySection> {
  ShiftType _shift = ShiftType.full;

  void _openFullTable() {
    showPlaceDayPricingSheet(
      context: context,
      property: widget.property,
      days: widget.days,
      selectedShift: _shift,
      onDayBook: widget.onBookDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final shifts = p.supportsShifts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaceSectionHeader(
          title: 'الأسعار والتوفر'.tr,
          subtitle: 'أرقام كاملة — اختر الشفت ثم اليوم'.tr,
        ),
        if (shifts) ...[
          PlaceShiftSelector(
            property: p,
            accent: widget.accent,
            selected: _shift,
            onChanged: (s) => setState(() => _shift = s),
          ),
          const SizedBox(height: 8),
          Text(
            'الشفت المختار ينطبق على جدول الأيام والتقويم'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: placeInk2,
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          const SizedBox(height: 4),
        ],
        PlaceBasePricingCard(property: p, accent: widget.accent),
        const SizedBox(height: 14),
        PlaceDayPricingTable(
          days: widget.days,
          supportsShifts: shifts,
          maxRows: 7,
          selectedShift: _shift,
          onDayBook: widget.onBookDay,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openFullTable,
          icon: const Icon(Icons.table_rows_rounded),
          label: Text('عرض جدول الأسعار الكامل'.tr),
        ),
        const SizedBox(height: 20),
        const ScallopDivider(),
        const SizedBox(height: 18),
        PlaceSectionHeader(
          title: 'التقويم'.tr,
          subtitle: shifts
              ? 'اضغط يوماً متاحاً — {shift}'.trArgs({
                  'shift': placeShiftHintLabel(p, _shift),
                })
              : 'اضغط يوماً متاحاً للحجز'.tr,
        ),
        const SizedBox(height: 10),
        VibesCard(
          child: PlaceAvailabilityBlock(
            shift: _shift,
            calendar: widget.buildCalendar,
          ),
        ),
      ],
    );
  }
}

/// تفصيل سعر كل ليلة — قبل تأكيد الحجز.
class PlaceNightlyPriceList extends StatelessWidget {
  const PlaceNightlyPriceList({
    super.key,
    required this.property,
    required this.start,
    required this.endExclusive,
    required this.shift,
    required this.availability,
  });

  final Property property;
  final DateTime start;
  final DateTime endExclusive;
  final ShiftType shift;
  final AvailabilityData? availability;

  @override
  Widget build(BuildContext context) {
    final rows = <DayPricing>[];
    var subtotal = 0.0;
    for (
      var d = start;
      d.isBefore(endExclusive);
      d = d.add(const Duration(days: 1))
    ) {
      final pricing = availability?.pricingFor(d);
      if (pricing != null) {
        rows.add(pricing);
        subtotal += pricing.priceFor(shift).toDouble();
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: placeLine),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'تفصيل الأيام'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: placeInk,
                  ),
                ),
              ),
              PlaceShiftBadge(shift: shift, compact: false),
            ],
          ),
          const SizedBox(height: 8),
          for (final day in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      placeFormatDateShort(day.date),
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: placeInk,
                      ),
                    ),
                  ),
                  PlaceFullPriceText(day.priceFor(shift), size: 13),
                ],
              ),
            ),
          Divider(height: 16, color: placeLine),
          Row(
            children: [
              Expanded(
                child: Text(
                  'مجموع الأيام (تقديري)'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: placeInk2,
                  ),
                ),
              ),
              PlaceFullPriceText(subtotal, size: 15),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الإجمالي النهائي قد يتضمن خصماً أو رسوماً — يظهر في «ملخص السعر».'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: placeInk2.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceCouponCard extends StatelessWidget {
  const PlaceCouponCard({
    super.key,
    required this.controller,
    required this.error,
    required this.applied,
    required this.suggestedCodes,
    required this.onApplyCode,
  });

  final TextEditingController controller;
  final String? error;
  final bool applied;
  final List<String> suggestedCodes;
  final ValueChanged<String> onApplyCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: placeLine),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 18, color: placeBrass),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'رمز خصم (اختياري)'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: placeInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'أدخل الرمز'.tr,
              filled: true,
              fillColor: placePaper,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: applied
                  ? Icon(Icons.check_circle, color: placeSuccess)
                  : null,
            ),
          ),
          if (suggestedCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in suggestedCodes)
                  ActionChip(
                    label: Text(code),
                    onPressed: () => onApplyCode(code),
                  ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: placeWarn,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PlaceStickyCheckoutBar extends StatelessWidget {
  const PlaceStickyCheckoutBar({
    super.key,
    required this.amount,
    required this.amountLabel,
    required this.buttonLabel,
    required this.accent,
    required this.enabled,
    required this.loading,
    required this.onConfirm,
  });

  final num amount;
  final String amountLabel;
  final String buttonLabel;
  final Color accent;
  final bool enabled;
  final bool loading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    // شريط حجز عائم: سعر واضح وزر متدرج بلون عالم المكان مع توهّج.
    final world = context.world;
    final active = enabled && !loading;
    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: world.glow.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlaceFullPriceText(amount, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      amountLabel,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: world.accentDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: active
                      ? () {
                          HapticFeedback.mediumImpact();
                          onConfirm();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: active
                            ? [Color.lerp(accent, Colors.white, .18)!, accent]
                            : [
                                accent.withValues(alpha: .35),
                                accent.withValues(alpha: .35),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: .38),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : const [],
                    ),
                    child: loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: themed(Colors.white, world.onAccent),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  buttonLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                    color: themed(Colors.white, world.onAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: themed(Colors.white, world.onAccent),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceTrustHints extends StatelessWidget {
  const PlaceTrustHints({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: placePaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: placeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'كيف يعمل الحجز؟'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: placeInk,
            ),
          ),
          SizedBox(height: 8),
          _hint(
            '١'.tr,
            'اختر التاريخ من التقويم — ترى السعر كاملاً لكل يوم.'.tr,
          ),
          _hint(
            '٢'.tr,
            'راجع الإجمالي ثم أكّد — نفتح لك محادثة لإتمام الدفع.'.tr,
          ),
          _hint('٣'.tr, 'أي استفسار؟ راسل المالك من صفحة المكان.'.tr),
        ],
      ),
    );
  }
}

class _hint extends StatelessWidget {
  const _hint(this.n, this.text);
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              color: placeBrass,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: placeInk2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
