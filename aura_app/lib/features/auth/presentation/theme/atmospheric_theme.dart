import 'package:flutter/material.dart';

/// The 4 distinct atmospheric environments
enum AtmosphericEnvironment {
  snow,
  rain,
  autumn,
  springDusk,
}

/// Dynamic destination with live temperature, timezone, and weather metadata
class AtmosphericDestination {
  final String locationName;
  final String region;
  final String country;
  final String weatherIcon;
  final String temperature;
  final String timeZoneAbbr;
  final int timeZoneOffsetMinutes;
  final AtmosphericEnvironment environment;
  final String assetPath;

  const AtmosphericDestination({
    required this.locationName,
    required this.region,
    required this.country,
    required this.weatherIcon,
    required this.temperature,
    this.timeZoneAbbr = 'IST',
    this.timeZoneOffsetMinutes = 330,
    required this.environment,
    required this.assetPath,
  });

  /// Calculates and formats the destination's current local time (e.g. 11:42 PM IST)
  String formatLiveTime([DateTime? customUtc]) {
    final utc = customUtc ?? DateTime.now().toUtc();
    final destTime = utc.add(Duration(minutes: timeZoneOffsetMinutes));
    final hour12 = destTime.hour % 12 == 0 ? 12 : destTime.hour % 12;
    final minuteStr = destTime.minute.toString().padLeft(2, '0');
    final ampm = destTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minuteStr $ampm $timeZoneAbbr';
  }

  /// Top Glassmorphic Pill Structure:
  /// [Condition Icon + Temp] • [Live Destination Time] • [City, Country]
  /// Matches exact regional examples:
  /// - ❄️ -3°C • 11:42 PM IST • Solang Valley, Manali
  /// - ❄️ -6°C • 12:12 PM MDT • Banff National Park, Canada
  /// - 🌸 16°C • 3:12 AM JST • Meguro River, Tokyo
  /// - 🌧️ 24°C • 11:42 PM IST • Marine Drive, Mumbai
  String get formattedPillText {
    final liveTime = formatLiveTime();
    return '$weatherIcon $temperature \u2022 $liveTime \u2022 $locationName';
  }

  /// Legacy compatible title & subtitle
  String get title => '$locationName $weatherIcon';
  String get subtitle => '$region, $country';
}

/// Rich visual tokens defining a dynamic atmospheric weather environment
class AtmosphericThemeData {
  final AtmosphericEnvironment environment;
  final String displayName;
  final LinearGradient backgroundGradient;
  final RadialGradient ambientBloom;
  final Color radarPrimaryAccent;
  final Color radarSecondaryAccent;
  final Color radarSweepStart;
  final Color centralBeaconGlow;
  final Color pillBackground;
  final Color pillBorder;
  final Color pillGlow;
  final Color indicatorDot;

  const AtmosphericThemeData({
    required this.environment,
    required this.displayName,
    required this.backgroundGradient,
    required this.ambientBloom,
    required this.radarPrimaryAccent,
    required this.radarSecondaryAccent,
    required this.radarSweepStart,
    required this.centralBeaconGlow,
    required this.pillBackground,
    required this.pillBorder,
    required this.pillGlow,
    required this.indicatorDot,
  });

