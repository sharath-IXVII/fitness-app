import '../../profile/domain/user_profile.dart';

/// Which diets a food fits. A vegan food also fits every other diet, a
/// vegetarian (dairy) food fits veg/egg/non-veg, and so on.
enum FoodClass { vegan, veg, egg, nonVeg }

extension FoodClassFit on FoodClass {
  bool fits(DietType diet) => switch (diet) {
    DietType.vegan => this == FoodClass.vegan,
    DietType.veg => this == FoodClass.vegan || this == FoodClass.veg,
    DietType.eggetarian => this != FoodClass.nonVeg,
    DietType.nonVeg => true,
  };
}

class Macros {
  const Macros({this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0, this.fiber = 0});

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  Macros operator +(Macros o) => Macros(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
    fiber: fiber + o.fiber,
  );

  Macros scale(double f) =>
      Macros(kcal: kcal * f, protein: protein * f, carbs: carbs * f, fat: fat * f, fiber: fiber * f);

  Map<String, dynamic> toJson() => {'kcal': kcal, 'p': protein, 'c': carbs, 'f': fat, 'fib': fiber};

  factory Macros.fromJson(Map<String, dynamic> j) => Macros(
    kcal: (j['kcal'] as num).toDouble(),
    protein: (j['p'] as num).toDouble(),
    carbs: (j['c'] as num).toDouble(),
    fat: (j['f'] as num).toDouble(),
    fiber: (j['fib'] as num? ?? 0).toDouble(),
  );
}

/// A food with nutrition for one typical serving.
class Food {
  const Food(this.id, this.name, this.serving, this.cls, this.macros, {this.tags = const {}});

  final String id;
  final String name;

  /// Human description of one serving, e.g. "1 cup (200 g)".
  final String serving;
  final FoodClass cls;

  /// Per serving.
  final Macros macros;

  /// Search helpers: "breakfast", "high-protein", "snack", …
  final Set<String> tags;

  bool get highProtein => macros.protein >= 12 || macros.protein / (macros.kcal / 100) >= 8;
}

extension FoodJson on Food {
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'serving': serving,
    'cls': cls.name,
    'macros': macros.toJson(),
  };

  static Food fromJson(Map<String, dynamic> j) => Food(
    j['id'] as String,
    j['name'] as String,
    j['serving'] as String? ?? '1 serving',
    FoodClass.values.asNameMap()[j['cls']] ?? FoodClass.veg,
    Macros.fromJson(j['macros'] as Map<String, dynamic>),
    tags: const {'mine'},
  );
}
