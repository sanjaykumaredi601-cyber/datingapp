import '../../data/models/voucher_document.dart';

abstract class VoucherRepository {
  Future<VoucherDocument> sendVoucher({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String type,
    required String title,
    required double amount,
    String currency = 'INR',
    String? message,
  });

  Future<List<VoucherDocument>> getVouchersForUser(String userId);

  Future<bool> redeemVoucher({
    required String voucherId,
    required String userId,
  });

  Stream<List<VoucherDocument>> watchUserVouchers(String userId);
}
