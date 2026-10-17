import 'dart:convert';

/// Social energy dimension for Aura DNA Blueprint
enum SocialEnergy {
  introvert('Introvert'),
  ambivert('Ambivert'),
  extrovert('Extrovert');

  final String label;
  const SocialEnergy(this.label);

  static SocialEnergy fromString(String? val) {
    if (val == null) return SocialEnergy.ambivert;
    return SocialEnergy.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == val.toLowerCase() ||
          e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => SocialEnergy.ambivert,
    );
  }
}

/// Ideal first meet preferences for Aura DNA Blueprint
enum IdealFirstMeet {
  coffeeAndWalk('Coffee & Walk'),
  cozyDrinks('Cozy Drinks'),
  deepTalk('Deep Talk'),
  foodAndMusic('Food & Music');

  final String label;
  const IdealFirstMeet(this.label);

  static IdealFirstMeet fromString(String? val) {
    if (val == null) return IdealFirstMeet.coffeeAndWalk;
    return IdealFirstMeet.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == val.toLowerCase() ||
          e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => IdealFirstMeet.coffeeAndWalk,
    );
  }
}

/// Lifestyle pace dimension for Aura DNA Blueprint
enum LifestylePace {
  spontaneous('Spontaneous'),
  balanced('Balanced'),
  mindful('Mindful');

  final String label;
  const LifestylePace(this.label);

  static LifestylePace fromString(String? val) {
    if (val == null) return LifestylePace.balanced;
    return LifestylePace.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == val.toLowerCase() ||
          e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => LifestylePace.balanced,
    );
  }
}

/// Connection goal dimension for Aura DNA Blueprint
enum ConnectionGoal {
  meaningful('Meaningful'),
  chemistry('Chemistry'),
  exploring('Exploring');

  final String label;
  const ConnectionGoal(this.label);

  static ConnectionGoal fromString(String? val) {
    if (val == null) return ConnectionGoal.meaningful;
    return ConnectionGoal.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == val.toLowerCase() ||
          e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => ConnectionGoal.meaningful,
    );
  }
}

/// Compatibility scoring algorithm utility:
/// Evaluates two [DnaBlueprint] instances across 4 psychological dimensions
/// and returns a deterministic compatibility percentage strictly between 50% and 99%.
int calculateCompatibility(DnaBlueprint a, DnaBlueprint b) {
  const int baseScore = 50;

  // 1. Social Energy (0 - 12 points)
  int socialPoints = 0;
  if (a.socialEnergy == b.socialEnergy) {
    socialPoints = 12;
  } else if (a.socialEnergy == SocialEnergy.ambivert ||
      b.socialEnergy == SocialEnergy.ambivert) {
    // Ambiverts harmonize easily with both Introverts and Extroverts
    socialPoints = 9;
  } else {
    // Introvert + Extrovert (Opposites dynamic)
    socialPoints = 6;
  }

  // 2. Ideal First Meet (0 - 13 points)
  int meetPoints = 0;
  if (a.idealFirstMeet == b.idealFirstMeet) {
    meetPoints = 13;
  } else {
    final pair = {a.idealFirstMeet, b.idealFirstMeet};
    if (pair.contains(IdealFirstMeet.coffeeAndWalk) &&
        pair.contains(IdealFirstMeet.deepTalk)) {
      meetPoints = 9; // Intimate, conversational day dates
    } else if (pair.contains(IdealFirstMeet.cozyDrinks) &&
        pair.contains(IdealFirstMeet.foodAndMusic)) {
      meetPoints = 9; // Energetic evening ambiance
    } else if (pair.contains(IdealFirstMeet.coffeeAndWalk) &&
        pair.contains(IdealFirstMeet.cozyDrinks)) {
      meetPoints = 8; // Classic beverage meet
    } else if (pair.contains(IdealFirstMeet.deepTalk) &&
        pair.contains(IdealFirstMeet.cozyDrinks)) {
      meetPoints = 8; // Thoughtful evening chats
    } else {
      meetPoints = 5; // Moderate overlap
    }
  }

  // 3. Lifestyle Pace (0 - 12 points)
  int pacePoints = 0;
  if (a.lifestylePace == b.lifestylePace) {
    pacePoints = 12;
  } else if (a.lifestylePace == LifestylePace.balanced ||
      b.lifestylePace == LifestylePace.balanced) {
    pacePoints = 8; // Balanced adapts well to either Spontaneous or Mindful
  } else {
    // Spontaneous + Mindful (polar opposites)
    pacePoints = 4;
  }

  // 4. Connection Goal (0 - 12 points)
  int goalPoints = 0;
  if (a.connectionGoal == b.connectionGoal) {
    goalPoints = 12;
  } else {
    final pair = {a.connectionGoal, b.connectionGoal};
    if (pair.contains(ConnectionGoal.meaningful) &&
        pair.contains(ConnectionGoal.chemistry)) {
      goalPoints = 8; // Strong romantic aspiration
    } else if (pair.contains(ConnectionGoal.chemistry) &&
        pair.contains(ConnectionGoal.exploring)) {
      goalPoints = 7; // Open-minded sparks
    } else if (pair.contains(ConnectionGoal.meaningful) &&
        pair.contains(ConnectionGoal.exploring)) {
      goalPoints = 6; // Differing intentionality
    } else {
      goalPoints = 5;
    }
  }

  final total = baseScore + socialPoints + meetPoints + pacePoints + goalPoints;
  return total.clamp(50, 99);
}

