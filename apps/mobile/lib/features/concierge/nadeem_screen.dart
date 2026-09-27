import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// نديم — رفيق الاختيار. يسأل سؤالاً واحداً في كل صفحة ثم يعرض ما يليق.
class NadeemScreen extends ConsumerStatefulWidget {
  const NadeemScreen({super.key});

  @override
  ConsumerState<NadeemScreen> createState() => _NadeemScreenState();
}

enum _Phase { intro, question, results }

enum _Occasion { wedding, engagement, birthday, family, work, other }

enum _Shift { full, morning, evening, flex }

class _Answers {
  _Occasion? occasion;
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
    if (typeOpen) {
      return switch (occasion) {
        _Occasion.wedding || _Occasion.engagement || _Occasion.work =>
          PropertyType.hall,
        _Occasion.birthday || _Occasion.family => PropertyType.farm,
        _ => null,
      };
    }
    return null;
  }

  String get occasionLabel => switch (occasion) {
    _Occasion.wedding => 'زفاف',
    _Occasion.engagement => 'خطوبة',
    _Occasion.birthday => 'عيد ميلاد',
    _Occasion.family => 'جلسة أهل',
    _Occasion.work => 'مناسبة عمل',
    _Occasion.other => 'مناسبة خاصة',
    null => 'مناسبتك',
  };

  String get summary {
    final bits = <String>[occasionLabel];
    if (type != null) {
      bits.add(switch (type!) {
        PropertyType.farm => 'مزرعة',
        PropertyType.hall => 'قاعة',
        PropertyType.decoration => 'تزيين',
      });
    }
    if (provinceName != null) bits.add(provinceName!);
    if (guestsLabel != null) bits.add(guestsLabel!);
    if (shift != null) {
      bits.add(switch (shift!) {
        _Shift.full => 'يوم كامل',
        _Shift.morning => 'صباح',
        _Shift.evening => 'مساء',
        _Shift.flex => 'توقيت مرن',
      });
    }
    if (budgetOpen) {
      bits.add('ميزانية مفتوحة');
    } else if (maxPrice != null) {
      bits.add('حتى ${PriceText.format(maxPrice!)}');
    }
    return bits.join(' · ');
  }
}

class _NadeemScreenState extends ConsumerState<NadeemScreen> {
  _Phase _phase = _Phase.intro;
  int _step = 0;
  final _answers = _Answers();
  List<_Scored>? _matches;
  bool _loading = false;
  String? _error;

  static const _total = 6;

