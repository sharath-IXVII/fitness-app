import 'food.dart';

enum MealType {
  breakfast('Breakfast', 0.25),
  lunch('Lunch', 0.35),
  snack('Snacks', 0.10),
  dinner('Dinner', 0.30);

  const MealType(this.label, this.share);

  final String label;

  /// Share of the day's calories this meal usually takes.
  final double share;
}

/// One logged item. Macros are stored, not looked up, so custom foods and
/// scanned plates (Phase 6) work the same way and history never changes.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.meal,
    required this.name,
    required this.servings,
    required this.perServing,
    this.foodId,
    this.serving,
    this.source = 'manual',
  });

  final String id;
  final MealType meal;
  final String name;
  final double servings;
  final Macros perServing;
  final String? foodId;
  final String? serving;

  /// "manual", "plan" or "scan".
  final String source;

  Macros get macros => perServing.scale(servings);

  MealEntry copyWith({double? servings, MealType? meal}) => MealEntry(
    id: id,
    meal: meal ?? this.meal,
    name: name,
    servings: servings ?? this.servings,
    perServing: perServing,
    foodId: foodId,
    serving: serving,
    source: source,
  );

  factory MealEntry.ofFood(String id, MealType meal, Food f, double servings, {String source = 'manual'}) => MealEntry(
    id: id,
    meal: meal,
    name: f.name,
    servings: servings,
    perServing: f.macros,
    foodId: f.id,
    serving: f.serving,
    source: source,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'meal': meal.name,
    'name': name,
    'servings': servings,
    'macros': perServing.toJson(),
    'food': ?foodId,
    'serving': ?serving,
    'source': source,
  };

  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
    id: j['id'] as String,
    meal: MealType.values.byName(j['meal'] as String),
    name: j['name'] as String,
    servings: (j['servings'] as num).toDouble(),
    perServing: Macros.fromJson(j['macros'] as Map<String, dynamic>),
    foodId: j['food'] as String?,
    serving: j['serving'] as String?,
    source: j['source'] as String? ?? 'manual',
  );
}

Macros totalOf(Iterable<MealEntry> entries) => entries.fold(const Macros(), (m, e) => m + e.macros);

/// Meals (breakfast/lunch/snack/dinner) with at least one item.
int mealsCovered(Iterable<MealEntry> entries) => entries.map((e) => e.meal).toSet().length;
