import 'package:fitalarm/features/diet/domain/food.dart';
import 'package:fitalarm/features/diet/domain/food_db.dart';
import 'package:fitalarm/features/scan/domain/recognition.dart';
import 'package:fitalarm/features/scan/tflite_food_detector.dart' show parseDetections;
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('label map: ids index the list, CRLF and quotes handled', () {
    const csv = 'id,name\r\n0,__background__\r\n1,Chaudin\r\n2,"Fish, chips"\r\n4,Idli\r\n';
    final labels = parseLabels(csv);
    expect(labels, ['__background__', 'Chaudin', 'Fish, chips', '', 'Idli']);
  });

  test('quantized scores are dequantized and normalized', () {
    final p = normalizeScores([0, 128, 64, 64], scale: 1 / 256, zeroPoint: 0);
    expect(p.reduce((a, b) => a + b), closeTo(1, 1e-9));
    expect(p[1], closeTo(0.5, 1e-9));
  });

  test('top guesses skip the background class and tiny scores', () {
    final best = topK([0.9, 0.01, 0.05, 0.03, 0.002], k: 3);
    expect(best.map((e) => e.$1), [2, 3]);
  });

  test('recognised dishes map to foods with nutrition', () {
    for (final (label, id) in [
      ('Idli', 'idli'),
      ('Butter chicken', 'butter_chicken'),
      ('Dal makhani', 'dal_makhani'),
      ('Chana masala', 'chole'),
      ('Neapolitan pizza', 'pizza_slice'),
      ('Kimchi fried rice', 'fried_rice'),
      ('Veggie burger', 'veggie_burger'),
      ('Cheeseburger', 'cheeseburger'),
      ('Hyderabadi biryani', 'veg_biryani'),
      ('White rice', 'rice'),
      ('Samosa', 'samosa'),
    ]) {
      expect(matchFood(label, foodsById)?.id, id, reason: label);
    }
    expect(matchFood('Chaudin', foodsById), isNull);
  });

  test('every mapped food exists in the nutrition list', () {
    // Spot-check that the mapping table only points at real foods.
    for (final label in ['Kulfi', 'Jalebi', 'Kheer', 'Rasgulla', 'Barfi', 'Dhokla', 'Pakora', 'Dahi vada', 'Muesli']) {
      expect(matchFood(label, foodsById), isA<Food>(), reason: label);
    }
  });

  test('mergeViews keeps the plate guess and adds confident side dishes', () {
    final merged = mergeViews([
      [('Biryani', 0.6), ('Pilaf', 0.2)],
      [('Raita', 0.5), ('Salad', 0.1)], // a region: Salad is too unsure to list
      [('Biryani', 0.9)],
    ]);
    expect(merged.map((g) => g.$1), ['Biryani', 'Raita', 'Pilaf']);
    // Where each was seen best: Biryani in region 2, Raita in region 1, Pilaf only in the whole photo.
    expect(merged.map((g) => g.$3), [2, 1, 0]);
    expect(merged.first.$2, closeTo(0.765, 1e-9)); // region score, weighted
    expect(merged[1].$2, closeTo(0.425, 1e-9));
  });

  test('breads and plain rice labels find their foods', () {
    final byId = {for (final f in foods) f.id: f};
    for (final l in ['Chapati', 'flatbread', 'Naan', 'tortilla', 'Phulka']) {
      expect(matchFood(l, byId)?.id, 'roti', reason: l);
    }
    expect(matchFood('boiled rice', byId)?.id, 'rice');
    expect(matchFood('Fish curry', byId)?.id, 'fish_curry'); // exact rules still win
    expect(matchFood('veg biryani', byId)?.id, 'veg_biryani');
  });

  test('detector outputs: boxes, classes and scores in either order', () {
    final boxes = [
      [
        [0.1, 0.2, 0.5, 0.6],
        [0.5, 0.5, 0.9, 0.95],
        [0.0, 0.0, 0.1, 0.1],
      ],
    ];
    final classes = [
      [3.0, 0.0, 7.0],
    ];
    final scores = [
      [0.82, 0.64, 0.1],
    ];
    for (final order in [
      [
        boxes,
        classes,
        scores,
        <double>[3],
      ],
      [
        boxes,
        scores,
        classes,
        <double>[3],
      ],
    ]) {
      final d = parseDetections(order);
      expect(d.map((x) => x.$1), [3, 0]); // the 0.1 one is too unsure
      expect(d.first.$3, const Rect.fromLTRB(0.2, 0.1, 0.6, 0.5));
    }
  });
}
