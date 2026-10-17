import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/core/services/firestore_discovery_service.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart';

/// Modal bottom sheet presenting a candidate user's full detailed dating profile:
/// - Full interactive multi-photo gallery PageView with dot indicators
/// - Distance, location, occupation, and dynamic hobby match score
/// - Interactive voice intro player with audio equalizer animation
/// - Icebreaker prompts cards
/// - Highlighted shared hobbies
/// - "Send Wave" and "Open Chat" actions
class DatingUserProfileDetailModal extends StatefulWidget {
  final DatingCandidateProfile profile;
  final VoidCallback? onWaveSent;

  const DatingUserProfileDetailModal({
    super.key,
    required this.profile,
    this.onWaveSent,
  });

  static void show(BuildContext context, DatingCandidateProfile profile, {VoidCallback? onWaveSent}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DatingUserProfileDetailModal(
        profile: profile,
        onWaveSent: onWaveSent,
      ),
    );
  }

  @override
  State<DatingUserProfileDetailModal> createState() => _DatingUserProfileDetailModalState();
}

class _DatingUserProfileDetailModalState extends State<DatingUserProfileDetailModal>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPhotoIndex = 0;

  // Voice Intro Player state
  bool _isPlayingVoice = false;
  double _voiceProgress = 0.0;
  Timer? _voiceTimer;
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _voiceTimer?.cancel();
    _waveformController.dispose();
    super.dispose();
  }

  void _toggleVoicePlayback() {
    HapticFeedback.selectionClick();
    setState(() {
      _isPlayingVoice = !_isPlayingVoice;
    });

    if (_isPlayingVoice) {
      _waveformController.repeat();
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) return;
        setState(() {
          _voiceProgress += 0.012;
          if (_voiceProgress >= 1.0) {
            _voiceProgress = 0.0;
            _isPlayingVoice = false;
            _waveformController.stop();
            timer.cancel();
          }
        });
      });
    } else {
      _waveformController.stop();
      _voiceTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final themeColor = p.matchScore >= 80 ? const Color(0xFFFF4D67) : const Color(0xFF00D2FF);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: Color(0xFFFFE4E6), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // 1. Photo Gallery Carousel with Tap-to-Advance & Indicators
                  _buildPhotoGallery(p, themeColor),

                  const SizedBox(height: 18),

                  // 2. Identity & Match Compatibility Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${p.displayName}, ${p.age}',
                                    style: const TextStyle(
                                      color: Color(0xFF181829),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                if (p.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF00D2FF),
                                    size: 22,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.occupation,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFFF4D67),
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${p.distanceKm} km away • ${p.locationName}',
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Dynamic Match Score Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7928CA), Color(0xFFFF4D67)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${p.matchScore}% Match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Looking For Intent Pill
                  if (p.relationshipGoal.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFE4E6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF3366),
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Looking for: ${p.relationshipGoal}',
                            style: const TextStyle(
                              color: Color(0xFF181829),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 18),

                  // 3. Voice Intro Player (Task 3 specification)
                  _buildVoiceIntroPlayer(p),

                  const SizedBox(height: 20),

                  // 4. Bio / About Section
                  const Text(
                    'About',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.bio,
                    style: const TextStyle(
                      color: Color(0xFF181829),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Hobbies & Overlapping Compatibility Tags
                  _buildHobbiesSection(p),

                  const SizedBox(height: 20),

                  // 6. Icebreaker Matching Prompts
                  _buildPromptsSection(p),

                  const SizedBox(height: 28),

                  // 7. Bottom Action Buttons (Wave & Chat)
                  _buildActionButtons(context, p),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(DatingCandidateProfile p, Color themeColor) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E2638), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // PageView
            PageView.builder(
              controller: _pageController,
              itemCount: p.photos.length,
              onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
              itemBuilder: (context, index) {
                final url = p.photos[index];
                return CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF131924),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00D2FF),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF131924),
                    child: const Icon(Icons.person, color: Colors.white30, size: 64),
                  ),
                );
              },
            ),

            // Subtle gradient overlay at top for indicators
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Tap photo zones (left for prev, right for next photo)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPhotoIndex > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPhotoIndex < p.photos.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Multi-Photo Indicator dashes
            if (p.photos.length > 1)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(
                    p.photos.length,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        height: 3.5,
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
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceIntroPlayer(DatingCandidateProfile p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPlayingVoice
              ? const Color(0xFFFF3366)
              : const Color(0xFFFFE4E6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3366).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFFFF3366),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Voice Intro Note',
                style: TextStyle(
                  color: Color(0xFF181829),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _isPlayingVoice ? 'Playing • 0:24' : 'Listen • 0:24',
                style: TextStyle(
                  color: _isPlayingVoice ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              // Play / Pause Circle Button
              GestureDetector(
                onTap: _toggleVoicePlayback,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7928CA), Color(0xFFFF4D67)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlayingVoice ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Animated Sound Waveform Visualizer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 32,
                      child: AnimatedBuilder(
                        animation: _waveformController,
                        builder: (context, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(24, (index) {
                              final wavePhase = (_waveformController.value * 2 * math.pi) + (index * 0.35);
                              final animHeight = _isPlayingVoice
                                  ? (8.0 + (math.sin(wavePhase).abs() * 22.0))
                                  : (6.0 + (index % 5) * 4.0);

                              final isPassed = (index / 24.0) <= _voiceProgress;

                              return Container(
                                width: 3.2,
                                height: animHeight,
                                decoration: BoxDecoration(
                                  color: isPassed
                                      ? const Color(0xFFFF4D67)
                                      : (_isPlayingVoice
                                          ? const Color(0xFF00D2FF).withValues(alpha: 0.7)
                                          : const Color(0xFF64748B)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Progress track
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _voiceProgress,
                        minHeight: 3,
                        backgroundColor: const Color(0xFF1E2638),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4D67)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHobbiesSection(DatingCandidateProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Interests & Hobbies',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (p.commonHobbies.isNotEmpty) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F5A0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00F5A0).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${p.commonHobbies.length} Shared Interests ✨',
                  style: const TextStyle(
                    color: Color(0xFF00F5A0),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: p.hobbies.map((hobby) {
            final isCommon = p.commonHobbies.any(
              (ch) => ch.trim().toLowerCase() == hobby.trim().toLowerCase(),
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isCommon
                    ? const Color(0xFFFF3366).withValues(alpha: 0.12)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCommon
                      ? const Color(0xFFFF3366)
                      : const Color(0xFFFFE4E6),
                  width: isCommon ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCommon) ...[
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFF3366),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    hobby,
                    style: TextStyle(
                      color: isCommon ? const Color(0xFFFF3366) : const Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: isCommon ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPromptsSection(DatingCandidateProfile p) {
    if (p.prompts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Matching Prompts',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...p.prompts.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFE4E6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.value,
                  style: const TextStyle(
                    color: Color(0xFF181829),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, DatingCandidateProfile p) {
    return Row(
      children: [
        // Send Wave Button
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF00D2FF).withValues(alpha: 0.08),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onWaveSent?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.waving_hand_rounded, color: Color(0xFF00D2FF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aura Wave sent to ${p.displayName}! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF131924),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            },
            icon: const Icon(Icons.waving_hand_rounded, color: Color(0xFF00D2FF), size: 18),
            label: const Text(
              'Send Wave',
              style: TextStyle(
                color: Color(0xFF00D2FF),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Open Chat / Message Button
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7928CA), Color(0xFFFF4D67)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
                final currentUid = FirestoreDiscoveryService().auth.currentUser?.uid ?? 'usr_me';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      matchId: 'match_${p.userId}',
                      matchName: p.displayName,
                      matchAvatarUrl: p.photos.isNotEmpty ? p.photos.first : null,
                      currentUserId: currentUid,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Open Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
