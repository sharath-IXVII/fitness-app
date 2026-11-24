import 'package:fitalarm/features/activity/domain/activity_session.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('good GPS: the GPS distance is used', () {
    expect(fusedDistance(kind: ActivityKind.walk, gpsMeters: 820, steps: 1000, strideM: 0.7), 820);
  });

  test('no GPS (indoors, treadmill): steps times stride give the distance', () {
    expect(fusedDistance(kind: ActivityKind.walk, gpsMeters: 0, steps: 1000, strideM: 0.7), closeTo(700, 0.01));
  });

  test('weak GPS that missed part of the walk: steps fill the gap', () {
    expect(fusedDistance(kind: ActivityKind.walk, gpsMeters: 300, steps: 1000, strideM: 0.7), closeTo(700, 0.01));
  });

  test('running strides are longer than walking ones', () {
    expect(
      fusedDistance(kind: ActivityKind.run, gpsMeters: 0, steps: 1000, strideM: 0.7),
      closeTo(1000 * 0.7 * runStrideFactor, 0.01),
    );
  });

  test('rides use GPS only: pedalling is not steps', () {
    expect(fusedDistance(kind: ActivityKind.cycle, gpsMeters: 5000, steps: 3000, strideM: 0.7), 5000);
    expect(fusedDistance(kind: ActivityKind.cycle, gpsMeters: 0, steps: 3000, strideM: 0.7), 0);
  });

  test('steps are saved with a walk and read back; old saves without steps still load', () {
    final s = ActivitySession(
      id: 'a',
      kind: ActivityKind.walk,
      startedAt: DateTime(2026, 11, 24, 7),
      movingMs: 600000,
      distanceM: 900,
      steps: 1234,
    );
    expect(ActivitySession.fromJson(s.toJson())!.steps, 1234);
    final old = s.toJson()..remove('st');
    expect(ActivitySession.fromJson(old)!.steps, 0);
  });
}
