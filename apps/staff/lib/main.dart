import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/session.dart';
import 'core/staff_notifications.dart';
import 'core/theme.dart';
import 'features/gate.dart';
import 'features/login.dart';

final staffNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // خطوات الإقلاع محمية: فشل أيٍّ منها لا يمنع فتح التطبيق أبداً
  try {
    await initializeDateFormatting('ar');
  } catch (_) {}
  try {
    await StaffNotifications.init().timeout(const Duration(seconds: 4));
  } catch (_) {}
  Session.onUnauthorized = () {
    staffNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  runApp(const StaffApp());
}

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: staffNavigatorKey,
      title: 'VIBES مكتب',
      debugShowCheckedModeBanner: false,
      theme: buildStaffTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      // منتقيات التاريخ والوقت وكل نصوص Material بالعربية
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox(),
      ),
      home: const Gate(),
    );
  }
}
