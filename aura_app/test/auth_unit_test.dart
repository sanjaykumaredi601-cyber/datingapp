// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aura_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aura_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aura_app/features/auth/data/models/user_document_model.dart';
import 'package:aura_app/core/services/google_auth_service.dart';

// ── Mocktail Mocks ──────────────────────────────────────────
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockOAuthCredential extends Mock implements OAuthCredential {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockFirebaseAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFlutterSecureStorage mockStorage;
  late MockUser mockUser;
  late AuthRepository authRepository;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockStorage = MockFlutterSecureStorage();
    mockUser = MockUser();

    when(() => mockUser.uid).thenReturn('usr_test_123');
    when(() => mockUser.email).thenReturn('qa.engineer@nextgenit.com');
    when(() => mockUser.displayName).thenReturn('NextGen QA Tester');
    when(() => mockUser.phoneNumber).thenReturn('+919876543210');

    // Default secure storage stubs
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async => {});
    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async => {});

    authRepository = AuthRepositoryImpl(
      firebaseAuth: mockFirebaseAuth,
      firestore: mockFirestore,
      storage: mockStorage,
    );
  });

  group('NextGen IT Global - AuthRepositoryImpl Unit Tests', () {
    test('1. authStateChanges emits user UID when FirebaseAuth user logs in', () async {
      when(() => mockFirebaseAuth.authStateChanges())
          .thenAnswer((_) => Stream.fromIterable([null, mockUser]));

      final emissions = await authRepository.authStateChanges().take(2).toList();
      expect(emissions, equals([null, 'usr_test_123']));
    });

    test('2. createOrUpdateUserDocument caches locally and writes to Firestore', () async {
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
      when(() => mockCollection.doc('usr_test_123')).thenReturn(mockDoc);
      when(() => mockDoc.set(any(), any())).thenAnswer((_) async => {});

      final testUser = UserDocumentModel(
        userId: 'usr_test_123',
        phone: '+919876543210',
        email: 'qa.engineer@nextgenit.com',
        displayName: 'NextGen QA Tester',
        isPhoneVerified: true,
        createdAt: DateTime(2026, 1, 1),
        lastActiveAt: DateTime(2026, 1, 2),
      );

      await authRepository.createOrUpdateUserDocument(testUser);

      // Verify cached user can be retrieved immediately without errors
      final retrieved = await authRepository.getUserDocument('usr_test_123');
      expect(retrieved, isNotNull);
      expect(retrieved!.userId, equals('usr_test_123'));
      expect(retrieved.email, equals('qa.engineer@nextgenit.com'));
      expect(retrieved.displayName, equals('NextGen QA Tester'));
      verify(() => mockStorage.write(key: 'current_user_id', value: 'usr_test_123')).called(1);
    });

    test('3. getUserDocument falls back to local memory cache when Firestore is unreachable', () async {
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
      when(() => mockCollection.doc('usr_cached_456')).thenReturn(mockDoc);
      when(() => mockDoc.get()).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));

      final cachedUser = UserDocumentModel(
        userId: 'usr_cached_456',
        phone: '+14165550199',
        displayName: 'Toronto Staging Tester',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      await authRepository.createOrUpdateUserDocument(cachedUser);
      final result = await authRepository.getUserDocument('usr_cached_456');

      expect(result, isNotNull);
      expect(result!.userId, equals('usr_cached_456'));
      expect(result.displayName, equals('Toronto Staging Tester'));
    });

    test('4. signOut calls firebaseAuth.signOut and clears active session', () async {
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async => {});

      await authRepository.signOut();

      verify(() => mockFirebaseAuth.signOut()).called(1);
      verify(() => mockStorage.delete(key: 'current_user_id')).called(1);
    });

    test('5. verifyPhoneOtp performs valid OTP handshake', () async {
      final success = await authRepository.verifyPhoneOtp('+919876543210', '123456');
      expect(success, isTrue);

      final user = await authRepository.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.isPhoneVerified, isTrue);
    });
  });

  group('NextGen IT Global - GoogleAuthService Controller Unit Tests', () {
    test('1. GoogleAuthService singleton returns consistent instance', () {
      final s1 = GoogleAuthService();
      final s2 = GoogleAuthService();
      expect(identical(s1, s2), isTrue);
    });

    test('2. signInWithGoogle executes mocked OAuth flow and returns successful session', () async {
      final service = GoogleAuthService();
      final result = await service.signInWithGoogle(
        mockEmail: 'devops@nextgenit.com',
        mockName: 'NextGen DevOps Lead',
        mockPhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile!.email, equals('devops@nextgenit.com'));
      expect(result.profile!.displayName, equals('NextGen DevOps Lead'));
      expect(result.token, isNotEmpty);
      expect(result.errorMessage, isNull);
    });

    test('3. GoogleSignInAccountProfile model correctly preserves token and identity mappings', () {
      final profile = GoogleSignInAccountProfile(
        id: 'google_12345',
        email: 'qa.lead@nextgenit.com',
        displayName: 'QA Lead',
        photoUrl: 'https://cdn.aura.dating/avatars/qa.jpg',
        idToken: 'mock_jwt_token',
        firebaseUid: 'usr_firebase_qa_01',
      );

      expect(profile.id, equals('google_12345'));
      expect(profile.email, equals('qa.lead@nextgenit.com'));
      expect(profile.displayName, equals('QA Lead'));
      expect(profile.photoUrl, equals('https://cdn.aura.dating/avatars/qa.jpg'));
      expect(profile.idToken, equals('mock_jwt_token'));
      expect(profile.firebaseUid, equals('usr_firebase_qa_01'));
    });
  });
}
