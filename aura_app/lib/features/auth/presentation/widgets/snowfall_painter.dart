import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Individual snowflake particle model with realistic winter breeze physics
/// and subtle tactile touch repulsion.
class Snowflake {
  double x;
  double y;
  double radius;
  double opacity;
  Color color;
  double speed; // Vertical downward velocity (20px to 45px per second)
  double swayFrequency; // Horizontal sinusoidal oscillation rate
  double swayAmplitude; // Horizontal sway magnitude (pixels)
  double swayPhase; // Initial random phase offset
  double touchRepelX; // Velocity induced by user touch repulsion
  double touchRepelY;

  Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.color,
    required this.speed,
    required this.swayFrequency,
    required this.swayAmplitude,
    required this.swayPhase,
    this.touchRepelX = 0.0,
    this.touchRepelY = 0.0,
  });

  /// Factory to spawn a randomized snowflake particle
  factory Snowflake.random(Size bounds, math.Random rng, {bool spawnAtTop = false}) {
    // Varied radii: 1.5px to 3.5px
    final radius = 1.5 + rng.nextDouble() * 2.0;

    // Randomized opacity: 0.25 to 0.75
    final opacity = 0.25 + rng.nextDouble() * 0.50;

    // Colors: Crisp Ice White (#FFFFFF) with subtle hint of Cyan Glow (#E0F7FA)
    // and soft Sunset Coral tint (#FFE5EC) to match ambient lighting
    final colorType = rng.nextInt(10);
    Color color;
    if (colorType < 6) {
      color = const Color(0xFFFFFFFF); // 60% Crisp Ice White
    } else if (colorType < 8) {
      color = const Color(0xFFE0F7FA); // 20% Ambient Cyan Glow hint
    } else {
      color = const Color(0xFFFFE5EC); // 20% Soft Sunset Coral ambient tint
    }

    // Vertical downward speed: 20px to 45px per second
    final speed = 20.0 + rng.nextDouble() * 25.0;

    // Gentle sinusoidal horizontal sway parameters
    final swayFrequency = 0.8 + rng.nextDouble() * 1.4;
    final swayAmplitude = 12.0 + rng.nextDouble() * 18.0;
    final swayPhase = rng.nextDouble() * math.pi * 2;

    final width = bounds.width > 0 ? bounds.width : 400.0;
    final height = bounds.height > 0 ? bounds.height : 800.0;

    final x = rng.nextDouble() * width;
    final y = spawnAtTop
        ? -10.0 - (rng.nextDouble() * 20.0)
        : rng.nextDouble() * height;

    return Snowflake(
      x: x,
      y: y,
      radius: radius,
      opacity: opacity,
      color: color,
      speed: speed,
      swayFrequency: swayFrequency,
      swayAmplitude: swayAmplitude,
      swayPhase: swayPhase,
    );
  }

  /// Updates snowflake position with vertical drift, sinusoidal sway,
  /// tactile touch repulsion, and smooth bottom-to-top recycling.
  void update(
    double dt,
    double totalTime,
    Size bounds,
    Offset? touchPoint,
    math.Random rng,
  ) {
    // 1. Vertical falling drift (20px to 45px per second)
    y += speed * dt;

    // 2. Tactile touch repulsion (gentle repulsion within 85px radius)
    if (touchPoint != null) {
      final dx = x - touchPoint.dx;
      final dy = y - touchPoint.dy;
      final distSq = dx * dx + dy * dy;
      const repelRadiusSq = 85.0 * 85.0; // 85px radius

      if (distSq < repelRadiusSq && distSq > 0.001) {
        final dist = math.sqrt(distSq);
        final factor = 1.0 - (dist / 85.0);
        const repelForce = 50.0; // Gentle velocity impulse
        final angle = math.atan2(dy, dx);
        touchRepelX += math.cos(angle) * (factor * repelForce);
        touchRepelY += math.sin(angle) * (factor * repelForce);
      }
    }

    // 3. Apply touch repulsion velocity with smooth exponential damping
    x += touchRepelX * dt;
    y += touchRepelY * dt;
    touchRepelX *= 0.88; // 12% decay per tick
    touchRepelY *= 0.88;

    // Screen horizontal wrapping if pushed far
    if (bounds.width > 0) {
      if (x < -20) x = bounds.width + 10;
      if (x > bounds.width + 20) x = -10;
    }

    // 4. Smooth recycling when flake passes below screen
    final bottomLimit = bounds.height > 0 ? bounds.height + 15 : 900.0;
    if (y > bottomLimit) {
      y = -10.0 - (rng.nextDouble() * 10.0);
      x = rng.nextDouble() * (bounds.width > 0 ? bounds.width : 400.0);
      speed = 20.0 + rng.nextDouble() * 25.0;
      radius = 1.5 + rng.nextDouble() * 2.0;
      opacity = 0.25 + rng.nextDouble() * 0.50;
      touchRepelX = 0.0;
      touchRepelY = 0.0;
    }
  }

  /// Computes rendered X coordinate factoring in sinusoidal sway
  double currentRenderX(double totalTime) {
    final sway = math.sin(totalTime * swayFrequency + swayPhase) * swayAmplitude;
    return x + sway;
  }
}

