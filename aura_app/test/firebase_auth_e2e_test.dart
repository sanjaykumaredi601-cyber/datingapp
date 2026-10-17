import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Authentication E2E State Verification (aura-b033d)', () {
    test('Verify Google and Mobile user records are officially stored in Firebase Auth', () async {
      final file = File('users.json');
      expect(file.existsSync(), isTrue, reason: 'users.json from firebase auth:export should exist');

      final content = await file.readAsString();
      final data = jsonDecode(content);
      final List users = data['users'] as List;

      expect(users.length, greaterThanOrEqualTo(2));

      // 1. Check Google user
      final googleUser = users.firstWhere(
        (u) => u['email'] == 'sanjaykumaredi60@gmail.com',
        orElse: () => null,
      );
      expect(googleUser, isNotNull, reason: 'Google user sanjaykumaredi60@gmail.com must exist');
      expect(googleUser['providerUserInfo'][0]['providerId'], equals('google.com'));

      // 2. Check Phone user
      final phoneUser = users.firstWhere(
        (u) => u['phoneNumber'] == '+919876543210',
        orElse: () => null,
      );
      expect(phoneUser, isNotNull, reason: 'Mobile phone user +919876543210 must exist');
    });
  });
}
