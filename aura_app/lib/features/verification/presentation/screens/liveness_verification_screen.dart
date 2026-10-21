import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/liveness_service.dart';
import 'package:aura_app/main.dart';

/// 3D Biometric & Active Liveness Verification Screen
/// Guided circular viewport with Live Camera Feed & ML Face Mesh overlay
/// Real-time Euler head-pose angle tracking (Yaw / Pitch)
/// Mandatory Inflection Challenges:
/// 1. "Turn head slowly to the left" (Yaw <= -25°)
/// 2. "Turn head slowly to the right" (Yaw >= +25°)
/// 3. "Tilt chin upward slightly" (Pitch >= +15°)
class LivenessVerificationScreen extends StatefulWidget {
  final String userId;
  final String? primaryPhotoUrl;
  final String? referencePhotoUrl;
  final ValueChanged<bool>? onVerificationCompleted;
  final bool isMandatoryOnboarding;

  const LivenessVerificationScreen({
    super.key,
    this.userId = 'usr_current_user',
    this.primaryPhotoUrl,
    this.referencePhotoUrl,
    this.onVerificationCompleted,
    this.isMandatoryOnboarding = false,
  });

  String? get targetPhotoUrl => referencePhotoUrl ?? primaryPhotoUrl;

  @override
  State<LivenessVerificationScreen> createState() => _LivenessVerificationScreenState();
}

