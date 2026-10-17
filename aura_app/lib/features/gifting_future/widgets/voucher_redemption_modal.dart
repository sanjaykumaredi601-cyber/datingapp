import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'dynamic_qr_code_widget.dart';

/// Modal dialog displaying the single-use dynamic QR code, alphanumeric voucher code,
/// and partner redemption instructions with strict non-cash enforcement.
class VoucherRedemptionModal extends StatefulWidget {
  final MicroGiftVoucher voucher;
  final bool isRecipient;
  final VoidCallback? onVoucherUpdated;

  const VoucherRedemptionModal({
    super.key,
    required this.voucher,
    this.isRecipient = true,
    this.onVoucherUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required MicroGiftVoucher voucher,
    bool isRecipient = true,
    VoidCallback? onVoucherUpdated,
  }) {
    HapticFeedback.lightImpact();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => VoucherRedemptionModal(
        voucher: voucher,
        isRecipient: isRecipient,
        onVoucherUpdated: onVoucherUpdated,
      ),
    );
  }

  @override
  State<VoucherRedemptionModal> createState() => _VoucherRedemptionModalState();
}

class _VoucherRedemptionModalState extends State<VoucherRedemptionModal> {
  late MicroGiftVoucher _currentVoucher;
  final _firestore = FirestoreService();
  Timer? _countdownTimer;
  bool _copied = false;
  bool _isRedeeming = false;

  @override
  void initState() {
    super.initState();
    _currentVoucher = widget.voucher;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _currentVoucher.singleUseCode));
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _simulatePartnerRedemption() async {
    setState(() => _isRedeeming = true);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 900));
    await _firestore.redeemPartnerVoucher(_currentVoucher.voucherId);

    final updated = await _firestore.getGiftVoucher(_currentVoucher.voucherId);
    if (mounted) {
      setState(() {
        _isRedeeming = false;
        if (updated != null) _currentVoucher = updated;
      });
      HapticFeedback.heavyImpact();
      widget.onVoucherUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _currentVoucher.remainingTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    final countdownStr = remaining == Duration.zero
        ? 'Expired'
        : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.deepObsidianSlate,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _currentVoucher.isRedeemedAtPartner
                ? AppColors.cyanGlow.withValues(alpha: 0.5)
                : AppColors.neonElectricMint.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonElectricMint.withValues(alpha: 0.12),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar with Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentVoucher.isRedeemedAtPartner
                          ? AppColors.cyanGlow.withValues(alpha: 0.15)
                          : AppColors.neonElectricMint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentVoucher.isRedeemedAtPartner
                            ? AppColors.cyanGlow
                            : AppColors.neonElectricMint,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentVoucher.isRedeemedAtPartner
                              ? Icons.check_circle_rounded
                              : Icons.verified_rounded,
                          size: 13,
                          color: _currentVoucher.isRedeemedAtPartner
                              ? AppColors.cyanGlow
                              : AppColors.neonElectricMint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentVoucher.isRedeemedAtPartner
                              ? 'REDEEMED'
                              : 'AUTHENTIC VOUCHER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _currentVoucher.isRedeemedAtPartner
                                ? AppColors.cyanGlow
                                : AppColors.neonElectricMint,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.titaniumSlate),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Gift Title & Partner
              Text(
                _currentVoucher.designatedItem,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.iceWhite,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront_rounded, size: 14, color: AppColors.neonElectricMint),
                  const SizedBox(width: 6),
                  Text(
                    _currentVoucher.partnerName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonElectricMint,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Dynamic QR Code Container
              DynamicQrCodeWidget(
                data: 'AURA_REDEEM:${_currentVoucher.singleUseCode}:${_currentVoucher.securityHash.substring(0, 16)}',
                size: 180,
                centerLabel: _currentVoucher.partnerName.contains('Starbucks')
                    ? 'SBX'
                    : (_currentVoucher.partnerName.contains('Blinkit') ? 'BLNK' : 'THEO'),
              ),

              const SizedBox(height: 16),

              // Alphanumeric Single-Use Code Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.midnightMarine,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.frostedBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentVoucher.singleUseCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.iceWhite,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _copyCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _copied
                              ? AppColors.neonElectricMint
                              : AppColors.neonElectricMint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _copied ? 'COPIED' : 'COPY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _copied
                                ? AppColors.deepObsidianSlate
                                : AppColors.neonElectricMint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Countdown Timer & Validity
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: remaining == Duration.zero
                        ? AppColors.error
                        : AppColors.softGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expires in: $countdownStr',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: remaining == Duration.zero
                          ? AppColors.error
                          : AppColors.softGold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Strict Non-Cash Legal Disclaimer (Fintech requirement)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.softGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.do_not_disturb_alt_rounded,
                          color: AppColors.softGold,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'CASH-OUT IS STRICTLY DISABLED',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.softGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Redemption is restricted strictly to 1x ${_currentVoucher.designatedItem} at ${_currentVoucher.partnerName}. Non-transferable, non-refundable, and cannot be converted to cash or wallet balance.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        color: AppColors.titaniumSlate.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Cryptographic Hash Audit Trace
              Text(
                'Security Hash: SHA256-${_currentVoucher.securityHash.substring(0, 16)}...',
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: AppColors.textTertiary,
                ),
              ),

              const SizedBox(height: 16),

              // In-store Scan / Redeem Partner Button
              if (!_currentVoucher.isRedeemedAtPartner && widget.isRecipient)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonElectricMint,
                      foregroundColor: AppColors.deepObsidianSlate,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isRedeeming ? null : _simulatePartnerRedemption,
                    child: _isRedeeming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.deepObsidianSlate,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Simulate Counter Scan / Claim',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.frostedBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: AppColors.iceWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