  /// 1. SNOW / GLACIAL (e.g., Solang Valley, Manali / Banff, Canada)
  /// Background Gradient: Daylight Glacial Pearl & Frost (#F0F9FF -> #E0F2FE -> #FFF1F2 -> #FFF9F7)
  /// Radar Accent: Ocean Frost Cyan (#0284C7) & Sky Ice (#38BDF8)
  factory AtmosphericThemeData.snow() {
    const primary = Color(0xFF0284C7); // Ocean Frost Cyan
    const secondary = Color(0xFF38BDF8); // Sky Ice
    return const AtmosphericThemeData(
      environment: AtmosphericEnvironment.snow,
      displayName: 'Glacial Arctic Snow',
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
      radarPrimaryAccent: primary,
      radarSecondaryAccent: secondary,
      radarSweepStart: Color(0x300284C7),
      centralBeaconGlow: primary,
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFBAE6FD),
      pillGlow: Color(0x2538BDF8),
      indicatorDot: primary,
    );
  }

  /// 2. RAIN / STORM (e.g., Marine Drive, Mumbai / Vancouver)
  /// Background Gradient: Daylight Fresh Rain & Dew (#F1F5F9 -> #E2E8F0 -> #EEF2F6 -> #FFF9F7)
  /// Radar Accent: Electric Royal Blue (#2563EB) & Soft Iris (#818CF8)
  factory AtmosphericThemeData.rain() {
    const primary = Color(0xFF2563EB);
    const secondary = Color(0xFF818CF8);
    return const AtmosphericThemeData(
      environment: AtmosphericEnvironment.rain,
      displayName: 'Monsoon Storm',
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF1F5F9),
          Color(0xFFE2E8F0),
          Color(0xFFEEF2F6),
          Color(0xFFFFF9F7),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ),
      ambientBloom: RadialGradient(
        colors: [
          Color(0x3060A5FA),
          Color(0x152563EB),
          Colors.transparent,
        ],
        stops: [0.0, 0.48, 1.0],
      ),
      radarPrimaryAccent: primary,
      radarSecondaryAccent: secondary,
      radarSweepStart: Color(0x282563EB),
      centralBeaconGlow: primary,
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFCBD5E1),
      pillGlow: Color(0x202563EB),
      indicatorDot: primary,
    );
  }

  /// 3. AUTUMN (e.g., Mont-Royal, Montreal)
  /// Background Gradient: Daylight Golden Amber & Warm Sunlight (#FFFBEB -> #FEF3C7 -> #FFFFEDD5 -> #FFF9F7)
  /// Radar Accent: Amber Gold (#D97706) & Sunset Tangerine (#EA580C)
  factory AtmosphericThemeData.autumn() {
    const primary = Color(0xFFD97706);
    const secondary = Color(0xFFEA580C);
    return const AtmosphericThemeData(
      environment: AtmosphericEnvironment.autumn,
      displayName: 'Autumn Maple Twilight',
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFBEB),
          Color(0xFFFEF3C7),
          Color(0xFFFFEDD5),
          Color(0xFFFFF9F7),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ),
      ambientBloom: RadialGradient(
        colors: [
          Color(0x35F59E0B),
          Color(0x18EA580C),
          Colors.transparent,
        ],
        stops: [0.0, 0.50, 1.0],
      ),
      radarPrimaryAccent: primary,
      radarSecondaryAccent: secondary,
      radarSweepStart: Color(0x28D97706),
      centralBeaconGlow: primary,
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFFDE68A),
      pillGlow: Color(0x25F59E0B),
      indicatorDot: primary,
    );
  }

  /// 4. CHERRY BLOSSOM / SPRING DUSK (e.g., Tokyo, Japan)
  /// Background Gradient: Daylight Sakura Pearl & Coral Blush (#FFF1F2 -> #FFE4E6 -> #FCE7F3 -> #FFF9F7)
  /// Radar Accent: Sunset Coral (#FF3366) & Electric Iris (#8B5CF6)
  factory AtmosphericThemeData.springDusk() {
    const primary = Color(0xFFFF3366);
    const secondary = Color(0xFF8B5CF6);
    return const AtmosphericThemeData(
      environment: AtmosphericEnvironment.springDusk,
      displayName: 'Sakura Spring Dusk',
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
      radarPrimaryAccent: primary,
      radarSecondaryAccent: secondary,
      radarSweepStart: Color(0x28FF3366),
      centralBeaconGlow: primary,
      pillBackground: Color(0xF2FFFFFF),
      pillBorder: Color(0xFFFFE4E6),
      pillGlow: Color(0x25FF3366),
      indicatorDot: primary,
    );
  }

  /// Resolves theme data from enum
  factory AtmosphericThemeData.fromEnvironment(AtmosphericEnvironment env) {
    switch (env) {
      case AtmosphericEnvironment.snow:
        return AtmosphericThemeData.snow();
      case AtmosphericEnvironment.rain:
        return AtmosphericThemeData.rain();
      case AtmosphericEnvironment.autumn:
        return AtmosphericThemeData.autumn();
      case AtmosphericEnvironment.springDusk:
        return AtmosphericThemeData.springDusk();
    }
  }
}

