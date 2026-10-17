import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'date_concierge_sheet.dart';

/// Glowing micro-spark particle for Canvas particle burst
class SparkParticle {
  final double angle;
  final double speed;
  final double radius;
  final Color color;
  final double maxDistance;

  SparkParticle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.color,
    required this.maxDistance,
  });
}

/// Canvas rendering soft outward burst of glowing micro-sparks (locked 60 FPS)
class SparkParticleBurstPainter extends CustomPainter {
  final double progress;
  final List<SparkParticle> particles;
  final Paint _sparkPaint = Paint()..style = PaintingStyle.fill;

  SparkParticleBurstPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final currentDist = p.maxDistance * progress;
      final x = center.dx + cos(p.angle) * currentDist;
      final y = center.dy + sin(p.angle) * currentDist;

      // Soft fade near outer boundaries
      final alpha = ((1.0 - progress) * 0.95).clamp(0.0, 1.0);
      _sparkPaint.color = p.color.withValues(alpha: alpha);

      // Micro spark dot
      canvas.drawCircle(Offset(x, y), p.radius, _sparkPaint);

      // Soft glow aura on larger sparks
      if (p.radius > 2.0 && progress < 0.8) {
        _sparkPaint.color = p.color.withValues(alpha: alpha * 0.4);
        canvas.drawCircle(Offset(x, y), p.radius * 2.2, _sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SparkParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Vertical Capsule Thermometer CustomPainter where glowing mercury rises from 0 to current score
class AnimatedThermometerPainter extends CustomPainter {
  final double scoreProgress; // 0.0 to 1.0 representing current score percentage
  final int targetScore;      // e.g. 88

  AnimatedThermometerPainter({
    required this.scoreProgress,
    required this.targetScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final radius = width / 2;

    final capsuleRect = Rect.fromLTWH(0, 0, width, height);
    final capsuleRRect = RRect.fromRectAndRadius(capsuleRect, Radius.circular(radius));

    // 1. Thermometer Glass Tube Background
    final tubePaint = Paint()
      ..color = const Color(0x33080A0F)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(capsuleRRect, tubePaint);

    // 2. Glass Tube Border
    final borderPaint = Paint()
      ..color = const Color(0x4DFF4D67)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(capsuleRRect, borderPaint);

    // 3. Tick Marks along capsule (25%, 50%, 75%, 100%)
    final tickPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.0;
    for (int pct in [25, 50, 75]) {
      final y = height - (height * (pct / 100.0));
      canvas.drawLine(Offset(width - 5, y), Offset(width - 1, y), tickPaint);
    }

    // 80% Ignition Tick Line (Glowing Coral)
    final ignitionY = height - (height * 0.80);
    final ignitionTickPaint = Paint()
      ..color = const Color(0xFFFF4D67)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(width - 7, ignitionY), Offset(width, ignitionY), ignitionTickPaint);

    // 4. Rising Glowing Mercury
    final mercuryHeight = (height * scoreProgress).clamp(radius * 2, height);
    final mercuryTop = height - mercuryHeight;
    final mercuryRect = Rect.fromLTWH(0, mercuryTop, width, mercuryHeight);
    final mercuryRRect = RRect.fromRectAndRadius(mercuryRect, Radius.circular(radius));

    // Gradient Mercury Liquid: Electric Iris -> Sunset Coral -> Golden Sparkle
    final mercuryGradient = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0xFF7928CA), // Electric Iris at base
        Color(0xFFFF4D67), // Sunset Coral
        Color(0xFFF59E0B), // Golden Sparkle at top
      ],
    );

    final mercuryPaint = Paint()
      ..shader = mercuryGradient.createShader(mercuryRect)
      ..style = PaintingStyle.fill;

    // Clip within capsule
    canvas.save();
    canvas.clipRRect(capsuleRRect);
    canvas.drawRRect(mercuryRRect, mercuryPaint);

    // Meniscus Glow at top of liquid
    final meniscusPaint = Paint()
      ..color = const Color(0xFFFFFBEB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, mercuryTop + radius * 0.6), radius * 0.45, meniscusPaint);

    canvas.restore();

    // Outer glow aura around thermometer when hot
    final glowPaint = Paint()
      ..color = const Color(0x33FF4D67)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(capsuleRRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant AnimatedThermometerPainter oldDelegate) {
    return oldDelegate.scoreProgress != scoreProgress ||
        oldDelegate.targetScore != targetScore;
  }
}

/// The Synchronized "80% Spark Ignition" Popup Modal
class VibeSparkIgnitionModal extends StatefulWidget {
  final int score;
  final String matchName;
  final Function(String invitationMessage)? onDatePlanSelected;

  const VibeSparkIgnitionModal({
    super.key,
    required this.score,
    required this.matchName,
    this.onDatePlanSelected,
  });

