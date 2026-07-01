import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_controller.dart';
import '../features/landing/landing_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/emergency_contacts_screen.dart';
import '../features/main_layout.dart';
import '../features/caregivers/caregivers_screen.dart';
import '../features/join/join_caregiver_screen.dart';
import '../features/bookings/booking_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/bookings/booking_details_screen.dart';
import '../features/bookings/change_caregiver_screen.dart';
import '../features/payment/screens/transactions_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/auth/email_verification_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/legal/legal_policy_screen.dart';
import '../features/legal/contact_us_screen.dart';
import '../features/legal/about_us_screen.dart';
import '../features/legal/policy_data.dart';
import '../features/notifications/notifications_screen.dart';
// Partner imports
import '../features/partner/partner_providers.dart';
import '../features/partner/partner_main_layout.dart';
import '../features/partner/partner_dashboard_screen.dart';
import '../features/partner/partner_bookings_screen.dart';
import '../features/partner/partner_profile_screen.dart';
import '../features/partner/partner_registration_screen.dart';
import '../features/partner/partner_booking_detail_screen.dart';
import '../features/partner/availability/availability_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  bool _disposed = false;

  void refresh() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);

  // Keep a single router instance alive. Trigger redirect re-evaluation via
  // refreshListenable instead of rebuilding the whole router.
  ref.listen(authStateProvider, (_, __) {
    refreshNotifier.refresh();
  });
  ref.listen(userModelProvider, (_, __) {
    refreshNotifier.refresh();
  });
  ref.listen(currentPersonnelProvider, (_, __) {
    refreshNotifier.refresh();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authStateAsync = ref.read(authStateProvider);
      if (authStateAsync.isLoading) return null;

      final isAuth = authStateAsync.value != null;
      final inAuthScreen = state.uri.path == '/auth/login';
      final currentPath = state.uri.path;
      final isPublicRoute = [
        '/',
        '/splash',
        '/caregivers',
        '/join-as-caregiver',
        '/auth/verify-email',
        '/contact',
        '/about',
        '/legal/privacy',
        '/legal/terms',
        '/legal/refunds',
        '/legal/data-collection',
        '/legal/account-deletion',
        '/legal/shipping',
      ].contains(currentPath);

      if (!isAuth && !isPublicRoute && !inAuthScreen) {
        return '/auth/login';
      }

      if (!isAuth) {
        return null;
      }

      final userModelAsync = ref.read(userModelProvider);
      if (userModelAsync.isLoading) return null;
      final role = userModelAsync.value?.role ?? 'family';

      if (kDebugMode) {
        debugPrint('[ROUTER] path=$currentPath isAuth=$isAuth role=$role');
      }

      // 1. Enforce email verification for all auth-gated routes
      if (isAuth &&
          !authStateAsync.value!.emailVerified &&
          currentPath != '/auth/verify-email' &&
          !isPublicRoute) {
        return '/auth/verify-email';
      }

      // 2. Prevent verified users from seeing the verification screen
      if (isAuth &&
          authStateAsync.value!.emailVerified &&
          currentPath == '/auth/verify-email') {
        return '/';
      }

      // 3. Force profile setup for family users if incomplete (only if verified)
      // Use `?? false` so that null user doc (still loading / not created) is treated as incomplete.
      if (isAuth &&
          authStateAsync.value!.emailVerified &&
          role == 'family' &&
          !(userModelAsync.value?.isProfileComplete ?? false) &&
          currentPath != '/auth/setup-profile' &&
          !inAuthScreen) {
        return '/auth/setup-profile';
      }

      // 4. Redirect caregivers to partner routes & enforce profile completion
      if (isAuth &&
          authStateAsync.value!.emailVerified &&
          role == 'caregiver') {
        final personnelAsync = ref.read(currentPersonnelProvider);
        final isPartnerRoute = currentPath.startsWith('/partner');

        debugPrint(
            '[ROUTER] Caregiver detected. isPartnerRoute=$isPartnerRoute');

        // If personnel data is still loading, don't redirect yet
        if (personnelAsync.isLoading) return null;

        final hasPersonnelRecord = personnelAsync.value != null;
        final isPersonnelProfileComplete =
            personnelAsync.value?.isProfileComplete ?? false;

        // If caregiver has no personnel record OR profile is incomplete, send to registration
        if ((!hasPersonnelRecord || !isPersonnelProfileComplete) &&
            currentPath != '/partner/register') {
          debugPrint('[ROUTER] Caregiver profile incomplete');
          return '/partner/register';
        }

        // If caregiver has complete personnel record but is NOT on a partner route, redirect them
        if (hasPersonnelRecord &&
            isPersonnelProfileComplete &&
            !isPartnerRoute) {
          debugPrint('[ROUTER] Caregiver redirected to /partner/dashboard');
          return '/partner/dashboard';
        }
      }

      // 5. Handle initial redirects from login screen
      if (isAuth && inAuthScreen) {
        final user = authStateAsync.value!;
        if (!user.emailVerified) return '/auth/verify-email';

        if (role == 'family') {
          if (!(userModelAsync.value?.isProfileComplete ?? false)) {
            return '/auth/setup-profile';
          }
          return '/dashboard/family';
        }
        if (role == 'caregiver') {
          final personnelAsync = ref.read(currentPersonnelProvider);
          if (personnelAsync.isLoading) return null;
          final hasPersonnelRecord = personnelAsync.value != null;
          final isPersonnelProfileComplete =
              personnelAsync.value?.isProfileComplete ?? false;
          if (!hasPersonnelRecord || !isPersonnelProfileComplete) {
            return '/partner/register';
          }
          return '/partner/dashboard';
        }
        if (role == 'admin') return '/dashboard/admin';
      }

      // 6. Handle direct /dashboard access
      if (isAuth && state.uri.path == '/dashboard') {
        if (role == 'family') return '/dashboard/family';
        if (role == 'caregiver') return '/partner/dashboard';
        if (role == 'admin') return '/dashboard/admin';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // ── Public routes (no auth required) ──────────
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) {
          final mode =
              state.uri.queryParameters['mode']; // 'signin' or 'signup'
          final role =
              state.uri.queryParameters['role']; // 'family' or 'caregiver'
          return AuthScreen(
            initialMode: mode,
            initialRole: role,
          );
        },
      ),
      GoRoute(
        path: '/caregivers',
        builder: (context, state) => const CaregiversScreen(),
      ),
      GoRoute(
        path: '/join-as-caregiver',
        builder: (context, state) => const JoinCaregiverScreen(),
      ),
      GoRoute(
        path: '/auth/setup-profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactUsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutUsScreen(),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalPolicyScreen(
          title: 'Privacy Policy',
          content: PolicyData.privacyPolicy,
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalPolicyScreen(
          title: 'Terms of Service',
          content: PolicyData.termsAndConditions,
        ),
      ),
      GoRoute(
        path: '/legal/refunds',
        builder: (context, state) => const LegalPolicyScreen(
          title: 'Cancellation & Refunds',
          content: PolicyData.cancellationPolicy,
        ),
      ),
      GoRoute(
        path: '/legal/data-collection',
        builder: (context, state) => const LegalPolicyScreen(
          title: 'Data Collection Policy',
          content: PolicyData.dataCollectionPolicy,
        ),
      ),
      GoRoute(
        path: '/legal/account-deletion',
        builder: (context, state) => const LegalPolicyScreen(
          title: 'Account Deletion',
          content: PolicyData.accountDeletionPolicy,
        ),
      ),
      GoRoute(
        path: '/legal/shipping',
        builder: (context, state) => const LegalPolicyScreen(
          title: 'Shipping & Delivery',
          content: PolicyData.shippingPolicy,
        ),
      ),

      // ── Auth-gated routes ─────────────────────────
      GoRoute(
        path: '/book',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingsScreen(),
      ),
      GoRoute(
        path: '/booking-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final from = state.uri.queryParameters['from'];
          return BookingDetailsScreen(
            bookingId: id,
            cancelOnBack: from == 'book',
          );
        },
      ),
      GoRoute(
        path: '/change-caregiver/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return ChangeCaregiverScreen(bookingId: bookingId);
        },
      ),

      // ── Family/Admin Dashboard shell (post-login) ──────────────
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/dashboard/family',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/dashboard/caregiver',
            redirect: (context, state) => '/partner/dashboard',
          ),
          GoRoute(
            path: '/dashboard/admin',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/emergency-contacts',
            name: 'emergencyContacts',
            builder: (context, state) => const EmergencyContactsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),

      // ── Partner shell (caregiver post-login) ──────────────
      GoRoute(
        path: '/partner/register',
        builder: (context, state) => const PartnerRegistrationScreen(),
      ),
      GoRoute(
        path: '/partner/booking-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PartnerBookingDetailScreen(bookingId: id);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => PartnerMainLayout(child: child),
        routes: [
          GoRoute(
            path: '/partner/dashboard',
            builder: (context, state) => const PartnerDashboardScreen(),
          ),
          GoRoute(
            path: '/partner/bookings',
            builder: (context, state) => const PartnerBookingsScreen(),
          ),
          GoRoute(
            path: '/partner/profile',
            builder: (context, state) => const PartnerProfileScreen(),
          ),
          GoRoute(
            path: '/partner/availability',
            builder: (context, state) => const AvailabilityScreen(),
          ),
          GoRoute(
            path: '/partner/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});