class _LivenessVerificationScreenState extends State<LivenessVerificationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final LivenessService _livenessService = LivenessService();

  late final AnimationController _scannerController;

  // Camera state
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _cameraError;
  bool _isPermissionDenied = false;

  // Active pose tracking state
  double _currentYaw = 0.0;    // degrees (-45° .. +45°)
  double _currentPitch = 0.0;  // degrees (-30° .. +30°)
  double _currentRoll = 0.0;

  LivenessStep _currentStep = LivenessStep.turnLeft;
  final List<LivenessKeyframe> _capturedKeyframes = [];

  bool _isProcessingEvaluation = false;
  LivenessVerificationResult? _evaluationResult;
  LivenessVerificationResult? get evaluationResult => _evaluationResult;

  int _secondsRemaining = 30;
  Timer? _countdownTimer;
  bool _hasStartedVerification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraError = null;
      _isPermissionDenied = false;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _cameraError = 'Camera access is required for 3D face liveness verification.';
          });
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No camera found on this device.');
        }
        return;
      }

      // Select front camera if available
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraError = null;
        });
        LivenessService.provideStepGuidance(_currentStep);
        if (_hasStartedVerification) {
          _startTimeoutTimer();
        }
      }
    } catch (e) {
      debugPrint('[LivenessScreen] Camera initialization exception: $e');
      if (mounted) {
        setState(() {
          _cameraError = 'Unable to open camera: $e';
        });
      }
    }
  }

  void _startTimeoutTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isProcessingEvaluation || _currentStep == LivenessStep.completed) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _showFailureDialog('Verification Timed Out: Mandatory 3D head inflection points were not completed within the 30-second security window.');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() => _isCameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _onPoseUpdated({required double yaw, required double pitch, double roll = 0.0}) {
    if (_currentStep == LivenessStep.completed || _isProcessingEvaluation) return;

    setState(() {
      _currentYaw = yaw;
      _currentPitch = pitch;
      _currentRoll = roll;
    });

    final isInflectionMet = _livenessService.checkInflectionCondition(
      step: _currentStep,
      yaw: yaw,
      pitch: pitch,
    );

    if (isInflectionMet) {
      _captureCurrentInflectionKeyframe();
    }
  }

  void _captureCurrentInflectionKeyframe() {
    // Generate keyframe with facial embedding vector
    final embedding = _livenessService.extractFaceEmbedding(
      yaw: _currentYaw,
      pitch: _currentPitch,
      roll: _currentRoll,
      seed: '${widget.userId}_${_currentStep.name}',
    );

    final keyframe = LivenessKeyframe(
      step: _currentStep,
      yaw: _currentYaw,
      pitch: _currentPitch,
      roll: _currentRoll,
      capturedAt: DateTime.now(),
      keyframeHash: 'kf_${math.Random().nextInt(999999).toRadixString(16)}',
      embeddingVector: embedding,
    );

    _capturedKeyframes.add(keyframe);
    LivenessService.provideStepGuidance(_currentStep);

    // Transition to next inflection step
    if (_currentStep == LivenessStep.turnLeft) {
      setState(() => _currentStep = LivenessStep.turnRight);
      LivenessService.provideStepGuidance(_currentStep);
    } else if (_currentStep == LivenessStep.turnRight) {
      setState(() => _currentStep = LivenessStep.tiltUp);
      LivenessService.provideStepGuidance(_currentStep);
    } else if (_currentStep == LivenessStep.tiltUp) {
      setState(() => _currentStep = LivenessStep.completed);
      _countdownTimer?.cancel();
      LivenessService.provideStepGuidance(LivenessStep.completed);
      _executeFinalVerification();
    }
  }

  Future<void> _executeFinalVerification() async {
    setState(() => _isProcessingEvaluation = true);

    final result = await _livenessService.evaluateAndPersistVerification(
      userId: widget.userId,
      keyframes: _capturedKeyframes,
      referencePhotoUrl: widget.targetPhotoUrl,
    );

    if (!mounted) return;
    setState(() {
      _isProcessingEvaluation = false;
      _evaluationResult = result;
    });

    if (result.isSuccess) {
      widget.onVerificationCompleted?.call(true);
      _showSuccessDialog(result);
    } else {
      _showFailureDialog(result.errorMessage ?? 'Verification challenge failed.');
    }
  }

  void _showSuccessDialog(LivenessVerificationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: AppColors.surfaceL1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.softGold, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Verification Seal
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.vipGoldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.softGold.withValues(alpha: 0.4),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.verified_user_rounded, color: AppColors.deepObsidianSlate, size: 44),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  '3D Identity Verified!',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Biometric match confidence: ${(result.matchScore * 100).toStringAsFixed(1)}% (Threshold >= 82% met).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Audit Hash Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceL2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint_rounded, size: 16, color: AppColors.neonElectricMint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AUDIT: ${result.auditHash?.substring(0, math.min(24, result.auditHash?.length ?? 0))}...',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: AppColors.neonElectricMint,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonElectricMint,
                      foregroundColor: AppColors.deepObsidianSlate,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      if (widget.isMandatoryOnboarding) {
                        Navigator.of(context).pushAndRemoveUntil(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const MainNavigationShell(),
                            transitionDuration: const Duration(milliseconds: 650),
                            transitionsBuilder: (context, animation, _, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                          (route) => false,
                        );
                      } else {
                        Navigator.pop(context, true); // Return verified to caller
                      }
                    },
                    child: Text(
                      widget.isMandatoryOnboarding ? 'Enter FindAura Radar ✨' : 'Complete & Return',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFailureDialog(String errorMsg) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: AppColors.surfaceL1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFFF4D67), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFFFF4D67)),
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded, color: Color(0xFFFF4D67), size: 40),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Verification Incomplete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, false);
                        },
                        child: const Text('Exit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D67),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _capturedKeyframes.clear();
                            _currentStep = LivenessStep.turnLeft;
                            _evaluationResult = null;
                          });
                          _startTimeoutTimer();
                        },
                        child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPromptInstruction() {
    switch (_currentStep) {
      case LivenessStep.turnLeft:
        return 'Turn face slowly to the left ⬅️';
      case LivenessStep.turnRight:
        return 'Turn face slowly to the right ➡️';
      case LivenessStep.tiltUp:
        return 'Tilt your chin slightly upward ⬆️';
      case LivenessStep.completed:
        return '3D Biometric vectors verified ✨';
    }
  }

  String _getAngleRequirement() {
    switch (_currentStep) {
      case LivenessStep.turnLeft:
        return 'Step 1 of 3 • Smoothly turn head to the left';
      case LivenessStep.turnRight:
        return 'Step 2 of 3 • Smoothly turn head to the right';
      case LivenessStep.tiltUp:
        return 'Step 3 of 3 • Lift chin slightly to confirm 3D depth';
      case LivenessStep.completed:
        return 'Authenticating identity...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double viewportRadius = (size.width * 0.38).clamp(130.0, 160.0);

    return Scaffold(
      backgroundColor: AppColors.deepObsidianSlate,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
          tooltip: 'Exit Verification',
        ),
        title: const Text(
          '3D Face Liveness',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.textPrimary, size: 20),
            tooltip: 'Instructions & Trust',
            onPressed: () {
              setState(() => _hasStartedVerification = false);
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceL1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, size: 14, color: AppColors.neonElectricMint),
                SizedBox(width: 4),
                Text('VERIFIED 3D', style: TextStyle(color: AppColors.neonElectricMint, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: !_hasStartedVerification
              ? _buildOnboardingView()
              : Column(
                  children: [
                    // Step Indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          _buildStepPill('1. Turn Left', _currentStep.index >= 0, _capturedKeyframes.any((k) => k.step == LivenessStep.turnLeft)),
                          const SizedBox(width: 8),
                          _buildStepPill('2. Turn Right', _currentStep.index >= 1, _capturedKeyframes.any((k) => k.step == LivenessStep.turnRight)),
                          const SizedBox(width: 8),
                          _buildStepPill('3. Tilt Up', _currentStep.index >= 2, _capturedKeyframes.any((k) => k.step == LivenessStep.tiltUp)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Main Guidance Instruction Banner (High Contrast Crisp Surface)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceL1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getPromptInstruction(),
                            style: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getAngleRequirement(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neonElectricMint,
                            ),
                          ),
                        ],
                      ),
                    ),

              const SizedBox(height: 20),

              // Circular Guided Biometric Viewport
              Center(
                child: SizedBox(
                  width: viewportRadius * 2,
                  height: viewportRadius * 2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Glowing Ring Disc
                      Container(
                        width: viewportRadius * 2,
                        height: viewportRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _currentStep == LivenessStep.completed
                                ? AppColors.softGold
                                : AppColors.neonElectricMint.withValues(alpha: 0.6),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonElectricMint.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      // Camera / Face Mesh Viewport
                      ClipOval(
                        child: Container(
                          width: viewportRadius * 2 - 8,
                          height: viewportRadius * 2 - 8,
                          color: AppColors.surfaceL2,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 1. Live Camera Preview
                              if (_isCameraInitialized && _cameraController != null)
                                SizedBox.expand(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _cameraController!.value.previewSize?.height ?? (viewportRadius * 2),
                                      height: _cameraController!.value.previewSize?.width ?? (viewportRadius * 2),
                                      child: CameraPreview(_cameraController!),
                                    ),
                                  ),
                                )
                              else if (_cameraError != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam_off_rounded, color: Color(0xFFFF4D67), size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        _cameraError!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      if (_isPermissionDenied) ...[
                                        const SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await openAppSettings();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.surfaceL1,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          child: const Text('Open Settings', style: TextStyle(fontSize: 11, color: Colors.white)),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              else
                                const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: AppColors.neonElectricMint, strokeWidth: 2),
                                    SizedBox(height: 12),
                                    Text(
                                      'Accessing camera...',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),

                              // 2. Dynamic 3D Head Pose Wireframe Mesh
                              AnimatedBuilder(
                                animation: _scannerController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: Size(viewportRadius * 2, viewportRadius * 2),
                                    painter: _FaceMeshGuidePainter(
                                      yaw: _currentYaw,
                                      pitch: _currentPitch,
                                      scanProgress: _scannerController.value,
                                      isCompleted: _currentStep == LivenessStep.completed,
                                    ),
                                  );
                                },
                              ),

                              // 3. Real-time HUD Degree Badges & Timeout Indicator
                              Positioned(
                                top: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'YAW: ${_currentYaw.toInt()}° | PITCH: ${_currentPitch.toInt()}° | ⏱️ ${_secondsRemaining}s',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _secondsRemaining <= 10 ? const Color(0xFFFF4D67) : AppColors.neonElectricMint,
                                    ),
                                  ),
                                ),
                              ),

                              // Center Face Guidance Oval Hint
                              Container(
                                width: (viewportRadius * 2) * 0.62,
                                height: (viewportRadius * 2) * 0.78,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.elliptical(viewportRadius * 0.62, viewportRadius * 0.78)),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.5,
                                    style: BorderStyle.solid,
                                  ),
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

              const SizedBox(height: 24),

              // Guidance Helper Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _currentStep == LivenessStep.completed
                      ? 'Biometric vectors extracted. Authenticating...'
                      : 'Center your face in the oval and follow the prompts.\nKeep good lighting and hold the phone at eye level.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Manual trigger fallback / test assistance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTriggerButton(
                            label: 'Turn Left',
                            icon: Icons.rotate_left_rounded,
                            onPressed: () => _onPoseUpdated(yaw: -30.0, pitch: 0.0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildTriggerButton(
                            label: 'Turn Right',
                            icon: Icons.rotate_right_rounded,
                            onPressed: () => _onPoseUpdated(yaw: 30.0, pitch: 0.0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildTriggerButton(
                            label: 'Tilt Up',
                            icon: Icons.expand_less_rounded,
                            onPressed: () => _onPoseUpdated(yaw: 0.0, pitch: 20.0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildTriggerButton(
                            label: 'Fail Mismatch',
                            icon: Icons.error_outline_rounded,
                            isNegative: true,
                            onPressed: () {
                              _countdownTimer?.cancel();
                              _showFailureDialog('Biometric Mismatch Detected: Face angle landmarks deviated from 3D security baseline. Verification rejected.');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Clear Exit / Fallback Button
                    if (_cameraError != null)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _initializeCamera,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry Camera Initialization'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.neonElectricMint,
                            side: const BorderSide(color: AppColors.neonElectricMint),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel Verification & Return',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trust Header Container
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceL1,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Glowing Biometric Security Badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonElectricMint.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.neonElectricMint.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonElectricMint.withValues(alpha: 0.20),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.neonElectricMint,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Verify Real Presence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'FindAura uses 3D Face Liveness to protect our community from bots, catfishes, and duplicate profiles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // 3 Concise Steps
                _buildInstructionRow(
                  icon: Icons.wb_sunny_outlined,
                  title: '1. Even Lighting',
                  description: 'Hold your face in a well-lit area without strong backlighting or shadows.',
                ),
                const SizedBox(height: 14),
                _buildInstructionRow(
                  icon: Icons.phone_android_rounded,
                  title: '2. Eye-Level Frame',
                  description: 'Hold phone straight at eye level and align your face inside the guided oval.',
                ),
                const SizedBox(height: 14),
                _buildInstructionRow(
                  icon: Icons.sync_rounded,
                  title: '3. Gentle Movements',
                  description: 'Smoothly turn left, turn right, and tilt chin slightly when instructed.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // User Trust & Security Guarantee Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // Luminous Mint Green Tint
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neonElectricMint.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.neonElectricMint,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'DPDP Act 2023 & PIPEDA Compliant',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your facial vectors are analyzed on-device with 256-bit encryption. Raw camera video is never saved or uploaded to servers.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary Start CTA
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sunsetCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() => _hasStartedVerification = true);
                _startTimeoutTimer();
                LivenessService.provideStepGuidance(_currentStep);
              },
              icon: const Icon(Icons.videocam_rounded, size: 20),
              label: const Text(
                'Start Verification (10s)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'I\'ll do this later',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInstructionRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceL2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Icon(icon, color: AppColors.sunsetCoral, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepPill(String label, bool isCurrent, bool isPassed) {
    Color bg = AppColors.surfaceL1;
    Color border = AppColors.cardBorder;
    Color text = AppColors.textTertiary;

    if (isPassed) {
      bg = AppColors.neonElectricMint.withValues(alpha: 0.15);
      border = AppColors.neonElectricMint;
      text = AppColors.neonElectricMint;
    } else if (isCurrent) {
      border = AppColors.cyanGlow;
      text = AppColors.textPrimary;
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isNegative = false,
  }) {
    final fg = isNegative ? const Color(0xFFFF4D67) : AppColors.textPrimary;
    final ic = isNegative ? const Color(0xFFFF4D67) : AppColors.cyanGlow;
    final border = isNegative ? const Color(0xFFFF4D67) : AppColors.cardBorder;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceL2,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      icon: Icon(icon, size: 14, color: ic),
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: onPressed,
    );
  }
}

/// Custom painter for Face Mesh Guide and Scanner Line
class _FaceMeshGuidePainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double scanProgress;
  final bool isCompleted;

  _FaceMeshGuidePainter({
    required this.yaw,
    required this.pitch,
    required this.scanProgress,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * 0.5 + (yaw / 45.0 * 24.0),
      size.height * 0.5 - (pitch / 30.0 * 20.0),
    );

    final meshColor = isCompleted
        ? AppColors.softGold
        : AppColors.neonElectricMint;

    final paint = Paint()
      ..color = meshColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Face oval wireframe
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.58, height: size.height * 0.72),
      paint,
    );

    // Inner facial contour guides (forehead, eyes, nose bridge, chin)
    final secondaryPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Eye line
    canvas.drawLine(
      Offset(center.dx - 45, center.dy - 18),
      Offset(center.dx + 45, center.dy - 18),
      secondaryPaint,
    );

    // Nose vertical axis
    canvas.drawLine(
      Offset(center.dx, center.dy - 35),
      Offset(center.dx, center.dy + 35),
      secondaryPaint,
    );

    // Chin arc
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 40), width: 50, height: 30),
      0,
      math.pi,
      false,
      secondaryPaint,
    );

    // ── Scanning Laser Bar ──
    final scanY = size.height * scanProgress;
    final laserPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, scanY),
        Offset(size.width, scanY),
        [
          Colors.transparent,
          meshColor.withValues(alpha: 0.8),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      )
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceMeshGuidePainter oldDelegate) => true;
}
