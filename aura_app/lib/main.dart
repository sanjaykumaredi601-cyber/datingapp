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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe platform orientation handling (desktop doesn't support orientation locking)
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Bright status bar + warm pearl navigation bar
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFFFF9F7),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  } catch (_) {}

  // Initialize Firebase across platforms
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('ℹ️ Firebase initialization notice: $e');
  }

  // Setup dependency injection
  await di.configureDependencies();

  // Initialize global Firebase Auth state listener
  GoogleAuthService().initializeAuthListener();

  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

/// Global AuthGate managing app session state reactively with FirebaseAuth.instance.authStateChanges()
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final auth = FirebaseAuth.instance;
      return StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
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
            return _UserGate(key: ValueKey(user.uid), user: user);
          } else {
            debugPrint('[AuthGate] No active Firebase session. Presenting WelcomeScreen.');
            return const WelcomeScreen();
          }
        },
      );
    } catch (e) {
      debugPrint('[AuthGate] Firebase Auth unavailable ($e). Falling back to WelcomeScreen.');
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
    try {
      // 1. Instant check from local secure storage for zero latency startup
      final localComplete = await _storage.read(key: 'is_profile_complete');
      if (localComplete == 'true') {
        return true;
      }
      // 2. Single-document read from Firestore with timeout
      return await UserProvisioningService().checkUserExists(widget.user.uid);
    } catch (_) {
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
