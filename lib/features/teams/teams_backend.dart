import 'package:cloud_firestore/cloud_firestore.dart';

import '../friends/domain/friends.dart' show newChallengeCode, normalizeCode;
import '../friends/friends_backend.dart' show FriendsFailure;
import 'domain/team.dart';

/// Teams in Firestore:
///   teams/{id}               {name, members, names, createdBy, code, createdAt}
///   teams/{id}/days/{date}   {done: [uids]}: who hit their goals that day
///   teamCodes/{code}         {teamId}
class TeamsBackend {
  TeamsBackend(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _teams => _db.collection('teams');
  CollectionReference<Map<String, dynamic>> get _codes => _db.collection('teamCodes');

  Stream<List<Team>> myTeams(String uid) => _teams
      .where('members', arrayContains: uid)
      .snapshots()
      .map((s) => [for (final d in s.docs) Team.fromJson(d.id, d.data())]);

  Future<Team> create(String uid, String myName, String name) async {
    final n = name.trim();
    if (n.length < 2 || n.length > 30) throw const FriendsFailure('Give the team a name of 2 to 30 letters.');
    var code = newChallengeCode();
    for (var i = 0; i < 5 && (await _codes.doc(code).get()).exists; i++) {
      code = newChallengeCode();
    }
    final ref = _teams.doc();
    final b = _db.batch()
      ..set(ref, {
        'name': n,
        'members': [uid],
        'names': {uid: myName},
        'createdBy': uid,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_codes.doc(code), {'teamId': ref.id});
    await b.commit();
    return Team(id: ref.id, name: n, members: [uid], names: {uid: myName}, code: code);
  }

  Future<Team> join(String uid, String myName, String typed) async {
    final code = normalizeCode(typed);
    if (code.length != 6) throw const FriendsFailure('Team codes have 6 letters and numbers.');
    final id = (await _codes.doc(code).get()).data()?['teamId'];
    final data = id is String ? (await _teams.doc(id).get()).data() : null;
    if (id is! String || data == null) throw const FriendsFailure('No team has that code.');
    final t = Team.fromJson(id, data);
    if (t.members.contains(uid)) return t;
    if (t.members.length >= Team.maxMembers) throw const FriendsFailure('That team is full (6 people).');
    await _teams.doc(id).update({
      'members': FieldValue.arrayUnion([uid]),
      'names.$uid': myName,
    });
    return t;
  }

  Future<void> leave(String teamId, String uid) => _teams.doc(teamId).update({
    'members': FieldValue.arrayRemove([uid]),
    'names.$uid': FieldValue.delete(),
  });

  /// Marks [uid] as done for [day] (their daily goals are met).
  Future<void> checkIn(String teamId, String uid, DateTime day) =>
      _teams.doc(teamId).collection('days').doc(teamDayKey(day)).set({
        'done': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));

  /// Who was done on each of the last [days] days.
  Stream<Map<String, Set<String>>> days(String teamId, {int days = 120}) => _teams
      .doc(teamId)
      .collection('days')
      .orderBy(FieldPath.documentId, descending: true)
      .limit(days)
      .snapshots()
      .map(
        (s) => {
          for (final d in s.docs) d.id: {for (final u in d.data()['done'] as List<dynamic>? ?? const []) u as String},
        },
      );

  Future<void> leaveAll(String uid) async {
    for (final t in await myTeams(uid).first) {
      await leave(t.id, uid);
    }
  }
}
