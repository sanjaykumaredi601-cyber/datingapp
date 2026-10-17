import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/core/security/security_service.dart';
import 'package:aura_app/core/services/chat_translation_service.dart';
import 'package:aura_app/features/chat/presentation/widgets/caller_call_waiting_modal.dart';
import 'package:aura_app/features/chat/presentation/widgets/receiver_call_consent_card.dart';
import 'package:aura_app/features/chat/presentation/widgets/secret_vault_widgets.dart';
import 'package:aura_app/features/chat/presentation/utils/call_permission_helper.dart';
import 'package:aura_app/core/services/secret_vault_service.dart';
import 'call_screen.dart';
import 'package:aura_app/features/chat/domain/services/vibe_spark_engine.dart';
import 'package:aura_app/features/chat/presentation/widgets/vibe_temperature_bar.dart';
import 'package:aura_app/features/chat/presentation/widgets/vibe_spark_ignition_modal.dart';

/// Interoperability typedef for ChatRoomScreen
typedef ChatRoomScreen = ChatScreen;

const Color sunsetCoral = Color(0xFFFF4D67);
const Color electricIris = Color(0xFF7928CA);
const Color roseGold = Color(0xFFF472B6);

// ─────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────

enum MessageStatus { sending, sent, delivered, read }
enum MessageType { text, image, gif, sticker, callPill, voiceNote, gift }
enum HandshakeStatus { accepted, pendingReceived, pendingSent }

class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  String content;
  final MessageType type;
  final String? mediaUrl;
  final DateTime sentAt;
  MessageStatus status;
  DateTime? readAt;
  bool isMine;
  bool isUnsent;

  // Real-Time In-Chat Translation Metadata
  String? translatedContent;
  String? detectedLanguage;
  String? targetLanguage;
  bool showTranslated;
  bool isTranslating;

  // Audio & Voice Note Metadata
  int? audioDurationSeconds;
  List<double>? audioWaveform;
  String? voiceTranscript;
  String? translatedTranscript;
  bool isTranscriptExpanded;
  bool showTranslatedTranscript;
  bool isTranscribing;
  String? transcriptLanguage;

  // Real-World Micro-Gifting Metadata
  MicroGiftVoucher? giftVoucher;

  ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    required this.sentAt,
    this.status = MessageStatus.sending,
    this.readAt,
    required this.isMine,
    this.isUnsent = false,
    this.translatedContent,
    this.detectedLanguage,
    this.targetLanguage,
    this.showTranslated = false,
    this.isTranslating = false,
    this.audioDurationSeconds,
    this.audioWaveform,
    this.voiceTranscript,
    this.translatedTranscript,
    this.isTranscriptExpanded = false,
    this.showTranslatedTranscript = false,
    this.isTranscribing = false,
    this.transcriptLanguage,
    this.giftVoucher,
  });
}

