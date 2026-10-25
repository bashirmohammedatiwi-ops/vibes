import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/map_constants.dart';
import '../auth/auth_controller.dart';
import '../../shared/data/property_providers.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/world_ui.dart';
import 'home_sections.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_map.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../core/perf/perf.dart';

/// ═══════════════════════════════════════════════════════════
/// أقسام الرئيسية — النظام التحريري v5 «الإتقان»
/// الأعلى تقييماً بأرقامه التحريرية المحبوبة (01/02/03 نحاسي)،
/// وبطل وبطاقات مُصقولة بأدق التفاصيل. بلا فيديو نهائياً.
/// ═══════════════════════════════════════════════════════════

const Color _ink = Color(0xFF141C2B);
const Color _ink2 = Color(0xFF5A6678);
const Color _ink3 = Color(0xFFB4BDCC);
const Color _brass = Color(0xFFA5813A);
const Color _brassSoft = Color(0xFFF0DCB4);
const Color _paper = Color(0xFFFFFFFF);
const Color _paperMuted = Color(0xFFF6F7F9);
const Color _line = Color(0xFFE4E9F0);

/// سعر كامل بفواصل الآلاف — للبطاقات، لا لاختصارات الخريطة.
String _money(num v) {
  final str = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    buf.write(str[i]);
    final remaining = str.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buf.write(',');
  }
  return buf.toString();
}

