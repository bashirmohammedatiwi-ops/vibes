import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/world_glyphs.dart';
import '../../shared/widgets/world_ui.dart';
import 'nadeem_config.dart';

/// ═══════════════════════════════════════════════════════════
/// نديم — مخطّط المناسبات. محادثة حيّة لا استبيان:
///   • نديم يكتب ويتفاعل مع كل إجابة، وإجاباتك فقاعات بلون العالم
///     (المسها لتعدّلها).
///   • لكل سؤال أداة خاصة: بطاقات مصوّرة للمناسبة، أيقونات العوالم،
///     عدّاد ضيوف بحشد يكبر أمامك، سماء الصباح والمساء للتوقيت،
///     وميزانية فوق رسم حيّ لأسعار الأماكن الحقيقية.
///   • النتيجة: خطة مناسبتك وبطاقات بحلقة تطابق وأسباب الاختيار.
/// ═══════════════════════════════════════════════════════════

class NadeemScreen extends ConsumerStatefulWidget {
  const NadeemScreen({super.key});

  @override
  ConsumerState<NadeemScreen> createState() => _NadeemScreenState();
}

enum _Shift { full, morning, evening, flex }

class _Answers {
  NadeemOccasion? occasion;
  PropertyType? type;
  bool typeOpen = false;
  String? provinceSlug;
  String? provinceName;
  int? minCapacity;
  String? guestsLabel;
  num? maxPrice;
  bool budgetOpen = false;
  _Shift? shift;

  PropertyType? get impliedType {
    if (type != null) return type;
    if (typeOpen) return occasion?.impliedType;
    return null;
  }

  String get occasionLabel => occasion?.label ?? 'مناسبتك';
}

/// رسالة في المحادثة.
class _Msg {
  const _Msg.nadeem(this.text) : mine = false, step = null, results = false;
  const _Msg.mine(this.text, this.step) : mine = true, results = false;
  const _Msg.results() : mine = false, text = '', step = null, results = true;

  final bool mine;
  final String text;
  final int? step;
  final bool results;
}

class _Scored {
  const _Scored(
    this.property,
    this.score, {
    required this.reasons,
    required this.precise,
  });

  final Property property;
  final int score;
  final List<String> reasons;
  final bool precise;
}

class _NadeemScreenState extends ConsumerState<NadeemScreen> {
  final _answers = _Answers();
  final _thread = <_Msg>[];
  final _scroll = ScrollController();

  /// الخطوة المعروضة أداتها في الأسفل — ‎-1 حين لا شيء.
  int _step = -1;
  bool _typing = false;
  bool _thinking = false;
  List<_Scored>? _matches;
  List<Property> _decorPicks = const [];
  String? _error;
  int _session = 0;

  /// لقطة الإعدادات عند بدء المحادثة — لا تتغير في منتصفها.
  NadeemConfig? _cfg;
  NadeemConfig get _c => _cfg ?? NadeemConfig.defaults;

  /// معرّف الجلسة على السيرفر (للإحصاءات).
  String? _loggedId;

  /// الخطوات المفعّلة بالترتيب — 0 المناسبة دائماً.
  List<int> get _flow => [
    0,
    if (_c.typeEnabled) 1,
    if (_c.provinceEnabled) 2,
    if (_c.guestsEnabled) 3,
    if (_c.shiftEnabled) 4,
    if (_c.budgetEnabled) 5,
  ];

  int get _total => _flow.length;

