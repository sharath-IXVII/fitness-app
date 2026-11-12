import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'domain/recognition.dart';

/// Step 2 of food recognition: names one dish cut out of the photo. Trained
/// for FittArc on the app's own food ids (tools/food_model). Runs on the phone.
class TfliteDishClassifier {
  TfliteDishClassifier._(this._interpreter, this._labels);

  static const modelAsset = 'assets/models/food_dish.tflite';
  static const labelsAsset = 'assets/models/food_dish_labels.csv';

  final Interpreter _interpreter;
  final List<String> _labels;

  static Future<TfliteDishClassifier?> load() async {
    if (kIsWeb) return null;
    try {
      final labels = parseLabels(await rootBundle.loadString(labelsAsset));
      final interpreter = await Interpreter.fromAsset(modelAsset, options: InterpreterOptions()..threads = 2);
      return TfliteDishClassifier._(interpreter, labels);
    } catch (e) {
      noteFoodModel('dish model load', e);
      return null;
    }
  }

  /// The three likeliest dishes for each box (fractions of the centre square
  /// of [image]), as (food id, probability), best first.
  Future<List<List<(String, double)>>> classify(Uint8List image, List<Rect> boxes) async {
    final input = _interpreter.getInputTensor(0);
    final h = input.shape[1], w = input.shape[2];
    final crops = await Isolate.run(() => cutOut(image, boxes, w, h));
    return [for (final rgb in crops) _run(rgb, w, h)];
  }

  List<(String, double)> _run(Uint8List rgb, int w, int h) {
    final input = _interpreter.getInputTensor(0);
    final output = _interpreter.getOutputTensor(0);
    final isFloat = input.type == TensorType.float32;
    final pixels = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final i = (y * w + x) * 3;
        return isFloat ? [rgb[i] / 255.0, rgb[i + 1] / 255.0, rgb[i + 2] / 255.0] : [rgb[i], rgb[i + 1], rgb[i + 2]];
      }),
    );
    final n = output.shape.last;
    final out = [output.type == TensorType.float32 ? List<double>.filled(n, 0) : List<int>.filled(n, 0)];
    _interpreter.run([pixels], out);
    final q = output.params;
    final quantized = output.type != TensorType.float32 && q.scale != 0;
    final scores = toProbabilities(
      out.first.cast<num>(),
      scale: quantized ? q.scale : 1,
      zeroPoint: quantized ? q.zeroPoint : 0,
    );
    final idx = [for (var i = 0; i < scores.length; i++) i]..sort((a, b) => scores[b].compareTo(scores[a]));
    return [
      for (final i in idx.take(3))
        if (i < _labels.length && _labels[i].isNotEmpty) (_labels[i], scores[i]),
    ];
  }

  /// Each box cut from the upright centre square of the photo, a little
  /// wider than the box (context helps), resized to the model's input.
  static List<Uint8List> cutOut(Uint8List bytes, List<Rect> boxes, int w, int h) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];
    final up = img.bakeOrientation(decoded);
    final side = math.min(up.width, up.height);
    final x0 = (up.width - side) ~/ 2, y0 = (up.height - side) ~/ 2;
    return [
      for (final b in boxes)
        () {
          final r = Rect.fromLTRB(
            (b.left - b.width * 0.05).clamp(0.0, 1.0),
            (b.top - b.height * 0.05).clamp(0.0, 1.0),
            (b.right + b.width * 0.05).clamp(0.0, 1.0),
            (b.bottom + b.height * 0.05).clamp(0.0, 1.0),
          );
          final crop = img.copyCrop(
            up,
            x: x0 + (side * r.left).round(),
            y: y0 + (side * r.top).round(),
            width: math.max(1, (side * r.width).round()),
            height: math.max(1, (side * r.height).round()),
          );
          final small = img.copyResize(crop, width: w, height: h, interpolation: img.Interpolation.average);
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
        }(),
    ];
  }
}

/// Model outputs as probabilities: dequantised, then softmax if they are
/// raw scores (some exports leave the softmax out), else normalised.
List<double> toProbabilities(List<num> raw, {double scale = 1, int zeroPoint = 0}) {
  final v = [for (final r in raw) (r - zeroPoint) * scale.toDouble()];
  if (v.isEmpty) return v;
  final sum = v.fold(0.0, (a, b) => a + b);
  final looksLikeProbs = v.every((x) => x >= 0 && x <= 1.0001) && (sum - 1).abs() < 0.05;
  if (looksLikeProbs) return v;
  if (v.every((x) => x >= 0) && sum > 0 && v.every((x) => x <= 1.0001)) return [for (final x in v) x / sum];
  final m = v.reduce(math.max);
  final e = [for (final x in v) math.exp(x - m)];
  final s = e.fold(0.0, (a, b) => a + b);
  return [for (final x in e) x / s];
}
