import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/services/voice_note_service.dart';

/// 30-Second Audio Voice Bio / Prompt Component ("Aura Voice Vibe")
/// Features a luxury frosted glass audio pill with dancing neon waveform bars
/// in Sunset Coral (#FF4D67) and Electric Iris (#7928CA).
class AuraVoiceVibeWidget extends StatefulWidget {
  final String? initialAudioUrl;
  final String initialPrompt;
  final bool isEditable;
  final Function(String audioPath, String prompt)? onSaved;
  final void Function(String prompt, String audioPath)? onRecordingCompleted;

  const AuraVoiceVibeWidget({
    super.key,
    this.initialAudioUrl,
    this.initialPrompt = 'My idea of an ideal spontaneous evening...',
    this.isEditable = true,
    this.onSaved,
    this.onRecordingCompleted,
  });

  @override
  State<AuraVoiceVibeWidget> createState() => _AuraVoiceVibeWidgetState();
}

class _AuraVoiceVibeWidgetState extends State<AuraVoiceVibeWidget>
    with SingleTickerProviderStateMixin {
  final VoiceNoteService _voiceService = VoiceNoteService();
  late AnimationController _waveController;
  late String _selectedPrompt;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _currentAudioPath;
  StreamSubscription<PlayerState>? _playerSub;

  static const List<String> availablePrompts = [
    'My idea of an ideal spontaneous evening...',
    'The vibe track that defines my frequency...',
    'If we crossed paths within 500m right now...',
    'A secret spot in my city you must experience...',
    'Unfiltered truth: what immediately captures my energy...',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPrompt = widget.initialPrompt;
    _currentAudioPath = widget.initialAudioUrl;
    _hasRecording = widget.initialAudioUrl != null;

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        if (_isPlaying || _isRecording) setState(() {});
      });

    _playerSub = _voiceService.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (_isPlaying) {
          if (!_waveController.isAnimating) _waveController.repeat(reverse: true);
        } else {
          _waveController.stop();
        }
      });
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playerSub?.cancel();
    _voiceService.stopAudio();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    HapticFeedback.selectionClick();
    if (_isPlaying) {
      await _voiceService.pauseAudio();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _waveController.stop();
        });
      }
    } else {
      final audioTarget = _currentAudioPath ?? widget.initialAudioUrl ?? '/users/current/voice_prompt.m4a';
      setState(() {
        _isPlaying = true;
        _waveController.repeat(reverse: true);
      });

      await _voiceService.playAudio(audioTarget);

      // Auto-stop preview fallback after 15 seconds if demo playback
      Timer(const Duration(seconds: 15), () {
        if (mounted && _isPlaying) {
          setState(() {
            _isPlaying = false;
            _waveController.stop();
          });
        }
      });
    }
  }

  Future<void> _startRecording() async {
    HapticFeedback.heavyImpact();
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF131924),
            content: Text(
              'Microphone permission is required to record voice vibe prompts.',
              style: TextStyle(color: Color(0xFFFF4D67), fontSize: 12),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _isPlaying = false;
      _hasRecording = false;
      _recordSeconds = 0;
      _waveController.repeat(reverse: true);
    });

    try {
      await _voiceService.startRecording();
    } catch (e) {
      debugPrint('[AuraVoiceVibeWidget] Start recording error: $e');
    }

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordSeconds >= 30) {
        _stopRecording();
      } else {
        setState(() => _recordSeconds++);
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    HapticFeedback.mediumImpact();

    String? path;
    try {
      path = await _voiceService.stopRecording();
    } catch (e) {
      debugPrint('[AuraVoiceVibeWidget] Stop recording error: $e');
    }

    final savedPath = (path != null && path.isNotEmpty)
        ? path
        : '/users/current/voice_prompt.m4a';

    setState(() {
      _isRecording = false;
      _hasRecording = true;
      _currentAudioPath = savedPath;
      _waveController.stop();
    });

    if (widget.onSaved != null) {
      widget.onSaved!(savedPath, _selectedPrompt);
    }
    if (widget.onRecordingCompleted != null) {
      widget.onRecordingCompleted!(_selectedPrompt, savedPath);
    }
  }

  Future<void> _deleteRecording() async {
    HapticFeedback.lightImpact();
    await _voiceService.stopAudio();
    setState(() {
      _hasRecording = false;
      _isPlaying = false;
      _currentAudioPath = null;
      _waveController.stop();
      _recordSeconds = 0;
    });
  }

  void _pickPrompt() {
    if (!widget.isEditable) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Voice Vibe Prompt',
              style: TextStyle(
                color: Color(0xFF181829),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ...availablePrompts.map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mic_none_rounded, color: Color(0xFFFF4D67), size: 20),
                  title: Text(
                    p,
                    style: TextStyle(
                      color: _selectedPrompt == p ? const Color(0xFFFF3366) : const Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: _selectedPrompt == p ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedPrompt = p);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isRecording
              ? const Color(0xFFFF4D67).withValues(alpha: 0.6)
              : const Color(0xFFFFE4E6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt Header Row
          GestureDetector(
            onTap: _pickPrompt,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF4D67).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 12, color: Color(0xFFFF4D67)),
                      SizedBox(width: 4),
                      Text(
                        'VOICE VIBE',
                        style: TextStyle(
                          color: Color(0xFFFF4D67),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPrompt,
                    style: const TextStyle(
                      color: Color(0xFF181829),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isEditable)
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Main Audio Pill Body with High Contrast Light Background
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE4E6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Play / Record Button
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else if (_hasRecording) {
                      _togglePlayback();
                    } else if (widget.isEditable) {
                      _startRecording();
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isRecording
                            ? [const Color(0xFFFF4D67), const Color(0xFFDC2626)]
                            : [const Color(0xFFFF4D67), const Color(0xFF8B5CF6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Animated Neon Waveform Bars
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: CustomPaint(
                      painter: _NeonWaveformPainter(
                        animationValue: _waveController.value,
                        isActive: _isPlaying || _isRecording,
                        isRecording: _isRecording,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Timer / Status
                Text(
                  _isRecording
                      ? '00:${_recordSeconds.toString().padLeft(2, '0')} / 00:30'
                      : (_hasRecording ? '00:28' : '30s max'),
                  style: TextStyle(
                    color: _isRecording ? const Color(0xFFFF4D67) : const Color(0xFF4B5563),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),

                if (_hasRecording && widget.isEditable && !_isRecording) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _deleteRecording,
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering 22 dancing neon gradient waveform bars.
class _NeonWaveformPainter extends CustomPainter {
  final double animationValue;
  final bool isActive;
  final bool isRecording;

  _NeonWaveformPainter({
    required this.animationValue,
    required this.isActive,
    required this.isRecording,
  });

  static const int barCount = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width - (barCount - 1) * 2.5) / barCount;
    final rng = Random(42);

    for (int i = 0; i < barCount; i++) {
      final baseHeightFactor = 0.25 + (rng.nextDouble() * 0.75);
      double barHeight;

      if (isActive) {
        final phase = (i / barCount) * pi * 2;
        final wave = sin(animationValue * pi * 2 + phase);
        barHeight = size.height * (0.3 + (0.65 * (wave.abs())));
      } else {
        barHeight = size.height * (0.2 + (0.5 * baseHeightFactor));
      }

      final x = i * (barWidth + 2.5);
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(3),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: isRecording
              ? [const Color(0xFFDC2626), const Color(0xFFFF4D67)]
              : [
                  const Color(0xFFFF4D67),
                  const Color(0xFF7928CA),
                  const Color(0xFF67E8F9),
                ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isActive != isActive ||
        oldDelegate.isRecording != isRecording;
  }
}
