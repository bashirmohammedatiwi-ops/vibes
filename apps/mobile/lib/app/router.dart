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
import '../features/provider/provider_ui.dart' show OwnerTheme;
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
import '../features/provider/provider_booking_detail_screen.dart';
import '../features/provider/provider_account_screen.dart';
import '../features/provider/provider_requests_screen.dart';
import '../features/provider/provider_profile_screen.dart';
import '../features/provider/owner_gate_screen.dart';
import '../features/concierge/nadeem_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../shared/widgets/property_world_theme.dart';
import '../core/app_mode/app_mode_controller.dart';

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
/// (مدد قصيرة محسّنة: استجابة فورية مع بقاء الإحساس الفاخر)
CustomTransitionPage<T> _fadeSlide<T>({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
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
  ref.listen<AppExperienceMode>(appModeProvider, (_, __) {});

  return GoRouter(
    initialLocation: '/',
    // رابط غير معروف (إشعار قديم مثلاً) — صفحة بهوية التطبيق بدل صفحة المطوّرين
    errorBuilder: (context, state) => const _RouteNotFound(),
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
        if (!auth.isProvider) return '/home';
        return providerBrowsingAsGuestFromRef(ref) ? '/home' : '/provider';
      }

      final browsingAsGuest =
          auth.isProvider && providerBrowsingAsGuestFromRef(ref);

      // المزوّد في وضع الضيف — يتصفح التطبيق العادي بحرية
      if (browsingAsGuest) {
        const guestShell = ['/home', '/explore', '/bookings', '/profile'];
        if (location.startsWith('/provider')) {
          return guestShell.contains(location) ? null : '/home';
        }
        if (location.startsWith('/owner')) {
          return '/home';
        }
        return null;
      }

      // المزوّد في بوابة المالك — المسارات المشتركة فقط خارج /provider
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
        '/support',
        '/search',
        '/map',
        '/compare',
        '/favorites',
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
            initialWinter: state.uri.queryParameters['winter'] == 'true',
            initialIndoorPool:
                state.uri.queryParameters['indoorPool'] == 'true',
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
        builder: (context, state) => PropertyWorldTheme(
          propertyId: state.pathParameters['id']!,
          child: PropertyDetailScreen(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) => PropertyWorldTheme(
          propertyId: state.pathParameters['id']!,
          child: BookingFlowScreen(
            propertyId: state.pathParameters['id']!,
            initialDate: state.uri.queryParameters['date'],
            initialShift: state.uri.queryParameters['shift'],
          ),
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
            payHintBookingId: state.uri.queryParameters['pay'],
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
          child: ProviderProfileScreen(providerId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const FavoritesScreen()),
      ),
      GoRoute(
        path: '/map',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: MapScreen(
            initialType: state.uri.queryParameters['type'],
            initialPropertyId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/compare',
        pageBuilder: (context, state) =>
            _fadeSlide(state: state, child: const CompareScreen()),
      ),
      GoRoute(
        path: '/owner',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: const OwnerTheme(child: OwnerGateScreen()),
        ),
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
        path: '/provider/account',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: const OwnerTheme(child: ProviderAccountScreen()),
        ),
      ),
      GoRoute(
        path: '/provider/bookings/:id',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: OwnerTheme(
            child: ProviderBookingDetailScreen(
              bookingId: state.pathParameters['id']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/provider/earnings',
        builder: (context, state) =>
            const OwnerTheme(child: ProviderEarningsScreen()),
      ),
      GoRoute(
        path: '/provider/requests',
        pageBuilder: (context, state) => _fadeSlide(
          state: state,
          child: const OwnerTheme(child: ProviderRequestsScreen()),
        ),
      ),
      GoRoute(path: '/provider/properties/new', redirect: (_, __) => '/owner'),
      GoRoute(
        path: '/provider/properties/:id/pricing',
        builder: (context, state) => OwnerTheme(
          child: ProviderPricingScreen(propertyId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/provider/properties/:id/media',
        builder: (context, state) => OwnerTheme(
          child: ProviderMediaScreen(propertyId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/provider/properties/:id/availability',
        builder: (context, state) => OwnerTheme(
          child: ProviderAvailabilityScreen(
            propertyId: state.pathParameters['id']!,
          ),
        ),
      ),
    ],
  );
});

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.explore_off_outlined,
                  size: 56,
                  color: Color(0xFFC89844),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الصفحة غير متاحة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ربما نُقل المحتوى أو انتهى الرابط.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF565D68),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text(
                    'العودة للرئيسية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
