import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_controller.dart';
import 'mode_transition_overlay.dart';

/// وضع التجربة: ضيف (تطبيق VIBES) أو مالك (بوابة المزوّد).
enum AppExperienceMode { guest, provider }

const _prefsKey = 'app_experience_mode';
const _lastGuestPathKey = 'app_last_guest_path';

final appModeProvider =
    StateNotifierProvider<AppModeNotifier, AppExperienceMode>(
      (ref) => AppModeNotifier(),
    );

class AppModeNotifier extends StateNotifier<AppExperienceMode> {
  AppModeNotifier() : super(AppExperienceMode.provider);

  var _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == AppExperienceMode.guest.name) {
      state = AppExperienceMode.guest;
    } else if (raw == AppExperienceMode.provider.name) {
      state = AppExperienceMode.provider;
    }
    _loaded = true;
  }

  Future<void> _persist(AppExperienceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> rememberGuestPath(String path) async {
    if (!path.startsWith('/') || path.startsWith('/provider')) return;
    const allowed = ['/home', '/explore', '/bookings', '/profile'];
    if (!allowed.contains(path)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGuestPathKey, path);
  }

  Future<String> lastGuestPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastGuestPathKey) ?? '/home';
  }

  Future<void> setProviderMode() async {
    state = AppExperienceMode.provider;
    await _persist(AppExperienceMode.provider);
  }

  Future<void> setGuestMode() async {
    state = AppExperienceMode.guest;
    await _persist(AppExperienceMode.guest);
  }

  /// بعد تسجيل الخروج — الافتراضي للضيف حتى يعود المزوّد للبوابة عند الدخول.
  Future<void> resetAfterLogout() async {
    state = AppExperienceMode.guest;
    await _persist(AppExperienceMode.guest);
  }

  Future<void> onProviderLogin() async {
    state = AppExperienceMode.provider;
    await _persist(AppExperienceMode.provider);
  }
}

bool providerBrowsingAsGuest(WidgetRef ref) {
  final auth = ref.read(authControllerProvider);
  if (!auth.isProvider) return false;
  return ref.read(appModeProvider) == AppExperienceMode.guest;
}

bool providerBrowsingAsGuestFromRef(Ref ref) {
  final auth = ref.read(authControllerProvider);
  if (!auth.isProvider) return false;
  return ref.read(appModeProvider) == AppExperienceMode.guest;
}

/// انتقال سينمائي بين التطبيقين ثم التوجيه.
Future<void> switchToProviderPortal(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authControllerProvider);
  if (!auth.isProvider) {
    context.push('/owner');
    return;
  }
  if (!context.mounted) return;
  await showModeTransition(context, toProvider: true);
  if (!context.mounted) return;
  await ref.read(appModeProvider.notifier).setProviderMode();
  if (!context.mounted) return;
  context.go('/provider');
}

Future<void> switchToGuestExperience(
  BuildContext context,
  WidgetRef ref, {
  String? guestPath,
}) async {
  final auth = ref.read(authControllerProvider);
  if (!auth.isProvider) {
    context.go(guestPath ?? '/home');
    return;
  }
  final path =
      guestPath ?? await ref.read(appModeProvider.notifier).lastGuestPath();
  if (!context.mounted) return;
  await showModeTransition(context, toProvider: false);
  if (!context.mounted) return;
  await ref.read(appModeProvider.notifier).setGuestMode();
  if (!context.mounted) return;
  context.go(path);
}
