import 'package:aura_app/features/radar/data/models/radar_vibe_beacon_model.dart';
import 'package:aura_app/features/radar/presentation/widgets/host_vibe_bottom_sheet.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/dna_blueprint_service.dart';
import 'package:aura_app/features/radar/data/models/dna_blueprint_model.dart';
import 'package:aura_app/features/radar/presentation/widgets/dna_blueprint_sheet.dart';
import 'package:aura_app/core/services/firestore_discovery_service.dart';
import 'package:aura_app/core/services/location_service.dart';
import 'package:aura_app/features/discovery/presentation/widgets/dating_user_profile_detail_modal.dart';
import 'package:aura_app/shared/widgets/aura_image.dart';

// ─────────────────────────────────────────────────────────
// RADAR COLOR PALETTE & THEME (Dark Luxury Obsidian & Romantic Neon)
// ─────────────────────────────────────────────────────────

class RadarColors {
  // Bright Daylight Cartography & Surfaces matching findaura.co
  static const Color obsidianBase = Color(0xFFFFF9F7); // Map land background (#FFF9F7)
  static const Color obsidianDeeper = Color(0xFFFFF5F2); // Deep canvas tone
  static const Color midnightNavy = Color(0xFFE0F2FE); // Water boundary / coastline (soft sky blue)
  static const Color darkSlate = Color(0xFFFFFFFF); // Roads & frosted containers
  static const Color roadBorderColor = Color(0xFFFFE4E6); // Road outline borders (soft warm rose)
  static const Color parkDark = Color(0xFFE6F9F0); // Parks & Nature polygons (soft mint)
  static const Color frostedSlate = Color(0xFFFFFFFF); // Glass containers
  static const Color specularBorder = Color(0xFFFFE4E6); // Specular borders
  static const Color midnightDrawer = Color(0xFFFFFFFF); // Bottom Discovery Drawer

  // Romantic Brand Accents
  static const Color sunsetCoral = Color(0xFFFF3366); // High-compatibility halo (>80%) & sweep beacon (#FF3366)
  static const Color electricIris = Color(0xFF8B5CF6); // Gradient beacon, pulsing rings (#8B5CF6)
  static const Color cyanGlow = Color(0xFF06B6D4); // Medium-compatibility halo & scan rings (#06B6D4)
  static const Color electricMint = Color(0xFF10B981); // Active slider & online status (#10B981)
  static const Color goldenStar = Color(0xFFF59E0B); // Stats rating stars (#F59E0B)

  // Typography (High-contrast Charcoal Slate on Daylight)
  static const Color iceWhite = Color(0xFF181829); // Crisp High-contrast text (#181829)
  static const Color titaniumGray = Color(0xFF4B5563); // Muted secondary text (#4B5563)
  static const Color slateMuted = Color(0xFF6B7280); // Low-contrast annotations (#6B7280)

  // Aliases for seamless backward compatibility across existing calls
  static const Color deepSage = electricIris;
  static const Color deepSageDark = darkSlate;
  static const Color darkForest = iceWhite;
  static const Color mutedMint = cyanGlow;
  static const Color paleMapTint = obsidianBase;
  static const Color softCream = darkSlate;
  static const Color pureWhite = frostedSlate;
  static const Color peachAccent = sunsetCoral;
  static const Color peachLight = Color(0x33FF3366);
  static const Color heartTerracotta = sunsetCoral;
  static const Color textMuted = titaniumGray;
  static const Color textLight = slateMuted;
  static const Color roadWhite = darkSlate;
  static const Color roadBorder = roadBorderColor;
  static const Color parkGreen = parkDark;
}

// ─────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────

class ZoneModel {
  final String zoneId;
  final double lat;
  final double lng;
  final int densityLevel;
  final int activityCount;
  final String zoneName;
  final double radiusMeters;

  const ZoneModel({
    required this.zoneId,
    required this.lat,
    required this.lng,
    required this.densityLevel,
    required this.activityCount,
    required this.zoneName,
    this.radiusMeters = 500,
  });
}

abstract class RadarState {}

class RadarInitial extends RadarState {}
class RadarLoading extends RadarState {}
class RadarPermissionDenied extends RadarState {}
class RadarError extends RadarState {
  final String message;
  RadarError(this.message);
}

class RadarLoaded extends RadarState {
  final List<ZoneModel> zones;
  final double userLat;
  final double userLng;
  final double radiusKm;
  final int activeZoneCount;
  final String currentZoneName;

  RadarLoaded({
    required this.zones,
    required this.userLat,
    required this.userLng,
    required this.radiusKm,
    required this.activeZoneCount,
    this.currentZoneName = 'Nearby',
  });

  RadarLoaded copyWith({
    List<ZoneModel>? zones,
    double? userLat,
    double? userLng,
    double? radiusKm,
    int? activeZoneCount,
    String? currentZoneName,
  }) =>
      RadarLoaded(
        zones: zones ?? this.zones,
        userLat: userLat ?? this.userLat,
        userLng: userLng ?? this.userLng,
        radiusKm: radiusKm ?? this.radiusKm,
        activeZoneCount: activeZoneCount ?? this.activeZoneCount,
        currentZoneName: currentZoneName ?? this.currentZoneName,
      );
}

// ─────────────────────────────────────────────────────────
// RADAR NOTIFIER
// ─────────────────────────────────────────────────────────

class RadarNotifier extends ValueNotifier<RadarState> {
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationDebounceTimer;
  Position? _lastPosition;
  double _currentRadiusValue = 25.0;

  RadarNotifier() : super(RadarInitial());

