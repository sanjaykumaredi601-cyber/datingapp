import '../utils/geohash_helper.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:aura_app/core/models/micro_gift_model.dart';
import 'package:aura_app/features/auth/data/models/user_document_model.dart';
import 'package:aura_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aura_app/features/radar/data/models/radar_profile_document.dart';
import 'package:aura_app/features/radar/data/repositories/radar_profile_repository_impl.dart';
import 'package:aura_app/features/chat/data/models/conversation_document.dart';
import 'package:aura_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aura_app/features/settings/data/repositories/support_ticket_repository_impl.dart';
import 'package:aura_app/features/chat/domain/entities/call_consent_request.dart';
export 'package:aura_app/core/models/micro_gift_model.dart';
export 'package:aura_app/features/chat/domain/entities/call_consent_request.dart';

/// Data Model representing a user profile document in Firestore
class FirestoreUserProfile {
  final String userId;
  final String displayName;
  final DateTime birthDate;
  final String gender;
  final String? customGender;
  final String pronouns;
  final List<String> orientations;
  final List<String> discoveryScope;
  final bool displayIdentityBadges;
  final String interestedIn;
  final List<String> photos;
  final List<String> passions;
  final List<String> lifestyleTags;
  final List<String> favoriteTreats; // Favorite Little Treats (Coffee, Dark Chocolate, Boba, Pastries)
  final String intention;
  final String bio;
  final String occupation;
  final String city;
  final String? voicePromptUrl;
  final String? voicePromptTitle;
  final int? voicePromptDuration;
  final bool isVerified;
  final DateTime updatedAt;

