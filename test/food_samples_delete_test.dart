import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/features/scan/food_samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleting an account removes that person\'s food samples and nobody else\'s', () async {
    final db = FakeFirebaseFirestore();
    Future<void> add(String uid) => db.collection('foodSamples').add({
      'uid': uid,
      'name': 'Roti / chapati',
      'confidence': 'high',
      'image': Blob(Uint8List(8)),
    });
    for (var i = 0; i < 5; i++) {
      await add('asha');
    }
    await add('ravi');

    await deleteFoodSamples(db, 'asha');

    final left = await db.collection('foodSamples').get();
    expect(left.docs, hasLength(1));
    expect(left.docs.single['uid'], 'ravi');
  });
}
