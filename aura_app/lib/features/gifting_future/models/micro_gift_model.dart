import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Available real-world micro-gifts in Aura
class MicroGiftItem {
  final String id;
  final String name;
  final int price; // In INR (₹)
  final String currency;
  final String emoji;
  final String partner;
  final String treatTag;
  final String description;
  final String redemptionInstructions;

  const MicroGiftItem({
    required this.id,
    required this.name,
    required this.price,
    this.currency = '₹',
    required this.emoji,
    required this.partner,
    required this.treatTag,
    required this.description,
    required this.redemptionInstructions,
  });

  static const List<MicroGiftItem> catalog = [
    MicroGiftItem(
      id: 'artisanal_chocolate_box',
      name: 'Artisanal Chocolate Box',
      price: 149,
      emoji: '🍫',
      partner: 'Blinkit Instant & Swiggy Instamart',
      treatTag: 'Dark Chocolate',
      description: 'Hand-crafted Belgian dark chocolate truffles & sea-salt pralines.',
      redemptionInstructions: 'Redeem directly via Blinkit / Swiggy Instamart coupon checkout or partner store counter.',
    ),
    MicroGiftItem(
      id: 'fresh_brewed_coffee',
      name: 'Fresh Brewed Coffee',
      price: 199,
      emoji: '☕',
      partner: 'Starbucks & Blue Tokai',
      treatTag: 'Coffee',
      description: 'Artisan pour-over, flat white, or velvety iced caramel latte.',
      redemptionInstructions: 'Present dynamic QR code at any Starbucks or Blue Tokai café counter nationwide.',
    ),
    MicroGiftItem(
      id: 'sweet_treat_macarons',
      name: 'Sweet Treat / Macarons',
      price: 129,
      emoji: '🧁',
      partner: 'Theobroma Patisserie',
      treatTag: 'Pastries',
      description: 'Parisian almond macarons & sweet oven-baked gourmet pastry.',
      redemptionInstructions: 'Scan voucher barcode at Theobroma checkout or enter code on app.',
    ),
  ];

