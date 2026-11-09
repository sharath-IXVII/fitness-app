import 'dart:math' as math;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/clubs/challenge_screens.dart' show countdown;
import 'package:fitalarm/features/clubs/clubs_backend.dart';
import 'package:fitalarm/features/clubs/domain/club.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:fitalarm/features/friends/friends_backend.dart' show FriendsFailure;
import 'package:flutter_test/flutter_test.dart';

/// A straight line north from Bengaluru: 0.001° of latitude ≈ 111 m.
GpsFix at(int step, {double every = 0.0005, int secs = 10, double acc = 8}) =>
    GpsFix(12.97 + step * every, 77.59, acc, DateTime(2026, 11, 9, 6).add(Duration(seconds: step * secs)));

void main() {
  test('distance between two points', () {
    expect(distanceBetween((12.97, 77.59), (12.98, 77.59)), closeTo(1112, 5));
  });

  test('the tracker adds up a run and leaves out bad readings and car-speed jumps', () {
    final t = RouteTracker(ActivityKind.run);
    for (var i = 0; i < 20; i++) {
      t.add(at(i)); // ~55 m every 10 s: a jog
    }
    expect(t.meters, closeTo(19 * 55.6, 19 * 55.6 * 0.05));
    final before = t.meters;
    expect(t.add(GpsFix(13.5, 77.59, 8, DateTime(2026, 11, 9, 6, 10))), isFalse); // 50 km away: a glitch
    expect(t.add(GpsFix(12.98, 77.59, 80, DateTime(2026, 11, 9, 6, 10))), isFalse); // poor accuracy
    expect(t.meters, before);
  });

  test('standing still adds nothing', () {
    final t = RouteTracker(ActivityKind.walk);
    for (var i = 0; i < 10; i++) {
      t.add(GpsFix(12.97 + (i.isEven ? 0.00001 : 0), 77.59, 5, DateTime(2026, 1, 1).add(Duration(seconds: i * 5))));
    }
    expect(t.meters, 0);
  });

  group('accuracy with realistic GPS noise', () {
    final kinds = [
      ('walking', ActivityKind.walk, 1.4),
      ('running', ActivityKind.run, 3.0),
      ('cycling', ActivityKind.cycle, 6.0),
    ];
    for (final (name, kind, speed) in kinds) {
      for (final (route, path) in [
        ('a city block', blockLoop(speed: speed, laps: 3)),
        ('a 400 m track', trackLoop(speed, 8)),
      ]) {
        test('$name on $route with the chip speed: within 1.5%', () {
          for (final seed in [1, 2, 3, 4, 5]) {
            for (final sigma in [5.0, 8.0]) {
              final t = RouteTracker(kind);
              for (final f in noisyRoute(path.$1, seed: seed, sigma: sigma, speed: speed)) {
                t.add(f);
              }
              final error = (t.meters - path.$2).abs() / path.$2;
              expect(error, lessThan(0.015), reason: '$name seed $seed: ${t.meters.round()} m of ${path.$2.round()} m');
            }
          }
        });
      }
      test('$name around a block from positions only (no chip speed): within 3%', () {
        final (truth, length) = blockLoop(speed: speed, laps: 3);
        for (final seed in [1, 2, 3]) {
          final t = RouteTracker(kind);
          for (final f in noisyRoute(truth, seed: seed)) {
            t.add(f);
          }
          expect((t.meters - length).abs() / length, lessThan(0.03), reason: '$name seed $seed');
        }
      });
    }

    test('standing still for 10 minutes with noisy GPS adds almost nothing', () {
      for (final chip in [null, 0.0]) {
        final t = RouteTracker(ActivityKind.walk);
        for (final f in noisyRoute(List.filled(600, (12.97, 77.59)), seed: 9, speed: chip)) {
          t.add(f);
        }
        expect(t.meters, lessThan(10));
      }
    });

    test('a car ride is not counted', () {
      final (truth, _) = blockLoop(speed: 12, laps: 1); // 43 km/h
      final t = RouteTracker(ActivityKind.run);
      for (final f in noisyRoute(truth, speed: 12)) {
        t.add(f);
      }
      expect(t.meters, lessThan(50));
    });

    test('the finish time is worked out between readings', () {
      final (truth, _) = blockLoop(speed: 3, laps: 1);
      final t = RouteTracker(ActivityKind.run);
      for (final f in noisyRoute(truth, seed: 3, speed: 3)) {
        t.add(f, target: 1000);
      }
      final secs = t.reachedAt(1000)!.difference(t.firstAt!).inMilliseconds / 1000;
      expect(secs, closeTo(1000 / 3, 1000 / 3 * 0.015)); // 1 km at 3 m/s
    });
  });

  test('countdown text', () {
    expect(countdown(const Duration(days: 2, hours: 3, minutes: 4)), '2 d 3 h');
    expect(countdown(const Duration(hours: 1, minutes: 5)), '1 h 05 min');
    expect(countdown(const Duration(minutes: 4, seconds: 9)), '4 min 09 s');
  });

  test('formatting and XP', () {
    expect(formatDuration(45 * 60000), '45:00');
    expect(formatDuration(3723000), '1:02:03');
    expect(formatPace(45 * 60000, 8000), '5:37 /km');
    expect(formatKm(8000), '8 km');
    expect(formatKm(2500), '2.5 km');
    expect(ActivityKind.run.minMillis(8000), 1152000); // 8 km at 25 km/h
    final c = ClubChallenge(
      id: 'x',
      clubId: 'c',
      title: 't',
      kind: ActivityKind.run,
      distanceM: 8000,
      startsAt: DateTime(2026),
      endsAt: DateTime(2027),
    );
    expect(c.finishXp, 130);
  });

  test('admin creates a challenge; members finish; best time ranks first', () async {
    final b = ClubsBackend(FakeFirebaseFirestore());
    final club = await b.create(uid: 'asha', myName: 'Asha', name: 'Lake Runners', about: '', kind: ClubKind.running);
    await b.createChallenge(
      club.id,
      uid: 'asha',
      title: 'Run 8 km',
      kind: ActivityKind.run,
      distanceM: 8000,
      startsAt: DateTime(2026, 11, 9),
      endsAt: DateTime(2026, 11, 16),
      start: (12.97, 77.59),
      startName: 'Lake gate',
    );
    await expectLater(
      b.createChallenge(
        club.id,
        uid: 'asha',
        title: 'see x.com',
        kind: ActivityKind.run,
        distanceM: 8000,
        startsAt: DateTime(2026, 11, 9),
        endsAt: DateTime(2026, 11, 16),
      ),
      throwsA(isA<FriendsFailure>()),
    );
    final ch = (await b.challenges(club.id).first).single;
    expect(ch.start, (12.97, 77.59));
    expect(ch.startName, 'Lake gate');

    expect(await b.submitResult(ch, uid: 'ravi', myName: 'Ravi', timeMs: 48 * 60000, distanceM: 8010), isTrue);
    expect(await b.submitResult(ch, uid: 'meera', myName: 'Meera', timeMs: 41 * 60000, distanceM: 8003), isTrue);
    expect(await b.submitResult(ch, uid: 'ravi', myName: 'Ravi', timeMs: 50 * 60000, distanceM: 8001), isFalse);
    await expectLater(
      b.submitResult(ch, uid: 'ravi', myName: 'Ravi', timeMs: 5 * 60000, distanceM: 8000),
      throwsA(isA<FriendsFailure>()),
    );
    await expectLater(
      b.submitResult(ch, uid: 'ravi', myName: 'Ravi', timeMs: 40 * 60000, distanceM: 6000),
      throwsA(isA<FriendsFailure>()),
    );
    final board = await b.results(club.id, ch.id).first;
    expect(board.map((r) => r.name), ['Meera', 'Ravi']);
    expect(board.last.timeMs, 48 * 60000);
  });
}

