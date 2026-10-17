import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Ambience modes for location-aware weather theme engine
enum AmbienceThemeMode {
  snow,
  twilight,
  clearNight,
}

/// Rich visual tokens defining a dynamic location-aware weather theme
class AmbienceThemeData {
  final AmbienceThemeMode mode;
  final String displayName;
  final LinearGradient backgroundGradient;
  final RadialGradient ambientBloom;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color radarRingPrimary;
  final Color radarRingSecondary;
  final Color radarSweepStart;
  final Color centralBeaconGlow;
  final Color pillBackground;
  final Color pillBorder;
  final Color indicatorDot;
  final bool enableCrispSnowfall;

  const AmbienceThemeData({
    required this.mode,
    required this.displayName,
    required this.backgroundGradient,
    required this.ambientBloom,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.radarRingPrimary,
    required this.radarRingSecondary,
    required this.radarSweepStart,
    required this.centralBeaconGlow,
    required this.pillBackground,
    required this.pillBorder,
    required this.indicatorDot,
    required this.enableCrispSnowfall,
  });

  /// 1. SNOW THEME: For snowy, mountain, and winter regions (Manali, Banff, Alps, Toronto)
  factory AmbienceThemeData.snow() {
    return const AmbienceThemeData(
      mode: AmbienceThemeMode.snow,
      displayName: 'Glacial Snowfall · Manali Mode',
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF0F9FF),
          Color(0xFFE0F2FE),
          Color(0xFFFFF1F2),
          Color(0xFFFFF9F7),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ),
      ambientBloom: RadialGradient(
        colors: [
          Color(0x3538BDF8),
          Color(0x150284C7),
          Colors.transparent,
        ],
        stops: [0.0, 0.45, 1.0],
      ),
      primaryAccent: Color(0xFF0284C7),   // Ocean Frost Cyan
      secondaryAccent: Color(0xFF38BDF8), // Sky Ice
      radarRingPrimary: Color(0xFF0284C7),
      radarRingSecondary: Color(0xFF38BDF8),
      radarSweepStart: Color(0x300284C7),
      centralBeaconGlow: Color(0xFF0284C7),
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFBAE6FD),
      indicatorDot: Color(0xFF0284C7),
      enableCrispSnowfall: true,
    );
  }

  /// 2. TWILIGHT THEME: For warm romantic evening locations (Paris, Mumbai, Venice)
  factory AmbienceThemeData.twilight() {
    return const AmbienceThemeData(
      mode: AmbienceThemeMode.twilight,
      displayName: 'Twilight Bloom · Paris Mode',
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFF1F2),
          Color(0xFFFFE4E6),
          Color(0xFFFCE7F3),
          Color(0xFFFFF9F7),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ),
      ambientBloom: RadialGradient(
        colors: [
          Color(0x35FF3366),
          Color(0x188B5CF6),
          Colors.transparent,
        ],
        stops: [0.0, 0.50, 1.0],
      ),
      primaryAccent: AppColors.sunsetCoral,
      secondaryAccent: AppColors.electricIris,
      radarRingPrimary: AppColors.sunsetCoral,
      radarRingSecondary: AppColors.electricIris,
      radarSweepStart: Color(0x28FF3366),
      centralBeaconGlow: AppColors.sunsetCoral,
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFFFE4E6),
      indicatorDot: AppColors.sunsetCoral,
      enableCrispSnowfall: false,
    );
  }

  /// 3. CLEAR NIGHT THEME: Daylight cosmic warm pearl
  factory AmbienceThemeData.clearNight() {
    return const AmbienceThemeData(
      mode: AmbienceThemeMode.clearNight,
      displayName: 'Cosmic Starlight · Clear Night',
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF8FAFC),
          Color(0xFFF1F5F9),
          Color(0xFFFFF1F2),
          Color(0xFFFFF9F7),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ),
      ambientBloom: RadialGradient(
        colors: [
          Color(0x308B5CF6),
          Color(0x15FF3366),
          Colors.transparent,
        ],
        stops: [0.0, 0.50, 1.0],
      ),
      primaryAccent: AppColors.electricIris,
      secondaryAccent: AppColors.sunsetCoral,
      radarRingPrimary: AppColors.electricIris,
      radarRingSecondary: AppColors.sunsetCoral,
      radarSweepStart: Color(0x288B5CF6),
      centralBeaconGlow: AppColors.electricIris,
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFFFE4E6),
      indicatorDot: AppColors.electricIris,
      enableCrispSnowfall: false,
    );
  }
}

/// Weather & Ambience Theme Provider / Location Hook
class WeatherAmbienceProvider {
  static final Set<String> _snowKeywords = {
    'manali',
    'shimla',
    'solang',
    'banff',
    'calgary',
    'toronto',
    'alps',
    'snow',
    'winter',
    'iceland',
    'switzerland',
    'whistler',
    'aspen',
    'gulmarg',
    'ladakh',
    'leh',
    'himalaya',
    'vancouver',
    'ottawa',
    'montreal',
  };

  static final Set<String> _twilightKeywords = {
    'paris',
    'mumbai',
    'venice',
    'rome',
    'twilight',
    'sunset',
    'dusk',
    'kyoto',
    'tokyo',
  };

  /// Resolves the ambient theme for a location title and subtitle.
  /// If [forcedMode] is non-null, overrides the automatic detection.
  static AmbienceThemeData resolveTheme({
    required String title,
    required String subtitle,
    AmbienceThemeMode? forcedMode,
  }) {
    if (forcedMode != null) {
      switch (forcedMode) {
        case AmbienceThemeMode.snow:
          return AmbienceThemeData.snow();
        case AmbienceThemeMode.twilight:
          return AmbienceThemeData.twilight();
        case AmbienceThemeMode.clearNight:
          return AmbienceThemeData.clearNight();
      }
    }

    final query = ('$title $subtitle').toLowerCase();

    // Check snow & mountain locations
    for (final kw in _snowKeywords) {
      if (query.contains(kw)) {
        return AmbienceThemeData.snow();
      }
    }

    // Check twilight locations
    for (final kw in _twilightKeywords) {
      if (query.contains(kw)) {
        return AmbienceThemeData.twilight();
      }
    }

    return AmbienceThemeData.clearNight();
  }
}
