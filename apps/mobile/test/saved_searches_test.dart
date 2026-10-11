import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibes/core/utils/saved_searches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedSearchStore', () {
    test('label يركّب وصف البحث بالعربية', () {
      const farm = SavedSearch(
        query: 'قاعة الورود',
        type: 'HALL',
        province: 'baghdad',
        capacity: 200,
      );
      expect(farm.label, contains('قاعة الورود'));
      expect(farm.label, contains('قاعات'));
      expect(farm.label, contains('200'));

      const empty = SavedSearch(query: '   ');
      expect(empty.isEmpty, isTrue);
    });

    test('signature يميّز البحوث المختلفة ويطابق المتطابقة', () {
      const a = SavedSearch(query: 'مزرعة', type: 'FARM');
      const b = SavedSearch(query: 'مزرعة', type: 'FARM');
      const c = SavedSearch(query: 'مزرعة', type: 'HALL');
      expect(a.signature, b.signature);
      expect(a.signature, isNot(c.signature));
    });

    test('save ثم load ثم remove يعملان بدورة كاملة', () async {
      SharedPreferences.setMockInitialValues({});
      const search = SavedSearch(query: 'قاعات بغداد', province: 'baghdad');

      final saved = await SavedSearchStore.save(search);
      expect(saved.length, 1);

      // إعادة حفظ نفس البحث لا تكرّره
      final again = await SavedSearchStore.save(search);
      expect(again.length, 1);

      final loaded = await SavedSearchStore.load();
      expect(loaded.first.query, 'قاعات بغداد');

      final afterRemove = await SavedSearchStore.remove(search.signature);
      expect(afterRemove, isEmpty);
    });

    test('البحث الفارغي لا يُحفظ', () async {
      SharedPreferences.setMockInitialValues({});
      const blank = SavedSearch(query: '');
      final result = await SavedSearchStore.save(blank);
      expect(result, isEmpty);
    });
  });
}
