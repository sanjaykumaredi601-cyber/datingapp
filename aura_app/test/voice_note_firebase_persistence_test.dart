// ignore_for_file: subtype_of_sealed_class, unused_local_variable
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/core/services/voice_note_service.dart';
import 'package:aura_app/core/services/user_provisioning_service.dart';
import 'package:aura_app/core/services/firebase_media_storage_service.dart';
import 'package:aura_app/features/auth/presentation/widgets/voice_video_intro_recorder.dart';
import 'package:aura_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:aura_app/features/auth/presentation/screens/dating_onboarding_flow_screen.dart';

// Mocks
class MockUser extends Mock implements User {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}
class MockReference extends Mock implements Reference {}
class MockUploadTask extends Mock implements UploadTask {}
class MockTaskSnapshot extends Mock implements TaskSnapshot {}

class FakeUploadTask extends Fake implements UploadTask {
  @override
  Future<S> then<S>(FutureOr<S> Function(TaskSnapshot) onValue, {Function? onError}) {
    return Future.value(MockTaskSnapshot()).then(onValue, onError: onError);
  }

  @override
  Future<TaskSnapshot> timeout(Duration timeLimit, {FutureOr<TaskSnapshot> Function()? onTimeout}) {
    return Future.value(MockTaskSnapshot());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
    registerFallbackValue(SetOptions(merge: true));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'hasPermission':
            return true;
          case 'isRecording':
            return true;
          case 'start':
            return null;
          case 'stop':
            return 'voice_intro_12345.m4a';
          default:
            return null;
        }
      },
    );
  });

  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDocRef;
  late MockFirebaseStorage mockStorage;
  late MockReference mockRootRef;
  late MockReference mockUserVoicePromptRef;
  late MockUser mockUser;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockUserDocRef = MockDocumentReference();
    mockStorage = MockFirebaseStorage();
    mockRootRef = MockReference();
    mockUserVoicePromptRef = MockReference();
    mockUser = MockUser();

    when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDocRef);
    when(() => mockUserDocRef.set(any(), any())).thenAnswer((_) async => {});

    when(() => mockStorage.ref()).thenReturn(mockRootRef);
    when(() => mockRootRef.child(any())).thenReturn(mockUserVoicePromptRef);
    when(() => mockUserVoicePromptRef.getDownloadURL())
        .thenAnswer((_) async => 'https://firebasestorage.googleapis.com/v0/b/aura.appspot.com/o/users%2Fusr_test_123%2Fvoice_prompts%2Fvoice_note.m4a?alt=media');

    when(() => mockUser.uid).thenReturn('usr_test_123');
    when(() => mockUser.displayName).thenReturn('Aura Romantic');
    when(() => mockUser.email).thenReturn('romantic@aura.dating');
    when(() => mockUser.phoneNumber).thenReturn('+14165559876');
    when(() => mockUser.photoURL).thenReturn('https://aura.dating/photos/avatar.jpg');
    when(() => mockUser.emailVerified).thenReturn(true);
    when(() => mockUser.providerData).thenReturn([]);
    when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async => {});
    when(() => mockUser.updatePhotoURL(any())).thenAnswer((_) async => {});
    when(() => mockUser.reload()).thenAnswer((_) async => {});
  });

  group('TASK 1: Voice Note Recording, Upload & Playback Flow', () {
    test('1.1 VoiceNoteService starts and stops recording in .m4a format', () async {
      final voiceService = VoiceNoteService();

      final recordPath = await voiceService.startRecording();
      expect(recordPath, isNotNull);
      expect(recordPath!.endsWith('.m4a'), isTrue);

      final stoppedPath = await voiceService.stopRecording();
      expect(stoppedPath, isNotNull);
      expect(stoppedPath!.endsWith('.m4a'), isTrue);
    });

    test('1.2 VoiceNoteService uploads audio to users/{userId}/voice_prompts/voice_note.m4a and updates Firestore', () async {
      final voiceService = VoiceNoteService();
      voiceService.storage = mockStorage;
      voiceService.firestore = mockFirestore;

      final dummyBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]);
      when(() => mockUserVoicePromptRef.putData(any(), any()))
          .thenAnswer((_) => FakeUploadTask());

      final downloadUrl = await voiceService.uploadAndPersistVoiceNote(
        userId: 'usr_test_123',
        localPath: 'voice_note.m4a',
        fileBytes: dummyBytes,
      );

      // Verify correct Firebase Storage path
      verify(() => mockRootRef.child('users/usr_test_123/voice_prompts/voice_note.m4a')).called(1);
      expect(downloadUrl, contains('voice_prompts%2Fvoice_note.m4a'));

      // Verify Firestore document update under users/{userId}
      final captured = verify(() => mockUserDocRef.set(captureAny(), any())).captured;
      expect(captured.isNotEmpty, isTrue);
      final Map<String, dynamic> firestoreMap = captured.first as Map<String, dynamic>;
      expect(firestoreMap['voiceNoteUrl'], equals(downloadUrl));
      expect(firestoreMap['updatedAt'], isNotNull);
    });

    test('1.3 FirebaseMediaStorageService uploadVoiceNote uploads to voice_prompts/voice_note.m4a', () async {
      final mediaStorage = FirebaseMediaStorageService();
      mediaStorage.storage = mockStorage;
      mediaStorage.firestore = mockFirestore;

      final dummyBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]);
      when(() => mockUserVoicePromptRef.putData(any(), any()))
          .thenAnswer((_) => FakeUploadTask());

      final resultUrl = await mediaStorage.uploadVoiceNote(
        uid: 'usr_test_123',
        localPath: 'voice_note.m4a',
        fileBytes: dummyBytes,
      );

      verify(() => mockRootRef.child('users/usr_test_123/voice_prompts/voice_note.m4a')).called(1);
      expect(resultUrl, isNotEmpty);
    });

    testWidgets('1.4 VoiceVideoIntroRecorder UI shows playback timeline and duration', (tester) async {
      String? updatedPath;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: VoiceVideoIntroRecorder(
              initialMediaUrl: 'voice_intro_12345.m4a',
              onMediaChanged: (path) => updatedPath = path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // UI should show playback preview
      expect(find.text('Voice Intro Recorded'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);

      // Tap Play to start playback
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap Pause to clean up periodic timer
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
    });
  });

  group('TASK 2: User Registration & Firebase Firestore Sync', () {
    test('2.1 UserProvisioningService syncs all required profile data to users/{userId}', () async {
      final provisioningService = UserProvisioningService();
      provisioningService.firestore = mockFirestore;

      final birthDate = DateTime(1998, 5, 14);
      final success = await provisioningService.completeOnboarding(
        user: mockUser,
        customDisplayName: 'Elena Rostova',
        age: 26,
        birthDate: birthDate,
        gender: 'Woman',
        bio: 'Art director, coffee connoisseur, lover of live jazz.',
        voiceNoteUrl: 'https://firebasestorage.googleapis.com/v0/b/aura/o/voice_note.m4a',
        photoUrls: [
          'https://aura.dating/photos/elena_1.jpg',
          'https://aura.dating/photos/elena_2.jpg',
        ],
        hobbies: ['Art', 'Design', 'Jazz'],
      );

      expect(success, isTrue);

      final captured = verify(() => mockUserDocRef.set(captureAny(), any())).captured;
      expect(captured.isNotEmpty, isTrue);
      final Map<String, dynamic> profile = captured.first as Map<String, dynamic>;

      // Verify all required fields from user specification
      expect(profile['name'], equals('Elena Rostova'));
      expect(profile['displayName'], equals('Elena Rostova'));
      expect(profile['gender'], equals('Woman'));
      expect(profile['age'], equals(26));
      expect(profile['birthdate'], isNotNull);
      expect(profile['bio'], equals('Art director, coffee connoisseur, lover of live jazz.'));
      expect(profile['voiceNoteUrl'], equals('https://firebasestorage.googleapis.com/v0/b/aura/o/voice_note.m4a'));
      expect(profile['photos'], containsAll([
        'https://aura.dating/photos/elena_1.jpg',
        'https://aura.dating/photos/elena_2.jpg',
      ]));
      expect(profile['createdAt'], isNotNull);
      expect(profile['updatedAt'], isNotNull);
    });

    testWidgets('2.2 Welcome screen displays Privacy Policy & Terms acceptance disclaimer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify disclaimer text exists within RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Terms of Service') && w.text.toPlainText().contains('Privacy Policy'),
        ),
        findsWidgets,
      );
    });

    testWidgets('2.3 Dating onboarding flow includes Terms & Privacy Policy checkbox in Step 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatingOnboardingFlowScreen(user: mockUser),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Terms of Service & Privacy Policy consent checkbox is present in Step 1
      expect(find.byType(Checkbox, skipOffstage: false), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('I am 18+ and accept the'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('SHORT BIO / ABOUT ME', skipOffstage: false), findsOneWidget);
    });

    test('2.4 Verify Firestore & Storage Security Rules configuration', () {
      final firestoreRulesFile = File('e:/Sanjayprojects/Datingapp/firestore.rules');
      expect(firestoreRulesFile.existsSync(), isTrue);
      final firestoreContent = firestoreRulesFile.readAsStringSync();

      // Verify rule: Authenticated users to write only to their own document: request.auth.uid == userId
      expect(firestoreContent.contains('match /users/{userId}'), isTrue);
      expect(firestoreContent.contains('request.auth.uid == userId'), isTrue);

      final storageRulesFile = File('e:/Sanjayprojects/Datingapp/storage.rules');
      expect(storageRulesFile.existsSync(), isTrue);
      final storageContent = storageRulesFile.readAsStringSync();

      // Verify rule: Audio files in Firebase Storage only writable by owner
      expect(storageContent.contains('match /users/{userId}/voice_prompts/{fileName}'), isTrue);
      expect(storageContent.contains('request.auth.uid == userId'), isTrue);
      expect(storageContent.contains('allow write: if isOwner(userId)'), isTrue);
    });
  });
}
