import 'package:flutter/foundation.dart';

import 'app_environment.dart';

/// Compile-time injected client identifiers.
///
/// Pass values with --dart-define during build/run.
class ClientKeys {
  static const String mapsApiKey =
      String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

  static const String razorpayKeyLive =
      String.fromEnvironment('RAZORPAY_KEY_LIVE', defaultValue: '');

  static const String razorpayKeyTest =
      String.fromEnvironment('RAZORPAY_KEY_TEST', defaultValue: '');

  static const String recaptchaSiteKey =
      String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');

  static const String _razorpayMode =
      String.fromEnvironment('RAZORPAY_KEY_MODE', defaultValue: '');

  /// Selects Razorpay key from compile-time values.
  ///
  /// Priority:
  /// 1) Explicit --dart-define=RAZORPAY_KEY_MODE=live|test
  /// 2) Production environment + release mode => live
  /// 3) Otherwise => test
  static String get razorpayKey {
    final mode = _razorpayMode.toLowerCase();
    if (mode == 'live') return razorpayKeyLive;
    if (mode == 'test') return razorpayKeyTest;

    final useLive = AppEnvironment.isProduction && kReleaseMode;
    return useLive ? razorpayKeyLive : razorpayKeyTest;
  }
}
