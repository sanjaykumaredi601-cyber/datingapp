import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Status result for location resolution
enum LocationResolutionStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  fallbackUsed,
}

/// Structured location result containing coordinates, source, and reverse geocoded display name
class LocationResult {
  final double latitude;
  final double longitude;
  final String displayName;
  final LocationResolutionStatus status;
  final String? errorMessage;
  final bool isAccurateGps;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.status,
    this.errorMessage,
    this.isAccurateGps = true,
  });

  /// Default graceful fallback (Toronto hub default for Canada / International)
  factory LocationResult.defaultFallback({
    String reason = 'Location services unavailable',
    double lat = 43.6532,
    double lng = -79.3832,
    String name = 'Downtown, Toronto',
  }) {
    return LocationResult(
      latitude: lat,
      longitude: lng,
      displayName: name,
      status: LocationResolutionStatus.fallbackUsed,
      errorMessage: reason,
      isAccurateGps: false,
    );
  }
}

/// Production Location Service for release builds
/// Resilient against GPS cold-starts, hardware timeouts, network disconnects, and R8 shrinking
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _cachedPosition;
  String? _cachedCityName;

  Position? get lastKnownPosition => _cachedPosition;

  /// High-reliability location resolver:
  /// 1. Checks service enablement and permissions.
  /// 2. If disabled/denied, returns proper LocationResolutionStatus (serviceDisabled, permissionDenied, etc.)
  /// 3. If granted, queries `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8))`
  /// 4. Falls back to `Geolocator.getLastKnownPosition()` if current position times out.
  /// 5. Reverse geocodes the resolved coordinates to City/Area dynamically using geocoding plugin.
  Future<LocationResult> getCurrentLocation({
    bool promptService = true,
  }) async {
    try {
      // 1. Service check
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] ⚠️ Location services are disabled on device.');
        return const LocationResult(
          latitude: 0,
          longitude: 0,
          displayName: '',
          status: LocationResolutionStatus.serviceDisabled,
          errorMessage: 'Location services are disabled on device. Please enable GPS in device settings.',
          isAccurateGps: false,
        );
      }

      // 2. Permission check
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] ⚠️ Location permission denied by user.');
        return const LocationResult(
          latitude: 0,
          longitude: 0,
          displayName: '',
          status: LocationResolutionStatus.permissionDenied,
          errorMessage: 'Location permission was denied.',
          isAccurateGps: false,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] ⚠️ Location permission permanently denied.');
        return const LocationResult(
          latitude: 0,
          longitude: 0,
          displayName: '',
          status: LocationResolutionStatus.permissionDeniedForever,
          errorMessage: 'Location permission is permanently denied. Please enable in App Settings.',
          isAccurateGps: false,
        );
      }

      // 3. Query getCurrentPosition(medium accuracy, 8s timeout) with fallback to getLastKnownPosition()
      Position? position;
      try {
        debugPrint('[LocationService] Querying Geolocator.getCurrentPosition (medium accuracy, 8s timeout)...');
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _cachedPosition = position;
      } catch (gpsErr) {
        debugPrint('[LocationService] getCurrentPosition timed out or error: $gpsErr. Checking getLastKnownPosition fallback...');
        try {
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            _cachedPosition = position;
            debugPrint('[LocationService] Fallback acquired last known position: (${position.latitude}, ${position.longitude})');
          }
        } catch (lastErr) {
          debugPrint('[LocationService] getLastKnownPosition failed: $lastErr');
        }
      }

      if (position == null && _cachedPosition != null) {
        position = _cachedPosition;
      }

      if (position == null) {
        return const LocationResult(
          latitude: 0,
          longitude: 0,
          displayName: '',
          status: LocationResolutionStatus.serviceDisabled,
          errorMessage: 'Could not resolve device coordinates.',
          isAccurateGps: false,
        );
      }

      // 4. Reverse geocode dynamically using geocoding plugin
      final zoneName = await reverseGeocodeGracefully(
        position.latitude,
        position.longitude,
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        displayName: zoneName,
        status: LocationResolutionStatus.success,
        isAccurateGps: true,
      );
    } catch (e) {
      debugPrint('[LocationService] Fatal location exception: $e');
      return LocationResult(
        latitude: 0,
        longitude: 0,
        displayName: '',
        status: LocationResolutionStatus.serviceDisabled,
        errorMessage: 'Error acquiring location: $e',
        isAccurateGps: false,
      );
    }
  }

  /// Safe dynamic reverse geocoding with 3-second timeout and offline resilience
  Future<String> reverseGeocodeGracefully(
    double lat,
    double lng, {
    String fallbackName = 'Current Location',
  }) async {
    // If we already have a cached name near this coordinate
    if (_cachedCityName != null && _cachedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _cachedPosition!.latitude,
        _cachedPosition!.longitude,
        lat,
        lng,
      );
      if (distance < 500) {
        return _cachedCityName!;
      }
    }

    try {
      // 1. Live dynamic geocoding via placemarkFromCoordinates with 3s timeout
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 3));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final locality = p.locality?.trim().isNotEmpty == true
            ? p.locality!.trim()
            : (p.subLocality?.trim().isNotEmpty == true
                ? p.subLocality!.trim()
                : (p.name?.trim().isNotEmpty == true ? p.name!.trim() : p.administrativeArea));
        final admin = p.administrativeArea?.trim().isNotEmpty == true
            ? p.administrativeArea!.trim()
            : p.country;
        if (locality != null && locality.isNotEmpty) {
          final formatted = admin != null && admin.isNotEmpty && admin != locality
              ? '$locality, $admin'
              : locality;
          _cachedCityName = formatted;
          return formatted;
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Dynamic reverse geocode note: $e');
    }

    // Default formatted coordinate label (e.g., 43.65°N, 79.38°W)
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    final display = '${lat.abs().toStringAsFixed(2)}°$latDir, ${lng.abs().toStringAsFixed(2)}°$lngDir';
    _cachedCityName = display;
    return display;
  }

  /// Checks if location service is enabled and permission is granted
  Future<bool> checkHasPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime location permission
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  /// Helper to prompt user to open app or location settings
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
