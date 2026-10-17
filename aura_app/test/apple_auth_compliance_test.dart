import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/apple_auth_service.dart';
import 'package:aura_app/features/auth/presentation/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Apple Sign-In & App Store Compliance Suite', () {
    test('AppleAuthService fallback creates valid credential profile', () async {
      final service = AppleAuthService();
      // On non-iOS testing runtime, service produces structured profile
      final result = await service.signInWithApple(
        mockEmail: 'tester.apple@privaterelay.appleid.com',
        mockName: 'Aura Tester',
      );

      expect(result.profile?.email, equals('tester.apple@privaterelay.appleid.com'));
      expect(result.profile?.displayName, equals('Aura Tester'));
      expect(result.profile?.id, contains('apple_sub_'));
      expect(result.token, isNotNull);
    });

    testWidgets('WelcomeScreen renders official Sign in with Apple button alongside Google without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812)); // Standard iPhone size

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(
            isDemoPreviewMode: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Apple Sign-in button exists
      expect(find.text('Continue with Apple'), findsOneWidget);

      // Verify Google Sign-in button exists alongside
      expect(find.text('Continue with Google'), findsOneWidget);

      // Verify phone OTP option exists
      expect(find.text('Use Phone Number / OTP'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
