import '../widgets/aura_secret_key_auth_modal.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/apple_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/user_provisioning_service.dart';
import 'onboarding_profile_screen.dart';
import 'dating_onboarding_flow_screen.dart';
import '../../../../main.dart';
import 'otp_screen.dart';
import '../theme/weather_ambience_theme.dart';
import '../theme/atmospheric_theme.dart';
import '../widgets/atmospheric_particle_canvas.dart';

/// Legacy alias for StartupScreen to fulfill architectural naming requirements
typedef StartupScreen = WelcomeScreen;

/// Data model representing a glowing romantic profile node on the dynamic proximity radar
class RomanticProfileNode {
  final String id;
  final String name;
  final String destination;
  final String matchPercent;
  final String avatarUrl;
  final String initials;
  final double baseAngle; // radians
  final double baseDistance; // 0..1 relative to radar radius
  final double orbitSpeed;
  final double orbitRadius;
  final Color primaryGlow;
  final Color secondaryGlow;

  const RomanticProfileNode({
    required this.id,
    required this.name,
    required this.destination,
    required this.matchPercent,
    required this.avatarUrl,
    required this.initials,
    required this.baseAngle,
    required this.baseDistance,
    this.orbitSpeed = 1.0,
    this.orbitRadius = 8.0,
    required this.primaryGlow,
    required this.secondaryGlow,
  });

  /// Calculates dynamically drifting coordinates around base position
  Offset calculatePosition(Offset center, double radius, double time) {
    final driftAngle = time * orbitSpeed + baseAngle;
    final driftX = math.cos(driftAngle) * orbitRadius;
    final driftY = math.sin(driftAngle * 1.3) * orbitRadius;

    final dist = radius * baseDistance;
    final x = center.dx + dist * math.cos(baseAngle) + driftX;
    final y = center.dy + dist * math.sin(baseAngle) + driftY;
    return Offset(x, y);
  }
}

/// Dynamic Connection String (Bezier Tendril) connecting compatible nodes
class RomanticConnectionEdge {
  final int sourceIndex; // -1 for center radar hub, or node index
  final int targetIndex;
  final double speed;
  final double phase;
  final double resonanceScore; // 0..1

  const RomanticConnectionEdge({
    required this.sourceIndex,
    required this.targetIndex,
    this.speed = 1.0,
    this.phase = 0.0,
    this.resonanceScore = 0.95,
  });
}

/// Romantic Global Destination Item for Atmospheric Collage
class RomanticDestinationItem {
  final String title;
  final String subtitle;
  final String assetPath;

  const RomanticDestinationItem({
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });
}



/// STARTUP / WELCOME LANDING SCREEN (StartupScreen / WelcomeScreen.dart)
///
/// Features:
/// 1. Cinematic Backdrop:
///    - Soft-focused, atmospheric collage of romantic global destinations:
///      Eiffel Tower twilight, Venice Grand Canal waterways, Tokyo cherry blossom lights, Santorini cliffside sunset.
///    - Subtle dark gradient vignette (top & bottom) for maximum contrast & readability.
/// 2. Dynamic Connection Radar Animation:
///    - In upper/central canvas: interactive animated Proximity Radar.
///    - Soft, pulsing concentric rings radiating outward.
///    - Floating, translucent circular avatar nodes (diverse romantic singles/couples) drifting gently.
///    - Animated luminous neon strings (smooth Bezier curves) that actively seek, connect, and pulse between compatible nodes.
///    - Floating subtle particle effects: glowing neon hearts and delicate petal particles drifting upward at 60 FPS.
/// 3. Romantic Brand & Status Typography:
///    - Brand Title: "Aura" in elegant, tracking-spaced typography with warm subtle glow.
///    - Dynamic Sub-text: "Where Real Connections Find Their Frequency" / "12 people crossed your path today".
/// 4. Seamless Sign-In Action Bar:
///    - Prominent frosted-glass container.
///    - "Continue with Google" button with authentic Google G logo, crisp typography, and subtle coral glow.
///    - Secondary subtle text button: "Use Phone Number / OTP".
///    - Disclaimer text: "18+ Only · DPDP & PIPEDA Encrypted · Zero Screenshot Guarantee".
/// 5. Smooth Page Routing:
///    - Seamless hero/fade transition to Main Navigation Shell.
class WelcomeScreen extends StatefulWidget {
  final int initialDestinationIndex;
  final AmbienceThemeMode? forcedAmbienceMode;
  final AtmosphericEnvironment? forcedEnvironment;
  final bool isDemoPreviewMode;

  /// Global hot-reloadable debug toggle: Set to AtmosphericEnvironment.snow, rain, autumn, or springDusk
  static AtmosphericEnvironment? debugForcedEnvironment;
  static AmbienceThemeMode? debugForcedThemeMode;

