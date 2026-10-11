import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibes/app/app.dart';
import 'package:vibes/core/notifications/firebase_placeholder.dart'
    as notifications;
import 'package:vibes/core/constants/map_constants.dart';
import 'package:vibes/core/utils/data_saver.dart';
import 'package:vibes/core/utils/error_guard.dart';
import 'package:vibes/core/perf/perf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MapConstants.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  ErrorGuard.init();
  // كاش صور أكبر — تطبيق غني بالصور: 400 صورة / 220MB
  // يقلل إعادة التحميل عند التنقل بين الشاشات بشكل ملموس.
  // الصور تُفك بمقاس العرض الآن، فـ150MB تكفي ولا تضغط ذاكرة الأجهزة الضعيفة
  PaintingBinding.instance.imageCache.maximumSize = 400;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  // إبقاء الصور الحية عند ضغط الذاكرة — لا تنظيف مبكر.
  // (clearLiveImages دالة استدعاء وليست ضبطاً؛ الافتراضي يحفظ الحية أصلاً.)
  // بدء أسرع: تسخين DataSaver وتسجيل الجهاز بعد أول إطار —
  // لا يحجبا العرض الأولي بأي انتظار شبكة.
  unawaited(DataSaver.warm().then((_) => notifications.init()));
  // معدل تحديث عالٍ (90/120Hz) + مراقبة أداء الجهاز للوضع الخفيف
  unawaited(Perf.init());

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: const ProviderScope(child: VibesApp()),
    ),
  );
}
