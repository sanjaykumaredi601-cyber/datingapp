import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/atmospheric_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. SNOW PARTICLE ENGINE (80+ Crisp Pure White Snowflakes & Layered Depths)
// ═════════════════════════════════════════════════════════════════════════════

enum SnowDepth { background, mid, front }

class SnowFlake {
  double x;
  double y;
  final SnowDepth depth;
  double radius;
  double opacity;
  double speed;
  double swayFrequency;
  double swayAmplitude;
  double swayPhase;
  double touchRepelX;
  double touchRepelY;

  SnowFlake({
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

  factory SnowFlake.random(Size bounds, math.Random rng, {bool spawnAtTop = false}) {
    final roll = rng.nextDouble();
    SnowDepth depth;
    double radius;
    double speed;
    double opacity;
    double swayFreq;
    double swayAmp;

    // 3 distinct z-depth layers with opacities strictly varied between 0.35 and 0.85
    // and gentle horizontal sinusoidal wind oscillation
    if (roll < 0.25) {
      depth = SnowDepth.front;
      radius = 3.5 + rng.nextDouble() * 1.5; // 3.5px - 5.0px (larger foreground flakes)
      speed = 32.0 + rng.nextDouble() * 16.0; // 32 - 48 px/s
      opacity = 0.65 + rng.nextDouble() * 0.20; // 0.65 - 0.85
      swayFreq = 0.85 + rng.nextDouble() * 0.55; // gentle wind frequency
      swayAmp = 18.0 + rng.nextDouble() * 14.0; // gentle wind sway amplitude
    } else if (roll < 0.70) {
      depth = SnowDepth.mid;
      radius = 2.0 + rng.nextDouble() * 1.0; // 2.0px - 3.0px
      speed = 20.0 + rng.nextDouble() * 10.0; // 20 - 30 px/s
      opacity = 0.48 + rng.nextDouble() * 0.22; // 0.48 - 0.70
      swayFreq = 0.70 + rng.nextDouble() * 0.50;
      swayAmp = 12.0 + rng.nextDouble() * 8.0;
    } else {
      depth = SnowDepth.background;
      radius = 1.0 + rng.nextDouble() * 0.7; // 1.0px - 1.7px
      speed = 12.0 + rng.nextDouble() * 8.0; // 12 - 20 px/s
      opacity = 0.35 + rng.nextDouble() * 0.15; // 0.35 - 0.50
      swayFreq = 0.55 + rng.nextDouble() * 0.45;
      swayAmp = 6.0 + rng.nextDouble() * 6.0;
    }

    final width = bounds.width > 0 ? bounds.width : 400.0;
    final height = bounds.height > 0 ? bounds.height : 800.0;
    final x = rng.nextDouble() * width;
    final y = spawnAtTop ? -10.0 - rng.nextDouble() * 20.0 : rng.nextDouble() * height;

    return SnowFlake(
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

  void update(double dt, double totalTime, Size bounds, Offset? touch, math.Random rng) {
    y += speed * dt;

    if (touch != null) {
      final dx = x - touch.dx;
      final dy = y - touch.dy;
      final distSq = dx * dx + dy * dy;
      const repelRadSq = 85.0 * 85.0;
      if (distSq < repelRadSq && distSq > 0.001) {
        final dist = math.sqrt(distSq);
        final factor = 1.0 - (dist / 85.0);
        const force = 52.0;
        final angle = math.atan2(dy, dx);
        touchRepelX += math.cos(angle) * (factor * force);
        touchRepelY += math.sin(angle) * (factor * force);
      }
    }

    x += touchRepelX * dt;
    y += touchRepelY * dt;
    touchRepelX *= 0.88;
    touchRepelY *= 0.88;

    if (bounds.width > 0) {
      if (x < -20) x = bounds.width + 10;
      if (x > bounds.width + 20) x = -10;
    }

    final bottom = bounds.height > 0 ? bounds.height + 15 : 900.0;
    if (y > bottom) {
      y = -10.0 - rng.nextDouble() * 15.0;
      x = rng.nextDouble() * (bounds.width > 0 ? bounds.width : 400.0);
      touchRepelX = 0.0;
      touchRepelY = 0.0;
    }
  }

  double currentRenderX(double time) {
    return x + math.sin(time * swayFrequency + swayPhase) * swayAmplitude;
  }
}

class SnowCanvasPainter extends CustomPainter {
  final List<SnowFlake> flakes;
  final double time;
  final Listenable? repaintListenable;

  // Soft depth-of-field blur on larger foreground snowflakes
  static final Paint _blurredForegroundPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

  // Soft subtle bloom halo around larger flakes
  static final Paint _haloPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

  // Organic core paint with anti-aliasing
  static final Paint _corePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  SnowCanvasPainter({
    required this.flakes,
    required this.time,
    this.repaintListenable,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    if (flakes.isEmpty) return;

    for (int i = 0; i < flakes.length; i++) {
      final f = flakes[i];
      // Wind drift: gentle horizontal sinusoidal oscillation
      final renderX = f.currentRenderX(time);
      final center = Offset(renderX, f.y);

      if (f.depth == SnowDepth.front) {
        // Soft outer ambient glow
        _haloPaint.color = const Color(0xFFE0F7FA).withValues(alpha: (f.opacity * 0.35).clamp(0.12, 0.40));
        canvas.drawCircle(center, f.radius * 2.2, _haloPaint);

        // Organic blurred snowflake with realistic depth-of-field
        _blurredForegroundPaint.color = Colors.white.withValues(alpha: f.opacity);
        canvas.drawCircle(center, f.radius, _blurredForegroundPaint);

        // Subtle soft crystalline nucleus
        _corePaint.color = Colors.white.withValues(alpha: (f.opacity * 0.90).clamp(0.40, 0.85));
        canvas.drawCircle(center, f.radius * 0.55, _corePaint);
      } else if (f.depth == SnowDepth.mid) {
        // Mid-depth gentle crystalline flake
        _corePaint.color = const Color(0xFFF0FDFE).withValues(alpha: f.opacity);
        canvas.drawCircle(center, f.radius, _corePaint);
      } else {
        // Distant background crisp micro-drift dot
        _corePaint.color = Colors.white.withValues(alpha: f.opacity);
        canvas.drawCircle(center, f.radius, _corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SnowCanvasPainter oldDelegate) {
    if (repaintListenable != null) return false;
    return oldDelegate.time != time || oldDelegate.flakes != flakes;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. RAIN / STORM PARTICLE ENGINE (High Speed 75° Neon Rain & Ripple Splashes)
// ═════════════════════════════════════════════════════════════════════════════

class RainDrop {
  double x;
  double y;
  double length;
  double speed;
  double opacity;
  double width;

  RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
    required this.width,
  });

  factory RainDrop.random(Size bounds, math.Random rng, {bool spawnAtTop = false}) {
    final width = bounds.width > 0 ? bounds.width : 400.0;
    final height = bounds.height > 0 ? bounds.height : 800.0;

    return RainDrop(
      x: -50.0 + rng.nextDouble() * (width + 100.0),
      y: spawnAtTop ? -30.0 - rng.nextDouble() * 40.0 : rng.nextDouble() * height,
      length: 14.0 + rng.nextDouble() * 14.0, // 14px to 28px streak
      speed: 400.0 + rng.nextDouble() * 180.0, // 400 - 580 px/s
      opacity: 0.40 + rng.nextDouble() * 0.45, // 0.40 - 0.85
      width: 1.1 + rng.nextDouble() * 0.8,
    );
  }

  void update(double dt, Size bounds, math.Random rng, List<RippleSplash> splashes) {
    // 75-degree angle: moving downwards and slightly to the right
    const angleRad = 75.0 * math.pi / 180.0;
    x += math.cos(angleRad) * speed * dt;
    y += math.sin(angleRad) * speed * dt;

    final bottomSheetLimit = bounds.height > 0 ? bounds.height * 0.82 : 650.0;
    if (y > bottomSheetLimit && rng.nextDouble() < 0.15 && splashes.length < 24) {
      splashes.add(RippleSplash(x: x, y: y));
    }

    final bottom = bounds.height > 0 ? bounds.height + 30 : 900.0;
    if (y > bottom) {
      y = -20.0 - rng.nextDouble() * 30.0;
      x = -30.0 + rng.nextDouble() * (bounds.width > 0 ? bounds.width + 60.0 : 460.0);
    }
  }
}

class RippleSplash {
  double x;
  double y;
  double radius;
  double opacity;

  RippleSplash({
    required this.x,
    required this.y,
    this.radius = 1.0,
    this.opacity = 0.65,
  });

  bool update(double dt) {
    radius += 24.0 * dt; // Expands outward
    opacity -= 1.8 * dt; // Fades out rapidly
    return opacity > 0.0;
  }
}

class RainCanvasPainter extends CustomPainter {
  final List<RainDrop> rainDrops;
  final List<RippleSplash> splashes;
  final Listenable? repaintListenable;

  static final Paint _streakPaint = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _splashPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;

  RainCanvasPainter({
    required this.rainDrops,
    required this.splashes,
    this.repaintListenable,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    if (rainDrops.isEmpty) return;

    const angleRad = 75.0 * math.pi / 180.0;
    final dx = math.cos(angleRad);
    final dy = math.sin(angleRad);

    // 1. Neon rain streaks
    for (int i = 0; i < rainDrops.length; i++) {
      final drop = rainDrops[i];
      _streakPaint.strokeWidth = drop.width;
      // Electric Neon Cyan tinted streaks
      _streakPaint.color = const Color(0xFF00F2FE).withValues(alpha: drop.opacity);

      final start = Offset(drop.x, drop.y);
      final end = Offset(drop.x + dx * drop.length, drop.y + dy * drop.length);
      canvas.drawLine(start, end, _streakPaint);
    }

    // 2. Micro ripple splashes
    for (int i = 0; i < splashes.length; i++) {
      final s = splashes[i];
      _splashPaint.color = const Color(0xFF00F2FE).withValues(alpha: s.opacity.clamp(0.0, 1.0));
      // Oval perspective splash
      final rect = Rect.fromCenter(center: Offset(s.x, s.y), width: s.radius * 2.2, height: s.radius * 0.9);
      canvas.drawOval(rect, _splashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RainCanvasPainter oldDelegate) {
    return repaintListenable == null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. AUTUMN FOLIAGE ENGINE (Tumbling Maple & Oak Leaves Drifting in Wind)
// ═════════════════════════════════════════════════════════════════════════════

class AutumnLeaf {
  double x;
  double y;
  double size;
  double rotation;
  double rotationSpeed;
  double tumblePhase;
  double tumbleSpeed;
  double speedX;
  double speedY;
  Color color;
  final bool isMaple;

  AutumnLeaf({
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.tumblePhase,
    required this.tumbleSpeed,
    required this.speedX,
    required this.speedY,
    required this.color,
    required this.isMaple,
  });

  factory AutumnLeaf.random(Size bounds, math.Random rng, {bool spawnAtTop = false}) {
    final width = bounds.width > 0 ? bounds.width : 400.0;
    final height = bounds.height > 0 ? bounds.height : 800.0;

    // Palette: Amber Gold, Sunset Rust, Maple Red, Golden Bronze
    const colors = [
      Color(0xFFF59E0B), // Warm Amber Gold
      Color(0xFFEA580C), // Sunset Rust
      Color(0xFFDC2626), // Maple Crimson
      Color(0xFFD97706), // Golden Bronze
      Color(0xFFB45309), // Burnished Amber
    ];

    return AutumnLeaf(
      x: -30.0 + rng.nextDouble() * (width + 60.0),
      y: spawnAtTop ? -20.0 - rng.nextDouble() * 30.0 : rng.nextDouble() * height,
      size: 10.0 + rng.nextDouble() * 8.0,
      rotation: rng.nextDouble() * math.pi * 2,
      rotationSpeed: 0.8 + rng.nextDouble() * 1.4,
      tumblePhase: rng.nextDouble() * math.pi * 2,
      tumbleSpeed: 1.2 + rng.nextDouble() * 1.5,
      speedX: 25.0 + rng.nextDouble() * 25.0, // Wind blowing rightward
      speedY: 35.0 + rng.nextDouble() * 25.0, // Falling downward
      color: colors[rng.nextInt(colors.length)],
      isMaple: rng.nextBool(),
    );
  }

  void update(double dt, double time, Size bounds, math.Random rng) {
    final sway = math.sin(time * 1.5 + tumblePhase) * 14.0;
    x += (speedX + sway) * dt;
    y += speedY * dt;
    rotation += rotationSpeed * dt;
    tumblePhase += tumbleSpeed * dt;

    final bottom = bounds.height > 0 ? bounds.height + 25 : 900.0;
    if (y > bottom || (bounds.width > 0 && x > bounds.width + 30)) {
      y = -20.0 - rng.nextDouble() * 20.0;
      x = -30.0 + rng.nextDouble() * (bounds.width > 0 ? bounds.width * 0.8 : 320.0);
    }
  }
}

class AutumnFoliagePainter extends CustomPainter {
  final List<AutumnLeaf> leaves;
  final double time;
  final Listenable? repaintListenable;

  static final Paint _leafPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  AutumnFoliagePainter({
    required this.leaves,
    required this.time,
    this.repaintListenable,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    if (leaves.isEmpty) return;

    for (int i = 0; i < leaves.length; i++) {
      final leaf = leaves[i];
      final tumble = math.cos(leaf.tumblePhase); // 3D flip effect

      canvas.save();
      canvas.translate(leaf.x, leaf.y);
      canvas.rotate(leaf.rotation);
      canvas.scale(1.0, tumble.abs().clamp(0.2, 1.0));

      _leafPaint.color = leaf.color.withValues(alpha: 0.85);

      if (leaf.isMaple) {
        // Star-like 5-pointed stylized maple leaf
        final path = Path();
        final s = leaf.size * 0.5;
        path.moveTo(0, -s);
        path.lineTo(s * 0.35, -s * 0.3);
        path.lineTo(s, -s * 0.1);
        path.lineTo(s * 0.45, s * 0.35);
        path.lineTo(s * 0.6, s);
        path.lineTo(0, s * 0.5);
        path.lineTo(-s * 0.6, s);
        path.lineTo(-s * 0.45, s * 0.35);
        path.lineTo(-s, -s * 0.1);
        path.lineTo(-s * 0.35, -s * 0.3);
        path.close();
        canvas.drawPath(path, _leafPaint);
      } else {
        // Smooth pointed oval leaf
        final oval = Rect.fromCenter(center: Offset.zero, width: leaf.size * 0.6, height: leaf.size * 1.2);
        canvas.drawOval(oval, _leafPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant AutumnFoliagePainter oldDelegate) {
    return repaintListenable == null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. SAKURA PETALS ENGINE (Organic Pink Petals Gently Floating Downward)
// ═════════════════════════════════════════════════════════════════════════════

class SakuraPetal {
  double x;
  double y;
  double size;
  double rotation;
  double rotationSpeed;
  double swayPhase;
  double speed;
  Color color;

  SakuraPetal({
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.swayPhase,
    required this.speed,
    required this.color,
  });

  factory SakuraPetal.random(Size bounds, math.Random rng, {bool spawnAtTop = false}) {
    final width = bounds.width > 0 ? bounds.width : 400.0;
    final height = bounds.height > 0 ? bounds.height : 800.0;

    const colors = [
      Color(0xFFFFB3C1), // Sakura Blossom Pink
      Color(0xFFFFCCD5), // Soft Pink
      Color(0xFFFF6B8B), // Neon Rose
      Color(0xFFFFF0F3), // Rose White
    ];

    return SakuraPetal(
      x: rng.nextDouble() * width,
      y: spawnAtTop ? -15.0 - rng.nextDouble() * 25.0 : rng.nextDouble() * height,
      size: 9.0 + rng.nextDouble() * 6.0,
      rotation: rng.nextDouble() * math.pi * 2,
      rotationSpeed: 0.6 + rng.nextDouble() * 1.0,
      swayPhase: rng.nextDouble() * math.pi * 2,
      speed: 22.0 + rng.nextDouble() * 18.0, // 22 - 40 px/s gentle drift
      color: colors[rng.nextInt(colors.length)],
    );
  }

  void update(double dt, double time, Size bounds, math.Random rng) {
    final sway = math.sin(time * 1.2 + swayPhase) * 16.0;
    x += sway * dt;
    y += speed * dt;
    rotation += rotationSpeed * dt;

    final bottom = bounds.height > 0 ? bounds.height + 20 : 900.0;
    if (y > bottom) {
      y = -15.0 - rng.nextDouble() * 20.0;
      x = rng.nextDouble() * (bounds.width > 0 ? bounds.width : 400.0);
    }
  }
}

class SakuraPetalsPainter extends CustomPainter {
  final List<SakuraPetal> petals;
  final double time;
  final Listenable? repaintListenable;

  static final Paint _petalPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  SakuraPetalsPainter({
    required this.petals,
    required this.time,
    this.repaintListenable,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    if (petals.isEmpty) return;

    for (int i = 0; i < petals.length; i++) {
      final p = petals[i];
      final flip = math.sin(time * 1.8 + p.swayPhase);

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.scale(1.0, flip.abs().clamp(0.3, 1.0));

      _petalPaint.color = p.color.withValues(alpha: 0.82);

      // Curved petal shape with subtle top indentation
      final path = Path();
      final s = p.size * 0.5;
      path.moveTo(0, s * 0.9);
      path.quadraticBezierTo(s * 0.8, s * 0.2, s * 0.6, -s * 0.6);
      path.quadraticBezierTo(0, -s * 0.4, -s * 0.6, -s * 0.6);
      path.quadraticBezierTo(-s * 0.8, s * 0.2, 0, s * 0.9);
      path.close();

      canvas.drawPath(path, _petalPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SakuraPetalsPainter oldDelegate) {
    return repaintListenable == null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. UNIFIED ATMOSPHERIC PARTICLE CANVAS (Seamless 800ms Cross-Fade Between Themes)
// ═════════════════════════════════════════════════════════════════════════════

class AtmosphericParticleCanvas extends StatefulWidget {
  final AtmosphericEnvironment environment;
  final ValueListenable<Offset?>? touchNotifier;

  const AtmosphericParticleCanvas({
    super.key,
    required this.environment,
    this.touchNotifier,
  });

  @override
  State<AtmosphericParticleCanvas> createState() => _AtmosphericParticleCanvasState();
}

class _AtmosphericParticleCanvasState extends State<AtmosphericParticleCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final math.Random _rng = math.Random(1337);

  // Particles for each environment
  final List<SnowFlake> _snowFlakes = [];
  final List<RainDrop> _rainDrops = [];
  final List<RippleSplash> _splashes = [];
  final List<AutumnLeaf> _autumnLeaves = [];
  final List<SakuraPetal> _sakuraPetals = [];

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

    const dt = 0.016;
    _elapsedTime += dt;

    final touch = widget.touchNotifier?.value;

    switch (widget.environment) {
      case AtmosphericEnvironment.snow:
        for (int i = 0; i < _snowFlakes.length; i++) {
          _snowFlakes[i].update(dt, _elapsedTime, _lastSize, touch, _rng);
        }
        break;
      case AtmosphericEnvironment.rain:
        // Update rain and splashes
        for (int i = 0; i < _rainDrops.length; i++) {
          _rainDrops[i].update(dt, _lastSize, _rng, _splashes);
        }
        _splashes.removeWhere((s) => !s.update(dt));
        break;
      case AtmosphericEnvironment.autumn:
        for (int i = 0; i < _autumnLeaves.length; i++) {
          _autumnLeaves[i].update(dt, _elapsedTime, _lastSize, _rng);
        }
        break;
      case AtmosphericEnvironment.springDusk:
        for (int i = 0; i < _sakuraPetals.length; i++) {
          _sakuraPetals[i].update(dt, _elapsedTime, _lastSize, _rng);
        }
        break;
    }
  }

  void _ensureParticlesSpawned(Size size) {
    if (_snowFlakes.isEmpty) {
      for (int i = 0; i < 85; i++) {
        _snowFlakes.add(SnowFlake.random(size, _rng));
      }
    }
    if (_rainDrops.isEmpty) {
      for (int i = 0; i < 75; i++) {
        _rainDrops.add(RainDrop.random(size, _rng));
      }
    }
    if (_autumnLeaves.isEmpty) {
      for (int i = 0; i < 35; i++) {
        _autumnLeaves.add(AutumnLeaf.random(size, _rng));
      }
    }
    if (_sakuraPetals.isEmpty) {
      for (int i = 0; i < 42; i++) {
        _sakuraPetals.add(SakuraPetal.random(size, _rng));
      }
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

        CustomPainter activePainter;
        switch (widget.environment) {
          case AtmosphericEnvironment.snow:
            activePainter = SnowCanvasPainter(
              flakes: _snowFlakes,
              time: _elapsedTime,
              repaintListenable: _ticker,
            );
            break;
          case AtmosphericEnvironment.rain:
            activePainter = RainCanvasPainter(
              rainDrops: _rainDrops,
              splashes: _splashes,
              repaintListenable: _ticker,
            );
            break;
          case AtmosphericEnvironment.autumn:
            activePainter = AutumnFoliagePainter(
              leaves: _autumnLeaves,
              time: _elapsedTime,
              repaintListenable: _ticker,
            );
            break;
          case AtmosphericEnvironment.springDusk:
            activePainter = SakuraPetalsPainter(
              petals: _sakuraPetals,
              time: _elapsedTime,
              repaintListenable: _ticker,
            );
            break;
        }

        return RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: CustomPaint(
              key: ValueKey<AtmosphericEnvironment>(widget.environment),
              size: size,
              painter: activePainter,
            ),
          ),
        );
      },
    );
  }
}
