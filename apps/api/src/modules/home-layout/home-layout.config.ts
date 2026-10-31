/**
 * ترتيب وظهور أقسام الصفحة الرئيسية في تطبيق الزبون والموقع — يُدار من لوحة التحكم.
 * أي مفتاح غير معروف يُتجاهل، وأي قسم جديد في الكود يُضاف تلقائياً مفعّلاً في آخره.
 */

export type LayoutItem = { key: string; enabled: boolean };

export type HomeLayout = {
  header: LayoutItem[];
  body: LayoutItem[];
  quickLinks: Record<string, boolean>;
};

/** أقسام رأس الصفحة (فوق المحتوى). */
export const HEADER_SECTIONS: { key: string; label: string; hint: string }[] = [
  { key: 'banners', label: 'البانرات الإعلانية', hint: 'الصور المتحركة أعلى الصفحة (تُدار من قسم البانرات)' },
  { key: 'nearest', label: 'بطاقة «الأقرب إليك»', hint: 'خريطة مصغّرة تفتح خريطة الأماكن' },
  { key: 'quickLinks', label: 'الاختصارات السريعة', hint: 'أزرار: الخريطة، العروض، الكوبونات، نديم، التجارب، المقارنة' },
  { key: 'destinations', label: 'الوجهات والمحافظات', hint: 'المحافظات وعدد الأماكن في كل منها' },
];

/** أقسام المحتوى بالترتيب الافتراضي. */
export const BODY_SECTIONS: { key: string; label: string; hint: string }[] = [
  { key: 'continueBooking', label: 'حجزك القادم', hint: 'يظهر للمسجّلين عند وجود حجز قادم' },
  { key: 'editorsPicks', label: 'أماكن مختارة', hint: 'الأماكن المميزة (المؤشّر عليها «مميز»)' },
  { key: 'occasions', label: 'خطّط لمناسبتك', hint: 'بطاقات المناسبات: زفاف، خطوبة، عيد ميلاد…' },
  { key: 'newArrivals', label: 'وصل حديثاً', hint: 'أحدث الأماكن في العالم المختار' },
  { key: 'winterFarms', label: 'مزارع شتوية', hint: 'في عالم المزارع فقط، عند وجود مزارع شتوية' },
  { key: 'coupon', label: 'تذكرة الكوبون', hint: 'أبرز كوبون خصم متاح' },
  { key: 'topRated', label: 'الأعلى تقييماً', hint: 'الأماكن الأعلى تقييماً' },
  { key: 'spotlights', label: 'لقطات من أماكننا', hint: 'الصور الكبيرة (تُدار من قسم أماكن مميزة)' },
  { key: 'map', label: 'خريطة الأماكن', hint: 'بطاقة الخريطة الكبيرة' },
  { key: 'recentlyViewed', label: 'شاهدتها مؤخراً', hint: 'الأماكن التي فتحها الزبون' },
  { key: 'following', label: 'مضيفون تتابعهم', hint: 'للزبائن الذين يتابعون أصحاب أماكن' },
  { key: 'trust', label: 'لماذا أجواء', hint: 'مزايا الحجز عبر أجواء' },
  { key: 'allPlaces', label: 'كل الأماكن', hint: 'قائمة كل أماكن العالم المختار — تبقى دائماً قبل التذييل' },
  { key: 'footer', label: 'تذييل الصفحة', hint: 'شعار ونص ختامي — دائماً في آخر الصفحة' },
];

export const QUICK_LINKS: { key: string; label: string }[] = [
  { key: 'map', label: 'الخريطة' },
  { key: 'offers', label: 'العروض' },
  { key: 'coupons', label: 'الكوبونات' },
  { key: 'experiences', label: 'التجارب' },
  { key: 'compare', label: 'المقارنة' },
];

export const DEFAULT_HOME_LAYOUT: HomeLayout = {
  header: HEADER_SECTIONS.map((s) => ({ key: s.key, enabled: true })),
  body: BODY_SECTIONS.map((s) => ({ key: s.key, enabled: true })),
  quickLinks: Object.fromEntries(QUICK_LINKS.map((q) => [q.key, true])),
};

function mergeList(raw: unknown, catalog: { key: string }[]): LayoutItem[] {
  const known = new Set(catalog.map((c) => c.key));
  const seen = new Set<string>();
  const out: LayoutItem[] = [];
  if (Array.isArray(raw)) {
    for (const item of raw) {
      if (!item || typeof item !== 'object') continue;
      const key = (item as { key?: unknown }).key;
      if (typeof key !== 'string' || !known.has(key) || seen.has(key)) continue;
      seen.add(key);
      out.push({ key, enabled: (item as { enabled?: unknown }).enabled !== false });
    }
  }
  for (const c of catalog) if (!seen.has(c.key)) out.push({ key: c.key, enabled: true });
  return out;
}

export function normalizeHomeLayout(raw: unknown): HomeLayout {
  const r = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const ql = r.quickLinks && typeof r.quickLinks === 'object' ? (r.quickLinks as Record<string, unknown>) : {};
  return {
    header: mergeList(r.header, HEADER_SECTIONS),
    body: mergeList(r.body, BODY_SECTIONS),
    quickLinks: Object.fromEntries(QUICK_LINKS.map((q) => [q.key, ql[q.key] !== false])),
  };
}
