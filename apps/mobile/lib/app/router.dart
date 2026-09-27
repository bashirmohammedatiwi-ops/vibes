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
import '../features/booking/booking_invoice_screen.dart';
import '../features/booking/bookings_screen.dart';
import '../features/discovery/reels_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/property/property_detail_screen.dart';
import '../features/search/search_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/support/support_screen.dart';
import '../features/chat/conversations_screen.dart';
import '../features/chat/call_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/offers/offers_screen.dart';
import '../features/offers/coupons_screen.dart';
import '../features/social/experiences_screen.dart';
import '../features/social/collection_detail_screen.dart';
import '../features/social/following_screen.dart';
import '../features/booking/invoices_screen.dart';
import '../features/map/map_screen.dart';
import '../features/compare/compare_feature.dart';
import '../features/provider/provider_shell.dart';
import '../features/provider/provider_add_property_screen.dart';
import '../features/provider/provider_requests_screen.dart';
import '../features/provider/provider_profile_screen.dart';
import '../features/provider/owner_gate_screen.dart';
import '../features/concierge/nadeem_screen.dart';
import '../shared/widgets/app_shell.dart';

/// التصفح الحر. الدخول يُطلب عند إتمام الحجز أو من الملف، أو للمسارات الخاصة.
bool _guestPath(String location) {
  const open = {
    '/',
    '/onboarding',
    '/login',
    '/home',
    '/explore',
    '/bookings',
    '/profile',
    '/search',
    '/nadeem',
    '/support',
    '/offers',
    '/coupons',
    '/experiences',
    '/map',
    '/compare',
  };
  if (open.contains(location)) return true;
  const prefixes = [
    '/property/',
    '/book/',
    '/offers/',
    '/experiences/',
    '/providers/',
  ];
  return prefixes.any(location.startsWith);
}

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
            position:
                Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: VibesMotion.curve),
                ),
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

      if (!auth.ready) {
        return location == '/' ? null : '/';
      }

      if (!auth.loggedIn) {
        if (_guestPath(location)) return null;
        final next = Uri.encodeComponent(state.uri.toString());
        return '/login?next=$next';
      }

      if (location == '/login' || location == '/onboarding') {
        return auth.isProvider ? '/provider' : '/home';
      }

      // المزوّد يعيش في نافذته — إلا المسارات المشتركة
      const sharedWithProvider = [
        '/property',
        '/book',
        '/booking',
        '/profile',
        '/chat',
        '/conversations',
        '/notifications',
        '/offers',
        '/collections',
        '/invoices',
        '/coupons',
        '/following',
        '/providers',
        '/experiences',
        '/nadeem',
      ];
      if (auth.isProvider && location.startsWith('/owner')) {
        return '/provider';
      }
      if (auth.isProvider &&
          !location.startsWith('/provider') &&
          !sharedWithProvider.any(location.startsWith)) {
        return '/provider';
      }
      if (!auth.isProvider && location.startsWith('/provider')) {
        return '/owner';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // قشرة الزبون: 4 تبويبات محفوظة الحالة
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ReelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const BookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // مسارات حرة للزبون
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: SearchScreen(
            initialType: state.uri.queryParameters['type'],
            initialProvince: state.uri.queryParameters['province'],
          ),
        ),
      ),
      GoRoute(
        path: '/nadeem',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const NadeemScreen()),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) =>
            PropertyDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) => BookingFlowScreen(
          propertyId: state.pathParameters['id']!,
          initialDate: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/booking-success',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: BookingSuccessScreen(
            bookingId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (context, state) =>
            BookingDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/booking/:id/invoice',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: BookingInvoiceScreen(bookingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const SupportScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/conversations',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const ConversationsScreen()),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: ChatScreen(
            conversationId: state.pathParameters['id']!,
            incomingCallId: state.uri.queryParameters['call'],
          ),
        ),
      ),
      GoRoute(
        path: '/call',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic>) {
            return const SizedBox.shrink();
          }
          return CallScreen(payload: extra);
        },
      ),
      GoRoute(
        path: '/offers',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const OffersScreen()),
      ),
      GoRoute(
        path: '/offers/:id',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: OffersScreen(highlightId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/coupons',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const CouponsScreen()),
      ),
      GoRoute(
        path: '/following',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const FollowingScreen()),
      ),
      GoRoute(
        path: '/invoices',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const InvoicesScreen()),
      ),
      GoRoute(
        path: '/collections/:id',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: CollectionDetailScreen(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/experiences',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const ExperiencesScreen()),
      ),
      GoRoute(
        path: '/experiences/:id',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: ExperiencesScreen(highlightId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/providers/:id',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: ProviderProfileScreen(
            providerId: state.pathParameters['id']!,
          ),
        ),
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
      GoRoute(
        path: '/owner',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const OwnerGateScreen()),
      ),

      // نافذة المزوّد
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ProviderShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider',
                builder: (context, state) => const ProviderHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/bookings',
                builder: (context, state) => const ProviderBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/calendar',
                builder: (context, state) => const ProviderCalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/properties',
                builder: (context, state) => const ProviderPropertiesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/provider/earnings',
        builder: (context, state) => const ProviderEarningsScreen(),
      ),
      GoRoute(
        path: '/provider/requests',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: const ProviderRequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/provider/properties/new',
        builder: (context, state) => const ProviderAddPropertyScreen(),
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
