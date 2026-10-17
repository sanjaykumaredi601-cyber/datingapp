import 'package:flutter_test/flutter_test.dart';

int calculateAge(DateTime birthDate, [DateTime? currentDate]) {
  final now = currentDate ?? DateTime.now();
  int age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

bool validateAgeIsAdult(DateTime birthDate, [DateTime? currentDate]) {
  return calculateAge(birthDate, currentDate) >= 18;
}

bool validateOtp(String otp) {
  return RegExp(r'^\d{6}$').hasMatch(otp.trim());
}

bool validatePhotoCount(int count) {
  return count >= 2 && count <= 6;
}

void main() {
  group('Profile Validation — Strict 18+ Age Checks', () {
    final referenceDate = DateTime(2026, 9, 25);

    test('rejects user who is 17 years and 364 days old', () {
      final birthDate = DateTime(2008, 9, 26);
      expect(calculateAge(birthDate, referenceDate), 17);
      expect(validateAgeIsAdult(birthDate, referenceDate), isFalse);
    });

    test('accepts user on their exact 18th birthday', () {
      final birthDate = DateTime(2008, 9, 25);
      expect(calculateAge(birthDate, referenceDate), 18);
      expect(validateAgeIsAdult(birthDate, referenceDate), isTrue);
    });

    test('accepts user who is 25 years old', () {
      final birthDate = DateTime(2001, 4, 15);
      expect(calculateAge(birthDate, referenceDate), 25);
      expect(validateAgeIsAdult(birthDate, referenceDate), isTrue);
    });
  });

  group('Profile Validation — Phone & 6-Digit OTP', () {
    test('rejects empty or partial OTP codes', () {
      expect(validateOtp(''), isFalse);
      expect(validateOtp('123'), isFalse);
      expect(validateOtp('12345'), isFalse);
    });

    test('rejects alphanumeric or special characters in OTP', () {
      expect(validateOtp('12A456'), isFalse);
      expect(validateOtp('12-456'), isFalse);
      expect(validateOtp('abcdef'), isFalse);
    });

    test('accepts valid 6-digit numeric OTP', () {
      expect(validateOtp('123456'), isTrue);
      expect(validateOtp('000000'), isTrue);
      expect(validateOtp('987654'), isTrue);
    });
  });

  group('Profile Validation — Media Upload Grid (2 to 6 Photos)', () {
    test('rejects profile with fewer than 2 photos', () {
      expect(validatePhotoCount(0), isFalse);
      expect(validatePhotoCount(1), isFalse);
    });

    test('accepts profile with 2 to 6 photos inclusive', () {
      expect(validatePhotoCount(2), isTrue);
      expect(validatePhotoCount(3), isTrue);
      expect(validatePhotoCount(6), isTrue);
    });

    test('rejects profile with more than 6 photos', () {
      expect(validatePhotoCount(7), isFalse);
      expect(validatePhotoCount(10), isFalse);
    });
  });
}
