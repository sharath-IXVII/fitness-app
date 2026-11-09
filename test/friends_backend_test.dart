import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/friends/domain/friends.dart';
import 'package:fitalarm/features/friends/friends_backend.dart';
import 'package:fitalarm/features/workout/domain/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

const _asha = PublicProfile(uid: 'asha', name: 'Asha', title: 'Master of Winter 2026', titleTier: 2, xp: 900);
const _ravi = PublicProfile(uid: 'ravi', name: 'Ravi', xp: 400);
const _meena = PublicProfile(uid: 'meena', name: 'Meena');

void main() {
  late FakeFirebaseFirestore db;
  late FriendsBackend b;

  setUp(() async {
    db = FakeFirebaseFirestore();
    b = FriendsBackend(db);
    for (final p in [_asha, _ravi, _meena]) {
      await b.syncProfile(p);
    }
  });

  test('challenge by code: share, join, both do it, become friends', () async {
    final c = await b.createChallenge(from: _asha, exercise: Exercise.pushUp, reps: 10, arcLabel: 'Winter Arc 2026');
    expect(c.code, hasLength(6));
    expect(c.status, ChallengeStatus.open);
    final msg = c.inviteMessage('https://play.example/app');
    expect(msg, contains("I'm challenging you to 10 push-ups for the Winter Arc 2026"));
    expect(msg, contains('Asha, Master of Winter 2026'));
    expect(msg, contains(c.code));

    // Ravi types the code, in lower case with a space.
    final typed = '${c.code.substring(0, 3).toLowerCase()} ${c.code.substring(3)}';
    final found = await b.findByCode(typed, me: 'ravi');
    expect(found.fromTitle, 'Master of Winter 2026');
    final joined = await b.accept(found, _ravi);
    expect(joined.toUid, 'ravi');

    // Nobody else can take it now.
    await expectLater(b.findByCode(c.code, me: 'meena'), throwsA(isA<FriendsFailure>()));

    var after = await b.markDone(joined, 'ravi');
    expect(after.status, ChallengeStatus.accepted);
    expect(await b.areFriends('asha', 'ravi'), isFalse);
    after = await b.markDone(joined, 'asha');
    expect(after.status, ChallengeStatus.done);
    expect(await b.areFriends('asha', 'ravi'), isTrue);
    expect(await b.areFriends('ravi', 'asha'), isTrue);

    final friends = await b.friends('ravi').first;
    expect(friends.single.title, 'Master of Winter 2026');

    final list = await b.challenges('asha').first;
    expect(list.single.status, ChallengeStatus.done);
  });

  test('an open challenge nobody joins expires after 48 hours and disappears', () async {
    final start = DateTime(2026, 3, 1, 9);
    final c = await withClock(Clock.fixed(start), () {
      return b.createChallenge(from: _asha, exercise: Exercise.pushUp, reps: 10, arcLabel: 'Winter Arc 2026');
    });

    // A day later it's still there and can be joined.
    await withClock(Clock.fixed(start.add(const Duration(hours: 24))), () async {
      expect((await b.challenges('asha').first).single.id, c.id);
      expect((await b.findByCode(c.code, me: 'ravi')).id, c.id);
    });

    // After 48 hours it's gone from the list and the code no longer works.
    await withClock(Clock.fixed(start.add(const Duration(hours: 49))), () async {
      expect(await b.challenges('asha').first, isEmpty);
      await expectLater(b.findByCode(c.code, me: 'ravi'), throwsA(isA<FriendsFailure>()));
    });

    // The sender's copy is cleaned up for good.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await db.collection('challenges').get()).docs, isEmpty);
  });

  test('a challenge someone has taken never expires', () async {
    final start = DateTime(2026, 3, 1, 9);
    final c = await withClock(Clock.fixed(start), () {
      return b.createChallenge(from: _asha, exercise: Exercise.squat, reps: 15, arcLabel: 'Winter Arc 2026');
    });
    await withClock(Clock.fixed(start.add(const Duration(hours: 5))), () => b.accept(c, _ravi));
    await withClock(Clock.fixed(start.add(const Duration(days: 10))), () async {
      expect((await b.challenges('ravi').first).single.status, ChallengeStatus.accepted);
    });
  });

  test('bad codes and your own code give friendly errors', () async {
    final c = await b.createChallenge(from: _asha, exercise: Exercise.squat, reps: 15, arcLabel: 'Winter Arc 2026');
    await expectLater(b.findByCode('ABC', me: 'ravi'), throwsA(isA<FriendsFailure>()));
    await expectLater(b.findByCode('ZZZZZZ', me: 'ravi'), throwsA(isA<FriendsFailure>()));
    await expectLater(b.findByCode(c.code, me: 'asha'), throwsA(isA<FriendsFailure>()));
  });

  test('friends can challenge each other directly; blocking stops it', () async {
    final c = await b.createChallenge(
      from: _asha,
      exercise: Exercise.plank,
      reps: 30,
      arcLabel: 'Winter Arc 2026',
      to: _ravi,
    );
    expect(c.status, ChallengeStatus.accepted);
    expect(c.task, '30s plank');
    final inbox = await b.challenges('ravi').first;
    expect(inbox.single.fromName, 'Asha');

    await b.block('ravi', 'asha');
    await expectLater(
      b.createChallenge(from: _asha, exercise: Exercise.squat, reps: 5, arcLabel: 'x', to: _ravi),
      throwsA(isA<FriendsFailure>()),
    );
    await b.report('ravi', 'asha', 'spam');
    expect((await db.collection('reports').get()).docs, hasLength(1));
  });

  test('removing a friend removes both sides', () async {
    final c = await b.createChallenge(from: _asha, exercise: Exercise.squat, reps: 5, arcLabel: 'x');
    final j = await b.accept(c, _meena);
    await b.markDone(j, 'asha');
    await b.markDone(j, 'meena');
    expect(await b.areFriends('meena', 'asha'), isTrue);
    await b.removeFriend('meena', 'asha');
    expect(await b.areFriends('meena', 'asha'), isFalse);
    expect(await b.areFriends('asha', 'meena'), isFalse);
  });

  test('codes are easy to read', () {
    for (var i = 0; i < 200; i++) {
      expect(newChallengeCode(), matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
    }
    expect(normalizeCode(' k7q-2mx '), 'K7Q2MX');
  });

  test('deleting an account removes the profile and both sides of friendships', () async {
    final c = await b.createChallenge(from: _asha, exercise: Exercise.squat, reps: 5, arcLabel: 'x');
    final j = await b.accept(c, _ravi);
    await b.markDone(j, 'asha');
    await b.markDone(j, 'ravi');
    await b.deleteMe('ravi');
    expect(await b.profile('ravi'), isNull);
    expect(await b.areFriends('asha', 'ravi'), isFalse);
  });

  group('friend requests (no XP)', () {
    test('everyone gets one stable code, and it can be looked up', () async {
      final code = await b.myFriendCode('asha');
      expect(code, hasLength(6));
      expect(await b.myFriendCode('asha'), code);
      expect(await b.myFriendCode('ravi'), isNot(code));
      final found = await b.findByFriendCode(' ${code.toLowerCase()} ', me: 'ravi');
      expect(found.uid, 'asha');
      expect(found.name, 'Asha');
    });

    test('bad codes, your own code, blocked people and existing friends get a clear message', () async {
      final mine = await b.myFriendCode('asha');
      await expectLater(b.findByFriendCode('ABC', me: 'ravi'), throwsA(isA<FriendsFailure>()));
      await expectLater(b.findByFriendCode('ZZZZZZ', me: 'ravi'), throwsA(isA<FriendsFailure>()));
      await expectLater(b.findByFriendCode(mine, me: 'asha'), throwsA(isA<FriendsFailure>()));
      await b.block('asha', 'ravi');
      await expectLater(b.findByFriendCode(mine, me: 'ravi'), throwsA(isA<FriendsFailure>()));
    });

    test('ask, accept, and both are friends; the request is gone', () async {
      await b.sendRequest(_ravi, _asha);
      final inbox = await b.incomingRequests('asha').first;
      expect(inbox.single.fromUid, 'ravi');
      expect(inbox.single.name, 'Ravi');
      expect(await b.areFriends('asha', 'ravi'), isFalse);

      await b.acceptRequest('asha', inbox.single);
      expect(await b.areFriends('asha', 'ravi'), isTrue);
      expect(await b.areFriends('ravi', 'asha'), isTrue);
      expect(await b.incomingRequests('asha').first, isEmpty);
      expect((await b.friends('ravi').first).single.uid, 'asha');
    });

    test('declining removes it and nobody becomes friends', () async {
      await b.sendRequest(_ravi, _asha);
      await b.declineRequest('asha', 'ravi');
      expect(await b.incomingRequests('asha').first, isEmpty);
      expect(await b.areFriends('asha', 'ravi'), isFalse);
    });

    test('someone who blocked you cannot be asked', () async {
      await b.block('asha', 'ravi');
      await expectLater(b.sendRequest(_ravi, _asha), throwsA(isA<FriendsFailure>()));
    });

    test('friends made this way can challenge each other straight away', () async {
      await b.sendRequest(_ravi, _asha);
      await b.acceptRequest('asha', (await b.incomingRequests('asha').first).single);
      final c = await b.createChallenge(
        from: _asha,
        exercise: Exercise.squat,
        reps: 12,
        arcLabel: 'Winter Arc 2026',
        to: _ravi,
      );
      expect(c.status, ChallengeStatus.accepted);
    });

    test('deleting your account removes your code and waiting requests', () async {
      final code = await b.myFriendCode('asha');
      await b.sendRequest(_ravi, _asha);
      await b.deleteMe('asha');
      await expectLater(b.findByFriendCode(code, me: 'meena'), throwsA(isA<FriendsFailure>()));
      expect(await b.incomingRequests('asha').first, isEmpty);
    });
  });

  group('XP for finishing challenges', () {
    FriendChallenge done(DateTime at, {ChallengeStatus status = ChallengeStatus.done}) => FriendChallenge(
      id: '${at.microsecondsSinceEpoch}',
      code: 'AAAAAA',
      fromUid: 'asha',
      fromName: 'Asha',
      exercise: Exercise.pushUp,
      reps: 10,
      arcLabel: 'Winter Arc 2026',
      createdAt: at,
      status: status,
    );

    test('50 XP for each finished challenge', () {
      expect(challengeBonusXp([done(DateTime(2026, 3, 2))]), 50);
      expect(challengeBonusXp(const []), 0);
    });

    test('open, taken and declined challenges earn nothing; friend requests earn nothing', () {
      expect(
        challengeBonusXp([
          done(DateTime(2026, 3, 2), status: ChallengeStatus.open),
          done(DateTime(2026, 3, 3), status: ChallengeStatus.accepted),
          done(DateTime(2026, 3, 4), status: ChallengeStatus.declined),
        ]),
        0,
      );
    });

    test('at most 3 count in one week, so it rewards doing them, not making them in bulk', () {
      final week = [for (var d = 2; d <= 8; d++) done(DateTime(2026, 3, d))]; // Mon 2 Mar to Sun 8 Mar
      expect(challengeBonusXp(week), 150);
      final nextWeek = [...week, done(DateTime(2026, 3, 9))];
      expect(challengeBonusXp(nextWeek), 200);
    });
  });

  test('invites: a new user enters a code once; the inviter sees them', () async {
    final code = await b.myFriendCode('asha');
    expect(await b.wasInvited('ravi'), isFalse);
    final inviter = await b.redeemInvite(_ravi, code);
    expect(inviter.uid, 'asha');
    expect(await b.wasInvited('ravi'), isTrue);
    expect(await b.invitees('asha').first, ['ravi']);
    await expectLater(b.redeemInvite(_ravi, code), throwsA(isA<FriendsFailure>()));
    // Ravi's request reached Asha.
    expect((await b.incomingRequests('asha').first).map((r) => r.fromUid), ['ravi']);
  });
}
