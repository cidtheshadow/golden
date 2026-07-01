import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'config_service.dart';
import '../core/utils/permission_flow_helper.dart';
// Android: google-services.json required in android/app/
// Web:     firebase-messaging-sw.js required in web/
//          VAPID key required — set 'vapid_key' in Firebase Remote Config

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _isInitialized = false;
  String? _fcmToken;
  String? _boundUserId;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final settings = await _fcm.getNotificationSettings();
    final canUseNotifications =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (canUseNotifications) {
      await refreshToken();
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.notification?.title}');
    });

    _fcm.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      final uid = _boundUserId;
      if (uid != null && uid.isNotEmpty) {
        await updateFCMToken(uid);
      }
    });

    _isInitialized = true;
  }

  Future<bool> ensurePermissionWithPrompt(BuildContext context) async {
    final granted = await PermissionFlowHelper.ensureNotificationPermission(
      context,
      feature: 'booking updates, reminders, and status changes',
    );
    if (granted) {
      await refreshToken();
    }
    return granted;
  }

  Future<void> refreshToken() async {
    try {
      if (kIsWeb) {
        _fcmToken = await _fcm
            .getToken(vapidKey: ConfigService().vapidKey)
            .timeout(const Duration(seconds: 10));
      } else {
        _fcmToken = await _fcm.getToken().timeout(const Duration(seconds: 10));
      }
      debugPrint('FCM Token obtained successfully');
    } catch (e) {
      debugPrint('FCM Token error or timeout: $e');
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
    String? bookingId,
    String? targetId,
    String collection = 'users',
  }) async {
    try {
      final callable = _functions.httpsCallable('createNotification');
      await callable.call({
        'targetUserId': userId,
        'title': title,
        'body': body,
        'type': type,
        'targetId': bookingId ?? targetId,
        'collection': collection,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> updateFCMToken(String userId,
      {String collection = 'users'}) async {
    if (_fcmToken == null) return;
    _boundUserId = userId;
    try {
      final docRef = _db.collection(collection).doc(userId);
      await docRef.set({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }
}
