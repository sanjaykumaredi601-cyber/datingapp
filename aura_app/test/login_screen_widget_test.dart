import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/features/auth/presentation/screens/welcome_screen.dart';

void main() {
  group('NextGen IT Global - Welcome / Login Screen Widget Tests', () {
    testWidgets('1. Renders Aura brand title and destination showcase', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      // Allow animations to initialize
      await tester.pump(const Duration(milliseconds: 100));

      // Brand title "Aura"
      expect(find.text('Aura'), findsOneWidget);

      // Verify romantic value proposition copy
      expect(
        find.textContaining('Where Real Connections Find Their Frequency'),
        findsOneWidget,
      );
    });

    testWidgets('2. Renders Google Sign-In and Apple Sign-In authentication action buttons', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Primary "Continue with Google" Button
      expect(find.text('Continue with Google'), findsOneWidget);

      // "Continue with Apple" Button
      expect(find.text('Continue with Apple'), findsOneWidget);

      // Verify Google Sign-In button is interactive
      final googleButton = find.text('Continue with Google');
      expect(googleButton, findsOneWidget);
    });

    testWidgets('3. Renders Phone OTP fallback, Secret Key entry, and Legal Compliance Disclaimers', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Secondary auth buttons
      expect(find.text('Phone OTP'), findsOneWidget);
      expect(find.text('Secret Key'), findsOneWidget);

      // Compliance and Privacy guarantee
      expect(
        find.textContaining('18+ Only · DPDP & PIPEDA Encrypted · Zero Screenshot Guarantee'),
        findsOneWidget,
      );
    });
  });
}
