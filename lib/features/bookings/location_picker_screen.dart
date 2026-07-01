import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/colors.dart';
import '../../core/utils/permission_flow_helper.dart';
import '../../utils/geocoding_helper.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;

  LocationResult(
      {required this.latitude, required this.longitude, required this.address});
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  LatLng _initialPosition =
      const LatLng(20.5937, 78.9629); // Default to India center
  LatLng? _currentCameraPosition;
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  bool _isSearching = false;
  bool _isFetchingSuggestions = false;
  bool _isSearchPanelVisible = false;
  Timer? _searchDebounce;
  List<PlacePrediction> _searchSuggestions = const [];
  String? _locationIssue;
  String? _accuracyHint;
  String _placeSessionToken = '';
  String _currentAddress = 'Move map to select location';
  bool _isFetchingAddress = false;
  GeocodingResult? _currentGeocodingResult;

  void _showLocationSearchUnavailableSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location search currently unavailable'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _renewPlaceSessionToken();
    _determinePosition();
  }

  void _renewPlaceSessionToken() {
    _placeSessionToken =
        '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
  }

  Future<void> _determinePosition() async {
    try {
      final hasInitial =
          widget.initialLatitude != null && widget.initialLongitude != null;

      // If initial position is provided, use it
      if (hasInitial) {
        setState(() {
          _initialPosition =
              LatLng(widget.initialLatitude!, widget.initialLongitude!);
          _currentCameraPosition = _initialPosition;
        });
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 15));
        _getAddressFromLatLng(_initialPosition);
      }

      final allowed = await PermissionFlowHelper.ensureLocationPermission(
        context,
        feature: 'auto-detecting your current service address',
      );
      if (!allowed) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _hasLocationPermission = false;
          _locationIssue =
              'Location permission is required to detect where you are. Tap Try Again to grant access.';
          _accuracyHint = null;
        });
        if (hasInitial) {
          // Keep the saved pin visible even if live permission is denied.
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final position = await _resolveBestCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _initialPosition = latLng;
        _currentCameraPosition = _initialPosition;
        _isLoading = false;
        _hasLocationPermission = true;
        _locationIssue = null;
        _accuracyHint = _buildAccuracyHint(position.accuracy);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _getAddressFromLatLng(_initialPosition);

      if (hasInitial && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated to your live current location.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLocationPermission = false;
          _locationIssue =
              'Could not access your current location. Check permission and GPS settings, then try again.';
          _accuracyHint = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _searchAndMoveToLocation([String? queryInput]) async {
    final query = (queryInput ?? _searchController.text).trim();
    if (query.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a location to search.')),
      );
      return;
    }

    setState(() => _isSearching = true);
    try {
      final predictions = _searchSuggestions.isNotEmpty
          ? _searchSuggestions
          : await GeocodingHelper.searchPlaces(
              query,
              sessionToken: _placeSessionToken,
              latitude: _currentCameraPosition?.latitude,
              longitude: _currentCameraPosition?.longitude,
            );
      if (predictions.isNotEmpty) {
        await _applySelectedPrediction(predictions.first, query: query);
        return;
      }

      final fallback = await GeocodingHelper.resolveAddressFallback(query);
      if (fallback == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching location found. Try area + city.'),
          ),
        );
        return;
      }

      final latLng = LatLng(fallback.latitude, fallback.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
      if (!mounted) return;
      setState(() {
        _currentCameraPosition = latLng;
        _accuracyHint = null;
        _currentAddress = fallback.formattedAddress;
        _currentGeocodingResult = fallback.geocodingResult;
        _searchSuggestions = const [];
      });
    } on FirebaseFunctionsException {
      _showLocationSearchUnavailableSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search failed. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchInputChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchSuggestions = const [];
        _isFetchingSuggestions = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isFetchingSuggestions = true);
      List<PlacePrediction> predictions = const [];
      try {
        predictions = await GeocodingHelper.searchPlaces(
          query,
          sessionToken: _placeSessionToken,
          latitude: _currentCameraPosition?.latitude,
          longitude: _currentCameraPosition?.longitude,
        );
      } on FirebaseFunctionsException {
        _showLocationSearchUnavailableSnackBar();
      } catch (e) {
        debugPrint('Suggestion search error: $e');
      }
      if (!mounted) return;
      setState(() {
        _searchSuggestions = predictions;
        _isFetchingSuggestions = false;
      });
    });
  }

  Future<void> _applySelectedPrediction(
    PlacePrediction selected, {
    String? query,
  }) async {
    PlaceResolution? resolved;
    try {
      resolved = await GeocodingHelper.resolvePlaceLocation(
        selected.placeId,
        sessionToken: _placeSessionToken,
      );
    } on FirebaseFunctionsException {
      _showLocationSearchUnavailableSnackBar();
      return;
    } catch (e) {
      debugPrint('Resolve place error: $e');
      return;
    }
    _renewPlaceSessionToken();
    if (resolved == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve this place. Try another result.'),
        ),
      );
      return;
    }
    final resolvedPlace = resolved;

    final latLng = LatLng(resolvedPlace.latitude, resolvedPlace.longitude);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    if (!mounted) return;
    setState(() {
      _searchController.text = selected.mainText.isNotEmpty
          ? selected.mainText
          : (query ?? selected.description);
      _currentCameraPosition = latLng;
      _accuracyHint = null;
      _currentAddress = resolvedPlace.formattedAddress;
      _currentGeocodingResult = resolvedPlace.geocodingResult;
      _searchSuggestions = const [];
      _isSearchPanelVisible = false;
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (mounted) setState(() => _isFetchingAddress = true);
    try {
      final result = await GeocodingHelper.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (result != null) {
        if (mounted) {
          setState(() {
            _currentAddress = result.formattedAddress;
            _currentGeocodingResult = result;
            _isFetchingAddress = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentAddress = "Unknown Location";
            _currentGeocodingResult = null;
            _isFetchingAddress = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      if (mounted) {
        setState(() {
          _currentAddress = "Could not fetch address";
          _currentGeocodingResult = null;
          _isFetchingAddress = false;
        });
      }
    }
  }

  /// Returns true if the location is within the serviceable
  /// Chandigarh tricity area (Chandigarh UT + SAS Nagar + Panchkula district)
  bool _isServiceableLocation(GeocodingResult result) {
    final fields = [
      result.locality,
      result.subLocality,
      result.administrativeArea,
      result.subAdministrativeArea,
    ].where((s) => s.isNotEmpty).map((s) => s.toLowerCase().trim()).toList();

    const serviceableAreas = [
      // Chandigarh UT
      'chandigarh',
      // SAS Nagar / Mohali district
      'mohali',
      'sahibzada ajit singh nagar',
      'sas nagar',
      's.a.s. nagar',
      'new chandigarh',
      'mullanpur',
      'kharar',
      'zirakpur',
      'derabassi',
      'dera bassi',
      'baltana',
      'balongi',
      'kurali',
      'morinda',
      'fatehgarh sahib',
      // Panchkula district
      'panchkula',
      'kalka',
      'pinjore',
      'barwala',
    ];

    for (final field in fields) {
      for (final area in serviceableAreas) {
        if (field.contains(area) || area.contains(field)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _onCameraMove(CameraPosition position) async {
    _currentCameraPosition = position.target;
  }

  Future<void> _onCameraIdle() async {
    if (_currentCameraPosition != null) {
      _getAddressFromLatLng(_currentCameraPosition!);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final allowed = await PermissionFlowHelper.ensureLocationPermission(
        context,
        feature: 're-centering the map to your current position',
      );
      if (!allowed) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _locationIssue =
                'Location access is still blocked. Allow permission to continue.';
            _accuracyHint = null;
          });
        }
        return;
      }

      final position = await _resolveBestCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      setState(() {
        _currentCameraPosition = latLng;
        _hasLocationPermission = true;
        _locationIssue = null;
        _accuracyHint = _buildAccuracyHint(position.accuracy);
      });
      _getAddressFromLatLng(latLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location')));
      }
    }
  }

  void _confirmLocation() {
    if (_currentCameraPosition != null) {
      final result = _currentGeocodingResult;
      if (result != null && !_isServiceableLocation(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Service is available in Chandigarh, Mohali (SAS Nagar), Panchkula and surrounding areas.',
              ),
            ),
          );
        }
        return;
      }

      Navigator.pop(
        context,
        LocationResult(
          latitude: _currentCameraPosition!.latitude,
          longitude: _currentCameraPosition!.longitude,
          address: _currentAddress,
        ),
      );
    }
  }

  Future<Position> _resolveBestCurrentPosition() async {
    final attempts = [
      const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 12),
      ),
      const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 10),
      ),
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 8),
      ),
    ];

    Position? bestObserved;
    for (final settings in attempts) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: settings,
        );
        if (_isAccurateEnough(pos)) {
          return pos;
        }
        if (bestObserved == null || pos.accuracy < bestObserved.accuracy) {
          bestObserved = pos;
        }
      } catch (_) {
        // Try the next strategy.
      }
    }

    Position? lastKnown;
    if (!kIsWeb) {
      lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          _isAccurateEnough(lastKnown, allowOlderFix: false)) {
        return lastKnown;
      }
    }

    final fallbackAccuracy = bestObserved?.accuracy ?? lastKnown?.accuracy;
    throw Exception(
      fallbackAccuracy != null
          ? 'Current location is too imprecise (±${fallbackAccuracy.toStringAsFixed(0)} m).'
          : 'Unable to determine a precise current location.',
    );
  }

  bool _isAccurateEnough(
    Position position, {
    bool allowOlderFix = true,
  }) {
    if (position.accuracy <= 0 || position.accuracy > 250) {
      return false;
    }
    final maxAge =
        allowOlderFix ? const Duration(minutes: 5) : const Duration(minutes: 2);
    final age = DateTime.now().difference(position.timestamp);
    if (age > maxAge) {
      return false;
    }
    return true;
  }

  String? _buildAccuracyHint(double accuracyMeters) {
    if (accuracyMeters <= 0) {
      return null;
    }
    if (accuracyMeters > 400) {
      return 'Your device returned an approximate location (±${accuracyMeters.toStringAsFixed(0)} m). Move outdoors or enable precise location for better accuracy.';
    }
    return null;
  }

  void _focusSearch() {
    setState(() {
      _isSearchPanelVisible = true;
    });
    _searchFocusNode.requestFocus();
  }

  void _closeSearchPanel() {
    setState(() {
      _isSearchPanelVisible = false;
      _isFetchingSuggestions = false;
      _searchSuggestions = const [];
    });
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Service Location'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _initialPosition, zoom: 15),
            onMapCreated: (controller) {
              _mapController = controller;
              // If already loaded, move to position
              if (!_isLoading) {
                _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialPosition, 15));
              }
            },
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: _hasLocationPermission,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          if (!_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 30),
                child:
                    Icon(Icons.location_pin, size: 50, color: GCColors.primary),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: GCColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: (_isLoading || _isFetchingAddress)
                          ? const Text("Locating you...",
                              style: TextStyle(fontStyle: FontStyle.italic))
                          : Text(_currentAddress,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isSearchPanelVisible)
            Positioned(
              top: 98,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Search places',
                                border: InputBorder.none,
                                isDense: true,
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                              onChanged: _onSearchInputChanged,
                              onSubmitted: (_) => _searchAndMoveToLocation(),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close search',
                            onPressed: _closeSearchPanel,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: _isFetchingSuggestions
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : (_searchController.text.trim().length < 2)
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Text('Type at least 2 letters'),
                                )
                              : _searchSuggestions.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: Text('No places found'),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _searchSuggestions.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final item = _searchSuggestions[index];
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.location_on_outlined,
                                          ),
                                          title: Text(
                                            item.mainText.isNotEmpty
                                                ? item.mainText
                                                : item.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: item.secondaryText.isEmpty
                                              ? null
                                              : Text(
                                                  item.secondaryText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                          onTap: () =>
                                              _applySelectedPrediction(item),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          if (_accuracyHint != null)
            Positioned(
              top: _isSearchPanelVisible ? 410 : 170,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _accuracyHint!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (_locationIssue != null)
            Positioned(
              top: _isSearchPanelVisible
                  ? (_accuracyHint != null ? 478 : 410)
                  : (_accuracyHint != null ? 238 : 170),
              left: 16,
              right: 16,
              child: Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _locationIssue!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _determinePosition,
                          child: const Text('Try Again'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 164,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'search_location_fab',
              onPressed: _isSearching ? null : _focusSearch,
              backgroundColor: Colors.white,
              child: const Icon(Icons.search_rounded, color: GCColors.primary),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_location_fab',
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: GCColors.primary),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed:
                  (_isLoading || _isFetchingAddress) ? null : _confirmLocation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: GCColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
