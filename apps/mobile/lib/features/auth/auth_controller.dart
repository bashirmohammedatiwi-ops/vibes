import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/app_restart.dart';
import '../../core/i18n/i18n.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/data_saver.dart';
import '../../core/utils/device_id.dart';
import '../../shared/models/models.dart';

/// ═══════════════════════════════════════════════════════════
/// المصادقة — جلسة واعية بالدور (زبون / مزوّد / فريق)
/// ═══════════════════════════════════════════════════════════

class AuthState {
  const AuthState({this.loggedIn = false, this.ready = false, this.user});

  final bool loggedIn;
  final bool ready;
  final User? user;

  bool get isProvider => user?.isProvider ?? false;
  bool get isStaff => user?.isStaff ?? false;

  AuthState copyWith({bool? loggedIn, bool? ready, User? user}) => AuthState(
    loggedIn: loggedIn ?? this.loggedIn,
    ready: ready ?? this.ready,
    user: user ?? this.user,
  );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._client, this._tokens) : super(const AuthState()) {
    sessionExpiredSignal.addListener(_onSessionExpired);
    _restore();
  }

  @override
  void dispose() {
    sessionExpiredSignal.removeListener(_onSessionExpired);
    super.dispose();
  }

  /// رفض الخادم رمز التحديث نهائياً — خروج نظيف (يظهر زر تسجيل الدخول)
  /// بدل بقاء الواجهة «مسجّلة» وكل الطلبات تعود Unauthorized.
  Future<void> _onSessionExpired() async {
    if (!state.loggedIn) return;
    await _cacheUser(null);
    if (mounted) state = const AuthState(ready: true);
  }

  final ApiClient _client;
  final TokenStorage _tokens;

  Future<void> _restore() async {
    final token = await _tokens.readAccess();
    if (token == null) {
      state = const AuthState(ready: true);
      return;
    }
    // دخول فوري من الملف المحفوظ — لا ننتظر الشبكة على شاشة البداية
    // (شبكة بطيئة/تجديد توكن قد يعلّق الإقلاع)، ثم نحدّث في الخلفية.
    final cached = await _readCachedUser();
    if (cached != null) {
      state = AuthState(loggedIn: true, ready: true, user: cached);
    }
    // استرجاع الملف إن أمكن — الفشل لا يبطل الجلسة
    try {
      final me = await _client.get('/api/users/me');
      final user = User.fromJson(me as Map<String, dynamic>);
      state = AuthState(loggedIn: true, ready: true, user: user);
      await _cacheUser(user);
      await _registerDevice();
    } catch (_) {
      final stillHasAccess = await _tokens.readAccess();
      if (stillHasAccess == null || stillHasAccess.isEmpty) {
        state = const AuthState(ready: true);
        return;
      }
      state = AuthState(
        loggedIn: true,
        ready: true,
        user: await _readCachedUser(),
      );
    }
  }

  Future<User?> _readCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_user');
      if (raw == null || raw.isEmpty) return null;
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(User? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove('cached_user');
      return;
    }
    await prefs.setString('cached_user', jsonEncode(user.toJson()));
  }

  Future<bool> hasPin(String phone) async {
    final data = await _client.post(
      '/api/auth/pin/lookup',
      body: {'phone': phone},
    );
    return data is Map && data['hasPin'] == true;
  }

  Future<void> loginWithPin(String phone, String pin) async {
    final data =
        await _client.post('/api/auth/pin', body: {'phone': phone, 'pin': pin})
            as Map<String, dynamic>;

    await _tokens.saveTokens(
      access: data['accessToken'] as String,
      refresh: (data['refreshToken'] as String?) ?? '',
    );

    final user = data['user'] is Map<String, dynamic>
        ? User.fromJson(data['user'] as Map<String, dynamic>)
        : null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);

    state = AuthState(loggedIn: true, ready: true, user: user);
    await _cacheUser(user);
    await _registerDevice();
  }

  Future<void> _registerDevice() async {
    try {
      final token = await diagnosticDeviceId();
      await _client.post(
        '/api/devices',
        body: {
          'token': token,
          'platform': kIsWeb
              ? 'web'
              : (defaultTargetPlatform == TargetPlatform.iOS
                    ? 'ios'
                    : 'android'),
        },
      );
    } catch (_) {}
  }

  Future<void> updateName(String name) async {
    final data = await _client.patch(
      '/api/users/me',
      body: {'name': name.trim()},
    );
    if (data is Map<String, dynamic>) {
      final user = User.fromJson(data);
      state = state.copyWith(user: user);
      await _cacheUser(user);
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await _tokens.readRefresh();
      await _client.post(
        '/api/auth/logout',
        body: {
          if (refresh != null && refresh.isNotEmpty) 'refreshToken': refresh,
        },
      );
    } catch (_) {
      // أفضل جهد — نكمل الخروج محلياً
    }
    await _tokens.clear();
    await _cacheUser(null);
    state = const AuthState(ready: true);
  }

  /// حذف الحساب (متطلب App Store و Google Play).
  /// الزبون: حذف فوري ثم خروج محلي — يرجع null.
  /// صاحب المكان: يُسجَّل طلب حذف لدى الدعم — يرجع رسالة توضيحية ويبقى مسجّلاً.
  Future<String?> deleteAccount() async {
    final res = await _client.delete('/api/users/me');
    if (res is Map && res['requested'] == true) {
      return res['message']?.toString() ?? 'استلمنا طلب حذف حسابك'.tr;
    }
    await _tokens.clear();
    await _cacheUser(null);
    state = const AuthState(ready: true);
    return null;
  }

  Future<void> refreshMe() async {
    try {
      final me = await _client.get('/api/users/me');
      if (me is Map<String, dynamic>) {
        final user = User.fromJson(me);
        state = state.copyWith(user: user);
        await _cacheUser(user);
      }
    } catch (_) {}
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// ═══════════════════════════════════════════════════════════
/// الإعدادات المحلية — الوضع الداكن واللغة
/// ═══════════════════════════════════════════════════════════

class PrefsState {
  const PrefsState({
    this.themeMode = ThemeMode.system,
    this.localeCode = 'ar',
    this.dataSaver = false,
  });
  final ThemeMode themeMode;
  final String localeCode;
  final bool dataSaver;

  PrefsState copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    bool? dataSaver,
  }) => PrefsState(
    themeMode: themeMode ?? this.themeMode,
    localeCode: localeCode ?? this.localeCode,
    dataSaver: dataSaver ?? this.dataSaver,
  );
}

