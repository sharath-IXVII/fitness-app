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
}
