import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for provisioning and maintaining user documents in Cloud Firestore `/users/{uid}`
/// triggered immediately upon successful Firebase Authentication sign-in.
class UserProvisioningService {
  static final UserProvisioningService _instance = UserProvisioningService._internal();
  factory UserProvisioningService() => _instance;
  UserProvisioningService._internal();

  FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore {
    try {
      _firestore ??= FirebaseFirestore.instance;
      return _firestore!;
    } catch (e) {
      debugPrint('[UserProvisioningService] FirebaseFirestore instance error: $e');
      rethrow;
    }
  }

  @visibleForTesting
  set firestore(FirebaseFirestore instance) => _firestore = instance;

  /// Checks if a user document exists in Firestore under `/users/{uid}`
  /// and whether their profile onboarding is marked as completed.
  Future<bool> checkUserExists(String uid) async {
    try {
      debugPrint('[UserProvisioningService] Checking if user doc exists for UID: $uid');
      final docRef = firestore.collection('users').doc(uid);
      final docSnapshot = await docRef.get().timeout(const Duration(seconds: 6));
      if (!docSnapshot.exists) {
        debugPrint('[UserProvisioningService] Document does not exist for UID: $uid');
        return false;
      }
      final data = docSnapshot.data();
      if (data == null) {
        debugPrint('[UserProvisioningService] Document data is empty for UID: $uid');
        return false;
      }
      final isCompleted = data['isProfileCompleted'] == true || data['isProfileComplete'] == true;
      debugPrint('[UserProvisioningService] User $uid exists. isProfileCompleted: $isCompleted');
      return isCompleted;
    } on TimeoutException {
      debugPrint('[UserProvisioningService] ⏱️ Timeout reading user doc for $uid. Proceeding responsive entry.');
      return true;
    } on FirebaseException catch (fe) {
      debugPrint('[UserProvisioningService] FirebaseException checking user: ${fe.code} - ${fe.message}');
      return true;
    } catch (e) {
      debugPrint('[UserProvisioningService] Error checking user existence: $e');
      return true;
    }
  }

