/// Data Model representing a Conversation in Firestore /conversations/{conversationId}
/// Conforms to firestore.rules:
/// - requires participantIds size == 2
/// - requires handshakeStatus in ['pending', 'accepted', 'declined']
class ConversationDocument {
  final String conversationId;
  final List<String> participantIds;
  final String handshakeStatus;
  final String? lastMessage;
  final DateTime? lastMessageTimestamp;
  final int autoPurgeTtlSeconds;
  final int chemistryScore;
  final DateTime createdAt;

  ConversationDocument({
    required this.conversationId,
    required this.participantIds,
    this.handshakeStatus = 'accepted',
    this.lastMessage,
    this.lastMessageTimestamp,
    this.autoPurgeTtlSeconds = 0, // 0 = off, 86400 = 24h, -1 = upon exit
    this.chemistryScore = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestoreMap() {
    return {
      'conversationId': conversationId,
      'participantIds': participantIds,
      'handshakeStatus': handshakeStatus,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp?.toIso8601String(),
      'autoPurgeTtlSeconds': autoPurgeTtlSeconds,
      'chemistryScore': chemistryScore,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ConversationDocument.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ConversationDocument(
      conversationId: docId ?? map['conversationId'] as String? ?? '',
      participantIds: List<String>.from(map['participantIds'] as List? ?? []),
      handshakeStatus: map['handshakeStatus'] as String? ?? 'accepted',
      lastMessage: map['lastMessage'] as String?,
      lastMessageTimestamp: map['lastMessageTimestamp'] != null
          ? DateTime.tryParse(map['lastMessageTimestamp'].toString())
          : null,
      autoPurgeTtlSeconds: (map['autoPurgeTtlSeconds'] as num?)?.toInt() ?? 0,
      chemistryScore: (map['chemistryScore'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ConversationDocument copyWith({
    String? handshakeStatus,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    int? autoPurgeTtlSeconds,
    int? chemistryScore,
  }) {
    return ConversationDocument(
      conversationId: conversationId,
      participantIds: participantIds,
      handshakeStatus: handshakeStatus ?? this.handshakeStatus,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      autoPurgeTtlSeconds: autoPurgeTtlSeconds ?? this.autoPurgeTtlSeconds,
      chemistryScore: chemistryScore ?? this.chemistryScore,
      createdAt: createdAt,
    );
  }
}
