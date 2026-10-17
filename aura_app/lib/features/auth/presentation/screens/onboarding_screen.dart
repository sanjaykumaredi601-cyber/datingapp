import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'profile_builder_screen.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onContinueAsGuest;

  const OnboardingScreen({super.key, required this.onContinueAsGuest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient gradient circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.auroraPurple.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.auroraTeal.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Brand Logo / Icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.auroraGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.auroraPurple.withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.waves_rounded, size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Brand Wordmark
                  const Text(
                    'AURA',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const AuroraGradientText(
                    'Find Your Frequency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle & Privacy Guarantee
                  const Text(
                    'Privacy-first dating based on real-world path crossings.\nNo precise location tracking. Zero spam.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Feature Highlights Carousel Cards
                  GlassmorphismCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    borderRadius: 20,
                    child: Column(
                      children: [
                        _buildFeatureRow(
                          Icons.radar_rounded,
                          'Anonymised Radar Heatmaps',
                          'Activity zones without pin-pointing your exact home or office.',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          Icons.swap_calls_rounded,
                          'Crossed Paths Echoes',
                          'Discover who shared your favorite spots throughout the day.',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          Icons.shield_outlined,
                          'DPDP Act & PIPEDA Safe',
                          'One-click 48h location wipe and full data sovereignty.',
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Actions
                  AuroraButton(
                    label: 'Get Started & Build Profile',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileBuilderScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  TextButton(
                    onPressed: onContinueAsGuest,
                    child: const Text(
                      'Preview as Guest Explorer',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceL2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.auroraTeal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
