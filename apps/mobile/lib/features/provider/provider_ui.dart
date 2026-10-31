import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';

import '../../core/theme/world_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_ui.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../property/place_experience_ui.dart';
import '../property/shift_calendar_ui.dart';
import 'provider_data.dart';

// ── ألوان بوابة المالك (كحلي وذهب) ──
const Color ownerNavy = Color(0xFF0B1A2E);
const Color ownerNavyHigh = Color(0xFF1B3857);
const Color ownerGold = Color(0xFFC89844);
const Color ownerGoldDeep = Color(0xFF8D6324);
const Color ownerGoldLight = Color(0xFFE0B568);
const Color ownerLine = Color(0xFFEDEEF1);
const Color ownerPaper = Color(0xFFF5F6F8);
const LinearGradient ownerNavyFill = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [ownerNavyHigh, ownerNavy],
);

/// تاريخ نسبي للحجوزات (اليوم / غداً / …)
String ownerRelativeBookingDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'غداً';
  if (diff == -1) return 'أمس';
  if (diff > 1 && diff < 7) return 'بعد $diff أيام';
  return '${date.day}/${date.month}';
}

bool ownerIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool ownerIsTomorrow(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays == 1;
}

bool ownerBookingCoversDay(Booking booking, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  final start = DateTime(
    booking.startDate.year,
    booking.startDate.month,
    booking.startDate.day,
  );
  final end = DateTime(
    booking.endDate.year,
    booking.endDate.month,
    booking.endDate.day,
  );
  return !target.isBefore(start) && target.isBefore(end);
}

String ownerFormatDayLong(DateTime d) {
  const months = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];
  const weekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];
  return '${weekdays[d.weekday % 7]} ${d.day} ${months[d.month - 1]}';
}

/// ملخص اليوم المحدّد في التقويم
class OwnerSelectedDayCard extends StatelessWidget {
  const OwnerSelectedDayCard({
    super.key,
    required this.day,
    required this.bookings,
    required this.isClosed,
  });

  final DateTime day;
  final List<Booking> bookings;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ownerFormatDayLong(day),
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ownerNavy,
                  ),
                ),
              ),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: placeInk2.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'مغلق',
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: placeInk2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (bookings.isEmpty)
            Text(
              'لا حجوزات مسجّلة في هذا اليوم',
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: placeInk2,
                height: 1.45,
              ),
            )
          else ...[
            Text(
              '${bookings.length} حجز${bookings.length > 1 ? 'اً' : ''}',
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: placeInk2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in bookings)
                  PlaceShiftBadge(
                    shift: b.shift,
                    compact: false,
                    external: b.isExternal,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ثيم بوابة المالك — كحلي وذهب — للشاشات خارج إطار البوابة.
class OwnerTheme extends StatelessWidget {
  const OwnerTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: applyWorld(Theme.of(context), WorldPalette.owner),
    child: child,
  );
}

WorldPalette get _o => WorldPalette.owner;
const _ink = Color(0xFF0F1B2D);
const _ink2 = Color(0xFF5B6576);
const _line = Color(0xFFEDEEF1);
const _soft = Color(0xFFF5F6F8);

/// خلفية البوابة.
class OwnerPortalCanvas extends StatelessWidget {
  const OwnerPortalCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: _o.canvas, child: child);
}

