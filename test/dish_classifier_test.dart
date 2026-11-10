import 'dart:ui';

import 'package:fitalarm/features/scan/tflite_dish_classifier.dart';
import 'package:fitalarm/features/scan/tflite_food_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('model outputs become probabilities', () {
    expect(toProbabilities([0.7, 0.2, 0.1]), [0.7, 0.2, 0.1]); // already probabilities
    final q = toProbabilities([200, 50, 5], scale: 1 / 255); // quantised
    expect(q.reduce((a, b) => a + b), closeTo(1, 1e-9));
    expect(q.first, greaterThan(0.75));
    final logits = toProbabilities([2.0, -1.0, 0.5]); // raw scores
    expect(logits.reduce((a, b) => a + b), closeTo(1, 1e-9));
    expect(logits.first, greaterThan(logits.last));
  });

  test('the same dish found twice is kept once', () {
    final kept = keepDistinct([
      (0, 0.9, const Rect.fromLTRB(0, 0, 0.5, 0.5)),
      (0, 0.8, const Rect.fromLTRB(0.02, 0.02, 0.5, 0.5)),
      (0, 0.7, const Rect.fromLTRB(0.6, 0.6, 1, 1)),
    ]);
    expect(kept.map((k) => k.$2), [0.9, 0.7]);
  });

  test('each box gets its best dish; the others are low-scored alternatives', () {
    const a = Rect.fromLTRB(0, 0, 0.5, 0.5), b = Rect.fromLTRB(0.5, 0.5, 1, 1);
    final out = nameBoxes(
      [a, b],
      [
        [('dal', 0.6), ('sambar', 0.3)],
        [('roti', 0.9), ('paratha', 0.05)],
      ],
    );
    expect(out.take(2).map((g) => g.$1), ['roti', 'dal']);
    expect(out[2].$1, 'sambar');
    expect(out[2].$2, closeTo(0.03, 1e-9));
    expect(out[2].$3, a);
  });

  test('a detector that only finds food needs the dish model', () {
    expect(TfliteFoodDetector.findsOnlyFood(['food']), isTrue);
    expect(TfliteFoodDetector.findsOnlyFood(['', 'food']), isTrue);
    expect(TfliteFoodDetector.findsOnlyFood(['roti', 'dal']), isFalse);
  });
}
