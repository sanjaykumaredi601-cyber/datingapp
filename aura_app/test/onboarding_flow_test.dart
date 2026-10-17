// ignore_for_file: subtype_of_sealed_class

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aura_app/core/services/user_provisioning_service.dart';
import 'package:aura_app/features/auth/presentation/screens/dating_onboarding_flow_screen.dart';

// Mocks
class MockUser extends Mock implements User {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockDocumentSnapshot mockSnapshot;
  late MockUser mockUser;
  late UserProvisioningService provisioningService;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();
    mockUser = MockUser();

    when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);

    when(() => mockUser.uid).thenReturn('usr_aurora_999');
    when(() => mockUser.email).thenReturn('sanjay@aura.dating');
    when(() => mockUser.displayName).thenReturn('Sanjay Original');
    when(() => mockUser.phoneNumber).thenReturn('+14165550199');
    when(() => mockUser.photoURL).thenReturn('https://aura.dating/avatars/sanjay.png');
    when(() => mockUser.providerData).thenReturn([]);
    when(() => mockUser.emailVerified).thenReturn(true);

    when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async => {});
    when(() => mockUser.updatePhotoURL(any())).thenAnswer((_) async => {});
    when(() => mockUser.reload()).thenAnswer((_) async => {});

    provisioningService = UserProvisioningService();
    provisioningService.firestore = mockFirestore;
  });

  group('UserProvisioningService Unit Tests', () {
    test('1. checkUserExists returns false when Firestore document does not exist', () async {
      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(false);

      final exists = await provisioningService.checkUserExists('usr_aurora_999');
      expect(exists, isFalse);
    });

    test('2. checkUserExists returns true when Firestore document exists and isProfileCompleted is true', () async {
      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn({
        'uid': 'usr_aurora_999',
        'isProfileCompleted': true,
      });

      final exists = await provisioningService.checkUserExists('usr_aurora_999');
      expect(exists, isTrue);
    });

    test('3. updateLastLogin updates lastLoginAt and lastActiveAt on existing doc', () async {
      when(() => mockDocRef.update(any())).thenAnswer((_) async => {});

      final success = await provisioningService.updateLastLogin('usr_aurora_999');
      expect(success, isTrue);

      verify(() => mockDocRef.update(any())).called(1);
    });

    test('4. completeOnboarding updates FirebaseAuth and compiles full dating profile into Firestore', () async {
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async => {});

      final success = await provisioningService.completeOnboarding(
        user: mockUser,
        customDisplayName: 'Sanjay Traveler',
        age: 26,
        birthDate: DateTime(2000, 5, 12),
        gender: 'Man',
        interestedIn: 'Women',
        relationshipGoal: 'Long-term partner',
        hobbies: ['Fitness', 'Travel', 'Tech'],
        prompts: {'A fun fact about me...': 'I love espresso and coding.'},
        photoUrls: [
          'https://aura.dating/photos/1.jpg',
          'https://aura.dating/photos/2.jpg',
        ],
        introMediaUrl: 'https://aura.dating/intro/audio.m4a',
      );

      expect(success, isTrue);

      // Verify FirebaseAuth display name update
      verify(() => mockUser.updateDisplayName('Sanjay Traveler')).called(1);
      verify(() => mockUser.reload()).called(1);

      // Verify Firestore write
      final captured = verify(() => mockDocRef.set(captureAny(), any())).captured;
      expect(captured.isNotEmpty, isTrue);

      final Map<String, dynamic> writtenData = captured.first as Map<String, dynamic>;
      expect(writtenData['uid'], equals('usr_aurora_999'));
      expect(writtenData['displayName'], equals('Sanjay Traveler'));
      expect(writtenData['age'], equals(26));
      expect(writtenData['gender'], equals('Man'));
      expect(writtenData['interestedIn'], equals('Women'));
      expect(writtenData['relationshipGoal'], equals('Long-term partner'));
      expect(writtenData['hobbies'], containsAll(['Fitness', 'Travel', 'Tech']));
      expect(writtenData['photoUrls'].length, equals(2));
      expect(writtenData['introMediaUrl'], equals('https://aura.dating/intro/audio.m4a'));
      expect(writtenData['isProfileCompleted'], isTrue);
      expect(writtenData['createdAt'], isA<FieldValue>());
      expect(writtenData['lastLoginAt'], isA<FieldValue>());
    });
  });

  group('DatingOnboardingFlowScreen Multi-Step Widget Tests', () {
    testWidgets('1. Renders Step 1 Demographics with name, birthdate, and identity selectors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Sanjay PreFilled',
            fallbackEmail: 'sanjay@aura.dating',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check step 1 elements
      expect(find.text('Step 1 of 4 · Identity'), findsOneWidget);
      expect(find.text('Who are you?'), findsOneWidget);
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('Sanjay Original'), findsOneWidget);
      expect(find.text('I IDENTIFY AS'), findsOneWidget);
      expect(find.text('INTERESTED IN'), findsOneWidget);
      expect(find.text('RELATIONSHIP GOAL'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('2. Validates empty name on Step 1 and blocks advance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear name
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, '');
      await tester.pump();

      // Tap Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name (minimum 2 characters).'), findsOneWidget);
    });

    testWidgets('3. Advances to Step 2 (Hobbies & Prompts) on valid demographics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Sanjay Tester',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue to go to Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4 · Vibe & Prompts'), findsOneWidget);
      expect(find.text('Your Passions & Prompts'), findsOneWidget);
      expect(find.text('ICEBREAKER PROMPT 1'), findsOneWidget);
    });

    testWidgets('4. Advances to Step 3 (Photos & Lenses) and displays upload options', (tester) async {
      when(() => mockUser.photoURL).thenReturn(null);
      await tester.pumpWidget(
        MaterialApp(
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Sanjay Tester',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 4 · Photos & Lenses'), findsOneWidget);
      expect(find.text('Add Your Photos'), findsOneWidget);
      expect(find.text('Gallery Upload'), findsOneWidget);
      expect(find.text('AR Filter Lens'), findsOneWidget);
    });
  });
}
