import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Preset lens filters for the AR / Beauty camera module
enum BeautyLensFilter {
  goldenHour('Golden Hour', Icons.wb_sunny_rounded, Color(0xFFF59E0B), Color(0xFFFF6B6B)),
  cyberNeon('Cyber Neon', Icons.blur_on_rounded, Color(0xFF00F2FE), Color(0xFF4FACFE)),
  vintageFilm('Vintage 35mm', Icons.camera_roll_rounded, Color(0xFFD97706), Color(0xFF78350F)),
  softBloom('Soft Bloom', Icons.auto_awesome_rounded, Color(0xFFEC4899), Color(0xFFF472B6)),
  monochromeNoir('Mono Noir', Icons.contrast_rounded, Color(0xFFE2E8F0), Color(0xFF1E293B)),
  sunsetVelvet('Sunset Velvet', Icons.local_fire_department_rounded, Color(0xFFFF5252), Color(0xFFFF7A00));

  final String label;
  final IconData icon;
  final Color primary;
  final Color secondary;

  const BeautyLensFilter(this.label, this.icon, this.primary, this.secondary);
}

/// Extensible Camera Capture Screen with real-time AR filter / beauty lens overlays
class CameraFilterCaptureScreen extends StatefulWidget {
  const CameraFilterCaptureScreen({super.key});

  static Future<String?> show(BuildContext context) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CameraFilterCaptureScreen(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<CameraFilterCaptureScreen> createState() => _CameraFilterCaptureScreenState();
}

class _CameraFilterCaptureScreenState extends State<CameraFilterCaptureScreen>
    with SingleTickerProviderStateMixin {
  BeautyLensFilter _selectedFilter = BeautyLensFilter.goldenHour;
  double _filterIntensity = 0.75;
  bool _isFrontCamera = true;
  bool _isCapturing = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleCapture() {
    HapticFeedback.heavyImpact();
    setState(() => _isCapturing = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      // Generate a stylized captured lens image URL / mock path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final lensName = _selectedFilter.name;
      final capturedPath = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80#filter=$lensName&ts=$timestamp';
      Navigator.of(context).pop(capturedPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Camera Viewfinder Canvas with AR Filter Overlay ──
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base camera sensor stream (simulated atmospheric portrait feed)
                Image.network(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF131A27),
                    child: const Center(
                      child: Icon(Icons.person, size: 100, color: Colors.white24),
                    ),
                  ),
                ),

                // Real-time Shader / Beauty Lens Color Filter
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _selectedFilter.primary.withValues(alpha: 0.28 * _filterIntensity),
                        _selectedFilter.secondary.withValues(alpha: 0.20 * _filterIntensity),
                      ],
                    ),
                  ),
                ),

                // Vignette Edge Softener
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),

                // AR Reticle Frame
                Center(
                  child: Container(
                    width: size.width * 0.82,
                    height: size.height * 0.58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _selectedFilter.primary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Top Navigation Bar ──
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Icon(_selectedFilter.icon, size: 15, color: _selectedFilter.primary),
                      const SizedBox(width: 6),
                      Text(
                        _selectedFilter.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isFrontCamera = !_isFrontCamera);
                  },
                ),
              ],
            ),
          ),

          // ── 3. Bottom Controls Panel ──
          Positioned(
            bottom: bottomPadding + 16,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter Intensity Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: _selectedFilter.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _filterIntensity,
                            onChanged: (val) => setState(() => _filterIntensity = val),
                          ),
                        ),
                      ),
                      Text(
                        '${(_filterIntensity * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Lens Carousel Selector
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: BeautyLensFilter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final lens = BeautyLensFilter.values[index];
                      final isSelected = lens == _selectedFilter;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = lens);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? lens.primary.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected ? lens.primary : Colors.white24,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(lens.icon, size: 15, color: lens.primary),
                              const SizedBox(width: 6),
                              Text(
                                lens.label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Shutter Button
                GestureDetector(
                  onTap: _isCapturing ? null : _handleCapture,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_selectedFilter.primary, _selectedFilter.secondary],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            )
                          : const SizedBox.shrink(),
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
