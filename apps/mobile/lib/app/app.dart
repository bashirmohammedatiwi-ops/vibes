import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibes/app/router.dart';
import 'package:vibes/core/theme/app_theme.dart';
import 'package:vibes/features/auth/auth_controller.dart';

class VibesApp extends ConsumerWidget {
  const VibesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'VIBEES',
      debugShowCheckedModeBanner: false,
      theme: VibesTheme.light(),
      darkTheme: VibesTheme.dark(),
      themeMode: prefs.darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(prefs.localeCode),
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
    );
  }
}