List<BoxShadow> _shadow({double o = 1}) => Perf.shadows([
  BoxShadow(
    color: Color.fromRGBO(20, 28, 43, 0.05 * o),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
  BoxShadow(
    color: Color.fromRGBO(20, 28, 43, 0.07 * o),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
]);

/// ── رأس القسم — عنوان تحريري: عمود نحاسي + كلمة أخيرة بلون النحاس.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(24, 40, 24, 0),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final accent = context.world.accent;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 4, height: 34, color: accent),
              const SizedBox(height: 5),
              Container(
                width: 4,
                height: 10,
                color: _ink.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _SectionTitleText(title: title)),
                    if (actionLabel != null)
                      GestureDetector(
                        onTap: onAction,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                actionLabel!,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 15,
                                color: accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(height: 1, color: _line),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(height: 1, color: _line),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: _ink2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleText extends StatelessWidget {
  const _SectionTitleText({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final accent = context.world.accent;
    const base = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 28,
      height: 1.08,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.65,
    );
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length < 2) {
      return Text(title, style: base.copyWith(color: _ink));
    }
    final head = words.sublist(0, words.length - 1).join(' ');
    final tail = words.last;
    return Text.rich(
      TextSpan(
        style: base.copyWith(color: _ink),
        children: [
          TextSpan(text: '$head '),
          TextSpan(
            text: tail,
            style: base.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

/// ── مختارات المحرر ─────────────────────────────────────────

class EditorsPicks extends ConsumerWidget {
  const EditorsPicks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    final props = (ref.watch(featuredPropertiesProvider).valueOrNull ?? [])
        .where((p) => p.type.name.toUpperCase() == section.typeFilter)
        .toList();

    if (props.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHead(
          title: 'أماكن مختارة',
          subtitle: props.length == 1
              ? 'المكان الذي اخترناه لك'
              : 'اسحب البطاقة لتشوف المكان التالي',
        ),
        const SizedBox(height: 16),
        _ChosenDeck(properties: props, accent: section.accent),
      ],
    );
  }
}

/// رزمة بطاقات متراكبة حقيقية — البطاقة الأمامية فوق الجميع، واثنتان خلفها
/// تطلّان من الأعلى أصغر قليلاً. اسحب البطاقة يميناً أو يساراً: تتبع إصبعك
/// وتميل، ثم تطير لآخر الرزمة وتتقدّم التالية بنعومة. الرزمة تدور بلا نهاية.
class _ChosenDeck extends StatefulWidget {
  const _ChosenDeck({required this.properties, required this.accent});

  final List<Property> properties;
  final Color accent;

  @override
  State<_ChosenDeck> createState() => _ChosenDeckState();
}

class _ChosenDeckState extends State<_ChosenDeck>
    with SingleTickerProviderStateMixin {
  static const _cardHeight = 232.0;
  static const _peek = 11.0; // كم تطلّ كل بطاقة خلفية من الأعلى
  static const _maxDepth = 3;

  late final AnimationController _ctl = AnimationController(vsync: this)
    ..addListener(_tick);
  int _top = 0;
  double _dx = 0;
  double _from = 0;
  double _to = 0;
  bool _flyOut = false;

  int get _n => widget.properties.length;

  @override
  void didUpdateWidget(covariant _ChosenDeck old) {
    super.didUpdateWidget(old);
    if (_top >= _n) _top = 0;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _tick() {
    final t = Curves.easeOutCubic.transform(_ctl.value);
    setState(() => _dx = _from + (_to - _from) * t);
  }

  void _animateTo(double target, {required bool flyOut, double velocity = 0}) {
    _from = _dx;
    _to = target;
    _flyOut = flyOut;
    final distance = (target - _dx).abs();
    final ms = flyOut
        ? (220 - (velocity.abs() / 40)).clamp(140, 220).toInt()
        : (180 + distance / 3).clamp(180, 320).toInt();
    _ctl
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0).whenComplete(() {
        if (!mounted || !_flyOut) return;
        setState(() {
          _top = (_top + 1) % _n;
          _dx = 0;
          _flyOut = false;
        });
      });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_ctl.isAnimating) return;
    setState(() => _dx += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d, double width) {
    if (_ctl.isAnimating) return;
    final v = d.velocity.pixelsPerSecond.dx;
    final passed = _dx.abs() > width * 0.26 || v.abs() > 700;
    if (passed) {
      HapticFeedback.selectionClick();
      final dir = (_dx == 0 ? v : _dx).sign;
      _animateTo(dir * width * 1.25, flyOut: true, velocity: v);
    } else {
      _animateTo(0, flyOut: false);
    }
  }

  void _jumpTo(int i) {
    if (i == _top || _ctl.isAnimating) return;
    HapticFeedback.selectionClick();
    setState(() {
      _top = i;
      _dx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_n == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: _cardHeight,
          child: _DeckCard(
            property: widget.properties.first,
            index: 0,
            total: 1,
          ),
        ),
      );
    }
    final depth = _n < _maxDepth ? _n : _maxDepth;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth - 40;
            // تقدّم البطاقات الخلفية أثناء السحب (0 → 1)
            final progress = (_dx.abs() / (width * 0.45)).clamp(0.0, 1.0);
            final cards = <Widget>[];
            for (var d = depth - 1; d >= 0; d--) {
              final i = (_top + d) % _n;
              final front = d == 0;
              // العمق الفعّال: البطاقات الخلفية تتقدّم خطوة مع السحب
              final eff = front ? 0.0 : d - progress;
              final scale = 1 - eff * 0.055;
              final dy = -eff * _peek;
              Widget card = _DeckCard(
                property: widget.properties[i],
                index: i,
                total: _n,
                dim: front ? 0 : (eff * 0.22).clamp(0.0, 0.44),
              );
              if (front) {
                card = Transform.translate(
                  offset: Offset(_dx, _dx.abs() * 0.04),
                  child: Transform.rotate(
                    angle: (_dx / width) * 0.14,
                    alignment: Alignment.bottomCenter,
                    child: card,
                  ),
                );
                card = GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: (d) => _onDragEnd(d, width),
                  child: card,
                );
              } else {
                card = IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: card,
                    ),
                  ),
                );
              }
              cards.add(
                Positioned(
                  key: ValueKey('deck-$i'),
                  top: _peek * (depth - 1),
                  left: 20,
                  right: 20,
                  height: _cardHeight,
                  child: card,
                ),
              );
            }
            return SizedBox(
              height: _cardHeight + _peek * (depth - 1) + 6,
              child: Stack(clipBehavior: Clip.none, children: cards),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _n; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _jumpTo(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 6,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: i == _top ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _top
                          ? widget.accent
                          : const Color(0xFFD5DCE6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// أقل سعر يبدأ منه المكان (يوم كامل أو فترة).
num _fromPrice(Property p) {
  final prices = <num>[
    p.pricePerDay,
    if (p.priceMorningShift != null) p.priceMorningShift!,
    if (p.priceEveningShift != null) p.priceEveningShift!,
  ].where((v) => v > 0).toList()..sort();
  return prices.isEmpty ? p.pricePerDay : prices.first;
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard({
    required this.property,
    required this.index,
    required this.total,
    this.dim = 0,
  });

  final Property property;
  final int index;
  final int total;

  /// تعتيم البطاقات الخلفية (0 = الأمامية).
  final double dim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = (ref.watch(favoritesProvider).valueOrNull ?? const <Property>[])
        .any((p) => p.id == property.id);
    final place = property.cityName ?? property.provinceName ?? '';
    final price = _fromPrice(property);
    final unit = switch (property.type) {
      PropertyType.decoration => 'للخدمة',
      _ when property.supportsShifts => 'للفترة',
      _ => 'لليوم',
    };
    return Semantics(
      button: true,
      label:
          '${property.name}، ${property.typeLabelAr}، يبدأ من ${_money(price)} دينار',
      child: PressScale(
        onTap: () => context.push('/property/${property.id}'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: _shadow(o: 1.15),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PropertyCover(property: property, iconSize: 46),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.38, 0.62, 1],
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0x660F1626),
                        Color(0xE6101827),
                      ],
                    ),
                  ),
                ),
                // الرأس: الترتيب والمفضلة
                PositionedDirectional(
                  top: 14,
                  start: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: GestureDetector(
                    onTap: () async {
                      if (!ref.read(authControllerProvider).loggedIn) {
                        await context.push('/login');
                        return;
                      }
                      HapticFeedback.lightImpact();
                      ref.read(favoritesProvider.notifier).toggle(property);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        fav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: fav ? const Color(0xFFE11D48) : _ink,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                // الجسم
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _brassSoft.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              property.typeLabelAr,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _brassSoft,
                              ),
                            ),
                          ),
                          if (property.ratingCount > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF5C451),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${property.ratingAvg.toStringAsFixed(1)} (${property.ratingCount})',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        property.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (place.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  place,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'يبدأ من',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    height: 1.1,
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _money(price),
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      TextSpan(
                                        text: '  د.ع · $unit',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/book/${property.id}'),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'احجز الآن',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // تعتيم البطاقات الخلفية (بدل الشفافية التي تُظهر الصور فوق بعض)
                if (dim > 0)
                  IgnorePointer(
                    child: ColoredBox(
                      color: const Color(0xFF0B1220).withValues(alpha: dim),
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

/// بطاقة المكان — صورة سينمائية + جسم تحريري مرتب.
class HomePlaceCard extends StatelessWidget {
  const HomePlaceCard({super.key, required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final meta = [
      property.cityName ?? property.provinceName ?? '',
      if (property.capacity > 0) '${property.capacity} ضيف',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      label:
          '${property.name}، ${property.typeLabelAr}، ${_money(property.pricePerDay)} دينار لليوم',
      child: PressScale(
        onTap: () => context.push('/property/${property.id}'),
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
            boxShadow: _shadow(o: 0.75),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2.12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PropertyCover(property: property, iconSize: 34),
                    if (property.featured)
                      PositionedDirectional(
                        top: 10,
                        end: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _brass.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'مميّز',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14.5,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              property.typeLabelAr,
                              if (meta.isNotEmpty) meta,
                              if (property.ratingCount > 0)
                                '★ ${property.ratingAvg.toStringAsFixed(1)}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: _ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(property.pricePerDay),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            height: 1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text(
                          'د.ع / يوم',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _ink2,
                            height: 1.1,
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
      ),
    );
  }
}

/// ── الأعلى تقييماً — التصميم المحبوب مستعاداً ومطوّراً ────

class TopRatedEditorial extends ConsumerWidget {
  const TopRatedEditorial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    final props = (ref.watch(topRatedPropertiesProvider).valueOrNull ?? [])
        .where(
          (p) =>
              p.type.name.toUpperCase() == section.typeFilter &&
              p.ratingCount > 0,
        )
        .take(5)
        .toList();
    if (props.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SectionHead(
          title: 'الأعلى تقييماً',
          subtitle: 'الأماكن التي نالت أعلى رضا ضيوفنا',
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
            boxShadow: _shadow(o: 0.8),
          ),
          child: Column(
            children: [
              for (var i = 0; i < props.length; i++) ...[
                _RankedRow(
                  property: props[i],
                  rank: i + 1,
                ).animate().fadeIn(delay: (80 * i).ms, duration: 340.ms),
                if (i < props.length - 1)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 136),
                    child: Divider(height: 1, color: _line),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({required this.property, required this.rank});

  final Property property;
  final int rank;

  @override
  Widget build(BuildContext context) {
    // المنصة الثلاث الأولى بأرقام نحاسية — البقية شعرية هادئة
    final podium = rank <= 3;
    return GestureDetector(
      onTap: () => context.push('/property/${property.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
        child: Row(
          children: [
            // الرقم التحريري الضخم zero-padded — روح التصميم
            SizedBox(
              width: 46,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: podium ? _brass : _ink3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _paperMuted,
              ),
              child: PropertyCover(property: property, iconSize: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: podium ? _brass : _ink3,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        property.ratingAvg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${property.ratingCount} تقييم',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // السعر — رقم كبير بحبر قوي ووحدة نحيفة
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _money(property.pricePerDay),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 3),
                const Text(
                  'د.ع',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _ink2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ── معاينة الخريطة — بلاطة حية أسفل المحافظات ─────────────

/// بلاطة خريطة مصغرة حية (غير تفاعلية) — تعرض مواقع الأماكن
/// الفعلية، مع غلاف أنيق: عنوان + عدد + زر فتح كامل.
/// الضغط يفتح شاشة الخريطة الكاملة.
class MapPreviewCard extends ConsumerWidget {
  const MapPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    final props =
        (ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[])
            .where(
              (p) =>
                  p.latitude != null &&
                  p.longitude != null &&
                  p.type.name.toUpperCase() == section.typeFilter,
            )
            .toList();

    return PressScale(
      onTap: () => context.push('/map?type=${section.typeFilter}'),
      child: Container(
        height: 248,
        margin: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: _shadow(o: 1.15),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VibesMapView(
              styleUri: MapConstants.styleUri,
              markers: [
                for (final p in props)
                  VibesMapMarker(
                    id: p.id,
                    latitude: p.latitude!,
                    longitude: p.longitude!,
                    imageUrl: p.coverUrl,
                    accent: accentForType(p.type.name),
                    photoPin: true,
                  ),
              ],
              centerLat: 33.3152,
              centerLng: 44.3661,
              zoom: 10,
              interactive: false,
              focusCluster: true,
              flyToSelection: false,
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 72),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.35, 0.72, 1],
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    _ink.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),

            PositionedDirectional(
              top: 12,
              start: 12,
              end: 12,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                  boxShadow: _shadow(o: 0.65),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _brass,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.label,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${props.length} ${props.length == 1 ? 'مكان' : 'أماكن'} على الخريطة',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.fullscreen_rounded,
                      size: 20,
                      color: section.accent,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              right: 14,
              left: 14,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                  boxShadow: _shadow(o: 0.85),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: section.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: section.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'استكشف على الخريطة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          Text(
                            section.provincesSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _ink,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text(
                        'افتح',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── خاتمة الصفحة — توقيع تحريري فاخر ─────────────────────

class EditorialFooter extends StatelessWidget {
  const EditorialFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 34),
        // خط فاصل بنقطة نحاسية — نفس لغة فاصل البطل
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE4E9F0))),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFA5813A),
                  shape: BoxShape.circle,
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE4E9F0))),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'VIBES',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: Color(0xFFB4BDCC),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'أرقى المزارع والقاعات وخدمات التزيين في العراق',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AA6B8),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// ── حالة فراغ ─────────────────────────────────────────────

class LightEmptyState extends StatelessWidget {
  const LightEmptyState({
    super.key,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.icon = Icons.explore_outlined,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _paperMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Icon(icon, color: _ink3, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: _ink2,
            ),
          ),
        ],
      ),
    );
  }
}
