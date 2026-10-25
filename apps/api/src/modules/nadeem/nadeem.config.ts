/**
 * إعدادات «نديم» — مخطّط المناسبات في تطبيق الزبون.
 * كل ما يظهر في المحادثة (النصوص، المناسبات، الخطوات، أوزان المطابقة،
 * الأماكن المثبّتة والمستبعدة) يُدار من لوحة التحكم ويُخزَّن JSON واحداً.
 * القيم الافتراضية هنا مطابقة لما كان مكتوباً داخل التطبيق.
 */

export type NadeemWorld = 'FARM' | 'HALL' | 'DECORATION';

export const NADEEM_ICONS = [
  'diamond',
  'heart',
  'cake',
  'family',
  'work',
  'sparkle',
  'party',
  'graduation',
  'baby',
  'music',
  'star',
  'gift',
  'moon',
  'sun',
  'pool',
  'food',
] as const;

export type NadeemIcon = (typeof NADEEM_ICONS)[number];

export type NadeemOccasion = {
  key: string;
  enabled: boolean;
  label: string;
  sub: string;
  icon: NadeemIcon;
  /** لون البطاقة + النوع المقترح حين يختار الزبون «اختر لي يا نديم». */
  world: NadeemWorld;
  /** النوع الذي يُفترض عند «اختر لي» — null = بلا افتراض. */
  impliedType: NadeemWorld | null;
  /** يقترح فرق تزيين مع النتائج. */
  suggestDecor: boolean;
  /** رد نديم بعد اختيار المناسبة. */
  reaction: string;
};

export type NadeemConfig = {
  enabled: boolean;
  showInNav: boolean;
  showOnHome: boolean;
  name: string;
  subtitle: string;
  typingLabel: string;
  disabledTitle: string;
  disabledMessage: string;
  greeting: string[];
  /** تأخير «يكتب…» بالمللي ثانية. */
  typingDelayMs: number;

  occasionStep: { question: string };
  typeStep: {
    enabled: boolean;
    question: string;
    reaction: string;
    reactionAuto: string;
    allowAuto: boolean;
    autoLabel: string;
    autoAnswer: string;
    showCounts: boolean;
    types: { key: NadeemWorld; enabled: boolean; label: string }[];
  };
  provinceStep: {
    enabled: boolean;
    question: string;
    reactionAll: string;
    /** {province} = اسم المحافظة. */
    reactionOne: string;
    anyLabel: string;
    showCounts: boolean;
    hideEmpty: boolean;
  };
  guestsStep: {
    enabled: boolean;
    question: string;
    reaction: string;
    min: number;
    max: number;
    initial: number;
    /** {n} = العدد. */
    answer: string;
    confirmLabel: string;
    scales: { upTo: number; label: string }[];
  };
  shiftStep: {
    enabled: boolean;
    question: string;
    reaction: string;
    morning: { enabled: boolean; title: string; sub: string };
    evening: { enabled: boolean; title: string; sub: string };
    full: { enabled: boolean; title: string; sub: string };
    flex: { enabled: boolean; label: string; answer: string };
  };
  budgetStep: {
    enabled: boolean;
    question: string;
    openLabel: string;
    openAnswer: string;
    submitLabel: string;
    /** {amount} = المبلغ. */
    answer: string;
    initialPercent: number;
  };

  finish: { intro: string; thinking: string; error: string; retryLabel: string };
  results: {
    /** {occasion} = اسم المناسبة. */
    title: string;
    editHint: string;
    precise: string;
    approximate: string;
    empty: string;
    decorIntro: string;
    restartLabel: string;
    allResultsLabel: string;
    autoTypeChip: string;
    showMatchPercent: boolean;
    showReasons: boolean;
  };

  occasions: NadeemOccasion[];

  matching: {
    type: number;
    typeMiss: number;
    province: number;
    provinceMiss: number;
    capacity: number;
    capacityMiss: number;
    budget: number;
    budgetMiss: number;
    shiftPrice: number;
    shiftSupport: number;
    fullDay: number;
    flex: number;
    ratingMultiplier: number;
    featured: number;
    winter: number;
    minScore: number;
    maxResults: number;
    decorCount: number;
    minPercent: number;
    maxPercent: number;
  };

  /** أماكن تُدفع للأعلى بنقاط إضافية. */
  pinned: { propertyId: string; bonus: number }[];
  /** أماكن لا يقترحها نديم أبداً. */
  excluded: string[];
};

