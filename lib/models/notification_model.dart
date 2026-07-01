import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final String sourceCollection;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.bookingId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
    this.sourceCollection = 'users',
  });

  factory NotificationModel.fromFirestore(
    DocumentSnapshot doc, {
    String sourceCollection = 'users',
  }) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return NotificationModel(
      id: doc.id,
      type: (data['type'] as String?) ?? 'general',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      bookingId: data['bookingId'] as String?,
      isRead: (data['isRead'] as bool?) ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      sourceCollection: sourceCollection,
    );
  }

  NotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
    DateTime? expiresAt,
    String? sourceCollection,
  }) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      body: body,
      bookingId: bookingId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt ?? this.expiresAt,
      sourceCollection: sourceCollection ?? this.sourceCollection,
    );
  }
}
