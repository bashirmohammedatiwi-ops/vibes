import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أداء متكيّف مع الجهاز:
///  • أعلى معدل تحديث تدعمه الشاشة على أندرويد (90/120Hz) — أجهزة كثيرة
///    (شاومي خاصة) تُشغّل التطبيقات على 60Hz افتراضياً.
///  • مراقبة توقيت الإطارات: إن تأخر جزء كبير منها على جهاز ضعيف يُفعَّل
///    «الوضع الخفيف» (ظلال أخف، بلا حركات دخول) ويُحفظ للمرات القادمة.
class Perf {
  Perf._();

  static const _prefKey = 'perf_lite_v1';

  /// الوضع الخفيف — تستمع له الواجهات التي تخفف تأثيراتها.
  static final ValueNotifier<bool> lite = ValueNotifier<bool>(false);

  static bool get isLite => lite.value;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lite.value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {}

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (_) {}
    }
    if (!lite.value) _watchFrames();
  }

  static int _samples = 0;
  static int _slow = 0;

  static void _watchFrames() {
    final binding = SchedulerBinding.instance;
    void onTimings(List<FrameTiming> timings) {
      final hz = _refreshRate();
      final budgetUs = (1e6 / hz).round();
      for (final t in timings) {
        // نتجاهل الإطارات الأولى (الإقلاع وتهيئة الشيدرات)
        if (_samples++ < 30) continue;
        final cost =
            t.buildDuration.inMicroseconds > t.rasterDuration.inMicroseconds
            ? t.buildDuration.inMicroseconds
            : t.rasterDuration.inMicroseconds;
        if (cost > budgetUs * 1.5) _slow++;
      }
      // بعد ~400 إطار (بضع ثوانٍ من الاستخدام): أكثر من 18% متأخرة = جهاز يعاني
      if (_samples >= 430) {
        binding.removeTimingsCallback(onTimings);
        final ratio = _slow / (_samples - 30);
        if (ratio > 0.18) _enableLite();
      }
    }

    binding.addTimingsCallback(onTimings);
  }

  static double _refreshRate() {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      final rate = views.isEmpty ? 60.0 : views.first.display.refreshRate;
      return rate.isFinite && rate >= 30 ? rate : 60.0;
    } catch (_) {
      return 60.0;
    }
  }

  static Future<void> _enableLite() async {
    lite.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
  }

  /// ظلال البطاقات: كاملة على الأجهزة القوية، وظل واحد خفيف في الوضع الخفيف.
  static List<BoxShadow> shadows(List<BoxShadow> full) {
    if (!lite.value || full.isEmpty) return full;
    final first = full.first;
    return [
      BoxShadow(
        color: first.color.withValues(alpha: first.color.a * .7),
        blurRadius: first.blurRadius.clamp(0, 8),
        offset: Offset(first.offset.dx, first.offset.dy.clamp(0, 3)),
      ),
    ];
  }

  /// هل تُشغَّل حركات الدخول الزخرفية؟
  static bool animationsOn(BuildContext context) =>
      !lite.value && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

/// حركة دخول لعناصر القوائم: لأول ٦ عناصر فقط (ما يظهر عند الفتح)، وبلا
/// حركة في الوضع الخفيف — العناصر التي تُبنى أثناء التمرير تظهر فوراً.
extension PerfListEntrance on Widget {
  Widget listEntrance(int index, {int stepMs = 40}) {
    if (Perf.isLite || index >= 6) return this;
    return animate(delay: Duration(milliseconds: stepMs * index))
        .fadeIn(duration: const Duration(milliseconds: 300))
        .slideY(begin: .04, end: 0, curve: Curves.easeOutCubic);
  }
}

/// قياس أداء (بناء خاص فقط: --dart-define=PERF_PROBE=true): يمرّر الشاشة
/// آلياً ويطبع إحصاءات الإطارات في السجل (adb logcat) — لا يعمل في الإصدار.
class PerfProbe {
  PerfProbe._();

  /// الشاشة المقيسة: home | property | search (فارغ = معطّل).
  static const target = String.fromEnvironment('PERF_PROBE');

  static Future<void> run(ScrollController scroll, {String screen = 'home'}) async {
    if (target != screen) return;
    await Future<void>.delayed(const Duration(seconds: 6));
    final build = <int>[];
    final raster = <int>[];
    void onTimings(List<FrameTiming> ts) {
      for (final t in ts) {
        build.add(t.buildDuration.inMicroseconds);
        raster.add(t.rasterDuration.inMicroseconds);
      }
    }

    SchedulerBinding.instance.addTimingsCallback(onTimings);
    var travelled = 0.0;
    for (var pass = 0; pass < 2; pass++) {
      // نزولاً بخطوات — المحتوى الكسول يُبنى فيمتد مدى التمرير تدريجياً
      for (var step = 0; step < 14; step++) {
        if (!scroll.hasClients) break;
        final pos = scroll.position;
        final target = (pos.pixels + 900).clamp(0.0, pos.maxScrollExtent);
        if (target <= pos.pixels + 1) break;
        travelled += target - pos.pixels;
        await scroll.animateTo(target, duration: const Duration(milliseconds: 650), curve: Curves.easeOut);
      }
      if (!scroll.hasClients) break;
      travelled += scroll.position.pixels;
      await scroll.animateTo(0, duration: const Duration(seconds: 3), curve: Curves.easeInOut);
    }
    debugPrint('PERF_PROBE travelled=${travelled.round()}px max=${scroll.hasClients ? scroll.position.maxScrollExtent.round() : -1}');
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    String stats(List<int> v) {
      if (v.isEmpty) return 'n/a';
      final s = [...v]..sort();
      double ms(int us) => us / 1000;
      final avg = v.reduce((a, b) => a + b) / v.length / 1000;
      return 'avg ${avg.toStringAsFixed(1)}ms p90 ${ms(s[(s.length * .9).floor()]).toStringAsFixed(1)}ms '
          'p99 ${ms(s[(s.length * .99).floor().clamp(0, s.length - 1)]).toStringAsFixed(1)}ms max ${ms(s.last).toStringAsFixed(1)}ms';
    }

    final hz = Perf._refreshRate();
    final budget = 1e6 / hz;
    var janky = 0;
    for (var i = 0; i < build.length; i++) {
      if (build[i] > budget || raster[i] > budget) janky++;
    }
    debugPrint('PERF_PROBE[$screen] frames=${build.length} hz=${hz.toStringAsFixed(0)} '
        'janky=${(100 * janky / (build.isEmpty ? 1 : build.length)).toStringAsFixed(1)}%');
    debugPrint('PERF_PROBE build  ${stats(build)}');
    debugPrint('PERF_PROBE raster ${stats(raster)}');
  }
}
