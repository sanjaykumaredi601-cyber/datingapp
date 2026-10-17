import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloud Firestore document model for /vouchers collection
class VoucherDocument {
  final String voucherId;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String type; // 'coffee' | 'drink' | 'sweet' | 'custom'
  final String title;
  final double amount;
  final String currency; // 'INR' | 'CAD' | 'USD'
  final String status; // 'ACTIVE' | 'REDEEMED' | 'EXPIRED'
  final String redemptionCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? message;

  VoucherDocument({
    required this.voucherId,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.amount,
    this.currency = 'INR',
    this.status = 'ACTIVE',
    required this.redemptionCode,
    required this.createdAt,
    required this.expiresAt,
    this.message,
  });

  Map<String, dynamic> toMap() => {
        'voucherId': voucherId,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'type': type,
        'title': title,
        'amount': amount,
        'currency': currency,
        'status': status,
        'redemptionCode': redemptionCode,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'message': message,
      };

  factory VoucherDocument.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return VoucherDocument(
      voucherId: map['voucherId'] as String? ?? docId,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Aura Member',
      recipientId: map['recipientId'] as String? ?? '',
      type: map['type'] as String? ?? 'coffee',
      title: map['title'] as String? ?? 'Specialty Coffee Voucher',
      amount: (map['amount'] as num?)?.toDouble() ?? 250.0,
      currency: map['currency'] as String? ?? 'INR',
      status: map['status'] as String? ?? 'ACTIVE',
      redemptionCode: map['redemptionCode'] as String? ?? 'COFFEE-AURA',
      createdAt: parseTime(map['createdAt']),
      expiresAt: parseTime(map['expiresAt']),
      message: map['message'] as String?,
    );
  }
}