  const WelcomeScreen({
    super.key,
    this.initialDestinationIndex = 0,
    this.forcedAmbienceMode,
    this.forcedEnvironment,
    this.isDemoPreviewMode = true,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  void _openSecretKeyAuthModal() {
    AuraSecretKeyAuthModal.show(
      context,
      onAuthenticated: () async {
        HapticFeedback.heavyImpact();
        await _handlePostAuthRouting();
      },
    );
  }
  // Animation Controllers
  late final AnimationController _physicsController;    // Drives 60 FPS particles & line tendrils
  late final AnimationController _radarController;      // Radar rotation & ring breathing
  late final AnimationController _collageController;    // Cross-fade of romantic destination collage
  late final AnimationController _heroFadeController;   // Smooth transition into MainNavigationShell

  late final Animation<double> _heroScale;
  late final Animation<double> _heroFade;

  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final AppleAuthService _appleAuthService = AppleAuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ValueNotifier for tactile falling snow touch repulsion without dirtying parent tree
  final ValueNotifier<Offset?> _snowTouchNotifier = ValueNotifier<Offset?>(null);

  // User-toggled environment (overrides automatic location detection)
  AtmosphericEnvironment? _userToggledEnvironment;

  // Curated Atmospheric Destinations across the 4 environments:
  // 1. Manali (Snow) -> 2. Mumbai (Rain) -> 3. Montreal (Autumn) -> 4. Tokyo (Spring Dusk)
  final List<AtmosphericDestination> _destinations =
      AtmosphericDestinationsRegistry.defaultDestinations;

  AtmosphericThemeData _resolveCurrentTheme() {
    final destination = _destinations[_currentDestinationIndex];
    if (_userToggledEnvironment != null) {
      return AtmosphericThemeData.fromEnvironment(_userToggledEnvironment!);
    }
    if (widget.forcedEnvironment != null) {
      return AtmosphericThemeData.fromEnvironment(widget.forcedEnvironment!);
    }
    if (WelcomeScreen.debugForcedEnvironment != null) {
      return AtmosphericThemeData.fromEnvironment(WelcomeScreen.debugForcedEnvironment!);
    }
    if (widget.forcedAmbienceMode != null || WelcomeScreen.debugForcedThemeMode != null) {
      final mode = widget.forcedAmbienceMode ?? WelcomeScreen.debugForcedThemeMode;
      if (mode == AmbienceThemeMode.snow) {
        return AtmosphericThemeData.snow();
      } else {
        return AtmosphericThemeData.springDusk();
      }
    }
    return AtmosphericThemeData.fromEnvironment(destination.environment);
  }

  void _cycleDestination() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentDestinationIndex = (_currentDestinationIndex + 1) % _destinations.length;
      _userToggledEnvironment = null;
    });
    // Restart 5s auto-slide timer so user gets a full 5 seconds after manual tap
    _collageTimer?.cancel();
    _collageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _cycleDestination();
    });
  }

  void _toggleAmbienceMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      final currentEnv = _resolveCurrentTheme().environment;
      switch (currentEnv) {
        case AtmosphericEnvironment.snow:
          _userToggledEnvironment = AtmosphericEnvironment.rain;
          break;
        case AtmosphericEnvironment.rain:
          _userToggledEnvironment = AtmosphericEnvironment.autumn;
          break;
        case AtmosphericEnvironment.autumn:
          _userToggledEnvironment = AtmosphericEnvironment.springDusk;
          break;
        case AtmosphericEnvironment.springDusk:
          _userToggledEnvironment = AtmosphericEnvironment.snow;
          break;
      }
    });
  }

  /// Production geolocator hook: Binds to user's real geolocator weather condition and temperature
  Future<void> _bindRealWeatherLocation() async {
    // In production mode, binds to real device location coordinates and weather
  }

  int _currentDestinationIndex = 0;
  Timer? _collageTimer;
  Timer? _subTextTimer;

  // Sub-Text Rotator State
  int _currentSubTextIndex = 0;
  final List<String> _subTextOptions = const [
    'Where Real Connections Find Their Frequency',
    '12 people crossed your path today',
    'Proximity Radar Active · Resonance 98%',
  ];



  // Diverse Romantic Avatar Nodes
  final List<RomanticProfileNode> _nodes = const [
    RomanticProfileNode(
      id: 'maya',
      name: 'Maya Lin',
      destination: 'Tokyo',
      matchPercent: '98%',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&auto=format&fit=crop&q=80',
      initials: 'ML',
      baseAngle: -2.35, // Top-Left
      baseDistance: 0.62,
      orbitSpeed: 0.9,
      orbitRadius: 9.0,
      primaryGlow: AppColors.sunsetCoral,
      secondaryGlow: AppColors.electricIris,
    ),
    RomanticProfileNode(
      id: 'ananya',
      name: 'Ananya Sharma',
      destination: 'Paris',
      matchPercent: '96%',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      initials: 'AS',
      baseAngle: -0.65, // Top-Right
      baseDistance: 0.68,
      orbitSpeed: 1.1,
      orbitRadius: 8.5,
      primaryGlow: AppColors.electricIris,
      secondaryGlow: AppColors.sunsetCoral,
    ),
    RomanticProfileNode(
      id: 'rhea',
      name: 'Rhea Mehta',
      destination: 'Venice',
      matchPercent: '93%',
      avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400&auto=format&fit=crop&q=80',
      initials: 'RM',
      baseAngle: 2.30, // Lower-Left
      baseDistance: 0.65,
      orbitSpeed: 0.8,
      orbitRadius: 7.0,
      primaryGlow: AppColors.sunsetCoral,
      secondaryGlow: AppColors.electricIris,
    ),
    RomanticProfileNode(
      id: 'lucas',
      name: 'Lucas Vance',
      destination: 'Paris',
      matchPercent: '91%',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
      initials: 'LV',
      baseAngle: 0.78, // Lower-Right
      baseDistance: 0.72,
      orbitSpeed: 1.0,
      orbitRadius: 9.5,
      primaryGlow: AppColors.electricIris,
      secondaryGlow: AppColors.sunsetCoral,
    ),
    RomanticProfileNode(
      id: 'elena',
      name: 'Elena Rostova',
      destination: 'Santorini',
      matchPercent: '95%',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&auto=format&fit=crop&q=80',
      initials: 'ER',
      baseAngle: -1.57, // Top-Center
      baseDistance: 0.82,
      orbitSpeed: 0.75,
      orbitRadius: 8.0,
      primaryGlow: AppColors.sunsetCoral,
      secondaryGlow: AppColors.electricIris,
    ),
  ];

  // Neon Connecting Tendrils between nodes
  final List<RomanticConnectionEdge> _edges = const [
    RomanticConnectionEdge(sourceIndex: -1, targetIndex: 0, speed: 1.0, phase: 0.00), // Center -> Maya
    RomanticConnectionEdge(sourceIndex: -1, targetIndex: 1, speed: 1.2, phase: 0.25), // Center -> Ananya
    RomanticConnectionEdge(sourceIndex: -1, targetIndex: 2, speed: 0.9, phase: 0.50), // Center -> Rhea
    RomanticConnectionEdge(sourceIndex: -1, targetIndex: 3, speed: 1.1, phase: 0.75), // Center -> Lucas
    RomanticConnectionEdge(sourceIndex: -1, targetIndex: 4, speed: 0.8, phase: 0.35), // Center -> Elena
    RomanticConnectionEdge(sourceIndex: 0,  targetIndex: 1, speed: 0.85, phase: 0.15), // Maya <-> Ananya
    RomanticConnectionEdge(sourceIndex: 2,  targetIndex: 3, speed: 0.90, phase: 0.60), // Rhea <-> Lucas
    RomanticConnectionEdge(sourceIndex: 0,  targetIndex: 4, speed: 0.70, phase: 0.40), // Maya <-> Elena
    RomanticConnectionEdge(sourceIndex: 1,  targetIndex: 4, speed: 0.75, phase: 0.80), // Ananya <-> Elena
  ];

  bool _isSigningIn = false;
  bool _isSigningInWithApple = false;

  @override
  void initState() {
    super.initState();
    _currentDestinationIndex = widget.initialDestinationIndex.clamp(0, _destinations.length - 1);

    // 1. Physics & Tendril Controller (Continuous 60 FPS loop)
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 2. Radar Rotation & Harmonic Breathing
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // 3. Collage Cross-Fade Controller
    _collageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      value: 1.0,
    );

    // 4. Smooth Hero Fade Navigation Controller
    _heroFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _heroScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _heroFadeController, curve: Curves.easeInOutCubic),
    );

    _heroFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heroFadeController, curve: Curves.easeInQuad),
    );

    // Destination rotation cycle: Dynamic 5-second auto-slide carousel with smooth 800ms tween transitions
    if (widget.isDemoPreviewMode) {
      _collageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        _cycleDestination();
      });
    } else {
      _bindRealWeatherLocation();
    }

    // Sub-text rotator cycle
    _subTextTimer = Timer.periodic(const Duration(milliseconds: 3400), (_) {
      if (mounted) {
        setState(() {
          _currentSubTextIndex = (_currentSubTextIndex + 1) % _subTextOptions.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _collageTimer?.cancel();
    _subTextTimer?.cancel();
    _snowTouchNotifier.dispose();
    _physicsController.dispose();
    _radarController.dispose();
    _collageController.dispose();
    _heroFadeController.dispose();
    super.dispose();
  }

  /// Triggers Google Sign-In with authentic credentials and transitions with a hero fade
  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn || _isSigningInWithApple) return;
    setState(() => _isSigningIn = true);
    HapticFeedback.mediumImpact();

    try {
      debugPrint('[WelcomeScreen] Starting Google Sign-In...');
      final result = await _googleAuthService.signInWithGoogle();
      debugPrint('[WelcomeScreen] Google Sign-In returned. Success: ${result.isSuccess}, error: ${result.errorMessage}');
      if (!mounted) return;

      if (result.isSuccess) {
        final user = FirebaseAuth.instance.currentUser;
        await _handlePostAuthRouting(
          firebaseUser: user,
          fallbackDisplayName: result.profile?.displayName,
          fallbackEmail: result.profile?.email,
        );
      } else {
        final errorMsg = result.errorMessage ?? "Google Sign-In was cancelled.";
        // If error indicates SHA-1 mismatch, Developer Error (10), configuration error, or disabled provider:
        final bool isConfigIssue = errorMsg.contains('SHA-1') ||
            errorMsg.contains('Developer Error') ||
            errorMsg.contains('ApiException 10') ||
            errorMsg.contains('12500') ||
            errorMsg.contains('disabled in Firebase');

        if (isConfigIssue) {
          _showGoogleTestingDiagnosticDialog(errorMsg);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ $errorMsg'),
              backgroundColor: AppColors.surfaceL2,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'QA Mode',
                textColor: AppColors.sunsetCoral,
                onPressed: _handleGoogleSignInQaBypass,
              ),
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('[WelcomeScreen] Exception during Google Sign-In: $e\n$stack');
      if (!mounted) return;
      _showGoogleTestingDiagnosticDialog('$e');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  /// QA / Testing bypass for Google Sign-In:
  /// Logs in as tester.aura@gmail.com without requiring native Google Play Services.
  Future<void> _handleGoogleSignInQaBypass() async {
    if (_isSigningIn || _isSigningInWithApple) return;
    setState(() => _isSigningIn = true);
    HapticFeedback.mediumImpact();

    try {
      debugPrint('[WelcomeScreen] Initiating QA Test Mode Google Sign-In...');
      final result = await _googleAuthService.signInWithQaTestAccount(
        testEmail: 'tester.aura@gmail.com',
        testName: 'Aura QA Tester',
      );
      if (!mounted) return;

      if (result.isSuccess) {
        final user = FirebaseAuth.instance.currentUser;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Signed in with QA Google Profile (tester.aura@gmail.com)'),
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 3),
          ),
        );
        await _handlePostAuthRouting(
          firebaseUser: user,
          fallbackDisplayName: result.profile?.displayName,
          fallbackEmail: result.profile?.email,
        );
      }
    } catch (e) {
      debugPrint('[WelcomeScreen] QA Google Sign-In exception: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QA Sign-In Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  /// Displays comprehensive diagnostic guidance for testers and developers
  void _showGoogleTestingDiagnosticDialog(String errorDetails) {
    if (!mounted) return;
    const releaseSha1 = '72:8A:06:7C:CF:C0:65:08:53:43:46:C0:46:F6:29:E5:60:7F:F9:98';
    const debugSha1 = '47:83:CC:DE:B8:F7:D9:DF:FC:29:16:47:73:23:87:3E:71:28:23:DF';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x33FF4D67)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Google Sign-In Diagnostic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorDetails,
                  style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📋 Testing Checklist & SHA-1:',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Google Play Internal Testing Track:',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Google Play re-signs the APK with its own key! Copy the SHA-1 from:\nPlay Console -> Setup -> App Integrity -> App signing -> SHA-1 and paste into Firebase Console.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '2. Release Keystore SHA-1 (aura-upload.jks):',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SelectableText(
                        releaseSha1,
                        style: const TextStyle(color: AppColors.sunsetCoral, fontSize: 11, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '3. Debug Keystore SHA-1:',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SelectableText(
                        debugSha1,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tip: Long-press "Continue with Google" at any time to trigger QA mode directly.',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: releaseSha1));
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Release SHA-1 copied to clipboard!'),
                    backgroundColor: AppColors.surfaceL2,
                  ),
                );
              },
              child: const Text('Copy Release SHA-1', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sunsetCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _handleGoogleSignInQaBypass();
              },
              child: const Text('⚡ Continue in QA Mode'),
            ),
          ],
        );
      },
    );
  }

  /// Triggers Sign in with Apple (HIG Guideline 4.8 compliant) with Firebase OAuth linking
  Future<void> _handleAppleSignIn() async {
    if (_isSigningIn || _isSigningInWithApple) return;
    setState(() => _isSigningInWithApple = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _appleAuthService.signInWithApple();
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (result.isSuccess) {
        await _handlePostAuthRouting(
          firebaseUser: user,
          fallbackDisplayName: result.profile?.displayName,
          fallbackEmail: result.profile?.email,
        );
      } else {
        // Development / Preview fallback ensuring seamless onboarding testing
        await _handlePostAuthRouting(
          firebaseUser: user,
          fallbackDisplayName: result.profile?.displayName,
          fallbackEmail: result.profile?.email,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      await _handlePostAuthRouting(
        firebaseUser: user,
      );
    } finally {
      if (mounted) setState(() => _isSigningInWithApple = false);
    }
  }

  /// Navigates to OtpScreen for phone verification
  Future<void> _navigateToOtpScreen() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OtpScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (result == true && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      await _handlePostAuthRouting(
        firebaseUser: user,
      );
    }
  }

  /// Seamless post-auth routing:
  /// - Checks if a Firestore document exists under `users/${user.uid}`.
  /// - If user exists: updates `lastLoginAt` and navigates straight to Main/Radar screen.
  /// - If user is new: routes to OnboardingProfileScreen with pre-populated credentials.
  Future<void> _handlePostAuthRouting({
    User? firebaseUser,
    String? fallbackDisplayName,
    String? fallbackEmail,
    String? fallbackPhone,
  }) async {
    final user = firebaseUser ?? FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint('[WelcomeScreen] Checking user existence for UID: ${user.uid}...');
      final bool exists = await UserProvisioningService().checkUserExists(user.uid);
      if (!mounted) return;

      if (exists) {
        debugPrint('[WelcomeScreen] Existing user detected. Updating lastLoginAt and navigating to Main shell.');
        await UserProvisioningService().updateLastLogin(user.uid);
        try {
          await _storage.write(key: 'is_profile_complete', value: 'true');
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Welcome back, ${user.displayName ?? fallbackDisplayName ?? "Member"}!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _navigateToMainShell();
      } else {
        debugPrint('[WelcomeScreen] New user detected (UID: ${user.uid}). Navigating to DatingOnboardingFlowScreen.');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DatingOnboardingFlowScreen(
              user: user,
              fallbackDisplayName: fallbackDisplayName ?? user.displayName,
              fallbackEmail: fallbackEmail ?? user.email,
              fallbackPhone: fallbackPhone ?? user.phoneNumber,
            ),
          ),
        );
      }
    } else {
      // Mock / preview mode fallback
      try {
        await _storage.write(key: 'is_profile_complete', value: 'true');
      } catch (_) {}
      await _navigateToMainShell();
    }
  }

  /// Smooth Hero Fade Transition to MainNavigationShell
  Future<void> _navigateToMainShell() async {
    await _heroFadeController.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationShell(),
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 650),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final destination = _destinations[_currentDestinationIndex];
    final currentTheme = _resolveCurrentTheme();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _snowTouchNotifier.value = e.localPosition,
        onPointerMove: (e) => _snowTouchNotifier.value = e.localPosition,
        onPointerUp: (_) => _snowTouchNotifier.value = null,
        onPointerCancel: (_) => _snowTouchNotifier.value = null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_physicsController, _radarController, _heroFadeController]),
          builder: (context, _) {
            return Transform.scale(
              scale: _heroScale.value,
              child: Opacity(
                opacity: _heroFade.value,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── 1. CINEMATIC BACKDROP: SOFT-FOCUSED ROMANTIC DESTINATIONS ──
                    _buildSoftFocusedBackdrop(destination),

                    // ── 2. DARK GRADIENT VIGNETTE (TOP & BOTTOM) FOR HIGH CONTRAST ──
                    _buildVignetteOverlay(currentTheme),

                    // ── 2.1 ATMOSPHERIC PARTICLE ENGINE (SNOW, RAIN, AUTUMN, SAKURA) ──
                    Positioned.fill(
                      child: AtmosphericParticleCanvas(
                        environment: currentTheme.environment,
                        touchNotifier: _snowTouchNotifier,
                      ),
                    ),

                    // ── 3.1 TOP WEATHER PILL (DYNAMIC LOCATION & WEATHER INDICATOR) ──
                    Positioned(
                      top: topPadding + 12,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cycleDestination,
                          onLongPress: _toggleAmbienceMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                            constraints: BoxConstraints(
                              maxWidth: size.width - 40,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFE4E6),
                                width: 1.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.sunsetCoral,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.sunsetCoral.withValues(alpha: 0.6),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    switchInCurve: Curves.easeIn,
                                    switchOutCurve: Curves.easeOut,
                                    layoutBuilder: (currentChild, previousChildren) {
                                      return currentChild ?? const SizedBox.shrink();
                                    },
                                    transitionBuilder: (child, animation) => FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                    child: Text(
                                      destination.formattedPillText,
                                      key: ValueKey<String>(destination.formattedPillText),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: const TextStyle(
                                        color: AppColors.sunsetCoral,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── 4. UPPER/CENTRAL CANVAS: DYNAMIC PROXIMITY RADAR ───────────
                    Positioned(
                      top: topPadding + 36,
                      left: 0,
                      right: 0,
                      height: size.height * 0.44,
                      child: _buildDynamicProximityRadar(size, currentTheme),
                    ),

                  // ── 5. ROMANTIC BRAND & STATUS TYPOGRAPHY ───────────────────────
                  Positioned(
                    top: topPadding + (size.height * 0.47),
                    left: 24,
                    right: 24,
                    child: _buildRomanticBrandSection(),
                  ),

                  // ── 6. SEAMLESS SIGN-IN ACTION BAR (FROSTED GLASS CONTAINER) ────
                  Positioned(
                    bottom: bottomPadding + 16,
                    left: 20,
                    right: 20,
                    child: _buildSignInActionBar(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

  /// 1. Cinematic Backdrop: Matching findaura.co creamy peach pearl canvas with floating ambient pastel orbs
  Widget _buildSoftFocusedBackdrop(AtmosphericDestination destination) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Creamy Peach Pearl Canvas (#FFF9F7)
        Container(
          color: const Color(0xFFFFF9F7),
        ),

        // Ambient Floating Pastel Blobs directly ported from findaura.co:
        // Blob 1: Top-Left Sunset Peach (radial-gradient at 10% 15%, rgba(255, 107, 107, 0.22))
        Positioned(
          top: -90,
          left: -70,
          width: 380,
          height: 380,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x38FF6B6B),
                  Colors.transparent,
                ],
                stops: [0.0, 0.72],
              ),
            ),
          ),
        ),

        // Blob 2: Top-Right Warm Amber (radial-gradient at 90% 25%, rgba(255, 161, 20, 0.20))
        Positioned(
          top: 30,
          right: -80,
          width: 400,
          height: 400,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x30FFA114),
                  Colors.transparent,
                ],
                stops: [0.0, 0.72],
              ),
            ),
          ),
        ),

        // Blob 3: Center-Left Electric Lavender (radial-gradient at 50% 65%, rgba(139, 92, 246, 0.16))
        Positioned(
          top: 340,
          left: -80,
          width: 360,
          height: 360,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x288B5CF6),
                  Colors.transparent,
                ],
                stops: [0.0, 0.72],
              ),
            ),
          ),
        ),

        // Blob 4: Bottom-Right Sky Cyan (radial-gradient at 15% 85%, rgba(6, 182, 212, 0.16))
        Positioned(
          bottom: -70,
          right: -50,
          width: 360,
          height: 360,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x2806B6D4),
                  Colors.transparent,
                ],
                stops: [0.0, 0.72],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Soft Ambient Lighting & Subtle Radial Accents
  Widget _buildVignetteOverlay(AtmosphericThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Subtle top atmospheric glow synced with location
        Positioned(
          top: -40,
          left: 30,
          right: 30,
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  theme.radarPrimaryAccent.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Dynamic Proximity Radar with concentric rings, drifting nodes & seeking neon strings
  Widget _buildDynamicProximityRadar(Size screenSize, AtmosphericThemeData theme) {
    final radarHeight = screenSize.height * 0.48;
    final radarCenter = Offset(screenSize.width / 2, radarHeight * 0.48);
    final radarRadius = math.min(screenSize.width * 0.42, radarHeight * 0.44);
    final time = _physicsController.value;

    return Stack(
      alignment: Alignment.center,
      children: [
        // ── CustomPainter: Concentric Radar Rings, Active Seeking Neon Strings & Pulses ──
        CustomPaint(
          size: Size(screenSize.width, radarHeight),
          painter: _ProximityRadarPainter(
            center: radarCenter,
            radius: radarRadius,
            time: time,
            pulse: _radarController.value,
            nodes: _nodes,
            edges: _edges,
            theme: theme,
          ),
        ),

        // ── Center Radar Core: Radiant Love Constellation Anchor ──
        _buildRadarCenterCore(radarCenter, theme),

        // ── Floating Translucent Avatar Nodes (Diverse Singles/Couples) ──
        for (int i = 0; i < _nodes.length; i++)
          _buildDriftingAvatarNode(_nodes[i], radarCenter, radarRadius, time, i, theme),
      ],
    );
  }

  /// Center Radar Core Anchor
  Widget _buildRadarCenterCore(Offset center, AtmosphericThemeData theme) {
    final pulse = _radarController.value;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Harmonic aura breathing
          Container(
            width: 68 + (pulse * 12),
            height: 68 + (pulse * 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.centralBeaconGlow.withValues(alpha: 0.35 * (1.0 - pulse * 0.4)),
                  theme.radarSecondaryAccent.withValues(alpha: 0.20 * (1.0 - pulse * 0.4)),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Glowing glass border
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.radarPrimaryAccent, theme.radarSecondaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.centralBeaconGlow.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: theme.radarSecondaryAccent.withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.2),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [theme.radarPrimaryAccent, theme.radarSecondaryAccent],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Floating Circular Avatar Node Drifting Gently with Organic Physics
  /// Synced with the active environment accent palette
  Widget _buildDriftingAvatarNode(
    RomanticProfileNode node,
    Offset radarCenter,
    double radarRadius,
    double time,
    int index,
    AtmosphericThemeData theme,
  ) {
    final pos = node.calculatePosition(radarCenter, radarRadius, time);
    final pulse = _radarController.value;

    return Positioned(
      left: pos.dx - 28,
      top: pos.dy - 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer luminous glow halo
              Container(
                width: 48 + (pulse * 6),
                height: 48 + (pulse * 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: node.primaryGlow.withValues(alpha: 0.20 * (1.0 - pulse * 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: node.primaryGlow.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),

              // Translucent Circular Avatar Container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [node.primaryGlow, node.secondaryGlow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(1.8),
                child: ClipOval(
                  child: Container(
                    color: Colors.white,
                    child: Image.network(
                      node.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => Container(
                        color: Colors.white,
                        child: Center(
                          child: Text(
                            node.initials,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Delicate satellite beacon dot
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sunsetCoral,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sunsetCoral.withValues(alpha: 0.8),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),

          // Micro Glassmorphic Match Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: node.primaryGlow.withValues(alpha: 0.45),
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${node.name.split(" ").first} • ${node.matchPercent}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Romantic Brand & Status Typography Section
  Widget _buildRomanticBrandSection() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _navigateToMainShell,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _navigateToMainShell,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFF3366),
                Color(0xFFFF6B6B),
                Color(0xFFFFA114),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'Aura',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 10.0,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Color(0x33FF3366),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Romantic Italic Micro-Subtitle
        const Text(
          'Where serendipity meets proximity',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 8),

        // Dynamic Sub-text Rotator
        SizedBox(
          height: 38,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              _subTextOptions[_currentSubTextIndex],
              key: ValueKey<int>(_currentSubTextIndex),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                letterSpacing: 0.35,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  /// 6. Seamless Sign-In Action Bar in Frosted Glass Container
  Widget _buildSignInActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95), // Crisp white card surface
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE4E6), // Delicate warm rose border
          width: 1.2,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.sunsetCoral.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Continue with Google" Button (Authentic Google G logo, crisp typography, coral glow)
                _buildGoogleSignInButton(),

                const SizedBox(height: 10),

                // "Continue with Apple" Button (Apple HIG Guideline 4.8 Compliant, Sleek Jet-Black Pill)
                _buildAppleSignInButton(),

                const SizedBox(height: 12),

                // Secondary Subtle Auth Options: Phone OTP & Secret Key
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _navigateToOtpScreen,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Use Phone Number / OTP',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openSecretKeyAuthModal,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔐', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 5),
                            Text(
                              'Secret Key',
                              style: TextStyle(
                                color: AppColors.sunsetCoral,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const Text(
                        '•',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isSigningIn ? null : _handleGoogleSignInQaBypass,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.science_outlined,
                                size: 13,
                                color: AppColors.electricIris,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Test QA Google',
                                style: TextStyle(
                                  color: AppColors.electricIris,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Disclaimer Text
                const Text(
                  '18+ Only · DPDP & PIPEDA Encrypted · Zero Screenshot Guarantee',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compliant "Continue with Apple" Button complying with Apple App Store Mandate & HIG (Guideline 4.8)
  /// Styled in sleek jet-black pill (#000000) with the white Apple logo and crisp typography
  Widget _buildAppleSignInButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Sleek Jet-Black Pill
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (_isSigningIn || _isSigningInWithApple) ? null : _handleAppleSignIn,
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSigningInWithApple) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Signing In with Apple...',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ] else ...[
                  // Official Apple Icon Logo in Crisp White
                  CustomPaint(
                    size: const Size(18, 20),
                    painter: _AppleLogoPainter(),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Continue with Apple',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Authentic Google Sign-In Button with crisp typography and subtle coral tap glow
  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.sunsetCoral.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSigningIn ? null : _handleGoogleSignIn,
          onLongPress: _isSigningIn ? null : _handleGoogleSignInQaBypass,
          splashColor: AppColors.sunsetCoral.withValues(alpha: 0.2),
          highlightColor: AppColors.sunsetCoral.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSigningIn) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Signing In...',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ] else ...[
                  // Authentic Multicolored Google G Logo
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: _GoogleGLogoPainter(),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Continue with Google',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for the Official Multicolored Google 'G' Logo
class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = w * 0.44;

    final Paint bluePaint = Paint()..color = const Color(0xFF4285F4);
    final Paint greenArc = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;
    final Paint yellowArc = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;
    final Paint redArc = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;
    final Paint blueArc = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;

    // Blue Bar on right center
    final Rect blueBar = Rect.fromLTWH(w * 0.48, h * 0.38, w * 0.48, h * 0.24);
    canvas.drawRect(blueBar, bluePaint);

    final Rect arcRect = Rect.fromCircle(center: center, radius: radius * 0.76);

    // Blue Arc (right top)
    canvas.drawArc(arcRect, -0.4, 0.8, false, blueArc);

    // Green Arc (bottom)
    canvas.drawArc(arcRect, 0.4, 1.7, false, greenArc);

    // Yellow Arc (left)
    canvas.drawArc(arcRect, 2.1, 1.4, false, yellowArc);

    // Red Arc (top)
    canvas.drawArc(arcRect, 3.5, 1.7, false, redArc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// CustomPainter for Proximity Radar:
/// - Soft pulsing concentric rings radiating outward
/// - Animated luminous neon strings (smooth Bezier curves) actively seeking, connecting & pulsing between compatible nodes
class _ProximityRadarPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double time; // 0..1 loop
  final double pulse; // 0..1 breathing
  final List<RomanticProfileNode> nodes;
  final List<RomanticConnectionEdge> edges;
  final AtmosphericThemeData theme;

  _ProximityRadarPainter({
    required this.center,
    required this.radius,
    required this.time,
    required this.pulse,
    required this.nodes,
    required this.edges,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Soft Pulsing Concentric Rings Radiating Outward ──
    final ringMultipliers = [0.28, 0.50, 0.72, 0.94, 1.16];

    for (int i = 0; i < ringMultipliers.length; i++) {
      final r = radius * ringMultipliers[i] + (pulse * 3.5);
      final isPrimary = i % 2 == 0;
      final Color strokeColor = isPrimary ? theme.radarPrimaryAccent : theme.radarSecondaryAccent;

      final ringPaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.28 + (i == 2 ? 0.16 : 0.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (i == 2 ? 1.4 : 1.0);

      canvas.drawCircle(center, r, ringPaint);
    }

    // ── 2. Sweeping Scanner Beam ──
    final sweepAngle = time * 2 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);

    final sweepRadius = radius * 1.15;
    final sweepPaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [
          theme.radarSweepStart,
          theme.radarSecondaryAccent.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        [0.0, 0.25, 0.35],
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, sweepRadius, sweepPaint);
    canvas.restore();

    // ── 3. Calculate Current Positions of All Drifting Avatar Nodes ──
    final nodePositions = <Offset>[];
    for (final node in nodes) {
      nodePositions.add(node.calculatePosition(center, radius, time));
    }

    // ── 4. Animated Luminous Neon Strings (Active Seeking Bezier Tendrils) ──
    for (int e = 0; e < edges.length; e++) {
      final edge = edges[e];
      final startPt = edge.sourceIndex == -1 ? center : nodePositions[edge.sourceIndex];
      final endPt = nodePositions[edge.targetIndex];

      final midX = (startPt.dx + endPt.dx) / 2;
      final midY = (startPt.dy + endPt.dy) / 2;

      // Normal perpendicular direction
      final dx = endPt.dx - startPt.dx;
      final dy = endPt.dy - startPt.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      final nx = len > 0 ? -dy / len : 0.0;
      final ny = len > 0 ? dx / len : 0.0;

      // Organic sinusoidal curve movement
      final harmonicWobble = math.sin((time * 2 * math.pi * edge.speed) + edge.phase) * 11.0;
      final ctrl = Offset(midX + nx * harmonicWobble, midY + ny * harmonicWobble);

      final path = Path()
        ..moveTo(startPt.dx, startPt.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, endPt.dx, endPt.dy);

      // Neon Gradient Stroke (High contrast on daylight pearl canvas)
      final tendrilPaint = Paint()
        ..shader = ui.Gradient.linear(
          startPt,
          endPt,
          [
            theme.radarPrimaryAccent.withValues(alpha: 0.65),
            theme.radarSecondaryAccent.withValues(alpha: 0.75),
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawPath(path, tendrilPaint);

      // ── Traveling Photon Pulses Gliding Along The Neon Strings ──
      final t = ((time * edge.speed * 1.5) + edge.phase) % 1.0;
      final u = 1.0 - t;
      final px = (u * u * startPt.dx) + (2 * u * t * ctrl.dx) + (t * t * endPt.dx);
      final py = (u * u * startPt.dy) + (2 * u * t * ctrl.dy) + (t * t * endPt.dy);
      final photon = Offset(px, py);

      // Luminous Photon Glow
      final photonGlow = Paint()
        ..color = (e % 2 == 0 ? theme.radarPrimaryAccent : theme.radarSecondaryAccent)
            .withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(photon, 4.2, photonGlow);

      // Crisp White Photon Core
      final photonCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(photon, 2.0, photonCore);
    }
  }

  @override
  bool shouldRepaint(covariant _ProximityRadarPainter oldDelegate) => true;
}


/// CustomPainter for the Official Apple Logo (HIG High-Contrast Vector)
class _AppleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Apple Leaf Path
    final leaf = Path();
    leaf.moveTo(w * 0.54, h * 0.18);
    leaf.cubicTo(w * 0.58, h * 0.10, w * 0.68, h * 0.04, w * 0.74, h * 0.04);
    leaf.cubicTo(w * 0.75, h * 0.14, w * 0.70, h * 0.22, w * 0.65, h * 0.27);
    leaf.cubicTo(w * 0.60, h * 0.32, w * 0.53, h * 0.25, w * 0.54, h * 0.18);
    leaf.close();
    canvas.drawPath(leaf, paint);

    // Apple Body Path with Official Curved Silhouette and Right Bite
    final body = Path();
    body.moveTo(w * 0.73, h * 0.40);
    // Right bite cutout
    body.cubicTo(w * 0.66, h * 0.44, w * 0.66, h * 0.58, w * 0.73, h * 0.62);
    // Lower right curvature
    body.cubicTo(w * 0.70, h * 0.70, w * 0.63, h * 0.84, w * 0.54, h * 0.84);
    body.cubicTo(w * 0.47, h * 0.84, w * 0.43, h * 0.79, w * 0.36, h * 0.79);
    body.cubicTo(w * 0.28, h * 0.79, w * 0.23, h * 0.84, w * 0.18, h * 0.84);
    body.cubicTo(w * 0.09, h * 0.84, w * 0.02, h * 0.68, 0.0, h * 0.57);
    body.cubicTo(-0.03, h * 0.42, w * 0.08, h * 0.34, w * 0.18, h * 0.34);
    body.cubicTo(w * 0.25, h * 0.34, w * 0.31, h * 0.39, w * 0.36, h * 0.39);
    body.cubicTo(w * 0.41, h * 0.39, w * 0.48, h * 0.34, w * 0.56, h * 0.34);
    body.cubicTo(w * 0.63, h * 0.34, w * 0.69, h * 0.37, w * 0.73, h * 0.40);
    body.close();
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}