/// Realistic phone GPS: each reading off by a few metres in a random
/// direction (normal noise), reported accuracy around 8 m.
List<GpsFix> noisyRoute(
  List<(double, double)> truth, {
  double sigma = 5,
  int seed = 1,
  int stepSecs = 1,
  double? speed,
  double speedSigma = 0.3,
}) {
  final rnd = math.Random(seed);
  double gauss() => math.sqrt(-2 * math.log(1 - rnd.nextDouble())) * math.cos(2 * math.pi * rnd.nextDouble());
  const mPerDegLat = 111320.0;
  return [
    for (final (i, (lat, lng)) in truth.indexed)
      GpsFix(
        lat + gauss() * sigma / mPerDegLat,
        lng + gauss() * sigma / (mPerDegLat * math.cos(lat * math.pi / 180)),
        8,
        DateTime(2026, 11, 9, 6).add(Duration(seconds: i * stepSecs)),
        // The chip's own speed: close to the truth, never below zero.
        speed: speed == null ? null : math.max(0, speed + gauss() * speedSigma),
        speedAccuracy: speed == null ? null : 0.5,
      ),
  ];
}

/// Laps of a 400 m running track (a circle), sampled every second.
(List<(double, double)>, double) trackLoop(double speed, int laps) {
  const r = 63.66, lat0 = 12.97, lng0 = 77.59, m = 111320.0;
  final mlng = m * math.cos(lat0 * math.pi / 180);
  final total = 2 * math.pi * r * laps;
  return (
    [for (var d = 0.0; d <= total; d += speed) (lat0 + r * math.sin(d / r) / m, lng0 + r * math.cos(d / r) / mlng)],
    total,
  );
}

/// A true path walking around a city block (rectangle) at [speed] m/s,
/// sampled every second; returns the points and the true length.
(List<(double, double)>, double) blockLoop({double speed = 3, int laps = 2, double w = 400, double h = 250}) {
  const lat0 = 12.97, lng0 = 77.59, mPerDegLat = 111320.0;
  final mPerDegLng = mPerDegLat * math.cos(lat0 * math.pi / 180);
  final perimeter = 2 * (w + h);
  final total = perimeter * laps;
  final pts = <(double, double)>[];
  for (var d = 0.0; d <= total; d += speed) {
    var p = d % perimeter;
    double x, y;
    if (p < w) {
      (x, y) = (p, 0);
    } else if ((p -= w) < h) {
      (x, y) = (w, p);
    } else if ((p -= h) < w) {
      (x, y) = (w - p, h);
    } else {
      p -= w;
      (x, y) = (0, h - p);
    }
    pts.add((lat0 + y / mPerDegLat, lng0 + x / mPerDegLng));
  }
  return (pts, total);
}
