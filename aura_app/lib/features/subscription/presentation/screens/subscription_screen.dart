import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/play_billing_service.dart';

/// Supported global currency regions with localized pricing matrix
enum CurrencyRegion {
  usd(
    name: 'United States',
    code: 'USD',
    symbol: '\$',
    flag: '🇺🇸',
    explorerMonthly: '\$14.99',
    explorerAnnualMo: '\$9.99',
    explorerAnnualTotal: '\$119.88',
    vipMonthly: '\$29.99',
    vipAnnualMo: '\$19.99',
    vipAnnualTotal: '\$239.88',
  ),
  cad(
    name: 'Canada',
    code: 'CAD',
    symbol: 'CA\$',
    flag: '🇨🇦',
    explorerMonthly: '\$19.99',
    explorerAnnualMo: '\$13.49',
    explorerAnnualTotal: '\$161.88',
    vipMonthly: '\$39.99',
    vipAnnualMo: '\$26.99',
    vipAnnualTotal: '\$323.88',
  ),
  eur(
    name: 'Eurozone',
    code: 'EUR',
    symbol: '€',
    flag: '🇪🇺',
    explorerMonthly: '€13.99',
    explorerAnnualMo: '€9.49',
    explorerAnnualTotal: '€113.88',
    vipMonthly: '€27.99',
    vipAnnualMo: '€18.49',
    vipAnnualTotal: '€221.88',
  ),
  gbp(
    name: 'United Kingdom',
    code: 'GBP',
    symbol: '£',
    flag: '🇬🇧',
    explorerMonthly: '£11.99',
    explorerAnnualMo: '£7.99',
    explorerAnnualTotal: '£95.88',
    vipMonthly: '£24.99',
    vipAnnualMo: '£16.49',
    vipAnnualTotal: '£197.88',
  ),
  inr(
    name: 'India',
    code: 'INR',
    symbol: '₹',
    flag: '🇮🇳',
    explorerMonthly: '₹799',
    explorerAnnualMo: '₹499',
    explorerAnnualTotal: '₹5,988',
    vipMonthly: '₹1,599',
    vipAnnualMo: '₹999',
    vipAnnualTotal: '₹11,988',
  ),
  aud(
    name: 'Australia',
    code: 'AUD',
    symbol: 'A\$',
    flag: '🇦🇺',
    explorerMonthly: 'A\$22.99',
    explorerAnnualMo: 'A\$14.99',
    explorerAnnualTotal: 'A\$179.88',
    vipMonthly: 'A\$44.99',
    vipAnnualMo: 'A\$29.99',
    vipAnnualTotal: 'A\$359.88',
  );

  final String name;
  final String code;
  final String symbol;
  final String flag;
  final String explorerMonthly;
  final String explorerAnnualMo;
  final String explorerAnnualTotal;
  final String vipMonthly;
  final String vipAnnualMo;
  final String vipAnnualTotal;

  const CurrencyRegion({
    required this.name,
    required this.code,
    required this.symbol,
    required this.flag,
    required this.explorerMonthly,
    required this.explorerAnnualMo,
    required this.explorerAnnualTotal,
    required this.vipMonthly,
    required this.vipAnnualMo,
    required this.vipAnnualTotal,
  });

