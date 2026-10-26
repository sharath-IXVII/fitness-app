import 'package:fitalarm/features/diet/domain/food.dart';
import 'package:fitalarm/features/health/domain/food_facts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every food has a unique id and a name', () {
    final ids = foodFacts.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final f in foodFacts) {
      expect(f.name.trim(), isNotEmpty);
    }
  });

  test('numbers are possible: parts never add up to more than 100 g, fibre is part of carbs', () {
    for (final f in foodFacts) {
      final parts = f.protein + f.carbs + f.fat + (f.water ?? 0);
      expect(parts, lessThanOrEqualTo(100.5), reason: '${f.id}: protein+carbs+fat+water = $parts g');
      expect(f.fibre, lessThanOrEqualTo(f.carbs), reason: '${f.id}: fibre is counted inside carbs');
      for (final v in [f.kcal, f.protein, f.carbs, f.fibre, f.fat]) {
        expect(v, greaterThanOrEqualTo(0));
      }
      for (final v in [f.vitC, f.vitA, f.calcium, f.iron, f.potassium]) {
        if (v != null) expect(v, greaterThanOrEqualTo(0));
      }
    }
  });

  test('calories match protein, carbs and fat (4-4-9), which catches a mistyped number', () {
    for (final f in foodFacts) {
      final expected = 4 * f.protein + 4 * f.carbs + 9 * f.fat;
      final tolerance = expected * 0.14 > 25 ? expected * 0.14 : 25.0;
      expect(
        (f.kcal - expected).abs(),
        lessThanOrEqualTo(tolerance),
        reason: '${f.id}: ${f.kcal} kcal listed but the macros give about ${expected.round()}',
      );
    }
  });

  test('foods that are dry or raw are labelled, so cooked and dry are not mixed up', () {
    expect(foodFacts.firstWhere((f) => f.id == 'poha').state, FactState.dry);
    expect(foodFacts.firstWhere((f) => f.id == 'rice').state, FactState.cooked);
    expect(foodFacts.firstWhere((f) => f.id == 'poha').label, 'Poha (rice flakes) (dry)');
  });

  group('rankings', () {
    FoodFact top(FactNutrient n) => rankFoods(n).first;

    test('known leaders', () {
      expect(top(FactNutrient.vitC).id, 'guava');
      expect(top(FactNutrient.fibre).id, 'chia');
      expect(top(FactNutrient.iron).id, 'dark_choc');
      expect(top(FactNutrient.calcium).id, 'cheese');
      expect(top(FactNutrient.protein).id, 'chicken');
      expect(top(FactNutrient.carbs).id, 'sugar');
      expect(top(FactNutrient.fat).id, 'oil');
      expect(top(FactNutrient.vitA).id, 'sweet_potato');
    });

    test('most watery foods are vegetables and fruit, watermelon beats sunflower seeds', () {
      final water = rankFoods(FactNutrient.water).take(15).map((f) => f.id).toList();
      expect(water.take(3), containsAll(['lauki', 'cucumber', 'coconut_water']));
      expect(water, contains('watermelon'));
      final w = foodFacts.firstWhere((f) => f.id == 'watermelon').water!;
      final s = foodFacts.firstWhere((f) => f.id == 'sunflower').water!;
      expect(w, greaterThan(s * 10));
    });

    test('sorted from richest down, and only foods with a value are listed', () {
      for (final n in FactNutrient.values) {
        final list = rankFoods(n);
        for (var i = 1; i < list.length; i++) {
          expect(n.of(list[i - 1])!, greaterThanOrEqualTo(n.of(list[i])!));
        }
        expect(list, isNotEmpty);
      }
      expect(rankFoods(FactNutrient.vitC).every((f) => f.vitC != null), isTrue);
    });

    test('a diet filter keeps only foods that fit', () {
      final veg = rankFoods(FactNutrient.protein, fits: (f) => f.cls == FoodClass.vegan || f.cls == FoodClass.veg);
      expect(veg.any((f) => f.id == 'chicken' || f.id == 'egg'), isFalse);
      expect(veg.any((f) => f.id == 'paneer'), isTrue);
      expect(veg.first.id, 'pumpkin_seeds');
    });
  });

  test('bands: simple, stated cut-offs', () {
    expect(FactNutrient.protein.band(25), 'Very rich');
    expect(FactNutrient.protein.band(12), 'Rich');
    expect(FactNutrient.protein.band(3), isNull);
    expect(FactNutrient.carbs.band(77), 'High');
    expect(FactNutrient.carbs.band(20), 'Medium');
    expect(FactNutrient.carbs.band(4), 'Low');
    expect(FactNutrient.fibre.band(7), 'High');
    expect(FactNutrient.fibre.band(3.5), 'Source');
    expect(FactNutrient.vitC.band(228), 'High');
    expect(FactNutrient.vitC.band(14), 'Source');
    expect(FactNutrient.vitC.band(2), isNull);
    expect(FactNutrient.water.band(95), isNull);
  });
}
