import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/vibes_graphics.dart';

/// ═══════════════════════════════════════════════════════════
/// عوالم VIBES الثلاثة — كل قسم هوية لونية من اللوحة الرسمية:
///   المزارع  → النحاس (دفء الأرض والضيافة)
///   القاعات  → الياقوت (فخامة الأعراس)
///   التزيين  → المابل (بهجة الاحتفال)
/// الهوية تنتقل بسلاسة عبر كامل الصفحة الرئيسية وشريط التنقل.
/// ═══════════════════════════════════════════════════════════

enum HomeSection { farm, hall, decoration }

final homeSectionProvider = StateProvider<HomeSection>(
  (ref) => HomeSection.farm,
);

extension HomeSectionX on HomeSection {
  /// اللون التوقيعي للقسم — من لوحة الهوية الرسمية
  Color get accent => switch (this) {
    HomeSection.farm => Vibes.teal, // النحاس
    HomeSection.hall => Vibes.coral, // الياقوت
    HomeSection.decoration => Vibes.mapple, // المابل
  };

  /// النسخة العميقة المقروءة على الخلفيات الفاتحة
  Color get accentDeep => switch (this) {
    HomeSection.farm => Vibes.honeyDeep,
    HomeSection.hall => themed(Brand.sapphire, VibesDark.coralBright),
    HomeSection.decoration => themed(
      const Color(0xFFC93A5C),
      const Color(0xFFF9AEC0),
    ),
  };

  /// الصبغة الناعمة للخلفيات
  Color get accentSoft => accent.withValues(alpha: .10);

  /// لون فوق اللون الممتلئ
  Color get onAccent => switch (this) {
    HomeSection.farm => Vibes.onTeal,
    HomeSection.hall => Vibes.onCoral,
    HomeSection.decoration => themed(Colors.white, const Color(0xFF2B0A16)),
  };

  String get label => switch (this) {
    HomeSection.farm => 'مزارع'.tr,
    HomeSection.hall => 'قاعات'.tr,
    HomeSection.decoration => 'تزيين'.tr,
  };

  String get tagline => switch (this) {
    HomeSection.farm => 'ضيافة الأرض والشمس'.tr,
    HomeSection.hall => 'ليلة العمر تستحق قاعة'.tr,
    HomeSection.decoration => 'تفاصيل تصنع الفرح'.tr,
  };

  /// «كل مزارع» — عنوان قائمة العالم الكاملة.
  String get allTitle => switch (this) {
    HomeSection.farm => 'كل مزارع'.tr,
    HomeSection.hall => 'كل قاعات'.tr,
    HomeSection.decoration => 'كل تزيين'.tr,
  };

  /// حالة الفراغ لقائمة العالم.
  String get emptyTitle => switch (this) {
    HomeSection.farm => 'لا مزارع بعد'.tr,
    HomeSection.hall => 'لا قاعات بعد'.tr,
    HomeSection.decoration => 'لا تزيين بعد'.tr,
  };

  /// زر البدء من ورقة المناسبة.
  String get startWith => switch (this) {
    HomeSection.farm => 'ابدأ بـمزارع'.tr,
    HomeSection.hall => 'ابدأ بـقاعات'.tr,
    HomeSection.decoration => 'ابدأ بـتزيين'.tr,
  };

  /// لا جولات فيديو لهذا العالم.
  String get noReelsTitle => switch (this) {
    HomeSection.farm => 'لا جولات فيديو لـمزارع بعد'.tr,
    HomeSection.hall => 'لا جولات فيديو لـقاعات بعد'.tr,
    HomeSection.decoration => 'لا جولات فيديو لـتزيين بعد'.tr,
  };

  String get typeFilter => switch (this) {
    HomeSection.farm => 'FARM',
    HomeSection.hall => 'HALL',
    HomeSection.decoration => 'DECORATION',
  };

  VibesCategory get icon => switch (this) {
    HomeSection.farm => VibesCategory.farm,
    HomeSection.hall => VibesCategory.hall,
    HomeSection.decoration => VibesCategory.decoration,
  };

  String get railTitle => switch (this) {
    HomeSection.farm => 'مزارع جديدة'.tr,
    HomeSection.hall => 'قاعات جديدة'.tr,
    HomeSection.decoration => 'أعمال تزيين'.tr,
  };

  String get railSubtitle => switch (this) {
    HomeSection.farm => 'أضيفت حديثاً إلى الضيافة'.tr,
    HomeSection.hall => 'قاعات دخلت الدار هذا الموسم'.tr,
    HomeSection.decoration => 'لمسات فرحت ضيوفنا'.tr,
  };

  String get provincesSubtitle => switch (this) {
    HomeSection.farm => 'مزارع على امتداد العراق'.tr,
    HomeSection.hall => 'قاعات في كل محافظة'.tr,
    HomeSection.decoration => 'فرق تزيين بالقرب منك'.tr,
  };

  String get spotlightsSubtitle => switch (this) {
    HomeSection.farm => 'ضيافة مختارة من فريق أجواء'.tr,
    HomeSection.hall => 'قاعات ليلة لا تُنسى'.tr,
    HomeSection.decoration => 'لمسات جاهزة لمناسبتك'.tr,
  };
}

/// سهم «التالي» لأزرار الانتقال: الرسم العربي كما هو، والإنجليزية تشير إلى الأمام.
IconData get forwardChevron =>
    I18n.isEn ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;

IconData get forwardArrow =>
    I18n.isEn ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded;

/// عالم العقار من نوعه — لرحلة حجز وتفاصيل بلون المكان نفسه
HomeSection sectionForType(String? type) => switch (type?.toUpperCase()) {
  'HALL' => HomeSection.hall,
  'DECORATION' => HomeSection.decoration,
  _ => HomeSection.farm,
};

Color accentForType(String? type) => sectionForType(type).accent;
