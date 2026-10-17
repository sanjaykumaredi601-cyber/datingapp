import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/dna_blueprint_service.dart';
import 'package:aura_app/features/radar/data/models/dna_blueprint_model.dart';
import 'package:aura_app/features/radar/presentation/widgets/dna_blueprint_sheet.dart';

void main() {
  group('Principal UX & Architecture: DNA Blueprint Model & Scoring Suite', () {
    test('1. Enum parsing, labels, and JSON serialization integrity', () {
      const blueprint = DnaBlueprint(
        socialEnergy: SocialEnergy.extrovert,
        idealFirstMeet: IdealFirstMeet.foodAndMusic,
        lifestylePace: LifestylePace.spontaneous,
        connectionGoal: ConnectionGoal.chemistry,
      );

      final map = blueprint.toMap();
      expect(map['socialEnergy'], 'Extrovert');
      expect(map['idealFirstMeet'], 'Food & Music');
      expect(map['lifestylePace'], 'Spontaneous');
      expect(map['connectionGoal'], 'Chemistry');

      final reconstructed = DnaBlueprint.fromMap(map);
      expect(reconstructed, equals(blueprint));
      expect(reconstructed.socialEnergy, SocialEnergy.extrovert);

      final jsonStr = blueprint.toJson();
      final fromJson = DnaBlueprint.fromJson(jsonStr);
      expect(fromJson, equals(blueprint));

      // Test fallback parsing for null/unexpected inputs
      expect(SocialEnergy.fromString(null), SocialEnergy.ambivert);
      expect(IdealFirstMeet.fromString('unknown_vibe'), IdealFirstMeet.coffeeAndWalk);
      expect(LifestylePace.fromString('random_pace'), LifestylePace.balanced);
      expect(ConnectionGoal.fromString(null), ConnectionGoal.meaningful);
    });

    test('2. calculateCompatibility returns percentage strictly between 50% and 99%', () {
      final defaultUser = DnaBlueprint.defaultUser();

      // Test against all combinations of options
      for (final energy in SocialEnergy.values) {
        for (final meet in IdealFirstMeet.values) {
          for (final pace in LifestylePace.values) {
            for (final goal in ConnectionGoal.values) {
              final candidate = DnaBlueprint(
                socialEnergy: energy,
                idealFirstMeet: meet,
                lifestylePace: pace,
                connectionGoal: goal,
              );
              final score = calculateCompatibility(defaultUser, candidate);
              expect(
                score >= 50 && score <= 99,
                isTrue,
                reason: 'Score $score out of bounds [50, 99] for $candidate',
              );
            }
          }
        }
      }
    });

    test('3. Exact match produces perfect 99% resonance', () {
      final user = DnaBlueprint.defaultUser();
      final score = calculateCompatibility(user, user);
      expect(score, equals(99));

      final ananya = DnaBlueprint.ananya();
      expect(calculateCompatibility(ananya, ananya), equals(99));
    });

    test('4. Curated demo radar node compatibility aligns with authentic badges', () {
      final user = DnaBlueprint.defaultUser();

      final ananyaScore = calculateCompatibility(user, DnaBlueprint.ananya());
      expect(ananyaScore, greaterThanOrEqualTo(80)); // High compatibility (>80%, 88% range)

      final mayaScore = calculateCompatibility(user, DnaBlueprint.maya());
      expect(mayaScore, greaterThanOrEqualTo(50));
      expect(mayaScore, lessThanOrEqualTo(80)); // Moderate alignment (70-78% range)

      final rheaScore = calculateCompatibility(user, DnaBlueprint.rhea());
      expect(rheaScore, greaterThanOrEqualTo(70)); // Solid match (79% range)

      final rohanScore = calculateCompatibility(user, DnaBlueprint.rohan());
      expect(rohanScore, greaterThanOrEqualTo(75)); // Strong chemistry (84% range)
    });
  });

  group('Principal UX & Architecture: DnaBlueprintService State Suite', () {
    late DnaBlueprintService service;

    setUp(() {
      service = DnaBlueprintService();
      service.resetForTesting();
    });

    test('1. Service initializes with default user blueprint', () {
      expect(service.blueprint.socialEnergy, SocialEnergy.ambivert);
      expect(service.blueprint.connectionGoal, ConnectionGoal.meaningful);
      expect(service.hideBelowCutoff, isFalse);
    });

    test('2. saveBlueprint updates in-memory state and notifies reactive listeners', () async {
      bool notified = false;
      service.addListener(() => notified = true);

      const customBlueprint = DnaBlueprint(
        socialEnergy: SocialEnergy.introvert,
        idealFirstMeet: IdealFirstMeet.deepTalk,
        lifestylePace: LifestylePace.mindful,
        connectionGoal: ConnectionGoal.meaningful,
      );

      await service.saveBlueprint(customBlueprint);

      expect(notified, isTrue);
      expect(service.blueprint.socialEnergy, SocialEnergy.introvert);
      expect(service.blueprint.idealFirstMeet, IdealFirstMeet.deepTalk);
    });

    test('3. setHideBelowCutoff toggles user filter preference and notifies listeners', () async {
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setHideBelowCutoff(true);
      expect(service.hideBelowCutoff, isTrue);
      expect(notifyCount, 1);

      await service.setHideBelowCutoff(false);
      expect(service.hideBelowCutoff, isFalse);
      expect(notifyCount, 2);
    });

    test('4. calculateMatch evaluates candidate against current user blueprint', () {
      service.resetForTesting(blueprint: DnaBlueprint.defaultUser());

      final matchScore = service.calculateMatch(DnaBlueprint.ananya());
      expect(matchScore, greaterThanOrEqualTo(50));
      expect(matchScore, lessThanOrEqualTo(99));
    });
  });

  group('Principal UX & Architecture: DnaBlueprintSheet UI Modal Suite', () {
    testWidgets('1. Renders Deep Obsidian modal with header and 4 interactive rows', (tester) async {
      DnaBlueprint? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DnaBlueprintSheet.show(
                    ctx,
                    initialBlueprint: DnaBlueprint.defaultUser(),
                    onSaved: (b) => savedResult = b,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify Header and Subtitle
      expect(find.text('✨ Your Aura DNA Blueprint'), findsOneWidget);
      expect(
        find.text('Define your frequency to discover compatible matches nearby.'),
        findsOneWidget,
      );
      expect(find.text('Active Frequency'), findsOneWidget);

      // Verify 4 Dimension row titles
      expect(find.text('SOCIAL ENERGY'), findsOneWidget);
      expect(find.text('IDEAL FIRST MEET'), findsOneWidget);
      expect(find.text('LIFESTYLE PACE'), findsOneWidget);
      expect(find.text('CONNECTION GOAL'), findsOneWidget);

      // Verify Save Action Button
      expect(find.text('Save Blueprint'), findsOneWidget);

      // Tap a chip to change selection
      await tester.tap(find.text('Extrovert ⚡'));
      await tester.pumpAndSettle();

      // Tap Save Blueprint
      await tester.tap(find.text('Save Blueprint'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify saved result received the updated option
      expect(savedResult, isNotNull);
      expect(savedResult!.socialEnergy, SocialEnergy.extrovert);
    });
  });
}
