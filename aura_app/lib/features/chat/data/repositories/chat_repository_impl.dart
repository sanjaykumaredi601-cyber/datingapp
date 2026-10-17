import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:aura_app/core/security/chat_encryption_helper.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_message_document.dart';
import '../models/conversation_document.dart';

/// Production Implementation of ChatRepository with Cloud Firestore and AES-256 E2EE
class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore? _firestore;

  // Local caching layers for offline/immediate UI responsiveness
  final Map<String, ConversationDocument> _localConversations = {};
  final Map<String, List<ChatMessageDocument>> _localMessages = {};
  final Map<String, StreamController<List<ChatMessageDocument>>> _controllers = {};

  ChatRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore();

  static FirebaseFirestore? _safeFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[ChatRepo] FirebaseFirestore not initialized: $e');
      return null;
    }
  }

  @override
  Future<void> createConversation(ConversationDocument conversation) async {
    _localConversations[conversation.conversationId] = conversation;
    _localMessages[conversation.conversationId] ??= [];

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('conversations')
            .doc(conversation.conversationId)
            .set(conversation.toFirestoreMap(), SetOptions(merge: true));
        debugPrint('[ChatRepo] Created conversation: ${conversation.conversationId}');
      } catch (e) {
        debugPrint('[ChatRepo] Firestore createConversation error: $e');
      }
    }
  }

  @override
  Future<List<ConversationDocument>> getConversations(String userId) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('conversations')
            .where('participantIds', arrayContains: userId)
            .orderBy('lastMessageTimestamp', descending: true)
            .get();

        final cloudList = snap.docs
            .map((d) => ConversationDocument.fromMap(d.data(), docId: d.id))
            .toList();

        for (final c in cloudList) {
          _localConversations[c.conversationId] = c;
        }
        return cloudList;
      } catch (e) {
        debugPrint('[ChatRepo] Firestore getConversations error: $e');
      }
    }

    return _localConversations.values
        .where((c) => c.participantIds.contains(userId))
        .toList();
  }

  @override
  Future<void> sendEncryptedMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String receiverId,
    required String plainText,
    int ttlSeconds = 0,
    String type = 'text',
  }) async {
    // 1. Two-way AES-256 encryption
    final encryptedCiphertext =
        ChatEncryptionHelper.encryptMessage(plainText, conversationId);

    final now = DateTime.now();
    final expiresAt =
        ttlSeconds > 0 ? now.add(Duration(seconds: ttlSeconds)) : null;

    final messageDoc = ChatMessageDocument(
      messageId: messageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: encryptedCiphertext,
      decryptedText: plainText,
      type: type,
      sentAt: now,
      ttlSeconds: ttlSeconds,
      expiresAt: expiresAt,
    );

    // 2. Insert into local memory for instant rendering
    _localMessages[conversationId] ??= [];
    _localMessages[conversationId]!.insert(0, messageDoc);
    _notify(conversationId);

    // 3. Update conversation lastMessage
    if (_localConversations.containsKey(conversationId)) {
      _localConversations[conversationId] = _localConversations[conversationId]!
          .copyWith(lastMessage: plainText, lastMessageTimestamp: now);
    }

    // 4. Cloud Firestore subcollection sync
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final batch = firestore.batch();
        final msgRef = firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId);

        batch.set(msgRef, messageDoc.toFirestoreMap());

        final convRef =
            firestore.collection('conversations').doc(conversationId);
        batch.set(
            convRef,
            {
              'lastMessage': encryptedCiphertext,
              'lastMessageTimestamp': now.toIso8601String(),
            },
            SetOptions(merge: true));

        await batch.commit();
        debugPrint('[ChatRepo] Encrypted message synced: $messageId');
      } catch (e) {
        debugPrint('[ChatRepo] Firestore sync fallback: $e');
      }
    }
  }

  @override
  Stream<List<ChatMessageDocument>> messageStream(String conversationId) {
    if (!_controllers.containsKey(conversationId)) {
      _controllers[conversationId] =
          StreamController<List<ChatMessageDocument>>.broadcast();

      // Listen to Firestore collection in real-time
      final firestore = _firestore;
      if (firestore != null) {
        firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('sentAt', descending: true)
            .snapshots()
            .listen(
          (snapshot) {
            final msgs = snapshot.docs
                .map((d) => ChatMessageDocument.fromMap(d.data(),
                    conversationId: conversationId, docId: d.id))
                .where((m) => !m.isExpired)
                .toList();

            _localMessages[conversationId] = msgs;
            _notify(conversationId);
          },
          onError: (e) {
            debugPrint('[ChatRepo] Firestore snapshot stream notice: $e');
          },
        );
      }
    }

    // Push initial cached messages
    Future.microtask(() => _notify(conversationId));
    return _controllers[conversationId]!.stream;
  }

  @override
  Future<void> purgeExpiredMessages(String conversationId) async {
    final list = _localMessages[conversationId];
    if (list != null) {
      list.removeWhere((m) => m.isExpired);
      _notify(conversationId);
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final now = DateTime.now().toIso8601String();
        final expiredDocs = await firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .where('expiresAt', isLessThan: now)
            .get();

        final batch = firestore.batch();
        for (final doc in expiredDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        debugPrint('[ChatRepo] Purge expired error: $e');
      }
    }
  }

  @override
  Future<void> instantPurge(String conversationId) async {
    _localMessages[conversationId]?.clear();
    _notify(conversationId);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final docs = await firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .get();

        final batch = firestore.batch();
        for (final doc in docs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('[ChatRepo] Cloud messages instantly purged for $conversationId');
      } catch (e) {
        debugPrint('[ChatRepo] Cloud instant purge error: $e');
      }
    }
  }

  @override
  Future<void> setAutoPurgeTtl(String conversationId, int ttlSeconds) async {
    if (_localConversations.containsKey(conversationId)) {
      _localConversations[conversationId] = _localConversations[conversationId]!
          .copyWith(autoPurgeTtlSeconds: ttlSeconds);
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('conversations').doc(conversationId).update({
          'autoPurgeTtlSeconds': ttlSeconds,
        });
      } catch (_) {}
    }
  }

  void _notify(String conversationId) {
    final list = _localMessages[conversationId] ?? [];
    if (_controllers.containsKey(conversationId) &&
        !_controllers[conversationId]!.isClosed) {
      _controllers[conversationId]!.add(List.unmodifiable(list));
    }
  }
}
