import 'dart:math' as math;

import 'package:fitalarm/features/health/domain/pulse_signal.dart';
import 'package:flutter_test/flutter_test.dart';

List<PulseSample> fake(double bpm, double noise, int seed, {double seconds = 24, double h2 = 0.35}) {
  final rnd = math.Random(seed);
  final out = <PulseSample>[];
  var t = 0.0;
  while (t < seconds) {
    final f = bpm / 60;
    final wave = math.sin(2 * math.pi * f * t) + h2 * math.sin(4 * math.pi * f * t + 0.8);
    out.add(PulseSample((t * 1e6).round(), 120 + 8 * math.sin(2 * math.pi * 0.05 * t) + 0.3 * t + wave + (rnd.nextDouble() - 0.5) * 2 * noise));
    t += (1 / 30) * (0.8 + rnd.nextDouble() * 0.4);
  }
  return out;
}

void main() {
  test('a wide sweep of rates and noise: never off by more than 3 bpm, always an answer', () {
    var bad = 0, total = 0, none = 0;
    final worst = <String>[];
    for (var bpm = 45; bpm <= 190; bpm += 3) {
      for (final noise in [0.1, 0.4, 0.8]) {
        for (var seed = 1; seed <= 3; seed++) {
          total++;
          final e = estimateHeartRate(fake(bpm.toDouble(), noise, seed));
          if (e == null) {
            none++;
            continue;
          }
          if ((e.bpm - bpm).abs() > 3) {
            bad++;
            if (worst.length < 12) worst.add('$bpm noise $noise seed $seed -> ${e.bpm.toStringAsFixed(1)} conf ${e.confidence.toStringAsFixed(2)}');
          }
        }
      }
    }
    expect(bad, 0, reason: 'off by more than 3 of $total:\n${worst.join('\n')}');
    expect(none, 0);
  });
}
