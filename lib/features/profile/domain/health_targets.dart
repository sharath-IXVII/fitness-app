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
  final int steps;
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

  factory HealthTargets.from(UserProfile p) {
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
    final water = _roundTo(p.weightKg * 35 + (active ? 500 : 0), 50);

    final strideFactor = p.gender == Gender.female ? 0.413 : 0.415;
    final heightM = p.heightCm / 100;

    return HealthTargets(
      bmr: bmr.round(),
      tdee: tdee.round(),
      calories: calories.round(),
      proteinG: protein.round(),
      carbsG: carbs.round(),
      fatG: fat.round(),
      fiberG: (calories / 1000 * 14).round(),
      waterMl: water,
      steps: switch (p.goal) {
        FitnessGoal.loseWeight => 10000,
        _ => 8000,
      },
      strideM: double.parse((p.heightCm * strideFactor / 100).toStringAsFixed(2)),
      bmi: double.parse((p.weightKg / (heightM * heightM)).toStringAsFixed(1)),
    );
  }

  static int _roundTo(double v, int step) => (v / step).round() * step;
}
