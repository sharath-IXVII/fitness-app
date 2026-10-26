import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../workout/domain/exercise.dart';
import 'domain/friends.dart';

/// A user-facing Friends error.
class FriendsFailure implements Exception {
  const FriendsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Friends, challenges and profiles in Cloud Firestore.
///
/// Layout (see firestore.rules for who may read and write what):
///   users/{uid}                      public profile
///   users/{uid}/friends/{friendUid}  {since, via: challengeId}
///   users/{uid}/blocked/{otherUid}   people this user blocked
///   challenges/{id}                  FriendChallenge
///   reports/{id}                     {by, about, reason, at}
class FriendsBackend {
  FriendsBackend(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _challenges => _db.collection('challenges');

  /// codes/{code} → {challengeId, fromUid}. Looked up one at a time, so
  /// open challenges can't be listed by strangers.
  CollectionReference<Map<String, dynamic>> get _codes => _db.collection('codes');

  // ------------------------------------------------------------- profiles

  /// The rules cap how much XP can grow per write; after a long time
  /// offline the shared XP catches up in steps instead of being refused.
  static const maxXpStep = 2000;

  Future<void> syncProfile(PublicProfile me) async {
    final ref = _users.doc(me.uid);
    final current = (await ref.get()).data();
    final before = current?['xp'];
    final json = me.toJson();
    if (before is int && me.xp > before + maxXpStep) json['xp'] = before + maxXpStep;
    if (before == null && me.xp > 200000) json['xp'] = 200000;
    await ref.set({...json, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<PublicProfile?> profile(String uid) async {
    final d = await _users.doc(uid).get();
    final data = d.data();
    return data == null ? null : PublicProfile.fromJson(uid, data);
  }

  Stream<PublicProfile?> watchProfile(String uid) => _users.doc(uid).snapshots().map((d) {
    final data = d.data();
    return data == null ? null : PublicProfile.fromJson(uid, data);
  });

  // --------------------------------------------------------------- friends

  /// Friends' profiles, refreshed whenever the friend list changes.
  Stream<List<PublicProfile>> friends(String uid) =>
      _users.doc(uid).collection('friends').snapshots().asyncMap((snap) async {
        final out = <PublicProfile>[];
        for (final d in snap.docs) {
          final p = await profile(d.id);
          if (p != null) out.add(p);
        }
        return out;
      });

  Future<bool> areFriends(String a, String b) async => (await _users.doc(a).collection('friends').doc(b).get()).exists;

  Future<void> removeFriend(String me, String other) async {
    final batch = _db.batch()
      ..delete(_users.doc(me).collection('friends').doc(other))
      ..delete(_users.doc(other).collection('friends').doc(me));
    await batch.commit();
  }

  Future<void> block(String me, String other) async {
    await removeFriend(me, other);
    // Close anything still open between the two, so it can't re-friend them.
    for (final c in await challenges(me).first) {
      if (c.involves(other) && (c.status == ChallengeStatus.open || c.status == ChallengeStatus.accepted)) {
        await decline(c);
      }
    }
    await _users.doc(me).collection('blocked').doc(other).set({'at': FieldValue.serverTimestamp()});
  }

  Future<bool> _blocked(String by, String who) async =>
      (await _users.doc(by).collection('blocked').doc(who).get()).exists;

  Future<void> report(String me, String other, String reason) =>
      _db.collection('reports').add({'by': me, 'about': other, 'reason': reason, 'at': FieldValue.serverTimestamp()});

  /// Deletes everything friends could see about [uid] (account deletion).
  Future<void> deleteMe(String uid) async {
    final me = _users.doc(uid);
    for (final f in (await me.collection('friends').get()).docs) {
      await removeFriend(uid, f.id);
    }
    for (final b in (await me.collection('blocked').get()).docs) {
      await b.reference.delete();
    }
    // Challenges carry names, so they go too.
    for (final c in await challenges(uid).first) {
      if (c.status == ChallengeStatus.open) await _codes.doc(c.code).delete();
      await _challenges.doc(c.id).delete();
    }
    await me.delete();
  }

  // ------------------------------------------------------------ challenges

  /// Creates a challenge. Without [to] it's open: anyone with the code can
  /// join. With [to] (a friend) it goes straight to them.
  Future<FriendChallenge> createChallenge({
    required PublicProfile from,
    required Exercise exercise,
    required int reps,
    required String arcLabel,
    PublicProfile? to,
  }) async {
    if (to != null && await _blocked(to.uid, from.uid)) {
      throw const FriendsFailure("You can't challenge this person.");
    }
    // Codes are random; retry on the rare clash.
    var code = newChallengeCode();
    for (var i = 0; i < 5 && (await _codes.doc(code).get()).exists; i++) {
      code = newChallengeCode();
    }
    final doc = _challenges.doc();
    final c = FriendChallenge(
      id: doc.id,
      code: code,
      fromUid: from.uid,
      fromName: from.name,
      fromTitle: from.title,
      toUid: to?.uid,
      toName: to?.name,
      toTitle: to?.title,
      exercise: exercise,
      reps: reps,
      arcLabel: arcLabel,
      status: to == null ? ChallengeStatus.open : ChallengeStatus.accepted,
      createdAt: clock.now(),
    );
    final batch = _db.batch()..set(doc, c.toJson());
    if (to == null) batch.set(_codes.doc(code), {'challengeId': doc.id, 'fromUid': from.uid});
    await batch.commit();
    return c;
  }

  Future<FriendChallenge?> _openByCode(String code) async {
    final link = (await _codes.doc(code).get()).data();
    final id = link?['challengeId'];
    if (id is! String) return null;
    try {
      final snap = await _challenges.doc(id).get();
      final c = _parseChallenge(snap.id, snap.data());
      return c != null && c.status == ChallengeStatus.open && c.code == code && !c.expiredAt(clock.now()) ? c : null;
    } on FirebaseException catch (e) {
      // No longer open and not ours: the rules hide it.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  static FriendChallenge? _parseChallenge(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      return FriendChallenge.fromJson(id, data);
    } catch (_) {
      return null; // a malformed document never breaks the list
    }
  }

  /// The open challenge for a code someone typed, or a friendly error.
  Future<FriendChallenge> findByCode(String typed, {required String me}) async {
    final code = normalizeCode(typed);
    if (code.length != 6) throw const FriendsFailure('Codes have 6 letters and numbers.');
    final c = await _openByCode(code);
    if (c == null) throw const FriendsFailure('No open challenge with that code. Check it, or ask for a new one.');
    if (c.fromUid == me) throw const FriendsFailure("That's your own challenge. Send the code to a friend!");
    if (await _blocked(c.fromUid, me) || await _blocked(me, c.fromUid)) {
      throw const FriendsFailure("You can't join this challenge.");
    }
    return c;
  }

  /// Joins an open challenge. Only the first person to accept gets it.
  Future<FriendChallenge> accept(FriendChallenge c, PublicProfile me) async {
    final ref = _challenges.doc(c.id);
    try {
      return await _accept(ref, c, me);
    } on FirebaseException catch (e) {
      // Losing the race: the challenge stopped being open, so it's hidden.
      if (e.code == 'permission-denied') throw const FriendsFailure('Someone else already took this challenge.');
      rethrow;
    }
  }

  Future<FriendChallenge> _accept(DocumentReference<Map<String, dynamic>> ref, FriendChallenge c, PublicProfile me) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = FriendChallenge.fromJson(snap.id, snap.data()!);
      if (current.expiredAt(clock.now())) {
        throw const FriendsFailure('This challenge has expired. Ask for a new one.');
      }
      if (current.status != ChallengeStatus.open || current.toUid != null) {
        throw const FriendsFailure('Someone else already took this challenge.');
      }
      tx.update(ref, {'toUid': me.uid, 'toName': me.name, 'toTitle': me.title, 'status': 'accepted'});
      return FriendChallenge.fromJson(c.id, {
        ...current.toJson(),
        'toUid': me.uid,
        'toName': me.name,
        'toTitle': me.title,
        'status': 'accepted',
      });
    });
  }

  Future<void> decline(FriendChallenge c) => _challenges.doc(c.id).update({'status': 'declined'});

  /// Writes both sides of the friendship for a finished challenge. Safe to
  /// repeat, so a failed write is simply retried later.
  Future<void> ensureFriendship(FriendChallenge c) async {
    if (c.status != ChallengeStatus.done || c.toUid == null) return;
    final batch = _db.batch()
      ..set(_users.doc(c.fromUid).collection('friends').doc(c.toUid), {
        'since': c.createdAt.millisecondsSinceEpoch,
        'via': c.id,
      })
      ..set(_users.doc(c.toUid).collection('friends').doc(c.fromUid), {
        'since': c.createdAt.millisecondsSinceEpoch,
        'via': c.id,
      });
    await batch.commit();
  }

  /// Records that [uid] did the challenge. When both have, it's done and
  /// the two become friends.
  Future<FriendChallenge> markDone(FriendChallenge c, String uid) async {
    final ref = _challenges.doc(c.id);
    final updated = await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      var current = FriendChallenge.fromJson(snap.id, snap.data()!);
      if (!current.involves(uid)) throw const FriendsFailure('This challenge is between other people.');
      final field = current.fromUid == uid ? 'fromDone' : 'toDone';
      final json = {...current.toJson(), field: true};
      current = FriendChallenge.fromJson(c.id, json);
      final both = current.fromDone && current.toDone;
      tx.update(ref, {field: true, if (both) 'status': 'done'});
      return both ? FriendChallenge.fromJson(c.id, {...json, 'status': 'done'}) : current;
    });
    if (updated.status == ChallengeStatus.done) await ensureFriendship(updated);
    return updated;
  }

