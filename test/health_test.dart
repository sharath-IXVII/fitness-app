import 'package:fitalarm/features/health/domain/health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resting pulse bands', () {
    expect(ratePulse(72).level, RatingLevel.normal);
    expect(ratePulse(55).level, RatingLevel.low);
    expect(ratePulse(110).level, RatingLevel.watch);
    expect(ratePulse(130).needsCare, isTrue);
  });

  test('readings survive saving and loading; old medical kinds and damaged ones are dropped', () {
    final r = HealthReading.single(kind: ReadingKind.pulse, at: DateTime(2026, 5, 1, 7), value: 66);
    final back = HealthReading.fromJson(r.toJson())!;
    expect(back.value, 66);
    expect(back.rating.level, RatingLevel.normal);
    expect(HealthReading.fromJson({'id': 'x', 'k': 'bloodPressure', 'at': 1, 's': 120, 'd': 80}), isNull);
    expect(HealthReading.fromJson({'id': 'x', 'k': 'glucose', 'at': 1, 'v': 96}), isNull);
    expect(HealthReading.fromJson({'id': 'x', 'k': 'oxygen', 'at': 1, 'v': 98}), isNull);
    expect(HealthReading.fromJson({'id': 'x', 'k': 'pulse', 'at': 1}), isNull);
  });
}
