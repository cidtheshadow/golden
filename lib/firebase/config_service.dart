import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../core/config/app_environment.dart';
import '../core/config/client_keys.dart';
import 'maps_loader_stub.dart'
    if (dart.library.js_interop) 'maps_loader_web.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _mapsScriptLoaded = false;

  // Public config fetched from Cloud Functions (stored in Secret Manager)
  bool _publicConfigLoaded = false;
  String _mapsPlatformKey = '';
  String _vapidKey = '';
  String _recaptchaSiteKey = '';
  String _razorpayKeyId = '';
  String _runtimeMode = '';

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: AppEnvironment.isProduction
            ? const Duration(hours: 1)
            : const Duration(minutes: 5),
      ));

      await _remoteConfig.setDefaults({
        'profilePhotoRequired': false,
        'bookingStartHour': 6,
        'bookingEndHour': 20,
        'vapid_key': '',
        'environment': AppEnvironment.remoteConfigEnvironment,
      });

      await _remoteConfig
          .fetchAndActivate()
          .timeout(const Duration(seconds: 8));

      debugPrint('[CONFIG] Environment: ${AppEnvironment.name}');

      // Fetch public, non-secret client keys from Cloud Functions (Secret Manager)
      await _fetchPublicConfig();

      // On web, dynamically load Google Maps SDK using the fetched key
      if (kIsWeb) {
        _loadMapsScriptWeb();
      }
    } catch (e) {
      debugPrint('ConfigService: Remote Config initialization failed: $e');
    }
  }

  /// Dynamically inject the Google Maps JS SDK on web using compile-time key.
  void _loadMapsScriptWeb() {
    if (_mapsScriptLoaded) return;
    // Prefer Cloud Functions delivered maps platform key (from Secret Manager)
    // Fallback to compile-time value only if not available.
    final key =
        _mapsPlatformKey.isNotEmpty ? _mapsPlatformKey : ClientKeys.mapsApiKey;
    if (key.isEmpty) {
      debugPrint(
          'ConfigService: MAPS_API_KEY is empty; skipping Maps SDK injection');
      return;
    }
    try {
      injectMapsScript(key);
      _mapsScriptLoaded = true;
    } catch (e) {
      debugPrint('ConfigService: Failed to inject Maps script: $e');
    }
  }

  bool get isProfilePhotoRequired =>
      _remoteConfig.getBool('profilePhotoRequired');

  int get bookingStartHour => _remoteConfig.getInt('bookingStartHour');
  int get bookingEndHour => _remoteConfig.getInt('bookingEndHour');

  String get mapsApiKey {
    if (_mapsPlatformKey.isNotEmpty) return _mapsPlatformKey;
    const fallback = ClientKeys.mapsApiKey;
    return fallback;
  }

  /// Returns Razorpay key delivered via Remote Config (preferred) or falls
  /// back to compile-time values. Production builds should rely on server-side
  /// order creation instead of embedding private keys.
  /// Razorpay publishable key id (server-selected by environment). This is
  /// safe to return to clients. The secret key is never exposed.
  String get razorpayKey {
    if (_razorpayKeyId.isNotEmpty) return _razorpayKeyId;
    return ClientKeys.razorpayKey;
  }

  String get environment => _remoteConfig.getString('environment');

  String get vapidKey => _vapidKey.isNotEmpty ? _vapidKey : '';

  String get recaptchaSiteKey {
    if (_recaptchaSiteKey.isNotEmpty) return _recaptchaSiteKey;
    return ClientKeys.recaptchaSiteKey;
  }

  Future<void> _fetchPublicConfig() async {
    if (_publicConfigLoaded) return;
    try {
      final callable = _functions.httpsCallable('getPublicConfig');
      final result = await callable.call().timeout(const Duration(seconds: 6));
      final Map data = (result.data ?? {}) as Map<dynamic, dynamic>;
      _mapsPlatformKey = (data['mapsPlatformKey'] ?? '') as String;
      _vapidKey = (data['vapidKey'] ?? '') as String;
      _recaptchaSiteKey = (data['recaptchaSiteKey'] ?? '') as String;
      _razorpayKeyId = (data['razorpayKeyId'] ?? '') as String;
      _runtimeMode = (data['mode'] ?? '') as String;
      _publicConfigLoaded = true;
      debugPrint('[ConfigService] Fetched public config (mode=$_runtimeMode)');
    } catch (e) {
      debugPrint('[ConfigService] Failed to fetch public config: $e');
    }
  }

  /// Fetch service details from Firestore at runtime.
  /// Returns a map with keys like `about` and `includes`.
  Future<Map<String, dynamic>> getServiceDetails(String serviceId) async {
    try {
      if (serviceId.isEmpty) return {};
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .get();
      if (!doc.exists) return {};
      final data = doc.data() ?? {};
      // Normalize includes to a List<String> if present
      if (data['includes'] is Iterable) {
        final includes = List<String>.from(data['includes']);
        return {
          'about': data['about'] ?? '',
          'includes': includes,
        };
      }
      return {
        'about': data['about'] ?? '',
        'includes': [],
      };
    } catch (e) {
      debugPrint('ConfigService: Firestore getServiceDetails failed: $e');
      return {};
    }
  }
}
