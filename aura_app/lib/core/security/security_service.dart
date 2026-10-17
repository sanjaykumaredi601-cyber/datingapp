import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.auraapp.aura_app/security');

  /// Toggles hardware-level FLAG_SECURE on Android (blocks screenshots and screen recording)
  static Future<void> setScreenSecurity(bool enabled) async {
    if (kIsWeb) return;
    try {
      if (enabled) {
        await _channel.invokeMethod('enableSecureMode');
      } else {
        await _channel.invokeMethod('disableSecureMode');
      }
    } catch (e) {
      debugPrint('SecurityService error: $e');
    }
  }
}
