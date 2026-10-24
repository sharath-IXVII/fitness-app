import 'package:fitalarm/features/profile/domain/health_targets.dart';
import 'package:fitalarm/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile({
  Gender gender = Gender.male,
  FitnessGoal goal = FitnessGoal.maintain,
  ActivityLevel activity = ActivityLevel.sedentary,
  double weight = 70,
}) => UserProfile(
  name: 'Test',
  gender: gender,
  age: 25,
  heightCm: 175,
  weightKg: weight,
  goal: goal,
  activity: activity,
  diet: DietType.veg,
  level: FitnessLevel.beginner,
  wakeTime: const TimeOfDay(hour: 6, minute: 0),
  sleepTime: const TimeOfDay(hour: 22, minute: 0),
);

void main() {
  test('Mifflin-St Jeor BMR and TDEE for a sedentary male', () {
    final t = HealthTargets.from(_profile());
    // 10*70 + 6.25*175 - 5*25 + 5 = 1673.75
    expect(t.bmr, 1674);
    expect(t.tdee, (1673.75 * 1.2).round());
    expect(t.calories, t.tdee);
  });

  test('female offset is -161', () {
    final t = HealthTargets.from(_profile(gender: Gender.female));
    expect(t.bmr, (700 + 1093.75 - 125 - 161).round());
  });

  test('weight loss applies a 500 kcal deficit but never below the floor', () {
    final maintain = HealthTargets.from(_profile());
    final lose = HealthTargets.from(_profile(goal: FitnessGoal.loseWeight));
    expect(lose.calories, maintain.calories - 500);

    final tiny = HealthTargets.from(_profile(gender: Gender.female, goal: FitnessGoal.loseWeight, weight: 35));
    expect(tiny.calories, greaterThanOrEqualTo(1200));
  });

  test('macros add up to the calorie target', () {
    final t = HealthTargets.from(_profile(goal: FitnessGoal.buildMuscle, activity: ActivityLevel.active));
    expect(t.proteinG, 140);
    final kcal = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9;
    expect((kcal - t.calories).abs(), lessThan(15));
    expect(t.fiberG, (t.calories / 1000 * 14).round());
  });

  test('water, stride and BMI', () {
    final t = HealthTargets.from(_profile());
    expect(t.waterMl, 2450);
    expect(t.strideM, 0.73);
    expect(t.bmi, 22.9);

    final active = HealthTargets.from(_profile(activity: ActivityLevel.active));
    expect(active.waterMl, 2950);
  });

  test('walking goal comes from the goal, weight and height', () {
    final lose = HealthTargets.from(_profile(goal: FitnessGoal.loseWeight));
    final keep = HealthTargets.from(_profile());
    final bulk = HealthTargets.from(_profile(goal: FitnessGoal.buildMuscle));
    expect(lose.steps, greaterThan(keep.steps));
    expect(keep.steps, greaterThan(bulk.steps));
    expect(lose.steps, inInclusiveRange(5000, 15000));
    expect(lose.kcalPerKm, 35); // 0.5 kcal per kg per km
    // The distance is the steps times the stride.
    expect(lose.walkKm, closeTo(lose.steps * lose.strideM / 1000, 0.06));
    // A heavier person burns more per km, so needs less distance for the same burn.
    final heavy = HealthTargets.from(_profile(goal: FitnessGoal.loseWeight, weight: 110));
    expect(heavy.walkKm, lessThan(lose.walkKm));
    expect(heavy.walkKcal, closeTo(lose.walkKcal, 40));
  });

  test('water goes up in hot seasons, and a custom goal wins', () {
    final base = HealthTargets.from(_profile());
    expect(HealthTargets.from(_profile(), waterBoostMl: 500).waterMl, base.waterMl + 500);
    expect(HealthTargets.from(_profile(), waterBoostMl: 500, waterOverrideMl: 3000).waterMl, 3000);
  });

  test('profile survives a JSON round-trip', () {
    final p = _profile();
    final back = UserProfile.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
  });
}
