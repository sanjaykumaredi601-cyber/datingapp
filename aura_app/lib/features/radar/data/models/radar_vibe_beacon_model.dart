import 'package:flutter/material.dart';

/// Micro-event temporary activity broadcast beacon on the Proximity Radar.
class RadarVibeBeaconModel {
  final String id;
  final String hostUid;
  final String hostName;
  final String hostAvatar;
  final String activityType;
  final String activityIcon;
  final String locationLabel;
  final int distanceMeters;
  final int slotsTotal;
  final int slotsRemaining;
  final int expiresInMinutes;
  final Color accentColor;

  const RadarVibeBeaconModel({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.hostAvatar,
    required this.activityType,
    required this.activityIcon,
    required this.locationLabel,
    required this.distanceMeters,
    this.slotsTotal = 2,
    this.slotsRemaining = 1,
    this.expiresInMinutes = 115,
    this.accentColor = const Color(0xFFF59E0B),
  });

  static List<RadarVibeBeaconModel> sampleBeacons() {
    return const [
      RadarVibeBeaconModel(
        id: 'vibe_01',
        hostUid: 'host_maya',
        hostName: 'Maya K.',
        hostAvatar: 'assets/mock/avatar_maya.jpg',
        activityType: 'Live Jazz Lounge & Wine',
        activityIcon: '🎷',
        locationLabel: 'The Blue Note Room (Bandra)',
        distanceMeters: 380,
        slotsTotal: 2,
        slotsRemaining: 1,
        expiresInMinutes: 85,
        accentColor: Color(0xFFF59E0B),
      ),
      RadarVibeBeaconModel(
        id: 'vibe_02',
        hostUid: 'host_elena',
        hostName: 'Elena V.',
        hostAvatar: 'assets/mock/avatar_elena.jpg',
        activityType: 'Art Gallery & Espresso Walk',
        activityIcon: '🎨',
        locationLabel: 'Kala Ghoda Pavilion',
        distanceMeters: 750,
        slotsTotal: 4,
        slotsRemaining: 2,
        expiresInMinutes: 110,
        accentColor: Color(0xFF67E8F9),
      ),
    ];
  }
}
