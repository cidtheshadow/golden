import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? map['number'] as String? ?? '',
      relationship:
          map['relationship'] as String? ?? map['relation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  bool get isValid =>
      name.isNotEmpty && phone.isNotEmpty && relationship.isNotEmpty;
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? street;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? profileImage;
  final DateTime? dob;
  final String role;
  final List<Map<String, dynamic>> emergencyContacts;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.street,
    this.city,
    this.state,
    this.pincode,
    this.country = 'India',
    this.latitude,
    this.longitude,
    this.profileImage,
    this.dob,
    this.role = 'family',
    required this.emergencyContacts,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      street: data['street'],
      city: data['city'],
      state: data['state'],
      pincode: data['pincode'],
      country: data['country'] ?? 'India',
      latitude: asDouble(data['latitude']),
      longitude: asDouble(data['longitude']),
      profileImage:
          ((data['profileImage'] ?? data['profileImageUrl']) as String?)
              ?.trim(), // Support both keys and trim
      dob: _parseDob(data['dob'] ?? data['dateOfBirth']),
      role: data['role'] ?? 'family',
      emergencyContacts: (data['emergencyContacts'] as List? ?? [])
          .whereType<Map>()
          .map((entry) =>
              EmergencyContact.fromMap(Map<String, dynamic>.from(entry))
                  .toMap())
          .toList(),
    );
  }

  static DateTime? _parseDob(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      // Try dd/MM/yyyy format first
      final parts = value.split('/');
      if (parts.length == 3) {
        try {
          return DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } catch (_) {}
      }
      // Try ISO format
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'profileImage': profileImage,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'role': role,
      'emergencyContacts': emergencyContacts,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? street,
    String? city,
    String? state,
    String? pincode,
    String? country,
    double? latitude,
    double? longitude,
    String? profileImage,
    DateTime? dob,
    String? role,
    List<Map<String, dynamic>>? emergencyContacts,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profileImage: profileImage ?? this.profileImage,
      dob: dob ?? this.dob,
      role: role ?? this.role,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  bool get isProfileComplete {
    return name.isNotEmpty &&
        phone.isNotEmpty &&
        address.isNotEmpty &&
        dob != null;
  }

  List<EmergencyContact> get emergencyContactModels =>
      emergencyContacts.map(EmergencyContact.fromMap).toList();
}
