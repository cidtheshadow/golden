import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String userId;
  String get familyId => userId;
  final String? userName; // Added
  final String serviceId;
  final String serviceName;
  final DateTime date;
  final String? time; // e.g., "10:00 AM"
  final String? duration; // e.g., "2 hours"
  final String status; // 'upcoming', 'completed', 'cancelled'
  final double price;
  final String? servicePersonnelId;
  String? get caregiverId => servicePersonnelId;
  final String? servicePersonnelName;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? startOtpDisplay;
  final String? completionOtpDisplay;
  final bool isVerifiedStart;
  final DateTime? startOtpExpiresAt;
  final DateTime? completionOtpExpiresAt;
  final int startOtpAttempts;
  final int completionOtpAttempts;
  final String? completionOtp;
  final DateTime? otpGeneratedAt;
  final bool isVerifiedComplete;
  final double? latitude;
  final double? longitude;
  final String? userLocationAddress;
  final DateTime? createdAt; // New field for booking timestamp
  final String? paymentId; // Razorpay payment ID for verification
  final String? transactionId; // Payment transaction record reference
  final String paymentStatus; // 'pending', 'paid', 'failed'
  final double? refundAmountDisplay;
  final String? cancelledBy;
  final String? refundReason;
  final String? specialNeeds;
  final String? elderName;
  final int? elderAge;
  final String? medicalConditions;

  BookingModel({
    required this.id,
    required this.userId,
    this.userName,
    required this.serviceId,
    required this.serviceName,
    required this.date,
    this.time,
    this.duration,
    required this.status,
    required this.price,
    this.servicePersonnelId,
    this.servicePersonnelName,
    this.startTime,
    this.endTime,
    this.startOtpDisplay,
    this.completionOtpDisplay,
    this.isVerifiedStart = false,
    this.startOtpExpiresAt,
    this.completionOtpExpiresAt,
    this.startOtpAttempts = 0,
    this.completionOtpAttempts = 0,
    this.completionOtp,
    this.otpGeneratedAt,
    this.isVerifiedComplete = false,
    this.latitude,
    this.longitude,
    this.userLocationAddress,
    this.createdAt,
    this.paymentId,
    this.transactionId,
    this.paymentStatus = 'pending',
    this.refundAmountDisplay,
    this.cancelledBy,
    this.refundReason,
    this.specialNeeds,
    this.elderName,
    this.elderAge,
    this.medicalConditions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'date': Timestamp.fromDate(date),
      'time': time,
      'duration': duration,
      'status': status,
      'price': price,
      'servicePersonnelId': servicePersonnelId,
      'servicePersonnelName': servicePersonnelName,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'startOtpDisplay': startOtpDisplay,
      'completionOtpDisplay': completionOtpDisplay,
      'isVerifiedStart': isVerifiedStart,
      'startOtpExpiresAt': startOtpExpiresAt != null
          ? Timestamp.fromDate(startOtpExpiresAt!)
          : null,
      'completionOtpExpiresAt': completionOtpExpiresAt != null
          ? Timestamp.fromDate(completionOtpExpiresAt!)
          : null,
      'startOtpAttempts': startOtpAttempts,
      'completionOtpAttempts': completionOtpAttempts,
      'completionOtp': completionOtp ?? '',
      'otpGeneratedAt':
          otpGeneratedAt != null ? Timestamp.fromDate(otpGeneratedAt!) : null,
      'isVerifiedComplete': isVerifiedComplete,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'userLocationAddress': userLocationAddress ?? '',
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'paymentId': paymentId ?? '',
      'transactionId': transactionId ?? '',
      'paymentStatus':
          paymentStatus.isEmpty ? 'pending_payment' : paymentStatus,
      'refundAmountDisplay': refundAmountDisplay ?? 0,
      'cancelledBy': cancelledBy ?? '',
      'refundReason': refundReason ?? '',
      'specialNeeds': specialNeeds ?? '',
      'elderName': elderName ?? '',
      'elderAge': elderAge ?? 0,
      'medicalConditions': medicalConditions ?? '',
    };
  }

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? asDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    double asDouble(dynamic value, {double fallback = 0.0}) {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    }

    int? asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return BookingModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: data['userName']?.toString(),
      serviceId: (data['serviceId'] ?? '').toString(),
      serviceName: (data['serviceName'] ?? '').toString(),
      date: asDateTime(data['date']) ?? DateTime.now(),
      time: data['time']?.toString(),
      duration: data['duration']?.toString(),
      status: (data['status'] ?? 'upcoming').toString(),
      price: asDouble(data['price']),
      servicePersonnelId:
          (data['servicePersonnelId'] ?? data['caregiverId'])?.toString(),
      servicePersonnelName:
          (data['servicePersonnelName'] ?? data['caregiverName'])?.toString(),
      startTime: asDateTime(data['startTime']),
      endTime: asDateTime(data['endTime']),
      startOtpDisplay: data['startOtpDisplay'] as String?,
      completionOtpDisplay: data['completionOtpDisplay'] as String?,
      isVerifiedStart: data['isVerifiedStart'] as bool? ?? false,
      startOtpExpiresAt: asDateTime(data['startOtpExpiresAt']),
      completionOtpExpiresAt: asDateTime(data['completionOtpExpiresAt']),
      startOtpAttempts: asInt(data['startOtpAttempts']) ?? 0,
      completionOtpAttempts: asInt(data['completionOtpAttempts']) ?? 0,
      completionOtp: data['completionOtp']?.toString(),
      otpGeneratedAt: asDateTime(data['otpGeneratedAt']),
      isVerifiedComplete: data['isVerifiedComplete'] ?? false,
      latitude: asDouble(data['latitude']),
      longitude: asDouble(data['longitude']),
      userLocationAddress: data['userLocationAddress']?.toString(),
      createdAt: asDateTime(data['createdAt']),
      paymentId: data['paymentId']?.toString(),
      transactionId: data['transactionId']?.toString(),
      paymentStatus: (data['paymentStatus'] ?? 'pending').toString(),
      refundAmountDisplay: data.containsKey('refundAmountDisplay')
          ? asDouble(data['refundAmountDisplay'])
          : null,
      cancelledBy: data['cancelledBy']?.toString(),
      refundReason: data['refundReason']?.toString(),
      specialNeeds: data['specialNeeds']?.toString(),
      elderName: data['elderName']?.toString(),
      elderAge: asInt(data['elderAge']),
      medicalConditions: data['medicalConditions']?.toString(),
    );
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? serviceId,
    String? serviceName,
    DateTime? date,
    String? time,
    String? duration,
    String? status,
    double? price,
    String? servicePersonnelId,
    String? servicePersonnelName,
    DateTime? startTime,
    DateTime? endTime,
    String? startOtpDisplay,
    String? completionOtpDisplay,
    bool? isVerifiedStart,
    DateTime? startOtpExpiresAt,
    DateTime? completionOtpExpiresAt,
    int? startOtpAttempts,
    int? completionOtpAttempts,
    String? completionOtp,
    DateTime? otpGeneratedAt,
    bool? isVerifiedComplete,
    double? latitude,
    double? longitude,
    String? userLocationAddress,
    DateTime? createdAt,
    String? paymentId,
    String? transactionId,
    String? paymentStatus,
    double? refundAmountDisplay,
    String? cancelledBy,
    String? refundReason,
    String? specialNeeds,
    String? elderName,
    int? elderAge,
    String? medicalConditions,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      date: date ?? this.date,
      time: time ?? this.time,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      price: price ?? this.price,
      servicePersonnelId: servicePersonnelId ?? this.servicePersonnelId,
      servicePersonnelName: servicePersonnelName ?? this.servicePersonnelName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startOtpDisplay: startOtpDisplay ?? this.startOtpDisplay,
      completionOtpDisplay: completionOtpDisplay ?? this.completionOtpDisplay,
      isVerifiedStart: isVerifiedStart ?? this.isVerifiedStart,
      startOtpExpiresAt: startOtpExpiresAt ?? this.startOtpExpiresAt,
      completionOtpExpiresAt:
          completionOtpExpiresAt ?? this.completionOtpExpiresAt,
      startOtpAttempts: startOtpAttempts ?? this.startOtpAttempts,
      completionOtpAttempts:
          completionOtpAttempts ?? this.completionOtpAttempts,
      completionOtp: completionOtp ?? this.completionOtp,
      otpGeneratedAt: otpGeneratedAt ?? this.otpGeneratedAt,
      isVerifiedComplete: isVerifiedComplete ?? this.isVerifiedComplete,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      userLocationAddress: userLocationAddress ?? this.userLocationAddress,
      createdAt: createdAt ?? this.createdAt,
      paymentId: paymentId ?? this.paymentId,
      transactionId: transactionId ?? this.transactionId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      refundAmountDisplay: refundAmountDisplay ?? this.refundAmountDisplay,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      refundReason: refundReason ?? this.refundReason,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      elderName: elderName ?? this.elderName,
      elderAge: elderAge ?? this.elderAge,
      medicalConditions: medicalConditions ?? this.medicalConditions,
    );
  }
}

class PaginatedBookingsResult {
  final List<BookingModel> bookings;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PaginatedBookingsResult({
    required this.bookings,
    required this.lastDocument,
    required this.hasMore,
  });
}
