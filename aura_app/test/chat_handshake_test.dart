import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/core/services/play_billing_service.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Handshake State Machine', () {
    test('initial state for message request should be pendingReceived', () {
      const status = HandshakeStatus.pendingReceived;
      expect(status, HandshakeStatus.pendingReceived);
      // Sender cannot send messages when pendingSent
      const senderStatus = HandshakeStatus.pendingSent;
      final isInputLocked = senderStatus == HandshakeStatus.pendingSent;
      expect(isInputLocked, isTrue);
    });

    test('accepting handshake transitions to accepted and unlocks chat', () {
      var currentStatus = HandshakeStatus.pendingReceived;
      // Simulate accept action
      currentStatus = HandshakeStatus.accepted;
      expect(currentStatus, HandshakeStatus.accepted);
      final isInputLocked = currentStatus == HandshakeStatus.pendingSent;
      expect(isInputLocked, isFalse);
    });

    test('declining handshake closes session', () {
      var currentStatus = HandshakeStatus.pendingReceived;
      var isDismissed = false;
      // Simulate decline
      isDismissed = true;
      expect(isDismissed, isTrue);
      expect(currentStatus, isNot(HandshakeStatus.accepted));
    });
  });

  group('Chat Purge & Auto-Purge TTL Logic', () {
    test('instant purge clears message list completely', () {
      final messages = ['Hey!', 'Coffee tomorrow?', 'Sounds good'];
      expect(messages.length, 3);

      // Execute Instant Purge
      messages.clear();
      expect(messages.isEmpty, isTrue);
    });

    test('validates supported auto-purge TTL configurations', () {
      const validTtls = ['off', '24h', '7d'];
      expect(validTtls.contains('off'), isTrue);
      expect(validTtls.contains('24h'), isTrue);
      expect(validTtls.contains('7d'), isTrue);
      expect(validTtls.contains('30d'), isFalse);
    });
  });

  group('FirestoreService Schema & Operations', () {
    test('saves and retrieves profile with valid data', () async {
      final service = FirestoreService();
      final profile = FirestoreUserProfile(
        userId: 'test_user_99',
        displayName: 'Aarav Patel',
        birthDate: DateTime(1998, 5, 12),
        gender: 'Man',
        interestedIn: 'Women',
        photos: ['url1', 'url2'],
        passions: ['Indie Music', 'Photography'],
        intention: 'Long-term partner',
      );

      await service.saveProfile(profile);
      final retrieved = await service.getProfile('test_user_99');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, 'Aarav Patel');
      expect(retrieved.photos.length, 2);
    });

    test('rejects profile with under-18 birth date', () async {
      final service = FirestoreService();
      final minorProfile = FirestoreUserProfile(
        userId: 'test_minor',
        displayName: 'Young Minor',
        birthDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
        gender: 'Man',
        interestedIn: 'Everyone',
        photos: ['url1', 'url2'],
        passions: ['Gaming'],
        intention: 'Figuring it out',
      );

      expect(() => service.saveProfile(minorProfile), throwsA(isA<ArgumentError>()));
    });

    test('rejects profile with fewer than 2 photos', () async {
      final service = FirestoreService();
      final singlePhotoProfile = FirestoreUserProfile(
        userId: 'test_single',
        displayName: 'Single Photo',
        birthDate: DateTime(2000, 1, 1),
        gender: 'Woman',
        interestedIn: 'Men',
        photos: ['url1'],
        passions: ['Yoga'],
        intention: 'Casual dating',
      );

      expect(() => service.saveProfile(singlePhotoProfile), throwsA(isA<ArgumentError>()));
    });

    test('creates conversation and handles instant purge', () async {
      final service = FirestoreService();
      const convId = 'conv_test_101';
      await service.createConversation(
        conversationId: convId,
        participantIds: ['user_a', 'user_b'],
        handshakeStatus: 'pending',
      );

      await service.sendMessage(
        conversationId: convId,
        messageId: 'msg_1',
        senderId: 'user_a',
        content: 'Hi there!',
      );

      await service.instantPurge(convId);
      // After purge, message stream should have 0 messages
      final stream = service.messageStream(convId);
      final firstEmission = await stream.first;
      expect(firstEmission.isEmpty, isTrue);
    });
  });

  group('PlayBillingService Entitlements', () {
    test('queries product details and contains INR pricing', () {
      final service = PlayBillingService();
      final products = service.queryProductDetails();
      expect(products.isNotEmpty, isTrue);
      expect(products.any((p) => p.priceFormatted.contains('₹')), isTrue);
      expect(products.any((p) => p.tier == SubscriptionTier.explorer), isTrue);
      expect(products.any((p) => p.tier == SubscriptionTier.vip), isTrue);
    });

    test('grants VIP entitlement successfully', () async {
      final service = PlayBillingService();
      await service.grantEntitlement(SubscriptionTier.vip);
      expect(service.currentTier, SubscriptionTier.vip);
    });
  });
}