  /// Displays the synchronized 80% ignition overlay with heavy haptic feedback
  static Future<void> show(
    BuildContext context, {
    required int score,
    required String matchName,
    Function(String invitationMessage)? onDatePlanSelected,
  }) async {
    HapticFeedback.heavyImpact();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VibeSparkIgnition',
      barrierColor: const Color(0xCC000000), // Dimmed dark backdrop
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, anim1, anim2) {
        return VibeSparkIgnitionModal(
          score: score,
          matchName: matchName,
          onDatePlanSelected: onDatePlanSelected,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<VibeSparkIgnitionModal> createState() => _VibeSparkIgnitionModalState();
}

class _VibeSparkIgnitionModalState extends State<VibeSparkIgnitionModal>
    with TickerProviderStateMixin {
  late AnimationController _burstController;
  late AnimationController _mercuryController;
  late Animation<double> _mercuryAnimation;
  late List<SparkParticle> _particles;

  @override
  void initState() {
    super.initState();

    // Particle Burst Animation
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    // Generate random micro-spark particles
    final rand = Random(42);
    final colors = [
      const Color(0xFFFF4D67), // Sunset Coral
      const Color(0xFFF59E0B), // Golden Sparkle
      const Color(0xFF7928CA), // Electric Iris
      const Color(0xFFFFFFFF), // Frost White
    ];

    _particles = List.generate(48, (i) {
      final angle = rand.nextDouble() * 2 * pi;
      final speed = 0.6 + rand.nextDouble() * 0.9;
      final radius = 1.2 + rand.nextDouble() * 2.2;
      final color = colors[rand.nextInt(colors.length)];
      final maxDistance = 70.0 + rand.nextDouble() * 110.0;
      return SparkParticle(
        angle: angle,
        speed: speed,
        radius: radius,
        color: color,
        maxDistance: maxDistance,
      );
    });

    // Mercury Rising dynamic animation (from 0 to score / 100)
    _mercuryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final targetFrac = (widget.score / 100.0).clamp(0.0, 1.0);
    _mercuryAnimation = Tween<double>(
      begin: 0.0,
      end: targetFrac,
    ).animate(
      CurvedAnimation(
        parent: _mercuryController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start mercury rise after slight burst impact
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _mercuryController.forward();
    });
  }

  @override
  void dispose() {
    _burstController.dispose();
    _mercuryController.dispose();
    super.dispose();
  }

  void _onPlanDatePressed() {
    Navigator.of(context).pop(); // Dismiss ignition modal
    DateConciergeSheet.show(
      context,
      matchName: widget.matchName,
      onInviteSent: widget.onDatePlanSelected,
    );
  }

  void _onKeepVibeingPressed() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 380),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Ambient Canvas Particle Burst
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _burstController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: SparkParticleBurstPainter(
                        progress: _burstController.value,
                        particles: _particles,
                      ),
                    );
                  },
                ),
              ),

              // Frosted Obsidian Modal Card
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                    decoration: BoxDecoration(
                      color: const Color(0xE6080A0F), // Frosted Obsidian, 90% opacity
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFFF4D67), // 1.5px solid #FF4D67
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66FF4D67),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated Vertical Capsule Thermometer Graphic
                        SizedBox(
                          height: 140,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              // Capsule Thermometer Tube
                              Positioned(
                                bottom: 0,
                                child: AnimatedBuilder(
                                  animation: _mercuryAnimation,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      size: const Size(28, 110),
                                      painter: AnimatedThermometerPainter(
                                        scoreProgress: _mercuryAnimation.value,
                                        targetScore: widget.score,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Glowing Temperature Head with Flame/Heart Spark Icon
                              Positioned(
                                top: 0,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFF4D67), Color(0xFFF59E0B)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x80FF4D67),
                                        blurRadius: 18,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Animated Current Score Badge
                        AnimatedBuilder(
                          animation: _mercuryAnimation,
                          builder: (context, _) {
                            final displayVal =
                                (_mercuryAnimation.value * 100).round();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF4D67),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0x66FF4D67),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$displayVal% VIBE RESONANCE',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Title
                        const Text(
                          '🔥 Resonance Ignited!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        const Text(
                          'Your conversation wavelength is in the top 5%. Take it offline? The vibe wavelength is ready for real life.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Primary Glowing Button: "Send Date Invite ✨"
                        GestureDetector(
                          onTap: _onPlanDatePressed,
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D67), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x80FF4D67),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Send Date Invite ✨',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Secondary Minimal Button: "Keep Vibeing"
                        GestureDetector(
                          onTap: _onKeepVibeingPressed,
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0x0FFFFFFF),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0x2EFFFFFF),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'Keep Vibeing',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
