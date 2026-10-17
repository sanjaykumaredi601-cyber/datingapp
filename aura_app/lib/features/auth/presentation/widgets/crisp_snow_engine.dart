import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Depth layers creating a true 3D mountain snowfall experience
enum SnowDepthLayer {
  background, // Tiny crisp crystal dots (1.0 - 1.5px, 12-18 px/s)
  mid,        // Mid-sized drifting flakes (2.0 - 3.0px, 20-30 px/s)
  front,      // Closer fast-falling flakes with soft halo (3.5 - 4.5px, 35-50 px/s)
}

/// Pure-white crisp snowflake model with natural wind sway and depth-based physics
class CrispSnowFlake {
  double x;
  double y;
  final SnowDepthLayer depth;
  double radius;
  double opacity;
  double speed;
  double swayFrequency;
  double swayAmplitude;
  double swayPhase;
  double touchRepelX;
  double touchRepelY;

  CrispSnowFlake({
    required this.x,
    required this.y,
    required this.depth,
    required this.radius,
    required this.opacity,
    required this.speed,
    required this.swayFrequency,
    required this.swayAmplitude,
    required this.swayPhase,
    this.touchRepelX = 0.0,
    this.touchRepelY = 0.0,
  });

  /// Spawns a snowflake with realistic mountain depth layer physics
  factory CrispSnowFlake.random(Size bounds, math.Random rng, {bool spawnAtTop = false}) {
    final layerRoll = rng.nextDouble();
    SnowDepthLayer depth;
    double radius;
    double speed;
    double opacity;
    double swayFreq;
    double swayAmp;

    if (layerRoll < 0.25) {
      // 1. FRONT LAYER (25%): Closer, faster, soft gaussian halo
      depth = SnowDepthLayer.front;
      radius = 3.5 + rng.nextDouble() * 1.0; // 3.5px to 4.5px
      speed = 35.0 + rng.nextDouble() * 15.0; // 35px to 50px/sec
      opacity = 0.70 + rng.nextDouble() * 0.25; // 0.70 to 0.95
      swayFreq = 1.0 + rng.nextDouble() * 0.8;
      swayAmp = 16.0 + rng.nextDouble() * 12.0; // wider sway
    } else if (layerRoll < 0.70) {
      // 2. MID LAYER (45%): Balanced drifting snow
      depth = SnowDepthLayer.mid;
      radius = 2.0 + rng.nextDouble() * 1.0; // 2.0px to 3.0px
      speed = 20.0 + rng.nextDouble() * 10.0; // 20px to 30px/sec
      opacity = 0.55 + rng.nextDouble() * 0.30; // 0.55 to 0.85
      swayFreq = 0.8 + rng.nextDouble() * 0.9;
      swayAmp = 10.0 + rng.nextDouble() * 8.0;
    } else {
      // 3. BACKGROUND DRIFT (30%): Tiny crisp crystal dots
      depth = SnowDepthLayer.background;
      radius = 1.0 + rng.nextDouble() * 0.5; // 1.0px to 1.5px
      speed = 12.0 + rng.nextDouble() * 6.0;  // 12px to 18px/sec
      opacity = 0.40 + rng.nextDouble() * 0.25; // 0.40 to 0.65
      swayFreq = 0.6 + rng.nextDouble() * 0.7;
      swayAmp = 4.0 + rng.nextDouble() * 5.0;  // gentle drift
    }

    final width = bounds.width > 0 ? bounds.width : 400.0;
    final height = bounds.height > 0 ? bounds.height : 800.0;

    final x = rng.nextDouble() * width;
    final y = spawnAtTop
        ? -10.0 - (rng.nextDouble() * 20.0)
        : rng.nextDouble() * height;

    return CrispSnowFlake(
      x: x,
      y: y,
      depth: depth,
      radius: radius,
      opacity: opacity,
      speed: speed,
      swayFrequency: swayFreq,
      swayAmplitude: swayAmp,
      swayPhase: rng.nextDouble() * math.pi * 2,
    );
  }

