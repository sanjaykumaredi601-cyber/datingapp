import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DateVibeOption {
  final String title;
  final String description;
  final String emoji;
  final String tag;
  final String outfitRecommendation;
  final String palette;
  final String scentNotes;
  final String destinationName;
  final String weatherInfo;
  final String weatherAdvice;

  const DateVibeOption({
    required this.title,
    required this.description,
    required this.emoji,
    required this.tag,
    required this.outfitRecommendation,
    required this.palette,
    required this.scentNotes,
    required this.destinationName,
    required this.weatherInfo,
    required this.weatherAdvice,
  });
}

/// Interactive Date Concierge Bottom Sheet with Date Prep & Outfit Concierge
class DateConciergeSheet extends StatefulWidget {
  final String matchName;
  final Function(String invitationMessage)? onInviteSent;
  final int initialTabIndex;

  const DateConciergeSheet({
    super.key,
    required this.matchName,
    this.onInviteSent,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String matchName,
    Function(String invitationMessage)? onInviteSent,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DateConciergeSheet(
        matchName: matchName,
        onInviteSent: onInviteSent,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<DateConciergeSheet> createState() => _DateConciergeSheetState();
}

class _DateConciergeSheetState extends State<DateConciergeSheet> {
  int _selectedIndex = 0;
  late int _activeTab; // 0 = Date Vibes, 1 = Outfit & Prep

  // Interactive Pre-Date Checklist Items
  final Map<String, bool> _checklist = {
    'Windproof Compact Umbrella': true,
    'Signature Date Fragrance (Decant)': true,
    'Charged MagSafe Power Bank (10,000mAh)': true,
    'Aura Live Shield Emergency SOS Active': true,
  };

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
  }

  final List<DateVibeOption> _options = const [
    DateVibeOption(
      title: 'Banff Alpine Rooftop Stargazing',
      description: 'Mountain panoramic views, heated glacial hearths & warm mulled wine',
      emoji: '❄️',
      tag: 'Glacial Romance',
      destinationName: 'Banff Rooftop, Canada',
      weatherInfo: '❄️ -6°C • Light Alpine Flurries • 85% Humidity',
      weatherAdvice: 'Alpine Chill Alert: Warm cashmere thermal knit, structured wool overcoat & shearling-lined boots recommended.',
      outfitRecommendation: 'Heavyweight cashmere roll-neck, charcoal tailored wool trousers, structured trench & leather gloves.',
      palette: 'Glacial Ice Cyan · Obsidian Black · Alpine White',
      scentNotes: 'Tonka bean, crisp Siberian cedarwood & roasted amber',
    ),
    DateVibeOption(
      title: 'Bandra Coastal Monsoon Cafe',
      description: 'Arabian sea breeze, artisanal pour-overs & vinyl jazz rhythms',
      emoji: '🌧️',
      tag: 'Cozy Drizzle',
      destinationName: 'Bandra Coastal Cafe, Mumbai',
      weatherInfo: '🌧️ 26°C • Tropical Monsoon Drizzle • 92% Humidity',
      weatherAdvice: 'Monsoon Alert: Breathable moisture-wicking linen blend, waterproof trench & compact umbrella strongly advised.',
      outfitRecommendation: 'Relaxed linen camp-collar shirt, tailored lightweight chinos, clean leather minimalist loafers.',
      palette: 'Warm Almond · Espresso Cream · Coastal Sage',
      scentNotes: 'Bergamot, fresh vetiver, black pepper & crisp green tea',
    ),
    DateVibeOption(
      title: 'Rooftop Sunset & Craft Cocktails',
      description: 'Skyline views, ambient lounge tunes & vibrant nightlife energy',
      emoji: '🍷',
      tag: 'Romantic Sunset',
      destinationName: 'Sky Lounge Penthouse',
      weatherInfo: '🌆 21°C • Mild Golden Hour Breeze • Clear Skies',
      weatherAdvice: 'Evening Breeze: Light velvet blazer or structured jacket suitable for sunset transition.',
      outfitRecommendation: 'Velvet crimson blazer over sleek black silk top, gold jewelry accents & tailored slacks.',
      palette: 'Velvet Crimson · Obsidian Slate · Champagne Gold',
      scentNotes: 'Black rose, smoked saffron & golden amber',
    ),
    DateVibeOption(
      title: 'Hidden Contemporary Gallery & Gelato',
      description: 'Curated modern art walk followed by midnight artisanal gelato',
      emoji: '🎨',
      tag: 'Creative Spark',
      destinationName: 'Kala Ghoda Heritage Art Walk',
      weatherInfo: '🌙 24°C • Pleasant Starlight Walk • Zero Rain',
      weatherAdvice: 'Comfortable Walking: Minimalist sneakers or architectural loafers suitable for 2-hour gallery stroll.',
      outfitRecommendation: 'Architectural trench coat, monochrome ribbed turtleneck, minimalist loafers & crossbody leather bag.',
      palette: 'Pewter Grey · Ivory Cream · Deep Indigo',
      scentNotes: 'Iris blossom, white suede & crisp vetiver',
    ),
    DateVibeOption(
      title: 'Botanical Glasshouse Stroll & Tea',
      description: 'Tropical orchids, misty waterfalls & rare matcha tea in nature',
      emoji: '🌿',
      tag: 'Serene Botanical',
      destinationName: 'Glasshouse Conservatory',
      weatherInfo: '🌤️ 22°C • Humid Conservatory Climate • Sunny',
      weatherAdvice: 'Greenhouse Climate: Breathable layers you can easily shed as humidity rises inside the glasshouse.',
      outfitRecommendation: 'Relaxed earth-toned linen overshirt, off-white structured trousers & low-profile sneakers.',
      palette: 'Sage Green · Terracotta Earth · Warm Alabaster',
      scentNotes: 'Matcha leaf, fig bark & sheer white musk',
    ),
  ];

  void _sendInvitation() {
    HapticFeedback.mediumImpact();
    final selected = _options[_selectedIndex];
    final inviteMessage = '💌 Date Invitation: "${selected.title}" at ${selected.destinationName}! Weather forecast and prep styling confirmed.';

    if (widget.onInviteSent != null) {
      widget.onInviteSent!(inviteMessage);
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131924),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFFFF4D67), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Date invitation sent to ${widget.matchName}!',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF4D67), width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedVibe = _options[_selectedIndex];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 14,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF2080A0F), // 95% Deep Midnight Obsidian
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0x33FF4D67), width: 1.2),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x33FF4D67), Color(0x33F59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x66FF4D67), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 12),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'AURA DATE & OUTFIT CONCIERGE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Main heading
                  Text(
                    'Plan with ${widget.matchName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Where serendipity meets proximity — curated date vibes & lookbook styling',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Segmented Tab Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xBF131924),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x2EFFFFFF)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeTab = 0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _activeTab == 0 ? const Color(0xFFFF4D67) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '✨ Curated Vibes',
                                style: TextStyle(
                                  color: _activeTab == 0 ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeTab = 1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _activeTab == 1 ? const Color(0xFFFF4D67) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '👗 Outfit & Prep',
                                style: TextStyle(
                                  color: _activeTab == 1 ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tab 0: Date Vibes List
                  if (_activeTab == 0)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _options[index];
                          final isSelected = _selectedIndex == index;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedIndex = index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0x2BFF4D67)
                                    : const Color(0xBF131924),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFF4D67)
                                      : const Color(0x1FFFFFFF),
                                  width: isSelected ? 1.5 : 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0x33FF4D67)
                                          : const Color(0x1FFFFFFF),
                                    ),
                                    child: Text(item.emoji, style: const TextStyle(fontSize: 19)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0x4DF59E0B)
                                                    : const Color(0x1AFFFFFF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.tag,
                                                style: TextStyle(
                                                  color: isSelected ? const Color(0xFFF59E0B) : Colors.white60,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.description,
                                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: isSelected ? const Color(0xFFFF4D67) : Colors.white38,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    // Tab 1: Date Prep, Weather Forecast & Outfit Concierge Lookbook
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Destination Weather Forecast Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101726),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedVibe.destinationName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          selectedVibe.weatherInfo,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0x3338BDF8),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'LIVE FORECAST',
                                      style: TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.wb_sunny_outlined, color: Color(0xFFF59E0B), size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        selectedVibe.weatherAdvice,
                                        style: const TextStyle(
                                          color: Color(0xFFF1F5F9),
                                          fontSize: 11.5,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Outfit Styling Lookbook Container
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xBF131924),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x4DFF4D67), width: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFF4D67), Color(0xFFF59E0B)],
                                      ),
                                    ),
                                    child: const Icon(Icons.checkroom_rounded, color: Colors.white, size: 15),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Look for ${selectedVibe.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      selectedVibe.tag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Color(0x1FFFFFFF), height: 16),

                              const Text(
                                'RECOMMENDED ATTIRE',
                                style: TextStyle(
                                  color: Color(0xFFFF4D67),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selectedVibe.outfitRecommendation,
                                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'COLOR PALETTE',
                                          style: TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          selectedVibe.palette,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'INTIMATE SCENT',
                                          style: TextStyle(
                                            color: Color(0xFF7928CA),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          selectedVibe.scentNotes,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 3. Interactive Pre-Date Checklist (Umbrella, Fragrance, Power Bank)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1722),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.playlist_add_check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'PRE-DATE ESSENTIALS CHECKLIST',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_checklist.values.where((v) => v).length}/${_checklist.length} Ready',
                                    style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._checklist.entries.map((entry) {
                                final isChecked = entry.value;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _checklist[entry.key] = !isChecked;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                          color: isChecked ? const Color(0xFF10B981) : Colors.white38,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: TextStyle(
                                              color: isChecked ? Colors.white : Colors.white54,
                                              fontSize: 12,
                                              decoration: isChecked ? TextDecoration.none : TextDecoration.lineThrough,
                                              fontWeight: isChecked ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Action CTA Button
                  GestureDetector(
                    onTap: _sendInvitation,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4D67), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66FF4D67),
                            blurRadius: 16,
                            spreadRadius: 1,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Send Date Invitation & Save Look 💌',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
