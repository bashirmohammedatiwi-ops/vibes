import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../home/home_sections.dart';

/// ═══════════════════════════════════════════════════════════
/// إعدادات نديم — تأتي من لوحة التحكم (`/api/nadeem/config`).
/// كل حقل له قيمة افتراضية مطابقة لما كان مكتوباً في التطبيق، فإن
/// تعذّر الاتصال يعمل نديم كما كان تماماً.
/// ═══════════════════════════════════════════════════════════

final nadeemConfigProvider = FutureProvider<NadeemConfig>((ref) async {
  ref.keepAlive();
  try {
    final data = await ref
        .watch(apiClientProvider)
        .get('/api/nadeem/config')
        .timeout(const Duration(seconds: 6));
    return NadeemConfig.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  } catch (_) {
    return NadeemConfig.fromJson(const {});
  }
});

/// الإعدادات الحالية فوراً (الافتراضية حتى يصل الرد).
NadeemConfig nadeemConfigNow(WidgetRef ref) =>
    ref.watch(nadeemConfigProvider).valueOrNull ?? NadeemConfig.defaults;

typedef _J = Map<String, dynamic>;

_J _obj(Object? v) => v is Map<String, dynamic> ? v : const {};
String _s(Object? v, String d) => v is String ? v : d;
bool _b(Object? v, bool d) => v is bool ? v : d;
int _i(Object? v, int d) => v is num ? v.round() : d;

PropertyType? _type(Object? v) => switch (v) {
  'FARM' => PropertyType.farm,
  'HALL' => PropertyType.hall,
  'DECORATION' => PropertyType.decoration,
  _ => null,
};

HomeSection _world(PropertyType? t) => switch (t) {
  PropertyType.hall => HomeSection.hall,
  PropertyType.decoration => HomeSection.decoration,
  _ => HomeSection.farm,
};

