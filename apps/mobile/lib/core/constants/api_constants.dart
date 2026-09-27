import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'http://localhost:3000';

    // USB: `adb reverse tcp:3000 tcp:3000` then device loopback hits the host.
    // Works on a physical phone (unlike 10.0.2.2, which is emulator-only).
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:3000';
    }

    return 'http://localhost:3000';
  }
}
