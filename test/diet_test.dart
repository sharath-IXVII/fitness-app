import 'package:fitalarm/features/diet/domain/food.dart';
import 'package:fitalarm/features/diet/domain/food_db.dart';
import 'package:fitalarm/features/diet/domain/meal_log.dart';
import 'package:fitalarm/features/diet/domain/meal_plan.dart';
import 'package:fitalarm/features/diet/domain/weight_goal.dart';
import 'package:fitalarm/features/profile/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food database is consistent', () {
    expect(foodsById.length, foods.length, reason: 'ids are unique');
    for (final f in foods) {
      final m = f.macros;
      // Energy from macros should be close to the stated calories.
      final fromMacros = m.protein * 4 + m.carbs * 4 + m.fat * 9;
      expect((fromMacros - m.kcal).abs() / m.kcal, lessThan(0.3), reason: f.name);
    }
  });

  test('diet classes', () {
    expect(FoodClass.vegan.fits(DietType.vegan), isTrue);
    expect(FoodClass.veg.fits(DietType.vegan), isFalse);
    expect(FoodClass.egg.fits(DietType.veg), isFalse);
    expect(FoodClass.egg.fits(DietType.eggetarian), isTrue);
    expect(FoodClass.nonVeg.fits(DietType.eggetarian), isFalse);
    expect(FoodClass.nonVeg.fits(DietType.nonVeg), isTrue);
  });

  test('meal plans respect the diet and land near the calorie target', () {
    for (final diet in DietType.values) {
      for (var seed = 0; seed < 20; seed++) {
        final plan = buildDayPlan(diet: diet, calories: 2200, proteinTarget: 120, seed: seed);
        expect(plan.map((m) => m.meal), MealType.values);
        for (final meal in plan) {
          for (final i in meal.items) {
            expect(i.food.cls.fits(diet), isTrue, reason: '${i.food.name} in a $diet plan');
          }
        }
        final kcal = plan.fold(0.0, (k, m) => k + m.macros.kcal);
        expect(kcal, inInclusiveRange(2200 * 0.7, 2200 * 1.3), reason: '$diet seed $seed: $kcal');
      }
    }
  });

  test('meal entries total and count meals', () {
    final e1 = MealEntry.ofFood('1', MealType.breakfast, foodsById['poha']!, 1);
    final e2 = MealEntry.ofFood('2', MealType.breakfast, foodsById['curd']!, 0.5);
    final e3 = MealEntry.ofFood('3', MealType.lunch, foodsById['dal']!, 2);
    final t = totalOf([e1, e2, e3]);
    expect(t.kcal, 270 + 60 + 400);
    expect(t.protein, 5 + 3.5 + 24);
    expect(mealsCovered([e1, e2, e3]), 2);
    expect(MealEntry.fromJson(e2.toJson()).toJson(), e2.toJson());
  });

  group('weight goal', () {
    final now = DateTime(2026, 10, 21);
    WeightGoal goal(double target, int days) => WeightGoal(
      startKg: 80,
      targetKg: target,
      deadline: now.add(Duration(days: days)),
      createdAt: now,
    );

    test('5 kg in 10 weeks is a realistic 0.5 kg/week loss', () {
      final g = goal(75, 70);
      expect(g.neededPerWeek(80, now), closeTo(-0.5, 0.001));
      expect(g.pace(80, now), GoalPace.realistic);
      expect(g.dailyAdjustment(80, now), -550);
    });

    test('too-fast goals are capped at the safe limit', () {
      final g = goal(70, 28); // 10 kg in 4 weeks
      expect(g.pace(80, now), GoalPace.tooFast);
      expect(g.dailyAdjustment(80, now), -1100);
      expect(g.safeEta(80, now), now.add(const Duration(days: 70)));
    });

    test('gaining is capped at 0.5 kg a week', () {
      final g = goal(84, 28);
      expect(g.pace(80, now), GoalPace.tooFast);
      expect(g.dailyAdjustment(80, now), 550);
    });

    test('progress and json', () {
      final g = goal(75, 70);
      expect(g.progress(77.5), 0.5);
      expect(WeightGoal.fromJson(g.toJson()).toJson(), g.toJson());
    });
  });
}
