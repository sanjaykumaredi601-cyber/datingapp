import '../../data/models/chat_message_document.dart';
import '../../data/models/conversation_document.dart';

/// Contract for Two-Way Encrypted Chat Messaging with TTL Purge in Cloud Firestore
abstract class ChatRepository {
  /// Upserts conversation document `/conversations/{conversationId}`
  Future<void> createConversation(ConversationDocument conversation);

  /// Retrieves list of user's active conversations
  Future<List<ConversationDocument>> getConversations(String userId);

  /// Sends an end-to-end encrypted message into subcollection `/conversations/{id}/messages`
  Future<void> sendEncryptedMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String receiverId,
    required String plainText,
    int ttlSeconds = 0,
    String type = 'text',
  });

  /// Real-time stream of decrypted messages in a conversation
  Stream<List<ChatMessageDocument>> messageStream(String conversationId);

  /// Purges messages whose TTL has expired
  Future<void> purgeExpiredMessages(String conversationId);

  /// Nuclear Instant Wipe: immediately clears all messages in conversation across cloud and memory
  Future<void> instantPurge(String conversationId);

  /// Sets auto-purge TTL for conversation (e.g. 0, 86400, or upon exit)
  Future<void> setAutoPurgeTtl(String conversationId, int ttlSeconds);
}
