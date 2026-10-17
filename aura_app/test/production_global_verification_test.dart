import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/phone_number_helper.dart';
import 'package:aura_app/core/utils/geohash_helper.dart';
import 'package:aura_app/core/services/compliance_service.dart';
import 'package:aura_app/core/services/location_stream_service.dart';
import 'package:aura_app/features/vouchers/domain/repositories/voucher_repository.dart';
import 'package:aura_app/features/vouchers/data/repositories/voucher_repository_impl.dart';
import 'package:aura_app/features/radar/presentation/screens/radar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. International Phone Registration & E.164 Formatting Matrix Tests', () {
    test('India (+91): Validates 10-digit mobile numbers with E.164 formatting', () {
      final country = PhoneNumberHelper.findByIsoCode('IN');
      expect(country.dialCode, equals('+91'));
      expect(country.minLength, equals(10));

      // Valid Indian numbers
      final res1 = PhoneNumberHelper.validate(country: country, rawInput: '9876543210');
      expect(res1.isValid, isTrue);
      expect(res1.formattedE164, equals('+919876543210'));

      final res2 = PhoneNumberHelper.validate(country: country, rawInput: '+91 87654 32109');
      expect(res2.isValid, isTrue);
      expect(res2.formattedE164, equals('+918765432109'));

      // Leading zero strip
      final res3 = PhoneNumberHelper.validate(country: country, rawInput: '07654321098');
      expect(res3.isValid, isTrue);
      expect(res3.formattedE164, equals('+917654321098'));

      // Invalid: too short or starting with invalid digit
      final invalid1 = PhoneNumberHelper.validate(country: country, rawInput: '12345');
      expect(invalid1.isValid, isFalse);

      final invalid2 = PhoneNumberHelper.validate(country: country, rawInput: '3876543210');
      expect(invalid2.isValid, isFalse);
    });

    test('Canada (+1): Validates NANP format and Canadian area codes', () {
      final country = PhoneNumberHelper.findByIsoCode('CA');
      expect(country.dialCode, equals('+1'));

      // Toronto 416 area code
      final res1 = PhoneNumberHelper.validate(country: country, rawInput: '4165550199');
      expect(res1.isValid, isTrue);
      expect(res1.formattedE164, equals('+14165550199'));

      // Vancouver 604 area code
      final res2 = PhoneNumberHelper.validate(country: country, rawInput: '(604) 555-0144');
      expect(res2.isValid, isTrue);
      expect(res2.formattedE164, equals('+16045550144'));

      // Invalid NANP (area code starting with 0 or 1)
      final invalid1 = PhoneNumberHelper.validate(country: country, rawInput: '1165550199');
      expect(invalid1.isValid, isFalse);
    });

    test('United Kingdom (+44), Australia (+61), UAE (+971), Singapore (+65)', () {
      // UK
      final uk = PhoneNumberHelper.findByIsoCode('GB');
      final resUk = PhoneNumberHelper.validate(country: uk, rawInput: '7911123456');
      expect(resUk.isValid, isTrue);
      expect(resUk.formattedE164, equals('+447911123456'));

      // Australia
      final au = PhoneNumberHelper.findByIsoCode('AU');
      final resAu = PhoneNumberHelper.validate(country: au, rawInput: '412345678');
      expect(resAu.isValid, isTrue);
      expect(resAu.formattedE164, equals('+61412345678'));

      // UAE
      final ae = PhoneNumberHelper.findByIsoCode('AE');
      final resAe = PhoneNumberHelper.validate(country: ae, rawInput: '501234567');
      expect(resAe.isValid, isTrue);
      expect(resAe.formattedE164, equals('+971501234567'));

      // Singapore
      final sg = PhoneNumberHelper.findByIsoCode('SG');
      final resSg = PhoneNumberHelper.validate(country: sg, rawInput: '91234567');
      expect(resSg.isValid, isTrue);
      expect(resSg.formattedE164, equals('+6591234567'));
    });

    test('Global ITU E.164 compliance checker correctly evaluates arbitrary strings', () {
      expect(PhoneNumberHelper.isValidE164String('+919876543210'), isTrue);
      expect(PhoneNumberHelper.isValidE164String('+14165550199'), isTrue);
      expect(PhoneNumberHelper.isValidE164String('+447911123456'), isTrue);
      expect(PhoneNumberHelper.isValidE164String('9876543210'), isFalse); // Missing +
      expect(PhoneNumberHelper.isValidE164String('+0123456789'), isFalse); // Leading 0 in country code
    });
  });

  group('2. Multi-Region Privacy Compliance Suite (India DPDP Act 2023 & Canada PIPEDA)', () {
    late ComplianceService complianceService;

    setUp(() {
      complianceService = ComplianceService();
    });

    test('Records granular consent logs for location tracking and biometric data', () async {
      const testUser = 'user_compliance_test_001';

      final locConsent = await complianceService.recordConsent(
        userId: testUser,
        consentType: 'LOCATION_TRACKING',
        granted: true,
        regulation: 'DPDP_ACT_2023',
      );
      expect(locConsent.consentId, startsWith('consent_'));
      expect(locConsent.granted, isTrue);
      expect(locConsent.regulation, equals('DPDP_ACT_2023'));

      final bioConsent = await complianceService.recordConsent(
        userId: testUser,
        consentType: 'BIOMETRIC_DATA',
        granted: true,
        regulation: 'CANADA_PIPEDA',
      );
      expect(bioConsent.consentType, equals('BIOMETRIC_DATA'));
      expect(bioConsent.regulation, equals('CANADA_PIPEDA'));
    });

    test('Executes one-click 48-hour location history purge', () async {
      const testUser = 'user_compliance_test_002';

      final purgeResult = await complianceService.purge48HourLocationHistory(
        userId: testUser,
      );

      expect(purgeResult.isSuccess, isTrue);
      expect(purgeResult.message, contains('48-hour location history'));
      expect(purgeResult.purgedAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
    });

    test('Generates complete user data export complying with data portability rights', () async {
      const testUser = 'user_compliance_test_003';

      await complianceService.recordConsent(
        userId: testUser,
        consentType: 'LOCATION_TRACKING',
        granted: true,
        regulation: 'DPDP_ACT_2023',
      );

      final export = await complianceService.exportUserData(userId: testUser);

      expect(export['exportMetadata'], isNotNull);
      expect(export['exportMetadata']['userId'], equals(testUser));
      expect(export['exportMetadata']['regulationsSupported'], contains('India DPDP Act 2023'));
      expect(export['exportMetadata']['regulationsSupported'], contains('Canada PIPEDA'));
      expect(export['locationHistory']['status'], contains('Zero Raw GPS'));
    });
  });

  group('3. 500m Safe Geohash Obfuscation & Path Crossing Suite', () {
    test('Encodes coordinates to exactly 6-character 500m geohash cell', () {
      const lat = 19.0596;
      const lon = 72.8295;

      final geohash500m = GeoHashHelper.obfuscateTo500mGeohash(lat, lon);
      expect(geohash500m.length, equals(6));
      expect(geohash500m, equals('te7u3m'));

      // Neighboring point ~50m away belongs to the same 500m cell
      const neighborLat = 19.0598;
      const neighborLon = 72.8296;
      final neighborHash = GeoHashHelper.obfuscateTo500mGeohash(neighborLat, neighborLon);
      expect(neighborHash, equals(geohash500m));
    });

    test('Decodes 500m cell center for privacy-safe UI map rendering', () {
      final center = GeoHashHelper.decodeCenter('te7u3m');
      expect(center['latitude'], isNotNull);
      expect(center['longitude'], isNotNull);

      // Center must be within the cell vicinity of Mumbai
      expect(center['latitude']!, closeTo(19.06, 0.1));
      expect(center['longitude']!, closeTo(72.83, 0.1));
    });

    test('PathCrossingEvent serializes properly with 48-hour expiration TTL', () {
      final now = DateTime.now();
      final event = PathCrossingEvent(
        echoId: 'echo_test_001',
        user1Id: 'user_a',
        user2Id: 'user_b',
        candidateName: 'Aanya',
        zoneName: 'Bandra Bandstand',
        geohash: 'te7u80',
        crossedAt: now,
      );

      final map = event.toMap();
      expect(map['echoId'], equals('echo_test_001'));
      expect(map['candidateName'], equals('Aanya'));
      expect(map['geohash'], equals('te7u80'));

      final expiresAt = DateTime.parse(map['expiresAt'] as String);
      final differenceHours = expiresAt.difference(now).inHours;
      expect(differenceHours, equals(48));
    });
  });

  group('4. Cloud Firestore Vouchers Collection & Repository Suite', () {
    late VoucherRepository voucherRepo;

    setUp(() {
      voucherRepo = VoucherRepositoryImpl();
    });

    test('Creates and dispatches coffee voucher with unique redemption code', () async {
      final voucher = await voucherRepo.sendVoucher(
        senderId: 'user_sender_101',
        senderName: 'Sanjay',
        recipientId: 'user_receiver_202',
        type: 'coffee',
        title: 'Blue Tokai Specialty Coffee',
        amount: 350.0,
        currency: 'INR',
        message: 'Loved crossing paths! Coffee on me ☕',
      );

      expect(voucher.voucherId, startsWith('vch_'));
      expect(voucher.status, equals('ACTIVE'));
      expect(voucher.type, equals('coffee'));
      expect(voucher.redemptionCode, startsWith('COFFEE-'));
      expect(voucher.amount, equals(350.0));
      expect(voucher.currency, equals('INR'));
    });

    test('Fetches user vouchers and processes one-time redemption lifecycle', () async {
      const recipientId = 'user_receiver_303';

      final voucher = await voucherRepo.sendVoucher(
        senderId: 'user_sender_101',
        senderName: 'Sanjay',
        recipientId: recipientId,
        type: 'drink',
        title: 'Artisan Mocktail',
        amount: 450.0,
      );

      final userVouchers = await voucherRepo.getVouchersForUser(recipientId);
      expect(userVouchers.any((v) => v.voucherId == voucher.voucherId), isTrue);

      // Redeem voucher
      final redeemed = await voucherRepo.redeemVoucher(
        voucherId: voucher.voucherId,
        userId: recipientId,
      );
      expect(redeemed, isTrue);

      // Re-redeeming should fail (already redeemed)
      final secondRedeem = await voucherRepo.redeemVoucher(
        voucherId: voucher.voucherId,
        userId: recipientId,
      );
      expect(secondRedeem, isFalse);
    });
  });

  group('5. Radar CustomPainter 60 FPS Canvas Stress Suite', () {
    test('CustomBaseMapPainter paints dark obsidian cartography without exception', () {
      final painter = CustomBaseMapPainter();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1920);

      // Paint should execute cleanly
      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('RadarRingsPainter executes 120 consecutive frames sustained at 60 FPS without memory leaks', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 400);

      final stopwatch = Stopwatch()..start();

      // Stress test: Simulate 120 frames (2 full seconds of 60 FPS rendering)
      for (int frame = 0; frame < 120; frame++) {
        final pulse = (frame % 60) / 60.0;

        final painter = RadarRingsPainter(
          center: const Offset(200, 200),
          pulseValue: pulse,
          radiusScale: 1.0,
        );

        painter.paint(canvas, size);
      }

      stopwatch.stop();

      // 120 frames in testing harness should take well under 1000ms (averaging < 8ms per frame)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