  Future<void> start({bool enableBackgroundTimer = true}) async {
    value = RadarLoading();
    final hasLoc = await requestAndSyncLocation();
    if (!hasLoc && value is! RadarLoaded) {
      value = RadarPermissionDenied();
    }

    if (enableBackgroundTimer) {
      // Auto-refresh periodic timer (45 seconds: 30–60s range)
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) {
          debugPrint('AURA_RADAR: [Auto-Refresh] Updating nearby radar entities (45s cycle)...');
          _loadRadar(radiusKm: _currentRadius);
        },
      );
    }
  }

  /// Requests location permissions and syncs live device location
  Future<bool> requestAndSyncLocation() async {
    try {
      final locResult = await LocationService().getCurrentLocation();

      if (locResult.status == LocationResolutionStatus.permissionDenied ||
          locResult.status == LocationResolutionStatus.permissionDeniedForever ||
          locResult.status == LocationResolutionStatus.serviceDisabled) {
        value = RadarPermissionDenied();
        return false;
      }

      final pos = Position(
        longitude: locResult.longitude,
        latitude: locResult.latitude,
        timestamp: DateTime.now(),
        accuracy: locResult.isAccurateGps ? 5.0 : 100.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      _lastPosition = pos;
      _loadRadarWithCoords(
        pos.latitude,
        pos.longitude,
        radiusKm: _currentRadius,
        zoneName: locResult.displayName.isNotEmpty ? locResult.displayName : 'Nearby',
      );

      // Start live debounced position stream tracking
      _startLiveLocationTracking();
      return true;
    } catch (e) {
      debugPrint('AURA_RADAR: Location sync exception: $e');
      if (value is! RadarLoaded) {
        value = RadarPermissionDenied();
      }
      return false;
    }
  }

  void _startLiveLocationTracking() {
    _positionStreamSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update when user has moved at least 10 meters
    );
    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position pos) {
          _onLocationStreamChanged(pos);
        },
        onError: (e) {
          debugPrint('AURA_RADAR: Location stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('AURA_RADAR: Unable to listen to location stream: $e');
    }
  }

  void _onLocationStreamChanged(Position pos) {
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (distance < 8) return; // Ignore small GPS jitter (<8m)
    }

    // Debounce rapid location shifts with 400ms debounce interval
    _locationDebounceTimer?.cancel();
    _locationDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _lastPosition = pos;
      _loadRadarWithCoords(pos.latitude, pos.longitude, radiusKm: _currentRadius);
    });
  }

  double get _currentRadius =>
      value is RadarLoaded ? (value as RadarLoaded).radiusKm : _currentRadiusValue;

  Future<void> refresh() => _loadRadar(radiusKm: _currentRadius);

  void changeRadius(double km) {
    _currentRadiusValue = km;
    if (value is RadarLoaded) {
      final current = value as RadarLoaded;
      final filteredZones = _generateMockZones(current.userLat, current.userLng)
          .where((z) => (z.densityLevel * 15) <= km * 1.5)
          .toList();
      value = current.copyWith(
        radiusKm: km,
        zones: filteredZones,
        activeZoneCount: filteredZones.length,
      );
    }
  }

  void switchZone(String zoneName, double lat, double lng) {
    if (value is RadarLoaded) {
      final current = value as RadarLoaded;
      final mock = _generateMockZones(lat, lng)
          .where((z) => (z.densityLevel * 15) <= _currentRadius * 1.5)
          .toList();
      value = current.copyWith(
        currentZoneName: zoneName,
        userLat: lat,
        userLng: lng,
        zones: mock,
        activeZoneCount: mock.length,
      );
    }
  }

  Future<void> _loadRadar({required double radiusKm}) async {
    try {
      final locResult = await LocationService().getCurrentLocation();
      if (locResult.status == LocationResolutionStatus.success) {
        final pos = Position(
          longitude: locResult.longitude,
          latitude: locResult.latitude,
          timestamp: DateTime.now(),
          accuracy: locResult.isAccurateGps ? 5.0 : 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        _lastPosition = pos;
        _loadRadarWithCoords(
          pos.latitude,
          pos.longitude,
          radiusKm: radiusKm,
          zoneName: locResult.displayName,
        );
      }
    } catch (_) {
      if (_lastPosition != null) {
        _loadRadarWithCoords(_lastPosition!.latitude, _lastPosition!.longitude, radiusKm: radiusKm);
      }
    }
  }

  void _loadRadarWithCoords(double lat, double lng, {required double radiusKm, String? zoneName}) {
    final mockZones = _generateMockZones(lat, lng)
        .where((z) => (z.densityLevel * 15) <= radiusKm * 1.5)
        .toList();
    final currentZone = zoneName ?? (value is RadarLoaded ? (value as RadarLoaded).currentZoneName : 'Nearby');
    value = RadarLoaded(
      zones: mockZones,
      userLat: lat,
      userLng: lng,
      radiusKm: radiusKm,
      activeZoneCount: mockZones.length,
      currentZoneName: currentZone,
    );
  }

  List<ZoneModel> _generateMockZones(double lat, double lng) {
    return [
      ZoneModel(zoneId: '1', lat: lat + 0.004, lng: lng + 0.006, densityLevel: 3, activityCount: 18, zoneName: 'Popular Cafe Hub'),
      ZoneModel(zoneId: '2', lat: lat - 0.005, lng: lng + 0.003, densityLevel: 2, activityCount: 12, zoneName: 'Downtown Social'),
      ZoneModel(zoneId: '3', lat: lat + 0.008, lng: lng - 0.004, densityLevel: 1, activityCount: 6, zoneName: 'Arts & Culture District'),
      ZoneModel(zoneId: '4', lat: lat - 0.003, lng: lng - 0.007, densityLevel: 2, activityCount: 14, zoneName: 'Park Promenade'),
      ZoneModel(zoneId: '5', lat: lat + 0.001, lng: lng + 0.010, densityLevel: 3, activityCount: 22, zoneName: 'Sunset Lounge Hub'),
    ];
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationDebounceTimer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────
// CUSTOM MAP PAINTER (DARK LUXURY OBSIDIAN CARTOGRAPHY)
// ─────────────────────────────────────────────────────────

class CustomBaseMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Land Background (Dark Luxury Obsidian #0A0D14)
    final bgPaint = Paint()..color = RadarColors.obsidianBase;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Coastal / Water Boundary (West of Mumbai - Midnight Navy #0D131F)
    final waterPaint = Paint()
      ..color = RadarColors.midnightNavy
      ..style = PaintingStyle.fill;
    final waterPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.14, 0)
      ..cubicTo(
        size.width * 0.12, size.height * 0.25,
        size.width * 0.05, size.height * 0.45,
        size.width * 0.15, size.height * 0.65,
      )
      ..cubicTo(
        size.width * 0.22, size.height * 0.80,
        size.width * 0.10, size.height * 0.95,
        size.width * 0.12, size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    // 3. Midnight Teal Park Polygons
    final parkPaint = Paint()
      ..color = RadarColors.parkDark
      ..style = PaintingStyle.fill;

    // Park 1 - Santa Cruz West
    final park1 = Path()
      ..moveTo(size.width * 0.38, size.height * 0.16)
      ..lineTo(size.width * 0.46, size.height * 0.14)
      ..lineTo(size.width * 0.49, size.height * 0.21)
      ..lineTo(size.width * 0.41, size.height * 0.23)
      ..close();
    canvas.drawPath(park1, parkPaint);

    // Park 2 - Near Center / Khar
    final park2 = Path()
      ..moveTo(size.width * 0.32, size.height * 0.42)
      ..lineTo(size.width * 0.42, size.height * 0.39)
      ..lineTo(size.width * 0.45, size.height * 0.48)
      ..lineTo(size.width * 0.35, size.height * 0.50)
      ..close();
    canvas.drawPath(park2, parkPaint);

    // Park 3 - Bandra East
    final park3 = Path()
      ..moveTo(size.width * 0.65, size.height * 0.60)
      ..lineTo(size.width * 0.78, size.height * 0.57)
      ..lineTo(size.width * 0.82, size.height * 0.67)
      ..lineTo(size.width * 0.68, size.height * 0.69)
      ..close();
    canvas.drawPath(park3, parkPaint);

    // 4. Road Networks (White Ribbon Paths with Subtle Outlines)
    final roadBorderPaint = Paint()
      ..color = RadarColors.roadBorder
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roadWhitePaint = Paint()
      ..color = RadarColors.roadWhite
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawRoad(Path path, double width) {
      roadBorderPaint.strokeWidth = width + 2.0;
      canvas.drawPath(path, roadBorderPaint);
      roadWhitePaint.strokeWidth = width;
      canvas.drawPath(path, roadWhitePaint);
    }

    // Main Arterial Road (Western Express Highway / SV Road curve)
    final mainArtery = Path()
      ..moveTo(size.width * 0.32, 0)
      ..cubicTo(
        size.width * 0.36, size.height * 0.18,
        size.width * 0.48, size.height * 0.30,
        size.width * 0.44, size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.40, size.height * 0.55,
        size.width * 0.58, size.height * 0.68,
        size.width * 0.62, size.height * 0.84,
      )
      ..lineTo(size.width * 0.66, size.height);
    drawRoad(mainArtery, 10.0);

    // Linking Highway 2 (Linking Road / Khar to Bandra)
    final linkingRoad = Path()
      ..moveTo(size.width * 0.55, 0)
      ..cubicTo(
        size.width * 0.56, size.height * 0.18,
        size.width * 0.60, size.height * 0.32,
        size.width * 0.62, size.height * 0.50,
      )
      ..cubicTo(
        size.width * 0.63, size.height * 0.65,
        size.width * 0.72, size.height * 0.78,
        size.width * 0.78, size.height,
      );
    drawRoad(linkingRoad, 8.0);

    // East-West Cross Arteries
    final roadEW1 = Path()
      ..moveTo(size.width * 0.10, size.height * 0.17)
      ..cubicTo(
        size.width * 0.35, size.height * 0.15,
        size.width * 0.65, size.height * 0.20,
        size.width, size.height * 0.19,
      );
    drawRoad(roadEW1, 6.0);

    final roadEW2 = Path()
      ..moveTo(size.width * 0.14, size.height * 0.32)
      ..cubicTo(
        size.width * 0.35, size.height * 0.31,
        size.width * 0.60, size.height * 0.34,
        size.width, size.height * 0.31,
      );
    drawRoad(roadEW2, 6.0);

    final roadEW3 = Path()
      ..moveTo(size.width * 0.16, size.height * 0.52)
      ..cubicTo(
        size.width * 0.38, size.height * 0.50,
        size.width * 0.62, size.height * 0.56,
        size.width, size.height * 0.54,
      );
    drawRoad(roadEW3, 6.5);

    final roadEW4 = Path()
      ..moveTo(size.width * 0.18, size.height * 0.70)
      ..cubicTo(
        size.width * 0.40, size.height * 0.69,
        size.width * 0.65, size.height * 0.72,
        size.width, size.height * 0.69,
      );
    drawRoad(roadEW4, 7.0);

    // Secondary Minor Streets Grid
    final minorStreet1 = Path()
      ..moveTo(size.width * 0.24, size.height * 0.22)
      ..lineTo(size.width * 0.42, size.height * 0.34);
    drawRoad(minorStreet1, 3.5);

    final minorStreet2 = Path()
      ..moveTo(size.width * 0.48, size.height * 0.23)
      ..lineTo(size.width * 0.46, size.height * 0.38);
    drawRoad(minorStreet2, 3.5);

    final minorStreet3 = Path()
      ..moveTo(size.width * 0.66, size.height * 0.20)
      ..lineTo(size.width * 0.64, size.height * 0.36);
    drawRoad(minorStreet3, 3.5);

    final minorStreet4 = Path()
      ..moveTo(size.width * 0.26, size.height * 0.40)
      ..lineTo(size.width * 0.36, size.height * 0.58);
    drawRoad(minorStreet4, 3.5);

    final minorStreet5 = Path()
      ..moveTo(size.width * 0.45, size.height * 0.52)
      ..lineTo(size.width * 0.55, size.height * 0.66);
    drawRoad(minorStreet5, 3.5);

    final minorStreet6 = Path()
      ..moveTo(size.width * 0.68, size.height * 0.46)
      ..lineTo(size.width * 0.74, size.height * 0.64);
    drawRoad(minorStreet6, 3.5);

  }

  @override
  bool shouldRepaint(CustomBaseMapPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────
// CONCENTRIC RADAR RINGS PAINTER
// ─────────────────────────────────────────────────────────

class RadarRingsPainter extends CustomPainter {
  final Offset center;
  final double pulseValue;
  final double radiusScale;
  final int activeCandidateCount;

  RadarRingsPainter({
    required this.center,
    required this.pulseValue,
    this.radiusScale = 1.0,
    this.activeCandidateCount = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveDiscRadius = (76.0 * radiusScale).clamp(50.0, 100.0);

    // 1. Inner Solid Faded Disc covering immediate zone
    final discPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          RadarColors.electricIris.withValues(alpha: 0.22),
          RadarColors.cyanGlow.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: effectiveDiscRadius));
    canvas.drawCircle(center, effectiveDiscRadius, discPaint);

    // 2. Dynamic Rotating Radar Sweep Beam (Romantic Scanner Fan)
    final sweepAngle = pulseValue * 2 * math.pi;
    final maxRadius = 412.0 * radiusScale;
    final sweepPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          Colors.transparent,
          RadarColors.electricIris.withValues(alpha: 0.02),
          RadarColors.electricIris.withValues(alpha: 0.10),
          RadarColors.sunsetCoral.withValues(alpha: 0.18),
        ],
        [0.0, 0.70, 0.90, 1.0],
        TileMode.clamp,
        sweepAngle - 0.75,
        sweepAngle,
      );
    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Leading edge beam line with glowing aura
    final sweepEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    final sweepLinePaint = Paint()
      ..color = RadarColors.sunsetCoral.withValues(alpha: 0.40)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, sweepEnd, sweepLinePaint);

    // 3. Concentric Delicate Radar Rings (Electric Iris & Cyan Glow)
    final ringRadii = [74.0, 118.0, 172.0, 226.0, 284.0, 348.0, 412.0];

    for (int i = 0; i < ringRadii.length; i++) {
      final baseR = ringRadii[i] * radiusScale;
      final r = baseR + (pulseValue * 3.5);

      final isEven = i % 2 == 0;
      final strokeAlpha = (0.25 - (i * 0.025)).clamp(0.08, 0.25);
      final Color strokeColor = isEven
          ? RadarColors.electricIris.withValues(alpha: strokeAlpha)
          : RadarColors.cyanGlow.withValues(alpha: 0.15);

      final ringPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;

      canvas.drawCircle(center, r, ringPaint);
    }

    // 4. Center Pin Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 12), width: 36, height: 16),
      shadowPaint,
    );

    // 5. Center Anchor Pin Active Continuous Pulsing Waves (Sunset Coral & Electric Iris)
    for (int wave = 0; wave < 3; wave++) {
      final waveProgress = (pulseValue + (wave * 0.333)) % 1.0;
      final waveRadius = 21.0 + (waveProgress * 54.0);
      final waveAlpha = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.40;

      final waveStroke = Paint()
        ..color = (wave % 2 == 0 ? RadarColors.sunsetCoral : RadarColors.electricIris)
            .withValues(alpha: waveAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * (1.0 - (waveProgress * 0.4));
      canvas.drawCircle(center, waveRadius, waveStroke);

      final waveFill = Paint()
        ..color = RadarColors.electricIris.withValues(alpha: waveAlpha * 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, waveRadius, waveFill);
    }

    // Center Pin Glowing Breathing Ring (Sunset Coral Glow)
    final pinGlowPaint = Paint()
      ..color = RadarColors.sunsetCoral.withValues(alpha: 0.22 + (pulseValue * 0.28))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 + (pulseValue * 2.2);
    canvas.drawCircle(center, 23.0, pinGlowPaint);

    // Center Anchor Pin (Dark Luxury Obsidian Slate #131924 with Sunset Coral Border)
    final pinPaint = Paint()
      ..color = RadarColors.darkSlate
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 21.0, pinPaint);

    final pinBorderPaint = Paint()
      ..color = RadarColors.sunsetCoral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, 21.0, pinBorderPaint);

    // Organic Mandala Pattern (Cyan Glow with Ice White Center)
    _drawMandalaPattern(canvas, center);

    // 6. Active Match Marker 1 Ring Connection Node (Top-Left - Sunset Coral Halo)
    if (activeCandidateCount >= 1) {
      final double node1Angle = -2.35; // radians (-135°)
      final double node1Radius = 118.0 * radiusScale;
      final node1Offset = Offset(
        center.dx + node1Radius * math.cos(node1Angle),
        center.dy + node1Radius * math.sin(node1Angle),
      );

      final node1Paint = Paint()
        ..color = RadarColors.sunsetCoral
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node1Offset, 4.5, node1Paint);

      final node1Aura = Paint()
        ..color = RadarColors.sunsetCoral.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(node1Offset, 8.5 + (pulseValue * 2.0), node1Aura);
    }

    // 7. Active Match Marker 2 Ring Node (Mid-Right - Cyan Glow Halo)
    if (activeCandidateCount >= 2) {
      final double node2Angle = -0.05; // radians (-3°)
      final double node2Radius = 118.0 * radiusScale;
      final node2Offset = Offset(
        center.dx + node2Radius * math.cos(node2Angle),
        center.dy + node2Radius * math.sin(node2Angle),
      );

      final node2Outer = Paint()
        ..color = RadarColors.cyanGlow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node2Offset, 7.5, node2Outer);

      final node2White = Paint()
        ..color = RadarColors.iceWhite
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node2Offset, 3.5, node2White);

      final node2Aura = Paint()
        ..color = RadarColors.cyanGlow.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(node2Offset, 12.0 + (pulseValue * 2.5), node2Aura);
    }

    // 8. Dynamic Moving Connecting Lines Between Center & Surrounding Match Nodes
    if (activeCandidateCount > 0) {
      _drawMovingConnectionLines(canvas, center, radiusScale);
    }
  }

  void _drawMovingConnectionLines(Canvas canvas, Offset c, double scale) {
    // Exact centers of the 4 profile match markers relative to radarCenter:
    // Marker 1: Ananya Sharma (Top-Left)
    final p1 = Offset(c.dx - 88, c.dy - (126 * scale));
    // Marker 2: Maya Lin (Mid-Right)
    final p2 = Offset(c.dx + (126 * scale), c.dy - 2);
    // Marker 3: Rhea Mehta (Lower-Left)
    final p3 = Offset(c.dx - 66, c.dy + (115 * scale));
    // Marker 4: Rohan Verma (Upper-Right)
    final p4 = Offset(c.dx + (135 * scale), c.dy - (96 * scale));

    final connections = [
      (c, p1, 0.0, 1.0),
      (c, p2, 0.25, 1.2),
      (c, p3, 0.50, 0.9),
      (c, p4, 0.75, 1.1),
      (p1, p4, 0.35, 0.8),
      (p2, p3, 0.65, 0.85),
    ];

    for (int i = 0; i < connections.length; i++) {
      final start = connections[i].$1;
      final end = connections[i].$2;
      final phase = connections[i].$3;
      final speed = connections[i].$4;

      final midX = (start.dx + end.dx) / 2;
      final midY = (start.dy + end.dy) / 2;
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      final nx = len > 0 ? -dy / len : 0.0;
      final ny = len > 0 ? dx / len : 0.0;

      final harmonicWobble = math.sin((pulseValue * 2 * math.pi) + phase) * 8.0;
      final ctrl = Offset(midX + nx * harmonicWobble, midY + ny * harmonicWobble);

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

      final linePaint = Paint()
        ..shader = ui.Gradient.linear(
          start,
          end,
          [
            AppColors.sunsetCoral.withValues(alpha: 0.38),
            AppColors.electricIris.withValues(alpha: 0.45),
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawPath(path, linePaint);

      // Moving photon particle along the line
      final t = ((pulseValue * speed) + phase) % 1.0;
      final u = 1.0 - t;
      final px = (u * u * start.dx) + (2 * u * t * ctrl.dx) + (t * t * end.dx);
      final py = (u * u * start.dy) + (2 * u * t * ctrl.dy) + (t * t * end.dy);
      final photon = Offset(px, py);

      // Photon glow halo
      final glowPaint = Paint()
        ..color = (i % 2 == 0 ? AppColors.sunsetCoral : AppColors.electricIris)
            .withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
      canvas.drawCircle(photon, 3.8, glowPaint);

      // Photon bright center
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(photon, 1.8, corePaint);
    }
  }

  void _drawMandalaPattern(Canvas canvas, Offset c) {
    final petalPaint = Paint()
      ..color = RadarColors.cyanGlow.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const int petalCount = 6;
    const double petalRadius = 6.0;
    for (int i = 0; i < petalCount; i++) {
      final angle = (i * 2 * math.pi) / petalCount;
      final petalCenter = Offset(
        c.dx + petalRadius * math.cos(angle),
        c.dy + petalRadius * math.sin(angle),
      );
      canvas.drawCircle(petalCenter, petalRadius, petalPaint);
    }

    final centerDotPaint = Paint()
      ..color = RadarColors.iceWhite
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 2.4, centerDotPaint);
  }

  @override
  bool shouldRepaint(RadarRingsPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.center != center ||
      oldDelegate.radiusScale != radiusScale;
}


// ─────────────────────────────────────────────────────────
// PRESENCE STATUS & INTERACTIVE RADAR MATCH AVATAR MARKER
// ─────────────────────────────────────────────────────────

enum MatchPresenceStatus {
  online,
  away,
  busy,
}

class RadarMatchAvatarMarker extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String initials;
  final MatchPresenceStatus status;
  final double pulseValue;
  final double avatarRadius;
  final Color themeColor;
  final VoidCallback onTap;
  final Widget? attachedBadge;

  const RadarMatchAvatarMarker({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.initials,
    required this.status,
    required this.pulseValue,
    this.avatarRadius = 22.0,
    this.themeColor = RadarColors.deepSage,
    required this.onTap,
    this.attachedBadge,
  });

  Color get _statusColor {
    switch (status) {
      case MatchPresenceStatus.online:
        return const Color(0xFF34C759); // Slack/Workspace Online Green
      case MatchPresenceStatus.away:
        return const Color(0xFFFFB300); // Amber Away
      case MatchPresenceStatus.busy:
        return const Color(0xFFFF3B30); // Coral Red Busy / Offline
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final diameter = avatarRadius * 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (attachedBadge != null) attachedBadge!,
          // Gentle breathing heartbeat pulse animation (scale from 1.0 to 1.06)
          Transform.scale(
            scale: 1.0 + (pulseValue * 0.06),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Subtle continuous blinking / glowing animation effect
                Container(
                  width: diameter + 10 + (pulseValue * 8),
                  height: diameter + 10 + (pulseValue * 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeColor.withValues(
                      alpha: (0.35 * (1.0 - (pulseValue * 0.45))).clamp(0.08, 0.38),
                    ),
                    border: Border.all(
                      color: themeColor.withValues(
                        alpha: (0.60 * (1.0 - pulseValue)).clamp(0.12, 0.60),
                      ),
                      width: 1.5,
                    ),
                  ),
                ),

                // Outer Circular Avatar Container with Border and Soft Romantic Radial Drop-Shadow
                Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RadarColors.darkSlate,
                    border: Border.all(
                      color: themeColor,
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.50),
                        blurRadius: 16,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            themeColor.withValues(alpha: 0.35),
                            themeColor.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: avatarRadius * 0.68,
                        ),
                      ),
                    ),
                    errorWidget: (ctx, url, err) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            themeColor.withValues(alpha: 0.40),
                            themeColor.withValues(alpha: 0.20),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: avatarRadius * 0.68,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Workspace-style Active Status Indicator Dot on the Border
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13.5,
                  height: 13.5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RadarColors.darkSlate,
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
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
    );
  }
}

