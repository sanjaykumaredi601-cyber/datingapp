import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'package:aura_app/core/services/firestore_discovery_service.dart';
import 'package:aura_app/features/discovery/presentation/widgets/dating_user_profile_detail_modal.dart';

class DiscoveryProfile {
  final String id;
  final String name;
  final int age;
  final String bio;
  final String distance;
  final String location;
  final String occupation;
  final List<String> photos;
  final List<String> tags;
  final bool isVerified;
  final String lookingFor;
  final DatingCandidateProfile? candidate;

  const DiscoveryProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.bio,
    required this.distance,
    required this.location,
    required this.occupation,
    required this.photos,
    required this.tags,
    this.isVerified = true,
    this.lookingFor = 'Long-term connection',
    this.candidate,
  });

  factory DiscoveryProfile.fromCandidate(DatingCandidateProfile c) {
    return DiscoveryProfile(
      id: c.userId,
      name: c.displayName,
      age: c.age,
      bio: c.bio,
      distance: '${c.distanceKm} km away',
      location: c.locationName,
      occupation: c.occupation,
      photos: c.photos,
      tags: c.hobbies,
      isVerified: c.isVerified,
      lookingFor: c.relationshipGoal,
      candidate: c,
    );
  }
}

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  bool _isGridView = false;
  int _currentIndex = 0;
  int _currentPhotoIndex = 0;
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  List<DiscoveryProfile> _profiles = [];
  bool _isLoading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadProfilesFromFirestore();
  }

  Future<void> _loadProfilesFromFirestore() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });
    try {
      final locResult = await LocationService().getCurrentLocation().timeout(
        const Duration(seconds: 4),
        onTimeout: () => LocationResult.defaultFallback(reason: 'GPS timeout'),
      );
      if (locResult.status == LocationResolutionStatus.permissionDenied ||
          locResult.status == LocationResolutionStatus.permissionDeniedForever) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _isLoading = false;
          });
        }
        return;
      }

      final lat = (locResult.latitude != 0.0) ? locResult.latitude : 19.0596;
      final lng = (locResult.longitude != 0.0) ? locResult.longitude : 72.8295;

      final candidates = await FirestoreDiscoveryService().fetchNearbyUsers(
        centerLat: lat,
        centerLng: lng,
        radiusKm: 50,
      );
      if (mounted) {
        setState(() {
          _profiles = candidates.map((c) => DiscoveryProfile.fromCandidate(c)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DiscoveryFeedScreen] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _onSwipe(bool isLike, {bool isSuperLike = false}) {
    HapticFeedback.mediumImpact();
    if (_currentIndex >= _profiles.length) return;

    final profile = _profiles[_currentIndex];

    // Trigger match celebration on second profile for demo excitement
    if (isLike && (_currentIndex == 0 || isSuperLike)) {
      _showMatchDialog(profile);
    }

    setState(() {
      _currentIndex++;
      _currentPhotoIndex = 0;
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
    });
  }

  void _showMatchDialog(DiscoveryProfile profile) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceL1,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.auroraTeal.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.auroraGradient.createShader(bounds),
                child: const Text(
                  'IT\'S A MATCH!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You and ${profile.name} both liked each other\'s Aura.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 80,
                width: 144,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceL1, width: 3),
                        ),
                        child: const CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.auroraPurple,
                          child: Icon(Icons.person, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceL1, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.auroraTeal,
                          backgroundImage: NetworkImage(profile.photos.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        matchId: 'match_${profile.id}',
                        matchName: profile.name,
                        currentUserId: 'user_me_001',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.auroraTeal,
                  foregroundColor: const Color(0xFF0D0D1A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Send a Message',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Keep Exploring',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDetails(DiscoveryProfile profile) {
    if (profile.candidate != null) {
      DatingUserProfileDetailModal.show(context, profile.candidate!);
      return;
    }

    // Synthesize candidate profile from profile data if direct reference is missing
    final candidate = DatingCandidateProfile(
      userId: profile.id,
      displayName: profile.name,
      age: profile.age,
      gender: 'Woman',
      interestedIn: 'Everyone',
      relationshipGoal: profile.lookingFor,
      occupation: profile.occupation,
      bio: profile.bio,
      locationName: profile.location,
      latitude: 19.0596,
      longitude: 72.8295,
      photos: profile.photos,
      hobbies: profile.tags,
      isVerified: profile.isVerified,
      distanceKm: double.tryParse(profile.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.5,
      matchScore: 84,
      prompts: {
        'A fun fact about me...': 'Architect by day, vinyl collector by night.',
        'My ideal weekend...': 'Getting iced matcha and exploring vintage art galleries.',
      },
      introMediaUrl: 'https://example.com/audio/sample_intro.m4a',
    );
    DatingUserProfileDetailModal.show(context, candidate);
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: _buildLocationPermissionPrompt()),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D67)),
        ),
      );
    }

    final hasProfiles = _currentIndex < _profiles.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'aura',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Color(0xFF181829),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3366).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.35)),
              ),
              child: const Text(
                'DISCOVER',
                style: TextStyle(
                  color: Color(0xFFFF3366),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
            tooltip: 'Filter Preferences',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filter radius: 25 km • Age: 20-30 • Verified only'),
                  backgroundColor: AppColors.surfaceL2,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _isGridView ? _buildGridView() : _buildSwipeDeck(hasProfiles),
            ),
            Positioned(
              top: 10,
              right: 14,
              child: _buildViewToggleFloatingPill(),
            ),
          ],
        ),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7928CA), Color(0xFFFF4D67)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.location_on_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Enable Location to Discover Nearby Matches',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aura connects you with genuine singles around you. Turn on location services to explore candidates in your area.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () async {
                final perm = await LocationService().requestPermission();
                if (perm == LocationPermission.deniedForever) {
                  await LocationService().openAppSettings();
                }
                _loadProfilesFromFirestore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D67),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                'Enable Location',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleFloatingPill() {
    const Color darkSlate = Color(0xFF0F141C);
    const Color mutedSlate = Color(0xFF8E9DAE);

    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: darkSlate.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2838), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isGridView) {
                HapticFeedback.selectionClick();
                setState(() => _isGridView = false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: !_isGridView
                    ? const LinearGradient(
                        colors: [Color(0xFF7928CA), Color(0xFFFF4D67)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !_isGridView ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_carousel_rounded,
                    size: 14,
                    color: !_isGridView ? Colors.white : mutedSlate,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Swipe',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: !_isGridView ? Colors.white : mutedSlate,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_isGridView) {
                HapticFeedback.selectionClick();
                setState(() => _isGridView = true);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: _isGridView
                    ? const LinearGradient(
                        colors: [Color(0xFF7928CA), Color(0xFFFF4D67)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _isGridView ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 14,
                    color: _isGridView ? Colors.white : mutedSlate,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Grid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isGridView ? Colors.white : mutedSlate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeDeck(bool hasProfiles) {
    if (!hasProfiles) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceL1,
                  border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.radar_rounded, size: 44, color: AppColors.auroraTeal),
              ),
              const SizedBox(height: 24),
              const Text(
                'You\'ve Caught Up!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'There are no more new profiles in your 25km radius right now. Expand your radar or reset to review.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _currentIndex = 0;
                  _currentPhotoIndex = 0;
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset Profiles'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceL2,
                  foregroundColor: AppColors.auroraTeal,
                  side: const BorderSide(color: AppColors.auroraTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentProfile = _profiles[_currentIndex];
    final nextProfile =
        _currentIndex + 1 < _profiles.length ? _profiles[_currentIndex + 1] : null;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Stack(
              children: [
                // Background Card (Next in Deck)
                if (nextProfile != null)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.95,
                      child: Opacity(
                        opacity: 0.6,
                        child: _buildProfileCard(nextProfile, isInteractive: false),
                      ),
                    ),
                  ),

                // Foreground Card (Interactive Draggable)
                Positioned.fill(
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _dragOffset += details.delta;
                        _dragAngle = _dragOffset.dx / 300.0 * 0.2;
                      });
                    },
                    onPanEnd: (details) {
                      if (_dragOffset.dx > 120) {
                        _onSwipe(true);
                      } else if (_dragOffset.dx < -120) {
                        _onSwipe(false);
                      } else if (_dragOffset.dy < -120) {
                        _onSwipe(true, isSuperLike: true);
                      } else {
                        setState(() {
                          _dragOffset = Offset.zero;
                          _dragAngle = 0.0;
                        });
                      }
                    },
                    child: Transform.translate(
                      offset: _dragOffset,
                      child: Transform.rotate(
                        angle: _dragAngle,
                        child: Stack(
                          children: [
                            _buildProfileCard(currentProfile, isInteractive: true),
                            // Like / Nope Stamps
                            if (_dragOffset.dx > 40)
                              Positioned(
                                top: 40,
                                left: 30,
                                child: Transform.rotate(
                                  angle: -0.2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppColors.auroraTeal, width: 3),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.black.withValues(alpha: 0.3),
                                    ),
                                    child: const Text(
                                      'LIKE',
                                      style: TextStyle(
                                        color: AppColors.auroraTeal,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_dragOffset.dx < -40)
                              Positioned(
                                top: 40,
                                right: 30,
                                child: Transform.rotate(
                                  angle: 0.2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppColors.error, width: 3),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.black.withValues(alpha: 0.3),
                                    ),
                                    child: const Text(
                                      'PASS',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_dragOffset.dy < -40 && _dragOffset.dx.abs() < 40)
                              Positioned(
                                top: 40,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppColors.auroraGold, width: 3),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.black.withValues(alpha: 0.3),
                                    ),
                                    child: const Text(
                                      'SUPER LIKE',
                                      style: TextStyle(
                                        color: AppColors.auroraGold,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating Action Dock Container: Deep glass floating bar with blur: 16px
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F131D).withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rewind Button (Yellow #FBBF24)
                      _buildActionButton(
                        icon: Icons.replay_rounded,
                        color: const Color(0xFFFBBF24),
                        size: 44,
                        onPressed: () {
                          if (_currentIndex > 0) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _currentIndex--;
                              _currentPhotoIndex = 0;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      // Dislike/Pass (Neon Sunset Coral #FF4D67)
                      _buildActionButton(
                        icon: Icons.close_rounded,
                        color: const Color(0xFFFF4D67),
                        size: 54,
                        onPressed: () => _onSwipe(false),
                      ),
                      const SizedBox(width: 12),
                      // Super Star (Soft Gold #F59E0B)
                      _buildActionButton(
                        icon: Icons.star_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 46,
                        onPressed: () => _onSwipe(true, isSuperLike: true),
                      ),
                      const SizedBox(width: 12),
                      // Like Heart (Electric Iris & Rose Gold Gradient)
                      _buildGradientActionButton(
                        icon: Icons.favorite_rounded,
                        gradientColors: const [Color(0xFF7928CA), Color(0xFFF472B6)],
                        size: 54,
                        onPressed: () => _onSwipe(true),
                      ),
                      const SizedBox(width: 12),
                      // Info (Translucent Slate)
                      _buildActionButton(
                        icon: Icons.info_outline_rounded,
                        color: const Color(0xFF8E9DAE),
                        size: 44,
                        onPressed: () => _showProfileDetails(currentProfile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildGradientActionButton({
    required IconData icon,
    required List<Color> gradientColors,
    required double size,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildProfileCard(DiscoveryProfile profile, {required bool isInteractive}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Photo View
            Positioned.fill(
              child: Image.network(
                profile.photos[_currentPhotoIndex.clamp(0, profile.photos.length - 1)],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceL2,
                  child: const Center(
                    child: Icon(Icons.person, size: 80, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),

            // Tap photo zones (left for prev, right for next photo)
            if (isInteractive && profile.photos.length > 1)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_currentPhotoIndex > 0) {
                            setState(() => _currentPhotoIndex--);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_currentPhotoIndex < profile.photos.length - 1) {
                            setState(() => _currentPhotoIndex++);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Photo Indicator Dots
            if (profile.photos.length > 1)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(
                    profile.photos.length,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == _currentPhotoIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Subtle dark vignette gradient from bottom to mid-card (#080A0F to transparent)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 280,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x99080A0F),
                      Color(0xF0080A0F),
                      Color(0xFF080A0F),
                    ],
                    stops: [0.0, 0.4, 0.75, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Profile Info Overlay
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showProfileDetails(profile),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${profile.name}, ${profile.age}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Color(0xFF00D2FF), size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFFF4D67), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${profile.distance} • ${profile.location}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Interest chips: Glassmorphic dark slate with rgba(255, 255, 255, 0.12) border
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: profile.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131924).withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        return GestureDetector(
          onTap: () => _showProfileDetails(profile),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    profile.photos.first,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.name}, ${profile.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          profile.distance,
                          style: const TextStyle(
                            color: AppColors.auroraTeal,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
