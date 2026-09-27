import 'package:flutter/foundation.dart';

class ApiConstants {
  static const server = 'http://187.127.88.146:6001';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:3000';
    return server;
  }
}
