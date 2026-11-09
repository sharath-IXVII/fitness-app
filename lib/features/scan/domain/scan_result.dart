import 'dart:ui' show Rect;

import '../../diet/domain/food.dart';

enum ScanConfidence { high, medium, low }

/// One food on the plate, with nutrition per serving.
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
    this.box,
  });

  final String name;
  final String portion;
  final int grams;
  final Macros macros;
  final FoodClass cls;
  final ScanConfidence confidence;
  final double factor;

  /// Roughly where it is on the photo (fractions of the square photo).
  final Rect? box;

  Macros get scaled => macros.scale(factor);

  ScannedItem copyWith({String? name, Macros? macros, double? factor}) => ScannedItem(
    name: name ?? this.name,
    portion: portion,
    grams: grams,
    macros: macros ?? this.macros,
    cls: cls,
    confidence: confidence,
    factor: factor ?? this.factor,
    box: box,
  );

  /// A food from the nutrition list, recognised with [score] (0–1).
  factory ScannedItem.fromFood(Food f, double score, {Rect? box}) => ScannedItem(
    name: f.name,
    portion: f.serving,
    grams: 0,
    macros: f.macros,
    cls: f.cls,
    box: box,
    confidence: score >= 0.6
        ? ScanConfidence.high
        : score >= 0.3
        ? ScanConfidence.medium
        : ScanConfidence.low,
  );
}
