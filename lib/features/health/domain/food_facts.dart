import 'package:flutter/material.dart';

import '../../diet/domain/food.dart';

/// Everyday foods with their nutrition per 100 g, to answer "which foods are
/// rich in what?". Values are typical figures from standard food composition
/// tables (USDA FoodData Central style), rounded. Home cooking and brands
/// vary, so treat them as a guide, not a lab result.
enum FactGroup {
  grains('Grains and starches'),
  pulses('Dals and beans'),
  nutsSeeds('Nuts and seeds'),
  dairyEggs('Milk and eggs'),
  meatFish('Meat and fish'),
  vegetables('Vegetables'),
  fruits('Fruits'),
  sweetsFats('Sugars and fats');

  const FactGroup(this.label);

  final String label;
}

/// How the weight was measured. Cooking adds water, so a cooked food always
/// looks "weaker" per 100 g than the same food dry.
enum FactState {
  raw('raw'),
  cooked('cooked'),
  dry('dry');

  const FactState(this.label);

  final String label;
}

/// The nutrients the guide can rank by.
enum FactNutrient {
  carbs('Carbs', 'g', Icons.grain_rounded, 'Your main fuel', 'Fuel for the brain and for workouts.'),
  protein('Protein', 'g', Icons.egg_alt_rounded, 'Builds and repairs', 'Builds muscle and keeps you full.'),
  fibre('Fibre', 'g', Icons.eco_rounded, 'Digestion and fullness', 'Keeps digestion regular and steadies sugar.'),
  fat('Fat', 'g', Icons.water_drop_rounded, 'Energy-dense', 'Needed for hormones. 9 kcal per gram, so it adds up.'),
  water('Water', 'g', Icons.opacity_rounded, 'Hydrating foods', 'Foods with more water fill you up on fewer calories.'),
  vitC('Vitamin C', 'mg', Icons.local_florist_rounded, 'Immunity and skin', 'Helps healing and iron absorption.'),
  vitA('Vitamin A', 'µg', Icons.visibility_rounded, 'Eyes and skin', 'Counted as RAE. Orange and dark green foods.'),
  calcium('Calcium', 'mg', Icons.egg_outlined, 'Bones and teeth', 'Also needed by muscles and nerves.'),
  iron('Iron', 'mg', Icons.bloodtype_rounded, 'Carries oxygen', 'Plant iron absorbs better with vitamin C.'),
  potassium('Potassium', 'mg', Icons.bolt_rounded, 'Fluid and muscles', 'Helps muscles and blood pressure balance.'),
  kcal('Calories', 'kcal', Icons.local_fire_department_rounded, 'Energy', 'Per 100 g, not per portion.');

  const FactNutrient(this.label, this.unit, this.icon, this.tagline, this.why);

  final String label;
  final String unit;
  final IconData icon;
  final String tagline;
  final String why;

  double? of(FoodFact f) => switch (this) {
    carbs => f.carbs,
    protein => f.protein,
    fibre => f.fibre,
    fat => f.fat,
    water => f.water,
    vitC => f.vitC,
    vitA => f.vitA,
    calcium => f.calcium,
    iron => f.iron,
    potassium => f.potassium,
    kcal => f.kcal,
  };

  /// "High" and "source" cut-offs per 100 g, or null when the nutrient is
  /// simply ranked. Vitamins and minerals use the EU labelling rule (30% and
  /// 15% of the daily reference value per 100 g); fibre uses the EU claim
  /// (6 g and 3 g). Protein, carbs and fat use simple guides of our own.
  ({double high, double source})? get cutoffs => switch (this) {
    protein => (high: 20, source: 10),
    carbs => (high: 45, source: 15),
    fibre => (high: 6, source: 3),
    fat => (high: 17.5, source: 3),
    vitC => (high: 24, source: 12),
    vitA => (high: 240, source: 120),
    calcium => (high: 240, source: 120),
    iron => (high: 4.2, source: 2.1),
    potassium => (high: 600, source: 300),
    water || kcal => null,
  };

