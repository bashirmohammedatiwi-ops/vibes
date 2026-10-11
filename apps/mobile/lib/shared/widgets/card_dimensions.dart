/// أبعاد البطاقات — شبكة 4pt، نسب ذهبية، مقاسات موحّدة في كل التطبيق.
abstract final class CardDims {
  CardDims._();

  // ── شبكة ──
  static const gap = 14.0;
  static const gapSm = 10.0;
  static const screenPad = 20.0;

  // ── زوايا ناعمة — أنيقة بلا كبسولة ──
  static const radius = 12.0;
  static const radiusSm = 8.0;
  static const photoRadius = 10.0;
  static const inset = 10.0;
  static const insetSm = 8.0;

  // ── حشوة المحتوى ──
  static const bodyPadH = 14.0;
  static const bodyPadV = 13.0;
  static const bodyPadCompact = 10.0;

  // ── نسب الصورة ──
  static const listingAspect = 2.05;
  static const featuredAspect = 16 / 9;
  static const hallAspect = 16 / 9;
  static const compactThumbAspect = 1.0;

  // ── عرض الشرائح الأفقية ──
  static const featuredWidth = 252.0;
  static const featuredWidthLg = 268.0;
  static const hallWidth = 308.0;
  static const hallWidthLg = 320.0;
  static const recentWidth = 256.0;
  static const railWidth = 272.0;

  /// بطاقات الرئيسية — صور أفقية، ارتفاع منخفض.
  static const homeRailWidth = 308.0;
  static const homeRailAspect = 16 / 9;
  static const provinceWidth = 220.0;
  static const provinceHeight = 124.0;
  static const spotlightWidth = 308.0;
  static const spotlightHeight = 136.0;
  static const homeSectionGap = 24.0;

  // ── بلاطات الرئيسية التحريرية ──
  /// مسافة موحّدة فوق كل قسم — أكثر من المسافة تحت العنوان.
  static const sectionTopGap = 36.0;

  /// بلاطة محافظة — صورة كاملة بتراكب نصي.
  static const provinceTileWidth = 168.0;
  static const provinceTileHeight = 204.0;

  /// إطار سينمائي — عريض منخفض للشريط المتحرك.
  static const cinematicWidth = 322.0;
  static const cinematicHeight = 148.0;

  /// خطوة الالتصاق للسكك الأفقية.
  static const railSnapStep = homeRailWidth + gap;

  // ── الرئيسية v3 — نظام بطاقات موحّد ──
  /// بطاقة قائمة رئيسية — صورة 16:10 ومعلومة كاملة تحتها.
  static const homeListCardWidth = 343.0;
  static const homeListCardAspect = 16 / 10;

  /// بطاقة سكة أفقية — أصغر قليلاً، نفس لغة القائمة.
  static const homeRailCardWidth = 240.0;
  static const homeRailCardAspect = 4 / 3;

  /// بلاطة وجهة الرئيسية — مستطيل صغير مضغوط.
  static const destinationTileWidth = 132.0;
  static const destinationTileHeight = 92.0;

  // ── ارتفاعات ثابتة ──
  static const compactHeight = 96.0;
  static const compactThumb = 112.0;
  static const compactThumbHeight = 62.0;
  static const bodyMinHeight = 74.0;
  static const captionMinHeight = 44.0;

  static double homeRailHeight([double width = homeRailWidth]) =>
      width / homeRailAspect;

  static double featuredHeight([double width = featuredWidth]) =>
      width / featuredAspect;

  static double hallHeight([double width = hallWidth]) => width / hallAspect;

  static double listingPhotoHeight(double width) => width / listingAspect;

  static double listCardHeight(double width, {bool compact = false}) {
    if (compact) return compactHeight;
    return inset + listingPhotoHeight(width - inset * 2) + bodyMinHeight;
  }
}
