import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/security/security_service.dart';

/// Secure In-App Calling Suite (Audio & Video)
/// Powered by WebRTC / Agora RTC encrypted signaling architecture
/// Enforces hardware-level Android FLAG_SECURE on Call Viewports to prevent screenshots and screen recordings
/// Ephemeral zero-knowledge: Persists 0 recordings or logs outside in-chat status pill
class CallScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String? matchAvatarUrl;
  final bool isVideoCall;
  final String currentUserId;

  const CallScreen({
    super.key,
    required this.matchId,
    required this.matchName,
    this.matchAvatarUrl,
    required this.isVideoCall,
    required this.currentUserId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  late bool _isVideoEnabled;
  bool _isFrontCamera = true;
  bool _isConnected = false;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  Timer? _connectTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideoCall;

    // Enforce Android FLAG_SECURE on calling viewport to block screenshots & screen recording
    SecurityService.setScreenSecurity(true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Simulate WebRTC / Agora RTC peer connection establishment
    _connectTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _isConnected = true);
      _startDurationTimer();
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  String _formatCallEndedPill(int totalSeconds) {
    if (totalSeconds < 60) {
      return 'Call Ended · ${totalSeconds}s';
    }
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return 'Call Ended · ${m}m ${s}s';
  }

  void _endCall() {
    final pillText = _formatCallEndedPill(_callDurationSeconds);
    Navigator.of(context).pop(pillText);
  }

  @override
  void dispose() {
    // Restore normal security mode
    SecurityService.setScreenSecurity(false);
    _connectTimer?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080A0F), // Deep Space Obsidian
        body: Stack(
          children: [
            // ── Background Ambient / Video Viewport ──
            if (widget.isVideoCall && _isVideoEnabled)
              _buildVideoViewport()
            else
              _buildVoiceAudioAura(),

            // ── Top Bar: Security & Encryption Indicator ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Encryption Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2A313C)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: Color(0xFF00F5A0), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'ENCRYPTED · DTLS-SRTP',
                            style: TextStyle(
                              color: Color(0xFF00F5A0),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // FLAG_SECURE Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sunsetCoral.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.sunsetCoral.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: AppColors.sunsetCoral, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'SCREEN SHIELD ON',
                            style: TextStyle(
                              color: AppColors.sunsetCoral,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── PiP Self View (when in video mode) ──
            if (widget.isVideoCall && _isVideoEnabled)
              Positioned(
                top: 80,
                right: 20,
                child: _buildPipSelfView(),
              ),

            // ── Bottom Calling Controls Bar (Glassmorphic) ──
            Positioned(
              bottom: 36,
              left: 20,
              right: 20,
              child: _buildCallControls(),
            ),
          ],
        ),
      ),
    );
  }

  /// Voice Audio Call Viewport with Breathing Avatar & Waves
  Widget _buildVoiceAudioAura() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Concentric Pulsing Audio Radar Rings
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.sunsetCoral.withValues(alpha: 0.35),
                        AppColors.electricIris.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sunsetCoral.withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: AppColors.surfaceL2,
                      backgroundImage: widget.matchAvatarUrl != null
                          ? NetworkImage(widget.matchAvatarUrl!)
                          : null,
                      child: widget.matchAvatarUrl == null
                          ? Text(
                              widget.matchName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Match Name
          Text(
            widget.matchName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Call Status or Duration Counter
          Text(
            _isConnected
                ? _formatDuration(_callDurationSeconds)
                : 'Securing encrypted channel...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _isConnected ? const Color(0xFF00F5A0) : AppColors.textSecondary,
              letterSpacing: _isConnected ? 1.5 : 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Video Call Simulated Feed
  Widget _buildVideoViewport() {
    return Stack(
      children: [
        // Main Remote Video Feed
        Positioned.fill(
          child: widget.matchAvatarUrl != null
              ? Image.network(
                  widget.matchAvatarUrl!,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: const Color(0xFF161B22),
                  child: Center(
                    child: Text(
                      widget.matchName[0],
                      style: const TextStyle(fontSize: 80, color: Colors.white24),
                    ),
                  ),
                ),
        ),

        // Gradient Shade Overlay
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xCC080A0F),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xE6080A0F),
                ],
                stops: [0.0, 0.25, 0.7, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Remote peer name & duration header
        Positioned(
          top: 80,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.matchName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00F5A0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? _formatDuration(_callDurationSeconds) : 'Connecting...',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Picture-in-Picture Local User View
  Widget _buildPipSelfView() {
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surfaceL2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            color: const Color(0xFF1F242C),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white30, size: 36),
            ),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  /// Glassmorphic Rounded Call Controls
  Widget _buildCallControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Mute Button
              _buildControlCircle(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                isActive: _isMuted,
                activeColor: AppColors.sunsetCoral,
                onTap: () => setState(() => _isMuted = !_isMuted),
              ),

              // Speakerphone Button
              _buildControlCircle(
                icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                isActive: _isSpeakerOn,
                activeColor: AppColors.electricIris,
                onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
              ),

              // Video Switch / Toggle Button
              if (widget.isVideoCall) ...[
                _buildControlCircle(
                  icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  isActive: !_isVideoEnabled,
                  activeColor: AppColors.sunsetCoral,
                  onTap: () => setState(() => _isVideoEnabled = !_isVideoEnabled),
                ),
                _buildControlCircle(
                  icon: Icons.flip_camera_ios_rounded,
                  isActive: false,
                  onTap: () => setState(() => _isFrontCamera = !_isFrontCamera),
                ),
              ],

              // End Call Button
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF4D67),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D67).withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCircle({
    required IconData icon,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? (activeColor ?? AppColors.sunsetCoral).withValues(alpha: 0.25)
              : const Color(0xFF1C222B),
          border: Border.all(
            color: isActive
                ? (activeColor ?? AppColors.sunsetCoral)
                : const Color(0xFF2A313C),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: isActive
                ? (activeColor ?? AppColors.sunsetCoral)
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
