import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/firestore_discovery_service.dart';
import 'package:aura_app/features/discovery/presentation/widgets/dating_user_profile_detail_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreDiscoveryService Compatibility & Filtering Unit Tests', () {
    test('calculateCompatibility computes accurate overlap and dynamic match percentage', () {
      final userHobbies = ['Architecture', 'Vinyl Records', 'Specialty Coffee', 'Trekking'];
      final candidateHobbies = ['Architecture', 'Vinyl Records', 'Indie Films', 'Ceramics'];

      final (score, common) = FirestoreDiscoveryService.calculateCompatibility(
        currentUserHobbies: userHobbies,
        candidateHobbies: candidateHobbies,
        seedUid: 'cand_test_01',
      );

      // Overlapping hobbies: Architecture, Vinyl Records (2 out of 4)
      expect(common.length, 2);
      expect(common, contains('Architecture'));
      expect(common, contains('Vinyl Records'));

      // 50% overlap should yield high compatibility score between 70% and 85%
      expect(score, greaterThanOrEqualTo(70));
      expect(score, lessThanOrEqualTo(98));
    });

    test('calculateCompatibility handles high overlap (3 out of 3 hobbies)', () {
      final userHobbies = ['Photography', 'Bouldering', 'Matcha'];
      final candidateHobbies = ['Photography', 'Bouldering', 'Matcha', 'Surfing'];

      final (score, common) = FirestoreDiscoveryService.calculateCompatibility(
        currentUserHobbies: userHobbies,
        candidateHobbies: candidateHobbies,
        seedUid: 'cand_test_02',
      );

      expect(common.length, 3);
      // Full overlap should yield very high score >= 90%
      expect(score, greaterThanOrEqualTo(90));
      expect(score, lessThanOrEqualTo(98));
    });

    test('calculateCompatibility falls back cleanly when user has no hobbies defined', () {
      final (score, common) = FirestoreDiscoveryService.calculateCompatibility(
        currentUserHobbies: [],
        candidateHobbies: ['Music', 'Art'],
        seedUid: 'cand_test_03',
      );

      expect(common, isEmpty);
      expect(score, greaterThanOrEqualTo(55));
      expect(score, lessThanOrEqualTo(88));
    });

    test('matchesGenderFilter accurately enforces gender and interest preferences', () {
      // 1. User interested in Women
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Women', candidateGender: 'Woman'),
        isTrue,
      );
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Women', candidateGender: 'Man'),
        isFalse,
      );

      // 2. User interested in Men
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Men', candidateGender: 'Man'),
        isTrue,
      );
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Men', candidateGender: 'Woman'),
        isFalse,
      );

      // 3. User interested in Everyone
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Everyone', candidateGender: 'Woman'),
        isTrue,
      );
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Everyone', candidateGender: 'Man'),
        isTrue,
      );
      expect(
        FirestoreDiscoveryService.matchesGenderFilter(userInterestedIn: 'Everyone', candidateGender: 'Non-Binary'),
        isTrue,
      );
    });

    test('Sample seed profiles have valid locations, distance, and prompts', () {
      final seeds = FirestoreDiscoveryService.getSampleSeedProfiles(
        centerLat: 19.0596,
        centerLng: 72.8295,
      );

      expect(seeds.length, greaterThanOrEqualTo(4));
      for (final seed in seeds) {
        expect(seed.displayName.isNotEmpty, isTrue);
        expect(seed.photos.length, greaterThanOrEqualTo(2));
        expect(seed.hobbies.isNotEmpty, isTrue);
        expect(seed.distanceKm, greaterThan(0));
        expect(seed.prompts.isNotEmpty, isTrue);
        expect(seed.introMediaUrl, isNotNull);
      }
    });
  });

  group('DatingUserProfileDetailModal Widget Tests', () {
    final testProfile = DatingCandidateProfile(
      userId: 'test_candidate_maya',
      displayName: 'Maya Lin',
      age: 26,
      gender: 'Woman',
      interestedIn: 'Everyone',
      relationshipGoal: 'Meaningful connection',
      occupation: 'Visual Director & Photographer',
      bio: 'Shooting 35mm film across the world. Looking for spontaneous road trips 📸🌿',
      locationName: 'Khar, Mumbai',
      latitude: 19.070,
      longitude: 72.835,
      photos: const [
        'https://images.unsplash.com/photo-1517841905240-472988babdf9',
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
      ],
      hobbies: const ['Photography', 'Vinyl Records', 'Specialty Coffee'],
      commonHobbies: const ['Photography', 'Vinyl Records'],
      matchScore: 88,
      prompts: const {
        'A fun fact about me...': 'I own a vintage 1978 Hasselblad camera.',
      },
      introMediaUrl: 'https://example.com/audio/maya_intro.m4a',
      isVerified: true,
      distanceKm: 2.4,
    );

    testWidgets('Renders candidate identity, dynamic match score, and shared hobbies', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatingUserProfileDetailModal(profile: testProfile),
          ),
        ),
      );
      await tester.pump();

      // Check name, age, verified badge
      expect(find.text('Maya Lin, 26'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      // Check occupation and location
      expect(find.text('Visual Director & Photographer'), findsOneWidget);
      expect(find.text('2.4 km away • Khar, Mumbai'), findsOneWidget);

      // Check dynamic match percentage pill
      expect(find.text('88% Match'), findsOneWidget);

      // Check relationship goal
      expect(find.text('Looking for: Meaningful connection'), findsOneWidget);

      // Check shared interest indicator
      expect(find.text('2 Shared Interests ✨'), findsOneWidget);
      expect(find.text('Photography'), findsOneWidget);
      expect(find.text('Vinyl Records'), findsOneWidget);

      // Check prompts
      expect(find.text('A fun fact about me...'), findsOneWidget);
      expect(find.text('I own a vintage 1978 Hasselblad camera.'), findsOneWidget);

      // Check Voice Intro player
      expect(find.text('Voice Intro Note'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Check action buttons
      expect(find.text('Send Wave'), findsOneWidget);
      expect(find.text('Open Chat'), findsOneWidget);
    });

    testWidgets('Voice intro player toggles play and pause on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatingUserProfileDetailModal(profile: testProfile),
          ),
        ),
      );
      await tester.pump();

      // Initially paused
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap play
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      // Now playing
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('Playing • 0:24'), findsOneWidget);

      // Tap pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      // Returns to play icon
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Tapping Send Wave triggers onWaveSent callback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool waveTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatingUserProfileDetailModal(
              profile: testProfile,
              onWaveSent: () => waveTriggered = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Send Wave'));
      await tester.pump();

      expect(waveTriggered, isTrue);
    });
  });
}