  /// Updates physics with downward drift, sinusoidal breeze, tactile repulsion, and smooth recycling
  void update(
    double dt,
    double totalTime,
    Size bounds,
    Offset? touchPoint,
    math.Random rng,
  ) {
    // 1. Downward drift
    y += speed * dt;

    // 2. Tactile touch repulsion (gentle repulsion within 85px radius)
    if (touchPoint != null) {
      final dx = x - touchPoint.dx;
      final dy = y - touchPoint.dy;
      final distSq = dx * dx + dy * dy;
      const repelRadiusSq = 85.0 * 85.0;

      if (distSq < repelRadiusSq && distSq > 0.001) {
        final dist = math.sqrt(distSq);
        final factor = 1.0 - (dist / 85.0);
        const repelForce = 52.0;
        final angle = math.atan2(dy, dx);
        touchRepelX += math.cos(angle) * (factor * repelForce);
        touchRepelY += math.sin(angle) * (factor * repelForce);
      }
    }

    // 3. Exponential velocity damping
    x += touchRepelX * dt;
    y += touchRepelY * dt;
    touchRepelX *= 0.88;
    touchRepelY *= 0.88;

    // Screen horizontal boundary wrap
    if (bounds.width > 0) {
      if (x < -20) x = bounds.width + 10;
      if (x > bounds.width + 20) x = -10;
    }

    // 4. Smooth recycling when passing screen bottom
    final bottomLimit = bounds.height > 0 ? bounds.height + 15 : 900.0;
    if (y > bottomLimit) {
      y = -10.0 - (rng.nextDouble() * 15.0);
      x = rng.nextDouble() * (bounds.width > 0 ? bounds.width : 400.0);
      touchRepelX = 0.0;
      touchRepelY = 0.0;
    }
  }

  /// Current render X factored by horizontal natural breeze sway
  double currentRenderX(double totalTime) {
    final sway = math.sin(totalTime * swayFrequency + swayPhase) * swayAmplitude;
    return x + sway;
  }
}

/// Zero-allocation, high-performance 60 FPS CustomPainter for pure-white multi-depth snow
class CrispSnowPainter extends CustomPainter {
  final List<CrispSnowFlake> snowflakes;
  final double? totalTime;
  final double Function()? getTime;
  final Listenable? repaintListenable;

  // Pre-allocated static Paint objects: zero memory allocations inside paint()
  static final Paint _frontHaloPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  static final Paint _snowCorePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  CrispSnowPainter({
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

      // 1. Soft glowing halo for Front Layer flakes (3.5px - 4.5px)
      if (flake.depth == SnowDepthLayer.front) {
        _frontHaloPaint.color = Colors.white.withValues(
          alpha: (flake.opacity * 0.22).clamp(0.05, 0.35),
        );
        canvas.drawCircle(center, flake.radius * 1.8, _frontHaloPaint);
      }

      // 2. Pure White Core Flake (colors: Colors.white, opacity 0.40 to 0.95)
      _snowCorePaint.color = Colors.white.withValues(alpha: flake.opacity);
      canvas.drawCircle(center, flake.radius, _snowCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CrispSnowPainter oldDelegate) {
    if (repaintListenable != null) return false;
    return oldDelegate.totalTime != totalTime ||
        oldDelegate.snowflakes != snowflakes;
  }
}

/// Turnkey, battery-efficient Crisp Snow Canvas engine widget.
/// Spawns 65 to 80 pure-white snowflakes across 3 distinct depth layers.
class CrispSnowCanvas extends StatefulWidget {
  final Widget? child;
  final int particleCount;
  final ValueListenable<Offset?>? touchNotifier;

  const CrispSnowCanvas({
    super.key,
    this.child,
    this.particleCount = 72, // 65 to 80 pure-white snowflakes
    this.touchNotifier,
  });

  @override
  State<CrispSnowCanvas> createState() => _CrispSnowCanvasState();
}

class _CrispSnowCanvasState extends State<CrispSnowCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<CrispSnowFlake> _snowflakes = [];
  final math.Random _rng = math.Random(1337);
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

    const dt = 0.016; // 60 FPS timestep
    _elapsedTime += dt;

    final activeTouch = widget.touchNotifier?.value ?? _internalTouchPoint;

    for (int i = 0; i < _snowflakes.length; i++) {
      _snowflakes[i].update(dt, _elapsedTime, _lastSize, activeTouch, _rng);
    }
  }

  void _ensureParticlesSpawned(Size size) {
    if (_snowflakes.length == widget.particleCount) return;

    _snowflakes.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _snowflakes.add(CrispSnowFlake.random(size, _rng, spawnAtTop: false));
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
                  painter: CrispSnowPainter(
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
