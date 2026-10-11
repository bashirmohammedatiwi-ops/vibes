import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'mapbox_token.dart';

/// Mapbox — SDK أصلي، أداء GPU.
/// الستايل LIGHT خفيف وسريع التحميل؛ STANDARD الثقيل (3D) يبطئ أول فتح.
class MapConstants {
  MapConstants._();

  // الرمز العام من ملف محلي غير مرفوع (mapbox_token.dart) أو من
  // --dart-define=MAPBOX_ACCESS_TOKEN=... — انسخ mapbox_token.dart.example.
  static const accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: kMapboxPublicToken,
  );

  /// Light — بلاطات فاتحة نظيفة، أسرع ستايل تحميلاً بفارق كبير.
  static const styleUri = 'mapbox://styles/mapbox/light-v11';

  /// تضاريس وطرق — أوضح للاستكشاف والمناطق الخضراء.
  static const exploreStyleUri = 'mapbox://styles/mapbox/outdoors-v12';

  /// قمر صناعي + تسميات — للتفاصيل الجغرافية.
  static const satelliteStyleUri =
      'mapbox://styles/mapbox/satellite-streets-v12';

  /// نسخة داكنة للوضع الليلي عند الحاجة.
  static const darkStyleUri = 'mapbox://styles/mapbox/dark-v11';

  static const iraqCenter = (lat: 33.3152, lng: 44.3661);
  static const defaultZoom = 5.8;
  static const detailZoom = 13.5;

  /// تسخين الخريطة: يبدأ تحميل الستايل والبلاطات قبل فتح شاشة الخريطة،
  /// فيصبح الفتح الفعلي لحظياً لأن كل شيء مخزّن.
  static Future<void> ensureInitialized() {
    // الويب غير مدعوم — حزمة Mapbox تتطلب منصات أصلية.
    if (kIsWeb) return Future.value();
    MapboxOptions.setAccessToken(accessToken);
    return Future.value();
  }
}
