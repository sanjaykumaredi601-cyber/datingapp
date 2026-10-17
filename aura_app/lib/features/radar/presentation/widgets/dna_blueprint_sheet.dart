import 'package:aura_app/core/services/cosmic_resonance_engine.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_app/core/services/dna_blueprint_service.dart';
import 'package:aura_app/features/radar/data/models/dna_blueprint_model.dart';

/// Modern Glassmorphic modal sheet for configuring Aura DNA Blueprint preferences.
/// Deep Obsidian Slate (#131924, 95% opacity, border: 1px solid rgba(121, 40, 202, 0.3)).
class DnaBlueprintSheet extends StatefulWidget {
  final DnaBlueprint? initialBlueprint;
  final ValueChanged<DnaBlueprint>? onSaved;

  const DnaBlueprintSheet({
    super.key,
    this.initialBlueprint,
    this.onSaved,
  });

  /// Static helper to display the sheet from any context
  static Future<DnaBlueprint?> show(
    BuildContext context, {
    DnaBlueprint? initialBlueprint,
    ValueChanged<DnaBlueprint>? onSaved,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<DnaBlueprint>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DnaBlueprintSheet(
        initialBlueprint: initialBlueprint,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<DnaBlueprintSheet> createState() => _DnaBlueprintSheetState();
}

class _DnaBlueprintSheetState extends State<DnaBlueprintSheet> {
  late SocialEnergy _selectedEnergy;
  late IdealFirstMeet _selectedMeet;
  late LifestylePace _selectedPace;
  late ConnectionGoal _selectedGoal;
  bool _isSaving = false;

  // Colors matching daylight design specifications
  static const Color deepObsidian = Color(0xFFFFFFFF);
  static const Color electricIris = Color(0xFF8B5CF6);
  static const Color sunsetCoral = Color(0xFFFF3366);
  static const Color iceWhite = Color(0xFF181829);
  static const Color titaniumGray = Color(0xFF4B5563);

  @override
  void initState() {
    super.initState();
    final current = widget.initialBlueprint ?? DnaBlueprintService().blueprint;
    _selectedEnergy = current.socialEnergy;
    _selectedMeet = current.idealFirstMeet;
    _selectedPace = current.lifestylePace;
    _selectedGoal = current.connectionGoal;
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final updated = DnaBlueprint(
      socialEnergy: _selectedEnergy,
      idealFirstMeet: _selectedMeet,
      lifestylePace: _selectedPace,
      connectionGoal: _selectedGoal,
      updatedAt: DateTime.now(),
    );

    widget.onSaved?.call(updated);

    // Save to local storage and sync to Firestore
    await DnaBlueprintService().saveBlueprint(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final maxSheetHeight = media.size.height * 0.85;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFFFFE4E6), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 28,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: electricIris.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '✨ Your Aura DNA Blueprint',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: iceWhite,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: electricIris.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: electricIris.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Active Frequency',
                            style: TextStyle(
                              color: sunsetCoral,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Define your frequency to discover compatible matches nearby.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: titaniumGray,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0x22FFFFFF), height: 1),

              // Scrollable Options Rows
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Social Energy
                      _buildDimensionRow(
                        title: 'SOCIAL ENERGY',
                        icon: Icons.bolt_rounded,
                        accentColor: sunsetCoral,
                        children: [
                          _buildOptionChip(
                            label: 'Introvert 🧘',
                            isSelected: _selectedEnergy == SocialEnergy.introvert,
                            onTap: () {
                              setState(() => _selectedEnergy = SocialEnergy.introvert);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Ambivert ⚖️',
                            isSelected: _selectedEnergy == SocialEnergy.ambivert,
                            onTap: () {
                              setState(() => _selectedEnergy = SocialEnergy.ambivert);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Extrovert ⚡',
                            isSelected: _selectedEnergy == SocialEnergy.extrovert,
                            onTap: () {
                              setState(() => _selectedEnergy = SocialEnergy.extrovert);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Row 2: Ideal First Meet
                      _buildDimensionRow(
                        title: 'IDEAL FIRST MEET',
                        icon: Icons.local_cafe_rounded,
                        accentColor: electricIris,
                        children: [
                          _buildOptionChip(
                            label: 'Coffee & Walk ☕',
                            isSelected: _selectedMeet == IdealFirstMeet.coffeeAndWalk,
                            onTap: () {
                              setState(() => _selectedMeet = IdealFirstMeet.coffeeAndWalk);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Cozy Drinks 🍸',
                            isSelected: _selectedMeet == IdealFirstMeet.cozyDrinks,
                            onTap: () {
                              setState(() => _selectedMeet = IdealFirstMeet.cozyDrinks);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Deep Talk 🌙',
                            isSelected: _selectedMeet == IdealFirstMeet.deepTalk,
                            onTap: () {
                              setState(() => _selectedMeet = IdealFirstMeet.deepTalk);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Food & Music 🎵',
                            isSelected: _selectedMeet == IdealFirstMeet.foodAndMusic,
                            onTap: () {
                              setState(() => _selectedMeet = IdealFirstMeet.foodAndMusic);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Row 3: Lifestyle Pace
                      _buildDimensionRow(
                        title: 'LIFESTYLE PACE',
                        icon: Icons.speed_rounded,
                        accentColor: sunsetCoral,
                        children: [
                          _buildOptionChip(
                            label: 'Spontaneous 🚀',
                            isSelected: _selectedPace == LifestylePace.spontaneous,
                            onTap: () {
                              setState(() => _selectedPace = LifestylePace.spontaneous);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Balanced 🌊',
                            isSelected: _selectedPace == LifestylePace.balanced,
                            onTap: () {
                              setState(() => _selectedPace = LifestylePace.balanced);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Mindful 🌿',
                            isSelected: _selectedPace == LifestylePace.mindful,
                            onTap: () {
                              setState(() => _selectedPace = LifestylePace.mindful);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Row 4: Connection Goal
                      _buildDimensionRow(
                        title: 'CONNECTION GOAL',
                        icon: Icons.favorite_rounded,
                        accentColor: electricIris,
                        children: [
                          _buildOptionChip(
                            label: 'Meaningful 💍',
                            isSelected: _selectedGoal == ConnectionGoal.meaningful,
                            onTap: () {
                              setState(() => _selectedGoal = ConnectionGoal.meaningful);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Chemistry 🔥',
                            isSelected: _selectedGoal == ConnectionGoal.chemistry,
                            onTap: () {
                              setState(() => _selectedGoal = ConnectionGoal.chemistry);
                              HapticFeedback.selectionClick();
                            },
                          ),
                          _buildOptionChip(
                            label: 'Exploring ✨',
                            isSelected: _selectedGoal == ConnectionGoal.exploring,
                            onTap: () {
                              setState(() => _selectedGoal = ConnectionGoal.exploring);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildCosmicResonanceRow(),
                    ],
                  ),
                ),
              ),

              // Bottom Save Action Bar with Gentle Glow Effect
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: deepObsidian,
                  border: const Border(
                    top: BorderSide(color: Color(0x1FFFFFFF), width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [electricIris, sunsetCoral],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: sunsetCoral.withValues(alpha: 0.38), // gentle glow effect
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: electricIris.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Save Blueprint',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCosmicResonanceRow() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF080A0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7928CA).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7928CA).withValues(alpha: 0.12),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text(
                'AURA COSMIC RESONANCE',
                style: TextStyle(
                  color: Color(0xFF67E8F9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D67).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '94% SYNC',
                  style: TextStyle(
                    color: Color(0xFFFF4D67),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CosmicResonanceEngine.instance.formatCelestialBadge(
              sunSign: 'Aries',
              moonRashi: 'Scorpio',
              compatibilityPercent: 94,
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Vedic Moon Sign (Rashi) & Western Sun Sign mapped into your 4D Frequency Matrix.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRow({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 15),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSelected
              ? sunsetCoral.withValues(alpha: 0.12)
              : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? sunsetCoral
                : const Color(0xFFFFE4E6),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: sunsetCoral.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: sunsetCoral,
                size: 14,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? sunsetCoral : titaniumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
