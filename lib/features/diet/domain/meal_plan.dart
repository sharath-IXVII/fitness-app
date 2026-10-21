import 'dart:math' as math;

import '../../profile/domain/user_profile.dart';
import 'food.dart';
import 'food_db.dart';
import 'meal_log.dart';

class PlanItem {
  const PlanItem(this.food, this.servings);

  final Food food;
  final double servings;

  Macros get macros => food.macros.scale(servings);
}

class PlannedMeal {
  const PlannedMeal(this.meal, this.items);

  final MealType meal;
  final List<PlanItem> items;

  Macros get macros => items.fold(const Macros(), (m, i) => m + i.macros);
}

/// Meal ideas: food ids with base servings, per meal slot. Each idea is
/// only offered if every food fits the user's diet.
const _ideas = <MealType, List<List<(String, double)>>>{
  MealType.breakfast: [
    [('poha', 1), ('curd', 0.5)],
    [('idli', 1.5), ('sambar', 1)],
    [('besan_chilla', 1), ('curd', 0.5)],
    [('moong_chilla', 1), ('apple', 1)],
    [('oats_milk', 1), ('banana', 1)],
    [('oats', 1), ('peanut_butter', 0.5), ('banana', 1)],
    [('upma', 1), ('sprouts', 0.5)],
    [('omelette', 1), ('bread', 1)],
    [('egg_bhurji', 1), ('roti', 1)],
    [('dosa', 1), ('sambar', 1), ('boiled_egg', 1)],
    [('tofu', 1), ('bread', 1)],
  ],
  MealType.lunch: [
    [('roti', 2), ('dal', 1), ('mixed_veg', 1), ('salad', 1)],
    [('rice', 1), ('rajma', 1), ('salad', 1)],
    [('rice', 1), ('sambar', 1), ('curd', 0.5), ('mixed_veg', 1)],
    [('roti', 2), ('palak_paneer', 1), ('salad', 1)],
    [('roti', 2), ('chole', 1), ('salad', 1)],
    [('brown_rice', 1), ('soya', 1), ('mixed_veg', 1)],
    [('rice', 1), ('chicken_curry', 1), ('salad', 1)],
    [('roti', 2), ('fish_curry', 1), ('salad', 1)],
    [('rice', 1), ('egg_curry', 1), ('salad', 1)],
    [('quinoa', 1), ('tofu', 1), ('salad', 1)],
  ],
  MealType.snack: [
    [('greek_yogurt', 1)],
    [('sprouts', 1)],
    [('almonds', 1), ('apple', 1)],
    [('peanuts', 1), ('chai', 1)],
    [('whey', 1), ('banana', 1)],
    [('boiled_egg', 2)],
    [('buttermilk', 1), ('dates', 1)],
  ],
  MealType.dinner: [
    [('roti', 2), ('paneer_bhurji', 1), ('salad', 1)],
    [('khichdi', 1), ('curd', 1)],
    [('roti', 2), ('dal', 1), ('bhindi', 1)],
    [('roti', 2), ('soya', 1), ('mixed_veg', 1)],
    [('roti', 2), ('chicken_curry', 1), ('salad', 1)],
    [('brown_rice', 1), ('grilled_fish', 1.5), ('mixed_veg', 1)],
    [('roti', 2), ('tandoori', 1), ('salad', 1)],
    [('roti', 2), ('egg_curry', 1)],
    [('quinoa', 1), ('dal', 1), ('salad', 1)],
  ],
};

/// Builds one day of meals that fits [diet] and lands near [calories],
/// preferring higher-protein ideas when [proteinTarget] is high. [seed]
/// picks a different combination (e.g. the date, or a "shuffle" counter).
List<PlannedMeal> buildDayPlan({
  required DietType diet,
  required int calories,
  required int proteinTarget,
  required int seed,
}) {
  final rng = math.Random(seed);
  return [
    for (final meal in MealType.values)
      () {
        final options = [
          for (final idea in _ideas[meal]!)
            if (idea.every((i) => foodsById[i.$1]!.cls.fits(diet)))
              [for (final (id, s) in idea) PlanItem(foodsById[id]!, s)],
        ];
        // Prefer ideas with more protein per calorie when the target is high.
        options.sort((a, b) {
          double density(List<PlanItem> o) {
            final m = o.fold(const Macros(), (x, i) => x + i.macros);
            return m.protein / math.max(1, m.kcal);
          }

          return density(b).compareTo(density(a));
        });
        final topHalf = options.take(math.max(2, (options.length * 0.6).ceil())).toList();
        final pick = topHalf[rng.nextInt(topHalf.length)];
        final base = pick.fold(0.0, (k, i) => k + i.macros.kcal);
        final want = calories * meal.share;
        // Scale servings towards the calorie share, in half-serving steps.
        final f = (want / math.max(1, base)).clamp(0.6, 1.8);
        return PlannedMeal(meal, [
          for (final i in pick) PlanItem(i.food, math.max(0.5, (i.servings * f * 2).round() / 2)),
        ]);
      }(),
  ];
}
