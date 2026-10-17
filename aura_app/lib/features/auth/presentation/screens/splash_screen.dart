export 'welcome_screen.dart';

import 'package:flutter/material.dart';
import 'welcome_screen.dart';

/// Backward-compatible alias for WelcomeScreen
/// Preserves legacy route bindings while routing to the new futuristic
/// romantic destination collage and dynamic radar screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen();
  }
}
