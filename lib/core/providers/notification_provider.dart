import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';

Stream<List<NotificationModel>> _notificationsForCollection(
  String uid,
  String collection,
) {
  return FirebaseFirestore.instance
      .collection(collection)
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => NotificationModel.fromFirestore(
                doc,
                sourceCollection: collection,
              ))
          .toList());
}

Stream<int> _unreadForCollection(String uid, String collection) {
  return FirebaseFirestore.instance
      .collection(collection)
      .doc(uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
}

Future<int> _fetchUnreadCountForCollection(
    String uid, String collection) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  } catch (_) {
    return 0;
  }
}

Future<int> _fetchUnreadCount(String uid) async {
  final results = await Future.wait([
    _fetchUnreadCountForCollection(uid, 'users'),
    _fetchUnreadCountForCollection(uid, 'servicePersonnel'),
  ]);
  return results.fold<int>(0, (total, item) => total + item);
}

final userNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return _notificationsForCollection(uid, 'users');
});

final partnerNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return _notificationsForCollection(uid, 'servicePersonnel');
});

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return const Stream.empty();
  }

  final userStream = _notificationsForCollection(uid, 'users');
  final partnerStream = _notificationsForCollection(uid, 'servicePersonnel');

  List<NotificationModel> latestUser = const [];
  List<NotificationModel> latestPartner = const [];

  return Stream.multi((controller) {
    void emit() {
      final merged = [...latestUser, ...latestPartner];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final unique = <String, NotificationModel>{};
      for (final n in merged) {
        unique['${n.sourceCollection}:${n.id}'] = n;
      }
      controller.add(unique.values.toList());
    }

    final sub1 = userStream.listen((value) {
      latestUser = value;
      emit();
    }, onError: controller.addError);

    final sub2 = partnerStream.listen((value) {
      latestPartner = value;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };
  });
});

final userUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return _unreadForCollection(uid, 'users');
});

final partnerUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return _unreadForCollection(uid, 'servicePersonnel');
});

final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(0);
  }

  return Stream.multi((controller) {
    var isCancelled = false;

    Future<void> run() async {
      while (!isCancelled) {
        final count = await _fetchUnreadCount(uid);
        if (!isCancelled) {
          controller.add(count);
        }
        await Future<void>.delayed(const Duration(seconds: 20));
      }
    }

    run();

    controller.onCancel = () {
      isCancelled = true;
    };
  });
});

Future<void> markNotificationRead(NotificationModel notification) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    // Use the server callable for all collections to avoid Firestore rules
    // denying client writes. The callable accepts either a single id or
    // multiple ids in `notificationIds` and an optional `collection`.
    await FirebaseFunctions.instance
        .httpsCallable('markNotificationsRead')
        .call({
      'notificationIds': [notification.id],
      'collection': notification.sourceCollection,
    });
    return;
  } catch (error) {
    debugPrint('[Notifications] markRead error: $error');
    rethrow;
  }
}

Future<void> markAllNotificationsRead(
    List<NotificationModel> notifications) async {
  final unread = notifications.where((n) => !n.isRead).toList();
  if (unread.isEmpty) return;

  // Group by sourceCollection for efficient batched server calls.
  final Map<String, List<String>> byCollection = {};
  for (final n in unread) {
    byCollection.putIfAbsent(n.sourceCollection, () => []).add(n.id);
  }

  try {
    for (final entry in byCollection.entries) {
      final ids = entry.value;
      const chunkSize = 200;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
            i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
        await FirebaseFunctions.instance
            .httpsCallable('markNotificationsRead')
            .call({'notificationIds': chunk, 'collection': entry.key});
      }
    }
  } catch (e) {
    debugPrint('[Notifications] markAllRead error: $e');
    rethrow;
  }
}
