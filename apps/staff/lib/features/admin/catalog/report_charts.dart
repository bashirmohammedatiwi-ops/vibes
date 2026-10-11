import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'catalog_common.dart';

/// رسوم بيانية خفيفة بلا حزم خارجية (CustomPainter + عناصر بسيطة).

/// ألوان أنواع الأماكن — ترتيب ثابت ومُتحقق من تمايزه لعمى الألوان.
Color worldColor(String? type) => switch (type) {
      'FARM' => const Color(0xFF0D9488),
      'HALL' => const Color(0xFF4F46E5),
      'DECORATION' => const Color(0xFFD97706),
      _ => placeInk2,
    };

class ChartPoint {
  const ChartPoint(this.label, this.value, {this.detail});
  final String label;
  final double value;
  final String? detail;
}

/// منحنى/أعمدة اتجاه زمني مع لمس لعرض القيمة.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    this.color = placeBrass,
    this.height = 180,
    this.valueFormatter,
    this.bars = false,
  });

  final List<ChartPoint> points;
  final Color color;
  final double height;
  final String Function(double)? valueFormatter;
  final bool bars;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selected;

  void _hit(Offset local, double width) {
    final n = widget.points.length;
    if (n == 0) return;
    // الرسم من اليسار لليمين زمنياً (المحور الزمني LTR حتى في الواجهة العربية).
    const left = _TrendPainter.leftPad;
    final usable = width - left - 8;
    final x = (local.dx - left).clamp(0, usable);
    final i = widget.bars
        ? (x / (usable / n)).floor().clamp(0, n - 1)
        : (n == 1 ? 0 : (x / (usable / (n - 1))).round().clamp(0, n - 1));
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = widget.valueFormatter ?? (v) => fmtCompact(v);
    final sel = _selected != null && _selected! < widget.points.length ? widget.points[_selected!] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: sel == null
                ? const Align(
                    key: ValueKey('hint'),
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('المس الرسم لعرض القيمة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk2)),
                  )
                : Align(
                    key: ValueKey(_selected),
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${sel.label}  ',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: placeInk2),
                        ),
                        TextSpan(
                          text: fmt(sel.value),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: placeInk, fontSize: 15),
                        ),
                        if (sel.detail != null)
                          TextSpan(text: '  · ${sel.detail}', style: const TextStyle(color: placeInk2)),
                      ]),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                  ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _hit(d.localPosition, c.maxWidth),
            onHorizontalDragUpdate: (d) => _hit(d.localPosition, c.maxWidth),
            onHorizontalDragEnd: (_) {},
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CustomPaint(
                size: Size(c.maxWidth, widget.height),
                painter: _TrendPainter(
                  points: widget.points,
                  color: widget.color,
                  selected: _selected,
                  bars: widget.bars,
                  axisFormatter: (v) => fmtCompact(v),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.color,
    required this.selected,
    required this.bars,
    required this.axisFormatter,
  });

  static const leftPad = 40.0;
  static const bottomPad = 22.0;

  final List<ChartPoint> points;
  final Color color;
  final int? selected;
  final bool bars;
  final String Function(double) axisFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - leftPad - 8;
    final chartH = size.height - bottomPad - 6;
    final maxV = points.fold<double>(0, (m, p) => math.max(m, p.value));
    final top = maxV <= 0 ? 1.0 : _niceCeil(maxV);

    final grid = Paint()
      ..color = placeLine
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = 6 + chartH - chartH * i / 3;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - 8, y), grid);
      _text(canvas, axisFormatter(top * i / 3), Offset(0, y - 7), width: leftPad - 6, align: TextAlign.right);
    }
    if (points.isEmpty) return;

    double xAt(int i) {
      if (bars) {
        final slot = chartW / points.length;
        return leftPad + slot * i + slot / 2;
      }
      return points.length == 1 ? leftPad + chartW / 2 : leftPad + chartW * i / (points.length - 1);
    }

    double yAt(double v) => 6 + chartH - (v / top) * chartH;

    if (bars) {
      final slot = chartW / points.length;
      final w = math.max(2.0, math.min(28.0, slot - 2));
      for (var i = 0; i < points.length; i++) {
        final x = xAt(i);
        final y = yAt(points[i].value);
        final paint = Paint()
          ..color = selected == null || selected == i ? color : color.withValues(alpha: 0.35);
        final h = 6 + chartH - y;
        if (h <= 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x - w / 2, y, w, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          paint,
        );
      }
    } else {
      final path = Path();
      final area = Path();
      for (var i = 0; i < points.length; i++) {
        final o = Offset(xAt(i), yAt(points[i].value));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
          area.moveTo(o.dx, 6 + chartH);
          area.lineTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
          area.lineTo(o.dx, o.dy);
        }
      }
      area.lineTo(xAt(points.length - 1), 6 + chartH);
      area.close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.02)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      if (selected != null && selected! < points.length) {
        final o = Offset(xAt(selected!), yAt(points[selected!].value));
        canvas.drawLine(
          Offset(o.dx, 6),
          Offset(o.dx, 6 + chartH),
          Paint()
            ..color = placeInk2.withValues(alpha: 0.4)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(o, 6, Paint()..color = Colors.white);
        canvas.drawCircle(o, 4.5, Paint()..color = color);
      }
    }

    // تسميات المحور الأفقي: أول ووسط وآخر.
    final idx = <int>{0, points.length ~/ 2, points.length - 1};
    for (final i in idx) {
      final x = xAt(i);
      _text(canvas, points[i].label, Offset(x - 40, size.height - 16), width: 80, align: TextAlign.center);
    }
  }

  double _niceCeil(double v) {
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / exp;
    final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
    return nice * exp;
  }

  void _text(Canvas canvas, String s, Offset at, {required double width, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: placeInk2)),
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points || old.selected != selected || old.color != color || old.bars != bars;
}

