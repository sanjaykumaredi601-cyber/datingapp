import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/features/chat/domain/services/vibe_spark_engine.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart'
    show ChatMessage, MessageType;
import 'package:aura_app/features/chat/presentation/widgets/vibe_temperature_bar.dart';
import 'package:aura_app/features/chat/presentation/widgets/vibe_spark_ignition_modal.dart';

void main() {
  group('VibeSparkEngine Unit Tests', () {
    late VibeSparkEngine engine;

    setUp(() {
      engine = VibeSparkEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('Initial score is 0 and hasIgnited is false', () {
      expect(engine.currentScore, equals(0));
      expect(engine.hasIgnited, isFalse);
    });

    test('Empty messages yield 0 for all factors', () {
      final breakdown = engine.calculateBreakdown(
        messages: [],
        currentUserId: 'user_1',
      );
      expect(breakdown.balanceScore, equals(0.0));
      expect(breakdown.momentumScore, equals(0.0));
      expect(breakdown.depthScore, equals(0.0));
      expect(breakdown.totalScore, equals(0));
      expect(breakdown.tier, equals('Frosted Glacial'));
    });

    test('Balanced exchange yields high balance score', () {
      final now = DateTime.now();
      final messages = List.generate(
        10,
        (i) => ChatMessage(
          id: '$i',
          matchId: 'match_1',
          senderId: i.isEven ? 'user_1' : 'user_2',
          content: 'Hello message $i',
          sentAt: now.subtract(Duration(minutes: 10 - i)),
          isMine: i.isEven,
        ),
      );

      final breakdown = engine.calculateBreakdown(
        messages: messages,
        currentUserId: 'user_1',
      );

      // Both users sent exactly 5 messages (perfect 1.0 balance ratio and 1.0 volume)
      expect(breakdown.balanceScore, greaterThanOrEqualTo(30.0));
    });

    test('One-sided conversation yields low balance score', () {
      final now = DateTime.now();
      final messages = List.generate(
        10,
        (i) => ChatMessage(
          id: '$i',
          matchId: 'match_1',
          senderId: 'user_1',
          content: 'One-sided spam $i',
          sentAt: now.subtract(Duration(minutes: 10 - i)),
          isMine: true,
        ),
      );

      final breakdown = engine.calculateBreakdown(
        messages: messages,
        currentUserId: 'user_1',
      );

      // Peer sent 0 messages
      expect(breakdown.balanceScore, equals(0.0));
    });

    test('Rapid reply burst (< 45s) yields high momentum score', () {
      final now = DateTime.now();
      final messages = [
        ChatMessage(
          id: '1',
          matchId: 'match_1',
          senderId: 'user_1',
          content: 'Hey there! How are you?',
          sentAt: now.subtract(const Duration(seconds: 120)),
          isMine: true,
        ),
        ChatMessage(
          id: '2',
          matchId: 'match_1',
          senderId: 'user_2',
          content: 'I am wonderful! Just left the concert.',
          sentAt: now.subtract(const Duration(seconds: 95)), // 25s reply
          isMine: false,
        ),
        ChatMessage(
          id: '3',
          matchId: 'match_1',
          senderId: 'user_1',
          content: 'No way, which band was playing tonight?',
          sentAt: now.subtract(const Duration(seconds: 70)), // 25s reply
          isMine: true,
        ),
        ChatMessage(
          id: '4',
          matchId: 'match_1',
          senderId: 'user_2',
          content: 'Coldplay live acoustics at the amphitheater!',
          sentAt: now.subtract(const Duration(seconds: 40)), // 30s reply
          isMine: false,
        ),
      ];

      final breakdown = engine.calculateBreakdown(
        messages: messages,
        currentUserId: 'user_1',
      );

      expect(breakdown.momentumScore, greaterThanOrEqualTo(25.0));
    });

    test('Rich interaction depth adds points for questions, media & length', () {
      final now = DateTime.now();
      final messages = [
        ChatMessage(
          id: '1',
          matchId: 'match_1',
          senderId: 'user_1',
          content: 'What is your favorite memory from visiting Tokyo? Would love to know!',
          sentAt: now.subtract(const Duration(minutes: 5)),
          isMine: true,
        ),
        ChatMessage(
          id: '2',
          matchId: 'match_1',
          senderId: 'user_2',
          content: 'Voice note from Tokyo cherry blossom festival',
          type: MessageType.voiceNote,
          sentAt: now.subtract(const Duration(minutes: 4)),
          isMine: false,
        ),
        ChatMessage(
          id: '3',
          matchId: 'match_1',
          senderId: 'user_1',
          content: 'Photo from the rooftop observatory overlooking Shibuya crossing',
          type: MessageType.image,
          sentAt: now.subtract(const Duration(minutes: 3)),
          isMine: true,
        ),
      ];

      final breakdown = engine.calculateBreakdown(
        messages: messages,
        currentUserId: 'user_1',
      );

      expect(breakdown.depthScore, greaterThanOrEqualTo(20.0));
    });

    test('High engagement triggers 80% ignition event exactly once per session', () async {
      int ignitionTriggerCount = 0;
      int capturedIgnitionScore = 0;

      engine.ignitionStream.listen((score) {
        ignitionTriggerCount++;
        capturedIgnitionScore = score;
      });

      // Emulate score of 85 directly via remote score update
      engine.onRemoteScoreReceived(85);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(engine.currentScore, equals(85));
      expect(engine.hasIgnited, isTrue);
      expect(ignitionTriggerCount, equals(1));
      expect(capturedIgnitionScore, equals(85));

      // Subsequent update above 80 should not duplicate trigger in the same session
      engine.onRemoteScoreReceived(92);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(engine.currentScore, equals(92));
      expect(ignitionTriggerCount, equals(1)); // Still 1!

      // Resetting session allows re-trigger
      engine.resetIgnitionSession();
      expect(engine.hasIgnited, isFalse);

      engine.onRemoteScoreReceived(95);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(ignitionTriggerCount, equals(2));
    });
  });

  group('Vibe Temperature Bar Widget Tests', () {
    testWidgets('Renders 4px temperature bar and updates pill badge on tap',
        (tester) async {
      int thresholdTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VibeTemperatureBar(
                score: 84,
                onThresholdTap: () => thresholdTaps++,
              ),
            ),
          ),
        ),
      );

      // Verify widget renders
      expect(find.byType(VibeTemperatureBar), findsOneWidget);

      // Tap track to reveal pill badge
      await tester.tap(find.byType(VibeTemperatureBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check text in pill badge
      expect(find.text('84% Vibe Resonance'), findsOneWidget);
      expect(thresholdTaps, equals(1));
    });

    testWidgets('Renders Frosted Glacial Blue for score < 50', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: VibeTemperatureBar(score: 35),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VibeTemperatureBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('35% Vibe Resonance'), findsOneWidget);
      expect(find.text('(Frosted Glacial)'), findsOneWidget);
    });

    testWidgets('Renders Electric Iris for score 50-79', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: VibeTemperatureBar(score: 68),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VibeTemperatureBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('68% Vibe Resonance'), findsOneWidget);
      expect(find.text('(Electric Iris)'), findsOneWidget);
    });
  });

  group('80% Spark Ignition Modal & Date Concierge Tests', () {
    testWidgets('Modal displays thermometer, copy, and triggers Date Concierge',
        (tester) async {
      String? sentInvite;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    VibeSparkIgnitionModal.show(
                      context,
                      score: 88,
                      matchName: 'Sophia',
                      onDatePlanSelected: (invite) => sentInvite = invite,
                    );
                  },
                  child: const Text('Show Modal'),
                );
              },
            ),
          ),
        ),
      );

      // Trigger modal
      await tester.tap(find.text('Show Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify title and copy
      expect(find.text('🔥 Resonance Ignited!'), findsOneWidget);
      expect(
        find.text(
          'Your conversation wavelength is in the top 5%. The moment feels right to meet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Plan a Date Now ✨'), findsOneWidget);
      expect(find.text('Keep Vibeing'), findsOneWidget);

      // Tap "Plan a Date Now ✨" to open DateConciergeSheet
      await tester.tap(find.text('Plan a Date Now ✨'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Date Concierge Sheet is shown
      expect(find.textContaining('CONCIERGE'), findsOneWidget);
      expect(find.text('Plan with Sophia'), findsOneWidget);
      expect(find.textContaining('Send Date Invitation'), findsOneWidget);

      // Send the date invitation
      await tester.tap(find.textContaining('Send Date Invitation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(sentInvite, contains('Date Ignition Invitation'));
    });
  });
}
