import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibes/app/router.dart';
import 'package:vibes/core/i18n/i18n.dart';
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

class VibesApp extends ConsumerStatefulWidget {
  const VibesApp({super.key});

  @override
  ConsumerState<VibesApp> createState() => _VibesAppState();
}

class _VibesAppState extends ConsumerState<VibesApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  /// الرموز اللونية تقرأ المظهر مباشرة، فعند تبدّله يُعاد بناء كل الشجرة
  /// مع الحفاظ على حالة الشاشات (بدل مفتاح جديد يعيد التنقل من البداية).
  void _rebuildTree() {
    void walk(Element e) {
      e.markNeedsBuild();
      e.visitChildren(walk);
    }

    if (mounted) (context as Element).visitChildren(walk);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsControllerProvider);
    final router = ref.watch(appRouterProvider);

    final dark = switch (prefs.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    if (dark != Appearance.isDark) {
      Appearance.isDark = dark;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildTree());
    }

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
    final darkTheme = applyWorld(VibesTheme.dark(), palette);

    // تنشيط مراقب المكالمات الواردة مع بقاء التطبيق حياً
    ref.watch(incomingCallProvider);

    return MaterialApp.router(
      title: 'VIBES',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      // تبديل فوري للثيم — العناصر البارزة تتحرك بنفسها (AnimatedContainer
      // وأخواتها) فلا يُعاد رسم التطبيق كله مع كل إطار أثناء الانتقال.
      themeAnimationDuration: Duration.zero,
      locale: Locale(I18n.locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