class OwnerBrassRule extends StatelessWidget {
  const OwnerBrassRule({super.key, this.width = 28});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        gradient: _o.fill,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class OwnerMetricTile extends StatelessWidget {
  const OwnerMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final String value;
  final bool highlight;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: highlight ? null : Colors.white,
          gradient: highlight
              ? LinearGradient(colors: [_o.nightHigh, _o.night])
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlight ? Colors.transparent : _line),
          boxShadow: [
            BoxShadow(
              color: _o.night.withValues(alpha: highlight ? .25 : .04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: highlight
                      ? Colors.white.withValues(alpha: .12)
                      : _o.accentFaint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: highlight ? _o.accentLight : _o.accentDeep,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: highlight ? Colors.white : _ink,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: highlight ? Colors.white.withValues(alpha: .75) : _ink2,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerQuickAction extends StatelessWidget {
  const OwnerQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: _o.night.withValues(alpha: .06),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 24, color: _o.nightHigh),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: _o.fill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: _o.onAccent,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerAlertBanner extends StatelessWidget {
  const OwnerAlertBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onAction,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _o.accent.withValues(alpha: .45),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: _o.glow.withValues(alpha: .18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _o.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: _o.onAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
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
                      color: _ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink2,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_o.nightHigh, _o.night]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: _o.accentLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerSectionTitle extends StatelessWidget {
  const OwnerSectionTitle(this.text, {super.key, this.subtitle, this.trailing});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink2,
                      height: 1.45,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// بطاقة أرباح الشهر — كحلي بزخرفة ذهبية، الرقم الكبير، اتجاه الشهر،
/// ومخطط صغير لآخر الأشهر.
class OwnerRevenueHero extends StatelessWidget {
  const OwnerRevenueHero({
    super.key,
    required this.revenue,
    required this.bookingsCount,
    this.onTap,
    this.series = const [],
  });

  final num revenue;
  final int bookingsCount;
  final VoidCallback? onTap;

  /// إيرادات آخر الأشهر بالترتيب الزمني (للمخطط والاتجاه).
  final List<num> series;

  @override
  Widget build(BuildContext context) {
    num? trend;
    if (series.length >= 2 && series[series.length - 2] > 0) {
      trend =
          (series.last - series[series.length - 2]) /
          series[series.length - 2] *
          100;
    }
    return PressScale(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_o.nightHigh, _o.night],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _o.night.withValues(alpha: .30),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -40,
              top: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _o.accent.withValues(alpha: .28),
                      _o.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'أرباح هذا الشهر',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                      const Spacer(),
                      if (trend != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (trend >= 0
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFF87171))
                                    .withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trend >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                size: 14,
                                color: trend >= 0
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${trend.abs().round()}٪',
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: trend >= 0
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatIqdShort(revenue),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'د.ع',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _o.accentLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$bookingsCount ${bookingsCount == 1 ? 'حجز مؤكد' : 'حجوزات مؤكدة'} هذا الشهر',
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: .7),
                    ),
                  ),
                  if (series.length >= 2) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _Sparkline(series, _o.accentLight),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'التقارير الكاملة',
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _o.accentLight,
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: _o.accentLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.values, this.color);

  final List<num> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV).abs() < 1 ? 1.0 : maxV - minV;
    // الزمن من اليسار لليمين دائماً
    Offset pt(int i) => Offset(
      size.width * i / (values.length - 1),
      size.height - 4 - (values[i] - minV) / range * (size.height - 8),
    );
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = pt(i - 1), b = pt(i);
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pt(values.length - 1), 4, Paint()..color = Colors.white);
    canvas.drawCircle(pt(values.length - 1), 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Sparkline old) =>
      old.values != values || old.color != color;
}

class OwnerCoverageStack extends StatelessWidget {
  const OwnerCoverageStack({
    super.key,
    required this.platformDays,
    required this.externalDays,
    required this.closedDays,
    required this.openDays,
    required this.totalSlots,
  });

  final int platformDays;
  final int externalDays;
  final int closedDays;
  final int openDays;
  final int totalSlots;

  @override
  Widget build(BuildContext context) {
    if (totalSlots <= 0) return const SizedBox.shrink();
    final filled = platformDays + externalDays + closedDays;
    final platformW = platformDays / totalSlots;
    final externalW = externalDays / totalSlots;
    final closedW = closedDays / totalSlots;
    final openW = openDays / totalSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (platformW > 0)
                  Expanded(
                    flex: (platformW * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: _o.nightHigh),
                  ),
                if (externalW > 0)
                  Expanded(
                    flex: (externalW * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: _o.accent),
                  ),
                if (closedW > 0)
                  Expanded(
                    flex: (closedW * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: placeInk2.withValues(alpha: .35)),
                  ),
                if (openW > 0)
                  Expanded(
                    flex: (openW * 1000).round().clamp(1, 1000),
                    child: const ColoredBox(color: ownerLine),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${((filled / totalSlots) * 100).round()}% من أيام الـ30 القادمة مُغطّاة',
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: placeInk2,
          ),
        ),
      ],
    );
  }
}