/// يملأ `{key}` في النص.
String fillTokens(String text, Map<String, String> values) {
  var out = text;
  values.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

class NadeemOccasion {
  const NadeemOccasion({
    required this.key,
    required this.label,
    required this.sub,
    required this.icon,
    required this.world,
    required this.impliedType,
    required this.suggestDecor,
    required this.reaction,
  });

  final String key;
  final String label;
  final String sub;
  final IconData icon;
  final HomeSection world;
  final PropertyType? impliedType;
  final bool suggestDecor;
  final String reaction;

  static IconData iconFor(String name) => switch (name) {
    'diamond' => Icons.diamond_outlined,
    'heart' => Icons.volunteer_activism_outlined,
    'cake' => Icons.cake_outlined,
    'family' => Icons.family_restroom_rounded,
    'work' => Icons.work_outline_rounded,
    'party' => Icons.celebration_outlined,
    'graduation' => Icons.school_outlined,
    'baby' => Icons.child_friendly_outlined,
    'music' => Icons.music_note_rounded,
    'star' => Icons.star_outline_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'moon' => Icons.nightlight_outlined,
    'sun' => Icons.wb_sunny_outlined,
    'pool' => Icons.pool_rounded,
    'food' => Icons.restaurant_rounded,
    _ => Icons.auto_awesome_outlined,
  };

  static NadeemOccasion? fromJson(_J j) {
    if (j['enabled'] == false) return null;
    final key = _s(j['key'], '');
    if (key.isEmpty) return null;
    return NadeemOccasion(
      key: key,
      label: _s(j['label'], 'مناسبة'),
      sub: _s(j['sub'], ''),
      icon: iconFor(_s(j['icon'], 'sparkle')),
      world: _world(_type(j['world'])),
      impliedType: _type(j['impliedType']),
      suggestDecor: _b(j['suggestDecor'], false),
      reaction: _s(j['reaction'], ''),
    );
  }
}

class NadeemSlot {
  const NadeemSlot(this.enabled, this.title, this.sub);
  final bool enabled;
  final String title;
  final String sub;

  static NadeemSlot fromJson(Object? v, NadeemSlot d) {
    final j = _obj(v);
    return NadeemSlot(
      _b(j['enabled'], d.enabled),
      _s(j['title'], d.title),
      _s(j['sub'], d.sub),
    );
  }
}

class NadeemConfig {
  NadeemConfig._(this._r);

  final _J _r;

  static final defaults = NadeemConfig.fromJson(const {});

  factory NadeemConfig.fromJson(_J json) => NadeemConfig._(json);

  _J _sec(String k) => _obj(_r[k]);

  // ── عام ──
  bool get enabled => _b(_r['enabled'], true);
  bool get showInNav => _b(_r['showInNav'], true);
  bool get showOnHome => _b(_r['showOnHome'], true);
  String get name {
    final n = _s(_r['name'], 'نديم').trim();
    return n.isEmpty ? 'نديم' : n;
  }

  String get subtitle => _s(_r['subtitle'], 'مخطّط مناسبتك الشخصي');
  String get typingLabel => _s(_r['typingLabel'], 'يكتب…');
  String get disabledTitle => _s(_r['disabledTitle'], 'نديم في استراحة قصيرة');
  String get disabledMessage => _s(
    _r['disabledMessage'],
    'نعمل على تحسين نديم — يمكنك البحث عن الأماكن مباشرة حتى يعود.',
  );
  List<String> get greeting {
    final g = _r['greeting'];
    if (g is List) {
      final list = g.whereType<String>().where((s) => s.trim().isNotEmpty);
      if (list.isNotEmpty) return list.toList();
    }
    return const [
      'أهلاً بك، أنا نديم ✨',
      'سأساعدك تختار المكان المثالي لمناسبتك — بخطوات خفيفة.',
    ];
  }

  /// معامل سرعة الكتابة — 1 = السرعة الأصلية (650ms).
  double get typingScale => _i(_r['typingDelayMs'], 650).clamp(0, 3000) / 650;

  // ── المناسبة ──
  String get occasionQuestion =>
      _s(_sec('occasionStep')['question'], 'ما المناسبة التي تخطّط لها؟');

  List<NadeemOccasion> get occasions {
    final raw = _r['occasions'];
    if (raw is List) {
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(NadeemOccasion.fromJson)
          .whereType<NadeemOccasion>()
          .toList();
      if (list.isNotEmpty) return list;
    }
    return _defaultOccasions;
  }

  static final _defaultOccasions = [
    for (final o in const [
      (
        'wedding',
        'زفاف',
        'ليلة العمر',
        'diamond',
        'HALL',
        'HALL',
        true,
        'ألف مبروك! ليلة العمر تستحق الأفضل 💍',
      ),
      (
        'engagement',
        'خطوبة',
        'بداية الحكاية',
        'heart',
        'DECORATION',
        'HALL',
        true,
        'مبارك مقدّماً! بداية جميلة تستحق مكاناً دافئاً.',
      ),
      (
        'birthday',
        'عيد ميلاد',
        'فرحة وزينة',
        'cake',
        'DECORATION',
        'FARM',
        true,
        'رائع! سنجعلها حفلة لا تُنسى 🎂',
      ),
      (
        'family',
        'جلسة أهل',
        'يوم دافئ',
        'family',
        'FARM',
        'FARM',
        false,
        'جميل — الأهل يستحقون يوماً هادئاً ومريحاً.',
      ),
      (
        'work',
        'عمل',
        'لقاء رسمي',
        'work',
        'HALL',
        'HALL',
        false,
        'ممتاز، سأبحث عن مكان أنيق ومنظّم.',
      ),
      (
        'other',
        'أخرى',
        'فاجئني',
        'sparkle',
        'FARM',
        null,
        false,
        'حسناً، أخبرني بالمزيد وسأقرأ بين السطور.',
      ),
    ])
      NadeemOccasion(
        key: o.$1,
        label: o.$2,
        sub: o.$3,
        icon: NadeemOccasion.iconFor(o.$4),
        world: _world(_type(o.$5)),
        impliedType: _type(o.$6),
        suggestDecor: o.$7,
        reaction: o.$8,
      ),
  ];

  // ── النوع ──
  _J get _typeStep => _sec('typeStep');
  bool get typeEnabled => _b(_typeStep['enabled'], true);
  String get typeQuestion => _s(_typeStep['question'], 'أي مكان يليق بها؟');
  String get typeReaction => _s(_typeStep['reaction'], 'اختيار موفّق.');
  String get typeReactionAuto =>
      _s(_typeStep['reactionAuto'], 'اترك الأمر لي — سأختار ما يناسب مناسبتك.');
  bool get typeAllowAuto => _b(_typeStep['allowAuto'], true);
  String get typeAutoLabel =>
      _s(_typeStep['autoLabel'], 'لست متأكداً — اختر لي يا نديم');
  String get typeAutoAnswer => _s(_typeStep['autoAnswer'], 'اختر لي يا نديم');
  bool get typeShowCounts => _b(_typeStep['showCounts'], true);

  /// الأنواع المفعّلة مع أسمائها.
  List<(PropertyType, HomeSection, String)> get types {
    final defaults = [
      (PropertyType.farm, HomeSection.farm, HomeSection.farm.label),
      (PropertyType.hall, HomeSection.hall, HomeSection.hall.label),
      (
        PropertyType.decoration,
        HomeSection.decoration,
        HomeSection.decoration.label,
      ),
    ];
    final raw = _typeStep['types'];
    if (raw is! List) return defaults;
    final out = <(PropertyType, HomeSection, String)>[];
    for (final d in defaults) {
      final key = switch (d.$1) {
        PropertyType.farm => 'FARM',
        PropertyType.hall => 'HALL',
        PropertyType.decoration => 'DECORATION',
      };
      final j = raw.whereType<Map<String, dynamic>>().firstWhere(
        (t) => t['key'] == key,
        orElse: () => const {},
      );
      if (j['enabled'] == false) continue;
      final label = _s(j['label'], d.$3).trim();
      out.add((d.$1, d.$2, label.isEmpty ? d.$3 : label));
    }
    return out.isEmpty ? defaults : out;
  }

  // ── المحافظة ──
  _J get _prov => _sec('provinceStep');
  bool get provinceEnabled => _b(_prov['enabled'], true);
  String get provinceQuestion => _s(_prov['question'], 'في أي محافظة؟');
  String get provinceReactionAll =>
      _s(_prov['reactionAll'], 'سأبحث في كل العراق.');
  String get provinceReactionOne =>
      _s(_prov['reactionOne'], 'تمام، سأركّز على {province}.');
  String get provinceAnyLabel => _s(_prov['anyLabel'], 'أي مكان في العراق');
  bool get provinceShowCounts => _b(_prov['showCounts'], true);
  bool get provinceHideEmpty => _b(_prov['hideEmpty'], false);

  // ── الضيوف ──
  _J get _guests => _sec('guestsStep');
  bool get guestsEnabled => _b(_guests['enabled'], true);
  String get guestsQuestion =>
      _s(_guests['question'], 'كم ضيفاً تتوقع تقريباً؟');
  String get guestsReaction =>
      _s(_guests['reaction'], 'وصلت — سأستبعد ما لا يتسع لضيوفك.');
  int get guestsMin => _i(_guests['min'], 10).clamp(1, 5000);
  int get guestsMax => _i(_guests['max'], 1000).clamp(guestsMin + 10, 20000);
  int get guestsInitial =>
      _i(_guests['initial'], 70).clamp(guestsMin, guestsMax);
  String get guestsAnswer => _s(_guests['answer'], 'حوالي {n} ضيف');
  String get guestsConfirm => _s(_guests['confirmLabel'], 'تمام — {n} ضيف');
  List<(int, String)> get guestScales {
    final raw = _guests['scales'];
    if (raw is List) {
      final list =
          raw
              .whereType<Map<String, dynamic>>()
              .map((s) => (_i(s['upTo'], 100), _s(s['label'], '')))
              .where((s) => s.$2.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => a.$1.compareTo(b.$1));
      if (list.isNotEmpty) return list;
    }
    return const [
      (30, 'جلسة حميمة'),
      (80, 'عزيمة عائلية'),
      (200, 'حفل متوسط'),
      (450, 'مناسبة كبيرة'),
      (100000, 'حدث ضخم'),
    ];
  }

  String guestScale(int n) {
    final scales = guestScales;
    for (final s in scales) {
      if (n <= s.$1) return s.$2;
    }
    return scales.last.$2;
  }

  // ── التوقيت ──
  _J get _shift => _sec('shiftStep');
  bool get shiftEnabled => _b(_shift['enabled'], true);
  String get shiftQuestion => _s(_shift['question'], 'متى تفضّل وقت المناسبة؟');
  String get shiftReaction => _s(_shift['reaction'], 'حلو، سأراعي التوقيت.');
  NadeemSlot get morning => NadeemSlot.fromJson(
    _shift['morning'],
    const NadeemSlot(true, 'صباحاً', 'شمس وهواء'),
  );
  NadeemSlot get evening => NadeemSlot.fromJson(
    _shift['evening'],
    const NadeemSlot(true, 'مساءً', 'أضواء وسهر'),
  );
  NadeemSlot get fullDay => NadeemSlot.fromJson(
    _shift['full'],
    const NadeemSlot(true, 'يوم كامل', 'من الصبح لليل'),
  );
  bool get flexEnabled => _b(_obj(_shift['flex'])['enabled'], true);
  String get flexLabel => _s(_obj(_shift['flex'])['label'], 'التوقيت مرن عندي');
  String get flexAnswer => _s(_obj(_shift['flex'])['answer'], 'التوقيت مرن');

  // ── الميزانية ──
  _J get _budget => _sec('budgetStep');
  bool get budgetEnabled => _b(_budget['enabled'], true);
  String get budgetQuestion =>
      _s(_budget['question'], 'وأخيراً — كم تحب أن تكون ميزانيتك لليوم؟');
  String get budgetOpenLabel => _s(_budget['openLabel'], 'مفتوحة');
  String get budgetOpenAnswer => _s(_budget['openAnswer'], 'الميزانية مفتوحة');
  String get budgetSubmit => _s(_budget['submitLabel'], 'اعرض النتائج');
  String get budgetAnswer => _s(_budget['answer'], 'حتى {amount} د.ع');
  double get budgetInitial =>
      (_i(_budget['initialPercent'], 55).clamp(0, 100)) / 100;

  // ── الإنهاء والنتائج ──
  _J get _finish => _sec('finish');
  String get finishIntro =>
      _s(_finish['intro'], 'ممتاز! دعني أقرأ الأماكن لأجلك…');
  String get finishThinking =>
      _s(_finish['thinking'], 'أطابق مناسبتك مع الأماكن المتاحة…');
  String get finishError => _s(
    _finish['error'],
    'تعذّر عليّ إكمال البحث الآن — تحقّق من الاتصال وحاول مجدداً.',
  );
  String get retryLabel => _s(_finish['retryLabel'], 'حاول مجدداً');

  _J get _res => _sec('results');
  String get resultsTitle => _s(_res['title'], 'خطة {occasion}');
  String get editHint => _s(_res['editHint'], 'المس أي بند لتعديله');
  String get resultsPrecise =>
      _s(_res['precise'], 'هذه أفضل الأماكن لمناسبتك، مرتّبة حسب التطابق 👇');
  String get resultsApprox => _s(
    _res['approximate'],
    'لم أجد تطابقاً كاملاً، لكن هذه الأقرب لما طلبت 👇',
  );
  String get resultsEmpty => _s(
    _res['empty'],
    'لم أجد مطابقة دقيقة الآن — جرّب توسيع الميزانية أو تغيير المحافظة.',
  );
  String get decorIntro =>
      _s(_res['decorIntro'], 'ولتكتمل الصورة — فرق تزيين تليق بمناسبتك 🌸');
  String get restartLabel => _s(_res['restartLabel'], 'من جديد');
  String get allResultsLabel => _s(_res['allResultsLabel'], 'كل النتائج');
  String get autoTypeChip => _s(_res['autoTypeChip'], 'نديم يختار');
  bool get showMatchPercent => _b(_res['showMatchPercent'], true);
  bool get showReasons => _b(_res['showReasons'], true);

  // ── المطابقة ──
  _J get _m => _sec('matching');
  int w(String key, int d) => _i(_m[key], d);
  int get maxResults => w('maxResults', 10).clamp(1, 30);
  int get minScore => w('minScore', 18);
  int get decorCount => w('decorCount', 6).clamp(0, 20);
  int get minPercent => w('minPercent', 55).clamp(0, 99);
  int get maxPercent => w('maxPercent', 99).clamp(minPercent + 1, 100);

  Map<String, int> get pinned {
    final raw = _r['pinned'];
    if (raw is! List) return const {};
    return {
      for (final p in raw.whereType<Map<String, dynamic>>())
        if (p['propertyId'] is String)
          p['propertyId'] as String: _i(p['bonus'], 30),
    };
  }

  Set<String> get excluded {
    final raw = _r['excluded'];
    return raw is List ? raw.whereType<String>().toSet() : const {};
  }
}
