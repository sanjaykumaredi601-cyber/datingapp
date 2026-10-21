import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a User Account document in Firestore `/users/{userId}`
/// Strictest compliance with firestore.rules: requires phone, createdAt, isPhoneVerified
class UserDocumentModel {
  final String userId;
  final String phone;
  final String? email;
  final String? displayName;
  final String? name;
  final String? gender;
  final DateTime? birthdate;
  final int? age;
  final String? bio;
  final String? voiceNoteUrl;
  final List<String> photos;
  final bool isPhoneVerified;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final DateTime? updatedAt;
  final String authProvider;
  final String? authKeyHash;
  final String? sovereignAddress;
  final String? westernSunSign;
  final String? vedicMoonSign;
  final String? birthCity;

  const UserDocumentModel({
    required this.userId,
    required this.phone,
    this.email,
    this.displayName,
    this.name,
    this.gender,
    this.birthdate,
    this.age,
    this.bio,
    this.voiceNoteUrl,
    this.photos = const [],
    this.isPhoneVerified = true,
    required this.createdAt,
    required this.lastActiveAt,
    this.updatedAt,
    this.authProvider = 'phone',
    this.authKeyHash,
    this.sovereignAddress,
    this.westernSunSign,
    this.vedicMoonSign,
    this.birthCity,
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'phone': phone,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (name != null || displayName != null) 'name': name ?? displayName,
      if (gender != null) 'gender': gender,
      if (birthdate != null) ...{
        'birthdate': Timestamp.fromDate(birthdate!),
        'birthDate': Timestamp.fromDate(birthdate!),
      },
      if (age != null) 'age': age,
      if (bio != null) 'bio': bio,
      if (voiceNoteUrl != null) ...{
        'voiceNoteUrl': voiceNoteUrl,
        'introMediaUrl': voiceNoteUrl,
      },
      if (photos.isNotEmpty) ...{
        'photos': photos,
        'photoUrls': photos,
      },
      'isPhoneVerified': isPhoneVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? lastActiveAt),
      'authProvider': authProvider,
      if (authKeyHash != null) 'auth_key_hash': authKeyHash,
      if (sovereignAddress != null) 'sovereign_address': sovereignAddress,
      if (westernSunSign != null) 'western_sun_sign': westernSunSign,
      if (vedicMoonSign != null) 'vedic_moon_sign': vedicMoonSign,
      if (birthCity != null) 'birth_city': birthCity,
    };
  }

  factory UserDocumentModel.fromMap(Map<String, dynamic> data, {String? docId}) {
    return UserDocumentModel.fromFirestoreMap(docId ?? data['userId'] as String? ?? '', data);
  }

  factory UserDocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserDocumentModel.fromFirestoreMap(doc.id, data);
  }

  factory UserDocumentModel.fromFirestoreMap(String docId, Map<String, dynamic> data) {
    final photosList = <String>[];
    if (data['photos'] is List) {
      photosList.addAll((data['photos'] as List).map((e) => e.toString()));
    } else if (data['photoUrls'] is List) {
      photosList.addAll((data['photoUrls'] as List).map((e) => e.toString()));
    }

    DateTime? parsedBirthdate;
    if (data['birthdate'] is Timestamp) {
      parsedBirthdate = (data['birthdate'] as Timestamp).toDate();
    } else if (data['birthDate'] is Timestamp) {
      parsedBirthdate = (data['birthDate'] as Timestamp).toDate();
    } else if (data['birthDate'] is String) {
      parsedBirthdate = DateTime.tryParse(data['birthDate'] as String);
    }

    return UserDocumentModel(
      userId: data['userId'] as String? ?? docId,
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      name: data['name'] as String? ?? data['displayName'] as String?,
      gender: data['gender'] as String?,
      birthdate: parsedBirthdate,
      age: (data['age'] as num?)?.toInt(),
      bio: data['bio'] as String?,
      voiceNoteUrl: data['voiceNoteUrl'] as String? ?? data['introMediaUrl'] as String?,
      photos: photosList,
      isPhoneVerified: data['isPhoneVerified'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      authProvider: data['authProvider'] as String? ?? 'phone',
      authKeyHash: data['auth_key_hash'] as String?,
      sovereignAddress: data['sovereign_address'] as String?,
      westernSunSign: data['western_sun_sign'] as String?,
      vedicMoonSign: data['vedic_moon_sign'] as String?,
      birthCity: data['birth_city'] as String?,
    );
  }

  UserDocumentModel copyWith({
    String? displayName,
    String? email,
    bool? isPhoneVerified,
    DateTime? lastActiveAt,
    String? authProvider,
    String? authKeyHash,
    String? sovereignAddress,
    String? westernSunSign,
    String? vedicMoonSign,
    String? birthCity,
  }) {
    return UserDocumentModel(
      userId: userId,
      phone: phone,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      authProvider: authProvider ?? this.authProvider,
      authKeyHash: authKeyHash ?? this.authKeyHash,
      sovereignAddress: sovereignAddress ?? this.sovereignAddress,
      westernSunSign: westernSunSign ?? this.westernSunSign,
      vedicMoonSign: vedicMoonSign ?? this.vedicMoonSign,
      birthCity: birthCity ?? this.birthCity,
    );
  }
}
