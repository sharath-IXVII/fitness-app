import 'dart:math' as math;

import 'package:fitalarm/features/health/domain/pulse_signal.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pretend fingertip signal: a pulse wave at [bpm] on a drifting baseline,
/// with noise, sampled at an uneven ~30 frames a second like a real camera.
List<PulseSample> fake(double bpm, {double seconds = 30, double noise = 0.15, int seed = 1, double motion = 0}) {
  final rnd = math.Random(seed);
  final out = <PulseSample>[];
  var t = 0.0;
  while (t < seconds) {
    final f = bpm / 60;
    final wave = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(4 * math.pi * f * t + 0.8);
    final drift = 8 * math.sin(2 * math.pi * 0.05 * t) + 0.3 * t;
    final jolt = motion > 0 && rnd.nextDouble() < 0.01 ? motion * (rnd.nextDouble() - 0.5) * 20 : 0;
    out.add(PulseSample((t * 1e6).round(), 120 + drift + wave + (rnd.nextDouble() - 0.5) * 2 * noise + jolt));
    t += (1 / 30) * (0.85 + rnd.nextDouble() * 0.3); // 25 to 35 fps
  }
  return out;
}

void main() {
  group('heart rate from a clean fingertip signal', () {
    for (final bpm in [48.0, 60.0, 72.0, 90.0, 110.0, 140.0, 170.0]) {
      test('${bpm.round()} bpm is found within 2', () {
        final e = estimateHeartRate(fake(bpm))!;
        expect((e.bpm - bpm).abs(), lessThanOrEqualTo(2), reason: 'got ${e.bpm}');
        expect(e.confidence, greaterThan(0.5));
      });
    }

    test('noisy signals are still close', () {
      for (var seed = 1; seed <= 8; seed++) {
        final e = estimateHeartRate(fake(78, noise: 0.5, seed: seed))!;
        expect((e.bpm - 78).abs(), lessThanOrEqualTo(3), reason: 'seed $seed got ${e.bpm}');
      }
    });
  });

  group('when there is no real pulse, it says so', () {
    test('random noise gives no confident rate', () {
      final rnd = math.Random(7);
      final noise = [for (var i = 0; i < 900; i++) PulseSample(i * 33333, 100 + rnd.nextDouble() * 4)];
      final e = estimateHeartRate(noise);
      expect(e == null || e.confidence < 0.4, isTrue, reason: 'noise gave ${e?.bpm} at ${e?.confidence}');
    });

    test('a flat line gives nothing', () {
      final flat = [for (var i = 0; i < 900; i++) PulseSample(i * 33333, 100)];
      expect(estimateHeartRate(flat), isNull);
    });

    test('too short a recording gives nothing', () {
      expect(estimateHeartRate(fake(72, seconds: 4)), isNull);
    });
  });

  group('the meter', () {
    PulseMeter feed(List<PulseSample> s, {PulseMeter? into}) {
      final m = into ?? PulseMeter();
      s.forEach(m.add);
      return m;
    }

    test('gives a result after 30 steady seconds', () {
      final m = feed(fake(72, seconds: 31));
      final r = m.result;
      expect(r.status, PulseStatus.done);
      expect((r.bpm! - 72).abs(), lessThanOrEqualTo(2));
      expect(m.progress, 1.0);
    });

    test('is still measuring before that, with a live rate', () {
      final m = feed(fake(72, seconds: 15));
      expect(m.result.status, PulseStatus.measuring);
      expect(m.progress, closeTo(0.5, 0.05));
      expect((m.live!.bpm - 72).abs(), lessThanOrEqualTo(3));
    });

    test('lifting the finger starts again', () {
      final m = feed(fake(72, seconds: 20));
      expect(m.progress, greaterThan(0.6));
      m.add(const PulseSample(21000000, 90, fingerOn: false));
      expect(m.fingerOn, isFalse);
      expect(m.progress, 0);
      expect(m.result.status, PulseStatus.needFinger);
    });

    test('a signal with no rhythm ends as unsteady, never as a made-up number', () {
      final rnd = math.Random(3);
      final m = PulseMeter();
      for (var i = 0; i < 30 * 52; i++) {
        m.add(PulseSample(i * 33333, 100 + rnd.nextDouble() * 3));
      }
      expect(m.result.status, PulseStatus.unsteady);
      expect(m.result.bpm, isNull);
    });
  });
}
