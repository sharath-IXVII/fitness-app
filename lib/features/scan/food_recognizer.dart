import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diet/diet_providers.dart';
import 'domain/recognition.dart';
import 'tflite_food_model_stub.dart' if (dart.library.ffi) 'tflite_food_model.dart';

/// One thing the model saw: a label, its probability (0–1), and where it is
/// on the square plate photo (fractions, 0–1), or null for the whole photo.
typedef RawGuess = (String label, double score, Rect? box);

/// Finds the foods in a photo.
typedef FoodClassifier = Future<List<RawGuess>> Function(Uint8List image);

/// Null when this build has no food model. The model runs through TensorFlow
/// Lite (dart:ffi), which only exists on phones; web gets a stub.
final foodClassifierProvider = FutureProvider<FoodClassifier?>((ref) => loadFoodModel());

/// Guesses for [image], best first, matched against the app's food list.
Future<List<FoodGuess>> recognizeFood(WidgetRef ref, FoodClassifier classify, Uint8List image) async {
  final byId = ref.read(allFoodsByIdProvider);
  return [
    for (final (label, score, box) in await classify(image))
      FoodGuess(label: label, score: score, food: matchFood(label, byId), box: box),
  ];
}
