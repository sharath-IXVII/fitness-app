import '../../diet/domain/food.dart';

enum ScanConfidence { high, medium, low }

/// One item the scanner found, with its estimate for the visible portion.
/// [factor] lets the user scale the portion before logging.
class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.portion,
    required this.grams,
    required this.macros,
    required this.cls,
    required this.confidence,
    this.factor = 1,
  });

  final String name;
  final String portion;
  final int grams;
  final Macros macros;
  final FoodClass cls;
  final ScanConfidence confidence;
  final double factor;

  Macros get scaled => macros.scale(factor);

  ScannedItem copyWith({String? name, Macros? macros, double? factor}) => ScannedItem(
    name: name ?? this.name,
    portion: portion,
    grams: grams,
    macros: macros ?? this.macros,
    cls: cls,
    confidence: confidence,
    factor: factor ?? this.factor,
  );

  static double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

  factory ScannedItem.fromJson(Map<String, dynamic> j) => ScannedItem(
    name: j['name'] as String? ?? 'Food',
    portion: j['portion'] as String? ?? '',
    grams: _n(j['grams']).round(),
    macros: Macros(
      kcal: _n(j['kcal']),
      protein: _n(j['protein_g']),
      carbs: _n(j['carbs_g']),
      fat: _n(j['fat_g']),
      fiber: _n(j['fiber_g']),
    ),
    cls: switch (j['veg']) {
      'vegan' => FoodClass.vegan,
      'egg' => FoodClass.egg,
      'non_veg' => FoodClass.nonVeg,
      _ => FoodClass.veg,
    },
    confidence: ScanConfidence.values.asNameMap()[j['confidence']] ?? ScanConfidence.low,
  );
}

class ScanResult {
  const ScanResult({required this.isFood, required this.items, this.note = ''});

  final bool isFood;
  final List<ScannedItem> items;
  final String note;

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
    isFood: j['is_food'] as bool? ?? false,
    items: [
      for (final i in (j['items'] as List? ?? const [])) ScannedItem.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
    note: j['note'] as String? ?? '',
  );
}

class ScanFailure implements Exception {
  const ScanFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
