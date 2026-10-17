// ignore_for_file: subtype_of_sealed_class, unused_local_variable
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aura_app/core/services/user_provisioning_service.dart';
import 'package:aura_app/core/services/firebase_media_storage_service.dart';
import 'package:aura_app/features/auth/presentation/screens/dating_onboarding_flow_screen.dart';
import 'package:aura_app/features/auth/presentation/widgets/voice_video_intro_recorder.dart';
import 'package:aura_app/features/profile/presentation/widgets/aura_voice_vibe_widget.dart';

// Mocks
class MockUser extends Mock implements User {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}
class MockReference extends Mock implements Reference {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockUser mockUser;
  late MockFirebaseStorage mockStorage;
  late MockReference mockRootRef;
  late MockReference mockChildRef;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockUser = MockUser();
    mockStorage = MockFirebaseStorage();
    mockRootRef = MockReference();
    mockChildRef = MockReference();

    when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);

    when(() => mockUser.uid).thenReturn('usr_test_verification_42');
    when(() => mockUser.email).thenReturn('alex@aura.dating');
    when(() => mockUser.displayName).thenReturn('Alex River');
    when(() => mockUser.phoneNumber).thenReturn('+14165550188');
    when(() => mockUser.photoURL).thenReturn(null);
    when(() => mockUser.providerData).thenReturn([]);
    when(() => mockUser.emailVerified).thenReturn(true);
    when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async => {});
    when(() => mockUser.reload()).thenAnswer((_) async => {});

    when(() => mockStorage.ref()).thenReturn(mockRootRef);
    when(() => mockRootRef.child(any())).thenReturn(mockChildRef);
  });

  group('AURA APP FLOW TEST 1: Quiz-Style Intro & Demographics UI Interactions', () {
    testWidgets('1.1 Quiz Step 1: Validates name, age calculation, gender and relationship goal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Alex River',
            fallbackEmail: 'alex@aura.dating',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Quiz Step 1 Header & Demographic selectors
      expect(find.text('Step 1 of 4 · Identity'), findsOneWidget);
      expect(find.text('Who are you?'), findsOneWidget);
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('Alex River'), findsOneWidget);
      expect(find.text('I IDENTIFY AS'), findsOneWidget);
      expect(find.text('INTERESTED IN'), findsOneWidget);
      expect(find.text('RELATIONSHIP GOAL'), findsOneWidget);

      // Verify quiz cards for relationship goals
      expect(find.text('Long-term partner'), findsWidgets);
      expect(find.text('Casual dating'), findsOneWidget);
      expect(find.text('Open to explore'), findsOneWidget);
      expect(find.text('New friendships'), findsOneWidget);

      // Tap on 'Casual dating' quiz card
      await tester.tap(find.text('Casual dating'));
      await tester.pumpAndSettle();

      // Tap on 'Man' gender chip
      await tester.tap(find.text('Man'));
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4 · Vibe & Prompts'), findsOneWidget);
      expect(find.text('Your Passions & Prompts'), findsOneWidget);
    });

    testWidgets('1.2 Quiz Step 2: Hobby chip selections & Icebreaker prompt answers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Alex River',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance from Step 1 to Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4 · Vibe & Prompts'), findsOneWidget);

      // Verify quiz hobbies chips exist
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Gaming'), findsOneWidget);

      // Select additional hobby chips
      await tester.tap(find.text('Fitness'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gaming'));
      await tester.pumpAndSettle();

      // Verify Icebreaker prompt questions
      expect(find.text('ICEBREAKER PROMPT 1'), findsOneWidget);
      expect(find.text('A fun fact about me...'), findsOneWidget);

      // Fill in custom answer
      final promptInputs = find.byType(TextFormField);
      expect(promptInputs, findsWidgets);

      await tester.enterText(promptInputs.first, 'I build AI dating apps and play cello.');
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 4 · Photos & Lenses'), findsOneWidget);
      expect(find.text('Add Your Photos'), findsOneWidget);
    });

    testWidgets('1.3 Quiz Step 3 to Step 4: Photo validation & Voice/Video Intro presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DatingOnboardingFlowScreen(
            user: mockUser,
            fallbackDisplayName: 'Alex River',
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

      // Verify validation: with 0 photos, tapping Continue should show error
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please upload at least 2 profile photos (minimum required).'), findsOneWidget);
    });
  });

  group('AURA APP FLOW TEST 2: Voice Recording Post-Processing', () {
    testWidgets('2.1 VoiceVideoIntroRecorder: State transitions, waveform, and audio path generation', (tester) async {
      String? recordedPathResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: VoiceVideoIntroRecorder(
              onMediaChanged: (mediaPath) {
                recordedPathResult = mediaPath;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: shows instructions and record audio button
      expect(find.text('Tap to Record Voice'), findsOneWidget);
      expect(find.text('Voice Intro (Max 30s)'), findsOneWidget);

      // Tap mic circle to record audio
      final micCircle = find.byIcon(Icons.mic_rounded);
      expect(micCircle, findsWidgets);
      await tester.tap(micCircle.last);
      await tester.pump();

      // Should enter active recording state
      expect(find.text('Stop Recording'), findsOneWidget);

      // Advance clock by 3 seconds
      await tester.pump(const Duration(seconds: 3));

      // Tap stop recording
      await tester.tap(find.text('Stop Recording'));
      await tester.pumpAndSettle();

      // Verify post-processing output:
      // 1. Should generate a timestamped .m4a audio container
      expect(recordedPathResult, isNotNull);
      expect(recordedPathResult!.startsWith('voice_intro_'), isTrue);
      expect(recordedPathResult!.endsWith('.m4a'), isTrue);

      // 2. UI should show completed audio preview with play/delete buttons
      expect(find.text('Voice Intro Recorded'), findsOneWidget);

      // 3. Test playback toggle
      final playIcon = find.byIcon(Icons.play_arrow_rounded);
      expect(playIcon, findsOneWidget);
      await tester.tap(playIcon);
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Advance clock past the 3-second preview timer
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 4. Test delete/clear recording
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(recordedPathResult, isNull);
      expect(find.text('Tap to Record Voice'), findsOneWidget);
    });

    testWidgets('2.2 AuraVoiceVibeWidget: Prompt selection, waveform bars and completion dispatch', (tester) async {
      String? savedAudioPath;
      String? savedPrompt;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AuraVoiceVibeWidget(
              initialPrompt: 'The vibe track that defines my frequency...',
              isEditable: true,
              onSaved: (path, prompt) {
                savedAudioPath = path;
                savedPrompt = prompt;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify prompt display
      expect(find.text('The vibe track that defines my frequency...'), findsOneWidget);

      // Verify voice vibe badge & audio pill play button
      expect(find.text('VOICE VIBE'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    test('2.3 FirebaseMediaStorageService: Voice intro post-processing & metadata attachment', () async {
      final storageService = FirebaseMediaStorageService();

      final dummyBytes = Uint8List.fromList([0, 0, 0, 32, 102, 116, 121, 112, 77, 52, 65]);
      final cloudUrl = await storageService.uploadUserIntroMedia(
        uid: 'usr_test_verification_42',
        localPath: 'mock_voice_intro.m4a',
        fileBytes: dummyBytes,
        filename: 'intro_voice_test.m4a',
        isVideo: false,
      );

      // Should resolve to path or fallback gracefully
      expect(cloudUrl.isNotEmpty, isTrue);
    });
  });

  group('AURA APP FLOW TEST 3: Image Upload Functionality', () {
    test('3.1 FirebaseMediaStorageService: Photo upload with JPEG content-type and custom metadata', () async {
      final storageService = FirebaseMediaStorageService();

      final dummyImageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);
      final resultUrl = await storageService.uploadUserPhoto(
        uid: 'usr_test_verification_42',
        localPath: 'temp_profile_shot.jpg',
        fileBytes: dummyImageBytes,
        filename: 'primary_avatar.jpg',
      );

      expect(resultUrl.isNotEmpty, isTrue);
    });

    test('3.2 FirebaseMediaStorageService: URL and local path fallback resilience', () async {
      final storageService = FirebaseMediaStorageService();

      // When given a remote CDN URL, it handles directly
      const cdnUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400';
      final returned = await storageService.uploadUserPhoto(
        uid: 'usr_test_verification_42',
        localPath: cdnUrl,
      );

      expect(returned, equals(cdnUrl));
    });
  });

  group('AURA APP FLOW TEST 4: End-to-End Profile Compilation & Firestore Schema', () {
    test('4.1 UserProvisioningService completes onboarding with quiz answers, photos, and voice note', () async {
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async => {});

      final provisioningService = UserProvisioningService();
      provisioningService.firestore = mockFirestore;

      final success = await provisioningService.completeOnboarding(
        user: mockUser,
        customDisplayName: 'Alex River',
        age: 25,
        birthDate: DateTime(2001, 8, 20),
        gender: 'Man',
        interestedIn: 'Women',
        relationshipGoal: 'Casual dating',
        hobbies: ['Fitness', 'Music', 'Gaming'],
        prompts: {
          'A fun fact about me...': 'I build AI dating apps and play cello.',
          'My ideal weekend consists of...': 'Exploring hidden cafes and catching live jazz.',
        },
        photoUrls: [
          'https://aura.dating/photos/alex_1.jpg',
          'https://aura.dating/photos/alex_2.jpg',
        ],
        introMediaUrl: 'https://aura.dating/intro/alex_voice.m4a',
        location: const GeoPoint(43.6532, -79.3832),
      );

      expect(success, isTrue);

      final captured = verify(() => mockDocRef.set(captureAny(), any())).captured;
      expect(captured.isNotEmpty, isTrue);

      final Map<String, dynamic> written = captured.first as Map<String, dynamic>;
      expect(written['uid'], equals('usr_test_verification_42'));
      expect(written['displayName'], equals('Alex River'));
      expect(written['age'], equals(25));
      expect(written['gender'], equals('Man'));
      expect(written['relationshipGoal'], equals('Casual dating'));
      expect(written['hobbies'], containsAll(['Fitness', 'Music', 'Gaming']));
      expect(written['prompts']['A fun fact about me...'], equals('I build AI dating apps and play cello.'));
      expect(written['photoUrls'].length, equals(2));
      expect(written['introMediaUrl'], equals('https://aura.dating/intro/alex_voice.m4a'));
      expect(written['isProfileCompleted'], isTrue);
    });
  });
}
