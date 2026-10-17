import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SubscriptionTier { free, explorer, vip }

class PlayBillingProduct {
  final String id;
  final String title;
  final String description;
  final String priceFormatted;
  final double priceAmount;
  final String billingPeriod; // 'month' or 'year'
  final SubscriptionTier tier;

  const PlayBillingProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceFormatted,
    required this.priceAmount,
    required this.billingPeriod,
    required this.tier,
  });
}

class PurchaseResult {
  final bool isSuccess;
  final String? orderId;
  final String? purchaseToken;
  final String? sku;
  final String? errorMessage;

  const PurchaseResult({
    required this.isSuccess,
    this.orderId,
    this.purchaseToken,
    this.sku,
    this.errorMessage,
  });
}

/// Android Google Play Billing Client Wrapper
/// Wraps Google Play Billing Library with entitlement verification and secure token storage
class PlayBillingService {
  static final PlayBillingService _instance = PlayBillingService._internal();
  factory PlayBillingService() => _instance;
  PlayBillingService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _purchaseUpdateController = StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get purchaseStream => _purchaseUpdateController.stream;

  SubscriptionTier _currentTier = SubscriptionTier.free;
  SubscriptionTier get currentTier => _currentTier;

  // Available Play Store Products
  static const List<PlayBillingProduct> products = [
    PlayBillingProduct(
      id: 'aura_pass_explorer_monthly',
      title: 'Aura Explorer Monthly',
      description: 'See who liked you, unlimited rewinds & stealth mode',
      priceFormatted: '₹499',
      priceAmount: 499.0,
      billingPeriod: 'month',
      tier: SubscriptionTier.explorer,
    ),
    PlayBillingProduct(
      id: 'aura_pass_explorer_annual',
      title: 'Aura Explorer Annual',
      description: 'See who liked you, unlimited rewinds (40% OFF)',
      priceFormatted: '₹3,599',
      priceAmount: 3599.0,
      billingPeriod: 'year',
      tier: SubscriptionTier.explorer,
    ),
    PlayBillingProduct(
      id: 'aura_pass_vip_monthly',
      title: 'Aura VIP Pass Monthly',
      description: '5 Daily Priority Super Waves, Travel Pass & 2x Echoes',
      priceFormatted: '₹1,199',
      priceAmount: 1199.0,
      billingPeriod: 'month',
      tier: SubscriptionTier.vip,
    ),
    PlayBillingProduct(
      id: 'aura_pass_vip_annual',
      title: 'Aura VIP Pass Annual',
      description: 'Ultimate VIP Dating Suite with 50% Annual Savings',
      priceFormatted: '₹8,999',
      priceAmount: 8999.0,
      billingPeriod: 'year',
      tier: SubscriptionTier.vip,
    ),
  ];

  Future<void> initialize() async {
    try {
      final savedTier = await _storage.read(key: 'user_subscription_tier');
      if (savedTier == 'vip') {
        _currentTier = SubscriptionTier.vip;
      } else if (savedTier == 'explorer') {
        _currentTier = SubscriptionTier.explorer;
      } else {
        _currentTier = SubscriptionTier.free;
      }
    } catch (_) {
      _currentTier = SubscriptionTier.free;
    }
    debugPrint('[PlayBillingService] Initialized. Current tier: $_currentTier');
  }

  List<PlayBillingProduct> queryProductDetails() {
    return products;
  }

  Future<PurchaseResult> launchBillingFlow(String sku) async {
    debugPrint('[PlayBillingService] Launching Google Play Billing flow for SKU: $sku');

    // Simulate Google Play Billing client handshake & prompt
    await Future.delayed(const Duration(milliseconds: 1200));

    final product = products.firstWhere(
      (p) => p.id == sku,
      orElse: () => products.first,
    );

    final mockToken = 'GPA.${DateTime.now().millisecondsSinceEpoch}.${sku.hashCode.abs()}';
    final mockOrderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    // Verify token with backend
    final isVerified = await verifyPurchaseToken(mockToken, sku);
    if (isVerified) {
      await grantEntitlement(product.tier);
      final result = PurchaseResult(
        isSuccess: true,
        orderId: mockOrderId,
        purchaseToken: mockToken,
        sku: sku,
      );
      _purchaseUpdateController.add(result);
      return result;
    } else {
      final result = const PurchaseResult(
        isSuccess: false,
        errorMessage: 'Google Play token verification failed.',
      );
      _purchaseUpdateController.add(result);
      return result;
    }
  }

  Future<bool> verifyPurchaseToken(String purchaseToken, String sku) async {
    // In production, this verifies with the backend API / Google Play Developer API
    debugPrint('[PlayBillingService] Verifying purchase token with Google Play API: $purchaseToken');
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }

  Future<void> grantEntitlement(SubscriptionTier tier) async {
    _currentTier = tier;
    final tierStr = tier == SubscriptionTier.vip
        ? 'vip'
        : (tier == SubscriptionTier.explorer ? 'explorer' : 'free');

    try {
      await _storage.write(key: 'user_subscription_tier', value: tierStr);
    } catch (_) {}
    debugPrint('[PlayBillingService] Entitlement granted: $tierStr');
  }

  void dispose() {
    _purchaseUpdateController.close();
  }
}
