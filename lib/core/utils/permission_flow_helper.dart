import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum _PermissionDialogAction { retry, openSettings, cancel }

class PermissionFlowHelper {
  static Future<bool> ensureLocationPermission(
    BuildContext context, {
    String feature = 'location-based services',
  }) async {
    // If location services are disabled at the OS level, prompt to open
    // location settings first so the user can enable device GPS.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;

      final action = await _showPermissionDialog(
        context,
        title: 'Location Services Disabled',
        message:
            'Your device location services are turned off. Enable them to use $feature.',
        showOpenSettings: true,
      );

      if (action == _PermissionDialogAction.openSettings) {
        await Geolocator.openLocationSettings();
        return false;
      }

      return false;
    }

    // Check for denied forever separately so we can direct users to settings.
    final currentPermission = await Geolocator.checkPermission();
    if (currentPermission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final action = await _showPermissionDialog(
        context,
        title: 'Location Permission Permanently Denied',
        message:
            'Location permission was permanently denied. Open app settings to allow $feature.',
        showOpenSettings: true,
      );
      if (action == _PermissionDialogAction.openSettings) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    final granted = await _checkLocationReady();
    if (granted) return true;
    if (!context.mounted) return false;

    final action = await _showPermissionDialog(
      context,
      title: 'Location Permission Needed',
      message:
          'We need your location to use $feature and find your current position accurately.',
      showOpenSettings: true,
    );

    if (action == _PermissionDialogAction.cancel || !context.mounted) {
      return false;
    }

    if (action == _PermissionDialogAction.openSettings) {
      await Geolocator.openAppSettings();
      return false;
    }

    return _checkLocationReady(forceRequest: true);
  }

  static Future<bool> ensureCameraPermission(
    BuildContext context, {
    String feature = 'taking profile photos',
  }) async {
    if (kIsWeb) {
      debugPrint(
          'Camera permission: running on web — browser prompt will be used');
      return true;
    }

    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      debugPrint('Camera permission: already granted');
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      final action = await _showPermissionDialog(
        context,
        title: 'Camera Permission Permanently Denied',
        message:
            'Camera access was permanently denied. Open app settings to allow $feature.',
        showOpenSettings: true,
      );
      if (action == _PermissionDialogAction.openSettings) {
        await openAppSettings();
      }
      return false;
    }

    if (!context.mounted) return false;

    final action = await _showPermissionDialog(
      context,
      title: 'Camera Permission Needed',
      message:
          'Camera access is required for $feature. You can retry now or open app settings.',
      showOpenSettings: true,
    );

    if (action == _PermissionDialogAction.cancel || !context.mounted) {
      return false;
    }

    if (action == _PermissionDialogAction.openSettings) {
      await openAppSettings();
      return false;
    }

    final requested = await Permission.camera.request();
    debugPrint('Camera permission request result: ${requested.isGranted}');
    return requested.isGranted || requested.isLimited;
  }

  static Future<bool> ensureNotificationPermission(
    BuildContext context, {
    String feature = 'booking and service alerts',
  }) async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    if (_notificationAuthorized(settings)) {
      debugPrint('Notification permission: already authorized');
      return true;
    }

    if (!context.mounted) return false;

    // On web, attempt a direct request first because opening app settings
    // programmatically isn't available in browsers.
    if (kIsWeb) {
      try {
        final requested = await messaging.requestPermission();
        debugPrint(
            'Web notification request result: ${requested.authorizationStatus}');
        return _notificationAuthorized(requested);
      } catch (e) {
        debugPrint('Web notification request failed: $e');
      }
    }

    final action = await _showPermissionDialog(
      context,
      title: 'Notification Permission Needed',
      message:
          'Notifications are required for $feature. Please allow notifications to stay updated.',
      showOpenSettings: true,
    );

    if (action == _PermissionDialogAction.cancel || !context.mounted) {
      return false;
    }

    if (action == _PermissionDialogAction.openSettings) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Open your browser site settings to allow notifications for this site.'),
          ),
        );
        return false;
      }
      await openAppSettings();
      return false;
    }

    final requested = await messaging.requestPermission();
    debugPrint('Notification request result: ${requested.authorizationStatus}');
    return _notificationAuthorized(requested);
  }

  static bool _notificationAuthorized(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<bool> _checkLocationReady({bool forceRequest = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || forceRequest) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<_PermissionDialogAction> _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool showOpenSettings = false,
  }) async {
    final action = await showDialog<_PermissionDialogAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PermissionDialogAction.cancel),
            child: const Text('Not Now'),
          ),
          if (showOpenSettings)
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_PermissionDialogAction.openSettings),
              child: const Text('Open Settings'),
            ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PermissionDialogAction.retry),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );

    return action ?? _PermissionDialogAction.cancel;
  }
}