  /// "Very rich", "Rich" or "Some", or null.
  String? band(double v) {
    final c = cutoffs;
    if (c == null) return null;
    if (this == protein || this == carbs) {
      if (v >= c.high) return this == protein ? 'Very rich' : 'High';
      if (v >= c.source) return this == protein ? 'Rich' : 'Medium';
      return this == carbs ? 'Low' : null;
    }
    if (this == fat) {
      if (v > c.high) return 'High';
      if (v > c.source) return 'Medium';
      return 'Low';
    }
    if (v >= c.high) return 'High';
    if (v >= c.source) return 'Source';
    return null;
  }
}

/// One food, nutrition per 100 g. Vitamins and minerals are null where the
/// reference value is not known well enough to print.
class FoodFact {
  const FoodFact(
    this.id,
    this.name,
    this.group,
    this.state,
    this.cls,
    this.kcal,
    this.protein,
    this.carbs,
    this.fibre,
    this.fat, {
    this.water,
    this.vitC,
    this.vitA,
    this.calcium,
    this.iron,
    this.potassium,
    this.note,
  });

  final String id;
  final String name;
  final FactGroup group;
  final FactState state;
  final FoodClass cls;
  final double kcal;
  final double protein;
  final double carbs;
  final double fibre;
  final double fat;
  final double? water;
  final double? vitC;
  final double? vitA;
  final double? calcium;
  final double? iron;
  final double? potassium;

  /// A short caveat, e.g. "typical paneer; brands vary".
  final String? note;

  String get label => '$name (${state.label})';
}

/// The foods, ranked by [n] from richest down. Foods without a value for [n]
/// are left out. [fits] narrows to a diet.
List<FoodFact> rankFoods(FactNutrient n, {bool Function(FoodFact)? fits}) {
  final list = [
    for (final f in foodFacts)
      if (n.of(f) != null && (fits == null || fits(f))) f,
  ]..sort((a, b) => n.of(b)!.compareTo(n.of(a)!));
  return list;
}

const _v = FoodClass.vegan, _d = FoodClass.veg, _e = FoodClass.egg, _m = FoodClass.nonVeg;
const _g = FactGroup.grains,
    _p = FactGroup.pulses,
    _n = FactGroup.nutsSeeds,
    _de = FactGroup.dairyEggs,
    _mf = FactGroup.meatFish,
    _ve = FactGroup.vegetables,
    _fr = FactGroup.fruits,
    _sf = FactGroup.sweetsFats;
const _raw = FactState.raw, _cooked = FactState.cooked, _dry = FactState.dry;

