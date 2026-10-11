import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين آمن للجلسة — SecureStorage على الأجهزة،
/// وعلى الويب SharedPreferences (بيانات المتصفح محلية أصلاً).
///
/// ثلاث حمايات ضد «Unauthorized» العشوائي:
///  1. نسخة في الذاكرة: لا نقرأ الـ Keychain مع كل طلب — قراءته قد تفشل
///     على iOS والهاتف مقفل أو التطبيق في الخلفية، فيُرسل الطلب بلا رمز.
///  2. إتاحة «بعد أول فتح قفل» على iOS: الرموز مقروءة في الخلفية أيضاً.
///  3. تثبيت جديد: الـ Keychain على iOS يبقى بعد حذف التطبيق، فنمسح
///     الرموز القديمة (المنتهية على الخادم) عند أول تشغيل بعد إعادة التثبيت.
class TokenStorage {
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _installMarker = 'session_install_marker';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  String? _accessCache;
  String? _refreshCache;
  Future<void>? _ready;

  Future<void> _ensureLoaded() => _ready ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      _accessCache = prefs.getString(_access);
      _refreshCache = prefs.getString(_refresh);
      return;
    }
    // تثبيت جديد = تفضيلات فارغة. التحديث العادي يُبقي «onboarded» أو
    // المستخدم المخزّن، فلا نُخرج المستخدمين الحاليين.
    final freshInstall =
        !prefs.containsKey(_installMarker) &&
        !prefs.containsKey('onboarded') &&
        !prefs.containsKey('cached_user');
    if (freshInstall) {
      try {
        await _storage.delete(key: _access);
        await _storage.delete(key: _refresh);
      } catch (_) {}
    }
    await prefs.setBool(_installMarker, true);
    try {
      _accessCache = await _readMigrating(_access);
      _refreshCache = await _readMigrating(_refresh);
    } catch (_) {
      // الـ Keychain غير متاح لحظياً — نعيد المحاولة في الطلب القادم
      _ready = null;
    }
  }

  /// يقرأ القيمة ويعيد كتابتها لتأخذ إعداد الإتاحة الجديد على iOS.
  Future<String?> _readMigrating(String key) async {
    final value = await _storage.read(key: key);
    if (value != null &&
        value.isNotEmpty &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } catch (_) {}
    }
    return value;
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessCache = access;
    _refreshCache = refresh;
    _ready ??= Future.value();
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_access, access);
      await prefs.setString(_refresh, refresh);
      return;
    }
    try {
      await _storage.write(key: _access, value: access);
      await _storage.write(key: _refresh, value: refresh);
    } catch (_) {
      // تبقى الجلسة صالحة في الذاكرة
    }
  }

  Future<String?> readAccess() async {
    await _ensureLoaded();
    return _accessCache;
  }

  Future<String?> readRefresh() async {
    await _ensureLoaded();
    return _refreshCache;
  }

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_access);
      await prefs.remove(_refresh);
      return;
    }
    try {
      await _storage.delete(key: _access);
      await _storage.delete(key: _refresh);
    } catch (_) {}
  }
}
