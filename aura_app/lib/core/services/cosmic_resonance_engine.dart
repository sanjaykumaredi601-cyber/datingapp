/// Cosmic Resonance Engine (Astrology & Zodiac Blueprint).
/// Computes Western Sun Sign, Vedic Moon Sign (Rashi), and astrological
/// compatibility resonance scores for the Aura 4D DNA Blueprint.
class CosmicResonanceEngine {
  CosmicResonanceEngine._();
  static final CosmicResonanceEngine instance = CosmicResonanceEngine._();

  static const List<Map<String, dynamic>> westernSigns = [
    {'name': 'Capricorn', 'symbol': '♑', 'element': 'Earth', 'start': [1, 1], 'end': [1, 19]},
    {'name': 'Aquarius', 'symbol': '♒', 'element': 'Air', 'start': [1, 20], 'end': [2, 18]},
    {'name': 'Pisces', 'symbol': '♓', 'element': 'Water', 'start': [2, 19], 'end': [3, 20]},
    {'name': 'Aries', 'symbol': '♈', 'element': 'Fire', 'start': [3, 21], 'end': [4, 19]},
    {'name': 'Taurus', 'symbol': '♉', 'element': 'Earth', 'start': [4, 20], 'end': [5, 20]},
    {'name': 'Gemini', 'symbol': '♊', 'element': 'Air', 'start': [5, 21], 'end': [6, 20]},
    {'name': 'Cancer', 'symbol': '♋', 'element': 'Water', 'start': [6, 21], 'end': [7, 22]},
    {'name': 'Leo', 'symbol': '♌', 'element': 'Fire', 'start': [7, 23], 'end': [8, 22]},
    {'name': 'Virgo', 'symbol': '♍', 'element': 'Earth', 'start': [8, 23], 'end': [9, 22]},
    {'name': 'Libra', 'symbol': '♎', 'element': 'Air', 'start': [9, 23], 'end': [10, 22]},
    {'name': 'Scorpio', 'symbol': '♏', 'element': 'Water', 'start': [10, 23], 'end': [11, 21]},
    {'name': 'Sagittarius', 'symbol': '♐', 'element': 'Fire', 'start': [11, 22], 'end': [12, 21]},
    {'name': 'Capricorn', 'symbol': '♑', 'element': 'Earth', 'start': [12, 22], 'end': [12, 31]},
  ];

  static const List<Map<String, dynamic>> vedicRashis = [
    {'rashi': 'Mesha (Aries)', 'ruler': 'Mars', 'element': 'Fire'},
    {'rashi': 'Vrishabha (Taurus)', 'ruler': 'Venus', 'element': 'Earth'},
    {'rashi': 'Mithuna (Gemini)', 'ruler': 'Mercury', 'element': 'Air'},
    {'rashi': 'Karka (Cancer)', 'ruler': 'Moon', 'element': 'Water'},
    {'rashi': 'Simha (Leo)', 'ruler': 'Sun', 'element': 'Fire'},
    {'rashi': 'Kanya (Virgo)', 'ruler': 'Mercury', 'element': 'Earth'},
    {'rashi': 'Tula (Libra)', 'ruler': 'Venus', 'element': 'Air'},
    {'rashi': 'Vrischika (Scorpio)', 'ruler': 'Mars', 'element': 'Water'},
    {'rashi': 'Dhanu (Sagittarius)', 'ruler': 'Jupiter', 'element': 'Fire'},
    {'rashi': 'Makara (Capricorn)', 'ruler': 'Saturn', 'element': 'Earth'},
    {'rashi': 'Kumbha (Aquarius)', 'ruler': 'Saturn', 'element': 'Air'},
    {'rashi': 'Meena (Pisces)', 'ruler': 'Jupiter', 'element': 'Water'},
  ];

  /// Calculates Western Sun sign from birth month and day.
  Map<String, dynamic> calculateSunSign(int month, int day) {
    for (final sign in westernSigns) {
      final startM = sign['start'][0] as int;
      final startD = sign['start'][1] as int;
      final endM = sign['end'][0] as int;
      final endD = sign['end'][1] as int;

      if ((month == startM && day >= startD) || (month == endM && day <= endD)) {
        return sign;
      }
    }
    return westernSigns[3]; // Fallback to Aries
  }

  /// Calculates Vedic Moon Sign / Rashi from date of birth.
  Map<String, dynamic> calculateVedicRashi(DateTime dob) {
    // Sidereal zodiac offset calculation approximation
    final dayOfYear = dob.difference(DateTime(dob.year, 1, 1)).inDays;
    final rashiIndex = ((dayOfYear + 8) ~/ 30.5) % 12;
    return vedicRashis[rashiIndex];
  }

  /// Calculates cosmic compatibility resonance between two astrological profiles.
  int calculateCosmicResonance({
    required String sunSign1,
    required String sunSign2,
  }) {
    final s1 = westernSigns.firstWhere(
      (s) => s['name'].toString().toLowerCase() == sunSign1.toLowerCase(),
      orElse: () => westernSigns[3],
    );
    final s2 = westernSigns.firstWhere(
      (s) => s['name'].toString().toLowerCase() == sunSign2.toLowerCase(),
      orElse: () => westernSigns[4],
    );

    final elem1 = s1['element'];
    final elem2 = s2['element'];

    if (elem1 == elem2) return 94; // Same element
    if ((elem1 == 'Fire' && elem2 == 'Air') || (elem1 == 'Air' && elem2 == 'Fire')) return 91;
    if ((elem1 == 'Earth' && elem2 == 'Water') || (elem1 == 'Water' && elem2 == 'Earth')) return 89;
    return 82; // Harmonious growth pairing
  }

  /// Formats celestial badge label: e.g. "Aries ☀️ · Scorpio 🌙 • 92% Sync"
  String formatCelestialBadge({
    required String sunSign,
    required String moonRashi,
    int? compatibilityPercent,
  }) {
    final comp = compatibilityPercent != null ? ' • $compatibilityPercent% Cosmic Sync' : '';
    return '$sunSign ☀️ · $moonRashi 🌙$comp';
  }

  static CosmicProfileResult calculate({
    required DateTime birthDate,
    String? birthTime,
    String? birthCity,
  }) {
    final sun = instance.calculateSunSign(birthDate.month, birthDate.day);
    final rashi = instance.calculateVedicRashi(birthDate);
    final westernSign = sun['name'] as String;
    final westernSymbol = sun['symbol'] as String;
    final westernElement = sun['element'] as String;
    final vedicRashi = rashi['rashi'] as String;
    final vedicRuler = rashi['ruler'] as String;
    final badge = instance.formatCelestialBadge(sunSign: westernSign, moonRashi: vedicRashi);
    return CosmicProfileResult(
      westernSign: westernSign,
      westernSymbol: westernSymbol,
      westernElement: westernElement,
      vedicRashi: vedicRashi,
      vedicRuler: vedicRuler,
      badge: badge,
    );
  }

}

class CosmicProfileResult {
  final String westernSign;
  final String westernSymbol;
  final String westernElement;
  final String vedicRashi;
  final String vedicRuler;
  final String badge;

  const CosmicProfileResult({
    required this.westernSign,
    required this.westernSymbol,
    required this.westernElement,
    required this.vedicRashi,
    required this.vedicRuler,
    required this.badge,
  });
}
