import 'package:flutter_test/flutter_test.dart';
import 'package:vibes/core/theme/app_theme.dart';
import 'package:vibes/features/home/home_sections.dart';

void main() {
  group('نظام عوالم الرئيسية', () {
    test('لكل عالم لوناً مختلفاً من اللوحة الرسمية', () {
      final accents = {
        for (final section in HomeSection.values) section: section.accent,
      };
      // ثلاثة ألوان متمايزة
      expect(accents.values.toSet().length, HomeSection.values.length);
      expect(accents[HomeSection.farm], Vibes.teal); // النحاس
      expect(accents[HomeSection.hall], Vibes.coral); // الياقوت
      expect(accents[HomeSection.decoration], Vibes.mapple); // المابل
    });

    test('تسميات وفلاتر كل عالم صحيحة وغير فارغة', () {
      for (final section in HomeSection.values) {
        expect(section.label, isNotEmpty);
        expect(section.tagline, isNotEmpty);
        expect(section.railTitle, isNotEmpty);
        expect(section.typeFilter, isNotEmpty);
      }
      expect(HomeSection.farm.typeFilter, 'FARM');
      expect(HomeSection.hall.typeFilter, 'HALL');
      expect(HomeSection.decoration.typeFilter, 'DECORATION');
    });

    test('ربط أنواع العقارات بعوالمها', () {
      expect(sectionForType('FARM'), HomeSection.farm);
      expect(sectionForType('farm'), HomeSection.farm);
      expect(sectionForType('HALL'), HomeSection.hall);
      expect(sectionForType('DECORATION'), HomeSection.decoration);
      // المجهول يهبط في عالم المزارع
      expect(sectionForType(null), HomeSection.farm);
      expect(sectionForType('UNKNOWN'), HomeSection.farm);
      expect(accentForType('HALL'), Vibes.coral);
    });

    test('ألوان فوق الممتلئ مقروءة', () {
      for (final section in HomeSection.values) {
        expect(section.onAccent, isNotNull);
        // علىAccent ليس شفافاً
        expect(section.onAccent.alpha, 255);
      }
    });
  });
}
