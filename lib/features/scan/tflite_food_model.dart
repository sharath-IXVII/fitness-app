import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'domain/recognition.dart';

/// Loads the bundled model; null when it's missing.
Future<Future<List<(String, double)>> Function(Uint8List)?> loadFoodModel() async =>
    (await TfliteFoodRecognizer.load())?.classify;

/// Recognises the food in a photo, entirely on the phone. Free, offline and
/// private: the photo never leaves the device.
///
/// Google's AIY "Food V1" classifier (2,024 dishes). The model files are
/// downloaded into assets/models/ by the build (see build-apk.yml); a build
/// without them simply has no recognizer.
class TfliteFoodRecognizer {
  TfliteFoodRecognizer._(this._interpreter, this._labels);

  static const modelAsset = 'assets/models/food_v1.tflite';
  static const labelsAsset = 'assets/models/food_labels.csv';

  final Interpreter _interpreter;
  final List<String> _labels;

  static Future<TfliteFoodRecognizer?> load() async {
    if (kIsWeb) return null;
    try {
      final labels = parseLabels(await rootBundle.loadString(labelsAsset));
      final interpreter = await Interpreter.fromAsset(modelAsset, options: InterpreterOptions()..threads = 2);
      return TfliteFoodRecognizer._(interpreter, labels);
    } catch (e) {
      debugPrint('Food model not available: $e');
      return null;
    }
  }

  /// Top guesses as (label, probability).
  Future<List<(String, double)>> classify(Uint8List image) async {
    final input = _interpreter.getInputTensor(0);
    final output = _interpreter.getOutputTensor(0);
    final h = input.shape[1], w = input.shape[2];
    final isFloat = input.type == TensorType.float32;

    // Decoding and resizing a photo is slow; do it off the UI thread.
    final rgb = await Isolate.run(() => preprocess(image, w, h));
    if (rgb == null) return const [];

    final pixels = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final i = (y * w + x) * 3;
        return isFloat ? [rgb[i] / 255.0, rgb[i + 1] / 255.0, rgb[i + 2] / 255.0] : [rgb[i], rgb[i + 1], rgb[i + 2]];
      }),
    );
    final classes = output.shape.last;
    final out = [output.type == TensorType.float32 ? List<double>.filled(classes, 0) : List<int>.filled(classes, 0)];
    _interpreter.run([pixels], out);

    final q = output.params;
    final quantized = output.type != TensorType.float32 && q.scale != 0;
    final scores = normalizeScores(
      out.first.cast<num>(),
      scale: quantized ? q.scale : 1,
      zeroPoint: quantized ? q.zeroPoint : 0,
    );
    return [
      for (final (i, s) in topK(scores, k: 6))
        if (i < _labels.length && _labels[i].isNotEmpty) (_labels[i], s),
    ];
  }

  /// Decodes, fixes orientation, centre-crops to a square and resizes to the
  /// model's input. Returns RGB bytes, or null if the image can't be read.
  static Uint8List? preprocess(Uint8List bytes, int w, int h) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final upright = img.bakeOrientation(decoded);
    final side = upright.width < upright.height ? upright.width : upright.height;
    final square = img.copyCrop(
      upright,
      x: (upright.width - side) ~/ 2,
      y: (upright.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final small = img.copyResize(square, width: w, height: h, interpolation: img.Interpolation.average);
    final out = Uint8List(w * h * 3);
    var i = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = small.getPixel(x, y);
        out[i++] = p.r.toInt();
        out[i++] = p.g.toInt();
        out[i++] = p.b.toInt();
      }
    }
    return out;
  }
}
