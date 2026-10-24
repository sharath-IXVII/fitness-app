import 'dart:math' as math;

import 'package:fitalarm/features/steps/domain/step_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates [seconds] of walking at [hz] steps per second, sampled at 50 Hz.
int walk(StepDetector d, double seconds, double hz, {double amp = 3, double startMs = 0}) {
  var steps = 0;
  for (var i = 0; i < seconds * 50; i++) {
    final t = i * 20.0;
    final a = 9.81 + amp * math.sin(2 * math.pi * hz * t / 1000);
    steps += d.onAccel((startMs + t).round(), 0, 0, a);
  }
  return steps;
}

void main() {
  test('walking at 2 steps a second is counted, warm-up included', () {
    final d = StepDetector();
    final n = walk(d, 20, 2);
    expect(n, inInclusiveRange(36, 42)); // 40 real steps
  });

  test('lying still counts nothing', () {
    final d = StepDetector();
    var n = 0;
    final r = math.Random(1);
    for (var i = 0; i < 2000; i++) {
      n += d.onAccel(i * 20, 0.05 * r.nextDouble(), 0.05 * r.nextDouble(), 9.81 + 0.05 * r.nextDouble());
    }
    expect(n, 0);
  });

  test('a couple of isolated bumps are not walking', () {
    final d = StepDetector();
    var n = 0;
    for (var i = 0; i < 400; i++) {
      final bump = (i == 50 || i == 250) ? 6.0 : 0.0;
      n += d.onAccel(i * 20, 0, 0, 9.81 + bump);
    }
    expect(n, 0);
  });

  test('violent rotation (shaking the phone) is rejected by the gyroscope', () {
    final d = StepDetector();
    d.onGyro(9, 0, 0);
    expect(walk(d, 10, 2), 0);
  });

  test('works whichever way the phone is held', () {
    final d = StepDetector();
    var n = 0;
    for (var i = 0; i < 1000; i++) {
      final a = 9.81 + 3 * math.sin(2 * math.pi * 1.8 * i * 20 / 1000);
      n += d.onAccel(i * 20, a * 0.8, a * 0.6, 0); // gravity mostly sideways
    }
    expect(n, inInclusiveRange(28, 38)); // ~36 real steps
  });
}
