import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/services/google_auth_service.dart';
import 'injection_container.dart' as di;
import 'features/radar/presentation/screens/radar_screen.dart';
import 'features/discovery/presentation/screens/discovery_feed_screen.dart';
import 'features/echoes/presentation/screens/echoes_screen.dart';
import 'features/chat/presentation/screens/matches_chat_list_screen.dart';
import 'features/settings/presentation/screens/settings_privacy_screen.dart';
import 'core/services/user_provisioning_service.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/auth/presentation/screens/onboarding_profile_screen.dart';
import 'features/auth/presentation/screens/dating_onboarding_flow_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('🚀 [STARTUP-0] Flutter Binding initialized successfully');

    // Catch framework-level rendering or layout errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🚨 [STARTUP-FLUTTER-ERROR] ${details.exceptionAsString()}');
      if (details.stack != null) {
        debugPrint('   Stack trace: ${details.stack}');
      }
    };

    // Catch asynchronous platform dispatcher errors (prevents sudden iOS simulator crashes)
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🚨 [STARTUP-PLATFORM-ERROR] $error');
      debugPrint('   Stack trace: $stack');
      return true; // Handled, prevent app process abort
    };

    // Safe platform orientation handling
    try {
      debugPrint('📱 [STARTUP-1] Setting preferred orientations...');
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      debugPrint('📱 [STARTUP-1] Preferred orientations configured.');
    } catch (e) {
      debugPrint('⚠️ [STARTUP-1] Orientation setting warning (non-fatal): $e');
    }

    // Bright status bar + warm pearl navigation bar
    try {
      debugPrint('🎨 [STARTUP-2] Applying System UI Overlay Style...');
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFFFF9F7),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      debugPrint('🎨 [STARTUP-2] System UI style applied.');
    } catch (e) {
      debugPrint('⚠️ [STARTUP-2] System UI styling warning: $e');
    }

    // Initialize Firebase across platforms with dual native/options strategy
    debugPrint('🔥 [STARTUP-3] Initializing Firebase for platform: ${defaultTargetPlatform.name} (web: $kIsWeb)...');
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, attempt native initialization from GoogleService-Info.plist first
        try {
          await Firebase.initializeApp();
          debugPrint('🔥 [STARTUP-3] Firebase initialized natively from GoogleService-Info.plist');
        } catch (plistErr) {
          debugPrint('ℹ️ [STARTUP-3] Native plist init note ($plistErr), trying DefaultFirebaseOptions...');
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          debugPrint('🔥 [STARTUP-3] Firebase initialized with DefaultFirebaseOptions');
        }
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('🔥 [STARTUP-3] Firebase initialized with DefaultFirebaseOptions');
      }
      debugPrint('🔥 [STARTUP-3] Active Firebase apps: ${Firebase.apps.map((a) => a.name).toList()}');
    } catch (e, stack) {
      debugPrint('⚠️ [STARTUP-3] Firebase initialization caught error (running in resilient mode): $e');
      debugPrint('   Stack: $stack');
    }

    // Setup dependency injection
    debugPrint('💉 [STARTUP-4] Configuring GetIt dependency injection container...');
    try {
      await di.configureDependencies();
      debugPrint('💉 [STARTUP-4] Dependency injection configured successfully.');
    } catch (e, stack) {
      debugPrint('❌ [STARTUP-4] DI configuration error: $e');
      debugPrint('   DI stack: $stack');
    }

    // Initialize global Firebase Auth state listener
    debugPrint('🔐 [STARTUP-5] Initializing global Auth listeners...');
    try {
      GoogleAuthService().initializeAuthListener();
      debugPrint('🔐 [STARTUP-5] Global Auth listener initialized.');
    } catch (e) {
      debugPrint('⚠️ [STARTUP-5] Auth listener registration notice: $e');
    }

    debugPrint('✨ [STARTUP-6] Executing runApp(const AuraApp())...');
    runApp(const AuraApp());
  }, (error, stackTrace) {
    debugPrint('💥 [UNCAUGHT-ZONE-ERROR] Unhandled exception in root zone: $error');
    debugPrint('   Stack trace: $stackTrace');
  });
}

typedef FindAuraApp = AuraApp;

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

