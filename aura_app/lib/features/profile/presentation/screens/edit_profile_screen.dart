import '../widgets/aura_voice_vibe_widget.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aura_app/core/constants/app_colors.dart';
import 'package:aura_app/core/services/firestore_service.dart';
import 'package:aura_app/core/security/security_service.dart';
import 'package:aura_app/core/services/firebase_media_storage_service.dart';
import 'package:aura_app/shared/widgets/aura_image.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _storage = const FlutterSecureStorage();
  final _firestoreService = FirestoreService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _occupationController;
  late TextEditingController _cityController;

  DateTime? _birthDate;
  String _gender = 'Man';
  String _interestedIn = 'Women';
  String _intention = 'Long-term partner';

  // Photos (minimum 2, maximum 6)
  List<String> _photos = [];

  // Passions
  final Set<String> _selectedPassions = {};

  // Data persistence for treat preferences (UI held for Beta track)
  final Set<String> _selectedTreats = {};

  final List<String> _availablePassions = [
    '🎵 Music',
    '☕ Coffee',
    '🏋️ Fitness',
    '✈️ Travel',
    '📚 Reading',
    '🎨 Art & Design',
    '🐕 Dogs',
    '🐈 Cats',
    '🍳 Cooking',
    '🎮 Gaming',
    '🎧 Vinyl Records',
    '🌿 Nature & Hiking',
    '🍿 Indie Cinema',
    '💻 Tech & Coding',
    '🧘 Yoga & Zen',
    '📸 Film Photography',
  ];

  final List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    SecurityService.setScreenSecurity(true);
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _occupationController = TextEditingController();
    _cityController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    SecurityService.setScreenSecurity(false);
    _nameController.dispose();
    _bioController.dispose();
    _occupationController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final currentUid = user?.uid ?? await _storage.read(key: 'current_user_id') ?? 'user_me_001';

      final storedName = await _storage.read(key: 'user_display_name');
      final storedBio = await _storage.read(key: 'user_bio');
      final storedBirthDate = await _storage.read(key: 'user_birthdate');
      final storedGender = await _storage.read(key: 'user_gender');
      final storedInterestedIn = await _storage.read(key: 'user_interested_in');
      final storedOccupation = await _storage.read(key: 'user_occupation');
      final storedCity = await _storage.read(key: 'user_city');
      final storedIntention = await _storage.read(key: 'user_intention');
      final storedPassions = await _storage.read(key: 'user_passions');
      final storedPhotos = await _storage.read(key: 'user_photos');

      if (storedName == null && storedBio == null) {
        final remoteProfile = await _firestoreService.getProfile(currentUid);
        if (remoteProfile != null) {
          _nameController.text = remoteProfile.displayName;
          _bioController.text = remoteProfile.bio;
          _occupationController.text = remoteProfile.occupation;
          _cityController.text = remoteProfile.city;
          _gender = remoteProfile.gender;
          _interestedIn = remoteProfile.interestedIn;
          _intention = remoteProfile.intention;
          _birthDate = remoteProfile.birthDate;
          _photos = List<String>.from(remoteProfile.photos);
          _selectedPassions.clear();
          _selectedPassions.addAll(remoteProfile.passions);
          _selectedTreats.clear();
          _selectedTreats.addAll(remoteProfile.favoriteTreats);

          // Cache locally to ensure rapid instant cold-starts
          await _storage.write(key: 'user_display_name', value: remoteProfile.displayName);
          await _storage.write(key: 'user_bio', value: remoteProfile.bio);
          await _storage.write(key: 'user_birthdate', value: remoteProfile.birthDate.toIso8601String());
          await _storage.write(key: 'user_gender', value: remoteProfile.gender);
          await _storage.write(key: 'user_interested_in', value: remoteProfile.interestedIn);
          await _storage.write(key: 'user_occupation', value: remoteProfile.occupation);
          await _storage.write(key: 'user_city', value: remoteProfile.city);
          await _storage.write(key: 'user_intention', value: remoteProfile.intention);
          await _storage.write(key: 'user_passions', value: jsonEncode(remoteProfile.passions));
          await _storage.write(key: 'user_favorite_treats', value: jsonEncode(remoteProfile.favoriteTreats));
          await _storage.write(key: 'user_photos', value: jsonEncode(remoteProfile.photos));
          if (remoteProfile.photos.isNotEmpty) {
            await _storage.write(key: 'user_avatar_url', value: remoteProfile.photos.first);
          }
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      _nameController.text = storedName ?? (user?.displayName ?? '');
      _bioController.text = storedBio ?? '';
      _occupationController.text = storedOccupation ?? '';
      _cityController.text = storedCity ?? '';
      _gender = storedGender ?? 'Man';
      _interestedIn = storedInterestedIn ?? 'Women';
      _intention = storedIntention ?? 'Long-term partner';

      if (storedBirthDate != null) {
        _birthDate = DateTime.tryParse(storedBirthDate);
      }
      _birthDate ??= DateTime(2000, 1, 1);

      if (storedPassions != null) {
        try {
          final list = List<String>.from(jsonDecode(storedPassions));
          _selectedPassions.addAll(list);
        } catch (_) {}
      }

      final storedTreats = await _storage.read(key: 'user_favorite_treats');
      if (storedTreats != null) {
        try {
          final list = List<String>.from(jsonDecode(storedTreats));
          _selectedTreats.addAll(list);
        } catch (_) {}
      }

      if (storedPhotos != null) {
        try {
          final list = List<String>.from(jsonDecode(storedPhotos));
          _photos = list;
        } catch (_) {}
      }
      if (_photos.isEmpty && user?.photoURL != null && user!.photoURL!.isNotEmpty) {
        _photos = [user.photoURL!];
      }
    } catch (_) {
      final user = FirebaseAuth.instance.currentUser;
      _nameController.text = user?.displayName ?? '';
      _bioController.text = '';
      _birthDate = DateTime(2000, 1, 1);
      _photos = (user?.photoURL != null && user!.photoURL!.isNotEmpty) ? [user.photoURL!] : [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackbar('Please enter your display name', isError: true);
      return;
    }

    if (_birthDate == null || _calculateAge(_birthDate!) < 18) {
      _showSnackbar('You must be at least 18 years old', isError: true);
      return;
    }

    if (_photos.length < 2) {
      _showSnackbar('Please upload at least 2 photos', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final currentUid = user?.uid ?? await _storage.read(key: 'current_user_id') ?? 'user_me_001';

      // 0. Upload any local device photos to Firebase Storage
      final List<String> uploadedPhotos = [];
      for (int i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        if (photo.startsWith('http://') || photo.startsWith('https://')) {
          uploadedPhotos.add(photo);
        } else {
          try {
            final cloudUrl = await FirebaseMediaStorageService().uploadUserPhoto(
              uid: currentUid,
              localPath: photo,
              filename: 'photo_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            uploadedPhotos.add(cloudUrl);
          } catch (e) {
            debugPrint('[EditProfile] Photo upload error: $e');
            uploadedPhotos.add(photo);
          }
        }
      }
      _photos = uploadedPhotos;

      // 1. Save to FlutterSecureStorage
      await _storage.write(key: 'user_display_name', value: name);
      await _storage.write(key: 'user_bio', value: _bioController.text.trim());
      await _storage.write(key: 'user_birthdate', value: _birthDate!.toIso8601String());
      await _storage.write(key: 'user_gender', value: _gender);
      await _storage.write(key: 'user_interested_in', value: _interestedIn);
      await _storage.write(key: 'user_occupation', value: _occupationController.text.trim());
      await _storage.write(key: 'user_city', value: _cityController.text.trim());
      await _storage.write(key: 'user_intention', value: _intention);
      await _storage.write(key: 'user_passions', value: jsonEncode(_selectedPassions.toList()));
      await _storage.write(key: 'user_favorite_treats', value: jsonEncode(_selectedTreats.toList()));
      await _storage.write(key: 'user_photos', value: jsonEncode(_photos));
      if (_photos.isNotEmpty) {
        await _storage.write(key: 'user_avatar_url', value: _photos[0]);
      }

      // 2. Sync to FirestoreService
      await _firestoreService.saveProfile(
        FirestoreUserProfile(
          userId: currentUid,
          displayName: name,
          birthDate: _birthDate!,
          gender: _gender,
          interestedIn: _interestedIn,
          photos: _photos,
          passions: _selectedPassions.toList(),
          favoriteTreats: _selectedTreats.map((t) => t.replaceAll(RegExp(r'[^\w\s]'), '').trim()).toList(),
          intention: _intention,
          bio: _bioController.text.trim(),
          occupation: _occupationController.text.trim(),
          city: _cityController.text.trim(),
          isVerified: true,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.mintGreen, size: 20),
                SizedBox(width: 10),
                Text('Profile updated successfully! ✨', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppColors.surfaceL1,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackbar('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.surfaceL1,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (_photos.length >= 6) {
      _showSnackbar('Maximum 6 photos allowed');
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _photos.add(picked.path);
        });
        HapticFeedback.lightImpact();
        _showSnackbar('Photo captured! Tap Save to persist to cloud.');
      }
    } catch (e) {
      _showSnackbar('Camera error: $e', isError: true);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_photos.length >= 6) {
      _showSnackbar('Maximum 6 photos allowed');
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _photos.add(picked.path);
        });
        HapticFeedback.lightImpact();
        _showSnackbar('Photo selected! Tap Save to persist to cloud.');
      }
    } catch (e) {
      _showSnackbar('Gallery error: $e', isError: true);
    }
  }

  void _addPhotoOption() {
    if (_photos.length >= 6) {
      _showSnackbar('Maximum 6 photos allowed');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceL1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.sunsetCoral),
                  title: const Text('Take Photo with Camera', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture live portrait', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.electricIris),
                  title: const Text('Choose from Photo Gallery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Upload pictures from your device', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.warmAmber),
                  title: const Text('Pick Curated Aesthetic Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select from high-res lookbook', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCuratedPhotosPicker();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCuratedPhotosPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceL1,
        title: const Text('Select Photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: GridView.builder(
            itemCount: _sampleAvatars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, idx) {
              final url = _sampleAvatars[idx];
              final isUsed = _photos.contains(url);
              return GestureDetector(
                onTap: isUsed
                    ? null
                    : () {
                        setState(() => _photos.add(url));
                        Navigator.pop(ctx);
                      },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AuraImage(imageSource: url, fit: BoxFit.cover),
                      if (isUsed)
                        Container(
                          color: Colors.black54,
                          child: const Icon(Icons.check, color: AppColors.mintGreen),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handlePhotoTap(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceL1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.sunsetCoral),
                title: const Text('Replace with Camera', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1080,
                    maxHeight: 1080,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    setState(() => _photos[index] = picked.path);
                    HapticFeedback.lightImpact();
                    _showSnackbar('Photo updated! Tap Save to persist.');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.electricIris),
                title: const Text('Replace from Gallery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1080,
                    maxHeight: 1080,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    setState(() => _photos[index] = picked.path);
                    HapticFeedback.lightImpact();
                    _showSnackbar('Photo updated! Tap Save to persist.');
                  }
                },
              ),
              if (index != 0)
                ListTile(
                  leading: const Icon(Icons.star_rounded, color: AppColors.warmAmber),
                  title: const Text('Make Main Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      final item = _photos.removeAt(index);
                      _photos.insert(0, item);
                    });
                    HapticFeedback.lightImpact();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Delete Photo', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_photos.length <= 2) {
                    _showSnackbar('Profile must have at least 2 photos', isError: true);
                    return;
                  }
                  setState(() => _photos.removeAt(index));
                  HapticFeedback.mediumImpact();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.sunsetCoral),
        ),
      );
    }

    final age = _birthDate != null ? _calculateAge(_birthDate!) : 26;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceL1,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back to Profile',
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunsetCoral,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio Voice Bio Prompt ("Aura Voice Vibe")
            const AuraVoiceVibeWidget(),
            const SizedBox(height: 20),
            // ── Section 1: Photos Grid ──────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PHOTOS & MEDIA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${_photos.length}/6 photos (min 2)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPhotosGrid(),
            const SizedBox(height: 28),

            // ── Section 2: Identity ─────────────────────
            const Text(
              'ABOUT YOU',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildInputField(
              label: 'Display Name',
              controller: _nameController,
              hint: 'Your name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),

            // Bio
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bio', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(
                      '${_bioController.text.length}/300',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceL1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 300,
                    onChanged: (_) => setState(() {}),
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: 'Share a glimpse into your vibe, hobbies, and favorite spots...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date of birth / Age (Strict 18+ Validation)
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ?? DateTime(now.year - 20, 1, 1),
                  firstDate: DateTime(now.year - 90, 1, 1),
                  lastDate: now,
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.sunsetCoral,
                        surface: AppColors.surfaceL1,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );

                if (picked != null) {
                  final calculated = _calculateAge(picked);
                  if (calculated < 18) {
                    _showSnackbar('You must be at least 18 years old', isError: true);
                    return;
                  }
                  setState(() => _birthDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: AppColors.sunsetCoral, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date of Birth', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '${_birthDate?.day ?? 14}/${_birthDate?.month ?? 5}/${_birthDate?.year ?? 1998} ($age years old)',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.mintGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('18+ Verified', style: TextStyle(color: AppColors.mintGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_rounded, color: AppColors.textTertiary, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Occupation & Location
            _buildInputField(
              label: 'Job Title / Occupation',
              controller: _occupationController,
              hint: 'e.g. Design Architect',
              icon: Icons.work_outline_rounded,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'City & Neighborhood',
              controller: _cityController,
              hint: 'e.g. New York, London, Tokyo, or Toronto',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 28),

            // ── Section 3: Relationship & Orientation ───
            const Text(
              'DATING PREFERENCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildSegmentPicker(
              label: 'My Gender',
              options: ['Man', 'Woman', 'Non-binary'],
              selected: _gender,
              onSelect: (val) => setState(() => _gender = val),
            ),
            const SizedBox(height: 16),
            _buildSegmentPicker(
              label: 'Interested In',
              options: ['Women', 'Men', 'Everyone'],
              selected: _interestedIn,
              onSelect: (val) => setState(() => _interestedIn = val),
            ),
            const SizedBox(height: 16),
            _buildSegmentPicker(
              label: 'Relationship Intentions',
              options: ['Long-term partner', 'Casual dating', 'New friends', 'Figuring it out'],
              selected: _intention,
              onSelect: (val) => setState(() => _intention = val),
            ),
            const SizedBox(height: 28),

            // ── Section 4: Passions & Lifestyle ─────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PASSIONS & LIFESTYLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${_selectedPassions.length}/8 selected',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availablePassions.map((passion) {
                final isSelected = _selectedPassions.contains(passion);
                return FilterChip(
                  label: Text(passion),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (_selectedPassions.length < 8) {
                          _selectedPassions.add(passion);
                        } else {
                          _showSnackbar('Select up to 8 passions');
                        }
                      } else {
                        _selectedPassions.remove(passion);
                      }
                    });
                    HapticFeedback.selectionClick();
                  },
                  backgroundColor: AppColors.surfaceL1,
                  selectedColor: AppColors.sunsetCoral.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: isSelected ? AppColors.sunsetCoral : AppColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.sunsetCoral : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Gifting Feature Hold: Favorite Little Treats hidden for Beta testing to focus on authentic compatibility.

            // ── Save CTA ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunsetCoral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Profile Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppColors.surfaceL1,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cancel & Go Back',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildPhotosGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final hasPhoto = index < _photos.length;

        if (hasPhoto) {
          final isMain = index == 0;
          return GestureDetector(
            onTap: () => _handlePhotoTap(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AuraImage(
                    imageSource: _photos[index],
                    fit: BoxFit.cover,
                  ),
                  if (isMain)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sunsetCoral,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        child: const Text(
                          'MAIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return InkWell(
            onTap: _addPhotoOption,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceL1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: AppColors.sunsetCoral, size: 28),
                  SizedBox(height: 6),
                  Text('Add', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceL1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.sunsetCoral, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentPicker({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSel = opt == selected;
            return ChoiceChip(
              label: Text(opt),
              selected: isSel,
              onSelected: (val) {
                if (val) {
                  onSelect(opt);
                  HapticFeedback.selectionClick();
                }
              },
              backgroundColor: AppColors.surfaceL1,
              selectedColor: AppColors.sunsetCoral,
              side: BorderSide(color: isSel ? AppColors.sunsetCoral : AppColors.cardBorder),
              labelStyle: TextStyle(
                color: isSel ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
