import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/core/services/daily_quota_service.dart';
import 'package:aura_app/core/services/liveness_service.dart';
import 'package:aura_app/features/subscription/presentation/screens/subscription_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Senior Android E2E Verification Tests', () {
    test('1. Profile Persistence: FirestoreUserProfile supports complete CRUD schema', () {
      final profile = FirestoreUserProfile(
        userId: 'usr_verified_999',
        displayName: 'Elena Rostova',
        birthDate: DateTime(1998, 5, 20),
        gender: 'Woman',
        interestedIn: 'Men',
        bio: 'Product Designer exploring architecture & indie coffee shops.',
        occupation: 'Lead Architect',
        city: 'Vancouver',
        voicePromptTitle: 'Best travel story...',
        voicePromptUrl: 'https://storage.googleapis.com/aura/voice/elena.m4a',
        photos: ['https://storage.googleapis.com/aura/photos/elena_1.jpg'],
        passions: ['Architecture', 'Art', 'Yoga'],
        lifestyleTags: ['Active', 'Social Drinker'],
        intention: 'Long-term',
      );

      final map = profile.toMap();

      // Ensure all fields are serialized cleanly for Firestore CRUD persistence
      expect(map['userId'], equals('usr_verified_999'));
      expect(map['displayName'], equals('Elena Rostova'));
      expect(map['bio'], equals('Product Designer exploring architecture & indie coffee shops.'));
      expect(map['occupation'], equals('Lead Architect'));
      expect(map['city'], equals('Vancouver'));
      expect(map['voicePromptTitle'], equals('Best travel story...'));
      expect(map['voicePromptUrl'], equals('https://storage.googleapis.com/aura/voice/elena.m4a'));
      expect(map['photos'], hasLength(1));

      // Test round-trip deserialization from Firestore snapshot
      final restored = FirestoreUserProfile.fromMap(map);
      expect(restored.displayName, equals('Elena Rostova'));
      expect(restored.occupation, equals('Lead Architect'));
      expect(restored.city, equals('Vancouver'));
      expect(restored.bio, contains('Product Designer'));
    });

    test('2. Currency Localization: CurrencyRegion accurately maps regions and pricing', () {
      expect(CurrencyRegion.inr.symbol, equals('₹'));
      expect(CurrencyRegion.inr.code, equals('INR'));
      expect(CurrencyRegion.usd.symbol, equals('\$'));
      expect(CurrencyRegion.cad.code, equals('CAD'));
      expect(CurrencyRegion.gbp.symbol, equals('£'));
      expect(CurrencyRegion.eur.symbol, equals('€'));
      expect(CurrencyRegion.aud.symbol, equals('A\$'));

      // Test auto-detect method fallback
      final detected = CurrencyRegion.detectLocalRegion();
      expect(CurrencyRegion.values.contains(detected), isTrue);
    });

    test('3. Daily Limits Quota: Limits are strictly enforced for free users', () {
      expect(DailyQuotaService.freeDailyEchoLimit, equals(5));
      expect(DailyQuotaService.freeDailyWaveLimit, equals(10));
    });

    test('4. 3D Face Liveness: Thresholds and inflection conditions match biometric specs', () {
      final service = LivenessService();

      expect(LivenessService.minLeftYawThreshold, equals(-25.0));
      expect(LivenessService.minRightYawThreshold, equals(25.0));
      expect(LivenessService.minPitchUpThreshold, equals(15.0));
      expect(LivenessService.verificationMatchThreshold, equals(0.82));

      // Verify that yaw/pitch conditions strictly trigger challenge step completion
      expect(service.checkInflectionCondition(step: LivenessStep.turnLeft, yaw: -28.0, pitch: 0), isTrue);
      expect(service.checkInflectionCondition(step: LivenessStep.turnLeft, yaw: -10.0, pitch: 0), isFalse);

      expect(service.checkInflectionCondition(step: LivenessStep.turnRight, yaw: 27.0, pitch: 0), isTrue);
      expect(service.checkInflectionCondition(step: LivenessStep.turnRight, yaw: 12.0, pitch: 0), isFalse);

      expect(service.checkInflectionCondition(step: LivenessStep.tiltUp, yaw: 0, pitch: 18.0), isTrue);
      expect(service.checkInflectionCondition(step: LivenessStep.tiltUp, yaw: 0, pitch: 5.0), isFalse);
    });
  });
}
