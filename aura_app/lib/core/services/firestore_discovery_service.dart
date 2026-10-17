import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Comprehensive Data Model representing a candidate user profile fetched from Firestore `/users`
class DatingCandidateProfile {
  final String userId;
  final String displayName;
  final int age;
  final DateTime? birthDate;
  final String gender;
  final String interestedIn;
  final String relationshipGoal;
  final String occupation;
  final String bio;
  final String locationName;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final List<String> hobbies;
  final Map<String, String> prompts;
  final String? introMediaUrl;
  final bool isVerified;
  final double distanceKm;
  final int matchScore;
  final List<String> commonHobbies;

  const DatingCandidateProfile({
    required this.userId,
    required this.displayName,
    required this.age,
    this.birthDate,
    required this.gender,
    required this.interestedIn,
    this.relationshipGoal = 'Long-term connection',
    this.occupation = 'Creative Professional',
    this.bio = '',
    this.locationName = 'Nearby District',
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.hobbies,
    this.prompts = const {},
    this.introMediaUrl,
    this.isVerified = true,
    this.distanceKm = 1.5,
    this.matchScore = 80,
    this.commonHobbies = const [],
  });

  DatingCandidateProfile copyWith({
    String? userId,
    String? displayName,
    int? age,
    DateTime? birthDate,
    String? gender,
    String? interestedIn,
    String? relationshipGoal,
    String? occupation,
    String? bio,
    String? locationName,
    double? latitude,
    double? longitude,
    List<String>? photos,
    List<String>? hobbies,
    Map<String, String>? prompts,
    String? introMediaUrl,
    bool? isVerified,
    double? distanceKm,
    int? matchScore,
    List<String>? commonHobbies,
  }) {
    return DatingCandidateProfile(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      relationshipGoal: relationshipGoal ?? this.relationshipGoal,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photos: photos ?? this.photos,
      hobbies: hobbies ?? this.hobbies,
      prompts: prompts ?? this.prompts,
      introMediaUrl: introMediaUrl ?? this.introMediaUrl,
      isVerified: isVerified ?? this.isVerified,
      distanceKm: distanceKm ?? this.distanceKm,
      matchScore: matchScore ?? this.matchScore,
      commonHobbies: commonHobbies ?? this.commonHobbies,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': userId,
      'userId': userId,
      'displayName': displayName,
      'age': age,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'gender': gender,
      'interestedIn': interestedIn,
      'relationshipGoal': relationshipGoal,
      'occupation': occupation,
      'bio': bio,
      'locationName': locationName,
      'location': GeoPoint(latitude, longitude),
      'latitude': latitude,
      'longitude': longitude,
      'photoUrls': photos,
      'photos': photos,
      'photoUrl': photos.isNotEmpty ? photos.first : '',
      'hobbies': hobbies,
      'prompts': prompts,
      'introMediaUrl': introMediaUrl,
      'isVerified': isVerified,
      'isProfileCompleted': true,
      'isProfileComplete': true,
    };
  }

  factory DatingCandidateProfile.fromFirestore(
    DocumentSnapshot doc, {
    required double centerLat,
    required double centerLng,
    required List<String> currentUserHobbies,
  }) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final uid = data['uid'] as String? ?? data['userId'] as String? ?? doc.id;
    final name = data['displayName'] as String? ?? 'Aura User';
    final age = (data['age'] as num?)?.toInt() ?? 24;

    DateTime? bDate;
    if (data['birthDate'] is Timestamp) {
      bDate = (data['birthDate'] as Timestamp).toDate();
    } else if (data['birthDate'] is String) {
      bDate = DateTime.tryParse(data['birthDate'] as String);
    }

    final gender = data['gender'] as String? ?? 'Woman';
    final interestedIn = data['interestedIn'] as String? ?? 'Everyone';
    final relationshipGoal = data['relationshipGoal'] as String? ?? 'Long-term connection';
    final bio = data['bio'] as String? ?? (data['about'] as String? ?? '');
    final occupation = data['occupation'] as String? ?? (data['job'] as String? ?? 'Creative Professional');
    final locationName = data['locationName'] as String? ?? 'Nearby';

