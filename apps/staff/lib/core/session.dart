import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

class Session {
  static String? token;
  static String? refreshToken;
  static Map<String, dynamic> me = {};
  static String deviceId = 'staff-device';
  static void Function()? onUnauthorized;
  static DateTime? _lastKeepAlive;
  static Future<bool>? _refreshInFlight;

  static List<String> get permissions =>
      (me['permissions'] as List<dynamic>? ?? []).map((e) => '$e').toList();

  static bool can(String code) => permissions.contains(code);

  static String get displayName => me['displayName']?.toString() ?? 'المكتب';

  static String get presenceState => me['presenceState']?.toString() ?? 'OFFLINE';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('staff_token');
    refreshToken = prefs.getString('staff_refresh');
    deviceId = prefs.getString('device_id') ?? 'staff-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('device_id', deviceId);
  }

  static Future<void> saveTokens({required String access, required String refresh}) async {
    token = access;
    refreshToken = refresh;
    _lastKeepAlive = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_token', access);
    await prefs.setString('staff_refresh', refresh);
  }

  /// @deprecated استخدم saveTokens
  static Future<void> saveToken(String value) async {
    await saveTokens(access: value, refresh: refreshToken ?? '');
  }

  /// تحديث access عبر refresh — يُستخدم من Api عند 401
  /// طلب واحد فقط في نفس الوقت؛ الباقي ينتظر النتيجة.
  static Future<bool> refreshAccess() async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _refreshAccessOnce().whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  static Future<bool> _refreshAccessOnce() async {
    final refresh = refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$apiBase/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      // Nest POST غالباً يرجع 201 وليس 200 فقط
      if (res.statusCode < 200 || res.statusCode >= 300) {
        await clear(notify: true);
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final access = data['accessToken'] as String?;
      if (access == null || access.isEmpty) {
        await clear(notify: true);
        return false;
      }
      await saveTokens(
        access: access,
        refresh: (data['refreshToken'] as String?) ?? refresh,
      );
      return true;
    } catch (_) {
      await clear(notify: true);
      return false;
    }
  }

  /// تجديد وقائي قبل انتهاء access (كل ~10 دقائق أثناء العمل)
  static Future<void> keepAlive() async {
    if (refreshToken == null || refreshToken!.isEmpty) return;
    final now = DateTime.now();
    if (_lastKeepAlive != null && now.difference(_lastKeepAlive!) < const Duration(minutes: 10)) {
      return;
    }
    await refreshAccess();
  }

  static void applyMe(Map<String, dynamic> data) {
    me = data;
  }

  static Future<void> clear({bool notify = false}) async {
    final wasIn = token != null || (refreshToken != null && refreshToken!.isNotEmpty);
    token = null;
    refreshToken = null;
    me = {};
    _lastKeepAlive = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staff_token');
    await prefs.remove('staff_refresh');
    if (notify && wasIn) onUnauthorized?.call();
  }
}
