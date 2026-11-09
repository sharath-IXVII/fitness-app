import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../friends/friends_backend.dart' show FriendsFailure;
import 'domain/club.dart';

/// Clubs in Cloud Firestore. Text only: no photos, no Firebase Storage.
///
/// Layout (see firestore.rules for who may read and write what):
///   clubs/{id}                      {name, about, kind, ownerUid, ownerName, createdAt}
///   clubs/{id}/members/{uid}        {name, joinedAt}
///   clubs/{id}/banned/{uid}         people the owner removed
///   clubs/{id}/messages/{msg}       {uid, name, text, at, expireAt}
///   users/{uid}/clubs/{id}          {name, kind}: the clubs this user is in
///
/// Messages carry expireAt (24 hours after sending). The app only shows the
/// last 24 hours, and a Firestore TTL policy on expireAt deletes them.
class ClubsBackend {
  ClubsBackend(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _clubs => _db.collection('clubs');
  CollectionReference<Map<String, dynamic>> _members(String club) => _clubs.doc(club).collection('members');
  CollectionReference<Map<String, dynamic>> _messages(String club) => _clubs.doc(club).collection('messages');
  CollectionReference<Map<String, dynamic>> _mine(String uid) => _db.collection('users').doc(uid).collection('clubs');

  /// Newest clubs first, for browsing.
  Stream<List<Club>> discover({int limit = 60}) => _clubs
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) Club.fromJson(d.id, d.data())]);

  /// Ids of the clubs [uid] is in.
  Stream<Set<String>> myClubIds(String uid) => _mine(uid).snapshots().map((s) => {for (final d in s.docs) d.id});

  Stream<Club?> watchClub(String id) => _clubs.doc(id).snapshots().map((d) {
    final data = d.data();
    return data == null ? null : Club.fromJson(d.id, data);
  });

  Future<Club> create({
    required String uid,
    required String myName,
    required String name,
    required String about,
    required ClubKind kind,
  }) async {
    final problem = clubProblem(name, about);
    if (problem != null) throw FriendsFailure(problem);
    final ref = _clubs.doc();
    final club = {
      'name': name.trim(),
      'about': about.trim(),
      'kind': kind.name,
      'ownerUid': uid,
      'ownerName': myName,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(club);
    await join(ref.id, uid: uid, myName: myName, clubName: name.trim(), kind: kind);
    return Club(id: ref.id, name: name.trim(), about: about.trim(), kind: kind, ownerUid: uid, ownerName: myName);
  }

  Future<void> join(
    String club, {
    required String uid,
    required String myName,
    required String clubName,
    required ClubKind kind,
  }) async {
    if ((await _clubs.doc(club).collection('banned').doc(uid).get()).exists) {
      throw const FriendsFailure("You can't join this club.");
    }
    final b = _db.batch()
      ..set(_members(club).doc(uid), {'name': myName, 'joinedAt': FieldValue.serverTimestamp()})
      ..set(_mine(uid).doc(club), {'name': clubName, 'kind': kind.name});
    await b.commit();
  }

  Future<void> leave(String club, String uid) async {
    final b = _db.batch()
      ..delete(_members(club).doc(uid))
      ..delete(_mine(uid).doc(club));
    await b.commit();
  }

  /// The owner removes [uid] from the club; they can't join it again.
  Future<void> removeMember(String club, String uid) async {
    final b = _db.batch()
      ..set(_clubs.doc(club).collection('banned').doc(uid), {'at': FieldValue.serverTimestamp()})
      ..delete(_members(club).doc(uid));
    await b.commit();
  }

  /// The owner closes the club for everyone.
  Future<void> deleteClub(String club, String uid) async {
    for (final m in (await _messages(club).get()).docs) {
      await m.reference.delete();
    }
    for (final m in (await _members(club).get()).docs) {
      await m.reference.delete();
    }
    await _mine(uid).doc(club).delete();
    await _clubs.doc(club).delete();
  }

  /// Members' names, by uid.
  Stream<Map<String, String>> members(String club) =>
      _members(club).snapshots().map((s) => {for (final d in s.docs) d.id: d.data()['name'] as String? ?? 'Member'});

  /// The last 24 hours of chat, oldest first.
  Stream<List<ClubMessage>> messages(String club) {
    final since = clock.now().subtract(ClubMessage.lifetime);
    return _messages(club)
        .where('at', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('at')
        .limitToLast(300)
        .snapshots()
        .map(
          (s) => [
            for (final d in s.docs)
              if (d.data()['at'] case final Timestamp at)
                ClubMessage(
                  id: d.id,
                  uid: d.data()['uid'] as String? ?? '',
                  name: d.data()['name'] as String? ?? 'Member',
                  text: d.data()['text'] as String? ?? '',
                  at: at.toDate(),
                ),
          ],
        );
  }

  Future<void> send(String club, {required String uid, required String myName, required String text}) async {
    final problem = messageProblem(text);
    if (problem != null) throw FriendsFailure(problem);
    await _messages(club).add({
      'uid': uid,
      'name': myName,
      'text': text.trim(),
      'at': FieldValue.serverTimestamp(),
      'expireAt': Timestamp.fromDate(clock.now().add(ClubMessage.lifetime)),
    });
  }

  /// The sender, or the club owner, takes a message down.
  Future<void> deleteMessage(String club, String id) => _messages(club).doc(id).delete();

  Future<void> report({
    required String me,
    required String club,
    required ClubMessage message,
    required String reason,
  }) => _db.collection('reports').add({
    'by': me,
    'about': message.uid,
    'reason': 'Club $club, message ${message.id}: $reason. Text: ${message.text}'.characters500,
    'at': FieldValue.serverTimestamp(),
  });

  /// Removes [uid] from every club, with their messages; closes the clubs
  /// they own (account deletion).
  Future<void> deleteMe(String uid) async {
    for (final c in (await _mine(uid).get()).docs) {
      final club = (await _clubs.doc(c.id).get()).data();
      if (club != null && club['ownerUid'] == uid) {
        await deleteClub(c.id, uid);
        continue;
      }
      for (final m in (await _messages(c.id).where('uid', isEqualTo: uid).get()).docs) {
        await m.reference.delete();
      }
      await leave(c.id, uid);
    }
  }
}

extension on String {
  String get characters500 => length <= 500 ? this : substring(0, 500);
}
