import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart' show ChatMessage, MessageType;

/// Factor breakdown explaining chemistry calculation
class VibeSparkBreakdown {
  final double balanceScore;   // 0 - 35
  final double momentumScore;  // 0 - 35
  final double depthScore;     // 0 - 30
  final int totalScore;        // 0 - 100

  const VibeSparkBreakdown({
    required this.balanceScore,
    required this.momentumScore,
    required this.depthScore,
    required this.totalScore,
  });

  String get tier {
    if (totalScore < 50) return 'Frosted Glacial';
    if (totalScore < 80) return 'Electric Iris';
    return 'Resonance Ignited';
  }
}

/// Reactive Controller & Calculation Engine for Aura Vibe Chemistry Score (0% - 100%)
///
/// Evaluates:
/// 1. Balanced exchange: Both users sending messages with similar frequency.
/// 2. Response momentum: Quick reply bursts indicating high engagement.
/// 3. Interaction depth: Media shares, voice notes, questions, and length balance.
///
/// Streams updates via Firestore `/conversations/{id}/chemistryScore` and emits
/// a distinct threshold trigger event when score >= 80 (once per session).
class VibeSparkEngine {
  static const int ignitionThreshold = 80;

  final FirestoreService _firestoreService;
  final StreamController<int> _scoreController = StreamController<int>.broadcast();
  final StreamController<int> _ignitionController = StreamController<int>.broadcast();
  final StreamController<VibeSparkBreakdown> _breakdownController =
      StreamController<VibeSparkBreakdown>.broadcast();

  int _currentScore = 0;
  bool _hasIgnitedInSession = false;
  StreamSubscription<int>? _firestoreSubscription;
  String? _activeConversationId;

  VibeSparkEngine({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  Stream<int> get scoreStream => _scoreController.stream;
  Stream<int> get ignitionStream => _ignitionController.stream;
  Stream<VibeSparkBreakdown> get breakdownStream => _breakdownController.stream;

  int get currentScore => _currentScore;
  bool get hasIgnited => _hasIgnitedInSession;

  void markIgnited() {
    _hasIgnitedInSession = true;
  }

  void resetIgnitionSession() {
    _hasIgnitedInSession = false;
  }

  /// Binds reactive engine to a specific conversation document in Firestore
  void bindConversation(String conversationId) {
    if (_activeConversationId == conversationId) return;
    _activeConversationId = conversationId;
    _firestoreSubscription?.cancel();

    _firestoreSubscription =
        _firestoreService.chemistryScoreStream(conversationId).listen((remoteScore) {
      onRemoteScoreReceived(remoteScore);
    });
  }

  /// Calculates factor breakdown and overall chemistry score (0 - 100)
  VibeSparkBreakdown calculateBreakdown({
    required List<ChatMessage> messages,
    required String currentUserId,
  }) {
    if (messages.isEmpty) {
      return const VibeSparkBreakdown(
        balanceScore: 0,
        momentumScore: 0,
        depthScore: 0,
        totalScore: 0,
      );
    }

    // 1. BALANCED EXCHANGE (up to 35 points)
    int myCount = 0;
    int peerCount = 0;
    for (final m in messages) {
      if (m.isMine || m.senderId == currentUserId) {
        myCount++;
      } else {
        peerCount++;
      }
    }

    final totalCount = myCount + peerCount;
    final int minCount = min(myCount, peerCount);
    final int maxCount = max(myCount, peerCount);
    final double balanceRatio = maxCount == 0 ? 0.0 : (minCount / maxCount);
    final double volumeRamp = (totalCount / 10.0).clamp(0.1, 1.0);
    final double balanceScore = (35.0 * balanceRatio * volumeRamp).clamp(0.0, 35.0);

    // 2. RESPONSE MOMENTUM (up to 35 points)
    final sorted = List<ChatMessage>.from(messages)
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    double momentumWeightSum = 0.0;
    int alternatingTurns = 0;
    int rapidStreak = 0;

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      if (prev.senderId != curr.senderId) {
        alternatingTurns++;
        final deltaSec = curr.sentAt.difference(prev.sentAt).inSeconds.abs();
        if (deltaSec <= 45) {
          momentumWeightSum += 1.0;
          rapidStreak++;
        } else if (deltaSec <= 120) {
          momentumWeightSum += 0.85;
          rapidStreak++;
        } else if (deltaSec <= 300) {
          momentumWeightSum += 0.55;
          rapidStreak = 0;
        } else if (deltaSec <= 900) {
          momentumWeightSum += 0.3;
          rapidStreak = 0;
        } else {
          momentumWeightSum += 0.1;
          rapidStreak = 0;
        }
      }
    }

    final double avgTurnWeight =
        alternatingTurns == 0 ? 0.3 : (momentumWeightSum / alternatingTurns);
    final double burstBonus = min(8.0, rapidStreak * 2.0);
    final double momentumScore =
        ((avgTurnWeight * 27.0) + burstBonus).clamp(0.0, 35.0);

    // 3. INTERACTION DEPTH (up to 30 points)
    double mediaPoints = 0.0;
    double questionPoints = 0.0;
    double lengthPoints = 0.0;

    for (final m in messages) {
      if (m.type == MessageType.voiceNote ||
          m.type == MessageType.image ||
          m.type == MessageType.gift ||
          m.giftVoucher != null ||
          m.type == MessageType.sticker) {
        mediaPoints = min(14.0, mediaPoints + 6.0);
      }

      final text = m.content.toLowerCase();
      if (text.contains('?') ||
          text.contains('what') ||
          text.contains('how') ||
          text.contains('why') ||
          text.contains('kya') ||
          text.contains('kaise')) {
        questionPoints = min(8.0, questionPoints + 3.0);
      }

      if (m.content.trim().length >= 25) {
        lengthPoints = min(8.0, lengthPoints + 2.0);
      }
    }

    final double depthScore =
        (mediaPoints + questionPoints + lengthPoints).clamp(0.0, 30.0);

    final int total = (balanceScore + momentumScore + depthScore).round().clamp(0, 100);

    return VibeSparkBreakdown(
      balanceScore: balanceScore,
      momentumScore: momentumScore,
      depthScore: depthScore,
      totalScore: total,
    );
  }

  Future<int> evaluateAndSync({
    required List<ChatMessage> messages,
    required String currentUserId,
    required String conversationId,
  }) async {
    final breakdown = calculateBreakdown(
      messages: messages,
      currentUserId: currentUserId,
    );
    final newScore = breakdown.totalScore;

    _breakdownController.add(breakdown);
    _applyScore(newScore);

    await _firestoreService.updateChemistryScore(conversationId, newScore);

    return newScore;
  }

  void onRemoteScoreReceived(int score) {
    final clamped = score.clamp(0, 100);
    _applyScore(clamped);
  }

  void _applyScore(int score) {
    final previous = _currentScore;
    _currentScore = score;
    _scoreController.add(score);

    if (_currentScore >= ignitionThreshold && !_hasIgnitedInSession) {
      _hasIgnitedInSession = true;
      debugPrint('[VibeSparkEngine] 🔥 Resonance Ignited at $_currentScore%!');
      _ignitionController.add(_currentScore);
    } else if (previous != score) {
      debugPrint('[VibeSparkEngine] Vibe Resonance updated to $_currentScore%');
    }
  }

  void dispose() {
    _firestoreSubscription?.cancel();
    _scoreController.close();
    _ignitionController.close();
    _breakdownController.close();
  }
}