  FirestoreUserProfile({
    required this.userId,
    required this.displayName,
    required this.birthDate,
    required this.gender,
    this.customGender,
    this.pronouns = 'She/Her',
    this.orientations = const ['Straight'],
    this.discoveryScope = const ['Everyone'],
    this.displayIdentityBadges = true,
    required this.interestedIn,
    required this.photos,
    required this.passions,
    this.lifestyleTags = const [],
    this.favoriteTreats = const ['Coffee', 'Dark Chocolate'],
    required this.intention,
    this.bio = '',
    this.occupation = '',
    this.city = '',
    this.voicePromptUrl,
    this.voicePromptTitle,
    this.voicePromptDuration,
    this.isVerified = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'birthDate': birthDate.toIso8601String(),
        'gender': gender,
        'customGender': customGender,
        'pronouns': pronouns,
        'orientations': orientations,
        'discoveryScope': discoveryScope,
        'displayIdentityBadges': displayIdentityBadges,
        'interestedIn': interestedIn,
        'photos': photos,
        'passions': passions,
        'lifestyleTags': lifestyleTags,
        'favoriteTreats': favoriteTreats,
        'intention': intention,
        'bio': bio,
        'occupation': occupation,
        'city': city,
        'voicePromptUrl': voicePromptUrl,
        'voicePromptTitle': voicePromptTitle,
        'voicePromptDuration': voicePromptDuration,
        'isVerified': isVerified,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FirestoreUserProfile.fromMap(Map<String, dynamic> map) {
    return FirestoreUserProfile(
      userId: map['userId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Anonymous',
      birthDate: map['birthDate'] != null
          ? DateTime.tryParse(map['birthDate'] as String) ?? DateTime(2000)
          : DateTime(2000),
      gender: map['gender'] as String? ?? 'Woman',
      customGender: map['customGender'] as String?,
      pronouns: map['pronouns'] as String? ?? 'She/Her',
      orientations: List<String>.from(map['orientations'] as List? ?? ['Straight']),
      discoveryScope: List<String>.from(map['discoveryScope'] as List? ?? ['Everyone']),
      displayIdentityBadges: map['displayIdentityBadges'] as bool? ?? true,
      interestedIn: map['interestedIn'] as String? ?? 'Men',
      photos: List<String>.from(map['photos'] as List? ?? []),
      passions: List<String>.from(map['passions'] as List? ?? (map['hobbies'] as List? ?? [])),
      lifestyleTags: List<String>.from(map['lifestyleTags'] as List? ?? []),
      favoriteTreats: List<String>.from(map['favoriteTreats'] as List? ?? ['Coffee', 'Dark Chocolate']),
      intention: map['intention'] as String? ?? (map['relationshipGoal'] as String? ?? 'Long-term partner'),
      bio: map['bio'] as String? ?? '',
      occupation: map['occupation'] as String? ?? '',
      city: map['city'] as String? ?? (map['locationName'] as String? ?? ''),
      voicePromptUrl: map['voicePromptUrl'] as String?,
      voicePromptTitle: map['voicePromptTitle'] as String?,
      voicePromptDuration: map['voicePromptDuration'] as int?,
      isVerified: map['isVerified'] as bool? ?? false,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }
}

/// Firestore Service layer for Aura
/// Provides robust cloud persistence with an in-memory/cache fallback
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Concrete Repository Layers
  final AuthRepositoryImpl _authRepo = AuthRepositoryImpl();
  final RadarProfileRepositoryImpl _radarRepo = RadarProfileRepositoryImpl();
  final ChatRepositoryImpl _chatRepo = ChatRepositoryImpl();
  final SupportTicketRepositoryImpl _ticketRepo = SupportTicketRepositoryImpl();

  AuthRepositoryImpl get authRepository => _authRepo;
  RadarProfileRepositoryImpl get radarProfileRepository => _radarRepo;
  ChatRepositoryImpl get chatRepository => _chatRepo;
  SupportTicketRepositoryImpl get supportTicketRepository => _ticketRepo;

  // In-memory collections representing Firestore documents
  final Map<String, Map<String, dynamic>> _users = {};
  final Map<String, FirestoreUserProfile> _profiles = {};
  final Map<String, Map<String, dynamic>> _conversations = {};
  final Map<String, List<Map<String, dynamic>>> _messages = {};

  final _messageStreamControllers =
      <String, StreamController<List<Map<String, dynamic>>>>{};

  // ─────────────────────────────────────────────────────────
  // USERS
  // ─────────────────────────────────────────────────────────
  Future<void> saveUser({
    required String userId,
    required String phone,
    bool isPhoneVerified = true,
  }) async {
    _users[userId] = {
      'userId': userId,
      'phone': phone,
      'isPhoneVerified': isPhoneVerified,
      'createdAt': DateTime.now().toIso8601String(),
      'lastActiveAt': DateTime.now().toIso8601String(),
    };
    try {
      await _authRepo.createOrUpdateUserDocument(UserDocumentModel(
        userId: userId,
        phone: phone,
        isPhoneVerified: isPhoneVerified,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));
    } catch (_) {}
    debugPrint('[FirestoreService] Saved user: $userId');
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    return _users[userId];
  }

  // ─────────────────────────────────────────────────────────
  // PROFILES
  // ─────────────────────────────────────────────────────────
  Future<void> saveProfile(FirestoreUserProfile profile) async {
    // Validate age 18+
    final age = DateTime.now().year - profile.birthDate.year;
    if (age < 18) {
      throw ArgumentError('Age must be at least 18 years old');
    }
    // Validate min 2 photos
    if (profile.photos.length < 2) {
      throw ArgumentError('Minimum 2 photos required');
    }

    _profiles[profile.userId] = profile;
    try {
      await _radarRepo.saveProfile(RadarProfileDocument(
        userId: profile.userId,
        displayName: profile.displayName,
        age: age,
        birthDate: profile.birthDate,
        gender: profile.gender,
        interestedIn: profile.interestedIn,
        photos: profile.photos,
        bio: profile.bio.isNotEmpty ? profile.bio : profile.intention,
        passions: profile.passions,
        lifestyleTags: profile.lifestyleTags,
        latitude: 19.0596,
        longitude: 72.8295,
        isVerified: profile.isVerified,
      ));
    } catch (_) {}

    try {
      await FirebaseFirestore.instance.collection('users').doc(profile.userId).set({
        'userId': profile.userId,
        'displayName': profile.displayName,
        'birthDate': profile.birthDate.toIso8601String(),
        'age': age,
        'gender': profile.gender,
        'customGender': profile.customGender,
        'pronouns': profile.pronouns,
        'interestedIn': profile.interestedIn,
        'photos': profile.photos,
        'avatarUrl': profile.photos.isNotEmpty ? profile.photos[0] : '',
        'hobbies': profile.passions,
        'passions': profile.passions,
        'favoriteTreats': profile.favoriteTreats,
        'relationshipGoal': profile.intention,
        'intention': profile.intention,
        'bio': profile.bio,
        'occupation': profile.occupation,
        'city': profile.city,
        'voicePromptUrl': profile.voicePromptUrl,
        'voicePromptTitle': profile.voicePromptTitle,
        'voicePromptDuration': profile.voicePromptDuration,
        'isVerified': profile.isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Firestore /users doc update fallback: $e');
    }

    debugPrint('[FirestoreService] Saved profile for user: ${profile.userId}');
  }

  Future<FirestoreUserProfile?> getProfile(String userId) async {
    if (_profiles.containsKey(userId)) {
      return _profiles[userId];
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final profile = FirestoreUserProfile.fromMap(doc.data()!);
        _profiles[userId] = profile;
        return profile;
      }
    } catch (e) {
      debugPrint('[FirestoreService] getProfile remote fetch fallback: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // CONVERSATIONS & HANDSHAKE
  // ─────────────────────────────────────────────────────────
  Future<void> createConversation({
    required String conversationId,
    required List<String> participantIds,
    String handshakeStatus = 'pending', // 'pending', 'accepted', 'declined'
  }) async {
    _conversations[conversationId] = {
      'conversationId': conversationId,
      'participantIds': participantIds,
      'handshakeStatus': handshakeStatus,
      'createdAt': DateTime.now().toIso8601String(),
      'autoPurgeTtl': 'off',
    };
    _messages[conversationId] ??= [];
    try {
      await _chatRepo.createConversation(ConversationDocument(
        conversationId: conversationId,
        participantIds: participantIds,
        handshakeStatus: handshakeStatus,
      ));
    } catch (_) {}
    debugPrint('[FirestoreService] Created conversation: $conversationId');
  }

  Future<void> updateHandshakeStatus(String conversationId, String status) async {
    if (_conversations.containsKey(conversationId)) {
      _conversations[conversationId]!['handshakeStatus'] = status;
      debugPrint('[FirestoreService] Handshake updated: $conversationId -> $status');
    }
  }

  // ---------------------------------------------------------
  // VIBE SPARK & CHEMISTRY SCORE STREAM
  // (/conversations/{id}/chemistryScore)
  // ---------------------------------------------------------
  final Map<String, StreamController<int>> _chemistryScoreControllers = {};

  Stream<int> chemistryScoreStream(String conversationId) {
    if (!_chemistryScoreControllers.containsKey(conversationId) ||
        _chemistryScoreControllers[conversationId]!.isClosed) {
      _chemistryScoreControllers[conversationId] =
          StreamController<int>.broadcast();
    }
    final currentScore = (_conversations[conversationId]?['chemistryScore'] as num?)?.toInt() ?? 0;
    Future.microtask(() {
      if (_chemistryScoreControllers.containsKey(conversationId) &&
          !_chemistryScoreControllers[conversationId]!.isClosed) {
        _chemistryScoreControllers[conversationId]!.add(currentScore);
      }
    });
    return _chemistryScoreControllers[conversationId]!.stream;
  }

  int getChemistryScore(String conversationId) {
    return (_conversations[conversationId]?['chemistryScore'] as num?)?.toInt() ?? 0;
  }

  Future<void> updateChemistryScore(String conversationId, int score) async {
    final clampedScore = score.clamp(0, 100);
    _conversations[conversationId] ??= {
      'conversationId': conversationId,
      'participantIds': ['user', 'partner'],
      'handshakeStatus': 'accepted',
      'createdAt': DateTime.now().toIso8601String(),
      'autoPurgeTtl': 'off',
    };
    _conversations[conversationId]!['chemistryScore'] = clampedScore;

    if (_chemistryScoreControllers.containsKey(conversationId) &&
        !_chemistryScoreControllers[conversationId]!.isClosed) {
      _chemistryScoreControllers[conversationId]!.add(clampedScore);
    }
    debugPrint(
      '[FirestoreService] Chemistry score updated: /conversations/$conversationId/chemistryScore -> $clampedScore%',
    );
  }

  // ─────────────────────────────────────────────────────────
  // TWO-WAY CALL CONSENT & PERMISSION HANDSHAKE
  // (/conversations/{id}/call_requests)
  // ─────────────────────────────────────────────────────────
  final Map<String, CallConsentRequest> _callRequests = {};
  final Map<String, StreamController<CallConsentRequest?>>
      _callRequestStreamControllers = {};

  Stream<CallConsentRequest?> callRequestStream(String conversationId) {
    if (!_callRequestStreamControllers.containsKey(conversationId) ||
        _callRequestStreamControllers[conversationId]!.isClosed) {
      _callRequestStreamControllers[conversationId] =
          StreamController<CallConsentRequest?>.broadcast();
    }
    final current = _callRequests[conversationId];
    Future.microtask(() {
      if (_callRequestStreamControllers[conversationId]?.isClosed == false) {
        _callRequestStreamControllers[conversationId]?.add(current);
      }
    });
    return _callRequestStreamControllers[conversationId]!.stream;
  }

  Future<void> emitCallRequest(
    String conversationId,
    CallConsentRequest request,
  ) async {
    _callRequests[conversationId] = request;
    _notifyCallRequestListener(conversationId);
    debugPrint(
      '[FirestoreService] Emitted Call Request in /conversations/$conversationId/call_requests: ${request.callType.value} (status: ${request.status.value})',
    );
  }

  Future<void> updateCallRequestStatus(
    String conversationId,
    CallConsentStatus status,
  ) async {
    if (_callRequests.containsKey(conversationId)) {
      _callRequests[conversationId] =
          _callRequests[conversationId]!.copyWith(status: status);
      _notifyCallRequestListener(conversationId);
      debugPrint(
        '[FirestoreService] Updated Call Request status in /conversations/$conversationId/call_requests: ${status.value}',
      );
    }
  }

  CallConsentRequest? getCallRequest(String conversationId) {
    return _callRequests[conversationId];
  }

  void clearCallRequest(String conversationId) {
    _callRequests.remove(conversationId);
    _notifyCallRequestListener(conversationId);
  }

  void _notifyCallRequestListener(String conversationId) {
    final current = _callRequests[conversationId];
    if (_callRequestStreamControllers.containsKey(conversationId) &&
        !_callRequestStreamControllers[conversationId]!.isClosed) {
      _callRequestStreamControllers[conversationId]!.add(current);
    }
  }

  // ─────────────────────────────────────────────────────────
  // MESSAGES & PURGE
  // ─────────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String content,
    String type = 'text',
  }) async {
    final msg = {
      'messageId': messageId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'sentAt': DateTime.now().toIso8601String(),
      'isUnsent': false,
    };

    _messages[conversationId] ??= [];
    _messages[conversationId]!.insert(0, msg);

    _notifyMessageListeners(conversationId);
    try {
      await _chatRepo.sendEncryptedMessage(
        conversationId: conversationId,
        messageId: messageId,
        senderId: senderId,
        receiverId: 'partner',
        plainText: content,
        type: type,
      );
    } catch (_) {}
    debugPrint('[FirestoreService] Message saved in $conversationId: $messageId');
  }

  Stream<List<Map<String, dynamic>>> messageStream(String conversationId) {
    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] =
          StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    // Emit initial list
    Future.microtask(() => _notifyMessageListeners(conversationId));
    return _messageStreamControllers[conversationId]!.stream;
  }

  Future<void> instantPurge(String conversationId) async {
    _messages[conversationId]?.clear();
    _notifyMessageListeners(conversationId);
    try {
      await _chatRepo.instantPurge(conversationId);
    } catch (_) {}
    debugPrint('[FirestoreService] Instant Purged conversation: $conversationId');
  }

  void _notifyMessageListeners(String conversationId) {
    final list = _messages[conversationId] ?? [];
    _messageStreamControllers[conversationId]?.add(List.unmodifiable(list));
  }

  // ─────────────────────────────────────────────────────────
  // 3D BIOMETRIC LIVENESS AUDIT PERSISTENCE
  // ─────────────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _biometricAuditStore = {};

  Future<void> saveBiometricVerification({
    required String userId,
    required String auditHash,
    required double matchScore,
  }) async {
    _biometricAuditStore[userId] = {
      'userId': userId,
      'is_verified': true,
      'biometric_audit_hash': auditHash,
      'audit_hash': auditHash,
      'biometric_match_score': matchScore,
      'match_score': matchScore,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Update user profile if exists
    if (_profiles.containsKey(userId)) {
      final p = _profiles[userId]!;
      _profiles[userId] = FirestoreUserProfile(
        userId: p.userId,
        displayName: p.displayName,
        birthDate: p.birthDate,
        gender: p.gender,
        customGender: p.customGender,
        pronouns: p.pronouns,
        orientations: p.orientations,
        discoveryScope: p.discoveryScope,
        displayIdentityBadges: p.displayIdentityBadges,
        interestedIn: p.interestedIn,
        photos: p.photos,
        passions: p.passions,
        lifestyleTags: p.lifestyleTags,
        intention: p.intention,
        isVerified: true,
        updatedAt: DateTime.now(),
      );
    }
    debugPrint('[FirestoreService] Biometric verification saved for $userId (Hash: ${auditHash.substring(0, 12)}...)');
  }

  Map<String, dynamic>? getBiometricAudit(String userId) {
    return _biometricAuditStore[userId];
  }

  // ─────────────────────────────────────────────────────────
  // ENTERPRISE SUPPORT TICKETS (/support_tickets)
  // ─────────────────────────────────────────────────────────
  final List<SupportTicket> _supportTickets = [];

  Future<void> submitSupportTicket(SupportTicket ticket) async {
    _supportTickets.insert(0, ticket);
    try {
      await _ticketRepo.submitTicket(ticket);
    } catch (_) {}
    debugPrint('[FirestoreService] Saved Support Ticket: ${ticket.ticketId} (${ticket.category})');
  }

  List<SupportTicket> getUserSupportTickets(String userId) {
    return _supportTickets.where((t) => t.userId == userId).toList();
  }

  Future<List<SupportTicket>> filterTickets({String? status, String? priority}) async {
    return _supportTickets.where((t) {
      final matchStatus = status == null || t.status.toUpperCase() == status.toUpperCase();
      final matchPriority = priority == null || t.priority.toUpperCase() == priority.toUpperCase();
      return matchStatus && matchPriority;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────
  // IN-APP REAL-WORLD MICRO-GIFTING VOUCHERS (/micro_gift_vouchers)
  // ─────────────────────────────────────────────────────────
  final Map<String, MicroGiftVoucher> _vouchers = {};

  Future<void> saveGiftVoucher(MicroGiftVoucher voucher) async {
    _vouchers[voucher.voucherId] = voucher;
    debugPrint('[FirestoreService] Saved Gift Voucher: ${voucher.voucherId} (${voucher.giftTitle} - Code: ${voucher.singleUseCode})');
  }

  Future<MicroGiftVoucher?> getGiftVoucher(String voucherId) async {
    return _vouchers[voucherId];
  }

  Future<bool> claimGiftVoucher(String voucherId) async {
    final v = _vouchers[voucherId];
    if (v == null || v.isExpired) return false;
    _vouchers[voucherId] = v.copyWith(
      isClaimed: true,
      claimedAt: DateTime.now(),
    );
    debugPrint('[FirestoreService] Claimed Gift Voucher: $voucherId (Item: ${v.designatedItem})');
    return true;
  }

  Future<bool> redeemPartnerVoucher(String voucherId) async {
    final v = _vouchers[voucherId];
    if (v == null || v.isExpired) return false;
    _vouchers[voucherId] = v.copyWith(
      isRedeemedAtPartner: true,
      redeemedAt: DateTime.now(),
    );
    debugPrint('[FirestoreService] Redeemed Partner Voucher: $voucherId at ${v.partnerName}');
    return true;
  }

  List<MicroGiftVoucher> getUserVouchers(String userId) {
    return _vouchers.values
        .where((v) => v.recipientId == userId || v.senderId == userId)
        .toList();
  }

  Future<void> updateFavoriteTreats(String userId, List<String> treats) async {
    if (_profiles.containsKey(userId)) {
      final p = _profiles[userId]!;
      _profiles[userId] = FirestoreUserProfile(
        userId: p.userId,
        displayName: p.displayName,
        birthDate: p.birthDate,
        gender: p.gender,
        customGender: p.customGender,
        pronouns: p.pronouns,
        orientations: p.orientations,
        discoveryScope: p.discoveryScope,
        displayIdentityBadges: p.displayIdentityBadges,
        interestedIn: p.interestedIn,
        photos: p.photos,
        passions: p.passions,
        lifestyleTags: p.lifestyleTags,
        favoriteTreats: treats,
        intention: p.intention,
        isVerified: p.isVerified,
        updatedAt: DateTime.now(),
      );
      debugPrint('[FirestoreService] Updated favorite treats for $userId: $treats');
    }
  }
  // ---------------------------------------------------------
  // ECHOES & PATH CROSSINGS PIPELINE (/users/{uid}/echoes)
  // ---------------------------------------------------------
  final Map<String, List<Map<String, dynamic>>> _userEchoes = {};

  Future<void> recordEchoEvent({
    required String uid,
    required String peerUid,
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
    required String zoneName,
  }) async {
    final distKm = GeoHashHelper.haversineDistanceKm(lat1, lon1, lat2, lon2);
    if (distKm <= 0.50) {
      final obfuscatedGeohash = GeoHashHelper.obfuscateTo500mGeohash(lat1, lon1);
      final echo = {
        'echoId': 'echo_${DateTime.now().millisecondsSinceEpoch}',
        'peerUid': peerUid,
        'zoneName': zoneName,
        'obfuscatedGeohash': obfuscatedGeohash,
        'crossedAt': DateTime.now().toIso8601String(),
        'isEncrypted': true,
        'resonanceSent': false,
      };
      _userEchoes[uid] ??= [];
      _userEchoes[uid]!.insert(0, echo);
      debugPrint('[FirestoreService] 500m Echo event logged in /users/$uid/echoes for cell $obfuscatedGeohash');
    }
  }

  Future<void> sendWhisperResonance({
    required String uid,
    required String echoId,
    required String peerUid,
  }) async {
    if (_userEchoes.containsKey(uid)) {
      for (final e in _userEchoes[uid]!) {
        if (e['echoId'] == echoId) {
          e['resonanceSent'] = true;
          break;
        }
      }
    }
    debugPrint('[FirestoreService] Whisper Resonance sent from $uid to $peerUid without disclosing exact coordinates');
  }

  List<Map<String, dynamic>> getEchoes(String uid) {
    return _userEchoes[uid] ?? [];
  }
}

class SupportTicket {
  final String ticketId;
  final String userId;
  final String category; // 'Payment / Subscription Issue', 'Safety & Harassment', 'Profile Verification', 'Technical Bug'
  final String subject;
  final String description;
  final String priority; // 'URGENT', 'HIGH', 'MEDIUM', 'LOW'
  final String status;   // 'OPEN', 'IN_REVIEW', 'RESOLVED'
  final String appVersion;
  final String osVersion;
  final String deviceModel;
  final String? transactionRefId;
  final DateTime createdAt;
  final int slaHours;

  SupportTicket({
    required this.ticketId,
    required this.userId,
    required this.category,
    required this.subject,
    required this.description,
    this.priority = 'MEDIUM',
    this.status = 'OPEN',
    this.appVersion = '1.0.0+1',
    this.osVersion = 'Android 17 (API 37)',
    this.deviceModel = 'Android Device',
    this.transactionRefId,
    DateTime? createdAt,
    this.slaHours = 24,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'ticketId': ticketId,
        'userId': userId,
        'category': category,
        'subject': subject,
        'description': description,
        'priority': priority,
        'status': status,
        'appVersion': appVersion,
        'osVersion': osVersion,
        'deviceModel': deviceModel,
        'transactionRefId': transactionRefId,
        'createdAt': createdAt.toIso8601String(),
        'slaHours': slaHours,
      };

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      ticketId: map['ticketId'] as String? ?? 'TKT-${DateTime.now().millisecondsSinceEpoch}',
      userId: map['userId'] as String? ?? 'usr_guest',
      category: map['category'] as String? ?? 'General Support',
      subject: map['subject'] as String? ?? 'Support Request',
      description: map['description'] as String? ?? '',
      priority: map['priority'] as String? ?? 'MEDIUM',
      status: map['status'] as String? ?? 'OPEN',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      osVersion: map['osVersion'] as String? ?? 'Android',
      deviceModel: map['deviceModel'] as String? ?? 'Smartphone',
      transactionRefId: map['transactionRefId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      slaHours: (map['slaHours'] as num?)?.toInt() ?? 24,
    );
  }
}