  @override
  void initState() {
    super.initState();
    final now = ref.read(nadeemConfigProvider);
    if (now.hasValue) {
      _cfg = now.value;
      _opening();
      // تحديث صامت للمرة القادمة — تعديلات لوحة التحكم تصل بلا إعادة تشغيل
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(nadeemConfigProvider);
      });
    } else {
      ref.read(nadeemConfigProvider.future).then((c) {
        if (!mounted) return;
        setState(() => _cfg = c);
        _opening();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── المحادثة ──

  Future<void> _opening() async {
    if (!_c.enabled) return;
    final s = _session;
    _answers.typeOpen = !_c.typeEnabled;
    final greeting = _c.greeting;
    for (var i = 0; i < greeting.length; i++) {
      await _say(greeting[i], s, delay: i == 0 ? 500 : 900);
    }
    await _ask(0, s);
  }

  Future<void> _say(String text, int session, {int delay = 650}) async {
    if (!mounted || session != _session) return;
    setState(() => _typing = true);
    _toBottom();
    await Future<void>.delayed(
      Duration(milliseconds: (delay * _c.typingScale).round()),
    );
    if (!mounted || session != _session) return;
    setState(() {
      _typing = false;
      _thread.add(_Msg.nadeem(text));
    });
    _toBottom();
  }

  Future<void> _ask(int step, int session) async {
    await _say(_question(step), session);
    if (!mounted || session != _session) return;
    setState(() => _step = step);
    _toBottom();
  }

  String _question(int step) => switch (step) {
    0 => _c.occasionQuestion,
    1 => _c.typeQuestion,
    2 => _c.provinceQuestion,
    3 => _c.guestsQuestion,
    4 => _c.shiftQuestion,
    _ => _c.budgetQuestion,
  };

  String _reaction(int step) => switch (step) {
    0 => _answers.occasion?.reaction ?? '',
    1 => _answers.typeOpen ? _c.typeReactionAuto : _c.typeReaction,
    2 =>
      _answers.provinceName == null
          ? _c.provinceReactionAll
          : fillTokens(_c.provinceReactionOne, {
              'province': _answers.provinceName!,
            }),
    3 => _c.guestsReaction,
    4 => _c.shiftReaction,
    _ => '',
  };

  Future<void> _answer(int step, String label, VoidCallback apply) async {
    HapticFeedback.selectionClick();
    final s = _session;
    setState(() {
      apply();
      _step = -1;
      _thread.add(_Msg.mine(label, step));
    });
    _toBottom();
    final flow = _flow;
    final at = flow.indexOf(step);
    final r = _reaction(step);
    if (r.isNotEmpty) await _say(r, s, delay: 520);
    if (at >= 0 && at < flow.length - 1) {
      await _ask(flow[at + 1], s);
    } else {
      await _finish(s);
    }
  }

  /// لمس إجابة سابقة — يعود إلى سؤالها ويقصّ ما بعده.
  void _editFrom(int step) {
    HapticFeedback.selectionClick();
    final i = _thread.indexWhere((m) => m.mine && m.step == step);
    if (i < 0) return;
    setState(() {
      _session++;
      _thread.removeRange(i, _thread.length);
      _typing = false;
      _thinking = false;
      _matches = null;
      _loggedId = null;
      _error = null;
      _step = step;
    });
    _toBottom();
  }

  void _restart() {
    HapticFeedback.mediumImpact();
    setState(() {
      _session++;
      _thread.clear();
      _step = -1;
      _typing = false;
      _thinking = false;
      _matches = null;
      _loggedId = null;
      _error = null;
      _cfg = ref.read(nadeemConfigProvider).valueOrNull ?? _cfg;
      _answers
        ..occasion = null
        ..type = null
        ..typeOpen = false
        ..provinceSlug = null
        ..provinceName = null
        ..minCapacity = null
        ..guestsLabel = null
        ..maxPrice = null
        ..budgetOpen = false
        ..shift = null;
    });
    _opening();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ── الاختيار ──

  Future<void> _finish(int session) async {
    await _say(_c.finishIntro, session, delay: 500);
    if (!mounted || session != _session) return;
    setState(() {
      _thinking = true;
      _error = null;
    });
    _toBottom();
    try {
      final client = ref.read(apiClientProvider);
      final results = await Future.wait([
        _collectMatches(client, _answers.type),
        Future<void>.delayed(const Duration(milliseconds: 1400)),
      ]);
      var decor = const <Property>[];
      final wantsDecor =
          (_answers.occasion?.suggestDecor ?? false) &&
          _c.decorCount > 0 &&
          _answers.impliedType != PropertyType.decoration;
      if (wantsDecor) {
        final excluded = _c.excluded;
        Future<List<Property>> pull(String? province) async =>
            (await fetchProperties(
                  client,
                  type: 'DECORATION',
                  province: province,
                  sort: 'rating',
                ))
                .where((p) => !excluded.contains(p.id))
                .take(_c.decorCount)
                .toList();
        decor = await pull(_answers.provinceSlug);
        if (decor.isEmpty) decor = await pull(null);
      }
      if (!mounted || session != _session) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _thinking = false;
        _matches = results.first as List<_Scored>;
        _decorPicks = decor;
        _thread.add(const _Msg.results());
      });
      _logSession(session);
    } catch (_) {
      if (!mounted || session != _session) return;
      setState(() {
        _thinking = false;
        _error = _c.finishError;
      });
    }
    _toBottom();
  }

  /// تسجيل الخطة للإحصاءات في لوحة التحكم — لا يؤثر على الزبون إن فشل.
  Future<void> _logSession(int session) async {
    final a = _answers;
    final list = _matches ?? const <_Scored>[];
    try {
      final res = await ref
          .read(apiClientProvider)
          .post(
            '/api/nadeem/sessions',
            body: {
              'occasion': a.occasion?.key,
              'propertyType': a.type == null ? null : _typeKey(a.type!),
              'autoType': a.type == null,
              'province': a.provinceName,
              'guests': a.minCapacity,
              'shift': a.shift?.name,
              'maxBudget': a.budgetOpen ? null : a.maxPrice?.round(),
              'budgetOpen': a.budgetOpen,
              'resultIds': [for (final m in list) m.property.id],
              'precise': list.isNotEmpty && list.first.precise,
              'platform': defaultTargetPlatform.name,
            },
          );
      if (!mounted || session != _session) return;
      if (res is Map && res['id'] is String) _loggedId = res['id'] as String;
    } catch (_) {}
  }

  void _logClick(String propertyId) {
    final id = _loggedId;
    if (id == null) return;
    ref
        .read(apiClientProvider)
        .post(
          '/api/nadeem/sessions/$id/click',
          body: {'propertyId': propertyId},
        )
        .catchError((_) => null);
  }

  Future<List<_Scored>> _collectMatches(
    ApiClient client,
    PropertyType? type,
  ) async {
    final typeKey = type == null ? null : _typeKey(type);
    final excluded = _c.excluded;
    final seen = <String>{...excluded};
    final pool = <Property>[];
    Future<void> pull({String? type, String? province, String? sort}) async {
      final extra = await fetchProperties(
        client,
        type: type,
        province: province,
        sort: sort ?? 'rating',
        pageSize: 100,
      );
      for (final p in extra) {
        if (seen.add(p.id)) pool.add(p);
      }
    }

    await pull(type: typeKey, province: _answers.provinceSlug);
    if (pool.length < 8) await pull(type: typeKey, sort: 'featured');
    if (pool.length < 8 && _answers.provinceSlug != null)
      await pull(province: _answers.provinceSlug);
    if (pool.isEmpty) await pull(sort: 'featured');

    final ranked =
        pool
            .map(
              (p) => _Scored(
                p,
                _score(p),
                reasons: _reasons(p),
                precise: _precise(p),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    final strong = ranked.where((m) => m.score >= _c.minScore).toList();
    return (strong.isNotEmpty ? strong : ranked).take(_c.maxResults).toList();
  }

  bool _precise(Property p) {
    final typeOk = _answers.type == null || p.type == _answers.type;
    final cityOk =
        _answers.provinceName == null ||
        p.provinceName == _answers.provinceName;
    final capOk =
        _answers.minCapacity == null || p.capacity >= _answers.minCapacity!;
    return typeOk && cityOk && capOk;
  }

  int _score(Property p) {
    final c = _c;
    var s = 0;
    final preferred = _answers.impliedType;
    if (preferred != null)
      s += p.type == preferred ? c.w('type', 40) : c.w('typeMiss', -12);
    final province = _answers.provinceName;
    if (province != null)
      s += p.provinceName == province
          ? c.w('province', 28)
          : c.w('provinceMiss', -10);
    final minCap = _answers.minCapacity;
    if (minCap != null)
      s += p.capacity >= minCap
          ? c.w('capacity', 22)
          : c.w('capacityMiss', -24);
    final maxPrice = _answers.maxPrice;
    if (maxPrice != null && !_answers.budgetOpen)
      s += _fromPrice(p) <= maxPrice
          ? c.w('budget', 18)
          : c.w('budgetMiss', -20);
    final shiftPrice = c.w('shiftPrice', 12);
    final shiftSupport = c.w('shiftSupport', 6);
    switch (_answers.shift) {
      case _Shift.morning:
        if (p.priceMorningShift != null) s += shiftPrice;
        if (p.supportsShifts) s += shiftSupport;
      case _Shift.evening:
        if (p.priceEveningShift != null) s += shiftPrice;
        if (p.supportsShifts) s += shiftSupport;
      case _Shift.full:
        if (!p.supportsShifts) s += c.w('fullDay', 8);
      case _Shift.flex:
        s += c.w('flex', 4);
      case null:
        break;
    }
    s += (p.ratingAvg * c.w('ratingMultiplier', 3)).round();
    if (p.featured) s += c.w('featured', 6);
    if (p.isWinter) s += c.w('winter', 0);
    s += c.pinned[p.id] ?? 0;
    return s;
  }

  /// نسبة التطابق المعروضة — من الدرجة إلى المدى المحدد في لوحة التحكم.
  int _matchPercent(int score) {
    final lo = _c.minPercent, hi = _c.maxPercent;
    return (lo + (score.clamp(-20, 110) + 20) / 130 * (hi - lo)).round().clamp(
      lo,
      hi,
    );
  }

  List<String> _reasons(Property p) {
    if (!_c.showReasons) return const [];
    final r = <String>[];
    if (_answers.provinceName != null &&
        p.provinceName == _answers.provinceName)
      r.add('في ${p.provinceName}');
    if (_answers.minCapacity != null && p.capacity >= _answers.minCapacity!)
      r.add('يتسع لـ ${p.capacity}');
    if (_answers.maxPrice != null &&
        !_answers.budgetOpen &&
        _fromPrice(p) <= _answers.maxPrice!) {
      r.add('ضمن ميزانيتك');
    }
    if (_answers.shift == _Shift.evening && p.priceEveningShift != null)
      r.add('شفت مسائي');
    if (_answers.shift == _Shift.morning && p.priceMorningShift != null)
      r.add('شفت صباحي');
    if (p.ratingCount > 0 && p.ratingAvg >= 4.5)
      r.add('تقييم ${p.ratingAvg.toStringAsFixed(1)}');
    if (p.featured) r.add('مختار');
    return r.take(3).toList();
  }

  // ── البناء ──

  WorldPalette get _palette => switch (_answers.impliedType) {
    PropertyType.farm => WorldPalette.farm,
    PropertyType.hall => WorldPalette.hall,
    PropertyType.decoration => WorldPalette.decoration,
    null => context.world,
  };

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 500),
      data: applyWorld(Theme.of(context), p),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayFor(darkBackground: false),
        child: Scaffold(
          backgroundColor: p.canvas,
          body: Column(
            children: [
              _TopBar(
                name: _c.name,
                subtitle: _c.subtitle,
                typingLabel: _c.typingLabel,
                typing: _typing || _thinking,
                progress: _progress,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                onRestart: _restart,
              ),
              if (_cfg == null)
                const Expanded(child: Center(child: _Orb(size: 64)))
              else if (!_c.enabled)
                Expanded(child: _disabled())
              else
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      for (var i = 0; i < _thread.length; i++)
                        _message(_thread[i], i),
                      if (_typing) const _TypingBubble(),
                      if (_thinking)
                        _ThinkingCard(palette: p, text: _c.finishThinking),
                      if (_error != null) _errorCard(),
                    ],
                  ),
                ),
              if (_cfg != null && _c.enabled) _composer(),
            ],
          ),
        ),
      ),
    );
  }

  double get _progress {
    final answered = _thread.where((m) => m.mine).length;
    return (answered / _total).clamp(0.0, 1.0);
  }

  Widget _message(_Msg m, int index) {
    if (m.results) return _results();
    final showAvatar =
        !m.mine &&
        (index == _thread.length - 1 ||
            _thread[index + 1].mine ||
            _thread[index + 1].results);
    return _Bubble(
      key: ValueKey('msg-$index-${m.text}'),
      text: m.text,
      mine: m.mine,
      showAvatar: showAvatar,
      onTap: m.mine && m.step != null && !_thinking
          ? () => _editFrom(m.step!)
          : null,
    );
  }

  Widget _disabled() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Orb(size: 72),
            const SizedBox(height: 18),
            Text(
              _c.disabledTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Vibes.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _c.disabledMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Vibes.inkSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            WorldButton(
              label: 'ابحث عن مكان',
              icon: Icons.search_rounded,
              height: 50,
              onTap: () => context.push('/search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(height: 10),
            WorldGhostButton(
              label: _c.retryLabel,
              icon: Icons.refresh_rounded,
              height: 44,
              onTap: () => _finish(_session),
            ),
          ],
        ),
      ),
    );
  }

  // ── أدوات الإجابة ──

  Widget _composer() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final Widget? body = switch (_step) {
      0 => _OccasionPicker(
        occasions: _c.occasions,
        onPick: (o) => _answer(0, o.label, () => _answers.occasion = o),
      ),
      1 => _TypePicker(
        config: _c,
        onPick: (t, label) => _answer(1, label, () {
          _answers.type = t;
          _answers.typeOpen = t == null;
        }),
      ),
      2 => _ProvincePicker(
        config: _c,
        type: _answers.impliedType,
        onPick: (slug, name) => _answer(2, name ?? _c.provinceAnyLabel, () {
          _answers.provinceSlug = slug;
          _answers.provinceName = name;
        }),
      ),
      3 => _GuestDial(
        config: _c,
        onDone: (n) {
          final label = fillTokens(_c.guestsAnswer, {'n': '$n'});
          _answer(3, label, () {
            _answers.minCapacity = n;
            _answers.guestsLabel = label;
          });
        },
      ),
      4 => _DayPicker(
        config: _c,
        onPick: (s, label) => _answer(4, label, () => _answers.shift = s),
      ),
      5 => _BudgetPicker(
        config: _c,
        type: _answers.impliedType,
        onDone: (max) => _answer(
          5,
          max == null
              ? _c.budgetOpenAnswer
              : fillTokens(_c.budgetAnswer, {'amount': _money(max)}),
          () {
            _answers.budgetOpen = max == null;
            _answers.maxPrice = max;
          },
        ),
      ),
      _ => null,
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .12),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: body == null
            ? SizedBox(key: const ValueKey('none'), height: bottom)
            : Container(
                key: ValueKey('step-$_step'),
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 30,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: body,
              ),
      ),
    );
  }

  // ── النتائج ──

  Widget _results() {
    final p = _palette;
    final list = _matches ?? const <_Scored>[];
    final width = MediaQuery.sizeOf(context).width;
    final card = (width * .78).clamp(260.0, 360.0);
    final c = _c;
    final chips = <(int, IconData, String)>[
      (0, Icons.celebration_rounded, _answers.occasionLabel),
      if (c.typeEnabled)
        if (_answers.type != null)
          (1, Icons.home_work_rounded, _typeLabel(_answers.type!))
        else
          (1, Icons.auto_awesome_rounded, c.autoTypeChip),
      if (c.provinceEnabled)
        (2, Icons.location_on_rounded, _answers.provinceName ?? 'كل العراق'),
      if (_answers.minCapacity != null)
        (3, Icons.groups_rounded, '${_answers.minCapacity} ضيف'),
      if (_answers.shift != null)
        (4, Icons.schedule_rounded, _shiftLabel(_answers.shift!)),
      if (c.budgetEnabled)
        (
          5,
          Icons.payments_rounded,
          _answers.budgetOpen || _answers.maxPrice == null
              ? c.budgetOpenLabel
              : 'حتى ${_money(_answers.maxPrice!)}',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // خطة المناسبة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color.lerp(p.accent, p.accentDeep, .2)!,
                  p.accentDeep,
                  Color.lerp(p.accentDeep, p.night, .5)!,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: p.glowShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const VibesLogo.mark(size: 28, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fillTokens(c.resultsTitle, {
                          'occasion': _answers.occasionLabel,
                        }),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      list.isEmpty ? '' : '${list.length} اقتراح',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: .8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in chips)
                      PressScale(
                        onTap: () => _editFrom(c.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.$2, size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                c.$3,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  c.editHint,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: .65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Bubble(
            text: list.isEmpty
                ? c.resultsEmpty
                : list.first.precise
                ? c.resultsPrecise
                : c.resultsApprox,
            mine: false,
            showAvatar: true,
          ),
          if (list.isNotEmpty)
            SizedBox(
              height: card * .62 + 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _MatchCard(
                  scored: list[i],
                  width: card,
                  percent: c.showMatchPercent
                      ? _matchPercent(list[i].score)
                      : null,
                  best: i == 0,
                  bestLabel: 'اختيار ${c.name} الأول',
                  onOpen: () => _logClick(list[i].property.id),
                ),
              ),
            ),
          if (_decorPicks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Bubble(text: c.decorIntro, mine: false, showAvatar: true),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _decorPicks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _MiniPlace(
                  property: _decorPicks[i],
                  onOpen: () => _logClick(_decorPicks[i].id),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: WorldGhostButton(
                  label: c.restartLabel,
                  icon: Icons.refresh_rounded,
                  height: 48,
                  onTap: _restart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WorldButton(
                  label: c.allResultsLabel,
                  icon: Icons.search_rounded,
                  height: 48,
                  onTap: () {
                    final t = _answers.impliedType;
                    final type = t == null
                        ? ''
                        : 'type=${t.name.toUpperCase()}';
                    final prov = _answers.provinceSlug == null
                        ? ''
                        : 'province=${_answers.provinceSlug}';
                    context.push(
                      '/search?${[type, prov].where((e) => e.isNotEmpty).join('&')}',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// أدوات مساعدة
// ═══════════════════════════════════════════════════════════

num _fromPrice(Property p) {
  final prices = <num>[
    p.pricePerDay,
    if (p.priceMorningShift != null) p.priceMorningShift!,
    if (p.priceEveningShift != null) p.priceEveningShift!,
  ].where((v) => v > 0).toList()..sort();
  return prices.isEmpty ? p.pricePerDay : prices.first;
}

String _money(num v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return '${m == m.roundToDouble() ? m.toInt() : m.toStringAsFixed(1)} مليون';
  }
  if (v >= 1000) return '${(v / 1000).round()} ألف';
  return formatIqdShort(v);
}

String _typeKey(PropertyType t) => switch (t) {
  PropertyType.farm => 'FARM',
  PropertyType.hall => 'HALL',
  PropertyType.decoration => 'DECORATION',
};

String _typeLabel(PropertyType t) => switch (t) {
  PropertyType.farm => 'مزرعة',
  PropertyType.hall => 'قاعة',
  PropertyType.decoration => 'تزيين',
};

String _shiftLabel(_Shift s) => switch (s) {
  _Shift.full => 'يوم كامل',
  _Shift.morning => 'صباحاً',
  _Shift.evening => 'مساءً',
  _Shift.flex => 'توقيت مرن',
};

// ═══════════════════════════════════════════════════════════
// الرأس
// ═══════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.subtitle,
    required this.typingLabel,
    required this.typing,
    required this.progress,
    required this.onBack,
    required this.onRestart,
  });

  final String name;
  final String subtitle;
  final String typingLabel;
  final bool typing;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Round(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 10),
              const _Orb(size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                        height: 1.2,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        typing ? typingLabel : subtitle,
                        key: ValueKey(typing),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: typing ? p.accentDeep : Vibes.inkTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _Round(icon: Icons.refresh_rounded, onTap: onRestart),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 3,
                backgroundColor: const Color(0xFFF0F1F3),
                valueColor: AlwaysStoppedAnimation(p.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F3F5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Vibes.ink),
      ),
    );
  }
}

/// كرة نديم — تدرّج العالم بحلقة ضوء تدور ببطء والشعار في المنتصف.
class _Orb extends StatefulWidget {
  const _Orb({required this.size});

  final double size;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    p.accentLight,
                    p.accent,
                    p.accentDeep,
                    p.accentLight,
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: s - 5,
            height: s - 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accent, p.accentDeep],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(s * .22),
              child: const VibesLogo.mark(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الفقاعات
// ═══════════════════════════════════════════════════════════

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.text,
    required this.mine,
    this.showAvatar = false,
    this.onTap,
  });

  final String text;
  final bool mine;
  final bool showAvatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .74,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: mine ? p.fill : null,
        color: mine ? null : Colors.white,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(20),
          topEnd: const Radius.circular(20),
          bottomStart: Radius.circular(mine ? 20 : 6),
          bottomEnd: Radius.circular(mine ? 6 : 20),
        ),
        border: mine ? null : Border.all(color: const Color(0xFFEDEEF1)),
        boxShadow: [
          BoxShadow(
            color: mine
                ? p.glow.withValues(alpha: .25)
                : Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.5,
                fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
                color: mine ? p.onAccent : Vibes.ink,
                height: 1.55,
              ),
            ),
          ),
          if (mine && onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.edit_rounded,
              size: 13,
              color: p.onAccent.withValues(alpha: .7),
            ),
          ],
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              SizedBox(
                width: 30,
                child: showAvatar ? const _Orb(size: 30) : null,
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(onTap: onTap, child: bubble),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const _Orb(size: 30),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(20),
                topEnd: Radius.circular(20),
                bottomStart: Radius.circular(6),
                bottomEnd: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0xFFEDEEF1)),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Transform.translate(
                      offset: Offset(
                        0,
                        -3 *
                            math
                                .sin(((_c.value - i * .18) % 1) * math.pi)
                                .clamp(0, 1),
                      ),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Color.lerp(p.accentLight, p.accentDeep, i / 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة «أقرأ الأماكن» — كرة تتنفس وحلقات تتسع.
class _ThinkingCard extends StatefulWidget {
  const _ThinkingCard({required this.palette, required this.text});

  final WorldPalette palette;
  final String text;

  @override
  State<_ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<_ThinkingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 2; i++)
                    Builder(
                      builder: (context) {
                        final t = (_c.value + i * .5) % 1;
                        return Opacity(
                          opacity: (1 - t) * .5,
                          child: Container(
                            width: 60 + 60 * t,
                            height: 60 + 60 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: p.accent, width: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  const _Orb(size: 60),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.accentDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// المناسبة — بطاقات بأيقونة متدرّجة
// ═══════════════════════════════════════════════════════════

class _OccasionPicker extends StatelessWidget {
  const _OccasionPicker({required this.occasions, required this.onPick});

  final List<NadeemOccasion> occasions;
  final void Function(NadeemOccasion) onPick;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final o in occasions) (o, o.label, o.sub, o.icon, o.world),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .95,
      children: [
        for (final it in items)
          PressScale(
            onTap: () => onPick(it.$1),
            child: Container(
              decoration: BoxDecoration(
                color: it.$5.palette.canvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: it.$5.palette.accent.withValues(alpha: .18),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: it.$5.palette.fill,
                      shape: BoxShape.circle,
                      boxShadow: it.$5.palette.glowShadow,
                    ),
                    child: Icon(it.$4, color: it.$5.palette.onAccent, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    it.$2,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Vibes.ink,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    it.$3,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Vibes.inkTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// نوع المكان — أيقونات العوالم المرسومة
// ═══════════════════════════════════════════════════════════

class _TypePicker extends ConsumerWidget {
  const _TypePicker({required this.config, required this.onPick});

  final NadeemConfig config;
  final void Function(PropertyType?, String) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = config.types;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final it in items) ...[
              if (it != items.first) const SizedBox(width: 10),
              Expanded(
                child: PressScale(
                  onTap: () => onPick(it.$1, it.$3),
                  child: Container(
                    height: 116,
                    decoration: BoxDecoration(
                      color: it.$2.palette.canvas,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: it.$2.palette.accent.withValues(alpha: .2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        WorldGlyph(
                          section: it.$2,
                          size: 44,
                          primary: it.$2.palette.accentDeep,
                          secondary: it.$2.palette.accentLight,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          it.$3,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Vibes.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (config.typeAllowAuto) ...[
          const SizedBox(height: 10),
          _SoftLink(
            icon: Icons.auto_awesome_rounded,
            label: config.typeAutoLabel,
            onTap: () => onPick(null, config.typeAutoAnswer),
          ),
        ],
      ],
    );
  }
}

class _SoftLink extends StatelessWidget {
  const _SoftLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: p.accentFaint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: p.accentDeep),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: p.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// المحافظة — بطاقات بأعداد الأماكن
// ═══════════════════════════════════════════════════════════

class _ProvincePicker extends ConsumerWidget {
  const _ProvincePicker({
    required this.config,
    required this.type,
    required this.onPick,
  });

  final NadeemConfig config;
  final PropertyType? type;
  final void Function(String?, String?) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final cities =
        ref.watch(locationsProvider).valueOrNull ?? const <CityOption>[];
    final props =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    final provinces = <String, ({String name, String slug})>{};
    for (final c in cities) {
      final slug = c.provinceSlug;
      if (slug != null && slug.isNotEmpty && c.provinceName.isNotEmpty)
        provinces[slug] = (name: c.provinceName, slug: slug);
    }
    int count(String name) => props
        .where(
          (x) => x.provinceName == name && (type == null || x.type == type),
        )
        .length;
    final list =
        provinces.values
            .where((pr) => !config.provinceHideEmpty || count(pr.name) > 0)
            .toList()
          ..sort((a, b) => count(b.name).compareTo(count(a.name)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pr in list)
                  PressScale(
                    onTap: () => onPick(pr.slug, pr.name),
                    child: Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        9,
                        10,
                        9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: p.accentDeep,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            pr.name,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Vibes.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SoftLink(
          icon: Icons.public_rounded,
          label: config.provinceAnyLabel,
          onTap: () => onPick(null, null),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الضيوف — رقم كبير وحشد يكبر أمامك
// ═══════════════════════════════════════════════════════════

class _GuestDial extends StatefulWidget {
  const _GuestDial({required this.config, required this.onDone});

  final NadeemConfig config;
  final ValueChanged<int> onDone;

  @override
  State<_GuestDial> createState() => _GuestDialState();
}

class _GuestDialState extends State<_GuestDial> {
  int get _min => widget.config.guestsMin;
  int get _max => widget.config.guestsMax;

  late double _t = _tFor(widget.config.guestsInitial);

  double _tFor(int n) =>
      math.sqrt(((n - _min) / (_max - _min)).clamp(0.0, 1.0));

  /// منحنى غير خطي — دقة أكبر للأعداد الصغيرة.
  int get _guests {
    final raw = _min + (_max - _min) * math.pow(_t, 2);
    final step = raw < 100 ? 5 : (raw < 300 ? 10 : 50);
    return ((raw / step).round() * step).clamp(_min, _max);
  }

  String get _scale => widget.config.guestScale(_guests);

  void _nudge(int delta) {
    HapticFeedback.selectionClick();
    final target = (_guests + delta).clamp(_min, _max);
    setState(() => _t = _tFor(target));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final people = (_guests / 25).ceil().clamp(1, 28);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StepBtn(
              icon: Icons.remove_rounded,
              onTap: () => _nudge(_guests > 300 ? -50 : -10),
            ),
            Expanded(
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: _guests.toDouble()),
                    duration: const Duration(milliseconds: 260),
                    builder: (context, v, _) => Text(
                      '${v.round()}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Vibes.ink,
                        height: 1.05,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      'ضيف · $_scale',
                      key: ValueKey(_scale),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: p.accentDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _StepBtn(
              icon: Icons.add_rounded,
              onTap: () => _nudge(_guests >= 300 ? 50 : 10),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // الحشد
        SizedBox(
          height: 30,
          child: Center(
            child: Wrap(
              spacing: 1,
              children: [
                for (var i = 0; i < people; i++)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(i),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 260),
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: Color.lerp(p.accentLight, p.accentDeep, i / 28),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: _t,
            onChanged: (v) {
              final before = _guests;
              setState(() => _t = v);
              if (_guests != before) HapticFeedback.selectionClick();
            },
          ),
        ),
        const SizedBox(height: 4),
        WorldButton(
          label: fillTokens(widget.config.guestsConfirm, {'n': '$_guests'}),
          icon: Icons.check_rounded,
          height: 52,
          onTap: () => widget.onDone(_guests),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: p.accent.withValues(alpha: .3)),
        ),
        child: Icon(icon, color: p.accentDeep, size: 24),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// التوقيت — سماء الصباح والمساء
// ═══════════════════════════════════════════════════════════

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.config, required this.onPick});

  final NadeemConfig config;
  final void Function(_Shift, String) onPick;

  @override
  Widget build(BuildContext context) {
    Widget sky({
      required List<Color> colors,
      required IconData icon,
      required Color iconColor,
      required String title,
      required String sub,
      required bool dark,
      required VoidCallback onTap,
    }) => Expanded(
      child: PressScale(
        onTap: onTap,
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: .35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: iconColor),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : Vibes.ink,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? Colors.white.withValues(alpha: .75)
                      : Vibes.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final m = config.morning, e = config.evening, f = config.fullDay;
    final skies = <Widget>[
      if (m.enabled)
        sky(
          colors: const [Color(0xFFFFF4D6), Color(0xFFFFD98A)],
          icon: Icons.wb_sunny_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: m.title,
          sub: m.sub,
          dark: false,
          onTap: () => onPick(_Shift.morning, m.title),
        ),
      if (e.enabled)
        sky(
          colors: const [Color(0xFF3B4A7A), Color(0xFF151B33)],
          icon: Icons.nightlight_round,
          iconColor: const Color(0xFFFDE68A),
          title: e.title,
          sub: e.sub,
          dark: true,
          onTap: () => onPick(_Shift.evening, e.title),
        ),
      if (f.enabled)
        sky(
          colors: const [
            Color(0xFFFFD98A),
            Color(0xFF6D5BBA),
            Color(0xFF151B33),
          ],
          icon: Icons.brightness_6_rounded,
          iconColor: Colors.white,
          title: f.title,
          sub: f.sub,
          dark: true,
          onTap: () => onPick(_Shift.full, f.title),
        ),
    ];
    final showFlex = config.flexEnabled || skies.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (skies.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < skies.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                skies[i],
              ],
            ],
          ),
        if (showFlex) ...[
          if (skies.isNotEmpty) const SizedBox(height: 10),
          _SoftLink(
            icon: Icons.schedule_rounded,
            label: config.flexLabel,
            onTap: () => onPick(_Shift.flex, config.flexAnswer),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الميزانية — رسم حيّ لأسعار الأماكن الحقيقية
// ═══════════════════════════════════════════════════════════

class _BudgetPicker extends ConsumerStatefulWidget {
  const _BudgetPicker({
    required this.config,
    required this.type,
    required this.onDone,
  });

  final NadeemConfig config;
  final PropertyType? type;
  final ValueChanged<num?> onDone;

  @override
  ConsumerState<_BudgetPicker> createState() => _BudgetPickerState();
}

class _BudgetPickerState extends ConsumerState<_BudgetPicker> {
  late double _t = widget.config.budgetInitial;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final all =
        ref.watch(propertiesProvider(null)).valueOrNull ?? const <Property>[];
    var prices =
        all
            .where((x) => widget.type == null || x.type == widget.type)
            .map(_fromPrice)
            .where((v) => v > 0)
            .toList()
          ..sort();
    if (prices.isEmpty) prices = [50000, 2000000];
    final lo = (prices.first * .8 / 10000).floor() * 10000.0;
    final hi = (prices.last * 1.05 / 10000).ceil() * 10000.0;
    final value = ((lo + (hi - lo) * _t) / 10000).round() * 10000;
    final within = prices.where((v) => v <= value).length;

    const bins = 16;
    final counts = List<int>.filled(bins, 0);
    for (final v in prices) {
      final i = (((v - lo) / (hi - lo)) * bins).floor().clamp(0, bins - 1);
      counts[i]++;
    }
    final peak = counts.reduce(math.max).clamp(1, 1 << 30);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'حتى ',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Vibes.inkSecondary,
              ),
            ),
            Text(
              formatIqdShort(value),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Vibes.ink,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'د.ع',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: p.accentDeep,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.accentFaint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                within == 0 ? 'لا أماكن بعد' : 'ضمن ميزانيتك',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: p.accentDeep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // الرسم البياني
        SizedBox(
          height: 64,
          child: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bins; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 6 + 58 * counts[i] / peak,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      gradient: (i + .5) / bins <= _t
                          ? LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [p.accentDeep, p.accentLight],
                            )
                          : null,
                      color: (i + .5) / bins <= _t
                          ? null
                          : const Color(0xFFE9EBEE),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _t,
              onChanged: (v) {
                final before = within;
                setState(() => _t = v);
                final after = prices
                    .where(
                      (x) =>
                          x <= ((lo + (hi - lo) * v) / 10000).round() * 10000,
                    )
                    .length;
                if (after != before) HapticFeedback.selectionClick();
              },
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: WorldGhostButton(
                label: widget.config.budgetOpenLabel,
                icon: Icons.all_inclusive_rounded,
                height: 50,
                onTap: () => widget.onDone(null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: WorldButton(
                label: widget.config.budgetSubmit,
                icon: Icons.auto_awesome_rounded,
                height: 50,
                onTap: () => widget.onDone(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بطاقات النتائج
// ═══════════════════════════════════════════════════════════

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.scored,
    required this.width,
    required this.percent,
    required this.best,
    required this.bestLabel,
    required this.onOpen,
  });

  final _Scored scored;
  final double width;
  final int? percent;
  final bool best;
  final String bestLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final prop = scored.property;
    final p = WorldPalette.forType(prop.type.name);
    final imageH = width * .62;
    return PressScale(
      onTap: () {
        onOpen();
        context.push('/property/${prop.id}');
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: best ? p.accent : const Color(0xFFEDEEF1),
            width: best ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: p.glow.withValues(alpha: best ? .25 : .10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PropertyCover(
                    property: prop,
                    iconSize: 40,
                    memCacheWidth: 720,
                  ),
                  if (best)
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: p.fill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          bestLabel,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: p.onAccent,
                          ),
                        ),
                      ),
                    ),
                  if (percent != null)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: _MatchRing(percent: percent!, color: p.accent),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Vibes.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final r in scored.reasons)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: p.accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              r,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Vibes.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatIqdShort(_fromPrice(prop)),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Vibes.ink,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'د.ع',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: p.accentDeep,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: p.fill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'احجز',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: p.onAccent,
                          ),
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
    );
  }
}

/// حلقة نسبة التطابق — تمتلئ عند الظهور.
class _MatchRing extends StatelessWidget {
  const _MatchRing({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percent / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 3.5,
                backgroundColor: const Color(0xFFEFF0F2),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              '${(v * 100).round()}٪',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Vibes.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlace extends StatelessWidget {
  const _MiniPlace({required this.property, required this.onOpen});

  final Property property;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = WorldPalette.forType(property.type.name);
    return PressScale(
      onTap: () {
        onOpen();
        context.push('/property/${property.id}');
      },
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.accent.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 76,
                child: PropertyCover(property: property, iconSize: 22),
              ),
            ),
            const SizedBox(width: 10),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Vibes.ink,
                    ),
                  ),
                  Text(
                    property.cityName ?? property.provinceName ?? '',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Vibes.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatIqdShort(_fromPrice(property))} د.ع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: p.accentDeep,
                    ),
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