  void _back() {
    HapticFeedback.selectionClick();
    if (_phase == _Phase.results) {
      setState(() {
        _phase = _Phase.question;
        _step = _total - 1;
        _matches = null;
        _error = null;
      });
      return;
    }
    if (_phase == _Phase.question && _step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (_phase == _Phase.question) {
      setState(() => _phase = _Phase.intro);
      return;
    }
    if (context.canPop()) context.pop();
  }

  Future<void> _pickAndAdvance(VoidCallback apply) async {
    HapticFeedback.selectionClick();
    setState(apply);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (_step < _total - 1) {
      setState(() => _step += 1);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    setState(() {
      _phase = _Phase.results;
      _loading = true;
      _error = null;
      _matches = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final type = _answers.type;
      final scored = await _collectMatches(client, type);
      if (!mounted) return;
      setState(() {
        _matches = scored;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر على نديم إكمال الاختيار. حاول مرة أخرى.';
      });
    }
  }

  Future<List<_Scored>> _collectMatches(
    ApiClient client,
    PropertyType? type,
  ) async {
    final typeKey = type == null
        ? null
        : switch (type) {
            PropertyType.farm => 'FARM',
            PropertyType.hall => 'HALL',
            PropertyType.decoration => 'DECORATION',
          };

    final seen = <String>{};
    var pool = <Property>[];

    Future<void> pull({String? type, String? province, String? sort}) async {
      final extra = await fetchProperties(
        client,
        type: type,
        province: province,
        sort: sort ?? 'rating',
        pageSize: 40,
      );
      for (final p in extra) {
        if (seen.add(p.id)) pool.add(p);
      }
    }

    await pull(type: typeKey, province: _answers.provinceSlug);
    if (pool.length < 8) {
      await pull(type: typeKey, sort: 'featured');
    }
    if (pool.length < 8 && _answers.provinceSlug != null) {
      await pull(province: _answers.provinceSlug);
    }
    if (pool.isEmpty) {
      await pull(sort: 'featured');
    }

    final ranked = pool
        .map(
          (p) => _Scored(
            p,
            _score(p),
            _reason(p),
            precise: _precise(p),
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final strong = ranked.where((m) => m.score >= 18).toList();
    return (strong.isNotEmpty ? strong : ranked).take(10).toList();
  }

  bool _precise(Property p) {
    final typeOk = _answers.type == null || p.type == _answers.type;
    final cityOk =
        _answers.provinceName == null || p.provinceName == _answers.provinceName;
    final capOk =
        _answers.minCapacity == null || p.capacity >= _answers.minCapacity!;
    return typeOk && cityOk && capOk;
  }

  int _score(Property p) {
    var s = 0;
    final preferred = _answers.impliedType;
    if (preferred != null) {
      s += p.type == preferred ? 40 : -12;
    }
    final province = _answers.provinceName;
    if (province != null) {
      s += p.provinceName == province ? 28 : -10;
    }
    final minCap = _answers.minCapacity;
    if (minCap != null) {
      s += p.capacity >= minCap ? 22 : -24;
    }
    final maxPrice = _answers.maxPrice;
    if (maxPrice != null && !_answers.budgetOpen) {
      s += p.pricePerDay <= maxPrice ? 18 : -20;
    }
    switch (_answers.shift) {
      case _Shift.morning:
        if (p.priceMorningShift != null) s += 12;
        if (p.supportsShifts) s += 6;
      case _Shift.evening:
        if (p.priceEveningShift != null) s += 12;
        if (p.supportsShifts) s += 6;
      case _Shift.full:
        if (!p.supportsShifts) s += 8;
      case _Shift.flex:
        s += 4;
      case null:
        break;
    }
    s += (p.ratingAvg * 3).round();
    if (p.featured) s += 6;
    return s;
  }

  String _reason(Property p) {
    final bits = <String>[p.typeLabelAr];
    final place = p.cityName ?? p.provinceName;
    if (place != null && place.isNotEmpty) bits.add(place);
    if (p.capacity > 0) bits.add('يتسع لـ ${p.capacity}');
    bits.add('${PriceText.format(p.pricePerDay)} لليوم');
    return bits.join(' · ');
  }

  void _restart() {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _Phase.intro;
      _step = 0;
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
      _matches = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final night = _phase != _Phase.results;
    return Scaffold(
      backgroundColor: night ? VibesDark.canvas : Vibes.canvas,
      body: night
          ? MaisonNightWash(child: SafeArea(child: _nightBody()))
          : MaisonWash(child: SafeArea(child: _resultsBody())),
    );
  }

  Widget _nightBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: Icon(
                  _phase == _Phase.intro
                      ? Icons.close_rounded
                      : Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              const CrestSeal(size: 22, color: Vibes.tealBright),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: VibesMotion.slow,
            switchInCurve: VibesMotion.curve,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: _phase == _Phase.intro
                ? KeyedSubtree(key: const ValueKey('intro'), child: _intro())
                : KeyedSubtree(
                    key: ValueKey('q-$_step'),
                    child: _questionPage(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _intro() {
    const program = [
      ('01', 'المناسبة'),
      ('02', 'المكان'),
      ('03', 'المدينة'),
      ('04', 'الضيوف'),
      ('05', 'الوقت'),
      ('06', 'الميزانية'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const MaisonKicker('رفيق المناسبة', light: true),
          const SizedBox(height: 12),
          Text(
            'نديم',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          const ArcFlourish(width: 42, color: Vibes.tealBright),
          const SizedBox(height: 18),
          Text(
            'سؤال واحد في كل صفحة. يقرأ نديم ذوقك ثم يعرض الأماكن الجاهزة للحجز.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: .82),
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          FolioPanel(
            color: Colors.white.withValues(alpha: .05),
            borderColor: Colors.white.withValues(alpha: .12),
            radius: Folio.chrome,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  for (var i = 0; i < program.length; i++) ...[
                    Row(
                      children: [
                        Text(
                          program[i].$1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Vibes.tealBright,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            program[i].$2,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (i < program.length - 1) const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          VibesButton(
            label: 'ابدأ الجلسة',
            icon: Icons.auto_awesome_rounded,
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() => _phase = _Phase.question);
            },
          ),
        ],
      ),
    );
  }

  Widget _questionPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepThread(current: _step, total: _total),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: MaisonKicker(_stepKicker, light: true)),
              Text(
                '${(_step + 1).toString().padLeft(2, '0')} / ${_total.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Vibes.tealBright,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _stepTitle,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stepHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .68),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(child: _stepOptions()),
        ],
      ),
    );
  }

  String get _stepKicker => switch (_step) {
    0 => 'السؤال الأول',
    1 => 'السؤال الثاني',
    2 => 'السؤال الثالث',
    3 => 'السؤال الرابع',
    4 => 'السؤال الخامس',
    _ => 'السؤال الأخير',
  };

  String get _stepTitle => switch (_step) {
    0 => 'ما المناسبة التي تخطط لها؟',
    1 => 'أي نوع مكان يليق بها؟',
    2 => 'أين تقيم المناسبة؟',
    3 => 'كم عدد الضيوف تقريباً؟',
    4 => 'كيف تفضّل التوقيت؟',
    _ => 'ما سقفك لليوم؟',
  };

  String get _stepHint => switch (_step) {
    0 => 'نديم يستخدم المناسبة ليضيّق الذوق لا ليحصر الخيارات.',
    1 => 'إن لم تحسم الأمر، اترك الاختيار لنديم.',
    2 => 'المحافظة تقرّب الأماكن الجاهزة فعلاً للحجز.',
    3 => 'السعة المعروضة هي الحد الأدنى الذي يناسبك.',
    4 => 'اليوم الكامل أو الشفت — حسب طبيعة المكان.',
    _ => 'السعر لليوم الواحد، بلا مفاجآت لاحقاً.',
  };

  Widget _stepOptions() {
    return switch (_step) {
      0 => _optionList([
        _Choice(
          'زفاف',
          'ليلة تُختار بعناية',
          Icons.favorite_border_rounded,
          selected: _answers.occasion == _Occasion.wedding,
          onTap: () => _pickAndAdvance(
            () => _answers.occasion = _Occasion.wedding,
          ),
        ),
        _Choice(
          'خطوبة',
          'احتفاء أقرب وأدفأ',
          Icons.auto_awesome_outlined,
          selected: _answers.occasion == _Occasion.engagement,
          onTap: () => _pickAndAdvance(
            () => _answers.occasion = _Occasion.engagement,
          ),
        ),
        _Choice(
          'عيد ميلاد',
          'جلسة خفيفة أو حفلة',
          Icons.cake_outlined,
          selected: _answers.occasion == _Occasion.birthday,
          onTap: () => _pickAndAdvance(
            () => _answers.occasion = _Occasion.birthday,
          ),
        ),
        _Choice(
          'جلسة أهل',
          'عزيمة أو استراحة',
          Icons.groups_outlined,
          selected: _answers.occasion == _Occasion.family,
          onTap: () => _pickAndAdvance(
            () => _answers.occasion = _Occasion.family,
          ),
        ),
        _Choice(
          'عمل أو مؤتمر',
          'لقاء رسمي أو إطلاق',
          Icons.work_outline_rounded,
          selected: _answers.occasion == _Occasion.work,
          onTap: () => _pickAndAdvance(() => _answers.occasion = _Occasion.work),
        ),
        _Choice(
          'أخرى',
          'دع نديم يقرأ بين السطور',
          Icons.more_horiz_rounded,
          selected: _answers.occasion == _Occasion.other,
          onTap: () =>
              _pickAndAdvance(() => _answers.occasion = _Occasion.other),
        ),
      ]),
      1 => _optionList([
        _Choice(
          'مزرعة',
          'هواء ومساحة وهناء',
          Icons.grass_rounded,
          selected: _answers.type == PropertyType.farm,
          onTap: () => _pickAndAdvance(() {
            _answers.type = PropertyType.farm;
            _answers.typeOpen = false;
          }),
        ),
        _Choice(
          'قاعة',
          'حضور أوضح واحتفاء أوسع',
          Icons.meeting_room_outlined,
          selected: _answers.type == PropertyType.hall,
          onTap: () => _pickAndAdvance(() {
            _answers.type = PropertyType.hall;
            _answers.typeOpen = false;
          }),
        ),
        _Choice(
          'تزيين',
          'تجهيز المكان كما يجب',
          Icons.auto_fix_high_outlined,
          selected: _answers.type == PropertyType.decoration,
          onTap: () => _pickAndAdvance(() {
            _answers.type = PropertyType.decoration;
            _answers.typeOpen = false;
          }),
        ),
        _Choice(
          'دع النديم يقرر',
          'يختار وفق مناسبتك',
          Icons.explore_outlined,
          selected: _answers.typeOpen,
          onTap: () => _pickAndAdvance(() {
            _answers.type = null;
            _answers.typeOpen = true;
          }),
        ),
      ]),
      2 => _cityOptions(),
      3 => _optionList([
        _Choice(
          'حتى 50',
          'جلسة حميمة',
          Icons.person_outline_rounded,
          selected: _answers.minCapacity == 20,
          onTap: () => _pickAndAdvance(() {
            _answers.minCapacity = 20;
            _answers.guestsLabel = 'حتى 50 ضيفاً';
          }),
        ),
        _Choice(
          'حتى 100',
          'عزيمة متوسطة',
          Icons.group_outlined,
          selected: _answers.minCapacity == 50,
          onTap: () => _pickAndAdvance(() {
            _answers.minCapacity = 50;
            _answers.guestsLabel = 'حتى 100 ضيف';
          }),
        ),
        _Choice(
          'حتى 200',
          'حضور أوضح',
          Icons.groups_outlined,
          selected: _answers.minCapacity == 100,
          onTap: () => _pickAndAdvance(() {
            _answers.minCapacity = 100;
            _answers.guestsLabel = 'حتى 200 ضيف';
          }),
        ),
        _Choice(
          'حتى 400',
          'مناسبة كبيرة',
          Icons.apartment_outlined,
          selected: _answers.minCapacity == 200,
          onTap: () => _pickAndAdvance(() {
            _answers.minCapacity = 200;
            _answers.guestsLabel = 'حتى 400 ضيف';
          }),
        ),
        _Choice(
          'أكثر من 400',
          'سعة استثنائية',
          Icons.domain_outlined,
          selected: _answers.minCapacity == 400,
          onTap: () => _pickAndAdvance(() {
            _answers.minCapacity = 400;
            _answers.guestsLabel = 'أكثر من 400 ضيف';
          }),
        ),
      ]),
      4 => _optionList([
        _Choice(
          'يوم كامل',
          'من الصباح حتى المساء',
          Icons.calendar_today_outlined,
          selected: _answers.shift == _Shift.full,
          onTap: () => _pickAndAdvance(() => _answers.shift = _Shift.full),
        ),
        _Choice(
          'شفت صباحي',
          'أخف وأهدأ',
          Icons.wb_sunny_outlined,
          selected: _answers.shift == _Shift.morning,
          onTap: () => _pickAndAdvance(() => _answers.shift = _Shift.morning),
        ),
        _Choice(
          'شفت مسائي',
          'حضور أوضح ليلاً',
          Icons.nights_stay_outlined,
          selected: _answers.shift == _Shift.evening,
          onTap: () => _pickAndAdvance(() => _answers.shift = _Shift.evening),
        ),
        _Choice(
          'مرن',
          'حسب ما يناسب المكان',
          Icons.all_inclusive_rounded,
          selected: _answers.shift == _Shift.flex,
          onTap: () => _pickAndAdvance(() => _answers.shift = _Shift.flex),
        ),
      ]),
      _ => _optionList([
        _Choice(
          'حتى 250 ألف',
          'اختيار عملي',
          Icons.payments_outlined,
          selected: _answers.maxPrice == 250000,
          onTap: () => _pickAndAdvance(() {
            _answers.maxPrice = 250000;
            _answers.budgetOpen = false;
          }),
        ),
        _Choice(
          'حتى 500 ألف',
          'وسط أنيق',
          Icons.account_balance_wallet_outlined,
          selected: _answers.maxPrice == 500000,
          onTap: () => _pickAndAdvance(() {
            _answers.maxPrice = 500000;
            _answers.budgetOpen = false;
          }),
        ),
        _Choice(
          'حتى مليون',
          'سقف أوسع',
          Icons.workspace_premium_outlined,
          selected: _answers.maxPrice == 1000000,
          onTap: () => _pickAndAdvance(() {
            _answers.maxPrice = 1000000;
            _answers.budgetOpen = false;
          }),
        ),
        _Choice(
          'مفتوح',
          'الجودة أولاً',
          Icons.all_inclusive_rounded,
          selected: _answers.budgetOpen,
          onTap: () => _pickAndAdvance(() {
            _answers.maxPrice = null;
            _answers.budgetOpen = true;
          }),
        ),
      ]),
    };
  }

  Widget _cityOptions() {
    final locations = ref.watch(locationsProvider);
    return locations.when(
      loading: () => const Center(child: ThreadProgress(width: 120)),
      error: (_, __) => _optionList(_fallbackCities()),
      data: (cities) {
        final unique = <String, ({String name, String slug})>{};
        for (final city in cities) {
          final slug = city.provinceSlug;
          if (slug != null &&
              slug.isNotEmpty &&
              city.provinceName.isNotEmpty) {
            unique[slug] = (name: city.provinceName, slug: slug);
          }
        }
        const featured = [
          'baghdad',
          'basra',
          'erbil',
          'najaf',
          'karbala',
          'nineveh',
        ];
        final provinces = unique.values.toList()
          ..sort((a, b) {
            final ai = featured.indexOf(a.slug);
            final bi = featured.indexOf(b.slug);
            if (ai >= 0 || bi >= 0) {
              if (ai < 0) return 1;
              if (bi < 0) return -1;
              return ai.compareTo(bi);
            }
            return a.name.compareTo(b.name);
          });
        final choices = [
          ...provinces.map(
            (p) => _Choice(
              p.name,
              'أماكن هذه المحافظة',
              Icons.location_on_outlined,
              selected: _answers.provinceSlug == p.slug,
              onTap: () => _pickAndAdvance(() {
                _answers.provinceSlug = p.slug;
                _answers.provinceName = p.name;
              }),
            ),
          ),
          _Choice(
            'مرن — كل العراق',
            'دع نديم يوسّع النظر',
            Icons.public_outlined,
            selected: false,
            onTap: () => _pickAndAdvance(() {
              _answers.provinceSlug = null;
              _answers.provinceName = null;
            }),
          ),
        ];
        return _optionList(choices);
      },
    );
  }

  List<_Choice> _fallbackCities() {
    const fallback = [
      ('بغداد', 'baghdad'),
      ('البصرة', 'basra'),
      ('أربيل', 'erbil'),
      ('النجف', 'najaf'),
      ('كربلاء', 'karbala'),
      ('نينوى', 'nineveh'),
    ];
    return [
      ...fallback.map(
        (p) => _Choice(
          p.$1,
          'أماكن هذه المحافظة',
          Icons.location_on_outlined,
          selected: _answers.provinceSlug == p.$2,
          onTap: () => _pickAndAdvance(() {
            _answers.provinceSlug = p.$2;
            _answers.provinceName = p.$1;
          }),
        ),
      ),
      _Choice(
        'مرن — كل العراق',
        'دع نديم يوسّع النظر',
        Icons.public_outlined,
        selected: false,
        onTap: () => _pickAndAdvance(() {
          _answers.provinceSlug = null;
          _answers.provinceName = null;
        }),
      ),
    ];
  }

  Widget _optionList(List<_Choice> choices) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: choices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final choice = choices[i];
        return _Choice(
          choice.title,
          choice.subtitle,
          choice.icon,
          selected: choice.selected,
          onTap: choice.onTap,
          index: i,
        );
      },
    );
  }

  Widget _resultsBody() {
    final stamps = _answers.summary.split(' · ').where((s) => s.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaisonPageHeader(
          title: 'اختيار نديم',
          kicker: 'يليق بك',
          onBack: _back,
          trailing: TextButton(
            onPressed: _restart,
            child: const Text('جلسة جديدة'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FolioPanel(
            color: VibesDark.canvas,
            borderColor: Vibes.teal.withValues(alpha: .45),
            railColor: Vibes.teal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MaisonKicker('قراءتك', light: true),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final stamp in stamps) _ResultStamp(stamp),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _resultsList()),
      ],
    );
  }

  Widget _resultsList() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThreadProgress(width: 140),
            SizedBox(height: 16),
            Text('نديم يرتّب ما يناسبك…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            VibesButton(label: 'أعِد المحاولة', onPressed: _finish),
          ],
        ),
      );
    }
    final matches = _matches ?? const <_Scored>[];
    final preciseCount = matches.where((m) => m.precise).length;
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CrestSeal(size: 36, color: Vibes.teal),
            const SizedBox(height: 16),
            Text(
              'لم يجد نديم مكاناً يطابق هذه القراءة تماماً.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            VibesButton(label: 'عدّل الإجابات', onPressed: _back),
          ],
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: matches.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        if (i == 0) {
          final title = preciseCount == 0
              ? 'أقرب ما وجد نديم لهذه القراءة'
              : matches.length == 1
              ? 'مكان واحد يليق بهذه القراءة'
              : '$preciseCount من ${matches.length} أماكن تليق بك';
          return Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: VibesTheme.textSecondaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          );
        }
        final match = matches[i - 1];
        return _MatchTile(rank: i, match: match);
      },
    );
  }
}

