import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';

/// Frosted Glass Romantic Loader Modal for Caller UI
/// Displays 30-second countdown, pulsing avatar halo, real-time response listening,
/// and allows the caller to cancel the request at any time.
class CallerCallWaitingModal extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String? peerAvatarUrl;
  final CallType callType;
  final CallConsentRequest request;
  final VoidCallback onCancel;

  const CallerCallWaitingModal({
    super.key,
    required this.conversationId,
    required this.peerName,
    this.peerAvatarUrl,
    required this.callType,
    required this.request,
    required this.onCancel,
  });

  /// Static helper to display the modal
  static Future<CallConsentStatus?> show({
    required BuildContext context,
    required String conversationId,
    required String peerName,
    String? peerAvatarUrl,
    required CallType callType,
    required CallConsentRequest request,
    required VoidCallback onCancel,
  }) {
    return showDialog<CallConsentStatus>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CallerCallWaitingModal(
        conversationId: conversationId,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        callType: callType,
        request: request,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<CallerCallWaitingModal> createState() => _CallerCallWaitingModalState();
}

class _CallerCallWaitingModalState extends State<CallerCallWaitingModal>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  StreamSubscription<CallConsentRequest?>? _streamSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.request.ttl;

    // Glowing halo pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 30-second circular countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _handleTimeout();
      } else {
        setState(() => _remainingSeconds--);
      }
    });

    // Listen to real-time status updates on Firestore / WebSocket
    _streamSub = FirestoreService()
        .callRequestStream(widget.conversationId)
        .listen((req) {
      if (!mounted || req == null) return;
      if (req.status == CallConsentStatus.accepted) {
        _countdownTimer?.cancel();
        Navigator.of(context).pop(CallConsentStatus.accepted);
      } else if (req.status == CallConsentStatus.declined) {
        _countdownTimer?.cancel();
        Navigator.of(context).pop(CallConsentStatus.declined);
      } else if (req.status == CallConsentStatus.cancelled) {
        _countdownTimer?.cancel();
        Navigator.of(context).pop(CallConsentStatus.cancelled);
      } else if (req.status == CallConsentStatus.expired) {
        _countdownTimer?.cancel();
        Navigator.of(context).pop(CallConsentStatus.expired);
      }
    });
  }

  void _handleTimeout() {
    FirestoreService().updateCallRequestStatus(
      widget.conversationId,
      CallConsentStatus.expired,
    );
    if (mounted) {
      Navigator.of(context).pop(CallConsentStatus.expired);
    }
  }

  void _handleCancel() {
    _countdownTimer?.cancel();
    widget.onCancel();
    FirestoreService().updateCallRequestStatus(
      widget.conversationId,
      CallConsentStatus.cancelled,
    );
    if (mounted) {
      Navigator.of(context).pop(CallConsentStatus.cancelled);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _streamSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / widget.request.ttl;
    final isVideo = widget.callType == CallType.video;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleCancel();
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF131924).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF7928CA).withValues(alpha: 0.20),
                  blurRadius: 40,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Call Type & Encrypted Handshake Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: const Color(0xFFFF4D67),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isVideo ? 'Encrypted Video Call' : 'Encrypted Audio Call',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF10B981),
                        size: 13,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Pulsing Avatar & Circular Countdown Ring
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Pulsing Glow Halo
                      AnimatedBuilder(
                        animation: _pulseScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: 126,
                              height: 126,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF7928CA).withValues(alpha: 0.35),
                                    const Color(0xFFFF4D67).withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.4, 0.7, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Circular Progress Sweep Ring
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF4D67),
                          ),
                        ),
                      ),

                      // Center Peer Avatar / Icon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF080A0F),
                          border: Border.all(
                            color: const Color(0xFF7928CA).withValues(alpha: 0.5),
                            width: 2,
                          ),
                          image: widget.peerAvatarUrl != null &&
                                  widget.peerAvatarUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(widget.peerAvatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: widget.peerAvatarUrl == null ||
                                widget.peerAvatarUrl!.isEmpty
                            ? Center(
                                child: Text(
                                  widget.peerName.isNotEmpty
                                      ? widget.peerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // Countdown Seconds Floating Badge
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF080A0F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF4D67).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${_remainingSeconds}s',
                            style: const TextStyle(
                              color: Color(0xFFFF4D67),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Main Messaging
                Text(
                  'Call request sent to ${widget.peerName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for permission...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unsolicited calling is disabled for mutual privacy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 28),

                // Cancel Request Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _handleCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Cancel Request',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF4D67),
                      side: BorderSide(
                        color: const Color(0xFFFF4D67).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor:
                          const Color(0xFFFF4D67).withValues(alpha: 0.08),
                    ),
                  ),
                ),

                // Interactive QA / Simulation shortcuts
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        FirestoreService().updateCallRequestStatus(
                          widget.conversationId,
                          CallConsentStatus.accepted,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        '⚡ Test Peer Accept',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        FirestoreService().updateCallRequestStatus(
                          widget.conversationId,
                          CallConsentStatus.declined,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Test Peer Decline',
                        style: TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