    // Parse coordinates
    double lat = centerLat + 0.005;
    double lng = centerLng + 0.005;
    if (data['location'] is GeoPoint) {
      final gp = data['location'] as GeoPoint;
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (data['latitude'] is num && data['longitude'] is num) {
      lat = (data['latitude'] as num).toDouble();
      lng = (data['longitude'] as num).toDouble();
    }

    // Parse photos
    List<String> photosList = [];
    if (data['photoUrls'] is List) {
      photosList = List<String>.from(data['photoUrls'] as List);
    } else if (data['photos'] is List) {
      photosList = List<String>.from(data['photos'] as List);
    }
    if (photosList.isEmpty && data['photoUrl'] is String && (data['photoUrl'] as String).isNotEmpty) {
      photosList.add(data['photoUrl'] as String);
    }
    if (photosList.isEmpty) {
      photosList = [
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&auto=format&fit=crop&q=80',
      ];
    }

    // Parse hobbies
    List<String> hobbiesList = [];
    if (data['hobbies'] is List) {
      hobbiesList = List<String>.from(data['hobbies'] as List);
    } else if (data['passions'] is List) {
      hobbiesList = List<String>.from(data['passions'] as List);
    }

    // Parse prompts
    Map<String, String> promptsMap = {};
    if (data['prompts'] is Map) {
      final rawPrompts = data['prompts'] as Map;
      rawPrompts.forEach((k, v) {
        if (k != null && v != null) {
          promptsMap[k.toString()] = v.toString();
        }
      });
    }

    final introMediaUrl = data['introMediaUrl'] as String?;
    final isVerified = data['isVerified'] as bool? ?? true;

    // Calculate distance
    final distMeters = Geolocator.distanceBetween(centerLat, centerLng, lat, lng);
    final distanceKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));

    // Calculate hobby compatibility
    final (score, common) = FirestoreDiscoveryService.calculateCompatibility(
      currentUserHobbies: currentUserHobbies,
      candidateHobbies: hobbiesList,
      seedUid: uid,
    );

    return DatingCandidateProfile(
      userId: uid,
      displayName: name,
      age: age,
      birthDate: bDate,
      gender: gender,
      interestedIn: interestedIn,
      relationshipGoal: relationshipGoal,
      occupation: occupation,
      bio: bio.isNotEmpty ? bio : 'Living life one sunset and good coffee at a time ☕🌅',
      locationName: locationName,
      latitude: lat,
      longitude: lng,
      photos: photosList,
      hobbies: hobbiesList,
      prompts: promptsMap,
      introMediaUrl: introMediaUrl,
      isVerified: isVerified,
      distanceKm: distanceKm,
      matchScore: score,
      commonHobbies: common,
    );
  }
}

/// Service that connects the Radar and Discover screens with real Firestore user profiles.
class FirestoreDiscoveryService {
  static final FirestoreDiscoveryService _instance = FirestoreDiscoveryService._internal();
  factory FirestoreDiscoveryService() => _instance;
  FirestoreDiscoveryService._internal();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  FirebaseFirestore get firestore {
    try {
      _firestore ??= FirebaseFirestore.instance;
      return _firestore!;
    } catch (_) {
      rethrow;
    }
  }

  FirebaseAuth get auth {
    try {
      _auth ??= FirebaseAuth.instance;
      return _auth!;
    } catch (_) {
      rethrow;
    }
  }

  @visibleForTesting
  set firestore(FirebaseFirestore instance) => _firestore = instance;

  @visibleForTesting
  set auth(FirebaseAuth instance) => _auth = instance;

