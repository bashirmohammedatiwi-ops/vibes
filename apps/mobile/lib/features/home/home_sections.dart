import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    HomeSection.hall => Brand.sapphire,
    HomeSection.decoration => const Color(0xFFC93A5C),
  };

  /// الصبغة الناعمة للخلفيات
  Color get accentSoft => accent.withValues(alpha: .10);

  /// لون فوق اللون الممتلئ
  Color get onAccent => switch (this) {
    HomeSection.farm => Vibes.onTeal,
    HomeSection.hall => Vibes.onCoral,
    HomeSection.decoration => Colors.white,
  };

  String get label => switch (this) {
    HomeSection.farm => 'مزارع',
    HomeSection.hall => 'قاعات',
    HomeSection.decoration => 'تزيين',
  };

  String get tagline => switch (this) {
    HomeSection.farm => 'ضيافة الأرض والشمس',
    HomeSection.hall => 'ليلة العمر تستحق قاعة',
    HomeSection.decoration => 'تفاصيل تصنع الفرح',
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
    HomeSection.farm => 'مزارع جديدة',
    HomeSection.hall => 'قاعات جديدة',
    HomeSection.decoration => 'أعمال تزيين',
  };

  String get railSubtitle => switch (this) {
    HomeSection.farm => 'أضيفت حديثاً إلى الضيافة',
    HomeSection.hall => 'قاعات دخلت الدار هذا الموسم',
    HomeSection.decoration => 'لمسات فرحت ضيوفنا',
  };

  String get provincesSubtitle => switch (this) {
    HomeSection.farm => 'مزارع على امتداد العراق',
    HomeSection.hall => 'قاعات في كل محافظة',
    HomeSection.decoration => 'فرق تزيين بالقرب منك',
  };

  String get spotlightsSubtitle => switch (this) {
    HomeSection.farm => 'ضيافة مختارة من فريق VIBEES',
    HomeSection.hall => 'قاعات ليلة لا تُنسى',
    HomeSection.decoration => 'لمسات جاهزة لمناسبتك',
  };
}

/// عالم العقار من نوعه — لرحلة حجز وتفاصيل بلون المكان نفسه
HomeSection sectionForType(String? type) => switch (type?.toUpperCase()) {
  'HALL' => HomeSection.hall,
  'DECORATION' => HomeSection.decoration,
  _ => HomeSection.farm,
};

Color accentForType(String? type) => sectionForType(type).accent;