class PrefsController extends StateNotifier<PrefsState> {
  PrefsController() : super(PrefsState(localeCode: I18n.locale)) {
    _load();
  }

  static ThemeMode _modeFrom(SharedPreferences prefs) {
    final saved = prefs.getString('themeMode');
    if (saved != null) {
      return ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
    // المستخدم الذي اختار سابقاً عبر المفتاح القديم يبقى على اختياره
    final legacy = prefs.getBool('darkMode');
    if (legacy == null) return ThemeMode.system;
    return legacy ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PrefsState(
      themeMode: _modeFrom(prefs),
      localeCode: I18n.locale,
      dataSaver: prefs.getBool('dataSaver') ?? false,
    );
    DataSaver.forced = state.dataSaver;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  /// يحفظ اللغة ويعيد تشغيل الواجهة: كل البيانات تُجلب باللغة الجديدة.
  Future<void> setLocale(String code) async {
    if (code == I18n.locale) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    I18n.locale = code;
    AppRestart.trigger();
  }

  Future<void> setDataSaver(bool value) async {
    DataSaver.forced = value;
    state = state.copyWith(dataSaver: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dataSaver', value);
  }
}

final prefsControllerProvider =
    StateNotifierProvider<PrefsController, PrefsState>(
      (ref) => PrefsController(),
    );

/// إعدادات المنصة العامة (أوقات الشفت الافتراضية، الدفع...)
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/settings');
  return AppSettings.fromJson(data as Map<String, dynamic>);
});