// ─────────────────────────────────────────────────────────
// SOCKET SERVICE
// ─────────────────────────────────────────────────────────

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final _connectionController = StreamController<bool>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController = StreamController<String>.broadcast();
  final _deleteMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatPurgedController = StreamController<Map<String, dynamic>>.broadcast();
  final _autoPurgeController = StreamController<Map<String, dynamic>>.broadcast();
  final _handshakeController = StreamController<Map<String, dynamic>>.broadcast();
  final _callRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _chemistryScoreController = StreamController<int>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<String> get readReceiptStream => _readReceiptController.stream;
  Stream<Map<String, dynamic>> get deleteMessageStream => _deleteMessageController.stream;
  Stream<Map<String, dynamic>> get chatPurgedStream => _chatPurgedController.stream;
  Stream<Map<String, dynamic>> get autoPurgeStream => _autoPurgeController.stream;
  Stream<Map<String, dynamic>> get handshakeStream => _handshakeController.stream;
  Stream<Map<String, dynamic>> get callRequestStream => _callRequestController.stream;
  Stream<int> get chemistryScoreStream => _chemistryScoreController.stream;

  void sendChemistryScore(String matchId, int score) {
    _socket?.emit('chemistry_score_updated', {
      'matchId': matchId,
      'score': score,
    });
  }

  bool get isConnected => _socket?.connected ?? false;

  void connect(String authToken, String currentUserId) {
    if (_socket?.connected == true) return;

    final backendUrl = kIsWeb
        ? 'http://localhost:3000'
        : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

    _socket = io.io(
      backendUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': authToken})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _connectionController.add(true);
        debugPrint('[Socket] Connected');
      })
      ..onDisconnect((_) {
        _connectionController.add(false);
        debugPrint('[Socket] Disconnected — scheduling reconnect');
        _scheduleReconnect(authToken, currentUserId);
      })
      ..onConnectError((err) {
        debugPrint('[Socket] Connection error: $err');
        _scheduleReconnect(authToken, currentUserId);
      })
      ..on('new_message', (data) {
        final msg = _parseIncomingMessage(data, currentUserId);
        _messageController.add(msg);
      })
      ..on('message_delivered', (data) {
        // handled via readReceiptStream or directly in chat state
      })
      ..on('message_read_ack', (data) {
        _readReceiptController.add(data['messageId'] as String);
      })
      ..on('message_deleted', (data) {
        _deleteMessageController.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('chat_purged', (data) {
        _chatPurgedController.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('auto_purge_updated', (data) {
        _autoPurgeController.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('handshake_updated', (data) {
        _handshakeController.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('call_request', (data) {
        _callRequestController.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('call_response', (data) {
        _callRequestController.add(Map<String, dynamic>.from(data as Map));
      })
      ..on('chemistry_score_updated', (data) {
        if (data != null && data['score'] != null) {
          _chemistryScoreController.add((data['score'] as num).toInt());
        }
      })
      ..on('typing_indicator', (data) {
        _typingController.add(Map<String, dynamic>.from(data as Map));
      });
  }

  void joinRoom(String matchId) =>
      _socket?.emit('join_room', {'matchId': matchId});

  void leaveRoom(String matchId) =>
      _socket?.emit('leave_room', {'matchId': matchId});

  void sendMessage({
    required String matchId,
    required String content,
    required String tempId,
    String type = 'text',
    String? mediaUrl,
  }) {
    _socket?.emit('send_message', {
      'matchId': matchId,
      'content': content,
      'contentType': type,
      'tempId': tempId,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    });
  }

  void deleteMessage({
    required String matchId,
    required String messageId,
    required String deleteType,
  }) {
    _socket?.emit('delete_message', {
      'matchId': matchId,
      'messageId': messageId,
      'deleteType': deleteType,
    });
  }

  void instantPurge(String matchId) =>
      _socket?.emit('instant_purge', {'matchId': matchId});

  void setAutoPurge(String matchId, String ttl) =>
      _socket?.emit('set_auto_purge', {'matchId': matchId, 'ttl': ttl});

  void sendHandshakeAction(String matchId, String action) =>
      _socket?.emit('handshake_action', {'matchId': matchId, 'action': action});

  void sendTypingStart(String matchId) =>
      _socket?.emit('typing_start', {'matchId': matchId});

  void sendTypingStop(String matchId) =>
      _socket?.emit('typing_stop', {'matchId': matchId});

  void markAsRead(String matchId, String messageId) =>
      _socket?.emit('message_read', {'matchId': matchId, 'messageId': messageId});

  void emitCallRequest({
    required String matchId,
    required Map<String, dynamic> data,
  }) {
    _socket?.emit('call_request', {
      'matchId': matchId,
      ...data,
    });
  }

  void emitCallResponse({
    required String matchId,
    required String status,
    required String callType,
  }) {
    _socket?.emit('call_response', {
      'matchId': matchId,
      'status': status,
      'callType': callType,
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _scheduleReconnect(String token, String userId) {
    if (_reconnectAttempts >= 5) return;
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => connect(token, userId));
  }

  ChatMessage _parseIncomingMessage(dynamic data, String currentUserId) {
    final map = Map<String, dynamic>.from(data as Map);
    final contentType = map['contentType'] as String? ?? 'text';
    MessageType type = MessageType.text;
    if (contentType == 'call_pill') {
      type = MessageType.callPill;
    } else if (contentType == 'voice_note' || contentType == 'audio') {
      type = MessageType.voiceNote;
    }

    return ChatMessage(
      id: map['messageId'] as String,
      matchId: map['matchId'] as String,
      senderId: map['senderId'] as String,
      content: map['content'] as String? ?? '',
      type: type,
      mediaUrl: map['mediaUrl'] as String?,
      audioDurationSeconds: map['durationSeconds'] as int? ?? (type == MessageType.voiceNote ? 5 : null),
      sentAt: DateTime.parse(map['sentAt'] as String),
      status: MessageStatus.delivered,
      isMine: map['senderId'] == currentUserId,
    );
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.dispose();
    _connectionController.close();
    _messageController.close();
    _typingController.close();
    _readReceiptController.close();
    _deleteMessageController.close();
    _chatPurgedController.close();
    _autoPurgeController.close();
    _handshakeController.close();
  }
}

// ─────────────────────────────────────────────────────────
// CHAT SCREEN
// ─────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String? matchAvatarUrl;
  final String currentUserId;
  final HandshakeStatus handshakeStatus;
  final List<String> recipientTreats;
  final VoidCallback? onHandshakeAccepted;
  final VoidCallback? onHandshakeDeclined;
  final int initialChemistryScore;
  final CallConsentRequest? initialIncomingCallRequest;
  final bool enableLiveSockets;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.matchName,
    this.matchAvatarUrl,
    required this.currentUserId,
    this.handshakeStatus = HandshakeStatus.accepted,
    this.recipientTreats = const ['Dark Chocolate', 'Coffee'],
    this.onHandshakeAccepted,
    this.onHandshakeDeclined,
    this.initialChemistryScore = 0,
    this.initialIncomingCallRequest,
    this.enableLiveSockets = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SocketService _socket = SocketService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<StreamSubscription> _subscriptions = [];

  late HandshakeStatus _handshakeStatus;
  String _autoPurgeTtl = 'Off'; // 'Off', '24 Hours', '7 Days'
  bool _isTyping = false;
  bool _peerIsTyping = false;
  bool _isOnline = false;
  bool _safetyBannerVisible = true;
  Timer? _typingTimer;

  // Two-Way Call Consent & Handshake State
  CallConsentRequest? _activeIncomingCallRequest;
  final Set<String> _mutedCallMatches = {};

  // Synchronized Vibe Spark & Chemistry Engine State
  late final VibeSparkEngine _vibeSparkEngine;
  int _currentChemistryScore = 0;

  @override
  void initState() {
    super.initState();
    SecurityService.setScreenSecurity(true);
    _handshakeStatus = widget.handshakeStatus;
    _currentChemistryScore = widget.initialChemistryScore;
    _activeIncomingCallRequest = widget.initialIncomingCallRequest;
    _vibeSparkEngine = VibeSparkEngine();
    _vibeSparkEngine.bindConversation(widget.matchId);
    if (widget.enableLiveSockets) {
      _socket.connect('demo_token', widget.currentUserId);
      _socket.joinRoom(widget.matchId);
    }
    _listenToLiveMessages();

    _subscriptions.addAll([
      _socket.messageStream.listen(_onMessageReceived),
      _socket.typingStream.listen(_onTypingEvent),
      _socket.connectionStream.listen((connected) {
        if (mounted) setState(() => _isOnline = connected);
      }),
      _socket.readReceiptStream.listen(_onReadReceipt),
      _socket.deleteMessageStream.listen(_onMessageDeleted),
      _socket.chatPurgedStream.listen(_onChatPurged),
      _socket.autoPurgeStream.listen(_onAutoPurgeUpdated),
      _socket.handshakeStream.listen(_onHandshakeUpdated),
      FirestoreService()
          .callRequestStream(widget.matchId)
          .listen(_onCallRequestUpdated),
      _socket.callRequestStream.listen(_onSocketCallRequest),
      _socket.chemistryScoreStream.listen((score) {
        _vibeSparkEngine.onRemoteScoreReceived(score);
      }),
      _vibeSparkEngine.scoreStream.listen((score) {
        if (mounted) setState(() => _currentChemistryScore = score);
      }),
      _vibeSparkEngine.ignitionStream.listen((score) {
        if (mounted) {
          VibeSparkIgnitionModal.show(
            context,
            score: score,
            matchName: widget.matchName,
            onDatePlanSelected: (invite) => _sendMessage(invite),
          );
        }
      }),
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateChemistry();
    });
  }

  @override
  void dispose() {
    SecurityService.setScreenSecurity(false);
    _vibeSparkEngine.dispose();
    if (widget.enableLiveSockets) {
      if (_autoPurgeTtl == 'Upon Exit') {
        _socket.instantPurge(widget.matchId);
      }
      _socket.leaveRoom(widget.matchId);
      _socket.sendTypingStop(widget.matchId);
      _socket.disconnect();
    }
    if (_autoPurgeTtl == 'Upon Exit') {
      FirestoreService().instantPurge(widget.matchId);
    }
    _typingTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  void _listenToLiveMessages() {
    try {
      final sub = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.matchId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        if (snapshot.docs.isNotEmpty) {
          final loaded = snapshot.docs.map((doc) {
            final data = doc.data();
            final senderId = (data['senderId'] ?? '').toString();
            final content = (data['decryptedText'] ?? data['content'] ?? '').toString();
            DateTime sentAt = DateTime.now();
            if (data['sentAt'] is Timestamp) {
              sentAt = (data['sentAt'] as Timestamp).toDate();
            } else if (data['sentAt'] is String) {
              sentAt = DateTime.tryParse(data['sentAt'] as String) ?? DateTime.now();
            }
            return ChatMessage(
              id: doc.id,
              matchId: widget.matchId,
              senderId: senderId,
              content: content,
              sentAt: sentAt,
              status: MessageStatus.delivered,
              isMine: senderId == widget.currentUserId,
            );
          }).toList();

          setState(() {
            _messages.clear();
            _messages.addAll(loaded);
          });
          _evaluateChemistry();
        }
      }, onError: (e) {
        debugPrint('[ChatScreen] Live messages stream notice: $e');
      });
      _subscriptions.add(sub);
    } catch (e) {
      debugPrint('[ChatScreen] Live messages init notice: $e');
    }
  }

  void _evaluateChemistry() {
    _vibeSparkEngine.evaluateAndSync(
      messages: _messages,
      currentUserId: widget.currentUserId,
      conversationId: widget.matchId,
    ).then((score) {
      _socket.sendChemistryScore(widget.matchId, score);
    });
  }

  void _onMessageReceived(ChatMessage msg) {
    if (!mounted || msg.matchId != widget.matchId) return;
    setState(() => _messages.insert(0, msg));
    _socket.markAsRead(widget.matchId, msg.id);
    _scrollToBottom();
    _evaluateChemistry();
  }

  void _onTypingEvent(Map<String, dynamic> data) {
    if (!mounted || data['matchId'] != widget.matchId) return;
    setState(() => _peerIsTyping = data['isTyping'] as bool);
  }

  void _onReadReceipt(String messageId) {
    if (!mounted) return;
    setState(() {
      for (final msg in _messages) {
        if (msg.id == messageId) {
          msg.status = MessageStatus.read;
          break;
        }
      }
    });
  }

  void _onMessageDeleted(Map<String, dynamic> data) {
    if (!mounted || data['matchId'] != widget.matchId) return;
    final msgId = data['messageId'] as String;
    final deleteType = data['deleteType'] as String;

    setState(() {
      if (deleteType == 'for_everyone') {
        for (final m in _messages) {
          if (m.id == msgId) {
            m.content = 'This message was unsent';
            m.isUnsent = true;
            break;
          }
        }
      } else if (deleteType == 'for_me') {
        _messages.removeWhere((m) => m.id == msgId);
      }
    });
  }

  void _onChatPurged(Map<String, dynamic> data) {
    if (!mounted || data['matchId'] != widget.matchId) return;
    setState(() => _messages.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat was wiped for both participants in real-time.'),
        backgroundColor: AppColors.surfaceL2,
      ),
    );
  }

  void _onAutoPurgeUpdated(Map<String, dynamic> data) {
    if (!mounted || data['matchId'] != widget.matchId) return;
    final ttl = data['ttl'] as String;
    setState(() {
      _autoPurgeTtl = ttl == '24h'
          ? '24 Hours'
          : (ttl == 'upon_exit' ? 'Upon Exit' : (ttl == '7d' ? '7 Days' : 'Off'));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-Purge TTL updated to $_autoPurgeTtl'),
        backgroundColor: AppColors.surfaceL2,
      ),
    );
  }

  void _onHandshakeUpdated(Map<String, dynamic> data) {
    if (!mounted || data['matchId'] != widget.matchId) return;
    final action = data['action'] as String;
    if (action == 'accept') {
      setState(() => _handshakeStatus = HandshakeStatus.accepted);
    }
  }

  void _acceptHandshake() {
    _socket.sendHandshakeAction(widget.matchId, 'accept');
    setState(() => _handshakeStatus = HandshakeStatus.accepted);
    widget.onHandshakeAccepted?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request accepted. You can now chat freely!'),
        backgroundColor: AppColors.surfaceL2,
      ),
    );
  }

  void _declineAndPurgeHandshake() {
    _socket.sendHandshakeAction(widget.matchId, 'decline');
    _socket.instantPurge(widget.matchId);
    FirestoreService().instantPurge(widget.matchId);
    setState(() => _messages.clear());
    widget.onHandshakeDeclined?.call();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request declined and conversation purged.'),
        backgroundColor: AppColors.surfaceL2,
      ),
    );
  }

  /// Gatekeeping Safety Rule: Calling icons unlock only after handshake is accepted
  /// AND a minimum threshold of 3 mutual messages are exchanged.
  bool get _isCallingUnlocked {
    if (_handshakeStatus != HandshakeStatus.accepted) return false;
    final validMsgs = _messages
        .where((m) => !m.isUnsent && m.type != MessageType.callPill)
        .toList();
    if (validMsgs.length < 3) return false;
    final hasMine = validMsgs.any((m) => m.isMine);
    final hasPeer = validMsgs.any((m) => !m.isMine);
    return hasMine && hasPeer;
  }

  // ─────────────────────────────────────────────────────────
  // TWO-WAY CALL CONSENT & PERMISSION HANDSHAKE LOGIC
  // ─────────────────────────────────────────────────────────

  void _onCallRequestUpdated(CallConsentRequest? req) {
    if (!mounted) return;
    if (req == null) {
      if (_activeIncomingCallRequest != null) {
        setState(() => _activeIncomingCallRequest = null);
      }
      return;
    }

    // Process incoming call request targeting current user
    if (req.callerId != widget.currentUserId) {
      if (req.status == CallConsentStatus.pending && !req.isExpired) {
        if (_mutedCallMatches.contains(widget.matchId)) {
          // Auto-decline if user has muted calls for this peer
          FirestoreService().updateCallRequestStatus(
            widget.matchId,
            CallConsentStatus.declined,
          );
          _socket.emitCallResponse(
            matchId: widget.matchId,
            status: 'declined',
            callType: req.callType.value,
          );
          return;
        }
        setState(() => _activeIncomingCallRequest = req);
      } else {
        if (_activeIncomingCallRequest != null) {
          setState(() => _activeIncomingCallRequest = null);
        }
      }
    }
  }

  void _onSocketCallRequest(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['status'] != null) {
      final status = CallConsentStatus.fromString(data['status'] as String?);
      FirestoreService().updateCallRequestStatus(widget.matchId, status);
    } else if (data['callerId'] != null) {
      final req = CallConsentRequest.fromMap(data);
      FirestoreService().emitCallRequest(widget.matchId, req);
    }
  }

  void _onAllowAndConnect(CallConsentRequest req) async {
    // Hardware Permission Validation
    final hasPermissions = await CallPermissionHelper.requestCallPermissions(
      context: context,
      isVideo: req.callType == CallType.video,
    );
    if (!hasPermissions) return;

    await FirestoreService().updateCallRequestStatus(
      widget.matchId,
      CallConsentStatus.accepted,
    );
    _socket.emitCallResponse(
      matchId: widget.matchId,
      status: 'accepted',
      callType: req.callType.value,
    );
    setState(() => _activeIncomingCallRequest = null);

    if (!mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          matchId: widget.matchId,
          matchName: widget.matchName,
          matchAvatarUrl: widget.matchAvatarUrl,
          isVideoCall: req.callType == CallType.video,
          currentUserId: widget.currentUserId,
        ),
      ),
    );

    if (result != null && mounted) {
      final pillMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        matchId: widget.matchId,
        senderId: widget.currentUserId,
        content: result,
        type: MessageType.callPill,
        sentAt: DateTime.now(),
        status: MessageStatus.read,
        isMine: true,
      );
      setState(() => _messages.insert(0, pillMsg));
      _socket.sendMessage(
        matchId: widget.matchId,
        content: result,
        tempId: pillMsg.id,
        type: 'call_pill',
      );
    }
  }

  void _onDeclineCall(CallConsentRequest req) async {
    await FirestoreService().updateCallRequestStatus(
      widget.matchId,
      CallConsentStatus.declined,
    );
    _socket.emitCallResponse(
      matchId: widget.matchId,
      status: 'declined',
      callType: req.callType.value,
    );
    setState(() => _activeIncomingCallRequest = null);
  }

  void _onMuteCallRequests(CallConsentRequest req) {
    _mutedCallMatches.add(widget.matchId);
    _onDeclineCall(req);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call requests muted from ${widget.matchName}'),
        backgroundColor: const Color(0xFF131924),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onCallExpired(CallConsentRequest req) async {
    await FirestoreService().updateCallRequestStatus(
      widget.matchId,
      CallConsentStatus.expired,
    );
    _socket.emitCallResponse(
      matchId: widget.matchId,
      status: 'expired',
      callType: req.callType.value,
    );
    setState(() => _activeIncomingCallRequest = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call request timed out.'),
          backgroundColor: Color(0xFF131924),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onCallTapped(bool isVideo) async {
    if (!_isCallingUnlocked) {
      _showSafeCallingLockedModal();
      return;
    }

    // Step 1: Pre-flight local hardware permission validation
    final hasPermissions = await CallPermissionHelper.requestCallPermissions(
      context: context,
      isVideo: isVideo,
    );
    if (!hasPermissions) return;

    // Step 2: Formulate real-time call request event payload
    final callRequest = CallConsentRequest(
      callerId: widget.currentUserId,
      callerName: 'You',
      callerAvatarUrl: null,
      callType: isVideo ? CallType.video : CallType.audio,
      status: CallConsentStatus.pending,
      timestamp: DateTime.now(),
      ttl: 30,
    );

    // Step 3: Emit lightweight event over Firestore (/conversations/{id}/call_requests) & WebSocket
    await FirestoreService().emitCallRequest(widget.matchId, callRequest);
    _socket.emitCallRequest(
      matchId: widget.matchId,
      data: callRequest.toMap(),
    );

    if (!mounted) return;

    // Step 4: Display Romantic Frosted Glass Loader Modal with 30s Circular Countdown
    final outcome = await CallerCallWaitingModal.show(
      context: context,
      conversationId: widget.matchId,
      peerName: widget.matchName,
      peerAvatarUrl: widget.matchAvatarUrl,
      callType: callRequest.callType,
      request: callRequest,
      onCancel: () {
        _socket.emitCallResponse(
          matchId: widget.matchId,
          status: 'cancelled',
          callType: callRequest.callType.value,
        );
      },
    );

    // Step 5: Process Caller Handshake State Machine Result
    if (!mounted) return;

    if (outcome == CallConsentStatus.accepted) {
      // Permission Handshake Approved! Launch Hardware-Protected Encrypted Call Screen
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            matchId: widget.matchId,
            matchName: widget.matchName,
            matchAvatarUrl: widget.matchAvatarUrl,
            isVideoCall: isVideo,
            currentUserId: widget.currentUserId,
          ),
        ),
      );

      if (result != null && mounted) {
        final pillMsg = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          matchId: widget.matchId,
          senderId: widget.currentUserId,
          content: result,
          type: MessageType.callPill,
          sentAt: DateTime.now(),
          status: MessageStatus.read,
          isMine: true,
        );
        setState(() => _messages.insert(0, pillMsg));
        _socket.sendMessage(
          matchId: widget.matchId,
          content: result,
          tempId: pillMsg.id,
          type: 'call_pill',
        );
      }
    } else if (outcome == CallConsentStatus.declined) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.matchName} is unavailable right now'),
          backgroundColor: const Color(0xFF131924),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (outcome == CallConsentStatus.expired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call request timed out.'),
          backgroundColor: Color(0xFF131924),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSafeCallingLockedModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surfaceL1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.warmAmber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.warmAmber, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Calling Suite Locked 🔒',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To protect your privacy and ensure safe connections, Voice and Video calling unlocks only after:\n\n1. Connection request handshake is accepted\n2. At least 3 mutual messages are exchanged',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceL2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoPurgeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surfaceL1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.sunsetCoral, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Auto-Purge Messages',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Automatically erase messages after a set duration for heightened privacy.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ...[
                {'title': 'Off', 'desc': 'Messages remain indefinitely', 'val': 'off'},
                {'title': '24 Hours', 'desc': 'Messages disappear 24h after being sent', 'val': '24h'},
                {'title': 'Upon Exit', 'desc': 'Nuclear wipe: Purges conversation when exiting this chat', 'val': 'upon_exit'},
              ].map((opt) {
                final isSelected = _autoPurgeTtl == opt['title'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.sunsetCoral.withValues(alpha: 0.12) : AppColors.surfaceL2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.sunsetCoral : AppColors.cardBorder,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      opt['title']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      opt['desc']!,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.sunsetCoral, size: 20)
                        : null,
                    onTap: () {
                      final selectedTitle = opt['title']!;
                      final ttlVal = opt['val']!;
                      setState(() => _autoPurgeTtl = selectedTitle);
                      _socket.setAutoPurge(widget.matchId, ttlVal);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Auto-Purge set to $selectedTitle'),
                          backgroundColor: AppColors.surfaceL2,
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmInstantPurge() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceL1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppColors.sunsetCoral, size: 24),
            SizedBox(width: 8),
            Text(
              'Purge Chat (Two-Way)?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all messages in this conversation simultaneously across both client memory stores and the Firestore document database in real-time. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _socket.instantPurge(widget.matchId);
              FirestoreService().instantPurge(widget.matchId);
              setState(() => _messages.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Instant Two-Way Purge completed for both participants.'),
                  backgroundColor: AppColors.surfaceL2,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sunsetCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Purge for Both', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteSheet(ChatMessage msg) {
    if (msg.isUnsent) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        decoration: BoxDecoration(
          color: AppColors.surfaceL1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (msg.isMine) ...[
              ListTile(
                leading: const Icon(Icons.undo_rounded, color: AppColors.error),
                title: const Text('Unsend for Everyone',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                subtitle: const Text('Remove this message for both participants',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _performDelete(msg, 'for_everyone');
                },
              ),
              const Divider(color: AppColors.surfaceL2),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.textPrimary),
              title: const Text('Delete for Me',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              subtitle: const Text('This message will be removed from your device only',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _performDelete(msg, 'for_me');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _performDelete(ChatMessage msg, String deleteType) {
    setState(() {
      if (deleteType == 'for_everyone') {
        msg.content = 'This message was unsent';
        msg.isUnsent = true;
      } else {
        _messages.removeWhere((m) => m.id == msg.id);
      }
    });

    _socket.deleteMessage(
      matchId: widget.matchId,
      messageId: msg.id,
      deleteType: deleteType,
    );
  }

  void _onInputChanged(String val) {
    if (!_isTyping && val.isNotEmpty) {
      _isTyping = true;
      _socket.sendTypingStart(widget.matchId);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _socket.sendTypingStop(widget.matchId);
      }
    });
  }

  void _sendMessage([String? customContent]) {
    final text = (customContent ?? _inputController.text).trim();
    if (text.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMsg = ChatMessage(
      id: tempId,
      matchId: widget.matchId,
      senderId: widget.currentUserId,
      content: text,
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
      isMine: true,
    );

    setState(() {
      _messages.insert(0, optimisticMsg);
      _safetyBannerVisible = false;
    });

    if (customContent == null) {
      _inputController.clear();
    }
    _isTyping = false;
    _socket.sendTypingStop(widget.matchId);
    _socket.sendMessage(
      matchId: widget.matchId,
      content: text,
      tempId: tempId,
    );
    // Persist live message to Cloud Firestore
    try {
      final firestore = FirebaseFirestore.instance;
      firestore
          .collection('conversations')
          .doc(widget.matchId)
          .collection('messages')
          .doc(tempId)
          .set({
        'messageId': tempId,
        'conversationId': widget.matchId,
        'senderId': widget.currentUserId,
        'content': text,
        'decryptedText': text,
        'sentAt': FieldValue.serverTimestamp(),
      });
      final snippet = {
        'matchId': widget.matchId,
        'peerName': widget.matchName,
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      };
      firestore
          .collection('users')
          .doc(widget.currentUserId)
          .collection('chats')
          .doc(widget.matchId)
          .set(snippet, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatScreen] Firestore persist notice: $e');
    }
    _scrollToBottom();
    _evaluateChemistry();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }


  void _sendVoiceNote() {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final voiceMsg = ChatMessage(
      id: tempId,
      matchId: widget.matchId,
      senderId: widget.currentUserId,
      content: 'Voice Note (0:05)',
      type: MessageType.voiceNote,
      audioDurationSeconds: 5,
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
      isMine: true,
    );

    setState(() {
      _messages.insert(0, voiceMsg);
      _safetyBannerVisible = false;
    });

    _socket.sendMessage(
      matchId: widget.matchId,
      content: 'Voice Note (0:05)',
      tempId: tempId,
      type: 'voice_note',
    );
    _scrollToBottom();
  }

  void _toggleTranslate(ChatMessage msg) async {
    if (msg.translatedContent != null) {
      setState(() {
        msg.showTranslated = !msg.showTranslated;
      });
      return;
    }

    setState(() => msg.isTranslating = true);
    final result = await ChatTranslationService().translateMessage(
      text: msg.content,
      targetLanguage: 'en',
    );

    if (mounted) {
      setState(() {
        msg.isTranslating = false;
        msg.translatedContent = result.translatedText;
        msg.detectedLanguage = result.detectedLanguageName;
        msg.showTranslated = true;
      });
    }
  }

  void _toggleVoiceTranscript(ChatMessage msg) {
    setState(() {
      msg.isTranscriptExpanded = !msg.isTranscriptExpanded;
    });
  }

  void _toggleVoiceTranscriptTranslate(ChatMessage msg) async {
    if (msg.translatedTranscript != null) {
      setState(() {
        msg.showTranslatedTranscript = !msg.showTranslatedTranscript;
      });
      return;
    }

    if (msg.voiceTranscript == null) return;

    setState(() => msg.isTranscribing = true);
    final result = await ChatTranslationService().translateMessage(
      text: msg.voiceTranscript!,
      targetLanguage: 'en',
      isVoiceTranscript: true,
    );

    if (mounted) {
      setState(() {
        msg.isTranscribing = false;
        msg.translatedTranscript = result.translatedText;
        msg.transcriptLanguage = result.detectedLanguageName;
        msg.showTranslatedTranscript = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              // Ultra-sleek, 4px glassmorphic ambient temperature track directly below AppBar
              VibeTemperatureBar(
                score: _currentChemistryScore,
                onThresholdTap: () {
                  if (_currentChemistryScore >= 80) {
                    VibeSparkIgnitionModal.show(
                      context,
                      score: _currentChemistryScore,
                      matchName: widget.matchName,
                      onDatePlanSelected: (invite) => _sendMessage(invite),
                    );
                  }
                },
              ),
              if (_safetyBannerVisible) _buildSafetyBanner(),
              Expanded(child: _buildMessageList()),
              if (_peerIsTyping) const _TypingIndicator(),
              if (_handshakeStatus == HandshakeStatus.pendingReceived)
                _buildHandshakeDecisionBar()
              else if (_handshakeStatus == HandshakeStatus.pendingSent)
                _buildHandshakeLockedBar()
              else
                _buildInputBar(),
            ],
          ),
          if (_activeIncomingCallRequest != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: ReceiverCallConsentCard(
                request: _activeIncomingCallRequest!,
                onAllowAndConnect: () =>
                    _onAllowAndConnect(_activeIncomingCallRequest!),
                onDecline: () => _onDeclineCall(_activeIncomingCallRequest!),
                onMute: () => _onMuteCallRequests(_activeIncomingCallRequest!),
                onExpired: () => _onCallExpired(_activeIncomingCallRequest!),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleHideChatWithSecretCode() async {
    final hasCode = await SecretVaultService().hasSecretCodeConfigured();
    if (!mounted) return;

    if (!hasCode) {
      // First time: prompt to create a secret code
      final created = await SecretCodeSetupDialog.show(context);
      if (!created || !mounted) return;
    }

    // Confirm hiding chat
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F141C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFFF4D67), size: 22),
            SizedBox(width: 10),
            Text(
              'Hide Chat in Vault?',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Conversation with ${widget.matchName} will be hidden from your inbox and protected by your Secret Code.\n\nTo view this chat again, type your secret code into the inbox search bar.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D67),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Hide Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SecretVaultService().addConversationsToVault([widget.matchId]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat with ${widget.matchName} moved to Secret Vault'),
          backgroundColor: const Color(0xFF0F141C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // Return to inbox feed
    }
  }

  AppBar _buildAppBar() {
    const Color roseGold = Color(0xFFF472B6);
    const Color sunsetCoral = Color(0xFFFF4D67);

    return AppBar(
      titleSpacing: 0,
      leading: const BackButton(color: AppColors.textPrimary),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.electricIris,
            backgroundImage: widget.matchAvatarUrl != null
                ? NetworkImage(widget.matchAvatarUrl!)
                : null,
            child: widget.matchAvatarUrl == null
                ? Text(widget.matchName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.matchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? const Color(0xFF00F5A0) : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _isOnline ? 'Online' : 'Offline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (_autoPurgeTtl != 'Off') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: sunsetCoral.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⏱️ $_autoPurgeTtl',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: sunsetCoral,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Voice Call Action Icon (Soft Sunset Coral tint)
        IconButton(
          tooltip: _isCallingUnlocked ? 'Encrypted Voice Call' : 'Voice Call Locked (Safe Gatekeeping)',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.call_rounded,
                color: _isCallingUnlocked ? sunsetCoral : AppColors.textDisabled,
                size: 20,
              ),
              if (!_isCallingUnlocked)
                const Positioned(
                  right: -3,
                  top: -3,
                  child: Icon(Icons.lock_rounded, color: AppColors.warmAmber, size: 10),
                ),
            ],
          ),
          onPressed: () => _onCallTapped(false),
        ),

        // Video Call Action Icon (Soft Rose Gold tint)
        IconButton(
          tooltip: _isCallingUnlocked ? 'Encrypted Video Call' : 'Video Call Locked (Safe Gatekeeping)',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.videocam_rounded,
                color: _isCallingUnlocked ? roseGold : AppColors.textDisabled,
                size: 22,
              ),
              if (!_isCallingUnlocked)
                const Positioned(
                  right: -3,
                  top: -3,
                  child: Icon(Icons.lock_rounded, color: AppColors.warmAmber, size: 10),
                ),
            ],
          ),
          onPressed: () => _onCallTapped(true),
        ),

        // Auto-Purge TTL Selector Icon (Soft Rose Gold tint)
        IconButton(
          tooltip: 'Auto-Purge TTL',
          icon: Icon(
            _autoPurgeTtl != 'Off' ? Icons.timer_rounded : Icons.timer_outlined,
            color: _autoPurgeTtl != 'Off' ? sunsetCoral : roseGold.withValues(alpha: 0.85),
            size: 22,
          ),
          onPressed: _showAutoPurgeSelector,
        ),

        // More Options Popup Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          color: AppColors.surfaceL2,
          onSelected: (val) {
            if (val == 'hide_chat_vault') {
              _handleHideChatWithSecretCode();
            } else if (val == 'instant_purge') {
              _confirmInstantPurge();
            } else if (val == 'auto_purge') {
              _showAutoPurgeSelector();
            } else if (val == 'toggle_mute_calls') {
              setState(() {
                if (_mutedCallMatches.contains(widget.matchId)) {
                  _mutedCallMatches.remove(widget.matchId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Call requests unmuted for ${widget.matchName}'),
                      backgroundColor: AppColors.surfaceL2,
                    ),
                  );
                } else {
                  _mutedCallMatches.add(widget.matchId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Call requests muted for ${widget.matchName}'),
                      backgroundColor: AppColors.surfaceL2,
                    ),
                  );
                }
              });
            } else if (val == 'simulate_incoming_call') {
              // Emulate incoming call request from peer for interactive verification
              final mockReq = CallConsentRequest(
                callerId: widget.matchId,
                callerName: widget.matchName,
                callerAvatarUrl: widget.matchAvatarUrl,
                callType: CallType.video,
                status: CallConsentStatus.pending,
                timestamp: DateTime.now(),
                ttl: 30,
              );
              FirestoreService().emitCallRequest(widget.matchId, mockReq);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'hide_chat_vault',
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: Color(0xFFFF758C), size: 18),
                  SizedBox(width: 10),
                  Text('Hide Chat (Secret Code)', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'auto_purge',
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 18),
                  SizedBox(width: 10),
                  Text('Auto-Purge Messages', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'instant_purge',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_rounded, color: AppColors.sunsetCoral, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Purge Chat (Two-Way)',
                    style: TextStyle(color: AppColors.sunsetCoral, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_mute_calls',
              child: Row(
                children: [
                  Icon(
                    _mutedCallMatches.contains(widget.matchId)
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _mutedCallMatches.contains(widget.matchId)
                        ? 'Unmute Call Requests'
                        : 'Mute Call Requests',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'simulate_incoming_call',
              child: Row(
                children: [
                  Icon(Icons.ring_volume_rounded, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 10),
                  Text('⚡ Test Incoming Call Banner',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'safety', child: Text('Safety Tips')),
            const PopupMenuItem(value: 'report', child: Text('Report')),
            const PopupMenuItem(
              value: 'block',
              child: Text('Block', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHandshakeDecisionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceL1,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppColors.sunsetCoral, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.matchName} wants to connect. Accept to unlock full messaging & calling.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _declineAndPurgeHandshake,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline & Purge', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _acceptHandshake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sunsetCoral,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Accept Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandshakeLockedBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceL1,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warmAmber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_rounded, color: AppColors.warmAmber, size: 16),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Awaiting handshake confirmation...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE4E6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: sunsetCoral, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'For your safety, never share personal contact info.',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _safetyBannerVisible = false),
            child: const Icon(Icons.close, color: AppColors.textTertiary, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showDate = index == _messages.length - 1 ||
            !_isSameDay(_messages[index].sentAt, _messages[index + 1].sentAt);
        return Column(
          children: [
            if (showDate) _DateDivider(date: msg.sentAt),
            _ChatBubble(
              message: msg,
              onLongPress: () => _showDeleteSheet(msg),
              onToggleTranslate: () => _toggleTranslate(msg),
              onToggleTranscript: () => _toggleVoiceTranscript(msg),
              onToggleTranscriptTranslate: () => _toggleVoiceTranscriptTranslate(msg),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceL1,
          border: Border(top: BorderSide(color: AppColors.surfaceL2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Emoji & GIF
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.emoji_emotions_outlined,
                  color: AppColors.textTertiary, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.gif_box_outlined,
                  color: AppColors.textTertiary, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextField(
                  controller: _inputController,
                  onChanged: _onInputChanged,
                  maxLines: null,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceL2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Image attach
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.image_outlined,
                  color: AppColors.textTertiary, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            const SizedBox(width: 4),

            // Send or Mic button with Electric Iris (#7928CA) / Sunset Coral gradient
            ValueListenableBuilder(
              valueListenable: _inputController,
              builder: (_, __, ___) {
                final hasText = _inputController.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: hasText ? _sendMessage : _sendVoiceNote,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: hasText
                          ? const LinearGradient(
                              colors: [sunsetCoral, electricIris],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF231E35), Color(0xFF1B2030)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasText
                            ? Colors.transparent
                            : electricIris.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: hasText
                          ? [
                              BoxShadow(
                                color: electricIris.withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      hasText ? Icons.send_rounded : Icons.mic_rounded,
                      color: hasText ? Colors.white : roseGold,
                      size: hasText ? 18 : 20,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────
// CHAT BUBBLE WIDGET
// ─────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleTranslate;
  final VoidCallback? onToggleTranscript;
  final VoidCallback? onToggleTranscriptTranslate;

  const _ChatBubble({
    required this.message,
    this.onLongPress,
    this.onToggleTranslate,
    this.onToggleTranscript,
    this.onToggleTranscriptTranslate,
  });

  static const List<String> _fontFallbacks = [
    'Noto Sans',
    'Noto Sans Devanagari',
    'Noto Sans Telugu',
    'Noto Sans Tamil',
    'Noto Sans Bengali',
    'Noto Sans Gurmukhi',
    'Noto Sans Gujarati',
    'Noto Sans Kannada',
    'Noto Sans Malayalam',
    'Noto Sans Oriya',
    'Noto Sans Arabic',
    'sans-serif',
  ];

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.callPill) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A313C)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_callback_rounded, color: AppColors.sunsetCoral, size: 14),
              const SizedBox(width: 8),
              Text(
                message.content,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamilyFallback: _fontFallbacks,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayText = (message.showTranslated && message.translatedContent != null)
        ? message.translatedContent!
        : message.content;

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.84,
          ),
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: message.isUnsent
                      ? null
                      : (message.isMine
                          ? const LinearGradient(
                              colors: [sunsetCoral, electricIris],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null),
                  color: message.isUnsent
                      ? AppColors.surfaceL2.withValues(alpha: 0.6)
                      : (message.isMine ? null : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(message.isMine ? 16 : 4),
                    bottomRight: Radius.circular(message.isMine ? 4 : 16),
                  ),
                  border: message.isMine && !message.isUnsent
                      ? null
                      : Border.all(color: const Color(0xFFFFE4E6), width: 1.0),
                ),
                child: message.isUnsent
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_rounded,
                              size: 15, color: AppColors.textTertiary),
                          SizedBox(width: 6),
                          Text(
                            'This message was unsent',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    : (message.type == MessageType.voiceNote
                        ? _buildVoiceNoteContent(context)
                        : _buildTextContent(displayText)),
              ),

              // Timestamp + status
              if (!message.isUnsent)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.sentAt),
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 10),
                      ),
                      if (message.isMine) ...[
                        const SizedBox(width: 4),
                        _StatusIcon(status: message.status),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(String displayText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: TextStyle(
            color: message.isMine ? Colors.white : const Color(0xFF181829),
            fontWeight: message.isMine ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            height: 1.4,
            fontFamilyFallback: _fontFallbacks,
          ),
        ),

        // Real-Time In-Chat Inline Translation Toggle Pill in Soft Rose (#FFF1F2)
        if (!message.isUnsent) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: onToggleTranslate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: message.isMine
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: message.showTranslated
                      ? sunsetCoral
                      : const Color(0xFFFFE4E6),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isTranslating) ...[
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        color: sunsetCoral,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Translating...',
                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ] else ...[
                    Icon(
                      Icons.translate_rounded,
                      size: 11,
                      color: message.showTranslated ? sunsetCoral : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.showTranslated
                            ? 'Translated (${message.detectedLanguage ?? "Auto"} -> EN) · Show Original'
                            : (message.detectedLanguage != null
                                ? 'Translate from ${message.detectedLanguage}'
                                : 'Translate to English'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: message.showTranslated ? sunsetCoral : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceNoteContent(BuildContext context) {
    final hasTranscript = message.voiceTranscript != null;
    final activeTranscriptText = (message.showTranslatedTranscript && message.translatedTranscript != null)
        ? message.translatedTranscript!
        : (message.voiceTranscript ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: message.isMine
                    ? Colors.white24
                    : AppColors.neonElectricMint.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: message.isMine
                    ? Colors.white
                    : AppColors.neonElectricMint,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            // Audio Waveform Visualization
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 16; i++)
                  Container(
                    width: 2.5,
                    height: 5.0 + ((i * 7) % 18).toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: message.isMine
                          ? Colors.white70
                          : AppColors.cyanGlow,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              '0:0${message.audioDurationSeconds ?? 5}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: message.isMine
                    ? Colors.white70
                    : AppColors.textSecondary,
              ),
            ),
            if (hasTranscript) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onToggleTranscript,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceL2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: message.isTranscriptExpanded
                          ? AppColors.neonElectricMint
                          : AppColors.cyanGlow.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.subtitles_rounded,
                        size: 11,
                        color: message.isTranscriptExpanded ? AppColors.neonElectricMint : AppColors.cyanGlow,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        message.isTranscriptExpanded ? 'Hide' : 'Transcript',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: message.isTranscriptExpanded ? AppColors.neonElectricMint : AppColors.cyanGlow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        // Expandable Multi-Lingual Transcript Drawer
        if (hasTranscript && message.isTranscriptExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: message.isMine
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.surfaceL2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.neonElectricMint.withValues(alpha: 0.3),
                width: 0.7,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic_rounded, size: 12, color: AppColors.neonElectricMint),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '🎙️ ${message.transcriptLanguage ?? "Dialect"} Audio Transcript',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neonElectricMint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded, size: 14, color: AppColors.cyanGlow),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activeTranscriptText,
                  style: TextStyle(
                    fontSize: 13,
                    color: message.isMine ? Colors.white : AppColors.textPrimary,
                    height: 1.35,
                    fontFamilyFallback: _fontFallbacks,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onToggleTranscriptTranslate,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: message.isMine
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.surfaceL1,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: message.showTranslatedTranscript
                            ? AppColors.neonElectricMint
                            : AppColors.cyanGlow.withValues(alpha: 0.35),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isTranscribing) ...[
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.2,
                              color: AppColors.neonElectricMint,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Translating Speech...',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        ] else ...[
                          Icon(
                            Icons.translate_rounded,
                            size: 11,
                            color: message.showTranslatedTranscript ? AppColors.neonElectricMint : AppColors.cyanGlow,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              message.showTranslatedTranscript
                                  ? 'Translated (${message.transcriptLanguage ?? "Dialect"} -> EN) · Show Original'
                                  : 'Translate Speech to English',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: message.showTranslatedTranscript ? AppColors.neonElectricMint : AppColors.cyanGlow,
                            ),
                          ),),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == MessageStatus.sending) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
            strokeWidth: 1.5, color: AppColors.textTertiary),
      );
    }
    final isRead = status == MessageStatus.read;
    return Icon(
      status == MessageStatus.sent ? Icons.check : Icons.done_all,
      size: 14,
      color: isRead ? const Color(0xFFF8FAFC) : AppColors.textTertiary,
    );
  }
}

// ─────────────────────────────────────────────────────────
// TYPING INDICATOR
// ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    // Stagger start
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.glassBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    gradient: AppColors.auroraGradient,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// DATE DIVIDER
// ─────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.surfaceL2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 11)),
          ),
          const Expanded(child: Divider(color: AppColors.surfaceL2)),
        ],
      ),
    );
  }
}
