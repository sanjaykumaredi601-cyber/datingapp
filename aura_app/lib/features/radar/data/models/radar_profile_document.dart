import 'package:aura_app/core/utils/geohash_helper.dart';

/// Data model representing a Public Profile document in Firestore `/profiles/{userId}`
/// Strictly adheres to firestore.rules:
/// - requires displayName.size() >= 2
/// - requires photos list size between 2 and 6
class RadarProfileDocument {
  final String userId;
  final String displayName;
  final int age;
  final DateTime birthDate;
  final String gender;
  final String interestedIn;
  final List<String> photos;
  final String bio;
  final List<String> passions;
  final List<String> lifestyleTags;
  final double latitude;
  final double longitude;
  final String geohash;
  final bool isVerified;
  final double? distanceKm;
  final int? matchScore;
  final DateTime updatedAt;

  RadarProfileDocument({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.birthDate,
    this.gender = 'Woman',
    this.interestedIn = 'Men',
    required this.photos,
    this.bio = '',
    this.passions = const [],
    this.lifestyleTags = const [],
    required this.latitude,
    required this.longitude,
    String? geohash,
    this.isVerified = false,
    this.distanceKm,
    this.matchScore,
    DateTime? updatedAt,
  })  : geohash = geohash ?? GeoHashHelper.obfuscateTo500mGeohash(latitude, longitude),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'age': age,
      'birthDate': birthDate.toIso8601String(),
      'gender': gender,
      'interestedIn': interestedIn,
      'photos': photos,
      'bio': bio,
      'passions': passions,
      'lifestyleTags': lifestyleTags,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'isVerified': isVerified,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RadarProfileDocument.fromMap(Map<String, dynamic> map, {String? docId}) {
    final lat = (map['latitude'] as num?)?.toDouble() ?? 19.0596;
    final lon = (map['longitude'] as num?)?.toDouble() ?? 72.8295;
    final bDate = map['birthDate'] != null
        ? DateTime.tryParse(map['birthDate'].toString()) ?? DateTime(2000, 1, 1)
        : DateTime(2000, 1, 1);

    return RadarProfileDocument(
      userId: docId ?? map['userId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Anonymous',
      age: (map['age'] as num?)?.toInt() ?? (DateTime.now().year - bDate.year),
      birthDate: bDate,
      gender: map['gender'] as String? ?? 'Woman',
      interestedIn: map['interestedIn'] as String? ?? 'Men',
      photos: List<String>.from(map['photos'] as List? ?? [
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9',
      ]),
      bio: map['bio'] as String? ?? '',
      passions: List<String>.from(map['passions'] as List? ?? []),
      lifestyleTags: List<String>.from(map['lifestyleTags'] as List? ?? []),
      latitude: lat,
      longitude: lon,
      geohash: map['geohash'] as String? ?? GeoHashHelper.obfuscateTo500mGeohash(lat, lon),
      isVerified: map['isVerified'] as bool? ?? false,
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      matchScore: (map['matchScore'] as num?)?.toInt(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  RadarProfileDocument copyWithDistance({double? distanceKm, int? matchScore}) {
    return RadarProfileDocument(
      userId: userId,
      displayName: displayName,
      age: age,
      birthDate: birthDate,
      gender: gender,
      interestedIn: interestedIn,
      photos: photos,
      bio: bio,
      passions: passions,
      lifestyleTags: lifestyleTags,
      latitude: latitude,
      longitude: longitude,
      geohash: geohash,
      isVerified: isVerified,
      distanceKm: distanceKm ?? this.distanceKm,
      matchScore: matchScore ?? this.matchScore,
      updatedAt: updatedAt,
    );
  }
}
