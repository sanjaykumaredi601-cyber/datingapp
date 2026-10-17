import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/features/radar/data/models/radar_vibe_beacon_model.dart';

/// Bottom sheet allowing users to broadcast a 2-hour Proximity Vibe Beacon
/// or request to join an active broadcast.
class HostVibeBottomSheet extends StatefulWidget {
  final Function(RadarVibeBeaconModel beacon) onVibeBroadcasted;

  const HostVibeBottomSheet({
    super.key,
    required this.onVibeBroadcasted,
  });

  static Future<void> show(BuildContext context, {required Function(RadarVibeBeaconModel) onBroadcast}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HostVibeBottomSheet(onVibeBroadcasted: onBroadcast),
    );
  }

  @override
  State<HostVibeBottomSheet> createState() => _HostVibeBottomSheetState();
}

class _HostVibeBottomSheetState extends State<HostVibeBottomSheet> {
  int _selectedActivityIndex = 0;
  int _selectedSlots = 2; // 2 = 1-on-1, 4 = Small Circle

  static const List<Map<String, String>> activities = [
    {'title': 'Coffee & Walk', 'icon': '☕', 'vibe': 'Spontaneous stroll & roast'},
    {'title': 'Live Jazz Lounge', 'icon': '🎷', 'vibe': 'Intimate cocktail acoustics'},
    {'title': 'Late Night Drive', 'icon': '🌃', 'vibe': 'City skyline frequency'},
    {'title': 'Art Gallery & Wine', 'icon': '🎨', 'vibe': 'Curated culture & talk'},
    {'title': 'Rooftop Sunset Drinks', 'icon': '🍸', 'vibe': 'Golden hour aperitivo'},
  ];

  void _broadcastVibe() {
    HapticFeedback.heavyImpact();
    final act = activities[_selectedActivityIndex];
    final beacon = RadarVibeBeaconModel(
      id: 'vibe_${DateTime.now().millisecondsSinceEpoch}',
      hostUid: 'current_user',
      hostName: 'You',
      hostAvatar: '',
      activityType: act['title']!,
      activityIcon: act['icon']!,
      locationLabel: 'Within 500m Proximity Radar',
      distanceMeters: 150,
      slotsTotal: _selectedSlots,
      slotsRemaining: _selectedSlots - 1,
      expiresInMinutes: 120,
      accentColor: const Color(0xFFF59E0B),
    );

    Navigator.pop(context);
    widget.onVibeBroadcasted(beacon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFFFE4E6), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                ),
                child: const Text('✨', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Host a Proximity Vibe',
                      style: TextStyle(
                        color: Color(0xFF181829),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Broadcast an ephemeral 2-hour activity within 500m-2km',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Activity selection
          const Text(
            'SELECT VIBE ACTIVITY',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ...activities.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isSelected = _selectedActivityIndex == idx;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedActivityIndex = idx);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFFFE4E6),
                  ),
                ),
                child: Row(
                  children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFB45309) : const Color(0xFF181829),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          Text(
                            item['vibe']!,
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFF59E0B)),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          // Slot count selector
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSlots = 2);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedSlots == 2
                          ? const Color(0xFFFF3366)
                          : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSlots == 2
                            ? const Color(0xFFFF3366)
                            : const Color(0xFFFFE4E6),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '1-on-1 Meetup',
                        style: TextStyle(
                          color: _selectedSlots == 2 ? Colors.white : const Color(0xFF181829),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSlots = 4);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedSlots == 4
                          ? const Color(0xFFFF3366)
                          : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSlots == 4
                            ? const Color(0xFFFF3366)
                            : const Color(0xFFFFE4E6),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Small Circle (Up to 4)',
                        style: TextStyle(
                          color: _selectedSlots == 4 ? Colors.white : const Color(0xFF181829),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Broadcast CTA
          ElevatedButton(
            onPressed: _broadcastVibe,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.radar_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'Broadcast Vibe Beacon (2 Hours)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
