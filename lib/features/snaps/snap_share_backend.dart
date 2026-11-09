import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../friends/friends_backend.dart' show FriendsFailure;

/// A snap a friend sent you. Gone after 24 hours.
class SharedSnap {
  const SharedSnap({
    required this.id,
    required this.from,
    required this.fromName,
    required this.caption,
    required this.image,
    required this.at,
  });

  static const lifetime = Duration(hours: 24);

  final String id;
  final String from;
  final String fromName;
  final String caption;
  final Uint8List image;
  final DateTime at;
}

/// In-app snaps between friends, in Firestore (no Firebase Storage):
///   snapShares/{id} {from, fromName, to: [uids], caption, image (JPEG,
///   under 200 KB), at, expireAt}
/// A TTL policy on expireAt deletes them after 24 hours.
class SnapShareBackend {
  SnapShareBackend(this._db);

  final FirebaseFirestore _db;

  static const maxBytes = 200 * 1024;
  static const maxFriends = 10;

  CollectionReference<Map<String, dynamic>> get _snaps => _db.collection('snapShares');

  Future<void> send({
    required String from,
    required String fromName,
    required List<String> to,
    required String caption,
    required Uint8List jpeg,
  }) async {
    if (to.isEmpty) throw const FriendsFailure('Pick at least one friend.');
    if (to.length > maxFriends) throw const FriendsFailure('Send to up to 10 friends at a time.');
    if (jpeg.length > maxBytes) throw const FriendsFailure('That picture is too big to send.');
    await _snaps.add({
      'from': from,
      'fromName': fromName,
      'to': to,
      'caption': caption.length > 120 ? caption.substring(0, 120) : caption,
      'image': Blob(jpeg),
      'at': FieldValue.serverTimestamp(),
      'expireAt': Timestamp.fromDate(clock.now().add(SharedSnap.lifetime)),
    });
  }

  /// Snaps sent to [uid] in the last 24 hours, newest first.
  Stream<List<SharedSnap>> inbox(String uid) => _snaps
      .where('to', arrayContains: uid)
      .where('at', isGreaterThan: Timestamp.fromDate(clock.now().subtract(SharedSnap.lifetime)))
      .orderBy('at', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if ((d.data()['image'], d.data()['at']) case (final Blob img, final Timestamp at))
              SharedSnap(
                id: d.id,
                from: d.data()['from'] as String? ?? '',
                fromName: d.data()['fromName'] as String? ?? 'Friend',
                caption: d.data()['caption'] as String? ?? '',
                image: img.bytes,
                at: at.toDate(),
              ),
        ],
      );

  Future<void> report(String me, SharedSnap s) => _db.collection('reports').add({
    'by': me,
    'about': s.from,
    'reason': 'Snap ${s.id}: ${s.caption}',
    'at': FieldValue.serverTimestamp(),
  });

  /// Removes snaps [uid] sent (account deletion).
  Future<void> deleteMine(String uid) async {
    for (final d in (await _snaps.where('from', isEqualTo: uid).get()).docs) {
      await d.reference.delete();
    }
  }
}
