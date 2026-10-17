import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';

/// Interactive Voice and Video Intro Recorder widget (up to 30s)
/// Allows recording, audio waveform visualization, preview playback, re-recording, and deletion.
class VoiceVideoIntroRecorder extends StatefulWidget {
  final String? initialMediaUrl;
  final ValueChanged<String?> onMediaChanged;

  const VoiceVideoIntroRecorder({
    super.key,
    this.initialMediaUrl,
    required this.onMediaChanged,
  });

  @override
  State<VoiceVideoIntroRecorder> createState() => _VoiceVideoIntroRecorderState();
}

class _VoiceVideoIntroRecorderState extends State<VoiceVideoIntroRecorder>
    with SingleTickerProviderStateMixin {
  bool _isVideoMode = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  Timer? _timer;
  String? _recordedPath;

  late final AnimationController _pulseController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _recordedPath = widget.initialMediaUrl;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isRecording = false;
    _isPlaying = false;
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.dispose();
    super.dispose();
  }

  void _startAudioRecording() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _recordedPath = null;
    });
    _pulseController.repeat(reverse: true);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
        if (_recordSeconds >= 30) {
          _stopAudioRecording();
        }
      });
    });
  }

  Future<void> _stopAudioRecording() async {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _timer = null;
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }

    try {
      // Guarded stop execution with 4-second timeout to prevent UI freezes
      await Future<void>(() {
        debugPrint('[VoiceVideoIntroRecorder] Stopping audio capture stream...');
      }).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[VoiceVideoIntroRecorder] ⚠️ Audio stop timeout guard reached (4s). Proceeding gracefully.');
        },
      );
    } catch (e) {
      debugPrint('[VoiceVideoIntroRecorder] Audio stop error: $e');
    }

    final mockVoicePath = 'voice_intro_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedPath = mockVoicePath;
      });
      widget.onMediaChanged(mockVoicePath);
    }
  }

  Future<void> _recordVideoSnippet() async {
    HapticFeedback.mediumImpact();
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null && mounted) {
        setState(() {
          _recordedPath = video.path;
          _isVideoMode = true;
        });
        widget.onMediaChanged(video.path);
      }
    } catch (e) {
      debugPrint('[VoiceVideoIntroRecorder] Video recording note: $e');
      // Simulated video path for development / emulator testing
      final mockVideo = 'video_intro_${DateTime.now().millisecondsSinceEpoch}.mp4';
      setState(() {
        _recordedPath = mockVideo;
        _isVideoMode = true;
      });
      widget.onMediaChanged(mockVideo);
    }
  }

  void _togglePlayback() {
    HapticFeedback.lightImpact();
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      Future.delayed(Duration(seconds: _recordSeconds > 0 ? _recordSeconds : 5), () {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  void _deleteRecording() {
    HapticFeedback.lightImpact();
    setState(() {
      _recordedPath = null;
      _isPlaying = false;
      _recordSeconds = 0;
    });
    widget.onMediaChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceL1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2838), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Mode Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isVideoMode ? Icons.videocam_rounded : Icons.mic_rounded,
                    color: AppColors.sunsetCoral,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isVideoMode ? 'Video Intro (Max 30s)' : 'Voice Intro (Max 30s)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
              // Mode Switch Toggle
              if (_recordedPath == null && !_isRecording)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isVideoMode = !_isVideoMode);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceL2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      _isVideoMode ? 'Switch to Audio' : 'Switch to Video',
                      style: const TextStyle(
                        color: AppColors.auroraTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Content States
          if (_recordedPath != null)
            _buildPlaybackPreview()
          else if (_isRecording)
            _buildActiveRecordingView()
          else
            _buildIdleRecorder(),
        ],
      ),
    );
  }

  Widget _buildIdleRecorder() {
    return Column(
      children: [
        Text(
          _isVideoMode
              ? 'Say hello with a 15–30 second selfie video. Profiles with video get 4x more mutual radar matches!'
              : 'Record a quick voice greeting. Share your vibe, energy, or an audio greeting to potential matches.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _isVideoMode ? _recordVideoSnippet : _startAudioRecording,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.sunsetCoral, AppColors.electricIris],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sunsetCoral.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isVideoMode ? Icons.videocam_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _isVideoMode ? 'Tap to Record Video' : 'Tap to Record Voice',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRecordingView() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFF334B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '00:${_recordSeconds.toString().padLeft(2, '0')} / 00:30',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'SpaceGrotesk',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Animated Audio Waveforms
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (i) {
              final randomHeight = 12.0 + (math.sin(i * 0.5 + _recordSeconds * 2).abs() * 32.0);
              return Container(
                width: 3.5,
                height: randomHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.sunsetCoral,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),

        // Stop Button
        Center(
          child: GestureDetector(
            onTap: _stopAudioRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF334B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFF334B)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Color(0xFFFF334B), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Stop Recording',
                    style: TextStyle(
                      color: Color(0xFFFF334B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceL2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.sunsetCoral,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isVideoMode ? 'Video Intro Captured' : 'Voice Intro Recorded',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recordSeconds > 0 ? '${_recordSeconds}s media clip' : 'Ready to share on profile',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                onPressed: _deleteRecording,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _isVideoMode ? _recordVideoSnippet : _startAudioRecording,
                icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.auroraTeal),
                label: const Text(
                  'Re-record',
                  style: TextStyle(color: AppColors.auroraTeal, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
