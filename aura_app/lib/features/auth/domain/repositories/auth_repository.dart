import '../../data/models/user_document_model.dart';

/// Contract for Authentication & Firestore `/users` account document operations
abstract class AuthRepository {
  /// Stream of the current user's authenticated ID
  Stream<String?> authStateChanges();

  /// Gets the currently authenticated user document, if available
  Future<UserDocumentModel?> getCurrentUser();

  /// Creates or updates the `/users/{userId}` document in Cloud Firestore
  Future<void> createOrUpdateUserDocument(UserDocumentModel user);

  /// Retrieves a user document by userId
  Future<UserDocumentModel?> getUserDocument(String userId);

  /// Updates heartbeat/last active timestamp
  Future<void> updateLastActive(String userId);

  /// Sends real SMS OTP to international E.164 phone number (+1 for Canada, +91 for India)
  Future<void> sendPhoneOtp(String e164Number);

  /// Verifies SMS OTP code and returns authentication success
  Future<bool> verifyPhoneOtp(String e164Number, String smsCode);

  /// Signs the user out from Firebase / local session
  /// Authenticates using a 12-word mnemonic phrase (or hex key) against /users/{userId}/auth_key_hash
  Future<UserDocumentModel?> signInWithSecretKey(String mnemonic);

  Future<void> signOut();
}
