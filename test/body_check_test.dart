import 'package:fitalarm/features/health/domain/body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthy weight for 174 cm (Asian cut-offs)', () {
    final r = healthyWeightRange(174);
    expect(r.min.round(), 56);
    expect(r.max.round(), 69);
  });

  test('U.S. Navy body fat estimate', () {
    // Man, 178 cm, waist 85, neck 38: about 16.4 % (worked by hand).
    expect(navyBodyFat(female: false, heightCm: 178, waistCm: 85, neckCm: 38), closeTo(16.4, 0.2));
    // Woman, 162 cm, waist 72, neck 32, hips 96: about 27–29 %.
    expect(navyBodyFat(female: true, heightCm: 162, waistCm: 72, neckCm: 32, hipCm: 96), closeTo(28, 2));
    expect(navyBodyFat(female: true, heightCm: 162, waistCm: 72, neckCm: 32), isNull); // hips needed
    expect(navyBodyFat(female: false, heightCm: 178, waistCm: 30, neckCm: 40), isNull); // impossible
  });

  test('bands and waist to height', () {
    expect(bodyFatBand(12, female: false), 'Athletic');
    expect(bodyFatBand(28, female: true), 'Average');
    expect(bodyFatBand(35, female: true), 'Above average');
    expect(waistToHeight(80, 170), lessThan(0.5));
  });
}
