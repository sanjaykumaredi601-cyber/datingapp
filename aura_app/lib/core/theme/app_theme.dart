import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.sunsetCoral,
      secondary: AppColors.electricIris,
      tertiary: AppColors.softGold,
      surface: AppColors.surfaceL1,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    ),

    // ── AppBar ────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
    ),

    // ── Text ──────────────────────────────────────────────
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -1.0),
      headlineLarge: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
      headlineMedium:TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      headlineSmall: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5),
      bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary, letterSpacing: 0.2),
      labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.5),
      labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.0),
    ),

    // ── Input Fields (Crisp White + Soft Warm Rose Border) ───
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceL1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sunsetCoral, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ── Elevated Button ────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sunsetCoral,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
    ),

    // ── Text Button ────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.sunsetCoral,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // ── Card (Crisp White with Soft Warm Rose Border) ──────
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Chip ──────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceL2,
      selectedColor: AppColors.sunsetCoral.withValues(alpha: 0.15),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(color: AppColors.sunsetCoral, fontSize: 13, fontWeight: FontWeight.w600),
      side: const BorderSide(color: AppColors.cardBorder, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // ── Slider ────────────────────────────────────────────
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.sunsetCoral,
      inactiveTrackColor: AppColors.surfaceL2,
      thumbColor: AppColors.sunsetCoral,
      overlayColor: AppColors.sunsetCoral.withValues(alpha: 0.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      trackHeight: 3,
    ),

    // ── Bottom Navigation ─────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: AppColors.sunsetCoral,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      elevation: 0,
    ),

    // ── Bottom Sheet ──────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceL1,
      modalBackgroundColor: AppColors.surfaceL1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      dragHandleColor: AppColors.textTertiary,
      showDragHandle: true,
    ),

    // ── Divider ───────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
      space: 0,
    ),
  );

  /// Seamless alias: darkTheme maps to lightTheme to ensure universal consistency across entire app
  static ThemeData get darkTheme => lightTheme;
}
