import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceOption {
  final String duration;
  final double price;

  ServiceOption({required this.duration, required this.price});

  Map<String, dynamic> toMap() {
    return {
      'duration': duration,
      'price': price,
    };
  }

  factory ServiceOption.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final parsedPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;

    return ServiceOption(
      duration: map['duration']?.toString() ?? '',
      price: parsedPrice,
    );
  }
}

class ServiceModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final List<String> includedItems;
  final bool isActive;
  final bool isPopular;
  final List<ServiceOption> options;

  ServiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.includedItems,
    required this.isActive,
    required this.isPopular,
    required this.options,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Migration logic: Check if 'options' exists, otherwise map old fields
    List<ServiceOption> options = [];
    if (data['options'] != null) {
      options = (data['options'] as List)
          .map((item) => ServiceOption.fromMap(item))
          .toList();
    } else {
      // Fallback for old data structure
      options.add(ServiceOption(
        duration: data['duration'] ?? '',
        price: (data['price'] ?? 0).toDouble(),
      ));
    }

    final dynamic rawIsActive = data['isActive'];
    final dynamic rawIsPopular = data['isPopular'];
    final bool resolvedIsActive = rawIsActive is bool
        ? rawIsActive
        : (rawIsPopular is bool ? rawIsPopular : true);
    final bool resolvedIsPopular =
        rawIsPopular is bool ? rawIsPopular : resolvedIsActive;

    return ServiceModel(
      id: doc.id,
      title: (data['title'] ?? data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      imageUrl: (data['imageUrl'] as String? ?? '').trim(),
      includedItems: (data['includedItems'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      isActive: resolvedIsActive,
      isPopular: resolvedIsPopular,
      options: options,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'includedItems': includedItems,
      'isActive': isActive,
      'isPopular': isPopular,
      'options': options.map((opt) => opt.toMap()).toList(),
    };
  }
}
