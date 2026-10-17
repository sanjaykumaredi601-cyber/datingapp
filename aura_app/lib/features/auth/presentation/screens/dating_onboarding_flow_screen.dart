import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/user_provisioning_service.dart';
import '../../../../core/services/firebase_media_storage_service.dart';
import '../../../../core/utils/image_compression_helper.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../widgets/camera_filter_lens_modal.dart';
import '../widgets/voice_video_intro_recorder.dart';
import 'package:aura_app/features/verification/presentation/screens/liveness_verification_screen.dart';

/// Legacy alias mapping OnboardingProfileScreen to the comprehensive DatingOnboardingFlowScreen
typedef OnboardingProfileScreen = DatingOnboardingFlowScreen;

/// Comprehensive 4-Step Dating App Onboarding & Profile Creation Flow
class DatingOnboardingFlowScreen extends StatefulWidget {
  final User? user;
  final String? fallbackDisplayName;
  final String? fallbackEmail;
  final String? fallbackPhone;

  const DatingOnboardingFlowScreen({
    super.key,
    this.user,
    this.fallbackDisplayName,
    this.fallbackEmail,
    this.fallbackPhone,
  });

  @override
  State<DatingOnboardingFlowScreen> createState() => _DatingOnboardingFlowScreenState();
}

class _DatingOnboardingFlowScreenState extends State<DatingOnboardingFlowScreen> {
  final PageController _pageController = PageController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final UserProvisioningService _provisioningService = UserProvisioningService();
  final FirebaseMediaStorageService _mediaStorageService = FirebaseMediaStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _stepErrorMessage;

  User? get _resolvedUser => widget.user ?? FirebaseAuth.instance.currentUser;

  // ── Step 1: Core Identity & Demographics ──
  late final TextEditingController _nameController;
  DateTime? _selectedBirthDate;
  int? _calculatedAge;
  String _selectedGender = 'Woman';
  String _selectedInterestedIn = 'Everyone';
  String _selectedRelationshipGoal = 'Long-term partner';

  final List<String> _genderOptions = const ['Woman', 'Man', 'Non-binary', 'More Options'];
  final List<String> _interestedInOptions = const ['Men', 'Women', 'Everyone'];
  final List<String> _relationshipGoals = const [
    'Long-term partner',
    'Casual dating',
    'Open to explore',
    'New friendships',
  ];

  // ── Step 2: Hobbies, Vibe Sparks & Matching Prompts ──
  final Set<String> _selectedHobbies = <String>{'Travel', 'Music', 'Coffee'};
  final List<String> _availableHobbies = const [
    'Fitness', 'Music', 'Travel', 'Tech', 'Gaming', 'Foodie', 'Art',
    'Coffee', 'Hiking', 'Reading', 'Yoga', 'Photography', 'Nightlife',
    'Cooking', 'Anime', 'Fashion', 'Nature', 'Dogs', 'Cats', 'Wine',
  ];

  // Modernized "This or That" Interactive Quick-Choice Cards
  final List<Map<String, dynamic>> _thisOrThatChoices = const [
    {
      'key': 'rhythm',
      'title': 'DAILY RHYTHM',
      'optionA': 'Early Bird 🌅',
      'optionB': 'Night Owl 🌙',
    },
    {
      'key': 'travel',
      'title': 'TRAVEL STYLE',
      'optionA': 'Spontaneous Trips 🎒',
      'optionB': 'Planned Itinerary 📋',
    },
    {
      'key': 'date',
      'title': 'FIRST DATE VIBE',
      'optionA': 'Cozy Coffee Date ☕',
      'optionB': 'Cocktails & Sunset 🍸',
    },
    {
      'key': 'roadtrip',
      'title': 'WEEKEND GETAWAY',
      'optionA': 'Spontaneous Road Trip 🚗',
      'optionB': 'Planned Getaway ✈️',
    },
    {
      'key': 'rendezvous',
      'title': 'LATE NIGHT VIBE',
      'optionA': 'Coffee Date vs. Night Walk 🌙',
      'optionB': 'Dancing till Dawn 🪩',
    },
  ];

  final Map<String, String> _selectedThisOrThat = {
    'rhythm': 'Night Owl 🌙',
    'travel': 'Spontaneous Trips 🎒',
    'date': 'Cozy Coffee Date ☕',
    'roadtrip': 'Spontaneous Road Trip 🚗',
    'rendezvous': 'Coffee Date vs. Night Walk 🌙',
  };


