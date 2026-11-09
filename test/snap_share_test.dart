import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/friends/friends_backend.dart' show FriendsFailure;
import 'package:fitalarm/features/snaps/snap_share_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a snap reaches the friends it was sent to, and only them', () async {
    final b = SnapShareBackend(FakeFirebaseFirestore());
    final jpeg = Uint8List.fromList(List.filled(50 * 1024, 7));
    await b.send(from: 'asha', fromName: 'Asha', to: ['ravi'], caption: 'Lunch: about 450 kcal', jpeg: jpeg);
    final ravi = await b.inbox('ravi').first;
    expect(ravi.single.fromName, 'Asha');
    expect(ravi.single.caption, contains('450 kcal'));
    expect(ravi.single.image.length, jpeg.length);
    expect(await b.inbox('meera').first, isEmpty);
    await b.deleteMine('asha');
    expect(await b.inbox('ravi').first, isEmpty);
  });

  test('size and recipient limits', () async {
    final b = SnapShareBackend(FakeFirebaseFirestore());
    final big = Uint8List(SnapShareBackend.maxBytes + 1);
    await expectLater(
      b.send(from: 'a', fromName: 'A', to: ['b'], caption: '', jpeg: big),
      throwsA(isA<FriendsFailure>()),
    );
    await expectLater(
      b.send(from: 'a', fromName: 'A', to: const [], caption: '', jpeg: Uint8List(10)),
      throwsA(isA<FriendsFailure>()),
    );
  });
}
