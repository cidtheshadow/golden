import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:cloud_functions/cloud_functions.dart';

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceResolution {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final GeocodingResult geocodingResult;

  const PlaceResolution({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.geocodingResult,
  });
}

class GeocodingResult {
  final String street;
  final String subLocality;
  final String locality;
  final String administrativeArea; // e.g. "Punjab", "Haryana", "Chandigarh"
  final String subAdministrativeArea; // e.g. "Sahibzada Ajit Singh Nagar"
  final String postalCode;
  final String country;
  final String address;
  final String formatted;
  final Map<String, String> components;

  GeocodingResult({
    this.street = '',
    this.subLocality = '',
    this.locality = '',
    this.administrativeArea = '',
    this.subAdministrativeArea = '',
    this.postalCode = '',
    this.country = '',
    this.address = '',
    this.formatted = '',
    this.components = const {},
  });

  /// Null-safe, empty-filtered address string — never produces ",,,,"
  String get formattedAddress {
    if (address.isNotEmpty) return address;
    if (formatted.isNotEmpty) return formatted;
    final parts = [
      if (street.isNotEmpty) street,
      if (subLocality.isNotEmpty) subLocality,
      if (locality.isNotEmpty) locality,
      if (subAdministrativeArea.isNotEmpty) subAdministrativeArea,
      if (administrativeArea.isNotEmpty) administrativeArea,
    ];
    // Remove duplicates while preserving order
    final seen = <String>{};
    final unique = parts.where((p) => seen.add(p)).toList();
    return unique.isEmpty ? 'Location selected' : unique.join(', ');
  }

  factory GeocodingResult.fromMap(Map<String, dynamic> data) {
    final components = Map<String, String>.from(
      (data['components'] as Map? ?? {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
    return GeocodingResult(
      street: data['street'] as String? ?? components['route'] ?? '',
      subLocality: data['subLocality'] as String? ??
          components['sublocality_level_1'] ??
          components['sublocality'] ??
          '',
      locality: data['locality'] as String? ?? components['locality'] ?? '',
      administrativeArea: data['administrativeArea'] as String? ??
          components['administrative_area_level_1'] ??
          '',
      subAdministrativeArea: data['subAdministrativeArea'] as String? ??
          components['administrative_area_level_2'] ??
          '',
      postalCode:
          data['postalCode'] as String? ?? components['postal_code'] ?? '',
      country: data['country'] as String? ?? components['country'] ?? '',
      address: data['address'] as String? ?? '',
      formatted: data['formatted'] as String? ?? '',
      components: components,
    );
  }
}

class GeocodingHelper {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<GeocodingResult?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (kIsWeb) {
      return _getAddressFromCoordinatesWeb(latitude, longitude);
    } else {
      return _getAddressFromCoordinatesNative(latitude, longitude);
    }
  }

  static Future<GeocodingResult?> _getAddressFromCoordinatesNative(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return GeocodingResult(
          street: place.street ?? '',
          subLocality: place.subLocality ?? '',
          locality: place.locality ?? '',
          administrativeArea: place.administrativeArea ?? '',
          subAdministrativeArea: place.subAdministrativeArea ?? '',
          postalCode: place.postalCode ?? '',
          country: place.country ?? '',
          formatted: [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(', '),
        );
      }
    } catch (e) {
      debugPrint('Native geocoding error: $e');
    }
    return null;
  }

  /// Web geocoding: calls the server-side Cloud Function `geocodeAddress`
  /// so the Maps API key NEVER leaves the server.
  static Future<GeocodingResult?> _getAddressFromCoordinatesWeb(
    double latitude,
    double longitude,
  ) async {
    try {
      final callable = _functions.httpsCallable('geocodeAddress');
      final result = await callable.call<Map<String, dynamic>>({
        'latitude': latitude,
        'longitude': longitude,
      });

      return GeocodingResult.fromMap(Map<String, dynamic>.from(result.data));
    } catch (e) {
      debugPrint('Web geocoding (Cloud Function) error: $e');
    }
    return null;
  }

  static Future<List<PlacePrediction>> searchPlaces(
    String input, {
    String? sessionToken,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final callable = _functions.httpsCallable('placeSearch');
      final result = await callable.call<Map<String, dynamic>>({
        'input': input,
        if (sessionToken != null && sessionToken.trim().isNotEmpty)
          'sessionToken': sessionToken.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      final data = Map<String, dynamic>.from(result.data);
      final items = (data['predictions'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (item) => PlacePrediction(
              placeId: item['placeId'] as String? ?? '',
              description: item['description'] as String? ?? '',
              mainText: item['mainText'] as String? ?? '',
              secondaryText: item['secondaryText'] as String? ?? '',
            ),
          )
          .where((item) => item.placeId.isNotEmpty)
          .toList(growable: false);

      return items;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Place search FirebaseFunctionsException: code=${e.code} message=${e.message} details=${e.details}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Place search error: $e');
      rethrow;
    }
  }

  static Future<PlaceResolution?> resolvePlaceLocation(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final callable = _functions.httpsCallable('resolvePlaceLocation');
      final result = await callable.call<Map<String, dynamic>>({
        'placeId': placeId,
        if (sessionToken != null && sessionToken.trim().isNotEmpty)
          'sessionToken': sessionToken.trim(),
      });

      final data = Map<String, dynamic>.from(result.data);
      final latitude = (data['latitude'] as num?)?.toDouble();
      final longitude = (data['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return null;
      }

      final geocodingResult = GeocodingResult.fromMap(data);
      return PlaceResolution(
        latitude: latitude,
        longitude: longitude,
        formattedAddress: data['formattedAddress'] as String? ??
            geocodingResult.formattedAddress,
        geocodingResult: geocodingResult,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Place details FirebaseFunctionsException: code=${e.code} message=${e.message} details=${e.details}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Place details error: $e');
      rethrow;
    }
  }

  static Future<PlaceResolution?> resolveAddressFallback(String query) async {
    try {
      final locations = await geocoding.locationFromAddress(query);
      if (locations.isEmpty) {
        return null;
      }

      final location = locations.first;
      final latitude = location.latitude;
      final longitude = location.longitude;
      final fromCoords = await getAddressFromCoordinates(latitude, longitude);
      final geocodingResult = fromCoords ??
          GeocodingResult(
            address: query,
            formatted: query,
          );

      return PlaceResolution(
        latitude: latitude,
        longitude: longitude,
        formattedAddress: geocodingResult.formattedAddress,
        geocodingResult: geocodingResult,
      );
    } catch (e) {
      debugPrint('Fallback geocoding error: $e');
      return null;
    }
  }
}
