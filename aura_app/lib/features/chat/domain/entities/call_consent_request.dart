import 'package:flutter/foundation.dart';

enum CallType {
  audio,
  video;

  String get value => name;

  static CallType fromString(String? type) {
    if (type?.toLowerCase() == 'video') return CallType.video;
    return CallType.audio;
  }
}

enum CallConsentStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled;

  String get value => name;

  static CallConsentStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return CallConsentStatus.accepted;
      case 'declined':
        return CallConsentStatus.declined;
      case 'expired':
        return CallConsentStatus.expired;
      case 'cancelled':
        return CallConsentStatus.cancelled;
      default:
        return CallConsentStatus.pending;
    }
  }
}

/// Domain entity representing a Two-Way Call Consent & Permission Handshake request.
/// Strictly enforces privacy and anti-harassment by requiring receiver consent
/// before any WebRTC / Agora media stream is opened.
@immutable
class CallConsentRequest {
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final CallType callType;
  final CallConsentStatus status;
  final DateTime timestamp;
  final int ttl; // Default: 30 seconds

  const CallConsentRequest({
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.callType,
    this.status = CallConsentStatus.pending,
    required this.timestamp,
    this.ttl = 30,
  });

  bool get isExpired {
    final diff = DateTime.now().difference(timestamp).inSeconds;
    return diff >= ttl || status == CallConsentStatus.expired;
  }

  int get remainingSeconds {
    final elapsed = DateTime.now().difference(timestamp).inSeconds;
    final left = ttl - elapsed;
    return left > 0 ? left : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      if (callerAvatarUrl != null) 'callerAvatarUrl': callerAvatarUrl,
      'callType': callType.value,
      'status': status.value,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl,
    };
  }

  factory CallConsentRequest.fromMap(Map<String, dynamic> map) {
    return CallConsentRequest(
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? 'Caller',
      callerAvatarUrl: map['callerAvatarUrl'] as String?,
      callType: CallType.fromString(map['callType'] as String?),
      status: CallConsentStatus.fromString(map['status'] as String?),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      ttl: (map['ttl'] as num?)?.toInt() ?? 30,
    );
  }

  CallConsentRequest copyWith({
    String? callerId,
    String? callerName,
    String? callerAvatarUrl,
    CallType? callType,
    CallConsentStatus? status,
    DateTime? timestamp,
    int? ttl,
  }) {
    return CallConsentRequest(
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatarUrl: callerAvatarUrl ?? this.callerAvatarUrl,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
    );
  }
}
