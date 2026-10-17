import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Ultra-sleek, 4px glassmorphic temperature track positioned directly below the chat AppBar.
///
/// Progress gradients:
/// - Low (< 50%): Frosted Glacial Blue (#38BDF8)
/// - Medium (50% - 79%): Electric Iris Purple (#7928CA)
/// - High (>= 80%): Sunset Coral to Golden Sparkle (#FF4D67 -> #F59E0B)
///
/// Tapping the track displays a subtle glassmorphic pill badge:
/// "[Score]% Vibe Resonance"
class VibeTemperatureBar extends StatefulWidget {
  final int score;
  final VoidCallback? onThresholdTap;

  const VibeTemperatureBar({
    super.key,
    required this.score,
    this.onThresholdTap,
  });

  @override
  State<VibeTemperatureBar> createState() => _VibeTemperatureBarState();
}

class _VibeTemperatureBarState extends State<VibeTemperatureBar>
    with SingleTickerProviderStateMixin {
  bool _showBadge = false;
  Timer? _autoHideTimer;
  late AnimationController _badgeAnimController;
  late Animation<double> _badgeScale;
  late Animation<double> _badgeOpacity;

  @override
  void initState() {
    super.initState();
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _badgeScale = CurvedAnimation(
      parent: _badgeAnimController,
      curve: Curves.easeOutBack,
    );
    _badgeOpacity = CurvedAnimation(
      parent: _badgeAnimController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _badgeAnimController.dispose();
    super.dispose();
  }

  void _toggleBadge() {
    setState(() {
      _showBadge = !_showBadge;
    });

    if (_showBadge) {
      _badgeAnimController.forward();
      _autoHideTimer?.cancel();
      _autoHideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _showBadge) {
          _badgeAnimController.reverse().then((_) {
            if (mounted) setState(() => _showBadge = false);
          });
        }
      });
    } else {
      _badgeAnimController.reverse();
    }

    if (widget.score >= 80 && widget.onThresholdTap != null) {
      widget.onThresholdTap!();
    }
  }

  LinearGradient _resolveGradient(int score) {
    if (score < 50) {
      // Low (< 50%): Frosted Glacial Blue
      return const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    } else if (score < 80) {
      // Medium (50% - 79%): Electric Iris Purple
      return const LinearGradient(
        colors: [Color(0xFF7928CA), Color(0xFF9333EA)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    } else {
      // High (>= 80%): Sunset Coral to Golden Sparkle
      return const LinearGradient(
        colors: [Color(0xFFFF4D67), Color(0xFFF59E0B)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }
  }

  Color _resolveGlowColor(int score) {
    if (score < 50) return const Color(0x6638BDF8);
    if (score < 80) return const Color(0x667928CA);
    return const Color(0x80FF4D67);
  }

  String _resolveTierLabel(int score) {
    if (score < 50) return 'Frosted Glacial';
    if (score < 80) return 'Electric Iris';
    return 'Resonance Ignited 🔥';
  }

  @override
  Widget build(BuildContext context) {
    final clampedScore = widget.score.clamp(0, 100);
    final gradient = _resolveGradient(clampedScore);
    final glowColor = _resolveGlowColor(clampedScore);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 4px Glassmorphic Temperature Track
        GestureDetector(
          onTap: _toggleBadge,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 12,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.transparent, // expanded touch target
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Frosted track base
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Glowing progress bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    final targetWidth =
                        constraints.maxWidth * (clampedScore / 100.0);
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0.0, end: targetWidth),
                      builder: (context, width, child) {
                        return Container(
                          height: 4,
                          width: width,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor,
                                blurRadius: clampedScore >= 80 ? 10 : 6,
                                spreadRadius: clampedScore >= 80 ? 1.5 : 0.5,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                // Spark head beacon for >= 80%
                if (clampedScore >= 80)
                  Positioned(
                    left: null,
                    right: null,
                    top: -2,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final headOffset =
                            MediaQuery.of(context).size.width * (clampedScore / 100.0) - 4;
                        return Transform.translate(
                          offset: Offset(headOffset.clamp(0.0, MediaQuery.of(context).size.width - 8), 0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFFFFF),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF4D67),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Animated Glassmorphic Pill Badge: "[Score]% Vibe Resonance"
        AnimatedBuilder(
          animation: _badgeAnimController,
          builder: (context, child) {
            if (_badgeAnimController.value == 0.0) {
              return const SizedBox.shrink();
            }
            return Opacity(
              opacity: _badgeOpacity.value,
              child: Transform.scale(
                scale: _badgeScale.value,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE6080A0F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: clampedScore >= 80
                                ? const Color(0xFFFF4D67)
                                : const Color(0x33FFFFFF),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tier icon
                            Icon(
                              clampedScore >= 80
                                  ? Icons.local_fire_department_rounded
                                  : (clampedScore >= 50
                                      ? Icons.bolt_rounded
                                      : Icons.ac_unit_rounded),
                              size: 14,
                              color: clampedScore >= 80
                                  ? const Color(0xFFFF4D67)
                                  : (clampedScore >= 50
                                      ? const Color(0xFF9333EA)
                                      : const Color(0xFF38BDF8)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$clampedScore% Vibe Resonance',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${_resolveTierLabel(clampedScore)})',
                              style: TextStyle(
                                color: clampedScore >= 80
                                    ? const Color(0xFFF59E0B)
                                    : Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