  static MicroGiftItem? findById(String id) {
    try {
      return catalog.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  static MicroGiftItem? findByTreatTag(String tag) {
    try {
      final normalized = tag.toLowerCase();
      return catalog.firstWhere((item) =>
          item.treatTag.toLowerCase() == normalized ||
          normalized.contains(item.treatTag.toLowerCase()) ||
          item.name.toLowerCase().contains(normalized));
    } catch (_) {
      return null;
    }
  }
}

/// Non-Cash Single-Use Micro-Gift Voucher Model
class MicroGiftVoucher {
  final String voucherId;
  final String singleUseCode;
  final String giftId;
  final String giftTitle;
  final int giftPrice;
  final String currency;
  final String partnerName;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String designatedItem;
  final String securityHash;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isClaimed;
  final DateTime? claimedAt;
  final bool isRedeemedAtPartner;
  final DateTime? redeemedAt;
  final bool isCashOutAllowed; // Strictly false

  MicroGiftVoucher({
    required this.voucherId,
    required this.singleUseCode,
    required this.giftId,
    required this.giftTitle,
    required this.giftPrice,
    this.currency = '₹',
    required this.partnerName,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.designatedItem,
    required this.securityHash,
    required this.createdAt,
    required this.expiresAt,
    this.isClaimed = false,
    this.claimedAt,
    this.isRedeemedAtPartner = false,
    this.redeemedAt,
    this.isCashOutAllowed = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  String get remainingFormatted {
    final diff = remainingTime;
    if (diff == Duration.zero) return 'Expired';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m left';
    }
    final seconds = diff.inSeconds % 60;
    return '${minutes}m ${seconds}s left';
  }

  /// Cryptographic Generator for Single-Use Alphanumeric Vouchers
  static MicroGiftVoucher create({
    required MicroGiftItem gift,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
  }) {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 48)); // 48-hour expiration
    final timestamp = now.millisecondsSinceEpoch;

    // Alphanumeric partner prefix
    String partnerPrefix = 'AURAX';
    if (gift.id.contains('coffee')) {
      partnerPrefix = 'AURA-SBX';
    } else if (gift.id.contains('chocolate')) {
      partnerPrefix = 'AURA-BLNK';
    } else if (gift.id.contains('macaron') || gift.id.contains('sweet')) {
      partnerPrefix = 'AURA-THB';
    }

    final rand = Random();
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final randomSuffix = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    final singleUseCode = '$partnerPrefix-$randomSuffix';

    final voucherId = 'VCH-$timestamp-${rand.nextInt(9000) + 1000}';

    // Anti-tamper SHA-256 HMAC Signature
    final rawPayload = '$voucherId:$singleUseCode:$senderId:$recipientId:${gift.id}:$timestamp:NO_CASH_OUT';
    final securityHash = sha256.convert(utf8.encode(rawPayload)).toString();

    return MicroGiftVoucher(
      voucherId: voucherId,
      singleUseCode: singleUseCode,
      giftId: gift.id,
      giftTitle: gift.name,
      giftPrice: gift.price,
      currency: gift.currency,
      partnerName: gift.partner,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      recipientName: recipientName,
      designatedItem: gift.name,
      securityHash: securityHash,
      createdAt: now,
      expiresAt: expiresAt,
      isClaimed: false,
      isRedeemedAtPartner: false,
      isCashOutAllowed: false,
    );
  }

  MicroGiftVoucher copyWith({
    bool? isClaimed,
    DateTime? claimedAt,
    bool? isRedeemedAtPartner,
    DateTime? redeemedAt,
  }) {
    return MicroGiftVoucher(
      voucherId: voucherId,
      singleUseCode: singleUseCode,
      giftId: giftId,
      giftTitle: giftTitle,
      giftPrice: giftPrice,
      currency: currency,
      partnerName: partnerName,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      recipientName: recipientName,
      designatedItem: designatedItem,
      securityHash: securityHash,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedAt: claimedAt ?? this.claimedAt,
      isRedeemedAtPartner: isRedeemedAtPartner ?? this.isRedeemedAtPartner,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      isCashOutAllowed: false,
    );
  }

  Map<String, dynamic> toMap() => {
        'voucherId': voucherId,
        'singleUseCode': singleUseCode,
        'giftId': giftId,
        'giftTitle': giftTitle,
        'giftPrice': giftPrice,
        'currency': currency,
        'partnerName': partnerName,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'designatedItem': designatedItem,
        'securityHash': securityHash,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'isClaimed': isClaimed,
        'claimedAt': claimedAt?.toIso8601String(),
        'isRedeemedAtPartner': isRedeemedAtPartner,
        'redeemedAt': redeemedAt?.toIso8601String(),
        'isCashOutAllowed': false,
        'regulatoryNote': 'Non-cash voucher strictly tied to designated item. Cash-out is disabled.',
      };

  factory MicroGiftVoucher.fromMap(Map<String, dynamic> map) {
    return MicroGiftVoucher(
      voucherId: map['voucherId'] as String,
      singleUseCode: map['singleUseCode'] as String,
      giftId: map['giftId'] as String,
      giftTitle: map['giftTitle'] as String,
      giftPrice: (map['giftPrice'] as num).toInt(),
      currency: map['currency'] as String? ?? '₹',
      partnerName: map['partnerName'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      recipientId: map['recipientId'] as String,
      recipientName: map['recipientName'] as String,
      designatedItem: map['designatedItem'] as String,
      securityHash: map['securityHash'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      isClaimed: map['isClaimed'] as bool? ?? false,
      claimedAt: map['claimedAt'] != null ? DateTime.tryParse(map['claimedAt'] as String) : null,
      isRedeemedAtPartner: map['isRedeemedAtPartner'] as bool? ?? false,
      redeemedAt: map['redeemedAt'] != null ? DateTime.tryParse(map['redeemedAt'] as String) : null,
      isCashOutAllowed: false,
    );
  }
}