/// Registry of curated destinations across the 4 environments
class AtmosphericDestinationsRegistry {
  static const List<AtmosphericDestination> defaultDestinations = [
    // 1. Manali (Snow)
    AtmosphericDestination(
      locationName: 'Solang Valley, Manali',
      region: 'Himachal Pradesh',
      country: 'India',
      weatherIcon: '❄️',
      temperature: '-3°C',
      timeZoneAbbr: 'IST',
      timeZoneOffsetMinutes: 330, // UTC +5:30
      environment: AtmosphericEnvironment.snow,
      assetPath: 'assets/images/romantic_paris.jpg',
    ),
    // 2. Banff (Snow / Glacial)
    AtmosphericDestination(
      locationName: 'Banff National Park, Canada',
      region: 'Alberta',
      country: 'Canada',
      weatherIcon: '❄️',
      temperature: '-6°C',
      timeZoneAbbr: 'MDT',
      timeZoneOffsetMinutes: -360, // UTC -6:00 (Mountain Daylight)
      environment: AtmosphericEnvironment.snow,
      assetPath: 'assets/images/romantic_paris.jpg',
    ),
    // 3. Tokyo (Cherry Blossom / Spring Dusk)
    AtmosphericDestination(
      locationName: 'Meguro River, Tokyo',
      region: 'Kanto',
      country: 'Japan',
      weatherIcon: '🌸',
      temperature: '18°C',
      timeZoneAbbr: 'JST',
      timeZoneOffsetMinutes: 540, // UTC +9:00
      environment: AtmosphericEnvironment.springDusk,
      assetPath: 'assets/images/romantic_kyoto.jpg',
    ),
    // 4. Mumbai (Rain / Monsoon Storm)
    AtmosphericDestination(
      locationName: 'Marine Drive, Mumbai',
      region: 'Maharashtra',
      country: 'India',
      weatherIcon: '🌧️',
      temperature: '24°C',
      timeZoneAbbr: 'IST',
      timeZoneOffsetMinutes: 330, // UTC +5:30
      environment: AtmosphericEnvironment.rain,
      assetPath: 'assets/images/romantic_venice.jpg',
    ),
    // 5. Montreal (Autumn Breeze)
    AtmosphericDestination(
      locationName: 'Mont-Royal, Montreal',
      region: 'Quebec',
      country: 'Canada',
      weatherIcon: '🍂',
      temperature: '12°C',
      timeZoneAbbr: 'EDT',
      timeZoneOffsetMinutes: -240, // UTC -4:00
      environment: AtmosphericEnvironment.autumn,
      assetPath: 'assets/images/romantic_santorini.jpg',
    ),
  ];

  /// Automatic detection based on location query
  static AtmosphericEnvironment detectEnvironment(String query) {
    final q = query.toLowerCase();

    // Snow keywords
    if (q.contains('manali') ||
        q.contains('banff') ||
        q.contains('snow') ||
        q.contains('solang') ||
        q.contains('shimla') ||
        q.contains('alps') ||
        q.contains('calgary') ||
        q.contains('aspen') ||
        q.contains('whistler')) {
      return AtmosphericEnvironment.snow;
    }

    // Rain / Monsoon keywords
    if (q.contains('mumbai') ||
        q.contains('rain') ||
        q.contains('storm') ||
        q.contains('monsoon') ||
        q.contains('cherrapunji') ||
        q.contains('vancouver') ||
        q.contains('marine drive') ||
        q.contains('london') ||
        q.contains('seattle')) {
      return AtmosphericEnvironment.rain;
    }

    // Autumn keywords
    if (q.contains('montreal') ||
        q.contains('autumn') ||
        q.contains('fall') ||
        q.contains('mont-royal') ||
        q.contains('maple') ||
        q.contains('boston') ||
        q.contains('toronto')) {
      return AtmosphericEnvironment.autumn;
    }

    // Spring Dusk / Sakura keywords
    return AtmosphericEnvironment.springDusk;
  }
}