export const DEFAULT_NADEEM_CONFIG: NadeemConfig = {
  enabled: true,
  showInNav: true,
  showOnHome: true,
  name: 'نديم',
  subtitle: 'مخطّط مناسبتك الشخصي',
  typingLabel: 'يكتب…',
  disabledTitle: 'نديم في استراحة قصيرة',
  disabledMessage: 'نعمل على تحسين نديم — يمكنك البحث عن الأماكن مباشرة حتى يعود.',
  greeting: ['أهلاً بك، أنا نديم ✨', 'سأساعدك تختار المكان المثالي لمناسبتك — بخطوات خفيفة.'],
  typingDelayMs: 650,

  occasionStep: { question: 'ما المناسبة التي تخطّط لها؟' },
  typeStep: {
    enabled: true,
    question: 'أي مكان يليق بها؟',
    reaction: 'اختيار موفّق.',
    reactionAuto: 'اترك الأمر لي — سأختار ما يناسب مناسبتك.',
    allowAuto: true,
    autoLabel: 'لست متأكداً — اختر لي يا نديم',
    autoAnswer: 'اختر لي يا نديم',
    showCounts: true,
    types: [
      { key: 'FARM', enabled: true, label: 'مزرعة' },
      { key: 'HALL', enabled: true, label: 'قاعة' },
      { key: 'DECORATION', enabled: true, label: 'تزيين' },
    ],
  },
  provinceStep: {
    enabled: true,
    question: 'في أي محافظة؟',
    reactionAll: 'سأبحث في كل العراق.',
    reactionOne: 'تمام، سأركّز على {province}.',
    anyLabel: 'أي مكان في العراق',
    showCounts: true,
    hideEmpty: false,
  },
  guestsStep: {
    enabled: true,
    question: 'كم ضيفاً تتوقع تقريباً؟',
    reaction: 'وصلت — سأستبعد ما لا يتسع لضيوفك.',
    min: 10,
    max: 1000,
    initial: 70,
    answer: 'حوالي {n} ضيف',
    confirmLabel: 'تمام — {n} ضيف',
    scales: [
      { upTo: 30, label: 'جلسة حميمة' },
      { upTo: 80, label: 'عزيمة عائلية' },
      { upTo: 200, label: 'حفل متوسط' },
      { upTo: 450, label: 'مناسبة كبيرة' },
      { upTo: 100000, label: 'حدث ضخم' },
    ],
  },
  shiftStep: {
    enabled: true,
    question: 'متى تفضّل وقت المناسبة؟',
    reaction: 'حلو، سأراعي التوقيت.',
    morning: { enabled: true, title: 'صباحاً', sub: 'شمس وهواء' },
    evening: { enabled: true, title: 'مساءً', sub: 'أضواء وسهر' },
    full: { enabled: true, title: 'يوم كامل', sub: 'من الصبح لليل' },
    flex: { enabled: true, label: 'التوقيت مرن عندي', answer: 'التوقيت مرن' },
  },
  budgetStep: {
    enabled: true,
    question: 'وأخيراً — كم تحب أن تكون ميزانيتك لليوم؟',
    openLabel: 'مفتوحة',
    openAnswer: 'الميزانية مفتوحة',
    submitLabel: 'اعرض النتائج',
    answer: 'حتى {amount} د.ع',
    initialPercent: 55,
  },

  finish: {
    intro: 'ممتاز! دعني أقرأ الأماكن لأجلك…',
    thinking: 'أطابق مناسبتك مع الأماكن المتاحة…',
    error: 'تعذّر عليّ إكمال البحث الآن — تحقّق من الاتصال وحاول مجدداً.',
    retryLabel: 'حاول مجدداً',
  },
  results: {
    title: 'خطة {occasion}',
    editHint: 'المس أي بند لتعديله',
    precise: 'هذه أفضل الأماكن لمناسبتك، مرتّبة حسب التطابق 👇',
    approximate: 'لم أجد تطابقاً كاملاً، لكن هذه الأقرب لما طلبت 👇',
    empty: 'لم أجد مطابقة دقيقة الآن — جرّب توسيع الميزانية أو تغيير المحافظة.',
    decorIntro: 'ولتكتمل الصورة — فرق تزيين تليق بمناسبتك 🌸',
    restartLabel: 'من جديد',
    allResultsLabel: 'كل النتائج',
    autoTypeChip: 'نديم يختار',
    showMatchPercent: true,
    showReasons: true,
  },

  occasions: [
    {
      key: 'wedding',
      enabled: true,
      label: 'زفاف',
      sub: 'ليلة العمر',
      icon: 'diamond',
      world: 'HALL',
      impliedType: 'HALL',
      suggestDecor: true,
      reaction: 'ألف مبروك! ليلة العمر تستحق الأفضل 💍',
    },
    {
      key: 'engagement',
      enabled: true,
      label: 'خطوبة',
      sub: 'بداية الحكاية',
      icon: 'heart',
      world: 'DECORATION',
      impliedType: 'HALL',
      suggestDecor: true,
      reaction: 'مبارك مقدّماً! بداية جميلة تستحق مكاناً دافئاً.',
    },
    {
      key: 'birthday',
      enabled: true,
      label: 'عيد ميلاد',
      sub: 'فرحة وزينة',
      icon: 'cake',
      world: 'DECORATION',
      impliedType: 'FARM',
      suggestDecor: true,
      reaction: 'رائع! سنجعلها حفلة لا تُنسى 🎂',
    },
    {
      key: 'family',
      enabled: true,
      label: 'جلسة أهل',
      sub: 'يوم دافئ',
      icon: 'family',
      world: 'FARM',
      impliedType: 'FARM',
      suggestDecor: false,
      reaction: 'جميل — الأهل يستحقون يوماً هادئاً ومريحاً.',
    },
    {
      key: 'work',
      enabled: true,
      label: 'عمل',
      sub: 'لقاء رسمي',
      icon: 'work',
      world: 'HALL',
      impliedType: 'HALL',
      suggestDecor: false,
      reaction: 'ممتاز، سأبحث عن مكان أنيق ومنظّم.',
    },
    {
      key: 'other',
      enabled: true,
      label: 'أخرى',
      sub: 'فاجئني',
      icon: 'sparkle',
      world: 'FARM',
      impliedType: null,
      suggestDecor: false,
      reaction: 'حسناً، أخبرني بالمزيد وسأقرأ بين السطور.',
    },
  ],

  matching: {
    type: 40,
    typeMiss: -12,
    province: 28,
    provinceMiss: -10,
    capacity: 22,
    capacityMiss: -24,
    budget: 18,
    budgetMiss: -20,
    shiftPrice: 12,
    shiftSupport: 6,
    fullDay: 8,
    flex: 4,
    ratingMultiplier: 3,
    featured: 6,
    winter: 0,
    minScore: 18,
    maxResults: 10,
    decorCount: 6,
    minPercent: 55,
    maxPercent: 99,
  },

  pinned: [],
  excluded: [],
};