class _Scored {
  const _Scored(this.property, this.score, this.reason, {this.precise = true});
  final Property property;
  final int score;
  final String reason;
  final bool precise;
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.rank, required this.match});

  final int rank;
  final _Scored match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              rank.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Vibes.teal,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            const ArcFlourish(width: 22, color: Vibes.tealBright),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                match.precise
                    ? 'اختيار دقيق · ${match.reason}'
                    : 'اقتراح قريب · ${match.reason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: match.precise
                      ? Vibes.coral
                      : VibesTheme.textTertiaryOf(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PropertyCard(
          property: match.property,
          heroEnabled: false,
          heroNamespace: 'nadeem',
        ),
      ],
    );
  }
}

class _StepThread extends StatelessWidget {
  const _StepThread({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: VibesMotion.fast,
              height: 2,
              color: i <= current
                  ? Vibes.teal
                  : Colors.white.withValues(alpha: .18),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _ResultStamp extends StatelessWidget {
  const _ResultStamp(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: Folio.chrome,
          side: BorderSide(color: Colors.white.withValues(alpha: .14)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: .9),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
    this.title,
    this.subtitle,
    this.icon, {
    required this.selected,
    required this.onTap,
    this.index = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VibesMotion.fast,
        curve: VibesMotion.curve,
        decoration: ShapeDecoration(
          color: selected
              ? const Color(0xFF1E3A56)
              : Colors.white.withValues(alpha: .05),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.radius,
            side: BorderSide(
              color: selected
                  ? Vibes.teal.withValues(alpha: .75)
                  : Colors.white.withValues(alpha: .12),
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 3,
                child: ColoredBox(
                  color: selected ? Vibes.teal : Colors.transparent,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
                  child: Row(
                    children: [
                      Text(
                        (index + 1).toString().padLeft(2, '0'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? Vibes.tealBright
                              : Colors.white.withValues(alpha: .38),
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        icon,
                        color: selected ? Vibes.tealBright : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: .62),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_rounded,
                          color: Vibes.tealBright,
                          size: 18,
                        ),
                    ],
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