/// Global AuthGate managing app session state reactively with FirebaseAuth.instance.authStateChanges()
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🚪 [AuthGate] Building AuthGate. Firebase apps initialized: ${Firebase.apps.isNotEmpty}');

    // If Firebase failed to initialize, route safely to WelcomeScreen
    if (Firebase.apps.isEmpty) {
      debugPrint('🚪 [AuthGate] No Firebase apps found. Falling back directly to WelcomeScreen.');
      return const WelcomeScreen();
    }

    try {
      final auth = FirebaseAuth.instance;
      return StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          debugPrint('🚪 [AuthGate] authStateChanges snapshot state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');

          if (snapshot.hasError) {
            debugPrint('⚠️ [AuthGate] Auth stream error: ${snapshot.error}. Presenting WelcomeScreen fallback.');
            return const WelcomeScreen();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF4D67),
                ),
              ),
            );
          }

          final User? user = snapshot.data;
          if (user != null) {
            debugPrint('🚪 [AuthGate] Active session found for UID: ${user.uid}. Proceeding to _UserGate.');
            return _UserGate(key: ValueKey(user.uid), user: user);
          } else {
            debugPrint('🚪 [AuthGate] No active Firebase session. Presenting WelcomeScreen.');
            return const WelcomeScreen();
          }
        },
      );
    } catch (e, stack) {
      debugPrint('❌ [AuthGate] Exception during AuthGate build: $e');
      debugPrint('   Stack trace: $stack');
      return const WelcomeScreen();
    }
  }
}

class _UserGate extends StatefulWidget {
  final User user;
  const _UserGate({super.key, required this.user});

  @override
  State<_UserGate> createState() => _UserGateState();
}

class _UserGateState extends State<_UserGate> {
  late final Future<bool> _profileStatusFuture;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _profileStatusFuture = _resolveProfileStatus();
  }

  Future<bool> _resolveProfileStatus() async {
    debugPrint('🔍 [_UserGate] Checking profile completion for UID: ${widget.user.uid}...');
    try {
      // 1. Instant check from local secure storage for zero latency startup
      final localComplete = await _storage.read(key: 'is_profile_complete').timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (localComplete == 'true') {
        debugPrint('🔍 [_UserGate] Local profile status is complete.');
        return true;
      }
      // 2. Single-document read from Firestore with timeout
      final exists = await UserProvisioningService().checkUserExists(widget.user.uid).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('⏱️ [_UserGate] Firestore check timed out, defaulting to resilient fallback.');
          return true;
        },
      );
      debugPrint('🔍 [_UserGate] Firestore check returned exists: $exists');
      return exists;
    } catch (e) {
      debugPrint('⚠️ [_UserGate] Profile status check error: $e. Falling back gracefully.');
      return true; // Resilient fallback for network timeouts
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _profileStatusFuture,
      builder: (context, docSnapshot) {
        if (docSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF4D67),
              ),
            ),
          );
        }

        if (docSnapshot.data == true) {
          debugPrint('[AuthGate] Existing completed profile for ${widget.user.uid}. Launching MainNavigationShell.');
          return const MainNavigationShell();
        } else {
          debugPrint('[AuthGate] User ${widget.user.uid} requires profile completion. Launching DatingOnboardingFlowScreen.');
          return DatingOnboardingFlowScreen(user: widget.user);
        }
      },
    );
  }
}

/// Alias for Main Navigation with Radar as primary tab
typedef MainRadarNavigation = MainNavigationShell;

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    RadarScreen(onNavigateTab: (index) => setState(() => _currentIndex = index)),
    const DiscoveryFeedScreen(),
    const EchoesScreen(),
    const MatchesChatListScreen(),
    const SettingsPrivacyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildPersistentBottomBar(),
    );
  }

  Widget _buildPersistentBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // Crisp White daylight bottom bar
        border: Border(
          top: BorderSide(color: Color(0xFFFFE4E6), width: 1.0), // Delicate warm rose border
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14FF3366), // Soft warm blush drop shadow
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.radar_rounded,
                activeIcon: Icons.radar_rounded,
                label: 'Radar',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.local_fire_department_outlined,
                activeIcon: Icons.local_fire_department_rounded,
                label: 'Discover',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.waves_outlined,
                activeIcon: Icons.waves_rounded,
                label: 'Echoes',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                badgeCount: 3,
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.shield_outlined,
                activeIcon: Icons.shield_rounded,
                label: 'Profile & Privacy',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final bool isSelected = _currentIndex == index;
    const Color activeColor = Color(0xFFFF3366); // Sunset Coral (#FF3366)
    const Color inactiveColor = Color(0xFF9CA3AF); // Soft Slate

    Widget iconWidget = Container(
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Icon(
        isSelected ? activeIcon : icon,
        color: isSelected ? activeColor : inactiveColor,
        size: 22,
      ),
    );

    if (badgeCount != null && badgeCount > 0) {
      iconWidget = Badge(
        backgroundColor: activeColor, // Coral dot
        textColor: Colors.white, // Crisp white counter
        label: Text(
          '$badgeCount',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        child: iconWidget,
      );
    }

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Active Indicator Pill in Sunset Coral (#FF4D67) with glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSelected ? 22 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.75),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
              iconWidget,
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
