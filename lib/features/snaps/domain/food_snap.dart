import 'dart:ui' show Rect;

import '../../diet/domain/food.dart';
import '../../diet/domain/meal_log.dart';

/// One food in a snap, with the amount eaten (portion × servings already applied).
class SnapItem {
  const SnapItem({required this.name, required this.portion, required this.macros, this.box});

  final String name;

  /// What was eaten, e.g. "1 piece (30 g)" or "1.5 × 1 cup (200 g)".
  final String portion;
  final Macros macros;

  /// Roughly where it is on the photo (fractions of the square photo).
  final Rect? box;

  Map<String, dynamic> toJson() => {
    'n': name,
    'p': portion,
    'm': macros.toJson(),
    if (box case final b?) 'b': [b.left, b.top, b.width, b.height],
  };

  static SnapItem fromJson(Map<String, dynamic> j) {
    final b = (j['b'] as List<dynamic>?)?.cast<num>();
    return SnapItem(
      name: j['n'] as String,
      portion: j['p'] as String? ?? '',
      macros: Macros.fromJson(j['m'] as Map<String, dynamic>),
      box: b == null || b.length != 4
          ? null
          : Rect.fromLTWH(b[0].toDouble(), b[1].toDouble(), b[2].toDouble(), b[3].toDouble()),
    );
  }
}

/// A food snap: the plate photo with what was on it. Snaps are kept on this
/// phone only; the photo is a file in the app's own storage.
class FoodSnap {
  const FoodSnap({required this.id, required this.at, required this.meal, required this.items, this.photo});

  final String id;
  final DateTime at;
  final MealType meal;
  final List<SnapItem> items;

  /// The photo's file name in [PhotoStore], or null without a photo.
  final String? photo;

  Macros get total => items.fold(const Macros(), (m, i) => m + i.macros);

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'meal': meal.name,
    'items': [for (final i in items) i.toJson()],
    if (photo != null) 'photo': photo,
  };

  /// Null for a damaged record.
  static FoodSnap? fromJson(Map<String, dynamic> j) {
    try {
      return FoodSnap(
        id: j['id'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        meal: MealType.values.asNameMap()[j['meal']] ?? MealType.lunch,
        items: [for (final i in j['items'] as List<dynamic>) SnapItem.fromJson(i as Map<String, dynamic>)],
        photo: j['photo'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// "1 piece (30 g)" for one serving, "1.5 × 1 piece (30 g)" otherwise.
String portionText(String serving, double servings) {
  if ((servings - 1).abs() < 0.01) return serving;
  final n = servings == servings.roundToDouble() ? servings.toStringAsFixed(0) : servings.toStringAsFixed(1);
  return serving.isEmpty ? '$n servings' : '$n × $serving';
}