/// High-performance, zero-allocation 60 FPS CustomPainter for falling snow
/// and glowing micro-crystal particles.
class SnowfallPainter extends CustomPainter {
  final List<Snowflake> snowflakes;
  final double? totalTime;
  final double Function()? getTime;

  // Pre-allocated reusable paint objects to guarantee zero GC pressure at 60 FPS
  static final Paint _particlePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  static final Paint _haloPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  final Listenable? repaintListenable;

  SnowfallPainter({
    required this.snowflakes,
    this.totalTime,
    this.getTime,
    this.repaintListenable,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    if (snowflakes.isEmpty) return;
    final time = getTime != null ? getTime!() : (totalTime ?? 0.0);

    for (int i = 0; i < snowflakes.length; i++) {
      final flake = snowflakes[i];
      final renderX = flake.currentRenderX(time);
      final center = Offset(renderX, flake.y);

      // 1. Draw glowing outer halo for larger particles (radii >= 2.4px)
      if (flake.radius >= 2.4) {
        _haloPaint.color = flake.color.withValues(
          alpha: (flake.opacity * 0.28).clamp(0.05, 0.40),
        );
        canvas.drawCircle(center, flake.radius * 2.2, _haloPaint);
      }

      // 2. Draw core micro-crystal snowflake
      _particlePaint.color = flake.color.withValues(alpha: flake.opacity);
      canvas.drawCircle(center, flake.radius, _particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowfallPainter oldDelegate) {
    if (repaintListenable != null) return false;
    return oldDelegate.totalTime != totalTime ||
        oldDelegate.snowflakes != snowflakes;
  }
}

/// Turnkey, battery-efficient Snowfall Canvas widget for landing/welcome screens.
/// Spawns 40 to 50 soft snow particles with varied radii, colors, and subtle touch repulsion.
class SnowfallCanvas extends StatefulWidget {
  final Widget? child;
  final int particleCount;
  final Offset? externalTouchPoint;
  final ValueListenable<Offset?>? touchNotifier;

  const SnowfallCanvas({
    super.key,
    this.child,
    this.particleCount = 48, // 40 to 50 soft snow particles
    this.externalTouchPoint,
    this.touchNotifier,
  });

  @override
  State<SnowfallCanvas> createState() => _SnowfallCanvasState();
}

class _SnowfallCanvasState extends State<SnowfallCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<Snowflake> _snowflakes = [];
  final math.Random _rng = math.Random(42);
  Offset? _internalTouchPoint;
  Size _lastSize = Size.zero;
  double _elapsedTime = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    if (_lastSize.width <= 0 || _lastSize.height <= 0) return;

    const dt = 0.016; // 60 FPS timestep (~16ms)
    _elapsedTime += dt;

    final activeTouch = widget.touchNotifier?.value ??
        widget.externalTouchPoint ??
        _internalTouchPoint;

    for (int i = 0; i < _snowflakes.length; i++) {
      _snowflakes[i].update(dt, _elapsedTime, _lastSize, activeTouch, _rng);
    }
  }

  void _ensureParticlesSpawned(Size size) {
    if (_snowflakes.length == widget.particleCount) return;

    _snowflakes.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _snowflakes.add(Snowflake.random(size, _rng, spawnAtTop: false));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _lastSize && size.width > 0 && size.height > 0) {
          _lastSize = size;
          _ensureParticlesSpawned(size);
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _internalTouchPoint = e.localPosition,
          onPointerMove: (e) => _internalTouchPoint = e.localPosition,
          onPointerUp: (_) => _internalTouchPoint = null,
          onPointerCancel: (_) => _internalTouchPoint = null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: SnowfallPainter(
                    snowflakes: _snowflakes,
                    getTime: () => _elapsedTime,
                    repaintListenable: _ticker,
                  ),
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

/// Convenience alias
typedef SnowfallPainterWidget = SnowfallCanvas;