  /// Calculates dynamic hobby compatibility percentage and overlapping tags:
  /// - Overlapping tags: intersection between candidate and current user hobbies.
  /// - Formula scales realistically: 50% baseline + (overlap fraction * 42%) + hash jitter.
  static (int, List<String>) calculateCompatibility({
    required List<String> currentUserHobbies,
    required List<String> candidateHobbies,
    String seedUid = '',
  }) {
    if (currentUserHobbies.isEmpty || candidateHobbies.isEmpty) {
      final fallbackScore = 65 + (seedUid.hashCode.abs() % 15);
      return (fallbackScore.clamp(55, 88), <String>[]);
    }

    final userSet = currentUserHobbies.map((e) => e.trim().toLowerCase()).toSet();
    final common = candidateHobbies.where((h) => userSet.contains(h.trim().toLowerCase())).toList();

    final overlapFraction = common.length / math.max(currentUserHobbies.length, 1);
    final bonus = (overlapFraction * 44).round();
    final hashJitter = (seedUid.hashCode.abs() % 5);
    final score = (52 + bonus + hashJitter).clamp(52, 98);

    return (score, common);
  }

  /// Checks if candidate's gender matches the user's `interestedIn` preference
  static bool matchesGenderFilter({
    required String? userInterestedIn,
    required String candidateGender,
  }) {
    if (userInterestedIn == null || userInterestedIn.isEmpty) return true;
    final pref = userInterestedIn.trim().toLowerCase();
    final cand = candidateGender.trim().toLowerCase();

    if (pref == 'everyone' || pref == 'all') return true;
    if (pref == 'men' || pref == 'man') {
      return cand == 'man' || cand == 'men';
    }
    if (pref == 'women' || pref == 'woman') {
      return cand == 'woman' || cand == 'women';
    }
    return cand == pref;
  }