class OwnerCalendarLegend extends StatelessWidget {
  const OwnerCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendDot(color: placeShiftMorning, label: 'صباح'),
        _LegendDot(color: placeShiftEvening, label: 'مساء'),
        _LegendDot(color: placeShiftFull, label: 'يوم كامل'),
        _LegendDot(color: ownerGoldDeep, label: 'خارجي'),
        _LegendDot(color: placeInk2, label: 'مغلق'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: placeInk2,
          ),
        ),
      ],
    );
  }
}

class OwnerSearchField extends StatelessWidget {
  const OwnerSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: VibesFont.ui,
        fontWeight: FontWeight.w700,
        color: _ink,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: VibesFont.ui,
          fontWeight: FontWeight.w600,
          color: _ink2,
        ),
        filled: true,
        fillColor: _soft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: b(Colors.transparent),
        enabledBorder: b(Colors.transparent),
        focusedBorder: b(_o.accent, 1.4),
        prefixIcon: const Icon(Icons.search_rounded, color: _ink2, size: 22),
      ),
    );
  }
}

class OwnerMenuTile extends StatelessWidget {
  const OwnerMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _o.accentFaint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: _o.accentDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_left_rounded,
                    color: _o.accentDeep.withValues(alpha: .6),
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تنبيه حجوزات الغد مع شارات الشفت.
class OwnerTomorrowBanner extends StatelessWidget {
  const OwnerTomorrowBanner({super.key, required this.bookings, this.onTap});

  final List<Booking> bookings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: _o.night.withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wb_twilight_rounded,
                    size: 20,
                    color: placeShiftEvening,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'غداً · ${bookings.length} حجز',
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ownerNavy,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_left_rounded,
                      color: placeInk2,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OwnerShiftDaySummary(bookings: bookings),
              Text(
                bookings
                    .map((b) => b.propertyName ?? 'مكان')
                    .take(2)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

/// توزيع إيراد الشهر حسب الشفت (صباح / مساء / يوم كامل).
class OwnerShiftRevenueBreakdown extends StatelessWidget {
  const OwnerShiftRevenueBreakdown({super.key, required this.stats});

  final ProviderMonthByShift stats;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (ShiftType.morning, stats.morning),
      (ShiftType.evening, stats.evening),
      (ShiftType.full, stats.full),
    ];
    final totalRevenue = rows.fold<num>(0, (sum, r) => sum + r.$2.revenue);
    if (totalRevenue <= 0 && rows.every((r) => r.$2.bookings == 0)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ownerPaper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ownerLine),
        ),
        child: Text(
          'لا إيرادات مؤكّدة هذا الشهر بعد — تظهر هنا حسب الفترة (صباح / مساء / يوم كامل).',
          style: TextStyle(
            fontFamily: VibesFont.ui,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: placeInk2,
            height: 1.45,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ownerLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هذا الشهر حسب الفترة',
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ownerNavy,
            ),
          ),
          const SizedBox(height: 12),
          for (final (shift, stat) in rows) ...[
            _ShiftRevenueRow(
              shift: shift,
              revenue: stat.revenue,
              bookings: stat.bookings,
              share: totalRevenue > 0 ? stat.revenue / totalRevenue : 0.0,
            ),
            if (shift != ShiftType.full) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ShiftRevenueRow extends StatelessWidget {
  const _ShiftRevenueRow({
    required this.shift,
    required this.revenue,
    required this.bookings,
    required this.share,
  });

  final ShiftType shift;
  final num revenue;
  final int bookings;
  final double share;

  @override
  Widget build(BuildContext context) {
    final color = placeShiftColor(shift);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlaceShiftBadge(shift: shift, compact: true),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$bookings حجز',
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: placeInk2,
                ),
              ),
            ),
            Text(
              '${PriceText.format(revenue)} د.ع',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: ownerLine,
            color: color,
          ),
        ),
      ],
    );
  }
}