/// Per 100 g. Order: kcal, protein, carbs, fibre, fat; then optional water,
/// vitamin C (mg), vitamin A (µg RAE), calcium (mg), iron (mg), potassium (mg).
const foodFacts = <FoodFact>[
  // Grains and starches
  FoodFact('rice', 'White rice', _g, _cooked, _v, 130, 2.7, 28.2, 0.4, 0.3, water: 68.4, calcium: 10, iron: 1.2),
  FoodFact('brown_rice', 'Brown rice', _g, _cooked, _v, 123, 2.7, 25.6, 1.6, 1.0, water: 70.3, calcium: 3, iron: 0.6),
  FoodFact(
    'poha',
    'Poha (rice flakes)',
    _g,
    _dry,
    _v,
    346,
    6.6,
    77.3,
    1.2,
    1.2,
    note: 'Dry weight. Soaked and cooked poha is far lower per 100 g.',
  ),
  FoodFact('atta', 'Whole wheat flour (atta)', _g, _dry, _v, 340, 13.2, 72.0, 10.7, 2.5, water: 10.3, calcium: 34, iron: 3.9, potassium: 363),
  FoodFact('oats', 'Rolled oats', _g, _dry, _v, 379, 13.2, 67.7, 10.1, 6.5, water: 8.2, calcium: 52, iron: 4.3, potassium: 362),
  FoodFact('ragi', 'Ragi (finger millet)', _g, _dry, _v, 336, 7.3, 72.0, 3.6, 1.3, water: 11.2, calcium: 344, iron: 3.9, potassium: 408),
  FoodFact('bajra', 'Bajra (pearl millet)', _g, _dry, _v, 378, 11.0, 72.8, 8.5, 4.2, water: 8.7, calcium: 8, iron: 3.0, potassium: 195),
  FoodFact('jowar', 'Jowar (sorghum)', _g, _dry, _v, 329, 10.6, 72.1, 6.7, 3.5, water: 9.2, calcium: 13, iron: 3.4, potassium: 363),
  FoodFact('bread', 'White bread', _g, _cooked, _v, 265, 9.0, 49.0, 2.7, 3.2, water: 36.7, calcium: 144, iron: 3.6, potassium: 115),
  FoodFact('pasta', 'Pasta', _g, _cooked, _v, 158, 5.8, 30.9, 1.8, 0.9, water: 62.0, calcium: 7, iron: 1.3, potassium: 44),
  FoodFact('potato', 'Potato', _g, _cooked, _v, 87, 1.9, 20.1, 1.8, 0.1, water: 77.0, vitC: 13.0, calcium: 5, iron: 0.3, potassium: 379),
  FoodFact(
    'sweet_potato',
    'Sweet potato (shakarkandi)',
    _g,
    _cooked,
    _v,
    90,
    2.0,
    20.7,
    3.3,
    0.2,
    water: 75.8,
    vitC: 19.6,
    vitA: 961,
    calcium: 38,
    iron: 0.7,
    potassium: 475,
  ),

  // Dals and beans (cooked, as eaten)
  FoodFact('masoor', 'Masoor dal (lentils)', _p, _cooked, _v, 116, 9.0, 20.1, 7.9, 0.4, water: 69.6, calcium: 19, iron: 3.3, potassium: 369),
  FoodFact('chana', 'Chickpeas (chana)', _p, _cooked, _v, 164, 8.9, 27.4, 7.6, 2.6, water: 60.2, calcium: 49, iron: 2.9, potassium: 291),
  FoodFact('rajma', 'Rajma (kidney beans)', _p, _cooked, _v, 127, 8.7, 22.8, 6.4, 0.5, water: 66.9, calcium: 28, iron: 2.2, potassium: 403),
  FoodFact('moong', 'Moong dal', _p, _cooked, _v, 105, 7.0, 19.2, 7.6, 0.4, water: 72.7, calcium: 27, iron: 1.4, potassium: 266),
  FoodFact('toor', 'Toor dal (pigeon peas)', _p, _cooked, _v, 121, 6.8, 23.7, 6.7, 0.4, water: 68.9, calcium: 42, iron: 1.1, potassium: 384),
  FoodFact('soya', 'Soybeans', _p, _cooked, _v, 173, 16.6, 9.9, 6.0, 9.0, water: 62.6, calcium: 102, iron: 5.1, potassium: 515),

  // Nuts and seeds
  FoodFact('peanuts', 'Peanuts', _n, _raw, _v, 567, 25.8, 16.1, 8.5, 49.2, water: 6.5, calcium: 92, iron: 4.6, potassium: 705),
  FoodFact('almonds', 'Almonds', _n, _raw, _v, 579, 21.2, 21.6, 12.5, 49.9, water: 4.4, calcium: 269, iron: 3.7, potassium: 733),
  FoodFact('walnuts', 'Walnuts', _n, _raw, _v, 654, 15.2, 13.7, 6.7, 65.2, water: 4.1, calcium: 98, iron: 2.9, potassium: 441),
  FoodFact('cashews', 'Cashews', _n, _raw, _v, 553, 18.2, 30.2, 3.3, 43.9, water: 5.2, calcium: 37, iron: 6.7, potassium: 660),
  FoodFact('sunflower', 'Sunflower seeds', _n, _raw, _v, 584, 20.8, 20.0, 8.6, 51.5, water: 4.7, calcium: 78, iron: 5.3, potassium: 645),
  FoodFact('pumpkin_seeds', 'Pumpkin seeds', _n, _raw, _v, 559, 30.2, 10.7, 6.0, 49.1, water: 5.2, calcium: 46, iron: 8.8, potassium: 809),
  FoodFact('chia', 'Chia seeds', _n, _raw, _v, 486, 16.5, 42.1, 34.4, 30.7, water: 5.8, calcium: 631, iron: 7.7, potassium: 407),
  FoodFact('flax', 'Flax seeds', _n, _raw, _v, 534, 18.3, 28.9, 27.3, 42.2, water: 7.0, calcium: 255, iron: 5.7, potassium: 813),

  // Milk and eggs
  FoodFact('milk', 'Milk (whole)', _de, _raw, _d, 61, 3.2, 4.8, 0, 3.3, water: 88.1, calcium: 113, potassium: 132),
  FoodFact('curd', 'Curd / plain yogurt', _de, _raw, _d, 61, 3.5, 4.7, 0, 3.3, water: 88.0, calcium: 121, potassium: 155),
  FoodFact('paneer', 'Paneer', _de, _raw, _d, 265, 18.3, 1.2, 0, 20.8, note: 'Typical paneer. Brands and homemade vary.'),
  FoodFact('cheese', 'Cheddar cheese', _de, _raw, _d, 403, 24.9, 1.3, 0, 33.1, water: 37.5, calcium: 721, iron: 0.7, potassium: 98),
  FoodFact('egg', 'Egg', _de, _cooked, _e, 155, 12.6, 1.1, 0, 10.6, water: 74.6, vitA: 149, calcium: 50, iron: 1.2, potassium: 126),

  // Meat and fish (cooked, no added fat)
  FoodFact('chicken', 'Chicken breast', _mf, _cooked, _m, 165, 31.0, 0, 0, 3.6, water: 65.3, calcium: 15, iron: 1.0, potassium: 256),
  FoodFact('mutton', 'Mutton (goat)', _mf, _cooked, _m, 143, 27.1, 0, 0, 3.0, water: 67.1, calcium: 17, iron: 3.7, potassium: 405),
  FoodFact('salmon', 'Salmon', _mf, _cooked, _m, 206, 22.1, 0, 0, 12.4, water: 64.9, calcium: 15, iron: 0.3, potassium: 384),
  FoodFact('tuna', 'Tuna (canned in water)', _mf, _cooked, _m, 116, 25.5, 0, 0, 0.8, water: 74.0, calcium: 11, iron: 1.4, potassium: 237),
  FoodFact('prawns', 'Prawns (shrimp)', _mf, _cooked, _m, 99, 24.0, 0.2, 0, 0.3, water: 75.9, calcium: 64, iron: 0.5, potassium: 259),

  // Vegetables (raw)
  FoodFact('spinach', 'Spinach (palak)', _ve, _raw, _v, 23, 2.9, 3.6, 2.2, 0.4, water: 91.4, vitC: 28.1, vitA: 469, calcium: 99, iron: 2.7, potassium: 558),
  FoodFact('broccoli', 'Broccoli', _ve, _raw, _v, 34, 2.8, 6.6, 2.6, 0.4, water: 89.3, vitC: 89.2, vitA: 31, calcium: 47, iron: 0.7, potassium: 316),
  FoodFact('carrot', 'Carrot', _ve, _raw, _v, 41, 0.9, 9.6, 2.8, 0.2, water: 88.3, vitC: 5.9, vitA: 835, calcium: 33, iron: 0.3, potassium: 320),
  FoodFact('tomato', 'Tomato', _ve, _raw, _v, 18, 0.9, 3.9, 1.2, 0.2, water: 94.5, vitC: 13.7, vitA: 42, calcium: 10, iron: 0.3, potassium: 237),
  FoodFact('cucumber', 'Cucumber', _ve, _raw, _v, 15, 0.7, 3.6, 0.5, 0.1, water: 95.2, vitC: 2.8, calcium: 16, iron: 0.3, potassium: 147),
  FoodFact('cauliflower', 'Cauliflower', _ve, _raw, _v, 25, 1.9, 5.0, 2.0, 0.3, water: 92.1, vitC: 48.2, calcium: 22, iron: 0.4, potassium: 299),
  FoodFact('cabbage', 'Cabbage', _ve, _raw, _v, 25, 1.3, 5.8, 2.5, 0.1, water: 92.2, vitC: 36.6, calcium: 40, iron: 0.5, potassium: 170),
  FoodFact('okra', 'Okra (bhindi)', _ve, _raw, _v, 33, 1.9, 7.5, 3.2, 0.2, water: 89.6, vitC: 23.0, vitA: 36, calcium: 82, iron: 0.6, potassium: 299),
  FoodFact('capsicum', 'Red capsicum', _ve, _raw, _v, 31, 1.0, 6.0, 2.1, 0.3, water: 92.2, vitC: 127.7, vitA: 157, calcium: 7, iron: 0.4, potassium: 211),
  FoodFact('onion', 'Onion', _ve, _raw, _v, 40, 1.1, 9.3, 1.7, 0.1, water: 89.1, vitC: 7.4, calcium: 23, iron: 0.2, potassium: 146),
  FoodFact('beetroot', 'Beetroot', _ve, _raw, _v, 43, 1.6, 9.6, 2.8, 0.2, water: 87.6, vitC: 4.9, calcium: 16, iron: 0.8, potassium: 325),
  FoodFact('peas', 'Green peas', _ve, _raw, _v, 81, 5.4, 14.5, 5.1, 0.4, water: 78.9, vitC: 40.0, vitA: 38, calcium: 25, iron: 1.5, potassium: 244),
  FoodFact('lauki', 'Bottle gourd (lauki)', _ve, _raw, _v, 14, 0.6, 3.4, 0.5, 0.0, water: 95.4, vitC: 10.1, calcium: 26, iron: 0.2, potassium: 150),
  FoodFact('pumpkin', 'Pumpkin', _ve, _raw, _v, 26, 1.0, 6.5, 0.5, 0.1, water: 91.6, vitC: 9.0, vitA: 426, calcium: 21, iron: 0.8, potassium: 340),
  FoodFact('brinjal', 'Brinjal (baingan)', _ve, _raw, _v, 25, 1.0, 5.9, 3.0, 0.2, water: 92.4, vitC: 2.2, calcium: 9, iron: 0.2, potassium: 229),
  FoodFact('mushroom', 'Mushrooms', _ve, _raw, _v, 22, 3.1, 3.3, 1.0, 0.3, water: 92.4, vitC: 2.1, calcium: 3, iron: 0.5, potassium: 318),

  // Fruits (raw)
  FoodFact('watermelon', 'Watermelon', _fr, _raw, _v, 30, 0.6, 7.6, 0.4, 0.2, water: 91.4, vitC: 8.1, vitA: 28, calcium: 7, iron: 0.2, potassium: 112),
  FoodFact('banana', 'Banana', _fr, _raw, _v, 89, 1.1, 22.8, 2.6, 0.3, water: 74.9, vitC: 8.7, vitA: 3, calcium: 5, iron: 0.3, potassium: 358),
  FoodFact('apple', 'Apple', _fr, _raw, _v, 52, 0.3, 13.8, 2.4, 0.2, water: 85.6, vitC: 4.6, vitA: 3, calcium: 6, iron: 0.1, potassium: 107),
  FoodFact('orange', 'Orange', _fr, _raw, _v, 47, 0.9, 11.8, 2.4, 0.1, water: 86.8, vitC: 53.2, vitA: 11, calcium: 40, iron: 0.1, potassium: 181),
  FoodFact('mango', 'Mango', _fr, _raw, _v, 60, 0.8, 15.0, 1.6, 0.4, water: 83.5, vitC: 36.4, vitA: 54, calcium: 11, iron: 0.2, potassium: 168),
  FoodFact('papaya', 'Papaya', _fr, _raw, _v, 43, 0.5, 10.8, 1.7, 0.3, water: 88.1, vitC: 60.9, vitA: 47, calcium: 20, iron: 0.3, potassium: 182),
  FoodFact('guava', 'Guava', _fr, _raw, _v, 68, 2.6, 14.3, 5.4, 1.0, water: 80.8, vitC: 228.3, vitA: 31, calcium: 18, iron: 0.3, potassium: 417),
  FoodFact('grapes', 'Grapes', _fr, _raw, _v, 69, 0.7, 18.1, 0.9, 0.2, water: 80.5, vitC: 3.2, vitA: 3, calcium: 10, iron: 0.4, potassium: 191),
  FoodFact('pomegranate', 'Pomegranate', _fr, _raw, _v, 83, 1.7, 18.7, 4.0, 1.2, water: 77.9, vitC: 10.2, calcium: 10, iron: 0.3, potassium: 236),
  FoodFact('pineapple', 'Pineapple', _fr, _raw, _v, 50, 0.5, 13.1, 1.4, 0.1, water: 86.0, vitC: 47.8, vitA: 3, calcium: 13, iron: 0.3, potassium: 109),
  FoodFact('kiwi', 'Kiwi', _fr, _raw, _v, 61, 1.1, 14.7, 3.0, 0.5, water: 83.1, vitC: 92.7, vitA: 4, calcium: 34, iron: 0.3, potassium: 312),
  FoodFact('lemon', 'Lemon (no peel)', _fr, _raw, _v, 29, 1.1, 9.3, 2.8, 0.3, water: 89.0, vitC: 53.0, calcium: 26, iron: 0.6, potassium: 138),
  FoodFact('coconut_water', 'Coconut water', _fr, _raw, _v, 19, 0.7, 3.7, 1.1, 0.2, water: 95.0, vitC: 2.4, calcium: 24, iron: 0.3, potassium: 250),
  FoodFact('dates', 'Dates (Medjool)', _fr, _dry, _v, 277, 1.8, 75.0, 6.7, 0.2, water: 21.4, calcium: 64, iron: 0.9, potassium: 696),
  FoodFact('raisins', 'Raisins', _fr, _dry, _v, 299, 3.1, 79.2, 3.7, 0.5, water: 15.4, calcium: 50, iron: 1.9, potassium: 749),

  // Sugars and fats
  FoodFact('sugar', 'White sugar', _sf, _dry, _v, 387, 0, 100.0, 0, 0, water: 0.1),
  FoodFact('jaggery', 'Jaggery (gur)', _sf, _dry, _v, 383, 0.4, 97.3, 0, 0.1, note: 'Typical jaggery. Varies by type.'),
  FoodFact('honey', 'Honey', _sf, _raw, _d, 304, 0.3, 82.4, 0.2, 0, water: 17.1),
  FoodFact('milk_choc', 'Milk chocolate', _sf, _dry, _d, 535, 7.7, 59.4, 3.4, 29.7, calcium: 189, iron: 2.3, potassium: 372),
  FoodFact('dark_choc', 'Dark chocolate (70–85%)', _sf, _dry, _v, 598, 7.8, 45.9, 10.9, 42.6, calcium: 73, iron: 11.9, potassium: 715),
  FoodFact('ghee', 'Ghee', _sf, _raw, _d, 876, 0.3, 0, 0, 99.5, water: 0.1),
  FoodFact('oil', 'Cooking oil', _sf, _raw, _v, 884, 0, 0, 0, 100.0, water: 0),
];