/// Immutable Aura DNA Blueprint data model.
class DnaBlueprint {
  final SocialEnergy socialEnergy;
  final IdealFirstMeet idealFirstMeet;
  final LifestylePace lifestylePace;
  final ConnectionGoal connectionGoal;
  final DateTime? updatedAt;

  const DnaBlueprint({
    required this.socialEnergy,
    required this.idealFirstMeet,
    required this.lifestylePace,
    required this.connectionGoal,
    this.updatedAt,
  });

  /// Default baseline blueprint for new Aura members
  factory DnaBlueprint.defaultUser() {
    return const DnaBlueprint(
      socialEnergy: SocialEnergy.ambivert,
      idealFirstMeet: IdealFirstMeet.coffeeAndWalk,
      lifestylePace: LifestylePace.balanced,
      connectionGoal: ConnectionGoal.meaningful,
    );
  }

  /// Curated personas for radar demo nodes
  factory DnaBlueprint.ananya() {
    return const DnaBlueprint(
      socialEnergy: SocialEnergy.ambivert,
      idealFirstMeet: IdealFirstMeet.coffeeAndWalk,
      lifestylePace: LifestylePace.mindful,
      connectionGoal: ConnectionGoal.meaningful,
    );
  }

  factory DnaBlueprint.maya() {
    return const DnaBlueprint(
      socialEnergy: SocialEnergy.introvert,
      idealFirstMeet: IdealFirstMeet.foodAndMusic,
      lifestylePace: LifestylePace.spontaneous,
      connectionGoal: ConnectionGoal.exploring,
    );
  }

  factory DnaBlueprint.rhea() {
    return const DnaBlueprint(
      socialEnergy: SocialEnergy.introvert,
      idealFirstMeet: IdealFirstMeet.deepTalk,
      lifestylePace: LifestylePace.mindful,
      connectionGoal: ConnectionGoal.meaningful,
    );
  }

  factory DnaBlueprint.rohan() {
    return const DnaBlueprint(
      socialEnergy: SocialEnergy.extrovert,
      idealFirstMeet: IdealFirstMeet.cozyDrinks,
      lifestylePace: LifestylePace.spontaneous,
      connectionGoal: ConnectionGoal.chemistry,
    );
  }

  /// Calculates compatibility percentage against another blueprint
  int calculateCompatibilityWith(DnaBlueprint other) {
    return calculateCompatibility(this, other);
  }

  DnaBlueprint copyWith({
    SocialEnergy? socialEnergy,
    IdealFirstMeet? idealFirstMeet,
    LifestylePace? lifestylePace,
    ConnectionGoal? connectionGoal,
    DateTime? updatedAt,
  }) {
    return DnaBlueprint(
      socialEnergy: socialEnergy ?? this.socialEnergy,
      idealFirstMeet: idealFirstMeet ?? this.idealFirstMeet,
      lifestylePace: lifestylePace ?? this.lifestylePace,
      connectionGoal: connectionGoal ?? this.connectionGoal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'socialEnergy': socialEnergy.label,
      'idealFirstMeet': idealFirstMeet.label,
      'lifestylePace': lifestylePace.label,
      'connectionGoal': connectionGoal.label,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory DnaBlueprint.fromMap(Map<String, dynamic> map) {
    return DnaBlueprint(
      socialEnergy: SocialEnergy.fromString(map['socialEnergy'] as String?),
      idealFirstMeet: IdealFirstMeet.fromString(map['idealFirstMeet'] as String?),
      lifestylePace: LifestylePace.fromString(map['lifestylePace'] as String?),
      connectionGoal: ConnectionGoal.fromString(map['connectionGoal'] as String?),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DnaBlueprint.fromJson(String source) =>
      DnaBlueprint.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DnaBlueprint &&
        other.socialEnergy == socialEnergy &&
        other.idealFirstMeet == idealFirstMeet &&
        other.lifestylePace == lifestylePace &&
        other.connectionGoal == connectionGoal;
  }

  @override
  int get hashCode =>
      socialEnergy.hashCode ^
      idealFirstMeet.hashCode ^
      lifestylePace.hashCode ^
      connectionGoal.hashCode;

  @override
  String toString() {
    return 'DnaBlueprint(socialEnergy: ${socialEnergy.label}, idealFirstMeet: ${idealFirstMeet.label}, lifestylePace: ${lifestylePace.label}, connectionGoal: ${connectionGoal.label})';
  }
}

/// Convenience alias matching PascalCase naming convention
typedef DnaBlueprintModel = DnaBlueprint;
