import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'firebase/config_service.dart';
import 'firebase/notification_service.dart';
import 'core/theme.dart';
import 'core/router.dart';

Future<void> _configureAppCheck() async {
  try {
    final recaptchaKey = ConfigService().recaptchaSiteKey;
    if (recaptchaKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
        webProvider: ReCaptchaEnterpriseProvider(recaptchaKey),
      );
    } else {
      // On mobile, still activate with platform provider even without web key.
      if (!kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
      }
    }
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

Future<void> _runDeferredStartupTasks() async {
  try {
    await ConfigService().initialize();
    await _configureAppCheck();
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Deferred startup initialization failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Defer non-critical startup tasks so first frame and routing are not blocked.
  unawaited(_runDeferredStartupTasks());

  runApp(
    const ProviderScope(
      child: PartnerApp(),
    ),
  );
}

class PartnerApp extends ConsumerWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For the partner app, we might want a different theme or initial route.
    // However, the existing router handles role-based redirection.
    // We can use a different provider or flag if needed.
    return MaterialApp.router(
      title: 'Golden Care Partner',
      theme: gcTheme().copyWith(
        primaryColor: Colors.blue[800],
      ),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
