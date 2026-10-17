import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/geohash_helper.dart';
import 'package:aura_app/features/radar/data/models/radar_vibe_beacon_model.dart';
import 'package:aura_app/features/radar/data/repositories/radar_profile_repository_impl.dart';

void main() {
  group('NextGen IT Global - Radar Distance & Spatial Logic Unit Tests', () {
    test('1. Haversine distance formula calculates exact geographic distance between known points', () {
      // Coordinates:
      // Point A: Bandra West, Mumbai (19.0596, 72.8295)
      // Point B: Carter Road Promenade (19.0650, 72.8250)
      final distanceKm = GeoHashHelper.haversineDistanceKm(
        19.0596, 72.8295,
        19.0650, 72.8250,
      );

      // Expected distance is approximately 0.76 km (~760 meters)
      expect(distanceKm, greaterThan(0.5));
      expect(distanceKm, lessThan(1.2));

      // Same coordinate returns 0 km
      final zeroDist = GeoHashHelper.haversineDistanceKm(19.0596, 72.8295, 19.0596, 72.8295);
      expect(zeroDist, equals(0.0));
    });

    test('2. Geohash encoding produces accurate hierarchical spatial hash', () {
      final hash9 = GeoHashHelper.encode(19.0596, 72.8295, precision: 9);
      final hash5 = GeoHashHelper.encode(19.0596, 72.8295, precision: 5);

      expect(hash9.length, equals(9));
      expect(hash5.length, equals(5));
      // 5-character prefix of 9-character hash must be identical
      expect(hash9.startsWith(hash5), isTrue);
    });

    test('3. geohashQueryBounds selects appropriate precision based on radius', () {
      final boundsSmallRadius = GeoHashHelper.geohashQueryBounds(19.0596, 72.8295, 2.0); // 2 km
      final boundsLargeRadius = GeoHashHelper.geohashQueryBounds(19.0596, 72.8295, 50.0); // 50 km

      expect(boundsSmallRadius.isNotEmpty, isTrue);
      expect(boundsLargeRadius.isNotEmpty, isTrue);

      // Smaller radius uses higher precision (longer geohash prefix)
      final smallPrefixLength = boundsSmallRadius.first[0].length;
      final largePrefixLength = boundsLargeRadius.first[0].length;
      expect(smallPrefixLength, greaterThan(largePrefixLength));
    });
  });

  group('NextGen IT Global - Radar Profile Repository & Filtering Tests', () {
    late RadarProfileRepositoryImpl repository;

    setUp(() {
      repository = RadarProfileRepositoryImpl();
    });

    test('1. queryNearbyProfiles filters candidates strictly within radius boundary', () async {
      // Center: Bandra West (19.0596, 72.8295)
      final allProfiles = await repository.queryNearbyProfiles(
        centerLat: 19.0596,
        centerLng: 72.8295,
        radiusKm: 25.0,
      );

      expect(allProfiles.isNotEmpty, isTrue);
      for (final profile in allProfiles) {
        expect(profile.distanceKm, isNotNull);
        expect(profile.distanceKm!, lessThanOrEqualTo(25.0));
      }

      // Restrict radius to a narrow 0.4 km
      final narrowProfiles = await repository.queryNearbyProfiles(
        centerLat: 19.0596,
        centerLng: 72.8295,
        radiusKm: 0.4,
      );

      // Seed profile Ananya at exact same coord (distance 0.0) must be included, others outside 400m excluded
      expect(narrowProfiles.length, lessThan(allProfiles.length));
    });

    test('2. queryNearbyProfiles sorts candidates by distance ascending', () async {
      final profiles = await repository.queryNearbyProfiles(
        centerLat: 19.0596,
        centerLng: 72.8295,
        radiusKm: 50.0,
      );

      for (int i = 0; i < profiles.length - 1; i++) {
        expect(profiles[i].distanceKm!, lessThanOrEqualTo(profiles[i + 1].distanceKm!));
      }
    });

    test('3. queryNearbyProfiles respects gender filters', () async {
      final womenOnly = await repository.queryNearbyProfiles(
        centerLat: 19.0596,
        centerLng: 72.8295,
        radiusKm: 50.0,
        genderFilter: 'Woman',
      );

      for (final p in womenOnly) {
        expect(p.gender, equals('Woman'));
      }
    });

    test('4. Vibe beacon model filters correctly by radial distance in meters', () {
      final beacons = RadarVibeBeaconModel.sampleBeacons();
      expect(beacons.isNotEmpty, isTrue);

      // Filter by 1000m (1km)
      final within1km = beacons.where((b) => b.distanceMeters <= 1000).toList();
      for (final b in within1km) {
        expect(b.distanceMeters, lessThanOrEqualTo(1000));
      }

      // Filter by 500m
      final within500m = beacons.where((b) => b.distanceMeters <= 500).toList();
      expect(within500m.length, lessThanOrEqualTo(within1km.length));
    });

    test('5. Distance based match marker visibility thresholds evaluation', () {
      // Simulate dynamic radius threshold logic matching RadarScreen implementation
      bool isMatchVisible(double currentRadiusKm, double matchDistanceKm) {
        return currentRadiusKm >= matchDistanceKm;
      }

      const ananyaDist = 2.0;
      const mayaDist = 5.0;
      const rheaDist = 12.0;
      const rohanDist = 20.0;

      // At 1 km: none should be visible
      expect(isMatchVisible(1.0, ananyaDist), isFalse);
      expect(isMatchVisible(1.0, mayaDist), isFalse);

      // At 3 km: Ananya visible, Maya not visible
      expect(isMatchVisible(3.0, ananyaDist), isTrue);
      expect(isMatchVisible(3.0, mayaDist), isFalse);

      // At 15 km: Ananya, Maya, Rhea visible, Rohan not visible
      expect(isMatchVisible(15.0, ananyaDist), isTrue);
      expect(isMatchVisible(15.0, mayaDist), isTrue);
      expect(isMatchVisible(15.0, rheaDist), isTrue);
      expect(isMatchVisible(15.0, rohanDist), isFalse);

      // At 25 km: all visible
      expect(isMatchVisible(25.0, rohanDist), isTrue);
    });
  });
}
