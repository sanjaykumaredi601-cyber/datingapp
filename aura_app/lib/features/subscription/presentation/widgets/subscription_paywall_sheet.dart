import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/play_billing_service.dart';
import '../screens/subscription_screen.dart';

/// Polished Bottom Sheet Subscription Paywall
/// Displays "Explorer Pass" and "VIP Pass" tiers
/// Integrates Android Google Play Billing wrapper to fetch SKUs, launch native payment sheets,
/// and handle verified entitlement activations
class SubscriptionPaywallSheet extends StatefulWidget {
  const SubscriptionPaywallSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubscriptionPaywallSheet(),
    );
  }

  @override
  State<SubscriptionPaywallSheet> createState() =>
      _SubscriptionPaywallSheetState();
}

class _SubscriptionPaywallSheetState extends State<SubscriptionPaywallSheet> {
  final PlayBillingService _billingService = PlayBillingService();
  int _selectedTierIndex = 1; // 0 = Explorer Pass, 1 = VIP Pass
  bool _isAnnual = true;
  bool _isProcessingPayment = false;
  late final CurrencyRegion _region = CurrencyRegion.detectLocalRegion();

  @override
  void initState() {
    super.initState();
    _billingService.initialize();
  }

  String get _currentSku {
    if (_selectedTierIndex == 0) {
      return _isAnnual
          ? 'aura_pass_explorer_annual'
          : 'aura_pass_explorer_monthly';
    } else {
      return _isAnnual ? 'aura_pass_vip_annual' : 'aura_pass_vip_monthly';
    }
  }

  String get _currentPriceFormatted {
    if (_selectedTierIndex == 0) {
      return _isAnnual
          ? '${_region.explorerAnnualTotal} / yr (${_region.explorerAnnualMo}/mo)'
          : '${_region.explorerMonthly} / mo';
    } else {
      return _isAnnual
          ? '${_region.vipAnnualTotal} / yr (${_region.vipAnnualMo}/mo)'
          : '${_region.vipMonthly} / mo';
    }
  }

  Future<void> _handlePlayPurchase() async {
    setState(() => _isProcessingPayment = true);
    HapticFeedback.heavyImpact();

    try {
      final sku = _currentSku;
      final result = await _billingService.launchBillingFlow(sku);

      if (!mounted) return;
      setState(() => _isProcessingPayment = false);

      if (result.isSuccess) {
        final tierTitle = _selectedTierIndex == 0 ? 'Explorer Pass' : 'VIP Pass';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.warmAmber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Entitlement Unlocked: FindAura $tierTitle Activated!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceL2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Payment cancelled.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F141C).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Header Badge & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sunsetCoral.withValues(alpha: 0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AURA PASS',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Supercharge Proximity & Matches',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Auto-detected Local Currency Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_region.flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        '${_region.name} (${_region.code} ${_region.symbol}) · Auto-Detected Local Currency',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Monthly vs Annual Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceL1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAnnual = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isAnnual ? AppColors.surfaceL2 : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Monthly',
                              style: TextStyle(
                                color: !_isAnnual ? Colors.white : AppColors.textTertiary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAnnual = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isAnnual ? AppColors.sunsetCoral : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Annual',
                                style: TextStyle(
                                  color: _isAnnual ? Colors.white : AppColors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SAVE 40%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
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

              const SizedBox(height: 16),

              // ── Tier Cards: Explorer Pass vs VIP Pass ──
              Row(
                children: [
                  // Explorer Pass Card
                  Expanded(
                    child: _buildTierCard(
                      index: 0,
                      title: 'Explorer Pass',
                      price: _isAnnual ? '${_region.explorerAnnualMo}/mo' : '${_region.explorerMonthly}/mo',
                      subtext: _isAnnual ? 'Billed ${_region.explorerAnnualTotal}/yr' : 'Billed monthly',
                      badge: null,
                      accentColor: AppColors.sunsetCoral,
                      perks: [
                        'See who liked you',
                        'Unlimited rewinds',
                        'Incognito stealth mode',
                        '5 Radar density zones',
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // VIP Pass Card
                  Expanded(
                    child: _buildTierCard(
                      index: 1,
                      title: 'VIP Pass',
                      price: _isAnnual ? '${_region.vipAnnualMo}/mo' : '${_region.vipMonthly}/mo',
                      subtext: _isAnnual ? 'Billed ${_region.vipAnnualTotal}/yr' : 'Billed monthly',
                      badge: 'MOST POPULAR',
                      accentColor: AppColors.warmAmber,
                      perks: [
                        'All Explorer perks',
                        '5 Daily Super Waves',
                        'Global Travel mode',
                        '2x Echoes proximity',
                        'Encrypted VIP priority',
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ── Native Google Play Purchase Action Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessingPayment ? null : _handlePlayPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedTierIndex == 1
                        ? AppColors.warmAmber
                        : AppColors.sunsetCoral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isProcessingPayment
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Subscribe for $_currentPriceFormatted',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Security & Google Play Disclaimer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textTertiary.withValues(alpha: 0.8),
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Google Play Billing • Instant Entitlement Verification',
                    style: TextStyle(
                      color: AppColors.textTertiary.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required int index,
    required String title,
    required String price,
    required String subtext,
    required String? badge,
    required Color accentColor,
    required List<String> perks,
  }) {
    final isSelected = _selectedTierIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTierIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : AppColors.surfaceL1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge / Header
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              )
            else
              const SizedBox(height: 19),

            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                color: isSelected ? accentColor : AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtext,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 10),

            // Perks List
            ...perks.map((perk) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: accentColor, size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        perk,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.2),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