  /// Updates only the `lastLoginAt` and `lastActiveAt` timestamps for an existing user.
  Future<bool> updateLastLogin(String uid) async {
    try {
      debugPrint('[UserProvisioningService] Updating lastLoginAt for UID: $uid');
      final docRef = firestore.collection('users').doc(uid);
      await docRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserProvisioningService] ✅ Successfully updated lastLoginAt for UID: $uid');
      return true;
    } on FirebaseException catch (fe) {
      debugPrint('[UserProvisioningService] FirebaseException updating lastLoginAt: ${fe.code} - ${fe.message}');
      return false;
    } catch (e) {
      debugPrint('[UserProvisioningService] Error updating lastLoginAt: $e');
      return false;
    }
  }

  /// Finalizes onboarding and creates the user document under `/users/{user.uid}`:
  /// 1. Updates `user.updateDisplayName(customName)` in FirebaseAuth.
  /// 2. Creates the Firestore document with uid, displayName, email, photoUrl,
  ///    isProfileCompleted: true, and timestamps.
  Future<bool> completeOnboarding({
    required User user,
    required String customDisplayName,
    String? customPhotoUrl,
    int? age,
    DateTime? birthDate,
    String? gender,
    String? interestedIn,
    String? relationshipGoal,
    List<String>? hobbies,
    dynamic prompts,
    List<String>? photoUrls,
    String? introMediaUrl,
    dynamic location,
  }) async {
    try {
      final trimmedName = customDisplayName.trim();
      debugPrint('[UserProvisioningService] Finalizing onboarding for UID: ${user.uid} with name "$trimmedName"...');

      // 1. Update FirebaseAuth displayName
      try {
        await user.updateDisplayName(trimmedName);
        final effectivePhoto = (photoUrls != null && photoUrls.isNotEmpty)
            ? photoUrls.first
            : customPhotoUrl;
        if (effectivePhoto != null && effectivePhoto.isNotEmpty) {
          await user.updatePhotoURL(effectivePhoto);
        }
        await user.reload();
        debugPrint('[UserProvisioningService] Updated FirebaseAuth display name to: $trimmedName');
      } catch (authError) {
        debugPrint('[UserProvisioningService] Warning: Could not update FirebaseAuth displayName: $authError');
      }

      // 2. Prepare Firestore document
      final docRef = firestore.collection('users').doc(user.uid);
      final now = FieldValue.serverTimestamp();

      final defaultPreferences = {
        'discoveryRadiusKm': 25,
        'ageRangeMin': 21,
        'ageRangeMax': 35,
        'genderPreference': (interestedIn != null && interestedIn.isNotEmpty)
            ? interestedIn.toLowerCase()
            : 'everyone',
        'notificationsEnabled': true,
        'ghostMode': false,
        'incognitoMode': false,
        'theme': 'dark',
        'preferredLanguages': ['en'],
      };

      final effectivePhotoUrl = (photoUrls != null && photoUrls.isNotEmpty)
          ? photoUrls.first
          : (customPhotoUrl ?? user.photoURL ?? '');

      final newUserData = <String, dynamic>{
        'uid': user.uid,
        'userId': user.uid,
        'displayName': trimmedName,
        'email': user.email ?? '',
        'photoUrl': effectivePhotoUrl,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
        if (age != null) 'age': age,
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
        if (gender != null) 'gender': gender,
        if (interestedIn != null) 'interestedIn': interestedIn,
        if (relationshipGoal != null) 'relationshipGoal': relationshipGoal,
        if (hobbies != null) 'hobbies': hobbies,
        if (prompts != null) 'prompts': prompts,
        if (introMediaUrl != null && introMediaUrl.isNotEmpty) 'introMediaUrl': introMediaUrl,
        if (location != null) 'location': location,
        'isProfileCompleted': true,
        'isProfileComplete': true,
        'createdAt': now,
        'lastLoginAt': now,
        'lastActiveAt': now,
        'authProvider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'google.com',
        'isEmailVerified': user.emailVerified,
        'isPhoneVerified': user.phoneNumber != null && user.phoneNumber!.isNotEmpty,
        if (user.phoneNumber != null) 'phone': user.phoneNumber,
        'preferences': defaultPreferences,
        // Flattened default preference fields for simple querying
        'discoveryRadiusKm': 25,
        'ageRangeMin': 21,
        'ageRangeMax': 35,
        'genderPreference': (interestedIn != null && interestedIn.isNotEmpty)
            ? interestedIn.toLowerCase()
            : 'everyone',
        'notificationsEnabled': true,
        'ghostMode': false,
        'incognitoMode': false,
        'theme': 'dark',
      };

      await docRef.set(newUserData, SetOptions(merge: true));
      debugPrint('[UserProvisioningService] ✅ Successfully created dating user document in Firestore: /users/${user.uid}');
      return true;
    } on FirebaseException catch (fe) {
      debugPrint('[UserProvisioningService] FirebaseException completing onboarding: ${fe.code} - ${fe.message}');
      return false;
    } catch (e, stack) {
      debugPrint('[UserProvisioningService] Unexpected error completing onboarding: $e\n$stack');
      return false;
    }
  }

  /// Legacy helper for provisioning user document directly if already completed
  Future<bool> provisionUser(User user) async {
    try {
      debugPrint('[UserProvisioningService] Checking document existence for UID: ${user.uid} in collection "users"...');
      final docRef = firestore.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint('[UserProvisioningService] Document does not exist. Creating new user document for UID: ${user.uid}...');
        final now = FieldValue.serverTimestamp();
        
        final defaultPreferences = {
          'discoveryRadiusKm': 25,
          'ageRangeMin': 21,
          'ageRangeMax': 35,
          'genderPreference': 'everyone',
          'notificationsEnabled': true,
          'ghostMode': false,
          'incognitoMode': false,
          'theme': 'dark',
          'preferredLanguages': ['en'],
        };

        final newUserData = <String, dynamic>{
          'uid': user.uid,
          'userId': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? 'Aura Member',
          'photoUrl': user.photoURL ?? '',
          'createdAt': now,
          'lastLoginAt': now,
          'lastActiveAt': now,
          'authProvider': user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'google.com',
          'isEmailVerified': user.emailVerified,
          'isPhoneVerified': user.phoneNumber != null && user.phoneNumber!.isNotEmpty,
          if (user.phoneNumber != null) 'phone': user.phoneNumber,
          'isProfileCompleted': true,
          'isProfileComplete': true,
          'preferences': defaultPreferences,
          'discoveryRadiusKm': 25,
          'ageRangeMin': 21,
          'ageRangeMax': 35,
          'genderPreference': 'everyone',
          'notificationsEnabled': true,
          'ghostMode': false,
          'incognitoMode': false,
          'theme': 'dark',
        };

        await docRef.set(newUserData, SetOptions(merge: true));
        debugPrint('[UserProvisioningService] ✅ Successfully created user document in Firestore: /users/${user.uid}');
      } else {
        debugPrint('[UserProvisioningService] Document already exists for UID: ${user.uid}. Updating lastLoginAt...');
        await docRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[UserProvisioningService] ✅ Successfully updated lastLoginAt for UID: ${user.uid}');
      }
      return true;
    } on FirebaseException catch (fe) {
      debugPrint('[UserProvisioningService] FirebaseException during user provisioning: code=${fe.code}, message=${fe.message}');
      return false;
    } catch (e, stack) {
      debugPrint('[UserProvisioningService] Unexpected error provisioning user document: $e\n$stack');
      return false;
    }
  }
}
