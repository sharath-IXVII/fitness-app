import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/clubs/clubs_backend.dart';
import 'package:fitalarm/features/clubs/domain/club.dart';
import 'package:fitalarm/features/friends/friends_backend.dart' show FriendsFailure;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('links are not allowed', () {
    test('catches web links, invite links and bare domains', () {
      for (final t in [
        'join https://example.com',
        'see www.example.org',
        'msg me on wa.me/919876543210',
        'channel t.me/fitgang',
        'my site fitgang.in',
        'FITGANG.COM is great',
        'check insta.app.',
      ]) {
        expect(containsLink(t), isTrue, reason: t);
      }
    });

    test('ordinary messages are fine', () {
      for (final t in [
        'Walk at 6 am tomorrow?',
        'I did 5.5 km today!',
        'Meet at the park gate. See you',
        'dal.rice combo was 450 kcal',
      ]) {
        expect(containsLink(t), isFalse, reason: t);
      }
    });

    test('message and club checks explain the problem', () {
      expect(messageProblem('  '), 'Type a message.');
      expect(messageProblem('go to x.com'), 'Links are not allowed in clubs.');
      expect(messageProblem('a' * 501), contains('500'));
      expect(messageProblem('Morning walk?'), isNull);
      expect(clubProblem('ab', ''), contains('at least 3'));
      expect(clubProblem('Walkers', 'join www.walk.in'), 'Links are not allowed in clubs.');
      expect(clubProblem('Morning Walkers', 'Every day at 6'), isNull);
    });
  });

  test('create, join, chat for 24 hours, remove a member, delete the club', () async {
    final db = FakeFirebaseFirestore();
    final b = ClubsBackend(db);
    final now = DateTime(2026, 11, 9, 7);
    await withClock(Clock.fixed(now), () async {
      final club = await b.create(
        uid: 'asha',
        myName: 'Asha',
        name: ' Morning Walkers ',
        about: '6 am',
        kind: ClubKind.walking,
      );
      expect(club.name, 'Morning Walkers');
      expect(await b.myClubIds('asha').first, {club.id});
      expect((await b.discover().first).single.kind, ClubKind.walking);

      await b.join(club.id, uid: 'ravi', myName: 'Ravi', clubName: club.name, kind: club.kind);
      expect((await b.members(club.id).first).keys, containsAll(['asha', 'ravi']));

      await b.send(club.id, uid: 'ravi', myName: 'Ravi', text: ' Hi all! ');
      await expectLater(
        b.send(club.id, uid: 'ravi', myName: 'Ravi', text: 'join fitgang.in'),
        throwsA(isA<FriendsFailure>()),
      );
      final msg = (await db.collection('clubs/${club.id}/messages').get()).docs.single.data();
      expect(msg['text'], 'Hi all!');
      expect((msg['expireAt'] as Timestamp).toDate(), now.add(const Duration(hours: 24)));

      // A message from yesterday is not shown.
      await db.collection('clubs/${club.id}/messages').add({
        'uid': 'asha',
        'name': 'Asha',
        'text': 'old',
        'at': Timestamp.fromDate(now.subtract(const Duration(hours: 25))),
      });
      final shown = await b.messages(club.id).first;
      expect(shown.map((m) => m.text), ['Hi all!']);

      // The owner removes Ravi; he can't join again.
      await b.removeMember(club.id, 'ravi');
      expect((await b.members(club.id).first).keys, ['asha']);
      await expectLater(
        b.join(club.id, uid: 'ravi', myName: 'Ravi', clubName: club.name, kind: club.kind),
        throwsA(isA<FriendsFailure>()),
      );

      await b.deleteMe('asha');
      expect((await db.collection('clubs').get()).docs, isEmpty);
      expect(await b.myClubIds('asha').first, isEmpty);
    });
  });

  test('deleting an account removes your messages from clubs you joined', () async {
    final db = FakeFirebaseFirestore();
    final b = ClubsBackend(db);
    final club = await b.create(uid: 'asha', myName: 'Asha', name: 'Gym Gang', about: '', kind: ClubKind.gym);
    await b.join(club.id, uid: 'ravi', myName: 'Ravi', clubName: club.name, kind: club.kind);
    await b.send(club.id, uid: 'ravi', myName: 'Ravi', text: 'Leg day');
    await b.send(club.id, uid: 'asha', myName: 'Asha', text: 'Yes!');
    await b.deleteMe('ravi');
    final left = (await db.collection('clubs/${club.id}/messages').get()).docs.map((d) => d['text']);
    expect(left, ['Yes!']);
    expect((await b.members(club.id).first).keys, ['asha']);
  });

  test('invite codes: the club gets one, anyone can find the club with it', () async {
    final db = FakeFirebaseFirestore();
    final b = ClubsBackend(db);
    final club = await b.create(uid: 'asha', myName: 'Asha', name: 'Gym Gang', about: '', kind: ClubKind.gym);
    expect(club.code, hasLength(6));
    expect(await b.inviteCode(club.id), club.code); // the same code every time
    final found = await b.findByCode(' ${club.code!.toLowerCase()} ');
    expect(found.id, club.id);
    expect(found.name, 'Gym Gang');
    await expectLater(b.findByCode('ZZZZZZ'), throwsA(isA<FriendsFailure>()));
    await expectLater(b.findByCode('abc'), throwsA(isA<FriendsFailure>()));
    await b.deleteClub(club.id, 'asha');
    expect((await db.collection('clubCodes').get()).docs, isEmpty);
  });
}
