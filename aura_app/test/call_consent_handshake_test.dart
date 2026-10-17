import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/firestore_service.dart';

void main() {
  group('Two-Way Call Consent & Permission Handshake Suite', () {
    const testConversationId = 'test_conversation_conv_123';
    final firestore = FirestoreService();

    test('1. CallConsentRequest model serialization and JSON schema integrity', () {
      final now = DateTime.now();
      final request = CallConsentRequest(
        callerId: 'user_a_uid',
        callerName: 'Aarav',
        callerAvatarUrl: 'https://example.com/avatar.jpg',
        callType: CallType.audio,
        status: CallConsentStatus.pending,
        timestamp: now,
        ttl: 30,
      );

      final map = request.toMap();
      expect(map['callerId'], equals('user_a_uid'));
      expect(map['callerName'], equals('Aarav'));
      expect(map['callType'], equals('audio'));
      expect(map['status'], equals('pending'));
      expect(map['ttl'], equals(30));
      expect(map['timestamp'], equals(now.toIso8601String()));

      final reconstructed = CallConsentRequest.fromMap(map);
      expect(reconstructed.callerId, equals(request.callerId));
      expect(reconstructed.callerName, equals(request.callerName));
      expect(reconstructed.callType, equals(CallType.audio));
      expect(reconstructed.status, equals(CallConsentStatus.pending));
      expect(reconstructed.ttl, equals(30));
    });

    test('2. Video call type and custom status parsing', () {
      final videoMap = {
        'callerId': 'user_b_uid',
        'callerName': 'Diya',
        'callType': 'video',
        'status': 'accepted',
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': 30,
      };

      final videoReq = CallConsentRequest.fromMap(videoMap);
      expect(videoReq.callType, equals(CallType.video));
      expect(videoReq.status, equals(CallConsentStatus.accepted));
    });

    test('3. TTL and Expiry calculation logic', () {
      // 10 seconds ago with 30s TTL -> remaining should be ~20s, not expired
      final recent = CallConsentRequest(
        callerId: 'user_a_uid',
        callerName: 'Aarav',
        callType: CallType.audio,
        status: CallConsentStatus.pending,
        timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
        ttl: 30,
      );
      expect(recent.isExpired, isFalse);
      expect(recent.remainingSeconds, inInclusiveRange(18, 20));

      // 35 seconds ago with 30s TTL -> expired
      final old = CallConsentRequest(
        callerId: 'user_a_uid',
        callerName: 'Aarav',
        callType: CallType.audio,
        status: CallConsentStatus.pending,
        timestamp: DateTime.now().subtract(const Duration(seconds: 35)),
        ttl: 30,
      );
      expect(old.isExpired, isTrue);
      expect(old.remainingSeconds, equals(0));

      // Explicit expired status
      final explicitExpired = recent.copyWith(status: CallConsentStatus.expired);
      expect(explicitExpired.isExpired, isTrue);
    });

    test('4. Real-time Firestore call request stream and status state machine', () async {
      final stream = firestore.callRequestStream(testConversationId);
      final receivedUpdates = <CallConsentRequest?>[];
      final sub = stream.listen((req) => receivedUpdates.add(req));

      // 1. Initial State: null or empty
      await Future.delayed(const Duration(milliseconds: 20));

      // 2. Emit Pending Call Request
      final request = CallConsentRequest(
        callerId: 'user_a_uid',
        callerName: 'Aarav',
        callType: CallType.video,
        status: CallConsentStatus.pending,
        timestamp: DateTime.now(),
        ttl: 30,
      );
      await firestore.emitCallRequest(testConversationId, request);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(firestore.getCallRequest(testConversationId)?.status,
          equals(CallConsentStatus.pending));

      // 3. Update to Accepted
      await firestore.updateCallRequestStatus(
          testConversationId, CallConsentStatus.accepted);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(firestore.getCallRequest(testConversationId)?.status,
          equals(CallConsentStatus.accepted));

      // 4. Update to Declined
      await firestore.updateCallRequestStatus(
          testConversationId, CallConsentStatus.declined);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(firestore.getCallRequest(testConversationId)?.status,
          equals(CallConsentStatus.declined));

      // 5. Update to Expired
      await firestore.updateCallRequestStatus(
          testConversationId, CallConsentStatus.expired);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(firestore.getCallRequest(testConversationId)?.status,
          equals(CallConsentStatus.expired));

      // Cleanup
      firestore.clearCallRequest(testConversationId);
      await sub.cancel();
      expect(firestore.getCallRequest(testConversationId), isNull);
    });
  });
}
