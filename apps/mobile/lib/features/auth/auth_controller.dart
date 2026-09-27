import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _restore();
  }

  final ApiClient _client;
  final TokenStorage _tokens;

  Future<void> _restore() async {
    final token = await _tokens.readAccess();
    if (token == null) {
      state = const AuthState(ready: true);
      return;
    }
    // استرجاع الملف إن أمكن — الفشل لا يبطل الجلسة
    try {
      final me = await _client.get('/api/users/me');
      final user = User.fromJson(me as Map<String, dynamic>);
      state = AuthState(
        loggedIn: true,
        ready: true,
        user: user,
      );
      await _cacheUser(user);
      await _registerDevice();
    } catch (_) {
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
    final data = await _client.post(
      '/api/auth/pin',
      body: {'phone': phone, 'pin': pin},
    ) as Map<String, dynamic>;

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
      await _client.post('/api/devices', body: {
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
      });
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
      await _client.post('/api/auth/logout');
    } catch (_) {
      // أفضل جهد — نكمل الخروج محلياً
    }
    await _tokens.clear();
    await _cacheUser(null);
    state = const AuthState(ready: true);
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

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
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
    this.darkMode = false,
    this.localeCode = 'ar',
    this.dataSaver = false,
  });
  final bool darkMode;
  final String localeCode;
  final bool dataSaver;

  PrefsState copyWith({bool? darkMode, String? localeCode, bool? dataSaver}) =>
      PrefsState(
        darkMode: darkMode ?? this.darkMode,
        localeCode: localeCode ?? this.localeCode,
        dataSaver: dataSaver ?? this.dataSaver,
      );
}

class PrefsController extends StateNotifier<PrefsState> {
  PrefsController() : super(const PrefsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PrefsState(
      darkMode: prefs.getBool('darkMode') ?? false, // الفاتح الدافئ هو الافتراضي
      localeCode: prefs.getString('locale') ?? 'ar',
      dataSaver: prefs.getBool('dataSaver') ?? false,
    );
    DataSaver.forced = state.dataSaver;
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(darkMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  Future<void> setLocale(String code) async {
    state = state.copyWith(localeCode: code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
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
