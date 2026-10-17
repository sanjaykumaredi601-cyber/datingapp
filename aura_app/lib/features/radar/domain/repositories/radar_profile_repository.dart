import '../../data/models/radar_profile_document.dart';

/// Contract for Proximity Radar Profile queries and updates on `/profiles`
abstract class RadarProfileRepository {
  /// Upserts a user's public profile into `/profiles/{userId}`
  Future<void> saveProfile(RadarProfileDocument profile);

  /// Retrieves a specific profile by userId
  Future<RadarProfileDocument?> getProfile(String userId);

  /// Queries nearby profiles within [radiusKm] using Geohash prefix range matching
  Future<List<RadarProfileDocument>> queryNearbyProfiles({
    required double centerLat,
    required double centerLng,
    double radiusKm = 25.0,
    String? genderFilter,
    int limit = 30,
  });

  /// Real-time stream of nearby profiles within radius
  Stream<List<RadarProfileDocument>> streamNearbyProfiles({
    required double centerLat,
    required double centerLng,
    double radiusKm = 25.0,
  });
}
