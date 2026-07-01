/// Compile-time environment flag.
/// Set via --dart-define=ENVIRONMENT=testing or production.
/// Defaults to 'testing' if not specified (safe default).
class AppEnvironment {
  static const String _env =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'testing');

  static bool get isProduction => _env == 'production';
  static bool get isTesting => _env == 'testing';
  static String get name => _env;

  /// Used when exposing the active build environment to app code.
  static String get remoteConfigEnvironment => _env;
}
