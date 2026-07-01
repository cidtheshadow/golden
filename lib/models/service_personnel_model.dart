import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePersonnelModel {
  final String id;
  final String name;
  final int age;
  final String gender;
  final double rating;
  final List<String> specialties;
  final String imageUrl;
  final bool isAvailable; // General availability (e.g. employed/active account)
  final bool isActive; // Indicates if the service personnel is currently active
  final bool isOnline; // "Live" status for immediate jobs, displayed in UI
  final int visitsCompleted;
  final bool idVerified;
  final List<String> languages;
  final List<String> keySkills;
  final List<Map<String, dynamic>> reviews;
  final String email;
  final String phone;
  final int experienceYears;
  final String bio;
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String country;

  ServicePersonnelModel({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.rating,
    required this.specialties,
    required this.imageUrl,
    this.isAvailable = true,
    this.isActive = true, // Default value for isActive
    this.isOnline = true,
    this.visitsCompleted = 0,
    this.idVerified = false,
    this.languages = const [],
    this.keySkills = const [],
    this.reviews = const [],
    this.email = '',
    this.phone = '',
    this.experienceYears = 0,
    this.bio = '',
    this.street = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.country = 'India',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'rating': rating,
      'specialties': specialties,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'isActive': isActive, // Include isActive in the map
      'isOnline': isOnline,
      'visitsCompleted': visitsCompleted,
      'idVerified': idVerified,
      'languages': languages,
      'keySkills': keySkills,
      'reviews': reviews,
      'email': email,
      'phone': phone,
      'experienceYears': experienceYears,
      'bio': bio,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
    };
  }

  factory ServicePersonnelModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return ServicePersonnelModel(
      id: doc.id,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      specialties: List<String>.from(data['specialties'] ?? []),
      imageUrl: (data['imageUrl'] as String? ?? '').trim(),
      isAvailable: data['isAvailable'] ?? true,
      isActive: data['isActive'] ?? true, // Safe fallback for legacy data
      isOnline: data['isOnline'] ?? true,
      visitsCompleted: data['visitsCompleted'] ?? 0,
      idVerified: data['idVerified'] ?? false,
      languages: List<String>.from(data['languages'] ?? []),
      keySkills: List<String>.from(data['keySkills'] ?? []),
      reviews: List<Map<String, dynamic>>.from(data['reviews'] ?? []),
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      experienceYears: data['experienceYears'] ?? 0,
      bio: data['bio'] ?? '',
      street: data['street'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      pincode: data['pincode'] ?? '',
      country: data['country'] ?? 'India',
    );
  }

  /// Whether the partner has completed all required profile fields.
  /// Mirrors [UserModel.isProfileComplete] for architectural consistency.
  bool get isProfileComplete {
    return name.isNotEmpty &&
        phone.isNotEmpty &&
        age > 0 &&
        gender.isNotEmpty &&
        specialties.isNotEmpty &&
        city.isNotEmpty &&
        state.isNotEmpty;
  }
}
