import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/booking/booking_flow_screen.dart';
import '../features/booking/booking_success_screen.dart';
import '../features/booking/booking_detail_screen.dart';
import '../features/booking/bookings_screen.dart';
import '../features/discovery/reels_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/property/property_detail_screen.dart';
import '../features/search/search_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/map/map_screen.dart';
import '../features/compare/compare_feature.dart';
import '../features/provider/provider_shell.dart';
import '../shared/widgets/app_shell.dart';
/// انتقالات موحدة: قياسي fade+slide، تفاصيل hero+fade
CustomTransitionPage<T> _fadeSlide<T>({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: VibesMotion.slow,
    reverseTransitionDuration: VibesMotion.base,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: VibesMotion.curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: VibesMotion.curve)),
        child: child,
      ),
    ),
  );
}

/// مزوّد الراوتر في نطاق Riverpod
final appRouterProvider = Provider<GoRouter>((ref) {
  // متابعة حالة المصادقة لإعادة التوجيه تلقائياً
  ref.listen<AuthState>(authControllerProvider, (_, __) {});

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // شاشات حرة بلا حارس
      const free = ['/', '/onboarding', '/login'];
      if (free.contains(location)) return null;

      if (!auth.ready) return '/';

      if (!auth.loggedIn) return '/login';

      // المزوّد يعيش في نافذته — إلا المسارات المشتركة
      const sharedWithProvider = ['/property', '/book', '/profile'];
      if (auth.isProvider &&
          !location.startsWith('/provider') &&
          !sharedWithProvider.any(location.startsWith)) {
        return '/provider';
      }
      if (!auth.isProvider && location.startsWith('/provider')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
          path: '/login', builder: (context, state) => const LoginScreen()),

      // قشرة الزبون: 4 تبويبات محفوظة الحالة
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ReelsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const BookingsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // مسارات حرة للزبون
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const SearchScreen()),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) =>
            PropertyDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) =>
            BookingFlowScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/booking-success',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const BookingSuccessScreen()),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (context, state) =>
            BookingDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const FavoritesScreen()),
      ),
      GoRoute(
        path: '/map',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const MapScreen()),
      ),
      GoRoute(
        path: '/compare',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const CompareScreen()),
      ),

      // نافذة المزوّد
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ProviderShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/provider',
              builder: (context, state) => const ProviderHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/provider/bookings',
              builder: (context, state) => const ProviderBookingsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/provider/calendar',
              builder: (context, state) => const ProviderCalendarScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/provider/properties',
              builder: (context, state) => const ProviderPropertiesScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/provider/earnings',
        builder: (context, state) => const ProviderEarningsScreen(),
      ),
      GoRoute(
        path: '/provider/properties/:id/pricing',
        builder: (context, state) =>
            ProviderPricingScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/provider/properties/:id/media',
        builder: (context, state) =>
            ProviderMediaScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/provider/properties/:id/availability',
        builder: (context, state) =>
            ProviderAvailabilityScreen(propertyId: state.pathParameters['id']!),
      ),
    ],
  );
});
