import 'package:fitalarm/core/geohash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('geohash matches known values', () {
    expect(geohash(57.64911, 10.40744, length: 11), 'u4pruydqqvj'); // the reference example
    expect(geohash(12.9716, 77.5946, length: 4), 'tdr1'); // Bengaluru
  });

  test('neighbours include the cell and those around it', () {
    final n = geohashNeighbours(12.9716, 77.5946);
    expect(n, contains('tdr1'));
    expect(n.length, 9);
  });
}
