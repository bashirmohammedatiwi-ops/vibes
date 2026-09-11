import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
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
      state = AuthState(
        loggedIn: true,
        ready: true,
        user: User.fromJson(me as Map<String, dynamic>),
      );
    } catch (_) {
      state = const AuthState(loggedIn: true, ready: true);
    }
  }

  Future<void> sendOtp(String phone) => _client.post(
        '/api/auth/otp/send',
        body: {'phone': phone},
      );

  Future<void> verifyOtp(String phone, String code) async {
    final data = await _client.post(
      '/api/auth/otp/verify',
      body: {'phone': phone, 'code': code},
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
  }

  Future<void> logout() async {
    try {
      await _client.post('/api/auth/logout');
    } catch (_) {
      // أفضل جهد — نكمل الخروج محلياً
    }
    await _tokens.clear();
    state = const AuthState(ready: true);
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
  const PrefsState({this.darkMode = false, this.localeCode = 'ar'});
  final bool darkMode;
  final String localeCode;

  PrefsState copyWith({bool? darkMode, String? localeCode}) => PrefsState(
        darkMode: darkMode ?? this.darkMode,
        localeCode: localeCode ?? this.localeCode,
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
    );
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
