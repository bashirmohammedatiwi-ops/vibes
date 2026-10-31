import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
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

/// نص معروض من لوحة التحكم: إن طابق نصاً افتراضياً معروفاً يُترجم، وإلا يبقى
/// كما كتبه المشرف. مرّر الافتراضي مترجماً.
String _t(Object? v, String d) => v is String ? v.tr : d;
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
      label: _t(j['label'], 'مناسبة'.tr),
      sub: _t(j['sub'], ''),
      icon: iconFor(_s(j['icon'], 'sparkle')),
      world: _world(_type(j['world'])),
      impliedType: _type(j['impliedType']),
      suggestDecor: _b(j['suggestDecor'], false),
      reaction: _t(j['reaction'], ''),
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
      _t(j['title'], d.title),
      _t(j['sub'], d.sub),
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
    final n = _t(_r['name'], 'نديم'.tr).trim();
    return n.isEmpty ? 'نديم'.tr : n;
  }

  String get subtitle => _t(_r['subtitle'], 'مخطّط مناسبتك الشخصي'.tr);
  String get typingLabel => _t(_r['typingLabel'], 'يكتب…'.tr);
  String get disabledTitle =>
      _t(_r['disabledTitle'], 'نديم في استراحة قصيرة'.tr);
  String get disabledMessage => _t(
    _r['disabledMessage'],
    'نعمل على تحسين نديم — يمكنك البحث عن الأماكن مباشرة حتى يعود.'.tr,
  );
  List<String> get greeting {
    final g = _r['greeting'];
    if (g is List) {
      final list = g.whereType<String>().where((s) => s.trim().isNotEmpty);
      if (list.isNotEmpty) return [for (final s in list) s.tr];
    }
    return [
      'أهلاً بك، أنا نديم ✨'.tr,
      'سأساعدك تختار المكان المثالي لمناسبتك — بخطوات خفيفة.'.tr,
    ];
  }

  /// معامل سرعة الكتابة — 1 = السرعة الأصلية (650ms).
  double get typingScale => _i(_r['typingDelayMs'], 650).clamp(0, 3000) / 650;

  // ── المناسبة ──
  String get occasionQuestion =>
      _t(_sec('occasionStep')['question'], 'ما المناسبة التي تخطّط لها؟'.tr);

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

  static List<NadeemOccasion> get _defaultOccasions => [
    for (final o in const [
      (
        'wedding',
        'زفاف', // i18n-ok
        'ليلة العمر', // i18n-ok
        'diamond',
        'HALL',
        'HALL',
        true,
        'ألف مبروك! ليلة العمر تستحق الأفضل 💍', // i18n-ok
      ),
      (
        'engagement',
        'خطوبة', // i18n-ok
        'بداية الحكاية', // i18n-ok
        'heart',
        'DECORATION',
        'HALL',
        true,
        'مبارك مقدّماً! بداية جميلة تستحق مكاناً دافئاً.', // i18n-ok
      ),
      (
        'birthday',
        'عيد ميلاد', // i18n-ok
        'فرحة وزينة', // i18n-ok
        'cake',
        'DECORATION',
        'FARM',
        true,
        'رائع! سنجعلها حفلة لا تُنسى 🎂', // i18n-ok
      ),
      (
        'family',
        'جلسة أهل', // i18n-ok
        'يوم دافئ', // i18n-ok
        'family',
        'FARM',
        'FARM',
        false,
        'جميل — الأهل يستحقون يوماً هادئاً ومريحاً.', // i18n-ok
      ),
      (
        'work',
        'عمل', // i18n-ok
        'لقاء رسمي', // i18n-ok
        'work',
        'HALL',
        'HALL',
        false,
        'ممتاز، سأبحث عن مكان أنيق ومنظّم.', // i18n-ok
      ),
      (
        'other',
        'أخرى', // i18n-ok
        'فاجئني', // i18n-ok
        'sparkle',
        'FARM',
        null,
        false,
        'حسناً، أخبرني بالمزيد وسأقرأ بين السطور.', // i18n-ok
      ),
    ])
      NadeemOccasion(
        key: o.$1,
        label: o.$2.tr,
        sub: o.$3.tr,
        icon: NadeemOccasion.iconFor(o.$4),
        world: _world(_type(o.$5)),
        impliedType: _type(o.$6),
        suggestDecor: o.$7,
        reaction: o.$8.tr,
      ),
  ];

  // ── النوع ──
  _J get _typeStep => _sec('typeStep');
  bool get typeEnabled => _b(_typeStep['enabled'], true);
  String get typeQuestion => _t(_typeStep['question'], 'أي مكان يليق بها؟'.tr);
  String get typeReaction => _t(_typeStep['reaction'], 'اختيار موفّق.'.tr);
  String get typeReactionAuto => _t(
    _typeStep['reactionAuto'],
    'اترك الأمر لي — سأختار ما يناسب مناسبتك.'.tr,
  );
  bool get typeAllowAuto => _b(_typeStep['allowAuto'], true);
  String get typeAutoLabel =>
      _t(_typeStep['autoLabel'], 'لست متأكداً — اختر لي يا نديم'.tr);
  String get typeAutoAnswer =>
      _t(_typeStep['autoAnswer'], 'اختر لي يا نديم'.tr);
  bool get typeShowCounts => _b(_typeStep['showCounts'], true);

  /// الأنواع المفعّلة مع أسمائها.
  List<(PropertyType, HomeSection, String)> get types {
    final defaults = [
      (PropertyType.farm, HomeSection.farm, HomeSection.farm.label.tr),
      (PropertyType.hall, HomeSection.hall, HomeSection.hall.label.tr),
      (
        PropertyType.decoration,
        HomeSection.decoration,
        HomeSection.decoration.label.tr,
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
      final label = _t(j['label'], d.$3).trim();
      out.add((d.$1, d.$2, label.isEmpty ? d.$3 : label));
    }
    return out.isEmpty ? defaults : out;
  }

  // ── المحافظة ──
  _J get _prov => _sec('provinceStep');
  bool get provinceEnabled => _b(_prov['enabled'], true);
  String get provinceQuestion => _t(_prov['question'], 'في أي محافظة؟'.tr);
  String get provinceReactionAll =>
      _t(_prov['reactionAll'], 'سأبحث في كل العراق.'.tr);
  String get provinceReactionOne =>
      _t(_prov['reactionOne'], 'تمام، سأركّز على {province}.'.tr);
  String get provinceAnyLabel => _t(_prov['anyLabel'], 'أي مكان في العراق'.tr);
  bool get provinceShowCounts => _b(_prov['showCounts'], true);
  bool get provinceHideEmpty => _b(_prov['hideEmpty'], false);

  // ── الضيوف ──
  _J get _guests => _sec('guestsStep');
  bool get guestsEnabled => _b(_guests['enabled'], true);
  String get guestsQuestion =>
      _t(_guests['question'], 'كم ضيفاً تتوقع تقريباً؟'.tr);
  String get guestsReaction =>
      _t(_guests['reaction'], 'وصلت — سأستبعد ما لا يتسع لضيوفك.'.tr);
  int get guestsMin => _i(_guests['min'], 10).clamp(1, 5000);
  int get guestsMax => _i(_guests['max'], 1000).clamp(guestsMin + 10, 20000);
  int get guestsInitial =>
      _i(_guests['initial'], 70).clamp(guestsMin, guestsMax);
  String get guestsAnswer => _t(_guests['answer'], 'حوالي {n} ضيف'.tr);
  String get guestsConfirm => _t(_guests['confirmLabel'], 'تمام — {n} ضيف'.tr);
  List<(int, String)> get guestScales {
    final raw = _guests['scales'];
    if (raw is List) {
      final list =
          raw
              .whereType<Map<String, dynamic>>()
              .map((s) => (_i(s['upTo'], 100), _t(s['label'], '')))
              .where((s) => s.$2.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => a.$1.compareTo(b.$1));
      if (list.isNotEmpty) return list;
    }
    return [
      (30, 'جلسة حميمة'.tr),
      (80, 'عزيمة عائلية'.tr),
      (200, 'حفل متوسط'.tr),
      (450, 'مناسبة كبيرة'.tr),
      (100000, 'حدث ضخم'.tr),
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
  String get shiftQuestion =>
      _t(_shift['question'], 'متى تفضّل وقت المناسبة؟'.tr);
  String get shiftReaction => _t(_shift['reaction'], 'حلو، سأراعي التوقيت.'.tr);
  NadeemSlot get morning => NadeemSlot.fromJson(
    _shift['morning'],
    NadeemSlot(true, 'صباحاً'.tr, 'شمس وهواء'.tr),
  );
  NadeemSlot get evening => NadeemSlot.fromJson(
    _shift['evening'],
    NadeemSlot(true, 'مساءً'.tr, 'أضواء وسهر'.tr),
  );
  NadeemSlot get fullDay => NadeemSlot.fromJson(
    _shift['full'],
    NadeemSlot(true, 'يوم كامل'.tr, 'من الصبح لليل'.tr),
  );
  bool get flexEnabled => _b(_obj(_shift['flex'])['enabled'], true);
  String get flexLabel =>
      _t(_obj(_shift['flex'])['label'], 'التوقيت مرن عندي'.tr);
  String get flexAnswer => _t(_obj(_shift['flex'])['answer'], 'التوقيت مرن'.tr);

  // ── الميزانية ──
  _J get _budget => _sec('budgetStep');
  bool get budgetEnabled => _b(_budget['enabled'], true);
  String get budgetQuestion =>
      _t(_budget['question'], 'وأخيراً — كم تحب أن تكون ميزانيتك لليوم؟'.tr);
  String get budgetOpenLabel => _t(_budget['openLabel'], 'مفتوحة'.tr);
  String get budgetOpenAnswer =>
      _t(_budget['openAnswer'], 'الميزانية مفتوحة'.tr);
  String get budgetSubmit => _t(_budget['submitLabel'], 'اعرض النتائج'.tr);
  String get budgetAnswer => _t(_budget['answer'], 'حتى {amount} د.ع'.tr);
  double get budgetInitial =>
      (_i(_budget['initialPercent'], 55).clamp(0, 100)) / 100;

  // ── الإنهاء والنتائج ──
  _J get _finish => _sec('finish');
  String get finishIntro =>
      _t(_finish['intro'], 'ممتاز! دعني أقرأ الأماكن لأجلك…'.tr);
  String get finishThinking =>
      _t(_finish['thinking'], 'أطابق مناسبتك مع الأماكن المتاحة…'.tr);
  String get finishError => _t(
    _finish['error'],
    'تعذّر عليّ إكمال البحث الآن — تحقّق من الاتصال وحاول مجدداً.'.tr,
  );
  String get retryLabel => _t(_finish['retryLabel'], 'حاول مجدداً'.tr);

  _J get _res => _sec('results');
  String get resultsTitle => _t(_res['title'], 'خطة {occasion}'.tr);
  String get editHint => _t(_res['editHint'], 'المس أي بند لتعديله'.tr);
  String get resultsPrecise => _t(
    _res['precise'],
    'هذه أفضل الأماكن لمناسبتك، مرتّبة حسب التطابق 👇'.tr,
  );
  String get resultsApprox => _t(
    _res['approximate'],
    'لم أجد تطابقاً كاملاً، لكن هذه الأقرب لما طلبت 👇'.tr,
  );
  String get resultsEmpty => _t(
    _res['empty'],
    'لم أجد مطابقة دقيقة الآن — جرّب توسيع الميزانية أو تغيير المحافظة.'.tr,
  );
  String get decorIntro =>
      _t(_res['decorIntro'], 'ولتكتمل الصورة — فرق تزيين تليق بمناسبتك 🌸'.tr);
  String get restartLabel => _t(_res['restartLabel'], 'من جديد'.tr);
  String get allResultsLabel => _t(_res['allResultsLabel'], 'كل النتائج'.tr);
  String get autoTypeChip => _t(_res['autoTypeChip'], 'نديم يختار'.tr);
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