// ── التنقية: نقبل فقط الحقول المعروفة وبأنواعها الصحيحة ──

type Json = Record<string, unknown>;

const isObj = (v: unknown): v is Json => !!v && typeof v === 'object' && !Array.isArray(v);

function str(v: unknown, fallback: string, max = 400): string {
  return typeof v === 'string' ? v.slice(0, max) : fallback;
}

function bool(v: unknown, fallback: boolean): boolean {
  return typeof v === 'boolean' ? v : fallback;
}

function num(v: unknown, fallback: number, min = -100000, max = 100000000): number {
  const n = typeof v === 'number' ? v : typeof v === 'string' && v.trim() !== '' ? Number(v) : NaN;
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

const WORLDS: NadeemWorld[] = ['FARM', 'HALL', 'DECORATION'];
const world = (v: unknown, fallback: NadeemWorld): NadeemWorld =>
  WORLDS.includes(v as NadeemWorld) ? (v as NadeemWorld) : fallback;

/** يدمج أي JSON مع القيم الافتراضية — مفتاح ناقص يأخذ الافتراضي. */
export function normalizeNadeemConfig(raw: unknown): NadeemConfig {
  const d = DEFAULT_NADEEM_CONFIG;
  const r = isObj(raw) ? raw : {};
  const sec = (k: string): Json => (isObj(r[k]) ? (r[k] as Json) : {});

  const typeStep = sec('typeStep');
  const provinceStep = sec('provinceStep');
  const guestsStep = sec('guestsStep');
  const shiftStep = sec('shiftStep');
  const budgetStep = sec('budgetStep');
  const finish = sec('finish');
  const results = sec('results');
  const matching = sec('matching');

  const slot = (o: Json, k: 'morning' | 'evening' | 'full') => {
    const s = isObj(o[k]) ? (o[k] as Json) : {};
    return {
      enabled: bool(s.enabled, d.shiftStep[k].enabled),
      title: str(s.title, d.shiftStep[k].title, 60),
      sub: str(s.sub, d.shiftStep[k].sub, 80),
    };
  };
  const flex = isObj(shiftStep.flex) ? (shiftStep.flex as Json) : {};

  const greeting = Array.isArray(r.greeting)
    ? r.greeting.filter((g): g is string => typeof g === 'string' && g.trim() !== '').map((g) => g.slice(0, 400)).slice(0, 6)
    : d.greeting;

  const types = Array.isArray(typeStep.types)
    ? WORLDS.map((key) => {
        const found = (typeStep.types as unknown[]).find((t) => isObj(t) && t.key === key) as Json | undefined;
        const def = d.typeStep.types.find((t) => t.key === key)!;
        return { key, enabled: bool(found?.enabled, def.enabled), label: str(found?.label, def.label, 40) };
      })
    : d.typeStep.types;

  const scales = Array.isArray(guestsStep.scales)
    ? (guestsStep.scales as unknown[])
        .filter(isObj)
        .map((s) => ({ upTo: num(s.upTo, 100, 1, 100000), label: str(s.label, '', 60) }))
        .filter((s) => s.label.trim() !== '')
        .sort((a, b) => a.upTo - b.upTo)
        .slice(0, 10)
    : d.guestsStep.scales;

  const seenKeys = new Set<string>();
  const occasions = Array.isArray(r.occasions)
    ? (r.occasions as unknown[])
        .filter(isObj)
        .map((o, i) => {
          let key = str(o.key, '', 40).trim().replace(/[^a-zA-Z0-9_-]/g, '') || `occ${i + 1}`;
          while (seenKeys.has(key)) key = `${key}_${i}`;
          seenKeys.add(key);
          const icon = NADEEM_ICONS.includes(o.icon as NadeemIcon) ? (o.icon as NadeemIcon) : 'sparkle';
          const implied = o.impliedType === null || o.impliedType === '' ? null : world(o.impliedType, 'FARM');
          return {
            key,
            enabled: bool(o.enabled, true),
            label: str(o.label, 'مناسبة', 40),
            sub: str(o.sub, '', 60),
            icon,
            world: world(o.world, 'FARM'),
            impliedType: implied,
            suggestDecor: bool(o.suggestDecor, false),
            reaction: str(o.reaction, '', 300),
          };
        })
        .slice(0, 12)
    : d.occasions;

  const minGuests = num(guestsStep.min, d.guestsStep.min, 1, 5000);
  const maxGuests = Math.max(minGuests + 10, num(guestsStep.max, d.guestsStep.max, 10, 20000));

  const pinned = Array.isArray(r.pinned)
    ? (r.pinned as unknown[])
        .filter(isObj)
        .map((p) => ({ propertyId: str(p.propertyId, '', 64), bonus: num(p.bonus, 30, -200, 500) }))
        .filter((p) => p.propertyId !== '')
        .slice(0, 50)
    : d.pinned;
  const excluded = Array.isArray(r.excluded)
    ? [...new Set((r.excluded as unknown[]).filter((x): x is string => typeof x === 'string' && x !== ''))].slice(0, 200)
    : d.excluded;

  const m = d.matching;
  const minPercent = num(matching.minPercent, m.minPercent, 0, 99);

  return {
    enabled: bool(r.enabled, d.enabled),
    showInNav: bool(r.showInNav, d.showInNav),
    showOnHome: bool(r.showOnHome, d.showOnHome),
    name: str(r.name, d.name, 30).trim() || d.name,
    subtitle: str(r.subtitle, d.subtitle, 80),
    typingLabel: str(r.typingLabel, d.typingLabel, 30),
    disabledTitle: str(r.disabledTitle, d.disabledTitle, 80),
    disabledMessage: str(r.disabledMessage, d.disabledMessage, 300),
    greeting: greeting.length ? greeting : d.greeting,
    typingDelayMs: num(r.typingDelayMs, d.typingDelayMs, 0, 3000),

    occasionStep: { question: str(sec('occasionStep').question, d.occasionStep.question, 200) },
    typeStep: {
      enabled: bool(typeStep.enabled, d.typeStep.enabled),
      question: str(typeStep.question, d.typeStep.question, 200),
      reaction: str(typeStep.reaction, d.typeStep.reaction, 300),
      reactionAuto: str(typeStep.reactionAuto, d.typeStep.reactionAuto, 300),
      allowAuto: bool(typeStep.allowAuto, d.typeStep.allowAuto),
      autoLabel: str(typeStep.autoLabel, d.typeStep.autoLabel, 80),
      autoAnswer: str(typeStep.autoAnswer, d.typeStep.autoAnswer, 80),
      showCounts: bool(typeStep.showCounts, d.typeStep.showCounts),
      types: types.some((t) => t.enabled) ? types : d.typeStep.types,
    },
    provinceStep: {
      enabled: bool(provinceStep.enabled, d.provinceStep.enabled),
      question: str(provinceStep.question, d.provinceStep.question, 200),
      reactionAll: str(provinceStep.reactionAll, d.provinceStep.reactionAll, 300),
      reactionOne: str(provinceStep.reactionOne, d.provinceStep.reactionOne, 300),
      anyLabel: str(provinceStep.anyLabel, d.provinceStep.anyLabel, 80),
      showCounts: bool(provinceStep.showCounts, d.provinceStep.showCounts),
      hideEmpty: bool(provinceStep.hideEmpty, d.provinceStep.hideEmpty),
    },
    guestsStep: {
      enabled: bool(guestsStep.enabled, d.guestsStep.enabled),
      question: str(guestsStep.question, d.guestsStep.question, 200),
      reaction: str(guestsStep.reaction, d.guestsStep.reaction, 300),
      min: minGuests,
      max: maxGuests,
      initial: Math.min(maxGuests, Math.max(minGuests, num(guestsStep.initial, d.guestsStep.initial, 1, 20000))),
      answer: str(guestsStep.answer, d.guestsStep.answer, 80),
      confirmLabel: str(guestsStep.confirmLabel, d.guestsStep.confirmLabel, 80),
      scales: scales.length ? scales : d.guestsStep.scales,
    },
    shiftStep: {
      enabled: bool(shiftStep.enabled, d.shiftStep.enabled),
      question: str(shiftStep.question, d.shiftStep.question, 200),
      reaction: str(shiftStep.reaction, d.shiftStep.reaction, 300),
      morning: slot(shiftStep, 'morning'),
      evening: slot(shiftStep, 'evening'),
      full: slot(shiftStep, 'full'),
      flex: {
        enabled: bool(flex.enabled, d.shiftStep.flex.enabled),
        label: str(flex.label, d.shiftStep.flex.label, 80),
        answer: str(flex.answer, d.shiftStep.flex.answer, 80),
      },
    },
    budgetStep: {
      enabled: bool(budgetStep.enabled, d.budgetStep.enabled),
      question: str(budgetStep.question, d.budgetStep.question, 200),
      openLabel: str(budgetStep.openLabel, d.budgetStep.openLabel, 40),
      openAnswer: str(budgetStep.openAnswer, d.budgetStep.openAnswer, 80),
      submitLabel: str(budgetStep.submitLabel, d.budgetStep.submitLabel, 40),
      answer: str(budgetStep.answer, d.budgetStep.answer, 80),
      initialPercent: num(budgetStep.initialPercent, d.budgetStep.initialPercent, 0, 100),
    },

    finish: {
      intro: str(finish.intro, d.finish.intro, 300),
      thinking: str(finish.thinking, d.finish.thinking, 200),
      error: str(finish.error, d.finish.error, 300),
      retryLabel: str(finish.retryLabel, d.finish.retryLabel, 40),
    },
    results: {
      title: str(results.title, d.results.title, 80),
      editHint: str(results.editHint, d.results.editHint, 120),
      precise: str(results.precise, d.results.precise, 300),
      approximate: str(results.approximate, d.results.approximate, 300),
      empty: str(results.empty, d.results.empty, 300),
      decorIntro: str(results.decorIntro, d.results.decorIntro, 300),
      restartLabel: str(results.restartLabel, d.results.restartLabel, 40),
      allResultsLabel: str(results.allResultsLabel, d.results.allResultsLabel, 40),
      autoTypeChip: str(results.autoTypeChip, d.results.autoTypeChip, 40),
      showMatchPercent: bool(results.showMatchPercent, d.results.showMatchPercent),
      showReasons: bool(results.showReasons, d.results.showReasons),
    },

    occasions: occasions.some((o) => o.enabled) ? occasions : d.occasions,

    matching: {
      type: num(matching.type, m.type, -500, 500),
      typeMiss: num(matching.typeMiss, m.typeMiss, -500, 500),
      province: num(matching.province, m.province, -500, 500),
      provinceMiss: num(matching.provinceMiss, m.provinceMiss, -500, 500),
      capacity: num(matching.capacity, m.capacity, -500, 500),
      capacityMiss: num(matching.capacityMiss, m.capacityMiss, -500, 500),
      budget: num(matching.budget, m.budget, -500, 500),
      budgetMiss: num(matching.budgetMiss, m.budgetMiss, -500, 500),
      shiftPrice: num(matching.shiftPrice, m.shiftPrice, -500, 500),
      shiftSupport: num(matching.shiftSupport, m.shiftSupport, -500, 500),
      fullDay: num(matching.fullDay, m.fullDay, -500, 500),
      flex: num(matching.flex, m.flex, -500, 500),
      ratingMultiplier: num(matching.ratingMultiplier, m.ratingMultiplier, 0, 50),
      featured: num(matching.featured, m.featured, -500, 500),
      winter: num(matching.winter, m.winter, -500, 500),
      minScore: num(matching.minScore, m.minScore, -500, 500),
      maxResults: num(matching.maxResults, m.maxResults, 1, 30),
      decorCount: num(matching.decorCount, m.decorCount, 0, 20),
      minPercent,
      maxPercent: Math.max(minPercent + 1, num(matching.maxPercent, m.maxPercent, 1, 100)),
    },

    pinned,
    excluded,
  };
}
