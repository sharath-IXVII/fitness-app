import 'dart:isolate';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../core/storage.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_service.dart';

/// "Help improve food recognition": off unless the user turns it on. When on,
/// each logged scan sends a small cut-out of every dish (256 px) with the
/// name the user confirmed. No full photo, no location, no names of people.
class FoodSamplesOptIn extends Notifier<bool> {
  static const key = 'food.samples.v1';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(key) ?? false;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPrefsProvider).setBool(key, on);
  }
}

final foodSamplesOptInProvider = NotifierProvider<FoodSamplesOptIn, bool>(FoodSamplesOptIn.new);

/// One dish to send: its confirmed name, where it is on the square photo
/// (null for the whole photo) and how sure the model was ('high', 'medium',
/// 'low').
typedef FoodSample = ({String name, Rect? box, String confidence});

/// Sends samples; null without a real account (demo mode, tests).
final foodSampleSenderProvider = Provider<Future<void> Function(Uint8List photo, List<FoodSample> items)?>((ref) {
  if (ref.watch(authServiceProvider) is! FirebaseAuthService) return null;
  final uid = ref.watch(authProvider)?.uid;
  if (uid == null) return null;
  final db = FirebaseFirestore.instance;
  return (photo, items) async {
    final cuts = await Isolate.run(() => cutSamples(photo, [for (final i in items) i.box]));
    for (final (i, item) in items.indexed) {
      if (i >= cuts.length || cuts[i] == null) continue;
      await db.collection('foodSamples').add({
        'uid': uid,
        'name': item.name,
        'confidence': item.confidence,
        'image': Blob(cuts[i]!),
        'at': FieldValue.serverTimestamp(),
      });
    }
  };
});

/// Cut-outs (JPEG, at most 256 px a side) of each box on the upright centre
/// square of [bytes]; the whole square for a null box. Null entries for boxes
/// that can't be cut.
List<Uint8List?> cutSamples(Uint8List bytes, List<Rect?> boxes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return [for (final _ in boxes) null];
  final up = img.bakeOrientation(decoded);
  final side = math.min(up.width, up.height);
  final x0 = (up.width - side) ~/ 2, y0 = (up.height - side) ~/ 2;
  return [
    for (final b in boxes)
      () {
        final r = b ?? const Rect.fromLTWH(0, 0, 1, 1);
        final w = (side * r.width).round(), h = (side * r.height).round();
        if (w < 16 || h < 16) return null;
        final crop = img.copyCrop(
          up,
          x: x0 + (side * r.left).round(),
          y: y0 + (side * r.top).round(),
          width: w,
          height: h,
        );
        final scale = 256 / math.max(w, h);
        final small = scale < 1 ? img.copyResize(crop, width: (w * scale).round(), height: (h * scale).round()) : crop;
        return Uint8List.fromList(img.encodeJpg(small, quality: 80));
      }(),
  ];
}