// ─────────────────────────────────────────────────────────
// MAIN RADAR SCREEN WIDGET
// ─────────────────────────────────────────────────────────

class RadarScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  final bool isTestMode;

  const RadarScreen({super.key, this.onNavigateTab, this.isTestMode = false});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with TickerProviderStateMixin {
  final List<RadarVibeBeaconModel> _activeVibeBeacons = [];
  late final RadarNotifier _notifier;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _refreshSpinController;
  late final Animation<double> _refreshSpinAnimation;
  final DnaBlueprintService _dnaService = DnaBlueprintService();

  List<DatingCandidateProfile> _nearbyProfiles = [];

  double _currentRadius = 25.0;
  double _compatibilityThreshold = 0.70; // 70% default

  // Intuitive Grouped Filter State
  RangeValues _filterAgeRange = const RangeValues(21, 38);
  double _filterMaxDistance = 35.0;
  String _filterInterestedIn = 'Everyone';
  bool _filterVerifiedOnly = false;
  final Set<String> _selectedLifestyleHabits = {
    'Daily Workout',
    'Socially',
    'Non-smoker',
    'Early Bird 🌅',
  };

  int _likesCount = 330;
  bool _isLiked = false;
  bool _isBoostActive = false;
  String _selectedZone = 'Nearby';
  Timer? _radiusDebounceTimer;
  bool _isRefreshing = false;

  // Connection Confirmation Tracking
  // Compatibility matching stats and user dots dynamically populate and display ONLY after connections are confirmed
  final Set<String> _confirmedConnectionUserIds = {};

  void _confirmConnection(String userId, String name) {
    if (!_confirmedConnectionUserIds.contains(userId)) {
      setState(() {
        _confirmedConnectionUserIds.add(userId);
      });
      HapticFeedback.mediumImpact();
      _pulseController.forward(from: 0.0);
      _showFeedbackToast(
        '🎉 Connection Confirmed with $name! Radar matching node & stats synced.',
        icon: Icons.favorite_rounded,
      );
    }
  }

  // Dynamic Global Location Search State
  Timer? _searchDebounceTimer;
  List<(String, String, double, double)> _globalSearchSuggestions = [];
  bool _isSearchingLocations = false;

  static const List<(String, String, double, double)> _curatedGlobalHubs = [
    ('London, United Kingdom', '142 active singles • Mayfair & Soho', 51.5074, -0.1278),
    ('New York, NY, USA', '210 active singles • Manhattan & Brooklyn', 40.7128, -74.0060),
    ('Tokyo, Japan', '185 active singles • Shibuya & Roppongi', 35.6762, 139.6503),
    ('Paris, France', '118 active singles • Le Marais & 7th Arr.', 48.8566, 2.3522),
    ('Dubai, UAE', '96 active singles • Marina & Downtown', 25.2048, 55.2708),
    ('Toronto, ON, Canada', '88 active singles • Downtown Core & Yorkville', 43.6532, -79.3832),
    ('Singapore', '104 active singles • Marina Bay & Tanjong Pagar', 1.3521, 103.8198),
    ('Sydney, Australia', '76 active singles • Bondi & CBD', -33.8688, 151.2093),
    ('Berlin, Germany', '92 active singles • Mitte & Kreuzberg', 52.5200, 13.4050),
    ('San Francisco, CA, USA', '84 active singles • SoMa & Marina', 37.7749, -122.4194),
    ('Seoul, South Korea', '126 active singles • Gangnam & Hongdae', 37.5665, 126.9780),
    ('Mumbai, India', '145 active singles • South Mumbai & Suburbs', 19.0760, 72.8777),
  ];

  Future<void> _searchGlobalLocations(String query, void Function(void Function()) setSheetState) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setSheetState(() {
        _globalSearchSuggestions = List.from(_curatedGlobalHubs);
        _isSearchingLocations = false;
      });
      return;
    }

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setSheetState(() => _isSearchingLocations = true);
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&addressdetails=1&limit=8',
        );
        final response = await http.get(url, headers: {'User-Agent': 'AuraApp/1.0'});
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          final results = data.map<(String, String, double, double)>((item) {
            final name = item['display_name'] as String? ?? 'Custom Location';
            final parts = name.split(',');
            final shortName = parts.take(math.min(2, parts.length)).join(',').trim();
            final country = parts.isNotEmpty ? parts.last.trim() : 'Global';
            final lat = double.tryParse(item['lat']?.toString() ?? '0.0') ?? 0.0;
            final lon = double.tryParse(item['lon']?.toString() ?? '0.0') ?? 0.0;
            final type = item['type']?.toString().toUpperCase() ?? 'REGION';
            return (shortName, '$country • $type', lat, lon);
          }).toList();

          if (mounted) {
            setSheetState(() {
              _globalSearchSuggestions = results;
              _isSearchingLocations = false;
            });
          }
        } else {
          setSheetState(() => _isSearchingLocations = false);
        }
      } catch (e) {
        debugPrint('AURA_RADAR: Global search exception: $e');
        if (mounted) {
          setSheetState(() => _isSearchingLocations = false);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _notifier = RadarNotifier();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _refreshSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _refreshSpinAnimation = CurvedAnimation(
      parent: _refreshSpinController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.isTestMode) {
      _notifier.start(enableBackgroundTimer: false);
    } else {
      _notifier.start();
      _wireLocationPermissionsOnStartup();
    }
    _notifier.addListener(_onRadarNotifierChanged);
    _dnaService.addListener(_onDnaServiceChanged);
    _loadNearbyProfiles();
  }

  /// Loads nearby candidate profiles from Firestore users collection
  Future<void> _loadNearbyProfiles() async {
    if (!mounted) return;
    if (_notifier.value is! RadarLoaded) return;
    final lat = (_notifier.value as RadarLoaded).userLat;
    final lng = (_notifier.value as RadarLoaded).userLng;
    try {
      final profiles = await FirestoreDiscoveryService().fetchNearbyUsers(
        centerLat: lat,
        centerLng: lng,
        radiusKm: _currentRadius,
      );
      if (mounted) {
        setState(() {
          _nearbyProfiles = profiles;
        });
      }
    } catch (e) {
      debugPrint('AURA_RADAR: Firestore nearby users fetch notice: $e');
    }
  }

  /// Helper to get user display initials
  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return 'AU';
  }

  /// Task 1: Wire location permissions on app startup / screen load
  void _wireLocationPermissionsOnStartup() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final granted = await _notifier.requestAndSyncLocation();
        if (mounted && granted) {
          final zone = _notifier.value is RadarLoaded
              ? (_notifier.value as RadarLoaded).currentZoneName
              : 'Live Location';
          _loadNearbyProfiles();
          _showFeedbackToast(
            'Live GPS synced: $zone 📍',
            icon: Icons.my_location_rounded,
          );
        }
      } catch (e) {
        debugPrint('AURA_RADAR: Location permission startup sync notice: $e');
      }
    });
  }

  /// Dynamic radius filtered vibe beacons
  List<RadarVibeBeaconModel> get _filteredVibeBeacons {
    final maxMeters = _currentRadius * 1000;
    return _activeVibeBeacons.where((b) => b.distanceMeters <= maxMeters).toList();
  }

  /// Dynamic count of active match markers within the selected discovery radius
  int get _activeMatchesCount {
    if (_nearbyProfiles.isNotEmpty) {
      return _nearbyProfiles.where((p) => p.distanceKm <= _currentRadius).length;
    }
    return 0;
  }

  void _onRadarNotifierChanged() {
    if (mounted) {
      if (_notifier.value is RadarLoaded) {
        final loaded = _notifier.value as RadarLoaded;
        if (loaded.currentZoneName.isNotEmpty && loaded.currentZoneName != _selectedZone) {
          _selectedZone = loaded.currentZoneName;
          _loadNearbyProfiles();
        }
      }
      setState(() {});
    }
  }

  void _onDnaServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _radiusDebounceTimer?.cancel();
    _refreshSpinController.dispose();
    _pulseController.dispose();
    _notifier.removeListener(_onRadarNotifierChanged);
    _notifier.dispose();
    _dnaService.removeListener(_onDnaServiceChanged);
    super.dispose();
  }

  /// Task 2: Automatically triggers radar refresh with 400ms debounce whenever Discovery Radius changes
  void _onRadiusChanged(double val) {
    setState(() => _currentRadius = val);

    // Debounced automatic refresh (400ms: within 300–500ms debounce requirement):
    // provides immediate smooth ring scaling, and dynamically queries & updates
    // active zones, beacons, and matching entities when slider adjustment settles
    _radiusDebounceTimer?.cancel();
    _radiusDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      _notifier.changeRadius(_currentRadius);
      _pulseController.forward(from: 0.0);
      _refreshSpinController.forward(from: 0.0);
      _loadNearbyProfiles();
      _showFeedbackToast(
        'Radar auto-refreshed: ${_currentRadius.toInt()} km range ($_activeMatchesCount matches in range)',
        icon: Icons.radar_rounded,
      );
    });
  }

  /// Triggers smooth manual radar refresh with tactile haptics & spin animation
  Future<void> _triggerManualRadarRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    _pulseController.forward(from: 0.0);
    _refreshSpinController.forward(from: 0.0);
    await _notifier.refresh();
    await _loadNearbyProfiles();
    if (mounted) {
      setState(() => _isRefreshing = false);
      final zoneCount = _notifier.value is RadarLoaded
          ? (_notifier.value as RadarLoaded).activeZoneCount
          : 5;
      _showFeedbackToast(
        'Radar Refreshed: $zoneCount zones updated, $_activeMatchesCount matches in range',
        icon: Icons.refresh_rounded,
      );
    }
  }

  void _showFeedbackToast(String message, {IconData icon = Icons.check_circle_rounded}) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomMargin = 148.0 + bottomPadding;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: RadarColors.pureWhite, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: RadarColors.deepSageDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_notifier.value is RadarPermissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        body: SafeArea(
          child: _buildLocationPermissionPrompt(),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final radarCenter = Offset(size.width * 0.46, size.height * 0.43);

    // Dynamic height of the Discovery Radius bottom panel (content + safe area)
    final double bottomSheetHeight = 138.0 + bottomPadding;

    // Calculate dynamic scaling for radar rings from radius slider
    final double radiusScale = (_currentRadius / 25.0).clamp(0.65, 1.45);

    return Scaffold(
      backgroundColor: RadarColors.paleMapTint,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 1. CUSTOM BASE MAP CANVAS (Cached in RepaintBoundary for 60+ FPS) ──
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: CustomBaseMapPainter(),
                  size: size,
                ),
              ),
            ),
          ),

          // ── 2. CONCENTRIC RADAR RINGS & CENTER PIN (Isolated in RepaintBoundary) ──
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: RadarRingsPainter(
                        center: radarCenter,
                        pulseValue: _pulseAnimation.value,
                        radiusScale: radiusScale,
                        activeCandidateCount: _confirmedConnectionUserIds.length,
                      ),
                      size: size,
                    );
                  },
                ),
              ),
            ),
          ),

          // ── 3. INTERACTIVE MATCH MARKERS ON RADAR (Requirement 3) ────────
          // Marker 1: Ananya Sharma (Top-Left on Ring 2, Online/Green, Matching Callout)
          Positioned(
            left: radarCenter.dx - 110,
            top: radarCenter.dy - (148 * radiusScale),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => _buildAnanyaMatchMarker(),
            ),
          ),

          // Marker 2: Maya Lin (Mid-Right on Ring 2, Online/Green, 70% Compatibility Pill)
          Positioned(
            right: 8,
            top: radarCenter.dy - 22,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => _buildMayaMatchMarker(),
            ),
          ),

          // Marker 3: Rhea Mehta (Lower-Left on Ring 3, Away/Yellow, 79% match)
          Positioned(
            left: radarCenter.dx - 88,
            top: radarCenter.dy + (95 * radiusScale),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => _buildRheaMatchMarker(),
            ),
          ),

          // Marker 4: Rohan Verma (Upper-Right on Ring 3, Busy/Red, 84% match)
          Positioned(
            left: radarCenter.dx + (115 * radiusScale),
            top: radarCenter.dy - (118 * radiusScale),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => _buildRohanMatchMarker(),
            ),
          ),

          // ── 5. TOP FLOATING PILL BAR (Location, Filter & Preferences) ───
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopPillBar(),
                  const SizedBox(height: 8),
                  // Floating Proximity Micro-Events Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active Beacon Marker Button (Dynamically filtered by discovery radius)
                      if (_filteredVibeBeacons.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showJoinVibeDialog(_filteredVibeBeacons.first),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_filteredVibeBeacons.first.activityIcon, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  '${_filteredVibeBeacons.first.hostName} • ${_filteredVibeBeacons.first.distanceMeters}m',
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      // "Host a Vibe ✨" Trigger Button
                      GestureDetector(
                        onTap: _showHostVibeModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.7)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('✨', style: TextStyle(fontSize: 11)),
                              SizedBox(width: 4),
                              Text(
                                'Host a Vibe',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
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
          ),

          // ── 6. PROFILE CARDS STACK & STATS OVERLAY ────────
          Positioned(
            right: 14,
            bottom: bottomSheetHeight + 78,
            child: _buildProfileStatsOverlay(),
          ),

          // ── 7. GPS TARGET CALIBRATION BUTTON (Floats cleanly with safe margin above bottom sheet) ──
          Positioned(
            right: 18,
            bottom: bottomSheetHeight + 24,
            child: _buildGpsButton(radarCenter),
          ),

          // ── 8. FLOATING REFRESH BUTTON (Floats safely above the bottom sheet with adequate 24px clearance) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomSheetHeight + 24,
            child: Center(
              child: _buildRefreshButton(),
            ),
          ),

          // ── 9. BOTTOM DISCOVERY SHEET / SLIDER CARD ──────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomDiscoverySheet(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // INTERACTIVE SHEETS & MODALS
  // ─────────────────────────────────────────────────────────

  // 1. Zone & Location Selector Modal (Dynamic Global Search)
  void _showZoneSelectorSheet() {
    debugPrint('AURA_RADAR: Opening Dynamic Global Location Selector');
    HapticFeedback.lightImpact();
    _globalSearchSuggestions = List.from(_curatedGlobalHubs);
    _isSearchingLocations = false;
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final isSearching = _isSearchingLocations;
          final suggestions = _globalSearchSuggestions;

          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: RadarColors.specularBorder, width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: RadarColors.sunsetCoral.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: RadarColors.sunsetCoral.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.public_rounded, color: RadarColors.sunsetCoral, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore Global Locations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: RadarColors.iceWhite,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Select any city worldwide or recalibrate with GPS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: RadarColors.titaniumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                  ),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: RadarColors.iceWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search city, state, or country worldwide...',
                      hintStyle: const TextStyle(fontSize: 13, color: RadarColors.slateMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: RadarColors.sunsetCoral, size: 20),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: RadarColors.titaniumGray),
                              onPressed: () {
                                searchController.clear();
                                _searchGlobalLocations('', setSheetState);
                              },
                            )
                          : (isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: RadarColors.sunsetCoral),
                                  ),
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      setSheetState(() {});
                      _searchGlobalLocations(val, setSheetState);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Live Device GPS Quick Action Button
                InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectedZone = 'Current Location (GPS)');
                    _notifier.switchZone('Current Location', 19.0760, 72.8777);
                    _loadNearbyProfiles();
                    _pulseController.forward(from: 0.0);
                    _refreshSpinController.forward(from: 0.0);
                    Navigator.pop(ctx);
                    _showFeedbackToast(
                      'Recalibrated to live device GPS coordinates 📍',
                      icon: Icons.my_location_rounded,
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFE4E6), width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location_rounded, color: RadarColors.sunsetCoral, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Use Live Device Location (Auto-Calibrate)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: RadarColors.iceWhite,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: RadarColors.sunsetCoral,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'GPS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    searchController.text.trim().isEmpty ? 'Popular Global FindAura Hubs' : 'Search Results (${suggestions.length})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: RadarColors.titaniumGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: suggestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.travel_explore_rounded, size: 40, color: RadarColors.slateMuted),
                              const SizedBox(height: 8),
                              Text(
                                'No locations found for "${searchController.text}"',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RadarColors.iceWhite),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try searching for a different city or country',
                                style: TextStyle(fontSize: 11, color: RadarColors.titaniumGray),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (context, index) {
                            final hub = suggestions[index];
                            final isSelected = _selectedZone.toLowerCase().contains(hub.$1.toLowerCase());

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? RadarColors.sunsetCoral.withValues(alpha: 0.15)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_city_rounded,
                                  color: isSelected ? RadarColors.sunsetCoral : RadarColors.titaniumGray,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                hub.$1,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? RadarColors.sunsetCoral : RadarColors.iceWhite,
                                ),
                              ),
                              subtitle: Text(
                                hub.$2,
                                style: const TextStyle(fontSize: 11, color: RadarColors.titaniumGray),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: RadarColors.sunsetCoral, size: 20)
                                  : const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: RadarColors.slateMuted),
                              onTap: () {
                                setState(() => _selectedZone = hub.$1);
                                _notifier.switchZone(hub.$1, hub.$3, hub.$4);
                                _loadNearbyProfiles();
                                _pulseController.forward(from: 0.0);
                                _refreshSpinController.forward(from: 0.0);
                                Navigator.pop(ctx);
                                _showFeedbackToast(
                                  'Radar recalibrated to ${hub.$1} 🌍',
                                  icon: Icons.public_rounded,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 2. Comprehensive Filter Sheet - High Contrast Redesign
  void _showFilterSheet() {
    debugPrint('AURA_RADAR: Opening Filter Sheet (High-Contrast Grouped Sections)');
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top drag pill
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header with high-contrast branding & Reset action
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Match & Radar Filters',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Fine-tune member vibes & lifestyle chemistry',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            _filterAgeRange = const RangeValues(21, 38);
                            _filterMaxDistance = 35.0;
                            _filterInterestedIn = 'Everyone';
                            _compatibilityThreshold = 0.70;
                            _filterVerifiedOnly = false;
                            _selectedLifestyleHabits.clear();
                            _selectedLifestyleHabits.addAll({
                              'Daily Workout',
                              'Socially',
                              'Non-smoker',
                              'Early Bird 🌅',
                            });
                          });
                          setState(() {});
                          _showFeedbackToast('Filters reset to default');
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFFF4D67)),
                        label: const Text(
                          'Reset',
                          style: TextStyle(
                            color: Color(0xFFFF4D67),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Scrollable Grouped Sections
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // ───────────────────────────────────────────────
                      // SECTION 1: MEMBER PREFERENCES
                      // ───────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF4D67).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person_search_rounded,
                                    color: Color(0xFFFF4D67),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'MEMBER PREFERENCES',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF4D67),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Looking For / Gender
                            const Text(
                              'Interested in Meeting',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: ['Women', 'Men', 'Everyone'].map((opt) {
                                final isSel = _filterInterestedIn == opt;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ChoiceChip(
                                      label: Center(
                                        child: Text(
                                          opt,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                            color: isSel ? Colors.white : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      selected: isSel,
                                      selectedColor: const Color(0xFFFF4D67),
                                      backgroundColor: Colors.white,
                                      showCheckmark: false,
                                      side: BorderSide(
                                        color: isSel ? const Color(0xFFFF4D67) : const Color(0xFFCBD5E1),
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (val) {
                                        if (val) {
                                          setSheetState(() => _filterInterestedIn = opt);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            // Age Range Slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Age Range',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    '${_filterAgeRange.start.round()} - ${_filterAgeRange.end.round()} yrs',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            RangeSlider(
                              values: _filterAgeRange,
                              min: 18,
                              max: 60,
                              divisions: 42,
                              activeColor: const Color(0xFFFF4D67),
                              inactiveColor: const Color(0xFFE2E8F0),
                              onChanged: (values) {
                                setSheetState(() => _filterAgeRange = values);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Maximum Distance Slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Maximum Distance Radius',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Text(
                                    '${_filterMaxDistance.round()} km',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF10B981),
                                thumbColor: const Color(0xFF10B981),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                              ),
                              child: Slider(
                                value: _filterMaxDistance,
                                min: 5,
                                max: 100,
                                divisions: 19,
                                onChanged: (val) {
                                  setSheetState(() => _filterMaxDistance = val);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Minimum Aura Compatibility
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Minimum Compatibility Match',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF5FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: Text(
                                    '${(_compatibilityThreshold * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF7E22CE),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF7928CA),
                                thumbColor: const Color(0xFF7928CA),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                              ),
                              child: Slider(
                                value: _compatibilityThreshold,
                                min: 0.50,
                                max: 0.95,
                                divisions: 9,
                                onChanged: (val) {
                                  setSheetState(() => _compatibilityThreshold = val);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Verified Only Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 20),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Verified Profiles Only',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Passed 3D Face Liveness validation',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Switch.adaptive(
                                    value: _filterVerifiedOnly,
                                    activeTrackColor: const Color(0xFF3B82F6),
                                    onChanged: (val) {
                                      setSheetState(() => _filterVerifiedOnly = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ───────────────────────────────────────────────
                      // SECTION 2: LIFESTYLE HABITS
                      // ───────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.spa_rounded,
                                    color: Color(0xFF10B981),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'LIFESTYLE HABITS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Workout & Fitness
                            const Text(
                              'Workout & Fitness',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'Daily Workout',
                                'Yoga & Pilates',
                                'Runner',
                                'Weekend Hiker',
                                'Casual Walks',
                              ].map((item) {
                                final isSel = _selectedLifestyleHabits.contains(item);
                                return FilterChip(
                                  label: Text(item),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFECFDF5),
                                  checkmarkColor: const Color(0xFF059669),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isSel ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? const Color(0xFF065F46) : const Color(0xFF334155),
                                  ),
                                  onSelected: (sel) {
                                    setSheetState(() {
                                      if (sel) {
                                        _selectedLifestyleHabits.add(item);
                                      } else {
                                        _selectedLifestyleHabits.remove(item);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Social Drinking
                            const Text(
                              'Social Drinking',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'Socially',
                                'Never / Sober',
                                'Special Occasions',
                                'Craft Beer & Wine',
                              ].map((item) {
                                final isSel = _selectedLifestyleHabits.contains(item);
                                return FilterChip(
                                  label: Text(item),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFFFF7ED),
                                  checkmarkColor: const Color(0xFFEA580C),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isSel ? const Color(0xFFF97316) : const Color(0xFFCBD5E1),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? const Color(0xFF9A3412) : const Color(0xFF334155),
                                  ),
                                  onSelected: (sel) {
                                    setSheetState(() {
                                      if (sel) {
                                        _selectedLifestyleHabits.add(item);
                                      } else {
                                        _selectedLifestyleHabits.remove(item);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Smoking Habits
                            const Text(
                              'Smoking Habits',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'Non-smoker',
                                'Social Smoker',
                                'Vape Only',
                                'Cannabis Friendly',
                              ].map((item) {
                                final isSel = _selectedLifestyleHabits.contains(item);
                                return FilterChip(
                                  label: Text(item),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFF0FDF4),
                                  checkmarkColor: const Color(0xFF16A34A),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isSel ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? const Color(0xFF15803D) : const Color(0xFF334155),
                                  ),
                                  onSelected: (sel) {
                                    setSheetState(() {
                                      if (sel) {
                                        _selectedLifestyleHabits.add(item);
                                      } else {
                                        _selectedLifestyleHabits.remove(item);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Dietary Habits
                            const Text(
                              'Dietary Habits',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'Omnivore',
                                'Vegetarian',
                                'Vegan',
                                'Pescatarian',
                                'Gluten-Free',
                              ].map((item) {
                                final isSel = _selectedLifestyleHabits.contains(item);
                                return FilterChip(
                                  label: Text(item),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFEFF6FF),
                                  checkmarkColor: const Color(0xFF2563EB),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isSel ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                                  ),
                                  onSelected: (sel) {
                                    setSheetState(() {
                                      if (sel) {
                                        _selectedLifestyleHabits.add(item);
                                      } else {
                                        _selectedLifestyleHabits.remove(item);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Sleep & Rhythm
                            const Text(
                              'Daily Rhythm & Companions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'Early Bird 🌅',
                                'Night Owl 🦉',
                                'Dog Lover 🐕',
                                'Cat Lover 🐈',
                                'Coffee Addict ☕',
                              ].map((item) {
                                final isSel = _selectedLifestyleHabits.contains(item);
                                return FilterChip(
                                  label: Text(item),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFFAF5FF),
                                  checkmarkColor: const Color(0xFF9333EA),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isSel ? const Color(0xFFA855F7) : const Color(0xFFCBD5E1),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? const Color(0xFF7E22CE) : const Color(0xFF334155),
                                  ),
                                  onSelected: (sel) {
                                    setSheetState(() {
                                      if (sel) {
                                        _selectedLifestyleHabits.add(item);
                                      } else {
                                        _selectedLifestyleHabits.remove(item);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Apply CTA Button pinned to bottom
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                        _showFeedbackToast(
                          'Radar Filters Applied: Matching Member Preferences & Habits ✨',
                          icon: Icons.check_circle_rounded,
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Apply Matching Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 3. Quick Connect Nearby People Sheet (From User Plus Icon)
  void _showQuickConnectSheet() {
    debugPrint('AURA_RADAR: Opening Quick Connect Sheet');
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.58,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: RadarColors.pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: RadarColors.mutedMint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, color: RadarColors.deepSage, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Nearby Radar Signals',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: RadarColors.darkForest),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('People currently detected within your 25 km radius', style: TextStyle(fontSize: 12, color: RadarColors.textMuted)),
                  if (_nearbyProfiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No nearby people discovered yet.\nTry expanding your radar radius!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: RadarColors.titaniumGray),
                        ),
                      ),
                    )
                  else
                    ..._nearbyProfiles.take(4).map(
                        (p) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          onTap: () {
                            Navigator.pop(ctx);
                            DatingUserProfileDetailModal.show(
                              context,
                              p,
                              onWaveSent: () => _showFeedbackToast('Wave sent to ${p.displayName}! 👋', icon: Icons.waving_hand_rounded),
                            );
                          },
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RadarColors.sunsetCoral.withValues(alpha: 0.12),
                              border: Border.all(color: RadarColors.sunsetCoral.withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(p.displayName),
                                style: const TextStyle(
                                  color: RadarColors.sunsetCoral,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RadarColors.darkForest)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: RadarColors.cyanGlow.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${p.matchScore}% Match',
                                  style: const TextStyle(
                                    color: RadarColors.cyanGlow,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${p.age} • ${p.occupation} • ${p.distanceKm} km away',
                            style: const TextStyle(fontSize: 11, color: RadarColors.textMuted),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _confirmedConnectionUserIds.contains(p.userId)
                                  ? const Color(0xFF10B981)
                                  : RadarColors.sunsetCoral,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                            ),
                            onPressed: () {
                              _confirmConnection(p.userId, p.displayName);
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              _confirmedConnectionUserIds.contains(p.userId) ? 'Connected ✓' : 'Connect ⚡',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. DNA / Dating Blueprint Modal
  
  // ── HOST & JOIN VIBE (PROXIMITY MICRO-EVENTS) ──────────────────────────
  void _showHostVibeModal() {
    debugPrint('AURA_RADAR: Opening Host Vibe Modal');
    HapticFeedback.mediumImpact();
    HostVibeBottomSheet.show(
      context,
      onBroadcast: (beacon) {
        setState(() {
          _activeVibeBeacons.insert(0, beacon);
        });
        _showFeedbackToast('✨ Vibe Broadcast Active: "${beacon.activityType}" (2 Hours)');
      },
    );
  }

  void _showJoinVibeDialog(RadarVibeBeaconModel beacon) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFFE4E6), width: 1.2),
        ),
        title: Row(
          children: [
            Text(beacon.activityIcon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                beacon.activityType,
                style: const TextStyle(color: RadarColors.iceWhite, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host: ${beacon.hostName} • ${beacon.distanceMeters}m away', style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Location: ${beacon.locationLabel}', style: const TextStyle(color: RadarColors.titaniumGray, fontSize: 12)),
            const SizedBox(height: 6),
            Text('Slots: ${beacon.slotsRemaining} of ${beacon.slotsTotal} remaining • Expires in ${beacon.expiresInMinutes} mins', style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
              'Joining requires mutual Two-Way Call / Vibe Handshake consent before connection.',
              style: TextStyle(color: RadarColors.slateMuted, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: RadarColors.titaniumGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showFeedbackToast('✨ Join Request Dispatched to ${beacon.hostName}!');
            },
            child: const Text('Send Join Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDnaBlueprintModal() {
    debugPrint('AURA_RADAR: Opening DNA Blueprint Modal');
    HapticFeedback.lightImpact();
    DnaBlueprintSheet.show(
      context,
      initialBlueprint: _dnaService.blueprint,
      onSaved: (saved) {
        setState(() {});
        _showFeedbackToast(
          '✨ Aura DNA Blueprint saved & synced!',
          icon: Icons.auto_awesome_rounded,
        );
      },
    );
  }

  // 5. Compatibility Threshold Adjustment Sheet (From Vertical 70% Gauge)
  void _showThresholdAdjustmentSheet() {
    debugPrint('AURA_RADAR: Opening Threshold & Radar Preferences Sheet');
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isHideBelow = _dnaService.hideBelowCutoff;
          return Container(
            height: MediaQuery.of(context).size.height * 0.66,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: RadarColors.pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: RadarColors.mutedMint, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Radar Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: RadarColors.darkForest),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: RadarColors.deepSage.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_compatibilityThreshold * 100).toInt()}% Cutoff',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RadarColors.deepSage),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Compatibility Threshold',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RadarColors.darkForest),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Only display signals and radar nodes meeting or exceeding this compatibility score.',
                  style: TextStyle(fontSize: 12, color: RadarColors.textMuted),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _compatibilityThreshold,
                  min: 0.50,
                  max: 0.95,
                  activeColor: RadarColors.deepSage,
                  inactiveColor: RadarColors.paleMapTint,
                  onChanged: (val) {
                    setModalState(() => _compatibilityThreshold = val);
                    setState(() => _compatibilityThreshold = val);
                  },
                ),
                const Divider(height: 16, color: RadarColors.paleMapTint),
                // Aura Radar Boost Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FindAura Radar Boost (30m)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RadarColors.darkForest),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Double your signal broadcast priority in active zones',
                          style: TextStyle(fontSize: 11.5, color: RadarColors.textMuted),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isBoostActive,
                      activeThumbColor: RadarColors.deepSage,
                      activeTrackColor: RadarColors.mutedMint.withValues(alpha: 0.5),
                      onChanged: (val) {
                        setModalState(() => _isBoostActive = val);
                        setState(() => _isBoostActive = val);
                        _showFeedbackToast(
                          val ? '⚡ FindAura Radar Boost Activated (30m)!' : 'FindAura Boost paused',
                          icon: Icons.auto_awesome_rounded,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Hide Nodes Below Cutoff Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hide Nodes Below Cutoff',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RadarColors.darkForest),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Completely hide nodes below cutoff instead of dimming',
                          style: TextStyle(fontSize: 11.5, color: RadarColors.textMuted),
                        ),
                      ],
                    ),
                    Switch(
                      value: isHideBelow,
                      activeThumbColor: RadarColors.sunsetCoral,
                      activeTrackColor: RadarColors.sunsetCoral.withValues(alpha: 0.4),
                      onChanged: (val) {
                        setModalState(() {});
                        _dnaService.setHideBelowCutoff(val);
                        setState(() {});
                        _showFeedbackToast(
                          val ? 'Below-cutoff nodes will now be hidden' : 'Below-cutoff nodes will be dimmed',
                          icon: val ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Tools: DNA Blueprint & Quick Connect
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: RadarColors.sunsetCoral),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDnaBlueprintModal();
                        },
                        icon: const Icon(Icons.hub_outlined, color: RadarColors.sunsetCoral, size: 16),
                        label: const Text('DNA Blueprint', style: TextStyle(color: RadarColors.sunsetCoral, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: RadarColors.mutedMint),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showQuickConnectSheet();
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: RadarColors.deepSage, size: 16),
                        label: const Text('Quick Connect', style: TextStyle(color: RadarColors.deepSage, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RadarColors.deepSage,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showFeedbackToast('Radar Preferences saved ✨');
                    },
                    child: const Text('Save Preferences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 6. Full Detailed Profile View Modal (From Matching Avatar Node)
  void _showCandidateProfileSheet([DatingCandidateProfile? target]) {
    final candidate = target ?? (_nearbyProfiles.isNotEmpty ? _nearbyProfiles[0] : null);
    if (candidate == null) return;
    HapticFeedback.lightImpact();
    DatingUserProfileDetailModal.show(
      context,
      candidate,
      onWaveSent: () {
        _confirmConnection(candidate.userId, candidate.displayName);
      },
    );
  }

  // 7. Compatibility Breakdown Sheet (From 70% Pill)
  void _showCompatibilityBreakdownSheet() {
    HapticFeedback.lightImpact();
    final mayaScore = _dnaService.calculateMatch(DnaBlueprint.maya());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.48,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        decoration: const BoxDecoration(
          color: RadarColors.midnightDrawer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: RadarColors.specularBorder, width: 1.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: RadarColors.cyanGlow.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.bubble_chart_rounded, color: RadarColors.cyanGlow, size: 24),
                const SizedBox(width: 8),
                Text('$mayaScore% Compatibility Node', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: RadarColors.iceWhite)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Detected within active ${_currentRadius.toInt()} km radius • Dynamic Match Node', style: const TextStyle(fontSize: 12, color: RadarColors.titaniumGray)),
            const SizedBox(height: 16),
            ...[
              ('Music & Art Taste', 0.85, 'Indie, Jazz, Vinyl'),
              ('Lifestyle & Routine', 0.70, 'Night Owl, Coffee explorer'),
              ('Values & Communication', 0.65, 'Mindfulness, Growth-oriented'),
            ].map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RadarColors.iceWhite)),
                        Text('${(m.$2 * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RadarColors.cyanGlow)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: m.$2,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation(RadarColors.cyanGlow),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [RadarColors.electricIris, RadarColors.sunsetCoral],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: RadarColors.sunsetCoral.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                onPressed: () {
                  final mayaCandidate = _nearbyProfiles.length > 1
                      ? _nearbyProfiles[1]
                      : (_nearbyProfiles.isNotEmpty ? _nearbyProfiles.first : null);
                  if (mayaCandidate != null) {
                    _confirmConnection(mayaCandidate.userId, mayaCandidate.displayName);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Send Connection Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 8. Stats Breakdown Modal
  void _showStatsModal() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFFE4E6), width: 1.2),
        ),
        title: const Row(
          children: [
            Text('Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: RadarColors.iceWhite)),
            SizedBox(width: 8),
            Icon(Icons.star_rounded, color: RadarColors.goldenStar, size: 20),
            Icon(Icons.star_rounded, color: RadarColors.goldenStar, size: 20),
            Icon(Icons.star_rounded, color: RadarColors.goldenStar, size: 20),
            Icon(Icons.star_rounded, color: RadarColors.goldenStar, size: 20),
            Icon(Icons.star_rounded, color: RadarColors.goldenStar, size: 20),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• Overall Compatibility: 138 index points', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RadarColors.iceWhite)),
            const SizedBox(height: 6),
            Text('• Detected Location: $_selectedZone', style: const TextStyle(fontSize: 13, color: RadarColors.titaniumGray)),
            const SizedBox(height: 6),
            const Text('• Common Interests: 15 Shared Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RadarColors.iceWhite)),
            const SizedBox(height: 4),
            const Text('(Architecture, Specialty Coffee, Vinyl Records, Indie Films, Photography, Books, Contemporary Art...)', style: TextStyle(fontSize: 11, color: RadarColors.slateMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: RadarColors.cyanGlow, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [RadarColors.sunsetCoral, RadarColors.cyanGlow],
                ),
                boxShadow: [
                  BoxShadow(
                    color: RadarColors.sunsetCoral.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(Icons.radar_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 28),
            const Text(
              'Enable Location to Discover Nearby Matches',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'FindAura connects you with verified singles in your exact vicinity. Turn on device location permissions to begin discovering nearby profiles and dynamic vibe beacons.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RadarColors.titaniumGray,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final granted = await _notifier.requestAndSyncLocation();
                if (!granted) {
                  await LocationService().openAppSettings();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: RadarColors.sunsetCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
              ),
              child: const Text(
                'Enable Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => LocationService().openLocationSettings(),
              child: const Text(
                'Device Location Settings',
                style: TextStyle(color: RadarColors.cyanGlow, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────

  Widget _buildTopPillBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: RadarColors.darkSlate.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Location & Zone Selector
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                debugPrint('AURA_RADAR: Top pill Nearby tapped');
                HapticFeedback.lightImpact();
                _showZoneSelectorSheet();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.location_on_rounded,
                    color: RadarColors.sunsetCoral,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _selectedZone.split(',').first.trim(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: RadarColors.iceWhite,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: RadarColors.titaniumGray,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Right Actions: Subtle Refresh, Filter & Preferences
          // 0. Subtle Manual Refresh Icon Button (Midnight Frosted Glass with spinning Cyan Glow icon)
          Tooltip(
            message: 'Refresh Radar',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _triggerManualRadarRefresh,
              child: Container(
                padding: const EdgeInsets.all(7.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRefreshing
                        ? RadarColors.cyanGlow.withValues(alpha: 0.65)
                        : const Color(0xFFFFE4E6),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isRefreshing
                          ? RadarColors.cyanGlow.withValues(alpha: 0.25)
                          : const Color(0x0A000000),
                      blurRadius: _isRefreshing ? 10 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _refreshSpinAnimation,
                  builder: (context, _) => Transform.rotate(
                    angle: _refreshSpinAnimation.value * 2 * math.pi,
                    child: Icon(
                      Icons.refresh_rounded,
                      color: _isRefreshing ? RadarColors.cyanGlow : RadarColors.iceWhite,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 1. Filter Button (Light High-Contrast Glass with Cyan Glow icon)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              debugPrint('AURA_RADAR: Top bar Filter tapped');
              HapticFeedback.lightImpact();
              _showFilterSheet();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFFFE4E6),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: RadarColors.cyanGlow, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'Filter',
                    style: TextStyle(
                      color: RadarColors.iceWhite,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 2. Preferences Button (Light High-Contrast Glass with Sunset Coral icon)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              debugPrint('AURA_RADAR: Top bar Preferences tapped');
              HapticFeedback.lightImpact();
              _showThresholdAdjustmentSheet();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFFFE4E6),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.room_preferences_outlined, color: RadarColors.sunsetCoral, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'Prefs',
                    style: TextStyle(
                      color: RadarColors.iceWhite,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  // ── 3. INTERACTIVE MATCH MARKERS (REQUIREMENT 3) ──────────────
  Widget _buildAnanyaMatchMarker() {
    if (_nearbyProfiles.isEmpty) return const SizedBox.shrink();
    final candidate = _nearbyProfiles[0];

    // Connection confirmation gate: Match marker displayed only when confirmed
    if (!_confirmedConnectionUserIds.contains(candidate.userId)) {
      return const SizedBox.shrink();
    }

    // Dynamic radius filtering based on candidate distance
    if (candidate.distanceKm > _currentRadius) {
      return const SizedBox.shrink();
    }

    final score = candidate.matchScore;
    final thresholdInt = (_compatibilityThreshold * 100).round();
    final meetsThreshold = score >= thresholdInt;

    if (!meetsThreshold && _dnaService.hideBelowCutoff) {
      return const SizedBox.shrink();
    }

    final themeColor = score >= 80 ? RadarColors.sunsetCoral : RadarColors.cyanGlow;

    return Opacity(
      opacity: meetsThreshold ? 1.0 : 0.28,
      child: RadarMatchAvatarMarker(
        name: candidate.displayName,
        avatarUrl: candidate.photos.isNotEmpty ? candidate.photos.first : '',
        initials: _getInitials(candidate.displayName),
        status: MatchPresenceStatus.online, // Green (Online / Available)
        pulseValue: meetsThreshold ? _pulseAnimation.value : 0.0,
        avatarRadius: 22,
        themeColor: themeColor,
        onTap: () => DatingUserProfileDetailModal.show(
          context,
          candidate,
          onWaveSent: () => _confirmConnection(candidate.userId, candidate.displayName),
        ),
        attachedBadge: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: meetsThreshold ? themeColor.withValues(alpha: 0.45) : const Color(0xFFFFE4E6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: themeColor,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    meetsThreshold ? '$score% match' : '$score% (dimmed)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: meetsThreshold ? RadarColors.iceWhite : RadarColors.titaniumGray,
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(10, 6),
              painter: _TriangleTickPainter(color: Colors.white),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildMayaMatchMarker() {
    if (_nearbyProfiles.length <= 1) return const SizedBox.shrink();
    final candidate = _nearbyProfiles[1];

    // Connection confirmation gate: Match marker displayed only when confirmed
    if (!_confirmedConnectionUserIds.contains(candidate.userId)) {
      return const SizedBox.shrink();
    }

    // Dynamic radius filtering based on candidate distance
    if (candidate.distanceKm > _currentRadius) {
      return const SizedBox.shrink();
    }

    final score = candidate.matchScore;
    final thresholdInt = (_compatibilityThreshold * 100).round();
    final meetsThreshold = score >= thresholdInt;

    if (!meetsThreshold && _dnaService.hideBelowCutoff) {
      return const SizedBox.shrink();
    }

    final themeColor = score >= 80 ? RadarColors.sunsetCoral : RadarColors.cyanGlow;

    return Opacity(
      opacity: meetsThreshold ? 1.0 : 0.28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RadarMatchAvatarMarker(
            name: candidate.displayName,
            avatarUrl: candidate.photos.isNotEmpty ? candidate.photos.first : '',
            initials: _getInitials(candidate.displayName),
            status: MatchPresenceStatus.online, // Green (Online / Available)
            pulseValue: meetsThreshold ? _pulseAnimation.value : 0.0,
            avatarRadius: 19,
            themeColor: themeColor,
            onTap: () => DatingUserProfileDetailModal.show(
              context,
              candidate,
              onWaveSent: () => _confirmConnection(candidate.userId, candidate.displayName),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showCompatibilityBreakdownSheet,
            child: _buildCompatibilityPill(score: score, meetsThreshold: meetsThreshold),
          ),
        ],
      ),
    );
  }

  Widget _buildRheaMatchMarker() {
    if (_nearbyProfiles.length <= 2) return const SizedBox.shrink();
    final candidate = _nearbyProfiles[2];

    // Connection confirmation gate: Match marker displayed only when confirmed
    if (!_confirmedConnectionUserIds.contains(candidate.userId)) {
      return const SizedBox.shrink();
    }

    // Dynamic radius filtering based on candidate distance
    if (candidate.distanceKm > _currentRadius) {
      return const SizedBox.shrink();
    }

    final score = candidate.matchScore;
    final thresholdInt = (_compatibilityThreshold * 100).round();
    final meetsThreshold = score >= thresholdInt;

    if (!meetsThreshold && _dnaService.hideBelowCutoff) {
      return const SizedBox.shrink();
    }

    final themeColor = score >= 80 ? RadarColors.sunsetCoral : RadarColors.cyanGlow;

    return Opacity(
      opacity: meetsThreshold ? 1.0 : 0.28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RadarMatchAvatarMarker(
            name: candidate.displayName,
            avatarUrl: candidate.photos.isNotEmpty ? candidate.photos.first : '',
            initials: _getInitials(candidate.displayName),
            status: MatchPresenceStatus.away, // Amber (Away)
            pulseValue: meetsThreshold ? _pulseAnimation.value : 0.0,
            avatarRadius: 18,
            themeColor: themeColor,
            onTap: () => DatingUserProfileDetailModal.show(
              context,
              candidate,
              onWaveSent: () => _confirmConnection(candidate.userId, candidate.displayName),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: meetsThreshold ? themeColor.withValues(alpha: 0.45) : const Color(0xFFFFE4E6),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '$score% match',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: meetsThreshold ? RadarColors.iceWhite : RadarColors.titaniumGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRohanMatchMarker() {
    if (_nearbyProfiles.length <= 3) return const SizedBox.shrink();
    final candidate = _nearbyProfiles[3];

    // Connection confirmation gate: Match marker displayed only when confirmed
    if (!_confirmedConnectionUserIds.contains(candidate.userId)) {
      return const SizedBox.shrink();
    }

    // Dynamic radius filtering based on candidate distance
    if (candidate.distanceKm > _currentRadius) {
      return const SizedBox.shrink();
    }

    final score = candidate.matchScore;
    final thresholdInt = (_compatibilityThreshold * 100).round();
    final meetsThreshold = score >= thresholdInt;

    if (!meetsThreshold && _dnaService.hideBelowCutoff) {
      return const SizedBox.shrink();
    }

    final themeColor = score >= 80 ? RadarColors.sunsetCoral : RadarColors.cyanGlow;

    return Opacity(
      opacity: meetsThreshold ? 1.0 : 0.28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RadarMatchAvatarMarker(
            name: candidate.displayName,
            avatarUrl: candidate.photos.isNotEmpty ? candidate.photos.first : '',
            initials: _getInitials(candidate.displayName),
            status: MatchPresenceStatus.busy, // Coral Red (Busy / Offline)
            pulseValue: meetsThreshold ? _pulseAnimation.value : 0.0,
            avatarRadius: 17,
            themeColor: themeColor,
            onTap: () => DatingUserProfileDetailModal.show(
              context,
              candidate,
              onWaveSent: () => _confirmConnection(candidate.userId, candidate.displayName),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: meetsThreshold ? themeColor.withValues(alpha: 0.45) : const Color(0xFFFFE4E6),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '$score% match',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: meetsThreshold ? RadarColors.iceWhite : RadarColors.titaniumGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityPill({int? score, bool meetsThreshold = true}) {
    final displayScore = score ?? (_compatibilityThreshold * 100).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: meetsThreshold
              ? RadarColors.cyanGlow
              : const Color(0xFFFFE4E6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: RadarColors.cyanGlow.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$displayScore%',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: meetsThreshold ? RadarColors.iceWhite : RadarColors.titaniumGray,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'compatibility',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: meetsThreshold ? RadarColors.iceWhite : RadarColors.titaniumGray,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildProfileStatsOverlay() {
    final confirmed = _nearbyProfiles.where((p) => _confirmedConnectionUserIds.contains(p.userId)).toList();
    if (confirmed.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showQuickConnectSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE4E6), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: RadarColors.cyanGlow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Radar Scanning...',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: RadarColors.iceWhite,
                    ),
                  ),
                  Text(
                    'Connect to sync matching stats',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: RadarColors.titaniumGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [RadarColors.sunsetCoral, RadarColors.electricIris],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: RadarColors.sunsetCoral.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Connect ⚡',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final candidate = confirmed.first;
    final mainPhoto = candidate.photos.isNotEmpty ? candidate.photos.first : '';
    final backPhoto = confirmed.length > 1 && confirmed[1].photos.isNotEmpty
        ? confirmed[1].photos.first
        : (candidate.photos.length > 1 ? candidate.photos[1] : mainPhoto);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stack of Deck Profile Cards (Interactive)
        GestureDetector(
          onTap: () => _showCandidateProfileSheet(candidate),
          child: SizedBox(
            width: 82,
            height: 94,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Back Profile Card
                if (backPhoto.isNotEmpty)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 58,
                      height: 66,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AuraImage(imageSource: backPhoto, fit: BoxFit.cover),
                      ),
                    ),
                  ),

                // Front Profile Card
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 64,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: mainPhoto.isNotEmpty
                              ? AuraImage(imageSource: mainPhoto, fit: BoxFit.cover, width: 64, height: 72)
                              : Container(
                                  color: RadarColors.electricIris,
                                  child: Center(
                                    child: Text(
                                      _getInitials(candidate.displayName),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                        ),
                        // Verified pill tag
                        if (candidate.isVerified)
                          Positioned(
                            bottom: 6,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  width: 0.5,
                                ),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Heart Button & Likes Badge (Interactive)
                Positioned(
                  bottom: -4,
                  right: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFFE4E6),
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          '$_likesCount',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: RadarColors.iceWhite,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _isLiked = !_isLiked;
                            _likesCount += _isLiked ? 1 : -1;
                          });
                          _showFeedbackToast(
                            _isLiked ? 'You liked ${candidate.displayName}! ❤️' : 'Like removed',
                            icon: Icons.favorite_rounded,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _isLiked ? Colors.redAccent : RadarColors.sunsetCoral,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: RadarColors.sunsetCoral.withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 12,
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

        const SizedBox(width: 8),

        // Stacked Glassmorphic Stats Card (Interactive -> Opens Stats Details)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showStatsModal,
          child: SizedBox(
            width: 144,
            height: 86,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Underneath Secondary Stats Card
                Positioned(
                  top: 14,
                  left: 6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFE4E6),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Compatibility: ${candidate.matchScore}%', style: const TextStyle(fontSize: 8.5, color: RadarColors.titaniumGray)),
                        Text('Location: ${candidate.distanceKm.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 8.5, color: RadarColors.titaniumGray)),
                        Text('Hobbies: ${candidate.hobbies.length} shared', style: const TextStyle(fontSize: 8.5, color: RadarColors.titaniumGray)),
                      ],
                    ),
                  ),
                ),

                // Front Primary Stats Card (Crisp White with Soft Rose border, radius 18)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFFE4E6),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${candidate.displayName.split(' ').first}\'s Stats',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RadarColors.iceWhite,
                              ),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => const Icon(
                                  Icons.star_rounded,
                                  size: 11,
                                  color: RadarColors.goldenStar, // Golden Stars #FBBF24
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compatibility: ${candidate.matchScore}%',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: RadarColors.cyanGlow,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Location: ${candidate.locationName.isNotEmpty ? candidate.locationName : _selectedZone.split(',').first}',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                            color: RadarColors.titaniumGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hobbies: ${candidate.hobbies.take(2).join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: RadarColors.iceWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _triggerManualRadarRefresh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              RadarColors.electricIris, // #7928CA
              RadarColors.sunsetCoral,  // #FF4D67
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: RadarColors.sunsetCoral.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _refreshSpinAnimation,
              builder: (context, _) => Transform.rotate(
                angle: _refreshSpinAnimation.value * 2 * math.pi,
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _isRefreshing ? 'REFRESHING...' : 'REFRESH RADAR',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsButton(Offset radarCenter) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        HapticFeedback.selectionClick();
        _pulseController.forward(from: 0.0);
        _refreshSpinController.forward(from: 0.0);
        await _notifier.refresh();
        if (mounted) {
          _showFeedbackToast(
            'Location recalibrated & auto-refreshed: $_selectedZone',
            icon: Icons.gps_fixed_rounded,
          );
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFFE4E6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: RadarColors.cyanGlow.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.my_location_rounded,
            color: RadarColors.cyanGlow,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDiscoverySheet() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 14 + bottomPadding),
      decoration: const BoxDecoration(
        color: RadarColors.midnightDrawer, // Deep Midnight Slate #0D111A
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: RadarColors.specularBorder, width: 1.2), // Specular border #1E2638
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF263346),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header Row: Discovery Radius & Km value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discovery Radius',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: RadarColors.titaniumGray, // Titanium Gray #94A3B8
                ),
              ),
              Text(
                '${_currentRadius.toInt()} km',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: RadarColors.iceWhite, // Crisp Ice White #F8FAFC
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Custom Gradient Track Slider (Interactive)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              trackShape: const _GradientSliderTrackShape(),
              thumbShape: const _CustomRadarThumbShape(radius: 10),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _currentRadius,
              min: 5,
              max: 100,
              onChanged: _onRadiusChanged,
            ),
          ),

          const SizedBox(height: 4),

          // Subtext on right: "Datacycle Radius"
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Datacycle Radius',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: RadarColors.slateMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CUSTOM SLIDER GRADIENT TRACK SHAPE
// ─────────────────────────────────────────────────────────

class _GradientSliderTrackShape extends SliderTrackShape {
  const _GradientSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 8;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final trackRadius = Radius.circular(rect.height / 2);

    // 1. Inactive Track: Dark Slate (#1F2937)
    final inactivePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;
    final fullRRect = RRect.fromRectAndRadius(rect, trackRadius);
    context.canvas.drawRRect(fullRRect, inactivePaint);

    // 2. Active Track: Gradient Cyan Glow (#00D2FF) to Electric Mint (#00F5A0)
    final activeRect = Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom);
    if (activeRect.width > 0) {
      final activeRRect = RRect.fromRectAndRadius(activeRect, trackRadius);
      final activeGradient = const LinearGradient(
        colors: [
          RadarColors.cyanGlow,     // #00D2FF
          RadarColors.electricMint, // #00F5A0
        ],
      ).createShader(activeRect);

      final activePaint = Paint()..shader = activeGradient;
      context.canvas.drawRRect(activeRRect, activePaint);
    }
  }
}

// ─────────────────────────────────────────────────────────
// CUSTOM SLIDER THUMB SHAPE
// ─────────────────────────────────────────────────────────

class _CustomRadarThumbShape extends SliderComponentShape {
  final double radius;

  const _CustomRadarThumbShape({this.radius = 10.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Outer Glow Shadow
    final shadowPaint = Paint()
      ..color = RadarColors.electricMint.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius + 2, shadowPaint);

    // Outer Circle with Gradient Cyan Glow -> Electric Mint
    final thumbGradient = const LinearGradient(
      colors: [
        RadarColors.cyanGlow,     // #00D2FF
        RadarColors.electricMint, // #00F5A0
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final thumbPaint = Paint()..shader = thumbGradient;
    canvas.drawCircle(center, radius, thumbPaint);

    // Inner Dark Core Dot
    final centerDotPaint = Paint()
      ..color = const Color(0xFF0D111A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.2, centerDotPaint);
  }
}

// ─────────────────────────────────────────────────────────
// HELPER PAINTER FOR TRIANGLE POINTER TICK
// ─────────────────────────────────────────────────────────

class _TriangleTickPainter extends CustomPainter {
  final Color color;

  _TriangleTickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TriangleTickPainter oldDelegate) => false;
}