  // Modernized "Dating Vibe" Interactive Chip Cloud
  final List<String> _availableDatingVibes = const [
    '#Foodie 🍕',
    '#GymGoer 💪',
    '#ArtLover 🎨',
    '#Gamer 🎮',
    '#CoffeeAddict ☕',
    '#MusicLover 🎧',
    '#Wanderlust ✈️',
    '#Bookworm 📚',
    '#NightOwl 🌙',
    '#NatureLover 🌿',
    '#TechGeek 💻',
    '#CreativeSoul ✨',
  ];

  final Set<String> _selectedDatingVibes = {'#Foodie 🍕', '#MusicLover 🎧', '#CoffeeAddict ☕'};

  String _promptQuestion1 = 'A fun fact about me...';
  final TextEditingController _promptAnswerController1 =
      TextEditingController(text: 'I can order espresso in 5 languages.');
  String _promptQuestion2 = 'My ideal weekend consists of...';
  final TextEditingController _promptAnswerController2 =
      TextEditingController(text: 'Exploring hidden cafes and catching live jazz.');

  final List<String> _availablePromptQuestions = const [
    'A fun fact about me...',
    'My ideal weekend consists of...',
    'The quickest way to my heart is...',
    'Together, we could...',
    'Two truths and a lie...',
    'My simple pleasures in life...',
    'I get overly excited about...',
    '🌶️ My most controversial opinion...',
    '✨ My non-negotiable Sunday ritual...',
    '🎶 The soundtrack to my life right now...',
  ];

  final Map<String, List<String>> _promptInspirations = const {
    'A fun fact about me...': [
      'I speak 3 languages fluently 🌍',
      'I once won a salsa dance-off 💃',
      'I can cook 5-star cacio e pepe 🍝',
    ],
    'My ideal weekend consists of...': [
      'Hidden cafe & live jazz evening 🎷',
      'Spontaneous road trip with great playlist 🚗',
      'Farmers market & bookstore treasure hunt 📚',
    ],
    'The quickest way to my heart is...': [
      'Surprise iced matcha latte 🍵',
      'Dark humor & sending memes at 2 AM 📱',
      'Cooking dinner together with vinyl records 🎶',
    ],
    'Together, we could...': [
      'Explore secret rooftop spots in the city 🌃',
      'Attempt challenging cooking recipes 🍳',
      'Book a last-minute weekend flight ✈️',
    ],
  };

  // ── Step 3: Profile Photos & Lens Filter Module ──
  // Stores local image paths or pre-filled URLs
  final List<String> _photoUrls = <String>[];

  // ── Step 4: Voice/Video Intro Recorder ──
  String? _introMediaUrl;

  @override
  void initState() {
    super.initState();
    final initialName = _resolvedUser?.displayName ?? widget.fallbackDisplayName ?? '';
    _nameController = TextEditingController(text: initialName);

    // Default birthdate (24 years old)
    final now = DateTime.now();
    _selectedBirthDate = DateTime(now.year - 24, now.month, now.day);
    _calculatedAge = 24;

    // Pre-fill initial photo from auth provider if available
    final authPhoto = _resolvedUser?.photoURL;
    if (authPhoto != null && authPhoto.isNotEmpty) {
      _photoUrls.add(authPhoto);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _promptAnswerController1.dispose();
    _promptAnswerController2.dispose();
    super.dispose();
  }

  void _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    setState(() {
      _selectedBirthDate = birthDate;
      _calculatedAge = age;
    });
  }

