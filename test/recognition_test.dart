import 'package:fitalarm/features/diet/domain/food.dart';
import 'package:fitalarm/features/diet/domain/food_db.dart';
import 'package:fitalarm/features/scan/domain/recognition.dart';
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
}
