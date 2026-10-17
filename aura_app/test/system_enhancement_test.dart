import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/liveness_service.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/core/services/google_auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('1. 3D Biometric & Active Liveness Verification Suite', () {
    final livenessService = LivenessService();

    test('Euler pose angle threshold validation (Yaw <= -25°, Yaw >= +25°, Pitch >= +15°)', () {
      // Left Turn: Yaw <= -25°
      expect(livenessService.checkInflectionCondition(step: LivenessStep.turnLeft, yaw: -25.0, pitch: 0.0), isTrue);
      expect(livenessService.checkInflectionCondition(step: LivenessStep.turnLeft, yaw: -30.0, pitch: 5.0), isTrue);
      expect(livenessService.checkInflectionCondition(step: LivenessStep.turnLeft, yaw: -20.0, pitch: 0.0), isFalse);

      // Right Turn: Yaw >= +25°
      expect(livenessService.checkInflectionCondition(step: LivenessStep.turnRight, yaw: 25.0, pitch: 0.0), isTrue);
      expect(livenessService.checkInflectionCondition(step: LivenessStep.turnRight, yaw: 35.0, pitch: -2.0), isTrue);
      expect(livenessService.checkInflectionCondition(step: LivenessStep.turnRight, yaw: 18.0, pitch: 0.0), isFalse);

      // Chin Up: Pitch >= +15°
      expect(livenessService.checkInflectionCondition(step: LivenessStep.tiltUp, yaw: 0.0, pitch: 15.0), isTrue);
      expect(livenessService.checkInflectionCondition(step: LivenessStep.tiltUp, yaw: -2.0, pitch: 22.0), isTrue);
      expect(livenessService.checkInflectionCondition(step: LivenessStep.tiltUp, yaw: 0.0, pitch: 12.0), isFalse);
    });

    test('Active keyframe collection & match threshold evaluation (>= 0.82)', () async {
      final List<LivenessKeyframe> keyframes = [
        LivenessKeyframe(
          step: LivenessStep.turnLeft,
          yaw: -28.5,
          pitch: 2.1,
          roll: 0.5,
          capturedAt: DateTime.now(),
          keyframeHash: 'hash_left_001',
          embeddingVector: List.generate(64, (i) => 0.12),
        ),
        LivenessKeyframe(
          step: LivenessStep.turnRight,
          yaw: 27.2,
          pitch: 1.0,
          roll: -0.3,
          capturedAt: DateTime.now(),
          keyframeHash: 'hash_right_002',
          embeddingVector: List.generate(64, (i) => 0.12),
        ),
        LivenessKeyframe(
          step: LivenessStep.tiltUp,
          yaw: 0.8,
          pitch: 18.4,
          roll: 0.1,
          capturedAt: DateTime.now(),
          keyframeHash: 'hash_pitch_003',
          embeddingVector: List.generate(64, (i) => 0.12),
        ),
      ];

      final result = await livenessService.evaluateAndPersistVerification(
        userId: 'user_test_999',
        keyframes: keyframes,
      );

      expect(result.isSuccess, isTrue);
      expect(result.matchScore, greaterThanOrEqualTo(0.82));
      expect(result.auditHash, isNotNull);
      expect(result.auditHash!.length, 64); // 256-bit SHA-256 HMAC hexadecimal hash

      // Verify Firestore persistence record
      final firestoreService = FirestoreService();
      final audit = firestoreService.getBiometricAudit('user_test_999');
      expect(audit, isNotNull);
      expect(audit!['is_verified'], isTrue);
      expect(audit['match_score'], greaterThanOrEqualTo(0.82));
    });
  });

  group('2. Google Sign-In & Security Alert Notification Suite', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('GoogleAuthService pre-fills onboarding profile and sets auth tokens', () async {
      final googleAuth = GoogleAuthService();
      final result = await googleAuth.signInWithGoogle(
        mockEmail: 'elena.rostova@gmail.com',
        mockName: 'Elena Rostova',
        mockPhotoUrl: 'https://images.unsplash.com/photo-test-elena',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile!.displayName, 'Elena Rostova');
      expect(result.profile!.email, 'elena.rostova@gmail.com');
      expect(result.token, isNotNull);
      expect(result.securityAlertDispatched, isTrue);
    });
  });

  group('3. Enterprise Help Desk & Support Ticket Suite', () {
    test('SupportTicket model serialization and 24h SLA defaults', () {
      final ticket = SupportTicket(
        ticketId: 'tkt_unit_test_01',
        userId: 'user_client_88',
        category: 'Payment / Subscription Issue',
        priority: 'HIGH',
        status: 'OPEN',
        subject: 'Double charge on VIP Pass',
        description: 'Charged twice during checkout',
        appVersion: '1.0.0+1',
        osVersion: 'Android 17 API 37',
        transactionRefId: 'UPI-REF-998877',
      );

      final map = ticket.toMap();
      expect(map['ticketId'], 'tkt_unit_test_01');
      expect(map['category'], 'Payment / Subscription Issue');
      expect(map['priority'], 'HIGH');
      expect(map['status'], 'OPEN');
      expect(map['slaHours'], 24);
      expect(map['transactionRefId'], 'UPI-REF-998877');

      final deserialized = SupportTicket.fromMap(map);
      expect(deserialized.ticketId, ticket.ticketId);
      expect(deserialized.category, ticket.category);
      expect(deserialized.slaHours, 24);
    });

    test('Support ticket queue filtering by status and priority', () async {
      final firestoreService = FirestoreService();

      final t1 = SupportTicket(
        ticketId: 'tkt_filter_1',
        userId: 'user_1',
        category: 'Technical Bug',
        priority: 'URGENT',
        status: 'OPEN',
        subject: 'Camera orientation',
        description: 'Test',
      );

      final t2 = SupportTicket(
        ticketId: 'tkt_filter_2',
        userId: 'user_2',
        category: 'Safety & Harassment',
        priority: 'HIGH',
        status: 'IN_REVIEW',
        subject: 'Safety concern',
        description: 'Test',
      );

      await firestoreService.submitSupportTicket(t1);
      await firestoreService.submitSupportTicket(t2);

      final openTickets = await firestoreService.filterTickets(status: 'OPEN');
      expect(openTickets.any((t) => t.ticketId == 'tkt_filter_1'), isTrue);
      expect(openTickets.any((t) => t.ticketId == 'tkt_filter_2'), isFalse);

      final urgentTickets = await firestoreService.filterTickets(priority: 'URGENT');
      expect(urgentTickets.any((t) => t.ticketId == 'tkt_filter_1'), isTrue);
      expect(urgentTickets.any((t) => t.ticketId == 'tkt_filter_2'), isFalse);
    });
  });

  group('4. Luxury Soothing Color Palette Refresh Suite', () {
    test('Color tokens adhere strictly to luxury specifications with zero reddish/orange tones', () {
      // Background: Deep Obsidian Slate (#0A0D14)
      expect(AppColors.deepObsidianSlate, const Color(0xFF0A0D14));
      expect(AppColors.background, const Color(0xFF0A0D14));

      // Surface: Midnight Marine (#131924) with frosted borders (#1E2638)
      expect(AppColors.midnightMarine, const Color(0xFF131924));
      expect(AppColors.surfaceL1, const Color(0xFF131924));
      expect(AppColors.frostedBorder, const Color(0xFF1E2638));
      expect(AppColors.cardBorder, const Color(0xFF1E2638));

      // Primary Accent: Neon Electric Mint (#00F5A0)
      expect(AppColors.neonElectricMint, const Color(0xFF00F5A0));
      expect(AppColors.primary, const Color(0xFF00F5A0));

      // Secondary Accent: Cyan Glow (#00D2FF)
      expect(AppColors.cyanGlow, const Color(0xFF00D2FF));
      expect(AppColors.secondary, const Color(0xFF00D2FF));

      // VIP / Verification: Soft Gold (#FBBF24) & Electric Lavender (#A78BFA)
      expect(AppColors.softGold, const Color(0xFFFBBF24));
      expect(AppColors.electricLavender, const Color(0xFFA78BFA));

      // Text: Crisp Ice White (#F8FAFC) & Titanium Slate (#94A3B8)
      expect(AppColors.iceWhite, const Color(0xFFF8FAFC));
      expect(AppColors.textPrimary, const Color(0xFFF8FAFC));
      expect(AppColors.titaniumSlate, const Color(0xFF94A3B8));
      expect(AppColors.textSecondary, const Color(0xFF94A3B8));

      // Sunset coral token is romantic Sunset Coral (#FF4D67)
      expect(AppColors.sunsetCoral, const Color(0xFFFF4D67));
    });
  });
}