/// أعمدة أفقية مرتبة (للحالات والمحافظات …).
class HBarList extends StatelessWidget {
  const HBarList({super.key, required this.items, this.color = placeInk, this.valueFormatter, this.colorOf});

  final List<ChartPoint> items;
  final Color color;
  final String Function(double)? valueFormatter;
  final Color Function(int index, ChartPoint p)? colorOf;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('لا بيانات في هذه الفترة', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
      );
    }
    final maxV = items.fold<double>(0, (m, p) => math.max(m, p.value));
    final fmt = valueFormatter ?? (v) => fmtCount(v);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk),
                      ),
                    ),
                    Text(
                      fmt(items[i].value),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w900, color: placeInk),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 8, color: placeLine.withValues(alpha: 0.6)),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: maxV <= 0 ? 0 : (items[i].value / maxV).clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorOf?.call(i, items[i]) ?? color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// حلقة نسب مع وسيلة إيضاح (للتوزيع حسب نوع العالم).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.items, required this.colorOf, this.centerLabel = 'الإجمالي'});

  final List<ChartPoint> items;
  final Color Function(ChartPoint) colorOf;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, p) => s + p.value);
    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('لا بيانات في هذه الفترة', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(items: items, colorOf: colorOf, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmtCount(total),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
                  Text(centerLabel, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: placeInk2)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colorOf(p), borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.label,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk)),
                      ),
                      Text(
                        '${fmtCount(p.value)} · ${(p.value / total * 100).round()}%',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.items, required this.colorOf, required this.total});

  final List<ChartPoint> items;
  final Color Function(ChartPoint) colorOf;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final gap = items.where((p) => p.value > 0).length > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;
    for (final p in items) {
      if (p.value <= 0) continue;
      final sweep = (p.value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        Paint()
          ..color = colorOf(p)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.items != items || old.total != total;
}

/// بطاقة مؤشر رئيسي مع تغيّر اختياري.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = placeInk,
    this.changePct,
    this.caption,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color accent;
  final num? changePct;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final change = changePct;
    final up = (change ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: placeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w900, color: placeInk),
            ),
          ),
          if (change != null)
            Row(
              children: [
                Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 15, color: up ? placeSuccess : placeDanger),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${up ? '+' : ''}$change% عن الفترة السابقة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: up ? placeSuccess : placeDanger,
                    ),
                  ),
                ),
              ],
            )
          else if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.w700, color: placeInk2),
            ),
        ],
      ),
    );
  }
}
