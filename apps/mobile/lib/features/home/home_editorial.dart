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
              : 'اسحب لتشوف المكان التالي',
        ),
        const SizedBox(height: 16),
        _ChosenDeck(properties: props, accent: section.accent),
      ],
    );
  }
}

/// رزمة بطاقات متراكبة — الأمامية كبيرة، واللي وراها تطلّ
/// من الجانب. السحب يقلّب للبطاقة التالية بنعومة.
class _ChosenDeck extends StatefulWidget {
  const _ChosenDeck({required this.properties, required this.accent});

  final List<Property> properties;
  final Color accent;

  @override
  State<_ChosenDeck> createState() => _ChosenDeckState();
}

class _ChosenDeckState extends State<_ChosenDeck> {
  late final PageController _page = PageController(
    viewportFraction: widget.properties.length == 1 ? 1 : 0.84,
  );
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.properties.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      children: [
        SizedBox(
          height: 192,
          child: PageView.builder(
            controller: _page,
            itemCount: n,
            padEnds: false,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _index = i);
            },
            itemBuilder: (context, i) {
              return AnimatedBuilder(
                animation: _page,
                builder: (context, child) {
                  final page = _page.hasClients ? (_page.page ?? 0) : 0.0;
                  final delta = (page - i).clamp(-1.2, 1.2);
                  final abs = delta.abs().clamp(0.0, 1.0);
                  final shift = delta * 36 * (rtl ? -1 : 1);
                  return Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      i == 0 ? 24 : 0,
                      4,
                      n == 1 ? 24 : 10,
                      4,
                    ),
                    child: Transform.translate(
                      offset: Offset(shift, abs * 8),
                      child: Transform.scale(
                        scale: 1 - abs * 0.06,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: (1 - abs * 0.18).clamp(0.62, 1),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: _DeckCard(
                  property: widget.properties[i],
                  accent: widget.accent,
                  index: i,
                  total: n,
                ),
              );
            },
          ),
        ),
        if (n > 1) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < n; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i == _index ? _brass : const Color(0xFFD5DCE6),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard({
    required this.property,
    required this.accent,
    required this.index,
    required this.total,
  });

  final Property property;
  final Color accent;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = (ref.watch(favoritesProvider).valueOrNull ?? const <Property>[])
        .any((p) => p.id == property.id);
    final place = property.cityName ?? property.provinceName ?? '';
    return Semantics(
      button: true,
      label:
          '${property.name}، ${property.typeLabelAr}، ${_money(property.pricePerDay)} دينار',
      child: PressScale(
        onTap: () => context.push('/property/${property.id}'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _shadow(o: 1.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PropertyCover(property: property, iconSize: 46),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.32, 0.58, 1],
                      colors: [
                        Color(0x1A0F1626),
                        Color(0x330F1626),
                        Color(0xDE141C2B),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 12,
                  start: 12,
                  child: _DeckRankMark(rank: index + 1),
                ),
                PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: GestureDetector(
                    onTap: () async {
                      if (!ref.read(authControllerProvider).loggedIn) {
                        await context.push('/login');
                        return;
                      }
                      ref.read(favoritesProvider.notifier).toggle(property);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        fav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: fav ? const Color(0xFFE11D48) : _ink,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        property.typeLabelAr,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _brassSoft.withValues(alpha: 0.95),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        property.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (place.isNotEmpty) place,
                          if (property.ratingCount > 0)
                            '★ ${property.ratingAvg.toStringAsFixed(1)}',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/book/${property.id}'),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'احجز الآن',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _money(property.pricePerDay),
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                switch (property.type) {
                                  PropertyType.decoration => 'د.ع / للخدمة',
                                  _ when property.supportsShifts =>
                                    'د.ع / للفترة',
                                  _ => 'د.ع / لليوم',
                                },
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

/// رقم ترتيبي على بطاقة «أماكن مختارة» — Montserrat تحريري، أبيض بالكامل.
class _DeckRankMark extends StatelessWidget {
  const _DeckRankMark({required this.rank});

  final int rank;

  static const _digitWhite = Colors.white;

  @override
  Widget build(BuildContext context) {
    final label = rank.toString().padLeft(2, '0');
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 6, 11, 7),
          decoration: BoxDecoration(
            color: const Color(0x80101824),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 1.5,
                height: 26,
                margin: const EdgeInsetsDirectional.only(end: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      height: 0.95,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                      color: _digitWhite,
                      fontFeatures: [FontFeature.tabularFigures()],
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 20,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ],
              ),
            ],
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
