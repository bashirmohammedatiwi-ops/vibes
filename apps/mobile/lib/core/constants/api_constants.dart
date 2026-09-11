import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://localhost:3000',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://10.0.2.2:3000',
      );
    }
    return const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:3000',
    );
  }
}
