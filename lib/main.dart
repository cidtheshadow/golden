import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'firebase/config_service.dart';
import 'firebase/notification_service.dart';
import 'core/theme.dart';
import 'core/router.dart';

Future<void> _enforceValidStartupSession() async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;

  if (user == null) return;

  try {
    await user.getIdToken(true);
  } on FirebaseAuthException catch (e) {
    const invalidCodes = {
      'user-disabled',
      'user-not-found',
      'invalid-user-token',
      'user-token-expired',
      'requires-recent-login',
    };

    if (invalidCodes.contains(e.code)) {
      await auth.signOut();
    }
  }
}

Future<void> _configureAppCheck() async {
  try {
    final recaptchaKey = ConfigService().recaptchaSiteKey;
    if (recaptchaKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        // PRODUCTION: always use playIntegrity for Android release builds
        // DEBUG: use debug provider only in debug mode
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
        webProvider: ReCaptchaEnterpriseProvider(recaptchaKey),
      );
    } else {
      if (!kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
      }
    }
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

Future<void> _configureCrashlytics() async {
  // Pass all uncaught Flutter framework errors to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Disable Crashlytics collection in debug mode
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
}

Future<void> _runDeferredStartupTasks() async {
  try {
    await Future.wait([
      _enforceValidStartupSession(),
      ConfigService().initialize(),
    ]);
    await _configureAppCheck();
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Deferred startup initialization failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Crashlytics to catch all errors before the app starts (Mobile only)
  if (!kIsWeb) {
    await _configureCrashlytics();
  }

  // Keep auth sessions stable across web refreshes
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // Defer non-critical startup tasks so first frame is not blocked
  unawaited(_runDeferredStartupTasks());

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            details.exceptionAsString() + '\n\n' + (details.stack?.toString() ?? ''),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: GoldenCareApp()));
}

class GoldenCareApp extends ConsumerWidget {
  const GoldenCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GoldenCare',
      theme: gcTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
