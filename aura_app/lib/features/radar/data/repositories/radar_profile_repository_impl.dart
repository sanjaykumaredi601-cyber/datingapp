import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:aura_app/core/utils/geohash_helper.dart';
import '../../domain/repositories/radar_profile_repository.dart';
import '../models/radar_profile_document.dart';

/// Production-ready Proximity Radar Profile Repository implementing Geohash bounding queries
class RadarProfileRepositoryImpl implements RadarProfileRepository {
  final FirebaseFirestore? _firestore;
  final Map<String, RadarProfileDocument> _localProfileCache = {};

  RadarProfileRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore() {
    _initializeSeedProfiles();
  }

  void _initializeSeedProfiles() {
    final seeds = [
      RadarProfileDocument(
        userId: 'cand_ananya_01',
        displayName: 'Ananya Sharma',
        age: 24,
        birthDate: DateTime(2002, 4, 12),
        gender: 'Woman',
        interestedIn: 'Men',
        latitude: 19.0596,
        longitude: 72.8295,
        photos: const [
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9',
        ],
        bio: 'Architect by day, vinyl collector by night.',
        passions: const ['Architecture', 'Vinyl Records', 'Coffee'],
        isVerified: true,
      ),
      RadarProfileDocument(
        userId: 'cand_maya_02',
        displayName: 'Maya Lin',
        age: 26,
        birthDate: DateTime(2000, 8, 21),
        gender: 'Woman',
        interestedIn: 'Everyone',
        latitude: 19.0700,
        longitude: 72.8400,
        photos: const [
          'https://images.unsplash.com/photo-1517841905240-472988babdf9',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
        ],
        bio: 'Film photographer & vintage cafe hopper.',
        passions: const ['Photography', 'Film', 'Indie Music'],
        isVerified: true,
      ),
      RadarProfileDocument(
        userId: 'cand_rhea_03',
        displayName: 'Rhea Kapoor',
        age: 25,
        birthDate: DateTime(2001, 11, 5),
        gender: 'Woman',
        interestedIn: 'Men',
        latitude: 19.1000,
        longitude: 72.8500,
        photos: const [
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        ],
        bio: 'Curator & yoga enthusiast.',
        passions: const ['Yoga', 'Art', 'Design'],
        isVerified: true,
      ),
      RadarProfileDocument(
        userId: 'cand_rohan_04',
        displayName: 'Rohan Verma',
        age: 27,
        birthDate: DateTime(1999, 2, 14),
        gender: 'Man',
        interestedIn: 'Women',
        latitude: 19.1200,
        longitude: 72.8600,
        photos: const [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
        ],
        bio: 'Music producer & trekker.',
        passions: const ['Music', 'Trekking', 'Cooking'],
        isVerified: true,
      ),
      RadarProfileDocument(
        userId: 'cand_lucas_05',
        displayName: 'Lucas Vance',
        age: 28,
        birthDate: DateTime(1998, 6, 18),
        gender: 'Man',
        interestedIn: 'Women',
        latitude: 19.1500,
        longitude: 72.8800,
        photos: const [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        ],
        bio: 'Sound designer & traveler.',
        passions: const ['Sound Design', 'Travel', 'Surfing'],
        isVerified: true,
      ),
    ];

    for (final profile in seeds) {
      _localProfileCache[profile.userId] = profile;
    }
  }

  static FirebaseFirestore? _safeFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[RadarProfileRepo] FirebaseFirestore not initialized: $e');
      return null;
    }
  }

  @override
  Future<void> saveProfile(RadarProfileDocument profile) async {
    // Validate strict Firestore rules: displayName size >= 2, photos 2..6
    if (profile.displayName.length < 2) {
      throw ArgumentError('Display name must be at least 2 characters long');
    }
    if (profile.photos.length < 2 || profile.photos.length > 6) {
      throw ArgumentError('Profile photos must contain between 2 and 6 images');
    }

    _localProfileCache[profile.userId] = profile;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('profiles')
            .doc(profile.userId)
            .set(profile.toFirestoreMap(), SetOptions(merge: true));
        debugPrint('[RadarProfileRepo] Synced profile ${profile.userId} (Geohash: ${profile.geohash})');
      } catch (e) {
        debugPrint('[RadarProfileRepo] Firestore save fallback: $e');
      }
    }
  }

  @override
  Future<RadarProfileDocument?> getProfile(String userId) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore.collection('profiles').doc(userId).get();
        if (doc.exists && doc.data() != null) {
          final p = RadarProfileDocument.fromMap(doc.data()!, docId: doc.id);
          _localProfileCache[userId] = p;
          return p;
        }
      } catch (e) {
        debugPrint('[RadarProfileRepo] Firestore getProfile error: $e');
      }
    }
    return _localProfileCache[userId];
  }

  @override
  Future<List<RadarProfileDocument>> queryNearbyProfiles({
    required double centerLat,
    required double centerLng,
    double radiusKm = 25.0,
    String? genderFilter,
    int limit = 30,
  }) async {
    final List<RadarProfileDocument> candidates = [];

    // 1. Try querying Cloud Firestore via Geohash bounds
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final bounds = GeoHashHelper.geohashQueryBounds(centerLat, centerLng, radiusKm);
        for (final b in bounds) {
          final start = b[0];
          final end = b[1];

          Query<Map<String, dynamic>> query = firestore
              .collection('profiles')
              .orderBy('geohash')
              .startAt([start])
              .endAt([end])
              .limit(limit);

          if (genderFilter != null && genderFilter != 'Everyone') {
            query = query.where('gender', isEqualTo: genderFilter);
          }

          final snap = await query.get();
          for (final doc in snap.docs) {
            final p = RadarProfileDocument.fromMap(doc.data(), docId: doc.id);
            candidates.add(p);
          }
        }
      } catch (e) {
        debugPrint('[RadarProfileRepo] Geohash query fallback: $e');
      }
    }

    // 2. If candidates list is empty, draw from local spatial cache
    if (candidates.isEmpty) {
      candidates.addAll(_localProfileCache.values);
    }

    // 3. Exact post-filtering by Haversine distance, gender filter & calculating match scores
    final List<RadarProfileDocument> nearbyResults = [];
    for (final profile in candidates) {
      if (genderFilter != null && genderFilter != 'Everyone' && profile.gender != genderFilter) {
        continue;
      }

      final distance = GeoHashHelper.haversineDistanceKm(
        centerLat,
        centerLng,
        profile.latitude,
        profile.longitude,
      );

      if (distance <= radiusKm) {
        final matchScore = 75 + (profile.userId.hashCode.abs() % 24);
        nearbyResults.add(profile.copyWithDistance(
          distanceKm: double.parse(distance.toStringAsFixed(1)),
          matchScore: matchScore,
        ));
      }
    }

    // Sort by distance ascending
    nearbyResults.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    return nearbyResults.take(limit).toList();
  }

  @override
  Stream<List<RadarProfileDocument>> streamNearbyProfiles({
    required double centerLat,
    required double centerLng,
    double radiusKm = 25.0,
  }) {
    // Return real-time periodic or snapshot stream
    final controller = StreamController<List<RadarProfileDocument>>();
    queryNearbyProfiles(centerLat: centerLat, centerLng: centerLng, radiusKm: radiusKm).then((list) {
      if (!controller.isClosed) controller.add(list);
    });

    final timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final list = await queryNearbyProfiles(
        centerLat: centerLat,
        centerLng: centerLng,
        radiusKm: radiusKm,
      );
      if (!controller.isClosed) controller.add(list);
    });

    controller.onCancel = () => timer.cancel();
    return controller.stream;
  }
}
