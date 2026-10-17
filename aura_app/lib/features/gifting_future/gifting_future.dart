/// ==============================================================================
/// AURA FUTURE ROADMAP MODULE: REAL-WORLD MICRO-GIFTING
/// ==============================================================================
/// This module isolates the models, cryptographic voucher generator, dynamic QR,
/// and interactive gifting sheets for future roadmap activation after the India
/// and Canada closed beta testing track.
///
/// Under Beta Track Guidelines:
/// - Real-world gifting UI (bottom sheet, chat input 🎁 icon, claim cards) is
///   held to focus user evaluation strictly on authentic compatibility, 500m
///   geohash proximity radar discovery, and end-to-end encrypted messaging.
/// - All underlying cryptographic voucher verification (SHA-256 HMAC anti-tamper,
///   partner prefixes for Starbucks/Blinkit/Theobroma, 48-hour expiration lifecycle)
///   is fully preserved in this isolated module.
/// ==============================================================================

library;

export 'models/micro_gift_model.dart';
export 'widgets/chat_gift_card_widget.dart';
export 'widgets/micro_gift_bottom_sheet.dart';
export 'widgets/voucher_redemption_modal.dart';
export 'widgets/dynamic_qr_code_widget.dart';
