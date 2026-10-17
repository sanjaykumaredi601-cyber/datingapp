import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Sign-In QA and Diagnostic Verification', () {
    test('1. GoogleAuthService singleton initialization', () {
      final service = GoogleAuthService();
      expect(service, isNotNull);
    });

    test('2. signInWithQaTestAccount returns valid profile and session token', () async {
      final service = GoogleAuthService();
      final result = await service.signInWithQaTestAccount(
        testEmail: 'tester.aura@gmail.com',
        testName: 'Aura QA Tester',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile?.email, equals('tester.aura@gmail.com'));
      expect(result.profile?.displayName, equals('Aura QA Tester'));
      expect(result.token, isNotNull);
    });

    test('3. Custom test account parameters', () async {
      final service = GoogleAuthService();
      final result = await service.signInWithQaTestAccount(
        testEmail: 'developer@aura.dating',
        testName: 'Lead Dev',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile?.email, equals('developer@aura.dating'));
      expect(result.profile?.displayName, equals('Lead Dev'));
    });
  });
}
