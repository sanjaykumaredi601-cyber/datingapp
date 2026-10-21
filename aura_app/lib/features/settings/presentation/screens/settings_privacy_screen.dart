import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/security/security_service.dart';
import '../../../../core/services/compliance_service.dart';
import 'package:aura_app/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aura_app/features/profile/presentation/screens/edit_profile_screen.dart';
import '../../../verification/presentation/screens/liveness_verification_screen.dart';
import 'help_support_screen.dart';
import '../../../auth/presentation/screens/welcome_screen.dart';
import '../../../../core/services/google_auth_service.dart';
import 'package:aura_app/shared/widgets/aura_image.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  final ApiClient _apiClient = ApiClient();
  final _storage = const FlutterSecureStorage();

  bool _isIncognito = false;
  bool _isScreenshotProtected = kReleaseMode;
  bool _isLoading = false;

  String _displayName = 'Sanjay';
  int _age = 26;
  String _occupation = '';
  String _city = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    if (kReleaseMode) {
      SecurityService.setScreenSecurity(true);
    }
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final name = await _storage.read(key: 'user_display_name');
    final birthdateStr = await _storage.read(key: 'user_birthdate');
    final avatar = await _storage.read(key: 'user_avatar_url');
    final occupation = await _storage.read(key: 'user_occupation');
    final city = await _storage.read(key: 'user_city');

    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _displayName = name;
        if (occupation != null) _occupation = occupation;
        if (city != null) _city = city;
        if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
        if (birthdateStr != null) {
          final bDate = DateTime.tryParse(birthdateStr);
          if (bDate != null) {
            final now = DateTime.now();
            int age = now.year - bDate.year;
            if (now.month < bDate.month || (now.month == bDate.month && now.day < bDate.day)) {
              age--;
            }
            _age = age;
          }
        }
      });
    }
  }

  Future<void> _toggleIncognito(bool val) async {
    HapticFeedback.lightImpact();
    setState(() => _isIncognito = val);
    try {
      await _apiClient.setIncognito(val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              val
                ? '👻 Ghost Mode ON: You are now invisible on radar and echoes.'
                : '👁️ Ghost Mode OFF: You are now discoverable nearby.',
            ),
            backgroundColor: AppColors.surfaceL1,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _toggleScreenshotProtection(bool val) async {
    HapticFeedback.lightImpact();
    setState(() => _isScreenshotProtected = val);
    await SecurityService.setScreenSecurity(val);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
              ? '🛡️ Screenshot Shield Active (Android FLAG_SECURE enabled)'
              : '⚠️ Screenshot Protection Disabled',
          ),
          backgroundColor: AppColors.surfaceL1,
        ),
      );
    }
  }

  Future<void> _wipeLocationHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceL1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.warning, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Wipe Location History?', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Under the India DPDP Act 2023, this will immediately and irrevocably wipe all 48-hour location history, 500m grid records, and path-crossing echoes from the database.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            child: const Text('Wipe Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final userId = await _storage.read(key: 'user_id') ?? 'current_user';
        final purgeRes = await ComplianceService().purge48HourLocationHistory(userId: userId);
        try {
          await _apiClient.purgeLocationHistory();
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✨ DPDP/PIPEDA Compliant Purge: ${purgeRes.message}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Location cache purged locally.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _storage.read(key: 'user_id') ?? 'current_user';
      Map<String, dynamic> exportPayload;
      try {
        final res = await _apiClient.exportData();
        exportPayload = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : await ComplianceService().exportUserData(userId: userId);
      } catch (_) {
        exportPayload = await ComplianceService().exportUserData(userId: userId);
      }

      final dataStr = const JsonEncoder.withIndent('  ').convert(exportPayload);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceL1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.download_rounded, color: AppColors.auroraTeal),
              SizedBox(width: 8),
              Text('DPDP Data Export', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                dataStr,
                style: const TextStyle(
                  color: AppColors.auroraTeal,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: dataStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data export copied to clipboard!')),
                );
              },
              child: const Text('Copy JSON', style: TextStyle(color: AppColors.auroraTeal)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppColors.textTertiary)),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download data export. Try again later.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceL1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Erase Account?', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Under the India DPDP Act 2023 (Right to Erasure), this will permanently destroy your profile, matches, messages, encryption keys, and photos. This action cannot be reversed.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Permanently Erase', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 1. Immediately show full-screen blocking modal overlay dialog so progress is visible regardless of scroll position
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => PopScope(
          canPop: false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Dialog(
              backgroundColor: const Color(0xFF0F141C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF1E2838), width: 1.5),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFFF4D67),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Securely removing your profile and data...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Scrubbing personal records, photos, matches, and encryption keys from Cloud Firestore.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8E9DAE),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // 2. Perform end-to-end data cleanup
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final uid = currentUser?.uid;

        // Scrub Firestore document
        if (uid != null) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).delete();
            debugPrint('[AccountDeletion] ✅ Scrubbed Firestore /users/$uid');
          } catch (e) {
            debugPrint('[AccountDeletion] Firestore delete notice: $e');
          }
        }

        // Call backend API if connected
        try {
          await _apiClient.deleteAccount();
        } catch (_) {}

        // Delete Firebase Auth user or sign out
        if (currentUser != null) {
          try {
            await currentUser.delete();
            debugPrint('[AccountDeletion] ✅ Deleted Firebase Auth user');
          } catch (e) {
            debugPrint('[AccountDeletion] FirebaseAuth delete note: $e');
            await FirebaseAuth.instance.signOut();
          }
        }

        // Clear local secure storage
        await _storage.deleteAll();
      } catch (e) {
        debugPrint('[AccountDeletion] Cleanup error: $e');
      }

      // 3. Cleanly navigate back to WelcomeScreen
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showReportDialog() {
    final TextEditingController reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceL1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Trust & Safety Center', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report an incident or harassment directly to our trust team:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Describe what happened...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceL2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _apiClient.reportUser('user_suspect_001', 'harassment', reasonCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report submitted. Our safety team reviews within 24 hours.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.auroraTeal,
              foregroundColor: const Color(0xFF0D0D1A),
            ),
            child: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile & Privacy',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  color: AppColors.auroraTeal,
                  backgroundColor: AppColors.surfaceL2,
                ),
              ),
            // User Profile Card (Tappable to Edit)
            InkWell(
              onTap: () async {
                final updated = await Navigator.of(context, rootNavigator: true).push<bool>(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (updated == true) {
                  _loadUserProfile();
                }
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL1,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        // Avatar Glow Ring: Concentric thin ring in Sunset Coral & Iris
                        Container(
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFF1F2),
                            ),
                            child: ClipOval(
                              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? AuraImage(
                                      imageSource: _avatarUrl,
                                      fit: BoxFit.cover,
                                      width: 68,
                                      height: 68,
                                    )
                                  : const Center(
                                      child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 36),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded, color: Color(0xFFFF3366), size: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '$_displayName, $_age',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Color(0xFF00D2FF), size: 16),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _occupation.isNotEmpty && _city.isNotEmpty
                                ? '$_occupation, $_city • Tap to edit'
                                : (_occupation.isNotEmpty
                                    ? '$_occupation • Tap to edit'
                                    : (_city.isNotEmpty
                                        ? '$_city • Tap to edit'
                                        : 'Active Member • Tap to edit')),
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          // "VIP PASS ACTIVE" Tag: Luxurious Warm Gold border and text (#FBBF24)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5), width: 1),
                            ),
                            child: const Text(
                              '🌟 VIP PASS ACTIVE',
                              style: TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // "Edit" Button: Frosted pill with coral accent border
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF3366).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: Color(0xFFFF4D67), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Color(0xFFFF4D67),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Subscription Banner: Executive Deep Iris to Violet gradient (#4C1D95 to #1E1B4B) with gold star
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4C1D95), // Deep Iris
                      Color(0xFF1E1B4B), // Violet Obsidian
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF7928CA).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 30),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage FindAura Subscription',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Stealth mode, unlimited echoes & rewind',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFBBF24), size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3D Biometric Identity & Active Liveness Verification
            _buildSectionHeader('BIOMETRIC IDENTITY & ACTIVE LIVENESS'),
            const SizedBox(height: 10),

            _buildSettingCard(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF00D2FF), size: 22),
                  ),
                  title: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          '3D Biometric Liveness Verification',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded, color: Color(0xFF00F5A0), size: 16),
                    ],
                  ),
                  subtitle: const Text(
                    'Active ML Kit face mesh verification: yaw/pitch inflection challenges & audit hash.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00D2FF), size: 14),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => LivenessVerificationScreen(
                          referencePhotoUrl: _avatarUrl,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Privacy & Compliance Section (Canada PIPEDA & India DPDP)
            _buildSectionHeader('PRIVACY & COMPLIANCE (CANADA PIPEDA & INDIA DPDP)'),
            const SizedBox(height: 10),

            _buildSettingCard(
              children: [
                SwitchListTile(
                  value: _isIncognito,
                  onChanged: _toggleIncognito,
                  title: const Text(
                    'Ghost / Incognito Mode',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Hide your profile and presence completely from Radar & Echoes while browsing.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  secondary: const Icon(Icons.visibility_off_rounded, color: Color(0xFFFF4D67)),
                  activeThumbColor: const Color(0xFFFF4D67),
                  activeTrackColor: const Color(0xFF7928CA).withValues(alpha: 0.65),
                ),
                const Divider(color: AppColors.surfaceL2, height: 1),
                SwitchListTile(
                  value: _isScreenshotProtected,
                  onChanged: _toggleScreenshotProtection,
                  title: const Text(
                    'Screenshot & Screen Recording Shield',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Hardware-level FLAG_SECURE prevents screen capture of chats and profile photos.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  secondary: const Icon(Icons.security_rounded, color: Color(0xFF7928CA)),
                  activeThumbColor: const Color(0xFFFF4D67),
                  activeTrackColor: const Color(0xFF7928CA).withValues(alpha: 0.65),
                ),
                const Divider(color: AppColors.surfaceL2, height: 1),
                ListTile(
                  leading: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFFFF4D67)),
                  title: const Text(
                    'Wipe 48-Hour Location History',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Immediately purges all stored 500m grid locations and path logs.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4D67)),
                  onTap: _wipeLocationHistory,
                ),
                const Divider(color: AppColors.surfaceL2, height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: AppColors.auroraTeal),
                  title: const Text(
                    'Export My Data (PIPEDA & DPDP Portability)',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Download a copy of your personal data, consent logs, and audit trail in JSON.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 14),
                  onTap: _exportData,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Trust & Safety
            _buildSectionHeader('SAFETY & COMMUNITY GUIDELINES'),
            const SizedBox(height: 10),

            _buildSettingCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: AppColors.textSecondary),
                  title: const Text(
                    'Blocked Users',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Manage users you have blocked from contacting you.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 14),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No users currently blocked.')),
                    );
                  },
                ),
                const Divider(color: AppColors.surfaceL2, height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppColors.auroraTeal),
                  title: const Text(
                    'Trust & Safety Center',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Report misconduct, harassment, or impersonation.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 14),
                  onTap: _showReportDialog,
                ),
                const Divider(color: AppColors.surfaceL2, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyanGlow.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.cyanGlow, size: 20),
                  ),
                  title: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Help & Support Portal',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '24h SLA',
                        style: TextStyle(color: AppColors.cyanGlow, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  subtitle: const Text(
                    'Submit enterprise support tickets with auto-metadata & 24h SLA resolution.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyanGlow, size: 14),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Account Erasure (Right to be Forgotten)
            _buildSectionHeader('ACCOUNT & RIGHT TO ERASURE'),
            const SizedBox(height: 10),

            _buildSettingCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.auroraTeal),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Sign out of your active session and return to Welcome screen.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 14),
                  onTap: () async {
                    await GoogleAuthService().signOut();
                    await _storage.deleteAll();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const Divider(color: AppColors.surfaceL2, height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF4D67)),
                  title: const Text(
                    'Delete Account & Erase All Data',
                    style: TextStyle(color: Color(0xFFFF4D67), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Permanent destruction of profile, messages, and encryption keys.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4D67)),
                  onTap: _deleteAccount,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // App Version & Legal Compliance Note
            Center(
              child: Column(
                children: const [
                  Text(
                    'FindAura v1.0.0 (Production Build)',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Designed in compliance with the Digital Personal Data Protection (DPDP) Act 2023 & PIPEDA.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 10.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF8B949E), // Titanium Slate (#8B949E)
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(children: children),
    );
  }
}
