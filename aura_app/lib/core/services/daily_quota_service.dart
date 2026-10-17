import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'play_billing_service.dart';
import '../../features/subscription/presentation/widgets/subscription_paywall_sheet.dart';

/// Service managing daily free tier limits (Echoes & Radar Waves)
/// Automatically prompts the premium subscription screen/paywall when quotas are reached
class DailyQuotaService {
  static final DailyQuotaService _instance = DailyQuotaService._internal();
  factory DailyQuotaService() => _instance;
  DailyQuotaService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final PlayBillingService _billingService = PlayBillingService();

  static const int freeDailyEchoLimit = 5;
  static const int freeDailyWaveLimit = 10;

  String get _todayKey => DateTime.now().toIso8601String().substring(0, 10);

  /// Check if user has unlimited access via active subscription tier
  bool get isPremium {
    return _billingService.currentTier == SubscriptionTier.explorer ||
        _billingService.currentTier == SubscriptionTier.vip;
  }

  /// Get today's echoes used count
  Future<int> getEchoesUsedToday() async {
    if (isPremium) return 0;
    final date = await _storage.read(key: 'quota_echo_date');
    if (date != _todayKey) {
      await _storage.write(key: 'quota_echo_date', value: _todayKey);
      await _storage.write(key: 'quota_echo_count', value: '0');
      return 0;
    }
    final countStr = await _storage.read(key: 'quota_echo_count') ?? '0';
    return int.tryParse(countStr) ?? 0;
  }

  /// Check if user can reveal another echo. If limit reached, automatically prompts paywall!
  Future<bool> checkAndConsumeEchoQuota(BuildContext context) async {
    if (isPremium) return true;

    final used = await getEchoesUsedToday();
    if (used >= freeDailyEchoLimit) {
      if (context.mounted) {
        // Automatically prompt the subscription paywall sheet
        await SubscriptionPaywallSheet.show(context);
      }
      return false;
    }

    // Increment quota
    await _storage.write(key: 'quota_echo_date', value: _todayKey);
    await _storage.write(key: 'quota_echo_count', value: (used + 1).toString());
    return true;
  }

  /// Get today's radar waves used count
  Future<int> getRadarWavesUsedToday() async {
    if (isPremium) return 0;
    final date = await _storage.read(key: 'quota_wave_date');
    if (date != _todayKey) {
      await _storage.write(key: 'quota_wave_date', value: _todayKey);
      await _storage.write(key: 'quota_wave_count', value: '0');
      return 0;
    }
    final countStr = await _storage.read(key: 'quota_wave_count') ?? '0';
    return int.tryParse(countStr) ?? 0;
  }

  /// Check if user can send another radar wave. If limit reached, automatically prompts paywall!
  Future<bool> checkAndConsumeWaveQuota(BuildContext context) async {
    if (isPremium) return true;

    final used = await getRadarWavesUsedToday();
    if (used >= freeDailyWaveLimit) {
      if (context.mounted) {
        // Automatically prompt the subscription paywall sheet
        await SubscriptionPaywallSheet.show(context);
      }
      return false;
    }

    // Increment quota
    await _storage.write(key: 'quota_wave_date', value: _todayKey);
    await _storage.write(key: 'quota_wave_count', value: (used + 1).toString());
    return true;
  }
}
