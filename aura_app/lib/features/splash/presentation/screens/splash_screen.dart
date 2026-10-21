import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../main.dart';

/// FindAura Animated Splash Screen
///
/// Features:
/// - Solid sky-blue background (#7FA6C4)
/// - Centered solid white 'FA' Monogram Logo
/// - Clean, modern white sans-serif 'FindAura' brand typography
/// - Brand subtitle: "Discover your vibe. Find your aura."
/// - Staggered fade-in animation: 'FA' monogram fades in first,
///   followed by 'FindAura' text and tagline.
class SplashScreen extends StatefulWidget {
  final Widget? nextScreen;
  final Duration animationDuration;
  final Duration totalDisplayDuration;
  final bool autoNavigate;
  final VoidCallback? onAnimationComplete;

  const SplashScreen({
    super.key,
    this.nextScreen,
    this.animationDuration = const Duration(milliseconds: 1400),
    this.totalDisplayDuration = const Duration(milliseconds: 2200),
    this.autoNavigate = true,
    this.onAnimationComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _faFade;
  late final Animation<double> _faScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // 1. FA Monogram fades in first: 0% -> 48%
    _faFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.48, curve: Curves.easeOut),
    );

    _faScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // 2. 'FindAura' brand text fades in second: 42% -> 80%
    _textFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.42, 0.80, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.42, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Subtitle / Tagline fades in smoothly: 60% -> 100%
    _taglineFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
    _animController.forward();

    if (widget.autoNavigate) {
      _navigationTimer = Timer(widget.totalDisplayDuration, _navigateToNext);
    }
  }

  void _navigateToNext() {
    if (!mounted) return;
    final destination = widget.nextScreen ?? const AuthGate();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Official FindAura sky-blue branding color: #7FA6C4
    const skyBlue = Color(0xFF7FA6C4);

    return Scaffold(
      backgroundColor: skyBlue,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.autoNavigate ? _navigateToNext : null,
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. FA Monogram Logo with first fade-in & subtle scale
                ScaleTransition(
                  scale: _faScale,
                  child: FadeTransition(
                    opacity: _faFade,
                    child: const FaMonogramWidget(
                      key: Key('splash_fa_monogram'),
                      width: 140,
                      height: 98,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. 'FindAura' Text with sequential fade-in & soft upward slide
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: const Text(
                      AppConstants.appName,
                      key: Key('splash_findaura_text'),
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Tagline: "Discover your vibe. Find your aura."
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    AppConstants.appTagline,
                    key: const Key('splash_tagline_text'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.92),
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vector-backed and asset-fallback FA Monogram Logo widget
class FaMonogramWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const FaMonogramWidget({
    super.key,
    this.width = 140,
    this.height = 98,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/icon/findaura_monogram.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        color: color,
        errorBuilder: (context, error, stackTrace) {
          // Robust CustomPaint fallback if asset is loaded in isolated test environments
          return CustomPaint(
            size: Size(width, height),
            painter: FaMonogramPainter(color: color),
          );
        },
      ),
    );
  }
}

/// Mathematically precise CustomPainter drawing the FindAura 'FA' Monogram
class FaMonogramPainter extends CustomPainter {
  final Color color;

  const FaMonogramPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scaleX = size.width / 166.0;
    final scaleY = size.height / 114.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Letter 'F' Path
    final fPath = Path()
      ..moveTo(0, 16)
      ..quadraticBezierTo(0, 0, 16, 0)
      ..lineTo(72, 0)
      ..quadraticBezierTo(82, 0, 82, 10)
      ..quadraticBezierTo(82, 20, 72, 20)
      ..lineTo(22, 20)
      ..lineTo(22, 44)
      ..lineTo(60, 44)
      ..quadraticBezierTo(68, 44, 68, 54)
      ..quadraticBezierTo(68, 64, 60, 64)
      ..lineTo(22, 64)
      ..lineTo(22, 106)
      ..quadraticBezierTo(22, 114, 14, 114)
      ..quadraticBezierTo(0, 114, 0, 106)
      ..close();

    canvas.drawPath(fPath, paint);

    // Letter 'A' with connecting dynamic swoosh Path
    final aPath = Path()
      // Apex of A
      ..moveTo(98, 0)
      ..quadraticBezierTo(106, 0, 112, 10)
      ..lineTo(148, 98)
      ..quadraticBezierTo(156, 114, 142, 114)
      ..quadraticBezierTo(132, 114, 126, 100)
      ..lineTo(118, 80)
      // Dynamic crossbar curve connecting across
      ..quadraticBezierTo(92, 70, 70, 60)
      ..quadraticBezierTo(60, 56, 68, 48)
      ..quadraticBezierTo(78, 52, 94, 56)
      ..lineTo(104, 30)
      ..lineTo(98, 12)
      ..close();

    canvas.drawPath(aPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FaMonogramPainter oldDelegate) =>
      oldDelegate.color != color;
}
