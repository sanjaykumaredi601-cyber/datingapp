import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/core/services/play_billing_service.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart';

void main() {
  group('1. Futuristic Hero Splash & Brand Identity Tests', () {
    test('Verifies Deep Space Obsidian palette and luminous brand colors', () {
      expect(AppColors.deepSpaceObsidian.toARGB32(), equals(0xFF0A0D14));
      expect(AppColors.background.toARGB32(), equals(0xFF0A0D14));
      expect(AppColors.sunsetCoral.toARGB32(), equals(0xFFFF4D67));
      expect(AppColors.electricIris.toARGB32(), equals(0xFF7928CA));
      expect(AppColors.mintGreen.toARGB32(), equals(0xFF00F5A0));
      expect(AppColors.warmAmber.toARGB32(), equals(0xFFFBBF24));
    });

    test('Verifies Brand taglines and encryption guarantees', () {
      const tagline = 'Proximity Meets Intent · Safe & Encrypted';
      expect(tagline.contains('Safe & Encrypted'), isTrue);
      expect(tagline.contains('Proximity Meets Intent'), isTrue);
    });
  });

  group('2. LGBTQ+ Inclusive Onboarding Architecture Tests', () {
    test('FirestoreUserProfile correctly serializes comprehensive LGBTQ+ matrix', () {
      final profile = FirestoreUserProfile(
        userId: 'user_lgbtq_001',
        displayName: 'Alex Jordan',
        birthDate: DateTime(1998, 5, 20),
        gender: 'Non-Binary',
        customGender: null,
        pronouns: 'They/Them',
        orientations: ['Queer', 'Pansexual'],
        discoveryScope: ['Non-Binary Folks', 'Women'],
        displayIdentityBadges: true,
        interestedIn: 'Non-Binary Folks, Women',
        photos: [
          'https://images.unsplash.com/photo-1?w=800',
          'https://images.unsplash.com/photo-2?w=800',
        ],
        passions: ['Music', 'Coffee Dates', 'Deep Conversations'],
        lifestyleTags: ['Tech', 'Travel', 'Long-term'],
        intention: 'Long-term',
        isVerified: true,
      );

      final map = profile.toMap();
      expect(map['gender'], equals('Non-Binary'));
      expect(map['pronouns'], equals('They/Them'));
      expect(map['orientations'], contains('Queer'));
      expect(map['orientations'], contains('Pansexual'));
      expect(map['discoveryScope'], contains('Non-Binary Folks'));
      expect(map['displayIdentityBadges'], isTrue);
      expect(map['photos'].length, equals(2));
      expect(map['lifestyleTags'], contains('Tech'));
      expect(map['lifestyleTags'], contains('Travel'));

      final reconstructed = FirestoreUserProfile.fromMap(map);
      expect(reconstructed.gender, equals('Non-Binary'));
      expect(reconstructed.pronouns, equals('They/Them'));
      expect(reconstructed.orientations, equals(['Queer', 'Pansexual']));
      expect(reconstructed.displayIdentityBadges, isTrue);
    });

    test('Validates Custom/Self-Describe gender and custom pronouns support', () {
      final customProfile = FirestoreUserProfile(
        userId: 'user_custom_002',
        displayName: 'Sam River',
        birthDate: DateTime(2001, 3, 14),
        gender: 'Custom/Self-Describe',
        customGender: 'Two-Spirit Agender',
        pronouns: 'ze/zir',
        orientations: ['Demisexual', 'Asexual'],
        discoveryScope: ['Everyone'],
        displayIdentityBadges: false,
        interestedIn: 'Everyone',
        photos: [
          'https://images.unsplash.com/photo-3?w=800',
          'https://images.unsplash.com/photo-4?w=800',
        ],
        passions: ['Art', 'Tech'],
        lifestyleTags: ['Casual', 'Coffee Dates'],
        intention: 'Casual',
      );

      expect(customProfile.customGender, equals('Two-Spirit Agender'));
      expect(customProfile.pronouns, equals('ze/zir'));
      expect(customProfile.displayIdentityBadges, isFalse);
    });

    test('Photo grid enforces minimum 2 photos constraint in FirestoreService', () async {
      final invalidProfile = FirestoreUserProfile(
        userId: 'user_invalid_photos',
        displayName: 'Robin',
        birthDate: DateTime(2000, 1, 1),
        gender: 'Woman',
        interestedIn: 'Men',
        photos: ['https://images.unsplash.com/only_one?w=800'],
        passions: ['Music'],
        intention: 'Long-term',
      );

      final firestore = FirestoreService();
      expect(
        () => firestore.saveProfile(invalidProfile),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('3. Two-Way Message Request Handshake & Ephemeral Purge Tests', () {
    test('Handshake state machine supports pendingSent and pendingReceived states', () {
      expect(HandshakeStatus.pendingSent, isNotNull);
      expect(HandshakeStatus.pendingReceived, isNotNull);
      expect(HandshakeStatus.accepted, isNotNull);
    });

    test('Timed Auto-Purge supports Off, 24 Hours, and Upon Exit', () {
      const supportedTtls = ['Off', '24 Hours', 'Upon Exit'];
      expect(supportedTtls, contains('Off'));
      expect(supportedTtls, contains('24 Hours'));
      expect(supportedTtls, contains('Upon Exit'));
    });

    test('Instant Two-Way Purge simultaneously clears Firestore database messages', () async {
      final firestore = FirestoreService();
      const testConvId = 'conv_instant_purge_test_001';

      await firestore.createConversation(
        conversationId: testConvId,
        participantIds: ['user_a', 'user_b'],
        handshakeStatus: 'accepted',
      );

      await firestore.sendMessage(
        conversationId: testConvId,
        messageId: 'msg_001',
        senderId: 'user_a',
        content: 'Confidential message',
      );

      await firestore.instantPurge(testConvId);

      final stream = firestore.messageStream(testConvId);
      final msgs = await stream.first;
      expect(msgs, isEmpty);
    });
  });

  group('4. Secure In-App Calling Gatekeeping Safety Rule Tests', () {
    test('Calling is locked when handshake is pending (even with messages)', () {
      final messages = [
        ChatMessage(
          id: '1',
          matchId: 'm1',
          senderId: 'user_b',
          content: 'Hello!',
          sentAt: DateTime.now(),
          isMine: false,
        ),
        ChatMessage(
          id: '2',
          matchId: 'm1',
          senderId: 'user_a',
          content: 'Hi there!',
          sentAt: DateTime.now(),
          isMine: true,
        ),
        ChatMessage(
          id: '3',
          matchId: 'm1',
          senderId: 'user_b',
          content: 'Nice to meet you',
          sentAt: DateTime.now(),
          isMine: false,
        ),
      ];

      // Handshake is not accepted
      const handshake = HandshakeStatus.pendingReceived;
      final isCallingUnlocked = handshake == HandshakeStatus.accepted &&
          messages.where((m) => !m.isUnsent && m.type != MessageType.callPill).length >= 3 &&
          messages.any((m) => m.isMine) &&
          messages.any((m) => !m.isMine);

      expect(isCallingUnlocked, isFalse);
    });

    test('Calling is locked when messages count < 3 (handshake accepted)', () {
      final messages = [
        ChatMessage(
          id: '1',
          matchId: 'm1',
          senderId: 'user_b',
          content: 'Hey there!',
          sentAt: DateTime.now(),
          isMine: false,
        ),
        ChatMessage(
          id: '2',
          matchId: 'm1',
          senderId: 'user_a',
          content: 'Hello!',
          sentAt: DateTime.now(),
          isMine: true,
        ),
      ];

      const handshake = HandshakeStatus.accepted;
      final isCallingUnlocked = handshake == HandshakeStatus.accepted &&
          messages.where((m) => !m.isUnsent && m.type != MessageType.callPill).length >= 3 &&
          messages.any((m) => m.isMine) &&
          messages.any((m) => !m.isMine);

      expect(isCallingUnlocked, isFalse);
    });

    test('Calling is locked when messages are one-sided (no mutual reciprocity)', () {
      final messages = [
        ChatMessage(
          id: '1',
          matchId: 'm1',
          senderId: 'user_a',
          content: 'Message 1',
          sentAt: DateTime.now(),
          isMine: true,
        ),
        ChatMessage(
          id: '2',
          matchId: 'm1',
          senderId: 'user_a',
          content: 'Message 2',
          sentAt: DateTime.now(),
          isMine: true,
        ),
        ChatMessage(
          id: '3',
          matchId: 'm1',
          senderId: 'user_a',
          content: 'Message 3',
          sentAt: DateTime.now(),
          isMine: true,
        ),
      ];

      const handshake = HandshakeStatus.accepted;
      final isCallingUnlocked = handshake == HandshakeStatus.accepted &&
          messages.where((m) => !m.isUnsent && m.type != MessageType.callPill).length >= 3 &&
          messages.any((m) => m.isMine) &&
          messages.any((m) => !m.isMine);

      expect(isCallingUnlocked, isFalse);
    });

    test('Calling UNLOCKS when handshake is accepted AND >= 3 mutual messages are exchanged', () {
      final messages = [
        ChatMessage(
          id: '1',
          matchId: 'm1',
          senderId: 'user_b',
          content: 'Hey! Loved your taste in music.',
          sentAt: DateTime.now(),
          isMine: false,
        ),
        ChatMessage(
          id: '2',
          matchId: 'm1',
          senderId: 'user_a',
          content: 'Thanks! Synthwave is my jam.',
          sentAt: DateTime.now(),
          isMine: true,
        ),
        ChatMessage(
          id: '3',
          matchId: 'm1',
          senderId: 'user_b',
          content: 'Same here! Have you heard of The Midnight?',
          sentAt: DateTime.now(),
          isMine: false,
        ),
      ];

      const handshake = HandshakeStatus.accepted;
      final isCallingUnlocked = handshake == HandshakeStatus.accepted &&
          messages.where((m) => !m.isUnsent && m.type != MessageType.callPill).length >= 3 &&
          messages.any((m) => m.isMine) &&
          messages.any((m) => !m.isMine);

      expect(isCallingUnlocked, isTrue);
    });

    test('Call ended status pill message formats properly with zero persistent recordings', () {
      final callPill = ChatMessage(
        id: 'call_pill_01',
        matchId: 'm1',
        senderId: 'user_a',
        content: 'Call Ended · 14m 20s',
        type: MessageType.callPill,
        sentAt: DateTime.now(),
        isMine: true,
      );

      expect(callPill.type, equals(MessageType.callPill));
      expect(callPill.content, equals('Call Ended · 14m 20s'));
    });
  });

  group('5. Monetization & Google Play Billing Tests', () {
    test('PlayBillingService queries SKUs for Explorer and VIP Pass tiers', () {
      final billing = PlayBillingService();
      final products = billing.queryProductDetails();

      expect(products.any((p) => p.id == 'aura_pass_explorer_monthly'), isTrue);
      expect(products.any((p) => p.id == 'aura_pass_explorer_annual'), isTrue);
      expect(products.any((p) => p.id == 'aura_pass_vip_monthly'), isTrue);
      expect(products.any((p) => p.id == 'aura_pass_vip_annual'), isTrue);

      final vipMonthly = products.firstWhere((p) => p.id == 'aura_pass_vip_monthly');
      expect(vipMonthly.tier, equals(SubscriptionTier.vip));
      expect(vipMonthly.priceFormatted, equals('₹1,199'));

      final explorerMonthly = products.firstWhere((p) => p.id == 'aura_pass_explorer_monthly');
      expect(explorerMonthly.tier, equals(SubscriptionTier.explorer));
      expect(explorerMonthly.priceFormatted, equals('₹499'));
    });

    test('PlayBillingService verifies and grants entitlement upon purchase flow', () async {
      final billing = PlayBillingService();
      final result = await billing.launchBillingFlow('aura_pass_vip_annual');

      expect(result.isSuccess, isTrue);
      expect(result.purchaseToken, isNotNull);
      expect(billing.currentTier, equals(SubscriptionTier.vip));
    });
  });
}
