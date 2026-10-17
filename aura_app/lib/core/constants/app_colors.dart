import 'package:flutter/material.dart';

/// Aura Bright, Warm & Colorful Dating Palette
/// Matching the findaura.co daylight aesthetic:
/// Base Background: Soft Creamy Peach Pearl (#FFF9F7)
/// Card Surfaces: Crisp White (#FFFFFF) & Soft Rose Pearl (#FFF1F2)
/// Frosted Borders: Soft Warm Rose (#FFE4E6)
/// Primary Accent: Sunset Coral (#FF3366) & Peach Glow (#FF6B6B)
/// Secondary Accent: Electric Iris (#8B5CF6) & Sky Cyan (#06B6D4)
/// VIP / Verified Accents: Sunshine Gold (#F59E0B) & Emerald Mint (#10B981)
/// Text: High-Contrast Deep Charcoal Slate (#181829) & Slate Body (#4B5563)
class AppColors {
  AppColors._();

  // ── Surface & Background Architecture ──────────────────
  static const Color background        = Color(0xFFFFF9F7); // Warm Creamy Peach Pearl (#FFF9F7)
  static const Color deepObsidianSlate = Color(0xFFFFF9F7); // Compatibility alias
  static const Color deepSpaceObsidian = Color(0xFFFFF9F7); // Compatibility alias
  static const Color midnightMarine    = Color(0xFFFFFFFF); // Crisp White Surface (#FFFFFF)
  static const Color surfaceL1         = Color(0xFFFFFFFF); // Container Card Surface
  static const Color surfaceL2         = Color(0xFFFFF1F2); // Elevated Soft Peach/Rose (#FFF1F2)
  static const Color card              = Color(0xFFFFFFFF); // Container Card Surface
  static const Color cardBorder        = Color(0xFFFFE4E6); // Delicate Warm Rose Border (#FFE4E6)
  static const Color frostedBorder     = Color(0xFFFFE4E6); // Delicate Warm Rose Border

  // ── Brand Accents (Vibrant Warm Dating) ─────────────────
  static const Color sunsetCoral       = Color(0xFFFF3366); // Sunset Coral (#FF3366)
  static const Color sunsetPeach       = Color(0xFFFF6B6B); // Sunset Peach (#FF6B6B)
  static const Color primary           = Color(0xFFFF3366); // Main Brand Accent
  static const Color cyanGlow          = Color(0xFF06B6D4); // Sky Cyan Accent (#06B6D4)
  static const Color secondary         = Color(0xFF8B5CF6); // Electric Iris / Lavender (#8B5CF6)
  static const Color softGold          = Color(0xFFF59E0B); // Amber Sunshine / VIP Accent (#F59E0B)
  static const Color electricLavender  = Color(0xFF8B5CF6); // Electric Lavender
  static const Color neonElectricMint  = Color(0xFF10B981); // Emerald Mint (#10B981)

  // ── Text Hierarchy (Deep Charcoal Slate & Soft Slate) ───
  static const Color textPrimary       = Color(0xFF181829); // Deep Charcoal Slate (#181829)
  static const Color textSecondary     = Color(0xFF4B5563); // Slate Body (#4B5563)
  static const Color textTertiary      = Color(0xFF6B7280); // Muted Slate (#6B7280)
  static const Color textDisabled      = Color(0xFF9CA3AF); // Disabled Gray
  static const Color iceWhite          = Color(0xFF181829); // High-contrast primary text alias
  static const Color titaniumSlate     = Color(0xFF4B5563); // Slate secondary text alias

  // ── Romantic Design Tokens ─────────────────────────────
  static const Color electricIris      = Color(0xFF8B5CF6); // Electric Iris (#8B5CF6)
  static const Color electricIrisViolet = Color(0xFF7C3AED);
  static const Color mintGreen         = neonElectricMint;
  static const Color warmAmber         = softGold;
  static const Color vividCyan         = cyanGlow;
  static const Color auroraTeal        = neonElectricMint;
  static const Color auroraPurple      = Color(0xFF8B5CF6);
  static const Color auroraGold        = softGold;
  static const Color auroraPink        = Color(0xFFFF3366);

  static const LinearGradient romanticNodeGradient = LinearGradient(
    colors: [Color(0xFFFF3366), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Status & State ─────────────────────────────────────
  static const Color success           = Color(0xFF10B981);
  static const Color online            = Color(0xFF10B981);
  static const Color warning           = Color(0xFFF59E0B);
  static const Color error             = Color(0xFFEF4444);

  // ── Glassmorphism & Frosted Borders ────────────────────
  static const Color glassBackground   = Color(0xEBFFFFFF); // 92% White Glass
  static const Color glassBorder       = Color(0xFFFFE4E6); // Delicate Warm Rose Border

  static const Color roseGold          = Color(0xFFF472B6);
  static const Color warmGold          = Color(0xFFF59E0B);

  // ── Gradients ──────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [sunsetCoral, sunsetPeach],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraGradient = LinearGradient(
    colors: [sunsetCoral, sunsetPeach],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraGradientFull = LinearGradient(
    colors: [sunsetCoral, sunsetPeach, electricLavender],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sentBubbleGradient = LinearGradient(
    colors: [sunsetCoral, sunsetPeach],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceL1, surfaceL2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vipGoldGradient = LinearGradient(
    colors: [softGold, Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient verificationBadgeGradient = LinearGradient(
    colors: [softGold, neonElectricMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFFFFF1F2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Heatmap Zone Colors ────────────────────────────────
  static const Color heatmapLow        = Color(0x3306B6D4);
  static const Color heatmapMedium     = Color(0x4010B981);
  static const Color heatmapHigh       = Color(0x4DF59E0B);
}
