import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/features/splash/presentation/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 1: FindAura Branding Constants & Variables', () {
    test('1.1 AppConstants and AppColors reflect FindAura branding and sky-blue #7FA6C4', () {
      expect(AppConstants.appName, equals('FindAura'));
      expect(AppConstants.appTagline, equals('Discover your vibe. Find your aura.'));
      expect(AppConstants.brandDomain, equals('findaura.co'));

      expect(AppColors.findAuraSkyBlue, equals(const Color(0xFF7FA6C4)));
      expect(AppColors.splashBackground, equals(const Color(0xFF7FA6C4)));
    });

    test('1.2 AndroidManifest.xml and iOS Info.plist specify FindAura display name', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent.contains('android:label="FindAura"'), isTrue);

      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final plistContent = plistFile.readAsStringSync();
      expect(plistContent.contains('<key>CFBundleDisplayName</key>'), isTrue);
      expect(plistContent.contains('<string>FindAura</string>'), isTrue);
    });
  });

  group('TASK 2: FindAura Animated Splash Screen', () {
    testWidgets('2.1 SplashScreen renders with solid sky-blue background #7FA6C4', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(autoNavigate: false),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF7FA6C4)));
    });

    testWidgets('2.2 SplashScreen centers FA monogram logo, FindAura text, and tagline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(autoNavigate: false),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('splash_fa_monogram')), findsOneWidget);
      expect(find.byKey(const Key('splash_findaura_text')), findsOneWidget);
      expect(find.text('FindAura'), findsOneWidget);
      expect(find.byKey(const Key('splash_tagline_text')), findsOneWidget);
      expect(find.text('Discover your vibe. Find your aura.'), findsOneWidget);
    });

    testWidgets('2.3 Staggered animation sequence: FA monogram fades in first, followed by FindAura text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            autoNavigate: false,
            animationDuration: Duration(milliseconds: 1000),
          ),
        ),
      );

      // t = 0ms: Initial state
      final faFadeFinder = find.ancestor(
        of: find.byKey(const Key('splash_fa_monogram')),
        matching: find.byType(FadeTransition),
      );
      final textFadeFinder = find.ancestor(
        of: find.byKey(const Key('splash_findaura_text')),
        matching: find.byType(FadeTransition),
      );

      FadeTransition faFade = tester.widget<FadeTransition>(faFadeFinder.first);
      FadeTransition textFade = tester.widget<FadeTransition>(textFadeFinder.first);

      expect(faFade.opacity.value, equals(0.0));
      expect(textFade.opacity.value, equals(0.0));

      // Advance 300ms (within FA monogram fade-in window)
      await tester.pump(const Duration(milliseconds: 300));
      faFade = tester.widget<FadeTransition>(faFadeFinder.first);
      textFade = tester.widget<FadeTransition>(textFadeFinder.first);

      expect(faFade.opacity.value, greaterThan(0.5));
      expect(textFade.opacity.value, equals(0.0)); // Text has not started fading in yet

      // Advance to 650ms (Text starts fading in)
      await tester.pump(const Duration(milliseconds: 350));
      faFade = tester.widget<FadeTransition>(faFadeFinder.first);
      textFade = tester.widget<FadeTransition>(textFadeFinder.first);

      expect(faFade.opacity.value, equals(1.0));
      expect(textFade.opacity.value, greaterThan(0.3));

      // Advance to 1000ms (All components fully faded in)
      await tester.pump(const Duration(milliseconds: 350));
      faFade = tester.widget<FadeTransition>(faFadeFinder.first);
      textFade = tester.widget<FadeTransition>(textFadeFinder.first);

      expect(faFade.opacity.value, equals(1.0));
      expect(textFade.opacity.value, equals(1.0));
    });

    testWidgets('2.4 SplashScreen transitions to next screen after total display duration', (tester) async {
      bool animationCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            autoNavigate: true,
            animationDuration: const Duration(milliseconds: 500),
            totalDisplayDuration: const Duration(milliseconds: 1000),
            nextScreen: const Scaffold(
              body: Center(child: Text('MainAppTargetScreen')),
            ),
            onAnimationComplete: () => animationCompleted = true,
          ),
        ),
      );

      // Finish animation
      await tester.pump(const Duration(milliseconds: 550));
      expect(animationCompleted, isTrue);

      // Advance to navigation timer trigger
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(find.text('MainAppTargetScreen'), findsOneWidget);
    });

    testWidgets('2.5 FaMonogramPainter custom vector scales and paints without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: Size(140, 98),
                painter: FaMonogramPainter(color: Colors.white),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
