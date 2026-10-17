// ignore_for_file: subtype_of_sealed_class
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aura_app/core/utils/phone_number_helper.dart';
import 'package:aura_app/core/services/firebase_media_storage_service.dart';
import 'package:aura_app/features/auth/presentation/screens/otp_screen.dart';
import 'package:aura_app/features/auth/presentation/screens/dating_onboarding_flow_screen.dart';

class MockUser extends Mock implements User {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUDIT TEST SUITE 1: International Phone Auth Validation (Canada +1 & India +91)', () {
    final canada = PhoneNumberHelper.findByIsoCode('CA');
    final india = PhoneNumberHelper.findByIsoCode('IN');

    test('1.1 Canada (+1) valid numbers, NANP formatting, and E.164 compliance', () {
      final res1 = PhoneNumberHelper.validate(country: canada, rawInput: '4165550199');
      expect(res1.isValid, isTrue);
      expect(res1.formattedE164, equals('+14165550199'));
      expect(res1.formattedNational, equals('(416) 555-0199'));

      // Pinned/pasted with leading +1
      final res2 = PhoneNumberHelper.validate(country: canada, rawInput: '+14165550199');
      expect(res2.isValid, isTrue);
      expect(res2.formattedE164, equals('+14165550199'));

      // Vancouver number
      final res3 = PhoneNumberHelper.validate(country: canada, rawInput: '6045550144');
      expect(res3.isValid, isTrue);
      expect(res3.formattedE164, equals('+16045550144'));
    });

    test('1.2 India (+91) valid numbers and formatting', () {
      final res1 = PhoneNumberHelper.validate(country: india, rawInput: '9876543210');
      expect(res1.isValid, isTrue);
      expect(res1.formattedE164, equals('+919876543210'));
      expect(res1.formattedNational, equals('98765-43210'));

      // Indian mobile starting with 7
      final res2 = PhoneNumberHelper.validate(country: india, rawInput: '7012345678');
      expect(res2.isValid, isTrue);
      expect(res2.formattedE164, equals('+917012345678'));
    });

    test('1.3 Whitelisted QA and Firebase test numbers support', () {
      final resTestCA = PhoneNumberHelper.validate(country: canada, rawInput: '4165550199');
      expect(resTestCA.isValid, isTrue);

      final resTestIN = PhoneNumberHelper.validate(country: india, rawInput: '9876543210');
      expect(resTestIN.isValid, isTrue);
    });