  /// Fetches nearby user profiles from Firestore `users` collection:
  /// 1. Excludes current logged-in user (`currentUser.uid`).
  /// 2. Filters by candidate's `gender` matching current user's `interestedIn`.
  /// 3. Filters candidates within `radiusKm` based on coordinates vs GeoPoint.
  /// 4. Calculates dynamic hobby compatibility score (e.g. 88% Match).
  /// 5. Gracefully falls back to high-fidelity seed profiles if Firestore query is empty or offline.
  Future<List<DatingCandidateProfile>> fetchNearbyUsers({
    User? currentUser,
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    String? overrideInterestedIn,
    List<String>? overrideHobbies,
    int limit = 30,
  }) async {
    final effectiveUser = currentUser ?? auth.currentUser;
    final currentUid = effectiveUser?.uid ?? '';

    // 1. Fetch current user profile to determine their interestedIn and hobbies
    String effectiveInterestedIn = overrideInterestedIn ?? 'Everyone';
    List<String> effectiveHobbies = overrideHobbies ?? [
      'Architecture',
      'Specialty Coffee',
      'Vinyl Records',
      'Art Galleries',
      'Trekking',
    ];

    if (effectiveUser != null && (overrideInterestedIn == null || overrideHobbies == null)) {
      try {
        final currentDoc = await firestore.collection('users').doc(effectiveUser.uid).get();
        if (currentDoc.exists && currentDoc.data() != null) {
          final data = currentDoc.data()!;
          if (overrideInterestedIn == null && data['interestedIn'] != null) {
            effectiveInterestedIn = data['interestedIn'].toString();
          }
          if (overrideHobbies == null && data['hobbies'] is List) {
            effectiveHobbies = List<String>.from(data['hobbies'] as List);
          }
        }
      } catch (e) {
        debugPrint('[FirestoreDiscoveryService] Current user fetch note: $e');
      }
    }

    final List<DatingCandidateProfile> candidates = [];

    // 2. Fetch candidates from Firestore
    try {
      final usersSnapshot = await firestore
          .collection('users')
          .limit(60)
          .get()
          .timeout(const Duration(seconds: 3));

      for (final doc in usersSnapshot.docs) {
        if (doc.id == currentUid) continue; // Task 1: Exclude current logged-in user

        final profile = DatingCandidateProfile.fromFirestore(
          doc,
          centerLat: centerLat,
          centerLng: centerLng,
          currentUserHobbies: effectiveHobbies,
        );

        // Task 2a: Gender filter
        if (!matchesGenderFilter(
          userInterestedIn: effectiveInterestedIn,
          candidateGender: profile.gender,
        )) {
          continue;
        }

        // Task 2b: Discovery radius distance filter
        if (profile.distanceKm <= radiusKm) {
          candidates.add(profile);
        }
      }
    } catch (e) {
      debugPrint('[FirestoreDiscoveryService] Firestore query fallback: $e');
    }

    // Only return real nearby users from Firestore database; no mock/dummy profiles

    // Sort by compatibility score descending, then distance ascending
    candidates.sort((a, b) {
      final compCmp = b.matchScore.compareTo(a.matchScore);
      if (compCmp != 0) return compCmp;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return candidates.take(limit).toList();
  }

  /// High quality seed profiles for offline resilience, testing, and initial demo delight
  static List<DatingCandidateProfile> getSampleSeedProfiles({
    double centerLat = 19.0596,
    double centerLng = 72.8295,
  }) {
    return [
      DatingCandidateProfile(
        userId: 'cand_ananya_01',
        displayName: 'Ananya Sharma',
        age: 24,
        birthDate: DateTime(2002, 4, 12),
        gender: 'Woman',
        interestedIn: 'Men',
        relationshipGoal: 'Meaningful connection',
        occupation: 'Architect & Designer',
        bio: 'Architect by day, vinyl collector by night. Let\'s get iced matcha and talk about Brutalist buildings ☕✨',
        locationName: 'Cultural Arts District',
        latitude: centerLat + 0.008, // ~1.2 km away
        longitude: centerLng - 0.006,
        distanceKm: 1.2,
        matchScore: 88,
        photos: const [
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&auto=format&fit=crop&q=80',
        ],
        hobbies: const ['Architecture', 'Vinyl Records', 'Specialty Coffee', 'Art Galleries', 'Trekking'],
        prompts: const {
          'A fun fact about me...': 'I can identify the architect behind almost any iconic building in South Bombay blindfolded.',
          'My ideal Sunday...': 'Slow pour-over coffee, vinyl spinning in the background, and discovering a hidden courtyard garden.',
        },
        introMediaUrl: 'https://example.com/audio/ananya_intro.m4a',
        isVerified: true,
      ),
      DatingCandidateProfile(
        userId: 'cand_maya_02',
        displayName: 'Maya Lin',
        age: 26,
        birthDate: DateTime(2000, 8, 21),
        gender: 'Woman',
        interestedIn: 'Everyone',
        relationshipGoal: 'Long-term connection',
        occupation: 'Visual Director & Photographer',
        bio: 'Shooting 35mm film across the world. Looking for someone who appreciates spontaneous road trips and golden hour light 📸🌿',
        locationName: 'Khar, Mumbai',
        latitude: centerLat + 0.015, // ~2.8 km away
        longitude: centerLng + 0.012,
        distanceKm: 2.8,
        matchScore: 82,
        photos: const [
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&auto=format&fit=crop&q=80',
        ],
        hobbies: const ['Photography', 'Vinyl Records', 'Indie Films', 'Specialty Coffee', 'Bouldering'],
        prompts: const {
          'You should leave a note if...': 'You know where to find the crispiest sourdough croissants in the city.',
          'Together we could...': 'Build a darkroom and print black-and-white portraits of street cats.',
        },
        introMediaUrl: 'https://example.com/audio/maya_intro.m4a',
        isVerified: true,
      ),
      DatingCandidateProfile(
        userId: 'cand_rhea_03',
        displayName: 'Rhea Mehta',
        age: 25,
        birthDate: DateTime(2001, 1, 15),
        gender: 'Woman',
        interestedIn: 'Men',
        relationshipGoal: 'Casual yet real',
        occupation: 'Ceramicist & Sculptor',
        bio: 'My hands are usually covered in clay. Let\'s bake sourdough, drink orange wine, and talk philosophy 🪴🍯',
        locationName: 'Juhu, Mumbai',
        latitude: centerLat - 0.018, // ~3.5 km away
        longitude: centerLng - 0.014,
        distanceKm: 3.5,
        matchScore: 79,
        photos: const [
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=800&auto=format&fit=crop&q=80',
        ],
        hobbies: const ['Ceramics', 'Houseplants', 'Bouldering', 'Thrifting', 'Specialty Coffee'],
        prompts: const {
          'The key to my heart is...': 'A playlist that seamlessly transitions from ambient electronica to indie jazz.',
        },
        introMediaUrl: 'https://example.com/audio/rhea_intro.m4a',
        isVerified: true,
      ),
      DatingCandidateProfile(
        userId: 'cand_rohan_04',
        displayName: 'Rohan Verma',
        age: 27,
        birthDate: DateTime(1999, 11, 30),
        gender: 'Man',
        interestedIn: 'Women',
        relationshipGoal: 'Long-term partner',
        occupation: 'Creative Technologist',
        bio: 'Synthesizers, generative AI art, and nighttime cycling along coastal roads. Tell me your favorite sci-fi book 🚲🌌',
        locationName: 'BKC, Mumbai',
        latitude: centerLat + 0.022, // ~4.6 km away
        longitude: centerLng + 0.024,
        distanceKm: 4.6,
        matchScore: 84,
        photos: const [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&auto=format&fit=crop&q=80',
        ],
        hobbies: const ['Electronic Music', 'Indie Films', 'Cycling', 'Specialty Coffee', 'Tech'],
        prompts: const {
          'A life goal of mine...': 'Building an interactive sound installation that responds to ocean waves.',
        },
        introMediaUrl: 'https://example.com/audio/rohan_intro.m4a',
        isVerified: true,
      ),
      DatingCandidateProfile(
        userId: 'cand_kabir_05',
        displayName: 'Kabir Mehta',
        age: 28,
        birthDate: DateTime(1998, 6, 18),
        gender: 'Man',
        interestedIn: 'Everyone',
        relationshipGoal: 'Meaningful connection',
        occupation: 'Sound Designer',
        bio: 'Analog synths and acoustic experiments. Never skipping opening credits of independent cinema 🎧🎬',
        locationName: 'Pali Hill, Mumbai',
        latitude: centerLat + 0.010, // ~1.8 km away
        longitude: centerLng + 0.008,
        distanceKm: 1.8,
        matchScore: 76,
        photos: const [
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&auto=format&fit=crop&q=80',
        ],
        hobbies: const ['Electronic Music', 'Indie Films', 'Pour Over', 'Analog Synths'],
        prompts: const {
          'Two truths and a lie...': 'I own 40 vintage synth modules, I’ve never eaten sushi, I once DJed in an abandoned church.',
        },
        introMediaUrl: 'https://example.com/audio/kabir_intro.m4a',
        isVerified: true,
      ),
      DatingCandidateProfile(
        userId: 'cand_tara_06',
        displayName: 'Tara Singhania',
        age: 25,
        birthDate: DateTime(2001, 7, 9),
        gender: 'Woman',
        interestedIn: 'Men',
        relationshipGoal: 'Coffee dates & exploring',
        occupation: 'Food Writer & Curator',
        bio: 'Curating culinary pop-ups and tracking down the best street dosa in town. Sourdough enthusiast 🥞🥂',
        locationName: 'Worli, Mumbai',
        latitude: centerLat - 0.035, // ~6.2 km away
        longitude: centerLng - 0.010,
        distanceKm: 6.2,
        matchScore: 74,
        photos: const [
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80',
        ],
        hobbies: const ['Foodie', 'Specialty Coffee', 'Art Galleries', 'Thrifting'],
        prompts: const {
          'My simple pleasures...': 'Crispy sourdough with cultured butter and a double espresso on a rainy afternoon.',
        },
        introMediaUrl: 'https://example.com/audio/tara_intro.m4a',
        isVerified: false,
      ),
    ];
  }
}
