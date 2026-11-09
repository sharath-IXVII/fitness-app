import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
    expect(t.meters, closeTo(19 * 55.6, 10));
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
