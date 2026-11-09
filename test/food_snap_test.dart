import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:clock/clock.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/diet/domain/food.dart';
import 'package:fitalarm/features/diet/domain/meal_log.dart';
import 'package:fitalarm/features/snaps/domain/food_snap.dart';
import 'package:fitalarm/features/snaps/snaps_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodSnap _snap(String id, DateTime at, {MealType meal = MealType.lunch}) => FoodSnap(
  id: id,
  at: at,
  meal: meal,
  photo: '$id.jpg',
  items: [
    const SnapItem(
      name: 'Rice',
      portion: '1 cup',
      macros: Macros(kcal: 200, protein: 4, carbs: 44, fiber: 0.6),
      box: Rect.fromLTWH(0.4, 0.4, 0.6, 0.6),
    ),
    const SnapItem(name: 'Dal', portion: '1 bowl', macros: Macros(kcal: 150, protein: 9, carbs: 20, fiber: 4)),
  ],
);

void main() {
  test('a snap survives saving and loading, with its boxes and totals', () {
    final s = _snap('a', DateTime(2026, 11, 9, 13));
    final back = FoodSnap.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>)!;
    expect(back.items, hasLength(2));
    expect(back.items.first.box, const Rect.fromLTWH(0.4, 0.4, 0.6, 0.6));
    expect(back.items.last.box, isNull);
    expect(back.total.kcal, 350);
    expect(back.total.fiber, closeTo(4.6, 1e-9));
    expect(back.photo, 'a.jpg');
    expect(FoodSnap.fromJson({'id': 'x'}), isNull);
  });

  test('portion text', () {
    expect(portionText('1 piece (30 g)', 1), '1 piece (30 g)');
    expect(portionText('1 piece (30 g)', 2), '2 × 1 piece (30 g)');
    expect(portionText('1 cup', 1.5), '1.5 × 1 cup');
    expect(portionText('', 2), '2 servings');
  });

  test('snaps are kept for 30 days and today lists them in order', () async {
    final now = DateTime(2026, 11, 9, 21);
    SharedPreferences.setMockInitialValues({
      snapsKey: jsonEncode([
        _snap('old', DateTime(2026, 9, 1)).toJson(),
        _snap('yesterday', DateTime(2026, 11, 8, 20)).toJson(),
        _snap('dinner', DateTime(2026, 11, 9, 20), meal: MealType.dinner).toJson(),
        _snap('breakfast', DateTime(2026, 11, 9, 8), meal: MealType.breakfast).toJson(),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    await withClock(Clock.fixed(now), () async {
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      expect(c.read(snapsProvider).map((s) => s.id), ['dinner', 'breakfast', 'yesterday']);
      expect(c.read(todaySnapsProvider).map((s) => s.id), ['breakfast', 'dinner']);
      await c.read(snapsProvider.notifier).remove('dinner');
      expect(c.read(todaySnapsProvider).map((s) => s.id), ['breakfast']);
    });
  });
}
