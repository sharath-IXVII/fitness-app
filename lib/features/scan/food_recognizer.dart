import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diet/diet_providers.dart';
import 'domain/recognition.dart';
import 'tflite_food_model_stub.dart' if (dart.library.ffi) 'tflite_food_model.dart';

/// Classifies a photo: the top labels with their probabilities.
typedef FoodClassifier = Future<List<(String, double)>> Function(Uint8List image);

/// Null when this build has no food model. The model runs through TensorFlow
/// Lite (dart:ffi), which only exists on phones; web gets a stub.
final foodClassifierProvider = FutureProvider<FoodClassifier?>((ref) => loadFoodModel());

/// Guesses for [image], best first, matched against the app's food list.
Future<List<FoodGuess>> recognizeFood(WidgetRef ref, FoodClassifier classify, Uint8List image) async {
  final byId = ref.read(allFoodsByIdProvider);
  return [
    for (final (label, score) in await classify(image))
      FoodGuess(label: label, score: score, food: matchFood(label, byId)),
  ];
}
