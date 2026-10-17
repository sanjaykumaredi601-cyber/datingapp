import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/features/chat/domain/entities/call_consent_request.dart';

/// Non-intrusive Glassmorphic Call Consent Card for Receiver UI
/// Displays caller avatar with pulsing Electric Iris halo (#7928CA),
/// Deep Obsidian Slate (#131924) glassmorphism, Allow & Connect, Not Now,
/// and Mute Call Requests options with 30s auto-expiry.
class ReceiverCallConsentCard extends StatefulWidget {
  final CallConsentRequest request;
  final VoidCallback onAllowAndConnect;
  final VoidCallback onDecline;
  final VoidCallback onMute;
  final VoidCallback onExpired;

  const ReceiverCallConsentCard({
    super.key,
    required this.request,
    required this.onAllowAndConnect,
    required this.onDecline,
    required this.onMute,
    required this.onExpired,
  });

  @override
  State<ReceiverCallConsentCard> createState() =>
      _ReceiverCallConsentCardState();
}

class _ReceiverCallConsentCardState extends State<ReceiverCallConsentCard>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.request.remainingSeconds;

    // Pulsing Electric Iris Halo (#7928CA)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 30-second TTL countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        widget.onExpired();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.request.callType == CallType.video;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Deep Obsidian Slate (#131924, 90% opacity, border: 1px solid rgba(255, 77, 103, 0.35))
            color: const Color(0xFF131924).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7928CA).withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Tag & Expiry Countdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7928CA).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7928CA).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                            color: const Color(0xFFFF4D67),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isVideo ? 'Incoming Video Request' : 'Incoming Audio Request',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Expires in ${_remainingSeconds}s',
                      style: TextStyle(
                        color: _remainingSeconds <= 5
                            ? const Color(0xFFFF4D67)
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Caller Details with Pulsing Electric Iris Halo (#7928CA)
              Row(
                children: [
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing Electric Iris Halo
                        AnimatedBuilder(
                          animation: _pulseScale,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseScale.value,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFF7928CA).withValues(alpha: 0.55),
                                      const Color(0xFF7928CA).withValues(alpha: 0.15),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.4, 0.75, 1.0],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF080A0F),
                            border: Border.all(
                              color: const Color(0xFF7928CA),
                              width: 2,
                            ),
                            image: widget.request.callerAvatarUrl != null &&
                                    widget.request.callerAvatarUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                        widget.request.callerAvatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: widget.request.callerAvatarUrl == null ||
                                  widget.request.callerAvatarUrl!.isEmpty
                              ? Center(
                                  child: Text(
                                    widget.request.callerName.isNotEmpty
                                        ? widget.request.callerName[0]
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Call Prompt Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.35,
                            ),
                            children: [
                              TextSpan(
                                text: widget.request.callerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF4D67),
                                ),
                              ),
                              const TextSpan(
                                text: ' is requesting an ',
                              ),
                              TextSpan(
                                text: isVideo ? 'Video' : 'Audio',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const TextSpan(
                                text: ' call.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Hardware streams are paused until you accept.',
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Action Buttons: Green / Mint "Allow & Connect" & Dark Frosted "Not Now"
              Row(
                children: [
                  // Dark Frosted "Not Now" Button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: widget.onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          backgroundColor: Colors.white.withValues(alpha: 0.07),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Not Now',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Green / Mint "Allow & Connect" Button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: widget.onAllowAndConnect,
                        icon: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Allow & Connect',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // Emerald / Mint
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // "Mute Call Requests" Option
              GestureDetector(
                onTap: widget.onMute,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Mute Call Requests from this user',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
