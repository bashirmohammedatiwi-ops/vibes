import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibes/app/router.dart';
import 'package:vibes/core/theme/app_theme.dart';
import 'package:vibes/core/theme/world_theme.dart';
import 'package:vibes/features/auth/auth_controller.dart';
import 'package:vibes/features/chat/incoming_call.dart';
import 'package:vibes/features/home/home_sections.dart';
import '../core/network/data_healer.dart';

/// سلوك تمرير التطبيق — بلا أشرطة تمرير نظام تشوه الواجهة:
/// لمس مرن (iOS-style stretch) على كل المنصات.
class VibesScrollBehavior extends MaterialScrollBehavior {
  const VibesScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class VibesApp extends ConsumerWidget {
  const VibesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsControllerProvider);
    final router = ref.watch(appRouterProvider);

    // ── العالم الحالي يلوّن الثيم كله — وMaterialApp يحرّك الانتقال ──
    final world = ref.watch(homeSectionProvider);
    // تذكّر آخر عالم — يفتح التطبيق عليه في المرة القادمة
    ref.listen<HomeSection>(homeSectionProvider, (_, next) {
      SharedPreferences.getInstance().then(
        (p) => p.setString('last_world', next.name),
      );
    });
    final palette = WorldPalette.of(world);
    final light = applyWorld(VibesTheme.light(), palette);
    final dark = applyWorld(VibesTheme.dark(), palette);

    // تنشيط مراقب المكالمات الواردة مع بقاء التطبيق حياً
    ref.watch(incomingCallProvider);

    return MaterialApp.router(
      title: 'VIBES',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: prefs.darkMode ? ThemeMode.dark : ThemeMode.light,
      // تبديل فوري للثيم — العناصر البارزة تتحرك بنفسها (AnimatedContainer
      // وأخواتها) فلا يُعاد رسم التطبيق كله مع كل إطار أثناء الانتقال.
      themeAnimationDuration: Duration.zero,
      locale: Locale(prefs.localeCode),
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      scrollBehavior: const VibesScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            // يعيد تحميل أي قسم فشل جلبه (أول فتح، انقطاع شبكة، عودة للتطبيق)
            DataHealer(child: child ?? const SizedBox.shrink()),
            // غطاء المكالمة الواردة فوق أي شاشة — بلا سياق تنقل خاص
            const Positioned.fill(child: IncomingCallSheet()),
          ],
        );
      },
    );
  }
}
