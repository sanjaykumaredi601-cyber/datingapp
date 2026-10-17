import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'voucher_redemption_modal.dart';

/// Interactive Chat Bubble Card for Real-World Micro-Gifts with Live Countdown & Voucher Modal
class ChatGiftCardWidget extends StatefulWidget {
  final MicroGiftVoucher voucher;
  final bool isMine;
  final VoidCallback? onClaimed;

  const ChatGiftCardWidget({
    super.key,
    required this.voucher,
    required this.isMine,
    this.onClaimed,
  });

  @override
  State<ChatGiftCardWidget> createState() => _ChatGiftCardWidgetState();
}

class _ChatGiftCardWidgetState extends State<ChatGiftCardWidget> {
  late MicroGiftVoucher _voucher;
  final _firestore = FirestoreService();
  Timer? _ticker;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _voucher = widget.voucher;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ChatGiftCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voucher != widget.voucher) {
      _voucher = widget.voucher;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    setState(() => _isClaiming = true);
    HapticFeedback.mediumImpact();

    await _firestore.claimGiftVoucher(_voucher.voucherId);
    final updated = await _firestore.getGiftVoucher(_voucher.voucherId);

    if (mounted) {
      setState(() {
        _isClaiming = false;
        if (updated != null) _voucher = updated;
      });
      HapticFeedback.heavyImpact();
      widget.onClaimed?.call();

      // Automatically open redemption modal
      VoucherRedemptionModal.show(
        context: context,
        voucher: _voucher,
        isRecipient: !widget.isMine,
        onVoucherUpdated: () async {
          final refreshed = await _firestore.getGiftVoucher(_voucher.voucherId);
          if (mounted && refreshed != null) {
            setState(() => _voucher = refreshed);
          }
        },
      );
    }
  }

  void _openVoucherModal() {
    VoucherRedemptionModal.show(
      context: context,
      voucher: _voucher,
      isRecipient: !widget.isMine,
      onVoucherUpdated: () async {
        final refreshed = await _firestore.getGiftVoucher(_voucher.voucherId);
        if (mounted && refreshed != null) {
          setState(() => _voucher = refreshed);
        }
      },
    );
  }

  String _getEmoji(String giftId) {
    if (giftId.contains('coffee')) return '☕';
    if (giftId.contains('chocolate')) return '🍫';
    return '🧁';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _voucher.remainingTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    final countdownStr = remaining == Duration.zero
        ? 'Expired'
        : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isRecipient = !widget.isMine;
    final emoji = _getEmoji(_voucher.giftId);

    return Container(
      width: 290,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F131D), // Deep Obsidian Slate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4D67).withValues(alpha: 0.65), // Sunset Coral border accent
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D67).withValues(alpha: 0.22), // Sunset Coral glow
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.18), // Warm Gold glow
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Bar with dual-glow Sunset Coral to Warm Gold gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF4D67).withValues(alpha: 0.28),
                    const Color(0xFFFBBF24).withValues(alpha: 0.20),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 15,
                    color: Color(0xFFFF4D67),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'REAL-WORLD MICRO-GIFT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF8FAFC),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  // Price Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.deepObsidianSlate,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_voucher.currency}${_voucher.giftPrice}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iceWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.deepObsidianSlate,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.frostedBorder),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _voucher.designatedItem,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.iceWhite,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _voucher.partnerName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFF472B6), // Rose Gold accent
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Countdown & Status Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.deepObsidianSlate,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: remaining == Duration.zero
                              ? AppColors.error
                              : const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expires: $countdownStr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: remaining == Duration.zero
                                ? AppColors.error
                                : const Color(0xFFFBBF24),
                          ),
                        ),
                        const Spacer(),
                        if (_voucher.isRedeemedAtPartner)
                          const Text(
                            'Redeemed ✅',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF00D2FF),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else if (_voucher.isClaimed)
                          const Text(
                            'Claimed ✅',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF00F5A0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Non-cash reminder microcopy
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 10, color: AppColors.titaniumSlate),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Single-use item voucher • Non-transferable • No cash-out',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.titaniumSlate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Action Button: Gradient fill from Sunset Coral (#FF4D67) to Electric Iris (#7928CA)
                  if (isRecipient && !_voucher.isClaimed)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isClaiming ? null : _handleClaim,
                        child: _isClaiming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.redeem_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Claim Gift & Open Voucher',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
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
                          side: BorderSide(
                            color: _voucher.isClaimed
                                ? const Color(0xFFFF4D67).withValues(alpha: 0.6)
                                : AppColors.frostedBorder,
                          ),
                          backgroundColor: _voucher.isClaimed
                              ? const Color(0xFFFF4D67).withValues(alpha: 0.12)
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openVoucherModal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 16,
                              color: _voucher.isClaimed
                                  ? const Color(0xFFFF4D67)
                                  : AppColors.iceWhite,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isRecipient
                                  ? (_voucher.isRedeemedAtPartner
                                      ? 'View Redeemed Voucher'
                                      : 'Open Voucher (QR & Code)')
                                  : 'View Voucher Status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _voucher.isClaimed
                                    ? const Color(0xFFFF4D67)
                                    : AppColors.iceWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
