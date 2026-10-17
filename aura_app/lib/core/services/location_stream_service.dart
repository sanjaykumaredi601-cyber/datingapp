import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../utils/geohash_helper.dart';
import 'local_notification_service.dart';

/// Path crossing event emitted when two users share a 500m geohash cell within 15 minutes
class PathCrossingEvent {
  final String echoId;
  final String user1Id;
  final String user2Id;
  final String candidateName;
  final String zoneName;
  final String geohash;
  final DateTime crossedAt;

  PathCrossingEvent({
    required this.echoId,
    required this.user1Id,
    required this.user2Id,
    required this.candidateName,
    required this.zoneName,
    required this.geohash,
    required this.crossedAt,
  });

  Map<String, dynamic> toMap() => {
        'echoId': echoId,
        'user1Id': user1Id,
        'user2Id': user2Id,
        'candidateName': candidateName,
        'zoneName': zoneName,
        'geohash': geohash,
        'timestamp': crossedAt.toIso8601String(),
        'expiresAt': crossedAt.add(const Duration(hours: 48)).toIso8601String(),
        'isWaved': false,
      };
}

/// Real-Time Background & Live Geolocation Stream with 500m Safe Obfuscation
class LocationStreamService {
  static final LocationStreamService _instance = LocationStreamService._internal();
  factory LocationStreamService() => _instance;
  LocationStreamService._internal();

  FirebaseFirestore? _firestore;
  StreamSubscription<Position>? _positionSubscription;
  final Uuid _uuid = const Uuid();

  String? _activeUserId;
  String? _activeUserName;
  String? _lastGeohash500m;
  DateTime? _lastUpdateTimestamp;

  // Stream of path crossing events for in-app UI reactions
  final StreamController<PathCrossingEvent> _crossingStreamController =
      StreamController<PathCrossingEvent>.broadcast();
  Stream<PathCrossingEvent> get onPathCrossing => _crossingStreamController.stream;

  void configureFirestore(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Starts listening to geolocation stream with 500m geohash privacy obfuscation
  Future<bool> startTracking({
    required String userId,
    required String userName,
    FirebaseFirestore? firestore,
  }) async {
    _activeUserId = userId;
    _activeUserName = userName;
    if (firestore != null) _firestore = firestore;

    // Check location service & permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    // Cancel existing subscription if any
    await _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50, // Update every 50 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handlePositionUpdate);

    return true;
  }

  /// Safe 500m obfuscation handler: Never broadcasts exact GPS lat/long
  Future<void> _handlePositionUpdate(Position position) async {
    final userId = _activeUserId;
    if (userId == null) return;

    // 1. Obfuscate to 500m geohash cell (precision 6, ~600m x 600m)
    final geohash500m = GeoHashHelper.obfuscateTo500mGeohash(
      position.latitude,
      position.longitude,
    );
    final approxCenter = GeoHashHelper.decodeCenter(geohash500m);
    final now = DateTime.now();

    // Debounce updates if cell hasn't changed and within 2 minutes
    if (_lastGeohash500m == geohash500m &&
        _lastUpdateTimestamp != null &&
        now.difference(_lastUpdateTimestamp!).inMinutes < 2) {
      return;
    }

    _lastGeohash500m = geohash500m;
    _lastUpdateTimestamp = now;

    // 2. Broadcast ONLY obfuscated cell center to Firestore
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('profiles').doc(userId).set({
          'geohash': geohash500m,
          'approxLatitude': approxCenter['latitude'],
          'approxLongitude': approxCenter['longitude'],
          'lastLocationUpdate': now.toIso8601String(),
        }, SetOptions(merge: true));

        // 3. Check for Real-Time Path Crossing in the same 500m geohash cell
        await _detectPathCrossings(
          currentUserId: userId,
          currentUserName: _activeUserName ?? 'Aura Member',
          geohash500m: geohash500m,
          currentTime: now,
        );
      } catch (_) {}
    }
  }

  /// Triggers path crossing event if another user is in the same 500m geohash within 15 minutes
  Future<void> _detectPathCrossings({
    required String currentUserId,
    required String currentUserName,
    required String geohash500m,
    required DateTime currentTime,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final windowStart = currentTime.subtract(const Duration(minutes: 15));

    try {
      final nearbyQuery = await firestore
          .collection('profiles')
          .where('geohash', isEqualTo: geohash500m)
          .limit(10)
          .get();

      for (final doc in nearbyQuery.docs) {
        if (doc.id == currentUserId) continue;

        final data = doc.data();
        final lastUpdateStr = data['lastLocationUpdate'] as String?;
        if (lastUpdateStr != null) {
          final lastTime = DateTime.tryParse(lastUpdateStr);
          if (lastTime != null && lastTime.isAfter(windowStart)) {
            final candidateName = data['displayName'] as String? ?? 'Nearby Member';
            final zoneName = data['currentZoneName'] as String? ?? 'Proximity Zone';

            final event = PathCrossingEvent(
              echoId: 'echo_${_uuid.v4().substring(0, 8)}',
              user1Id: currentUserId,
              user2Id: doc.id,
              candidateName: candidateName,
              zoneName: zoneName,
              geohash: geohash500m,
              crossedAt: currentTime,
            );

            // Save event into /echoes
            await firestore.collection('echoes').doc(event.echoId).set(event.toMap());

            // Fire notification
            await LocalNotificationService().showPathCrossingNotification(
              echoId: event.echoId,
              candidateName: candidateName,
              zoneName: zoneName,
            );

            // Broadcast on in-app stream
            _crossingStreamController.add(event);
            break; // Fire once per cell update
          }
        }
      }
    } catch (_) {}
  }

  /// Stops stream subscription and active GPS tracking
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeUserId = null;
  }
}
