import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';

/// Modal bottom sheet allowing User A to browse and purchase real-world micro-gifts for User B
class MicroGiftBottomSheet extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final List<String> recipientTreats;
  final String senderId;
  final String senderName;

  const MicroGiftBottomSheet({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientTreats,
    required this.senderId,
    required this.senderName,
  });

  static Future<MicroGiftVoucher?> show({
    required BuildContext context,
    required String recipientId,
    required String recipientName,
    required List<String> recipientTreats,
    required String senderId,
    required String senderName,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<MicroGiftVoucher>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MicroGiftBottomSheet(
        recipientId: recipientId,
        recipientName: recipientName,
        recipientTreats: recipientTreats,
        senderId: senderId,
        senderName: senderName,
      ),
    );
  }

  @override
  State<MicroGiftBottomSheet> createState() => _MicroGiftBottomSheetState();
}

class _MicroGiftBottomSheetState extends State<MicroGiftBottomSheet> {
  final _firestore = FirestoreService();
  String? _purchasingGiftId;

  bool _isPreferred(MicroGiftItem item) {
    if (widget.recipientTreats.isEmpty) return false;
    final itemTreat = item.treatTag.toLowerCase();
    return widget.recipientTreats.any((t) {
      final treat = t.toLowerCase();
      return treat.contains(itemTreat) ||
          itemTreat.contains(treat) ||
          (itemTreat.contains('chocolate') && treat.contains('chocolate')) ||
          (itemTreat.contains('coffee') && treat.contains('coffee')) ||
          (itemTreat.contains('pastry') && (treat.contains('pastries') || treat.contains('boba')));
    });
  }

  Future<void> _purchaseGift(MicroGiftItem gift) async {
    setState(() => _purchasingGiftId = gift.id);
    HapticFeedback.selectionClick();

    // Simulate instant fintech authorization & cryptographic token generation
    await Future.delayed(const Duration(milliseconds: 700));

    final voucher = MicroGiftVoucher.create(
      gift: gift,
      senderId: widget.senderId,
      senderName: widget.senderName,
      recipientId: widget.recipientId,
      recipientName: widget.recipientName,
    );

    // Persist in Firestore
    await _firestore.saveGiftVoucher(voucher);

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.of(context).pop(voucher);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.recipientName.split(' ').first;
    final primaryTreat = widget.recipientTreats.isNotEmpty
        ? widget.recipientTreats.first
        : 'Dark Chocolate';

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.deepObsidianSlate,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.frostedBorder, width: 1.5),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neonElectricMint.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonElectricMint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.neonElectricMint.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.neonElectricMint,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Real-World Micro-Gifting',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iceWhite,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send a claimable treat straight into your chat',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.titaniumSlate.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.titaniumSlate),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Recipient's Preferred Treat Highlight Banner (Requirement 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.neonElectricMint.withValues(alpha: 0.15),
                      AppColors.midnightMarine,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.neonElectricMint.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.neonElectricMint,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12.5, color: AppColors.iceWhite),
                          children: [
                            TextSpan(
                              text: '$firstName prefers ',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: primaryTreat,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.neonElectricMint,
                              ),
                            ),
                            const TextSpan(
                              text: ' 💖',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Gift Catalog Cards
              ...MicroGiftItem.catalog.map((item) {
                final isPreferred = _isPreferred(item);
                final isProcessing = _purchasingGiftId == item.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildGiftItemCard(item, isPreferred, isProcessing),
                );
              }),

              const SizedBox(height: 4),

              // Regulatory Non-Cash Disclaimer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.midnightMarine,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.frostedBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.titaniumSlate,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Item-specific partner voucher. Cash-out is strictly disabled. Valid for 48 hours.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.titaniumSlate.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftItemCard(MicroGiftItem item, bool isPreferred, bool isProcessing) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.midnightMarine,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPreferred
              ? AppColors.neonElectricMint.withValues(alpha: 0.6)
              : AppColors.frostedBorder,
          width: isPreferred ? 1.5 : 1,
        ),
        boxShadow: isPreferred
            ? [
                BoxShadow(
                  color: AppColors.neonElectricMint.withValues(alpha: 0.08),
                  blurRadius: 16,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji Avatar
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deepObsidianSlate,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPreferred
                        ? AppColors.neonElectricMint.withValues(alpha: 0.4)
                        : AppColors.frostedBorder,
                  ),
                ),
                child: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.iceWhite,
                            ),
                          ),
                        ),
                        // Price Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.neonElectricMint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.neonElectricMint.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${item.currency}${item.price}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.neonElectricMint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.titaniumSlate.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 12,
                          color: AppColors.titaniumSlate,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.partner,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.titaniumSlate,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isPreferred)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonElectricMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: AppColors.neonElectricMint),
                      const SizedBox(width: 4),
                      Text(
                        'Matches ${widget.recipientName.split(' ').first}\'s treat!',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonElectricMint,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              GestureDetector(
                onTap: _purchasingGiftId != null ? null : () => _purchaseGift(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPreferred
                        ? AppColors.neonElectricMint
                        : AppColors.iceWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.deepObsidianSlate,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flash_on_rounded,
                              size: 14,
                              color: AppColors.deepObsidianSlate,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Send ${item.currency}${item.price}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepObsidianSlate,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
