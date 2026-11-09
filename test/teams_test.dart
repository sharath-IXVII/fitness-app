import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/friends/friends_backend.dart' show FriendsFailure;
import 'package:fitalarm/features/teams/domain/team.dart';
import 'package:fitalarm/features/teams/teams_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 9, 20);
  Map<String, Set<String>> days(List<Set<String>> oldestFirst) => {
    for (final (i, d) in oldestFirst.indexed)
      teamDayKey(DateTime(today.year, today.month, today.day - (oldestFirst.length - 1 - i))): d,
  };

  test('a team day counts only when everyone is done', () {
    const team = ['asha', 'ravi'];
    expect(
      teamStreak(
        team,
        days([
          {'asha', 'ravi'},
          {'asha', 'ravi'},
          {'asha', 'ravi'},
        ]),
        today,
      ),
      3,
    );
    // Ravi missed yesterday: the streak is gone for both.
    expect(
      teamStreak(
        team,
        days([
          {'asha', 'ravi'},
          {'asha'},
          {'asha', 'ravi'},
        ]),
        today,
      ),
      1,
    );
    // Today isn't finished yet: the streak to yesterday still stands.
    expect(
      teamStreak(
        team,
        days([
          {'asha', 'ravi'},
          {'asha', 'ravi'},
          {'asha'},
        ]),
        today,
      ),
      2,
    );
    // One person isn't a team.
    expect(
      teamStreak(
        ['asha'],
        days([
          {'asha'},
        ]),
        today,
      ),
      0,
    );
  });

  test('badges by team streak', () {
    expect(teamBadge(6), isNull);
    expect(teamBadge(7), 'Bronze Squad');
    expect(teamBadge(45), 'Gold Squad');
  });

  test('create, join by code, check in, leave', () async {
    final b = TeamsBackend(FakeFirebaseFirestore());
    final t = await b.create('asha', 'Asha', 'Winter Warriors');
    expect(t.code, hasLength(6));
    await b.join('ravi', 'Ravi', t.code!.toLowerCase());
    final mine = (await b.myTeams('ravi').first).single;
    expect(mine.members, ['asha', 'ravi']);
    expect(mine.names['ravi'], 'Ravi');
    await expectLater(b.join('ravi', 'Ravi', 'ZZZZZZ'), throwsA(isA<FriendsFailure>()));
    await b.checkIn(t.id, 'asha', today);
    await b.checkIn(t.id, 'ravi', today);
    final d = await b.days(t.id).first;
    expect(d[teamDayKey(today)], {'asha', 'ravi'});
    await b.leave(t.id, 'ravi');
    expect(await b.myTeams('ravi').first, isEmpty);
  });

  test('a team is full at 6', () async {
    final b = TeamsBackend(FakeFirebaseFirestore());
    final t = await b.create('u0', 'U0', 'Six Pack');
    for (var i = 1; i < 6; i++) {
      await b.join('u$i', 'U$i', t.code!);
    }
    await expectLater(b.join('u6', 'U6', t.code!), throwsA(isA<FriendsFailure>()));
  });
}
