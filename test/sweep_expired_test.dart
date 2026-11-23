import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/clubs/clubs_backend.dart';
import 'package:fitalarm/features/snaps/snap_share_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 23, 12);
  Timestamp hoursAgo(int h) => Timestamp.fromDate(now.subtract(Duration(hours: h)));

  test('old club chat is deleted: all of it by the owner, only your own otherwise', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('clubs/c1').set({'ownerUid': 'asha', 'name': 'Lake walkers'});
    for (final u in ['asha', 'ravi']) {
      await db.doc('users/$u/clubs/c1').set({'name': 'Lake walkers', 'kind': 'walking'});
    }
    Future<void> msg(String id, String uid, int h) =>
        db.doc('clubs/c1/messages/$id').set({'uid': uid, 'name': uid, 'text': 'hi', 'at': hoursAgo(h)});
    await msg('old-ravi', 'ravi', 30);
    await msg('old-asha', 'asha', 48);
    await msg('new-ravi', 'ravi', 2);

    await withClock(Clock.fixed(now), () async {
      // Ravi isn't the owner: only his own old message goes.
      expect(await ClubsBackend(db).sweepExpired('ravi'), 1);
      expect((await db.doc('clubs/c1/messages/old-ravi').get()).exists, isFalse);
      expect((await db.doc('clubs/c1/messages/old-asha').get()).exists, isTrue);
      // Asha owns the club: every old message goes, new ones stay.
      expect(await ClubsBackend(db).sweepExpired('asha'), 1);
    });
    final left = await db.collection('clubs/c1/messages').get();
    expect([for (final d in left.docs) d.id], ['new-ravi']);
  });

  test('snaps older than a day are deleted by the sender\'s app; new ones stay', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('snapShares/old').set({
      'from': 'asha',
      'to': ['ravi'],
      'at': hoursAgo(25),
    });
    await db.doc('snapShares/new').set({
      'from': 'asha',
      'to': ['ravi'],
      'at': hoursAgo(3),
    });
    await db.doc('snapShares/theirs').set({
      'from': 'ravi',
      'to': ['asha'],
      'at': hoursAgo(40),
    });
    await withClock(Clock.fixed(now), () async {
      expect(await SnapShareBackend(db).sweepExpired('asha'), 1);
    });
    final left = {for (final d in (await db.collection('snapShares').get()).docs) d.id};
    expect(left, {'new', 'theirs'});
  });
}