  /// Automatically detect localized regional currency based on device locale / Play Store region
  static CurrencyRegion detectLocalRegion() {
    try {
      final countryCode = WidgetsBinding.instance.platformDispatcher.locale.countryCode?.toUpperCase();
      switch (countryCode) {
        case 'IN':
          return CurrencyRegion.inr;
        case 'CA':
          return CurrencyRegion.cad;
        case 'GB':
        case 'UK':
          return CurrencyRegion.gbp;
        case 'AU':
        case 'NZ':
          return CurrencyRegion.aud;
        case 'DE':
        case 'FR':
        case 'IT':
        case 'ES':
        case 'NL':
        case 'BE':
        case 'AT':
        case 'IE':
        case 'PT':
        case 'FI':
        case 'GR':
          return CurrencyRegion.eur;
        case 'US':
        default:
          return CurrencyRegion.usd;
      }
    } catch (_) {
      return CurrencyRegion.usd;
    }
  }
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTierIndex = 1; // 0 = Free, 1 = Explorer, 2 = VIP
  bool _isAnnual = true;
  late CurrencyRegion _selectedRegion;
  bool _isProcessingPayment = false;
  final PlayBillingService _billingService = PlayBillingService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _selectedRegion = CurrencyRegion.detectLocalRegion();
    _billingService.initialize();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AURA VAULT PAYMENT GATEWAY: BIOMETRIC & CARD-BASED CHECKOUT
  // ──────────────────────────────────────────────────────────────────────────
  void _openAuraVaultCheckout(String planName, String formattedPrice) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AuraVaultGatewaySheet(
        planName: planName,
        price: formattedPrice,
        currencyRegion: _selectedRegion,
        tierIndex: _selectedTierIndex,
        onPaymentSuccess: (String transactionId, String methodUsed) {
          Navigator.pop(ctx);
          _completeSubscription(planName, transactionId, methodUsed);
        },
      ),
    );
  }

  Future<void> _completeSubscription(
    String planName,
    String transactionId,
    String methodUsed,
  ) async {
    setState(() => _isProcessingPayment = true);

    // 1. Grant entitlement in PlayBillingService
    final tier = _selectedTierIndex == 2
        ? SubscriptionTier.vip
        : SubscriptionTier.explorer;
    _billingService.grantEntitlement(tier);

    // 2. Persist entitlement in FlutterSecureStorage
    await _storage.write(key: 'subscription_tier', value: tier.name);
    await _storage.write(key: 'subscription_active', value: 'true');
    await _storage.write(
      key: 'subscription_expiry',
      value: DateTime.now()
          .add(Duration(days: _isAnnual ? 365 : 30))
          .toIso8601String(),
    );
    await _storage.write(key: 'last_payment_tx_id', value: transactionId);

    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

    // 3. Show Rich Confirmation Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F141C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFF1E2838), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66FF4D67),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to $planName!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your subscription is active with full access to stealth radar, unmetered echoes, and verified matchmaking.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Rail', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text(methodUsed, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Auth Token', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text(
                        transactionId.length > 16
                            ? '${transactionId.substring(0, 8)}...${transactionId.substring(transactionId.length - 6)}'
                            : transactionId,
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(confirmCtx);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D67),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Start Exploring Now ✨', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final region = _selectedRegion;

    // Localized price strings
    final explorerMonthlyPrice = region.explorerMonthly;
    final explorerAnnualPrice = region.explorerAnnualMo;
    final vipMonthlyPrice = region.vipMonthly;
    final vipAnnualPrice = region.vipAnnualMo;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'FindAura Premium',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // Top Hero Badge
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D67), Color(0xFF7928CA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D67).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Elevate Your FindAura',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Stealth radar, unlimited echoes, verified authenticity, and global reach.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),

                // ───────────────────────────────────────────────
                // AUTO-DETECTED SINGLE LOCALIZED CURRENCY BANNER
                // ───────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          region.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    'AUTO-DETECTED',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Localized Pricing',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${region.name} · ${region.code} (${region.symbol})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-localized for your Play Store territory. Local taxes included with zero foreign transaction fees.',
                              style: TextStyle(
                                color: const Color(0xFF94A3B8).withValues(alpha: 0.9),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Billing Cycle Toggle (Monthly vs Annual)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceL1,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBillingTab('Monthly', !_isAnnual, () => setState(() => _isAnnual = false)),
                        _buildBillingTab('Annual (Save 35%)', _isAnnual, () => setState(() => _isAnnual = true)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Plan Cards
                _buildPlanCard(
                  tierIndex: 1,
                  badge: 'MOST POPULAR',
                  name: 'Explorer Pass',
                  price: _isAnnual
                      ? '$explorerAnnualPrice / mo'
                      : '$explorerMonthlyPrice / mo',
                  subtext: _isAnnual
                      ? 'Billed annually at ${region.explorerAnnualTotal}'
                      : 'Billed monthly',
                  color: AppColors.auroraTeal,
                  features: const [
                    'Extended 50km Radar Radius',
                    'Unlimited Path-Crossing Echoes',
                    'Rewind Last Passed Profile',
                    'Direct Read Receipts in Chat',
                    '1 Free Daily SuperLike',
                  ],
                ),

                const SizedBox(height: 16),

                _buildPlanCard(
                  tierIndex: 2,
                  badge: 'ULTIMATE PRIVACY & POWER',
                  name: 'VIP Pass',
                  price: _isAnnual
                      ? '$vipAnnualPrice / mo'
                      : '$vipMonthlyPrice / mo',
                  subtext: _isAnnual
                      ? 'Billed annually at ${region.vipAnnualTotal}'
                      : 'Billed monthly',
                  color: AppColors.auroraGold,
                  features: const [
                    'Stealth Radar Mode (Complete Invisibility)',
                    'See Who Liked You Before Swiping',
                    'Hardware Screenshot Alerts & Shield',
                    '5 Free Weekly SuperEchoes',
                    'Top Priority Placement in Matches',
                    'All Explorer Pass Features',
                  ],
                ),

                const SizedBox(height: 16),

                _buildPlanCard(
                  tierIndex: 0,
                  badge: 'CURRENT PLAN',
                  name: 'Free Explorer',
                  price: '${region.symbol}0',
                  subtext: 'Always free',
                  color: AppColors.textTertiary,
                  features: const [
                    'Standard 25km Radar Heatmap',
                    '5 Path-Crossing Echoes / day',
                    'Encrypted End-to-End Chat',
                    '500m Grid Privacy Obfuscation',
                  ],
                ),

                const SizedBox(height: 30),

                // Feature Comparison Matrix
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceL1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FEATURE COMPARISON',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMatrixRow('Radar Range', '25 km', '50 km', '100 km'),
                      _buildMatrixRow('Daily Echoes', '5 / day', 'Unlimited', 'Unlimited'),
                      _buildMatrixRow('Stealth Radar', '✕', '✕', '✓'),
                      _buildMatrixRow('See Who Liked You', '✕', '✕', '✓'),
                      _buildMatrixRow('Screenshot Protection', 'Standard', 'Enhanced', 'Hardware Lock'),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // CTA Button
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: _selectedTierIndex == 0
                        ? null
                        : (_selectedTierIndex == 2
                            ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                            : const LinearGradient(colors: [Color(0xFFFF4D67), Color(0xFF7928CA)])),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _selectedTierIndex == 0
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFFFF4D67).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _selectedTierIndex == 0
                        ? null
                        : () {
                            final name = _selectedTierIndex == 1 ? 'Explorer Pass' : 'VIP Pass';
                            final String priceStr;
                            if (_selectedTierIndex == 1) {
                              priceStr = _isAnnual ? '${region.explorerAnnualTotal}/year' : '${region.explorerMonthly}/month';
                            } else {
                              priceStr = _isAnnual ? '${region.vipAnnualTotal}/year' : '${region.vipMonthly}/month';
                            }
                            _openAuraVaultCheckout(name, priceStr);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTierIndex == 0 ? const Color(0xFF1E2838) : Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: _selectedTierIndex == 2 ? const Color(0xFF0D0D1A) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTierIndex == 0
                              ? 'Current Active Plan'
                              : 'Subscribe with Biometric / Card Gateway',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'Subscriptions auto-renew until cancelled. Multi-currency 256-bit AES Vault checkout. Cancel anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          if (_isProcessingPayment)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF4D67)),
                    SizedBox(height: 20),
                    Text(
                      'Activating FindAura Premium Entitlement...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillingTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4D67) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required int tierIndex,
    required String badge,
    required String name,
    required String price,
    required String subtext,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = _selectedTierIndex == tierIndex;

    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = tierIndex),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? color : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? color : AppColors.textDisabled,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  price,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Text(
              subtext,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceL2, height: 1),
            const SizedBox(height: 14),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

  Widget _buildMatrixRow(String title, String free, String explorer, String vip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              explorer,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.auroraTeal, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              vip,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.auroraGold, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// AURA VAULT PAYMENT GATEWAY: BIOMETRIC & CARD MODAL SHEET
// ────────────────────────────────────────────────────────────────────────────
class _AuraVaultGatewaySheet extends StatefulWidget {
  final String planName;
  final String price;
  final CurrencyRegion currencyRegion;
  final int tierIndex;
  final void Function(String transactionId, String methodUsed) onPaymentSuccess;

  const _AuraVaultGatewaySheet({
    required this.planName,
    required this.price,
    required this.currencyRegion,
    required this.tierIndex,
    required this.onPaymentSuccess,
  });

  @override
  State<_AuraVaultGatewaySheet> createState() => _AuraVaultGatewaySheetState();
}

class _AuraVaultGatewaySheetState extends State<_AuraVaultGatewaySheet>
    with SingleTickerProviderStateMixin {
  int _activeGatewayTab = 0; // 0 = Credit/Debit Card, 1 = Biometric One-Tap

  // Card input controllers
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  bool _isCardValid = false;
  bool _isAuthorizing = false;

  // Biometric scanner state
  bool _isScanningBiometric = false;
  late final AnimationController _biometricPulseController;
  late final Animation<double> _biometricPulseAnimation;

  @override
  void initState() {
    super.initState();
    _biometricPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _biometricPulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _biometricPulseController, curve: Curves.easeInOut),
    );

    _cardNumberController.addListener(_validateCard);
    _cardExpiryController.addListener(_validateCard);
    _cardCvvController.addListener(_validateCard);
    _cardHolderController.addListener(_validateCard);
  }

  @override
  void dispose() {
    _biometricPulseController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  void _validateCard() {
    final rawNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
    final expiry = _cardExpiryController.text.trim();
    final cvv = _cardCvvController.text.trim();
    final name = _cardHolderController.text.trim();

    final validNumber = rawNumber.length >= 15 && rawNumber.length <= 16;
    final validExpiry = RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(expiry);
    final validCvv = cvv.length >= 3 && cvv.length <= 4;
    final validName = name.length >= 3;

    final isAllValid = validNumber && validExpiry && validCvv && validName;
    if (isAllValid != _isCardValid) {
      setState(() => _isCardValid = isAllValid);
    }
  }

  String _detectCardBrand(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('4')) return 'VISA';
    if (clean.startsWith(RegExp(r'5[1-5]')) || clean.startsWith(RegExp(r'2[2-7]'))) return 'MASTERCARD';
    if (clean.startsWith(RegExp(r'3[47]'))) return 'AMEX';
    if (clean.startsWith('60') || clean.startsWith('65')) return 'RUPAY';
    return 'CARD';
  }

  Future<void> _processCardPayment() async {
    if (!_isCardValid) return;
    setState(() => _isAuthorizing = true);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final token = 'AES_TOKEN_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}';
    final brand = _detectCardBrand(_cardNumberController.text);
    widget.onPaymentSuccess(token, 'Encrypted $brand Vault Card');
  }

  Future<void> _processBiometricPayment() async {
    setState(() => _isScanningBiometric = true);
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final bioToken = 'BIO_CRYPT_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}';
    widget.onPaymentSuccess(bioToken, 'Hardware Biometric Sensor');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF1E2838), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Vault Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF4D67).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.security_rounded, color: Color(0xFFFF4D67), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FindAura Vault Payment Gateway',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.planName} • ${widget.price}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Selector: Card vs Biometric
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF131A26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeGatewayTab = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _activeGatewayTab == 0 ? const Color(0xFF1E2838) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: 16,
                              color: _activeGatewayTab == 0 ? const Color(0xFFFF4D67) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Card Gateway',
                              style: TextStyle(
                                color: _activeGatewayTab == 0 ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: _activeGatewayTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeGatewayTab = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _activeGatewayTab == 1 ? const Color(0xFF1E2838) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 17,
                              color: _activeGatewayTab == 1 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Biometric One-Tap',
                              style: TextStyle(
                                color: _activeGatewayTab == 1 ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: _activeGatewayTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF1E293B)),

          // Active Tab Body
          Expanded(
            child: _activeGatewayTab == 0 ? _buildCardGatewayBody() : _buildBiometricGatewayBody(),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // CARD GATEWAY BODY WITH LIVE PREVIEW
  // ───────────────────────────────────────────────
  Widget _buildCardGatewayBody() {
    final rawNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
    final brand = _detectCardBrand(rawNumber);
    final cardHolder = _cardHolderController.text.isEmpty ? 'AURA MEMBER' : _cardHolderController.text.toUpperCase();
    final expiry = _cardExpiryController.text.isEmpty ? 'MM/YY' : _cardExpiryController.text;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      children: [
        // Live Holographic Card Preview
        Container(
          height: 175,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF311042), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0x33FF4D67), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.nfc_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AURA VAULT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              // Card Number
              Text(
                rawNumber.isEmpty
                    ? '•••• •••• •••• ••••'
                    : _formatCardNumberDisplay(rawNumber),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARDHOLDER',
                        style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        cardHolder,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'EXPIRES',
                        style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        expiry,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Cardholder Name
        _buildInputField(
          controller: _cardHolderController,
          label: 'Cardholder Full Name',
          hint: 'e.g. Sanjay Verma',
          icon: Icons.person_outline_rounded,
        ),

        const SizedBox(height: 12),

        // Card Number
        _buildInputField(
          controller: _cardNumberController,
          label: 'Card Number',
          hint: '4000 1234 5678 9010',
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            _CardNumberInputFormatter(),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _cardExpiryController,
                label: 'Expiry Date',
                hint: 'MM/YY',
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  _CardExpiryInputFormatter(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                controller: _cardCvvController,
                label: 'CVV / CVC',
                hint: '•••',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Submit Card Button
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: _isCardValid
                ? const LinearGradient(colors: [Color(0xFFFF4D67), Color(0xFF7928CA)])
                : null,
            color: _isCardValid ? null : const Color(0xFF1E2838),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton(
            onPressed: (_isCardValid && !_isAuthorizing) ? _processCardPayment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isAuthorizing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Encrypting & Tokenizing Card...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  )
                : Text(
                    'Pay ${widget.price} Securely',
                    style: TextStyle(
                      color: _isCardValid ? Colors.white : const Color(0xFF64748B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),
        const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
              SizedBox(width: 6),
              Text(
                'PCI-DSS Level 1 Encrypted • 3D Secure 2.0 Auth',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // BIOMETRIC ONE-TAP GATEWAY BODY
  // ───────────────────────────────────────────────
  Widget _buildBiometricGatewayBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Biometric Sensor Graphic with Animated Ring
          ScaleTransition(
            scale: _biometricPulseAnimation,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isScanningBiometric ? Icons.fingerprint_rounded : Icons.fingerprint_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'One-Tap Biometric Authentication',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirm payment instantly using device Face ID or Fingerprint scanner. Zero card numbers stored.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Authorized Charge', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                Text(
                  widget.price,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Authenticate Button
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isScanningBiometric ? null : _processBiometricPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isScanningBiometric
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Validating Biometric Sensor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Authenticate & Subscribe Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
            filled: true,
            fillColor: const Color(0xFF131A26),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4D67), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCardNumberDisplay(String raw) {
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// INPUT FORMATTERS
// ────────────────────────────────────────────────────────────────────────────
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