  /// Deletes a lapsed open challenge and its code. Best effort: if it fails
  /// (offline), it's hidden anyway and tried again next time.
  Future<void> _discard(FriendChallenge c) async {
    try {
      await _codes.doc(c.code).delete();
      await _challenges.doc(c.id).delete();
    } catch (_) {}
  }

  /// Every challenge [uid] sent or received, newest first.
  Stream<List<FriendChallenge>> challenges(String uid) {
    final controller = StreamController<List<FriendChallenge>>();
    List<FriendChallenge>? sent, got;
    void emit() {
      // Wait for both queries, so the list never flashes up half-empty.
      if (sent == null || got == null) return;
      final every = {
        for (final c in [...sent!, ...got!]) c.id: c,
      }.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Open challenges nobody joined in time vanish, and the sender's are
      // tidied away (the challenge and its share code).
      final now = clock.now();
      final lapsed = every.where((c) => c.expiredAt(now)).toList();
      for (final c in lapsed.where((c) => c.fromUid == uid)) {
        unawaited(_discard(c));
      }
      final all = every.where((c) => !c.expiredAt(now)).toList();
      if (!controller.isClosed) controller.add(all);
    }

    List<FriendChallenge> parse(QuerySnapshot<Map<String, dynamic>> s) => [
      for (final d in s.docs) ?_parseChallenge(d.id, d.data()),
    ];
    final subs = [
      _challenges.where('fromUid', isEqualTo: uid).snapshots().listen((s) {
        sent = parse(s);
        emit();
      }, onError: controller.addError),
      _challenges.where('toUid', isEqualTo: uid).snapshots().listen((s) {
        got = parse(s);
        emit();
      }, onError: controller.addError),
    ];
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }
}
