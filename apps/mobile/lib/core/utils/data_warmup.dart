import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/marketplace_providers.dart';
import '../../shared/data/property_providers.dart';
import 'vibes_net_image.dart';

/// تسخين البيانات — يُلمس Providers الأساسية للرئيسية أثناء الـ Splash
/// فتبدأ طلبات الشبكة مبكراً بالتوازي مع الأنيميشن، وعند فتح الرئيسية
/// تجد البيانات جاهزة أو شبه جاهزة — بلا شاشات انتظار.
///
/// يُستدعى مرة واحدة من Splash؛ لمس provider يبدأ جلب Future ويبقى في الكاش.
class DataWarmup {
  DataWarmup._();

  static bool _done = false;

  static void warm(WidgetRef ref) {
    if (_done) return;
    _done = true;

    void touch<T>(Future<T> future) {
      future.ignore();
    }

    // لمس فقط — Riverpod يبدأ الجلب فوراً ويبقيه في الكاش.
    touch(
      ref.read(propertiesProvider(null).future).then((list) {
        // بطاقات القائمة بعرض الشاشة (~360 منطقي × 2) → مقاس 800 نفسه الذي
        // ستطلبه البطاقة، فتظهر الصورة فوراً من الكاش.
        for (final property in list.take(10)) {
          final url = property.coverUrl;
          if (url == null || url.isEmpty) continue;
          VibesNetImage.cache.downloadFile(sizedImageUrl(url, 800)).ignore();
        }
      }),
    );
    touch(
      ref.read(bannersProvider.future).then((list) {
        for (final banner in list.take(4)) {
          final url = banner.imageUrl;
          if (url.isEmpty) continue;
          VibesNetImage.cache.downloadFile(sizedImageUrl(url, 800)).ignore();
        }
      }),
    );
    touch(ref.read(featuredPropertiesProvider.future));
    touch(ref.read(newPropertiesProvider('FARM').future));
    touch(ref.read(newPropertiesProvider('HALL').future));
    touch(ref.read(newPropertiesProvider('DECORATION').future));
    touch(ref.read(topRatedPropertiesProvider.future));
    touch(ref.read(publicCouponsProvider.future));
    touch(ref.read(locationsProvider.future));
  }

  /// إعادة تمكين التسخين بعد اختبار أو إعادة تشغيل ساخنة.
  static void resetForHotRestart() => _done = false;
}
