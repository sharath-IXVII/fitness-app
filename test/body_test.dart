import 'package:fitalarm/features/health/domain/body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BMI is weight over height squared', () {
    expect(bmi(70, 175), closeTo(22.86, 0.01));
    expect(bmi(64, 162), closeTo(24.39, 0.01));
    expect(bmi(50, 160), closeTo(19.53, 0.01));
  });

  test('bands use the Asian-adjusted cut-offs, and the edges fall the right way', () {
    BmiBand? b(double v) => rateBmi(v, age: 30).band;
    expect(b(18.4), BmiBand.under);
    expect(b(18.5), BmiBand.healthy);
    expect(b(22.9), BmiBand.healthy);
    expect(b(23.0), BmiBand.over);
    expect(b(24.9), BmiBand.over);
    expect(b(25.0), BmiBand.obese);
    expect(b(32), BmiBand.obese);
  });

  test('teenagers are not rated with adult ranges', () {
    final r = rateBmi(21, age: 15);
    expect(r.band, isNull);
    expect(r.advice, contains('adults'));
  });

  test('the healthy weight range matches the healthy BMI at that height', () {
    final r = healthyWeightRange(170);
    expect(r.min, closeTo(53.5, 0.1));
    expect(r.max, closeTo(66.2, 0.1));
    expect(rateBmi(bmi(r.min, 170), age: 30).band, BmiBand.healthy);
    expect(rateBmi(bmi(r.max, 170), age: 30).band, BmiBand.healthy);
  });
}
