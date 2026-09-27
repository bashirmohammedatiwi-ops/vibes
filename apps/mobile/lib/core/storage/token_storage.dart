import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين آمن للجلسة — SecureStorage على الأجهزة،
/// وعلى الويب SharedPreferences (بيانات المتصفح محلية أصلاً).
class TokenStorage {
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_access, access);
      await prefs.setString(_refresh, refresh);
      return;
    }
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<String?> readAccess() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_access);
    }
    return _storage.read(key: _access);
  }

  Future<String?> readRefresh() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refresh);
    }
    return _storage.read(key: _refresh);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_access);
      await prefs.remove(_refresh);
      return;
    }
    await _storage.deleteAll();
  }
}