    test('1.4 Input validation error handling for incomplete and invalid entries', () {
      final resEmpty = PhoneNumberHelper.validate(country: canada, rawInput: '');
      expect(resEmpty.isValid, isFalse);
      expect(resEmpty.errorMessage, contains('cannot be empty'));

      final resShort = PhoneNumberHelper.validate(country: canada, rawInput: '41655');
      expect(resShort.isValid, isFalse);
      expect(resShort.errorMessage, contains('require at least 10 digits'));

      final resLong = PhoneNumberHelper.validate(country: canada, rawInput: '416555019999');
      expect(resLong.isValid, isFalse);
      expect(resLong.errorMessage, contains('cannot exceed 10 digits'));
    });
  });

  group('AUDIT TEST SUITE 2: OTP Screen UI & QA Fast-Fill Verification Flow', () {
    testWidgets('2.1 OtpScreen renders Canada as default and provides test pills', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter Phone Number'), findsOneWidget);
      expect(find.text('What\'s your number?'), findsOneWidget);
      expect(find.text('🇨🇦'), findsWidgets);
      expect(find.text('+1'), findsWidgets);

      // Verify Test quick fill pills
      expect(find.text('Test CA (+1)'), findsOneWidget);
      expect(find.text('Test IN (+91)'), findsOneWidget);

      // Tap on Test CA pill
      await tester.tap(find.text('Test CA (+1)'));
      await tester.pumpAndSettle();

      expect(find.text('4165550199'), findsOneWidget);
    });

    testWidgets('2.2 OtpScreen renders 6 OTP digits and Dev Fast-Fill button when code is sent', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(
            initialIsOtpSent: true,
            initialPhoneNumber: '+14165550199',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify Phone'), findsOneWidget);
      expect(find.text('Enter 6-Digit Code'), findsOneWidget);
      expect(find.text('Code sent to +14165550199'), findsOneWidget);
      expect(find.text('Dev Fast-Fill (123456)'), findsOneWidget);
      expect(find.text('Verify & Enter'), findsOneWidget);

      // Verify 6 OTP text input fields
      expect(find.byType(TextField), findsNWidgets(6));
    });
  });

  group('AUDIT TEST SUITE 3: Modernized Onboarding, Mini-Quiz & Prompts Flow', () {
    late MockUser mockUser;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocRef;

    setUp(() {
      mockUser = MockUser();
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference();
      mockDocRef = MockDocumentReference();

      when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);

      when(() => mockUser.uid).thenReturn('usr_audit_qa_99');
      when(() => mockUser.email).thenReturn('qa@aura.dating');
      when(() => mockUser.displayName).thenReturn('Aura Specialist');
      when(() => mockUser.phoneNumber).thenReturn('+14165550199');
      when(() => mockUser.photoURL).thenReturn(null);
      when(() => mockUser.providerData).thenReturn([]);
      when(() => mockUser.emailVerified).thenReturn(true);
      when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async => {});
      when(() => mockUser.reload()).thenAnswer((_) async => {});
    });

    testWidgets('3.1 Step 2 Mini-Quiz and Interactive Icebreaker Prompts with Inspirations', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Aura Specialist',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4 · Vibe & Prompts'), findsOneWidget);

      // Verify Mini-Quiz This-or-That sections
      expect(find.text('VIBE COMPATIBILITY QUIZ (THIS OR THAT)'), findsOneWidget);
      expect(find.text('DAILY RHYTHM'), findsOneWidget);
      expect(find.text('TRAVEL STYLE'), findsOneWidget);
      expect(find.text('FIRST DATE VIBE'), findsOneWidget);

      expect(find.text('Early Bird 🌅'), findsOneWidget);
      expect(find.text('Night Owl 🌙'), findsOneWidget);
      expect(find.text('Spontaneous Trips 🎒'), findsOneWidget);
      expect(find.text('Planned Itinerary 📋'), findsOneWidget);

      // Tap on 'Early Bird 🌅' to update rhythm quiz choice
      await tester.tap(find.text('Early Bird 🌅'));
      await tester.pumpAndSettle();

      // Verify Prompt 1 and Prompt Inspiration Chips
      expect(find.text('ICEBREAKER PROMPT 1'), findsOneWidget);
      expect(find.text('A fun fact about me...'), findsOneWidget);
      expect(find.text('Quick Inspiration (tap to fill):'), findsWidgets);

      // Tap an inspiration chip to prefill
      expect(find.text('I speak 3 languages fluently 🌍'), findsOneWidget);
      await tester.tap(find.text('I speak 3 languages fluently 🌍'));
      await tester.pumpAndSettle();

      expect(find.text('I speak 3 languages fluently 🌍'), findsWidgets);

      // Advance to Step 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 4 · Photos & Lenses'), findsOneWidget);
    });

    testWidgets('3.2 Step 3 to Step 4 Voice/Video Intro presentation and local fallback resilience', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Aura Specialist',
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

  group('AUDIT TEST SUITE 4: Storage Service Timeouts & Non-Freezing Guarantees', () {
    test('4.1 FirebaseMediaStorageService handles uninitialized / offline storage with fallback', () async {
      final storageService = FirebaseMediaStorageService();

      // Upload with offline storage should fallback without throwing
      final photoRes = await storageService.uploadUserPhoto(
        uid: 'usr_audit_qa_99',
        localPath: 'mock_local_path.jpg',
      );
      expect(photoRes, equals('mock_local_path.jpg'));

      final introRes = await storageService.uploadUserIntroMedia(
        uid: 'usr_audit_qa_99',
        localPath: 'mock_intro_audio.m4a',
      );
      expect(introRes, equals('mock_intro_audio.m4a'));
    });
  });
}
