import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'core/theme/admin_theme.dart';
import 'core/services/admin_service.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/auth/initial_password_reset_screen.dart';
import 'features/administrators/administrators_screen.dart';
import 'features/audit_logs/audit_logs_screen.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/caregivers/caregivers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/pricing/pricing_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/users/users_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

final _router = GoRouter(
  initialLocation: '/login',
  refreshListenable:
      GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isLogin = state.uri.path == '/login';
    final isChangePassword = state.uri.path == '/change-password';

    if (user == null && !isLogin) return '/login';
    if (user == null && isChangePassword) return '/login';

    if (user != null) {
      final requiresPasswordChange =
          await AdminService.instance.isPasswordChangeRequired();
      if (requiresPasswordChange && !isChangePassword) {
        return '/change-password';
      }
      if (!requiresPasswordChange && isChangePassword) {
        return '/dashboard';
      }
      if (isLogin) return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),
    GoRoute(
      path: '/change-password',
      builder: (_, __) => const InitialPasswordResetScreen(),
    ),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
    GoRoute(path: '/audit-logs', builder: (_, __) => const AuditLogsScreen()),
    GoRoute(
        path: '/administrators',
        builder: (_, __) => const AdministratorsScreen()),
    GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
    GoRoute(path: '/caregivers', builder: (_, __) => const CaregiversScreen()),
    GoRoute(path: '/pricing', builder: (_, __) => const PricingScreen()),
    GoRoute(
        path: '/transactions', builder: (_, __) => const TransactionsScreen()),
  ],
);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoldenCare Admin',
      theme: AdminTheme.theme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
