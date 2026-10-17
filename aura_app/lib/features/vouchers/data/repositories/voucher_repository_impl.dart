import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/voucher_repository.dart';
import '../models/voucher_document.dart';

class VoucherRepositoryImpl implements VoucherRepository {
  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  // In-memory cache for offline and test runs
  final List<VoucherDocument> _inMemoryVouchers = [];

  VoucherRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore,
        _uuid = const Uuid();

  String _generateRedemptionCode(String prefix) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return '$prefix-$code';
  }

  @override
  Future<VoucherDocument> sendVoucher({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String type,
    required String title,
    required double amount,
    String currency = 'INR',
    String? message,
  }) async {
    final now = DateTime.now();
    final voucher = VoucherDocument(
      voucherId: 'vch_${_uuid.v4().substring(0, 8)}',
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      type: type,
      title: title,
      amount: amount,
      currency: currency,
      status: 'ACTIVE',
      redemptionCode: _generateRedemptionCode(type.toUpperCase()),
      createdAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      message: message,
    );

    _inMemoryVouchers.add(voucher);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('vouchers')
            .doc(voucher.voucherId)
            .set(voucher.toMap());
      } catch (_) {}
    }

    return voucher;
  }

  @override
  Future<List<VoucherDocument>> getVouchersForUser(String userId) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final query = await firestore
            .collection('vouchers')
            .where('recipientId', isEqualTo: userId)
            .get();

        if (query.docs.isNotEmpty) {
          return query.docs
              .map((doc) => VoucherDocument.fromMap(doc.data(), doc.id))
              .toList();
        }
      } catch (_) {}
    }

    return _inMemoryVouchers
        .where((v) => v.recipientId == userId || v.senderId == userId)
        .toList();
  }

  @override
  Future<bool> redeemVoucher({
    required String voucherId,
    required String userId,
  }) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final docRef = firestore.collection('vouchers').doc(voucherId);
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data();
          if (data?['recipientId'] == userId && data?['status'] == 'ACTIVE') {
            await docRef.update({'status': 'REDEEMED', 'redeemedAt': Timestamp.now()});
            return true;
          }
        }
      } catch (_) {}
    }

    final index = _inMemoryVouchers.indexWhere((v) => v.voucherId == voucherId);
    if (index != -1 && _inMemoryVouchers[index].status == 'ACTIVE') {
      _inMemoryVouchers[index] = VoucherDocument(
        voucherId: _inMemoryVouchers[index].voucherId,
        senderId: _inMemoryVouchers[index].senderId,
        senderName: _inMemoryVouchers[index].senderName,
        recipientId: _inMemoryVouchers[index].recipientId,
        type: _inMemoryVouchers[index].type,
        title: _inMemoryVouchers[index].title,
        amount: _inMemoryVouchers[index].amount,
        currency: _inMemoryVouchers[index].currency,
        status: 'REDEEMED',
        redemptionCode: _inMemoryVouchers[index].redemptionCode,
        createdAt: _inMemoryVouchers[index].createdAt,
        expiresAt: _inMemoryVouchers[index].expiresAt,
        message: _inMemoryVouchers[index].message,
      );
      return true;
    }

    return false;
  }

  @override
  Stream<List<VoucherDocument>> watchUserVouchers(String userId) {
    final firestore = _firestore;
    if (firestore != null) {
      return firestore
          .collection('vouchers')
          .where('recipientId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => VoucherDocument.fromMap(doc.data(), doc.id))
              .toList());
    }

    return Stream.value(
      _inMemoryVouchers
          .where((v) => v.recipientId == userId || v.senderId == userId)
          .toList(),
    );
  }
}
