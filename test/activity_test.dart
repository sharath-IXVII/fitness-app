import 'dart:convert';
import 'dart:math' as math;

import 'package:fitalarm/features/activity/domain/activity_session.dart';
import 'package:fitalarm/features/activity/domain/skip_counter.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skip counter: two skips a second with sensor noise, counted exactly', () {
    final rnd = math.Random(4);
    final c = SkipCounter();
    final t0 = DateTime(2026, 11, 9, 7);
    // 60 skips over 30 s, sampled at 50 Hz: a landing spike of ~15 m/s² every 500 ms.
    for (var ms = 0; ms < 30000; ms += 20) {
      final phase = ms % 500;
      final spike = phase < 60 ? 15.0 * math.sin(phase / 60 * math.pi) : 0.0;
      final noise = (rnd.nextDouble() - 0.5) * 2.5;
      c.add(spike + noise, noise, noise, t0.add(Duration(milliseconds: ms)));
    }
    expect(c.count, 60);
  });

  test('skip counter: walking and handling the phone are not counted', () {
    final c = SkipCounter();
    final t0 = DateTime(2026);
    for (var ms = 0; ms < 20000; ms += 20) {
      final walk = 3.5 * math.sin(ms / 1000 * 2 * math.pi); // gentle sway
      c.add(walk, 1, 1, t0.add(Duration(milliseconds: ms)));
    }
    expect(c.count, 0);
  });

  test('an activity keeps its numbers and gets a friendly title', () {
    final s = ActivitySession(
      id: 'a',
      kind: ActivityKind.run,
      startedAt: DateTime(2026, 11, 9, 6, 30),
      movingMs: 30 * 60000,
      distanceM: 5000,
      route: const [(12.97, 77.59), (12.98, 77.6)],
      splitsMs: const [360000, 720000],
    );
    final back = ActivitySession.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>)!;
    expect(back.title, 'Morning run');
    expect(back.distanceM, 5000);
    expect(back.avgKmh, 10);
    expect(back.kcal, 300);
    expect(back.route.last, (12.98, 77.6));
    expect(ActivitySession.fromJson({'id': 'x'}), isNull);
  });
}
