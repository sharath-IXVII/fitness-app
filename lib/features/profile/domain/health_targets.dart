import 'user_profile.dart';

/// Daily targets derived from the user's body and goal.
///
/// Formulas: Mifflin-St Jeor BMR × activity factor = TDEE, adjusted for the
/// goal. Protein is set per kg of body weight, fat at 25% of calories, carbs
/// take the remainder, and fiber follows the 14 g per 1000 kcal guideline.
class HealthTargets {
  const HealthTargets({
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.waterMl,
    required this.steps,
    required this.walkKm,
    required this.walkKcal,
    required this.kcalPerKm,
    required this.strideM,
    required this.bmi,
  });

  final int bmr;
  final int tdee;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int waterMl;

  /// Daily walking target: steps, the distance they make, and the calories
  /// that burns for this body weight.
  final int steps;
  final double walkKm;
  final int walkKcal;

  /// Calories one km of walking burns for this person (≈ 0.5 per kg).
  final double kcalPerKm;
  final double strideM;
  final double bmi;

  static const _activityFactor = {
    ActivityLevel.sedentary: 1.2,
    ActivityLevel.light: 1.375,
    ActivityLevel.moderate: 1.55,
    ActivityLevel.active: 1.725,
    ActivityLevel.veryActive: 1.9,
  };

  static const _proteinPerKg = {FitnessGoal.loseWeight: 1.8, FitnessGoal.maintain: 1.4, FitnessGoal.buildMuscle: 2.0};

  /// [waterBoostMl] is the season's extra water (hot months need more);
  /// [waterOverrideMl] is a goal the user set themselves.
  factory HealthTargets.from(UserProfile p, {int waterBoostMl = 0, int? waterOverrideMl}) {
    final genderOffset = switch (p.gender) {
      Gender.male => 5.0,
      Gender.female => -161.0,
      Gender.other => -78.0,
    };
    final bmr = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age + genderOffset;
    final tdee = bmr * _activityFactor[p.activity]!;

    final floor = p.gender == Gender.male ? 1500.0 : 1200.0;
    final calories = switch (p.goal) {
      FitnessGoal.loseWeight => (tdee - 500).clamp(floor, double.infinity),
      FitnessGoal.maintain => tdee,
      FitnessGoal.buildMuscle => tdee + 300,
    };

    final protein = p.weightKg * _proteinPerKg[p.goal]!;
    final fat = calories * 0.25 / 9;
    final carbs = ((calories - protein * 4 - fat * 9) / 4).clamp(0, double.infinity);

    final active = p.activity.index >= ActivityLevel.active.index;
    final water = waterOverrideMl ?? _roundTo(p.weightKg * 35 + (active ? 500 : 0) + waterBoostMl, 50);

    final strideFactor = p.gender == Gender.female ? 0.413 : 0.415;
    final heightM = p.heightCm / 100;
    final strideM = double.parse((p.heightCm * strideFactor / 100).toStringAsFixed(2));

    // Walking goal: the calories a day of walking should burn for the goal,
    // turned into distance with this person's weight, then into steps with
    // their stride. Kept to a sensible 5,000–15,000 steps.
    final walkKcal = switch (p.goal) {
      FitnessGoal.loseWeight => 300.0,
      FitnessGoal.maintain => 200.0,
      FitnessGoal.buildMuscle => 150.0,
    };
    final kcalPerKm = 0.5 * p.weightKg;
    final steps = _roundTo((walkKcal / kcalPerKm * 1000 / strideM).clamp(5000, 15000), 500);
    final km = steps * strideM / 1000;

    return HealthTargets(
      bmr: bmr.round(),
      tdee: tdee.round(),
      calories: calories.round(),
      proteinG: protein.round(),
      carbsG: carbs.round(),
      fatG: fat.round(),
      fiberG: (calories / 1000 * 14).round(),
      waterMl: water,
      steps: steps,
      walkKm: double.parse(km.toStringAsFixed(1)),
      walkKcal: (km * kcalPerKm).round(),
      kcalPerKm: kcalPerKm,
      strideM: strideM,
      bmi: double.parse((p.weightKg / (heightM * heightM)).toStringAsFixed(1)),
    );
  }

  static int _roundTo(double v, int step) => (v / step).round() * step;
}
