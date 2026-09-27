import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibes/app/app.dart';
import 'package:vibes/core/notifications/firebase_placeholder.dart'
    as notifications;
import 'package:vibes/core/utils/data_saver.dart';
import 'package:vibes/core/utils/error_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  ErrorGuard.init();
  PaintingBinding.instance.imageCache.maximumSize = 180;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;
  unawaited(DataSaver.warm());
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.cairo(),
      GoogleFonts.montserrat(),
    ]);
  } catch (_) {}
  await notifications.init();

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
