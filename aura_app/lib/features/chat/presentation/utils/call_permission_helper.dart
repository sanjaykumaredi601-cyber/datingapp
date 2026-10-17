import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aura_app/core/constants/app_colors.dart';

/// Helper utility for handling audio and video call permissions gracefully
/// with clear UX explaining privacy and security considerations.
class CallPermissionHelper {
  /// Request necessary hardware permissions for calls.
  /// Audio calls require Microphone. Video calls require Microphone and Camera.
  static Future<bool> requestCallPermissions({
    required BuildContext context,
    required bool isVideo,
  }) async {
    if (kIsWeb) return true;

    // Check Microphone status
    PermissionStatus micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    if (micStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermissionDeniedDialog(
          context: context,
          permissionName: 'Microphone',
          isPermanent: true,
        );
      }
      return false;
    }

    if (!micStatus.isGranted) {
      if (context.mounted) {
        await _showPermissionDeniedDialog(
          context: context,
          permissionName: 'Microphone',
          isPermanent: false,
        );
      }
      return false;
    }

    // Check Camera status if Video Call
    if (isVideo) {
      PermissionStatus cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      if (cameraStatus.isPermanentlyDenied) {
        if (context.mounted) {
          await _showPermissionDeniedDialog(
            context: context,
            permissionName: 'Camera',
            isPermanent: true,
          );
        }
        return false;
      }

      if (!cameraStatus.isGranted) {
        if (context.mounted) {
          await _showPermissionDeniedDialog(
            context: context,
            permissionName: 'Camera',
            isPermanent: false,
          );
        }
        return false;
      }
    }

    return true;
  }

  static Future<void> _showPermissionDeniedDialog({
    required BuildContext context,
    required String permissionName,
    required bool isPermanent,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: const Color(0xFF131924).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFFFF4D67),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$permissionName Permission Needed',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isPermanent
                      ? '$permissionName access is blocked. Please enable it in system settings to enjoy private encrypted calling on Aura.'
                      : '$permissionName access is required to connect to encrypted voice/video calls. Please allow permission to proceed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isPermanent) {
                            openAppSettings();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D67),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(isPermanent ? 'Settings' : 'OK'),
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
}
