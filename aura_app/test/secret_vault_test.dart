import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/secret_vault_service.dart';
import 'package:aura_app/core/services/local_notification_service.dart';
import 'package:crypto/crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Principal Mobile Security: Secret Code Hidden Chat Vault Suite', () {
    late SecretVaultService vaultService;

    setUp(() async {
      vaultService = SecretVaultService();
      await vaultService.resetVault();
      await vaultService.initialize();
    });

    test('1. Secret code configuration, SHA-256 hashing, and verification integrity', () async {
      expect(await vaultService.hasSecretCodeConfigured(), isFalse);

      const rawSecretCode = 'AuraSecret2026!';
      await vaultService.setSecretCode(rawSecretCode);

      expect(await vaultService.hasSecretCodeConfigured(), isTrue);
      expect(vaultService.hasSecretCodeConfiguredSync(), isTrue);

      // Verify correct code
      final isMatch = await vaultService.verifySecretCode(rawSecretCode);
      expect(isMatch, isTrue);
      expect(vaultService.isUnlocked, isTrue);

      // Verify wrong code
      final wrongMatch = await vaultService.verifySecretCode('IncorrectPass123');
      expect(wrongMatch, isFalse);

      // Verify empty or whitespace
      expect(await vaultService.verifySecretCode(''), isFalse);
      expect(await vaultService.verifySecretCode('   '), isFalse);
    });

    test('2. SHA-256 hash match against crypto standard', () async {
      const code = 'RomanticSecret#99';
      await vaultService.setSecretCode(code);

      final expectedHash = sha256.convert(utf8.encode(code.trim())).toString();
      expect(expectedHash.isNotEmpty, isTrue);
      expect(await vaultService.verifySecretCode(code), isTrue);

      // Ensure lowercase comparison works
      expect(await vaultService.verifySecretCode(code.toLowerCase()), isFalse);
    });

    test('3. Adding and removing conversations from the Secret Vault', () async {
      expect(vaultService.hiddenConversationIds, isEmpty);
      expect(vaultService.isConversationHidden('conv_ananya_01'), isFalse);

      // Add single and multiple
      await vaultService.addConversationsToVault(['conv_ananya_01', 'conv_aarav_101']);
      expect(vaultService.hiddenConversationIds.length, equals(2));
      expect(vaultService.isConversationHidden('conv_ananya_01'), isTrue);
      expect(vaultService.isConversationHidden('conv_aarav_101'), isTrue);
      expect(vaultService.isConversationHidden('conv_other_999'), isFalse);

      // Add duplicate should not duplicate
      await vaultService.addConversationsToVault(['conv_ananya_01']);
      expect(vaultService.hiddenConversationIds.length, equals(2));

      // Remove single
      await vaultService.removeConversationFromVault('conv_ananya_01');
      expect(vaultService.isConversationHidden('conv_ananya_01'), isFalse);
      expect(vaultService.isConversationHidden('conv_aarav_101'), isTrue);
      expect(vaultService.hiddenConversationIds.length, equals(1));
    });

    test('4. Auto-Purge from memory and Lifecycle State transitions', () async {
      await vaultService.setSecretCode('AuraLifeCycleCode');
      await vaultService.verifySecretCode('AuraLifeCycleCode');
      expect(vaultService.isUnlocked, isTrue);

      // Manual memory purge
      vaultService.purgeMemoryUnlockState();
      expect(vaultService.isUnlocked, isFalse);

      // Re-unlock
      await vaultService.verifySecretCode('AuraLifeCycleCode');
      expect(vaultService.isUnlocked, isTrue);

      // Simulate AppLifecycleState.paused
      vaultService.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(vaultService.isUnlocked, isFalse);

      // Re-unlock and simulate AppLifecycleState.inactive
      await vaultService.verifySecretCode('AuraLifeCycleCode');
      expect(vaultService.isUnlocked, isTrue);
      vaultService.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(vaultService.isUnlocked, isFalse);
    });

    test('5. Stealth notification privacy guarantee: Zero sender leaks for vault chats', () async {
      const hiddenConvId = 'match_secret_agent';
      const normalConvId = 'match_normal_friend';

      await vaultService.addConversationsToVault([hiddenConvId]);
      expect(vaultService.isConversationHidden(hiddenConvId), isTrue);
      expect(vaultService.isConversationHidden(normalConvId), isFalse);

      final notifService = LocalNotificationService();

      // Trigger notification for hidden chat - should not throw and use stealth privacy
      await notifService.showChatMessageNotification(
        conversationId: hiddenConvId,
        senderName: 'Sanjay (Secret Crush)',
        messagePreview: 'Meet me at Bandra Bandstand at 8 PM tonight ❤️',
      );

      final hiddenPayload = notifService.lastChatMessageNotificationPayload;
      expect(hiddenPayload, isNotNull);
      expect(hiddenPayload!['displayTitle'], equals('New Message Received'));
      expect(hiddenPayload['displayBody'], contains('Encrypted notification'));
      expect(hiddenPayload['displayBody'].toString().contains('Secret Crush'), isFalse);
      expect(hiddenPayload['isHidden'], isTrue);

      // Trigger notification for normal chat
      await notifService.showChatMessageNotification(
        conversationId: normalConvId,
        senderName: 'Maya Lin',
        messagePreview: 'Hey! Loved your profile on the proximity radar ✨',
      );

      final normalPayload = notifService.lastChatMessageNotificationPayload;
      expect(normalPayload, isNotNull);
      expect(normalPayload!['displayTitle'], equals('Maya Lin'));
      expect(normalPayload['displayBody'], equals('Hey! Loved your profile on the proximity radar ✨'));
      expect(normalPayload['isHidden'], isFalse);
    });
  });
}
