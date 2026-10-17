import 'package:aura_app/core/security/chat_encryption_helper.dart';

/// Data Model representing an individual chat message in `/conversations/{id}/messages/{messageId}`
/// Conforms to firestore.rules:
/// - requires senderId == request.auth.uid
/// - requires content.size() > 0
/// - requires sentAt is timestamp
class ChatMessageDocument {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content; // Stored as AES-256 ciphertext
  final String decryptedText; // In-memory decrypted plain text
  final String type; // 'text', 'gift', 'image'
  final DateTime sentAt;
  final bool isUnsent;
  final List<String> deletedForUsers;
  final int ttlSeconds;
  final DateTime? expiresAt;

  ChatMessageDocument({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    String? decryptedText,
    this.type = 'text',
    DateTime? sentAt,
    this.isUnsent = false,
    this.deletedForUsers = const [],
    this.ttlSeconds = 0,
    this.expiresAt,
  })  : sentAt = sentAt ?? DateTime.now(),
        decryptedText = decryptedText ??
            ChatEncryptionHelper.decryptMessage(content, conversationId);

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type,
      'sentAt': sentAt.toIso8601String(),
      'isUnsent': isUnsent,
      'deletedForUsers': deletedForUsers,
      'ttlSeconds': ttlSeconds,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  factory ChatMessageDocument.fromMap(
    Map<String, dynamic> map, {
    required String conversationId,
    String? docId,
  }) {
    final rawContent = map['content'] as String? ?? '';
    final expAt = map['expiresAt'] != null
        ? DateTime.tryParse(map['expiresAt'].toString())
        : null;

    return ChatMessageDocument(
      messageId: docId ?? map['messageId'] as String? ?? '',
      conversationId: conversationId,
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      content: rawContent,
      type: map['type'] as String? ?? 'text',
      sentAt: map['sentAt'] != null
          ? DateTime.tryParse(map['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isUnsent: map['isUnsent'] as bool? ?? false,
      deletedForUsers: List<String>.from(map['deletedForUsers'] as List? ?? []),
      ttlSeconds: (map['ttlSeconds'] as num?)?.toInt() ?? 0,
      expiresAt: expAt,
    );
  }
}