  Future<void> _pickBirthDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(now.year - 22, 1, 1);
    final firstDate = DateTime(now.year - 80, 1, 1);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.sunsetCoral,
              onPrimary: Colors.white,
              surface: Color(0xFF131A27),
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F141C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _calculateAge(picked);
    }
  }

  // ── Step Navigation & Validation ──
  bool _validateCurrentStep() {
    setState(() => _stepErrorMessage = null);

    if (_currentStep == 0) {
      if (_nameController.text.trim().length < 2) {
        setState(() => _stepErrorMessage = 'Please enter your full name (minimum 2 characters).');
        return false;
      }
      if (_calculatedAge == null || _calculatedAge! < 18) {
        setState(() => _stepErrorMessage = 'You must be at least 18 years old to join Aura.');
        return false;
      }
      return true;
    }

    if (_currentStep == 1) {
      if (_selectedHobbies.length < 3) {
        setState(() => _stepErrorMessage = 'Please select at least 3 hobbies to help matches find your vibe.');
        return false;
      }
      return true;
    }

    if (_currentStep == 2) {
      if (_photoUrls.length < 2) {
        setState(() => _stepErrorMessage = 'Please upload at least 2 profile photos (minimum required).');
        return false;
      }
      return true;
    }

    return true;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) {
      HapticFeedback.mediumImpact();
      return;
    }

    HapticFeedback.lightImpact();
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finalizeOnboarding();
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _stepErrorMessage = null;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  // ── Photo Actions ──
  Future<void> _pickPhotoFromGallery() async {
    if (_photoUrls.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos allowed.')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (file != null && mounted) {
        // Optimistic UI: display immediately in profile grid
        setState(() => _photoUrls.add(file.path));

        // Pre-compress locally to ensure <350 KB JPEG resolution
        try {
          final compressed = await ImageCompressionHelper.compressProfileImage(File(file.path));
          final idx = _photoUrls.indexOf(file.path);
          if (idx != -1 && mounted) {
            setState(() {
              _photoUrls[idx] = compressed.path;
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DatingOnboarding] Gallery picker note: $e');
    }
  }

  Future<void> _launchCameraFilterModal() async {
    if (_photoUrls.length >= 6) return;
    HapticFeedback.lightImpact();
    final capturedUrl = await CameraFilterCaptureScreen.show(context);
    if (capturedUrl != null && mounted) {
      setState(() => _photoUrls.add(capturedUrl));
      if (!capturedUrl.startsWith('http')) {
        try {
          final compressed = await ImageCompressionHelper.compressProfileImage(File(capturedUrl));
          final idx = _photoUrls.indexOf(capturedUrl);
          if (idx != -1 && mounted) {
            setState(() {
              _photoUrls[idx] = compressed.path;
            });
          }
        } catch (_) {}
      }
    }
  }

  void _removePhoto(int index) {
    HapticFeedback.lightImpact();
    setState(() => _photoUrls.removeAt(index));
  }

  // ── Database Finalization ──
  Future<void> _finalizeOnboarding() async {
    setState(() {
      _isSubmitting = true;
      _stepErrorMessage = null;
    });
    HapticFeedback.heavyImpact();

    final user = _resolvedUser;
    final customName = _nameController.text.trim();

    try {
      List<String> uploadedPhotoUrls = [];
      String? uploadedIntroUrl;

      // 1. Parallel uploads to Firebase Storage with individual timeouts & pre-compression
      if (user != null) {
        final uploadFutures = _photoUrls.asMap().entries.map((entry) async {
          final i = entry.key;
          final photo = entry.value;
          if (photo.startsWith('http://') || photo.startsWith('https://')) {
            return photo;
          } else {
            return await _mediaStorageService.uploadUserPhoto(
              uid: user.uid,
              localPath: photo,
              filename: 'photo_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
          }
        });

        uploadedPhotoUrls = await Future.wait(uploadFutures);

        // 2. Audio Intro: Store local path and proceed IMMEDIATELY to avoid freezing!
        // Audio upload runs asynchronously in background to Firebase Storage.
        if (_introMediaUrl != null && _introMediaUrl!.isNotEmpty) {
          uploadedIntroUrl = _introMediaUrl;
          final localAudio = _introMediaUrl!;
          final uid = user.uid;
          final isVid = localAudio.endsWith('.mp4');

          if (!localAudio.startsWith('http')) {
            unawaited(Future(() async {
              try {
                final cloudUrl = await _mediaStorageService.uploadUserIntroMedia(
                  uid: uid,
                  localPath: localAudio,
                  isVideo: isVid,
                );
                if (cloudUrl.startsWith('http')) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .set({'introMediaUrl': cloudUrl}, SetOptions(merge: true));
                  debugPrint('[DatingOnboarding] ✅ Background audio intro uploaded: $cloudUrl');
                }
              } catch (e) {
                debugPrint('[DatingOnboarding] Background audio upload note: $e');
              }
            }));
          }
        }
      } else {
        uploadedPhotoUrls = List.from(_photoUrls);
        uploadedIntroUrl = _introMediaUrl;
      }


      final promptsMap = {
        'datingVibes': _selectedDatingVibes.toList(),
        'thisOrThat': _selectedThisOrThat,
        if (_promptAnswerController1.text.trim().isNotEmpty)
          _promptQuestion1: _promptAnswerController1.text.trim(),
        if (_promptAnswerController2.text.trim().isNotEmpty)
          _promptQuestion2: _promptAnswerController2.text.trim(),
      };

      // 3. Compile all fields and write to Firestore users/${user.uid} with 15s timeout
      if (user != null) {
        final success = await _provisioningService.completeOnboarding(
          user: user,
          customDisplayName: customName,
          age: _calculatedAge ?? 24,
          birthDate: _selectedBirthDate,
          gender: _selectedGender,
          interestedIn: _selectedInterestedIn,
          relationshipGoal: _selectedRelationshipGoal,
          hobbies: _selectedHobbies.toList(),
          prompts: promptsMap,
          photoUrls: uploadedPhotoUrls,
          introMediaUrl: uploadedIntroUrl,
          location: const GeoPoint(43.6532, -79.3832), // Toronto hub default
        ).timeout(const Duration(seconds: 15), onTimeout: () => true);

        if (!success) {
          throw Exception('Failed to write user profile to Firestore.');
        }
      }

      // Cache profile completion locally
      try {
        await _storage.write(key: 'is_profile_complete', value: 'true');
        await _storage.write(key: 'user_display_name', value: customName);
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Welcome to Aura, $customName! Your profile is active.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Mandatory Step 5: 3D Face Liveness Verification
      // Enforces biometric proof of humanness before granting access to Radar
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LivenessVerificationScreen(
            isMandatoryOnboarding: true,
            userId: user?.uid ?? 'usr_current_user',
            primaryPhotoUrl: uploadedPhotoUrls.isNotEmpty ? uploadedPhotoUrls.first : null,
          ),
          transitionDuration: const Duration(milliseconds: 650),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      debugPrint('[DatingOnboarding] Finalization error: $e');
      if (mounted) {
        setState(() {
          _stepErrorMessage = 'Notice: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: _previousStep,
        ),
        title: _buildStepProgressBar(),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient aurora glow background
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.sunsetCoral.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.electricIris.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Error banner if any
                if (_stepErrorMessage != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _stepErrorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Multi-step PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1Demographics(),
                      _buildStep2HobbiesAndPrompts(),
                      _buildStep3PhotosAndFilters(),
                      _buildStep4VoiceIntro(),
                    ],
                  ),
                ),

                // Bottom Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: AuroraButton(
                    label: _currentStep == 3 ? 'Complete & Enter Radar' : 'Continue',
                    isLoading: _isSubmitting,
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressBar() {
    const totalSteps = 4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final isActive = i <= _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _currentStep ? 24 : 12,
          height: 4.5,
          decoration: BoxDecoration(
            color: isActive ? AppColors.sunsetCoral : Colors.white24,
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.sunsetCoral.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: CORE IDENTITY & DEMOGRAPHICS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1Demographics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1 of 4 · Identity',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.sunsetCoral,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Who are you?',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your identity sets how you will appear to nearby profiles on the radar.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 1. Full Name
          _buildFieldHeader('FULL NAME'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration('Your name or nickname', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 20),

          // 2. Date of Birth & Age Calculation
          _buildFieldHeader('DATE OF BIRTH (18+)'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickBirthDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceL1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2838), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: AppColors.sunsetCoral, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedBirthDate != null
                          ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                          : 'Select your birthday',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_calculatedAge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sunsetCoral.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sunsetCoral.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '$_calculatedAge yrs',
                        style: const TextStyle(color: AppColors.sunsetCoral, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Gender Identity
          _buildFieldHeader('I IDENTIFY AS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderOptions.map((g) {
              final isSelected = _selectedGender == g;
              return ChoiceChip(
                label: Text(g),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedGender = g),
                selectedColor: AppColors.sunsetCoral,
                backgroundColor: AppColors.surfaceL1,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.sunsetCoral : const Color(0xFF1E2838),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 4. Interested In
          _buildFieldHeader('INTERESTED IN'),
          const SizedBox(height: 8),
          Row(
            children: _interestedInOptions.map((option) {
              final isSelected = _selectedInterestedIn == option;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedInterestedIn = option);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.auroraTeal.withValues(alpha: 0.22)
                            : AppColors.surfaceL1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.auroraTeal : const Color(0xFF1E2838),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? AppColors.auroraTeal : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 5. Relationship Goals
          _buildFieldHeader('RELATIONSHIP GOAL'),
          const SizedBox(height: 8),
          Column(
            children: _relationshipGoals.map((goal) {
              final isSelected = _selectedRelationshipGoal == goal;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRelationshipGoal = goal);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.electricIris.withValues(alpha: 0.2)
                        : AppColors.surfaceL1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.electricIris : const Color(0xFF1E2838),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.electricIris : AppColors.textTertiary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        goal,
                        style: TextStyle(
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: HOBBIES & MATCHING PROMPTS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2HobbiesAndPrompts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2 of 4 · Vibe & Prompts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.auroraTeal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Passions & Prompts',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select 3 to 7 passions (${_selectedHobbies.length}/7 selected)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Multi-Select Hobbies
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableHobbies.map((hobby) {
              final isSelected = _selectedHobbies.contains(hobby);
              return FilterChip(
                label: Text(hobby),
                selected: isSelected,
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (selected) {
                      if (_selectedHobbies.length < 7) {
                        _selectedHobbies.add(hobby);
                      }
                    } else {
                      _selectedHobbies.remove(hobby);
                    }
                  });
                },
                selectedColor: AppColors.sunsetCoral,
                backgroundColor: AppColors.surfaceL1,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.sunsetCoral : const Color(0xFF1E2838),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // ── 1. Interactive "This or That" Quick-Choice Cards ──
          _buildFieldHeader('VIBE COMPATIBILITY QUIZ (THIS OR THAT)'),
          const SizedBox(height: 6),
          const Text(
            'Pick your vibe instincts to fuel real-time resonance matching',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Column(
            children: _thisOrThatChoices.map((quiz) {
              final key = quiz['key'] as String;
              final title = quiz['title'] as String;
              final optA = quiz['optionA'] as String;
              final optB = quiz['optionB'] as String;
              final currentVal = _selectedThisOrThat[key] ?? optA;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL1,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF1E2838),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
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
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.sunsetCoral,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Option A Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedThisOrThat[key] = optA);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: currentVal == optA
                                    ? AppColors.auroraTeal.withValues(alpha: 0.16)
                                    : AppColors.surfaceL2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: currentVal == optA ? AppColors.auroraTeal : const Color(0xFF1E2838),
                                  width: currentVal == optA ? 1.8 : 1.0,
                                ),
                                boxShadow: currentVal == optA
                                    ? [
                                        BoxShadow(
                                          color: AppColors.auroraTeal.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                optA,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: currentVal == optA ? Colors.white : AppColors.textSecondary,
                                  fontWeight: currentVal == optA ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Option B Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedThisOrThat[key] = optB);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: currentVal == optB
                                    ? AppColors.sunsetCoral.withValues(alpha: 0.16)
                                    : AppColors.surfaceL2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: currentVal == optB ? AppColors.sunsetCoral : const Color(0xFF1E2838),
                                  width: currentVal == optB ? 1.8 : 1.0,
                                ),
                                boxShadow: currentVal == optB
                                    ? [
                                        BoxShadow(
                                          color: AppColors.sunsetCoral.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                optB,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: currentVal == optB ? Colors.white : AppColors.textSecondary,
                                  fontWeight: currentVal == optB ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 2. Interactive "Dating Vibe" Multi-Select Chip Cloud ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldHeader('DATING VIBE · CHIP CLOUD'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.electricIris.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.electricIris.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_selectedDatingVibes.length} selected',
                  style: const TextStyle(
                    color: AppColors.electricIris,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select all tags that describe your romantic lifestyle and dating presence',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableDatingVibes.map((vibe) {
              final isSelected = _selectedDatingVibes.contains(vibe);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selectedDatingVibes.remove(vibe);
                    } else {
                      _selectedDatingVibes.add(vibe);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.electricIris.withValues(alpha: 0.22)
                        : AppColors.surfaceL1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.electricIris : const Color(0xFF1E2838),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.electricIris.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, color: AppColors.electricIris, size: 14),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        vibe,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 3. Creative Icebreaker Prompts ──
          _buildFieldHeader('PROFILE PROMPT (OPTIONAL)'),
          const SizedBox(height: 8),
          _buildPromptCard(
            question: _promptQuestion1,
            controller: _promptAnswerController1,
            onSelectNewQuestion: (q) => setState(() => _promptQuestion1 = q),
          ),
          const SizedBox(height: 16),

          _buildFieldHeader('ADDITIONAL PROMPT (OPTIONAL)'),
          const SizedBox(height: 8),
          _buildPromptCard(
            question: _promptQuestion2,
            controller: _promptAnswerController2,
            onSelectNewQuestion: (q) => setState(() => _promptQuestion2 = q),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard({
    required String question,
    required TextEditingController controller,
    required ValueChanged<String> onSelectNewQuestion,
  }) {
    final inspirations = _promptInspirations[question] ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceL1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2838), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: AppColors.sunsetCoral, size: 20),
                    tooltip: 'Shuffle question',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final currIdx = _availablePromptQuestions.indexOf(question);
                      final nextIdx = (currIdx + 1) % _availablePromptQuestions.length;
                      onSelectNewQuestion(_availablePromptQuestions[nextIdx]);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.auroraTeal, size: 20),
                    onPressed: () => _showPromptSelector(onSelectNewQuestion),
                    tooltip: 'Choose question from list',
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E2838), height: 16),
          TextFormField(
            controller: controller,
            maxLines: 2,
            maxLength: 120,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Type your answer or tap inspiration below...',
              hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.6)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
            ),
          ),
          if (inspirations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 13, color: AppColors.softGold),
                const SizedBox(width: 4),
                const Text(
                  'Quick Inspiration (tap to fill):',
                  style: TextStyle(color: AppColors.softGold, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: inspirations.map((spark) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      controller.text = spark;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceL2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33FF4D67)),
                    ),
                    child: Text(
                      spark,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showPromptSelector(ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: _availablePromptQuestions.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E2838), height: 1),
            itemBuilder: (context, i) {
              final q = _availablePromptQuestions[i];
              return ListTile(
                title: Text(q, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                onTap: () {
                  onSelected(q);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: PROFILE PHOTOS & CAMERA FILTER MODULE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3PhotosAndFilters() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3 of 4 · Photos & Lenses',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.sunsetCoral,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add Your Photos',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload between 2 and 6 photos. The first slot is your primary radar beacon avatar.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Dual Upload Options Button Bar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhotoFromGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 17, color: AppColors.auroraTeal),
                  label: const Text('Gallery Upload', style: TextStyle(color: AppColors.auroraTeal, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.auroraTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _launchCameraFilterModal,
                  icon: const Icon(Icons.camera_enhance_rounded, size: 17, color: AppColors.sunsetCoral),
                  label: const Text('AR Filter Lens', style: TextStyle(color: AppColors.sunsetCoral, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.sunsetCoral),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6-Grid Photo Slots
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final hasPhoto = index < _photoUrls.length;
              final isPrimary = index == 0;

              if (hasPhoto) {
                final photo = _photoUrls[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: photo.startsWith('http://') || photo.startsWith('https://')
                          ? Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surfaceL2,
                                child: const Icon(Icons.person_outline_rounded, color: Colors.white38),
                              ),
                            )
                          : (File(photo).existsSync()
                              ? Image.file(
                                  File(photo),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.surfaceL2,
                                    child: const Icon(Icons.image_outlined, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  color: AppColors.surfaceL2,
                                  child: const Icon(Icons.image_rounded, color: Colors.white38),
                                )),
                    ),
                    if (isPrimary)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sunsetCoral,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRIMARY',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return GestureDetector(
                  onTap: _pickPhotoFromGallery,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceL1,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E2838), width: 1.2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPrimary ? Icons.star_border_rounded : Icons.add_rounded,
                            color: isPrimary ? AppColors.sunsetCoral : AppColors.textTertiary,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPrimary ? 'Avatar' : 'Slot ${index + 1}',
                            style: TextStyle(
                              color: isPrimary ? AppColors.sunsetCoral : AppColors.textTertiary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4: VOICE/VIDEO INTRO RECORDER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4VoiceIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 4 of 4 · Media Intro',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.electricIris,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record Your Intro',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share a 15–30s voice greeting or video snippet. Let nearby matches hear your natural tone and presence.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          VoiceVideoIntroRecorder(
            initialMediaUrl: _introMediaUrl,
            onMediaChanged: (media) => setState(() => _introMediaUrl = media),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceL1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2838), width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.auroraTeal, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Optional media: You can skip recording now and add a voice note anytime from your profile.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.sunsetCoral.withValues(alpha: 0.9),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textTertiary.withValues(alpha: 0.6),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.sunsetCoral, size: 20),
      filled: true,
      fillColor: AppColors.surfaceL1,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E2838), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E2838), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sunsetCoral, width: 1.8),
      ),
    );
  }
}
