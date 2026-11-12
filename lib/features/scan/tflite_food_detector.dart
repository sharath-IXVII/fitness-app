import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'domain/recognition.dart';
import 'tflite_dish_classifier.dart';

/// A food detector trained for FittArc (see tools/food_model/README.md):
/// finds each dish on the plate with an exact box. Runs on the phone.
///
/// Expects the usual TFLite detection outputs: boxes [1, N, 4] (top, left,
/// bottom, right, 0–1), classes [1, N], scores [1, N] and a count [1]. The
/// classes and scores can come in either order; they are told apart by
/// their values.
class TfliteFoodDetector {
  TfliteFoodDetector._(this._interpreter, this._labels, this._dish, this._anchors);

  static const modelAsset = 'assets/models/food_detector.tflite';
  static const labelsAsset = 'assets/models/food_detector_labels.csv';

  /// SSD anchors (x, y, w, h as float32) for models exported without the
  /// box-decoding step (Model Maker leaves that to MediaPipe).
  static const anchorsAsset = 'assets/models/food_detector_anchors.bin';

  /// Detections less sure than this are left out.
  static const minScore = 0.35;

  /// The same for raw SSD outputs, whose scores run lower.
  static const rawMinScore = 0.25;

  final Interpreter _interpreter;
  final List<String> _labels;

  /// Step 2, naming each dish; null when the detector names dishes itself.
  final TfliteDishClassifier? _dish;

  /// Non-null when the model gives raw SSD outputs that we decode ourselves.
  final Float32List? _anchors;

  /// A detector that only finds "food" needs the dish classifier.
  static bool findsOnlyFood(List<String> labels) =>
      labels.where((l) => l.isNotEmpty && l != 'background').every((l) => l == 'food');

  static Future<TfliteFoodDetector?> load() async {
    if (kIsWeb) return null;
    try {
      final labels = parseLabels(await rootBundle.loadString(labelsAsset));
      final interpreter = await Interpreter.fromAsset(modelAsset, options: InterpreterOptions()..threads = 2);
      final outs = interpreter.getOutputTensors();
      Float32List? anchors;
      if (outs.length == 2) {
        // Raw SSD outputs: boxes [1, N, 4] and class scores [1, N, C].
        final data = await rootBundle.load(anchorsAsset);
        anchors = data.buffer.asFloat32List(data.offsetInBytes, data.lengthInBytes ~/ 4);
        final n = outs.firstWhere((t) => t.shape.last == 4).shape[1];
        if (anchors.length != n * 4) {
          noteFoodModel('detector', 'anchors ${anchors.length ~/ 4} vs boxes $n');
          return null;
        }
      } else if (outs.length < 3) {
        return null;
      }
      final dish = await TfliteDishClassifier.load();
      if (findsOnlyFood(labels) && dish == null) {
        noteFoodModel('detector', 'dish model missing');
        return null;
      }
      return TfliteFoodDetector._(interpreter, labels, findsOnlyFood(labels) ? dish : null, anchors);
    } catch (e) {
      // No detector in this build: the classifier is used.
      noteFoodModel('detector load', e);
      return null;
    }
  }

  Future<List<(String, double, Rect?)>> detect(Uint8List image) async {
    final input = _interpreter.getInputTensor(0);
    final h = input.shape[1], w = input.shape[2];
    final rgb = await Isolate.run(() => _square(image, w, h));
    if (rgb == null) return const [];
    final isFloat = input.type == TensorType.float32;
    final pixels = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final i = (y * w + x) * 3;
        return isFloat ? [rgb[i] / 255.0, rgb[i + 1] / 255.0, rgb[i + 2] / 255.0] : [rgb[i], rgb[i + 1], rgb[i + 2]];
      }),
    );
    final outs = _interpreter.getOutputTensors();
    final anchors = _anchors;
    if (anchors != null) {
      // Outputs are read from the tensors directly below.
      _interpreter.runInference([
        [pixels],
      ]);
      final bi = outs.indexWhere((t) => t.shape.last == 4);
      final si = 1 - bi;
      List<double> values(Tensor t) {
        final q = t.params;
        final quantized = t.type != TensorType.float32 && q.scale != 0;
        if (t.type == TensorType.float32) {
          return t.data.buffer.asFloat32List(t.data.offsetInBytes, t.data.lengthInBytes ~/ 4);
        }
        if (t.type == TensorType.int8) {
          return [
            for (final b in t.data.buffer.asInt8List(t.data.offsetInBytes, t.data.lengthInBytes))
              quantized ? (b - q.zeroPoint) * q.scale : b.toDouble(),
          ];
        }
        return [for (final b in t.data) quantized ? (b - q.zeroPoint) * q.scale : b.toDouble()];
      }

      final found = decodeSsd(
        values(_interpreter.getOutputTensor(bi)),
        values(_interpreter.getOutputTensor(si)),
        anchors,
        classes: outs[si].shape.last,
        minScore: rawMinScore,
      );
      final dish = _dish;
      final boxes = [for (final f in found.take(8)) f.$3];
      if (dish != null) return nameBoxes(boxes, await dish.classify(image, boxes));
      return [
        for (final (cls, score, box) in found)
          if (cls < _labels.length && _labels[cls].isNotEmpty) (_labels[cls], score, box),
      ];
    }
    final buffers = <int, Object>{
      for (final (i, t) in outs.indexed)
        i: t.shape.length == 3
            ? [List.generate(t.shape[1], (_) => List<double>.filled(t.shape[2], 0))]
            : t.shape.length == 2
            ? [List<double>.filled(t.shape[1], 0)]
            : List<double>.filled(t.shape.isEmpty ? 1 : t.shape[0], 0),
    };
    _interpreter.runForMultipleInputs([
      [pixels],
    ], buffers);
    final parsed = parseDetections([for (var i = 0; i < outs.length; i++) buffers[i]!], minScore: minScore);
    final dish = _dish;
    if (dish != null) {
      final boxes = [for (final p in keepDistinct(parsed).take(8)) p.$3];
      return nameBoxes(boxes, await dish.classify(image, boxes));
    }
    return [
      for (final (cls, score, box) in parsed)
        if (cls >= 0 && cls < _labels.length && _labels[cls].isNotEmpty) (_labels[cls], score, box),
    ];
  }

  static Uint8List? _square(Uint8List bytes, int w, int h) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final up = img.bakeOrientation(decoded);
    final side = up.width < up.height ? up.width : up.height;
    final crop = img.copyCrop(up, x: (up.width - side) ~/ 2, y: (up.height - side) ~/ 2, width: side, height: side);
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
  }
}

/// Reads detector outputs ([boxes, classes, scores, count] in any order)
/// into (class, score, box) for detections at least [minScore], best first.
/// Boxes are (top, left, bottom, right) fractions; returned as Rects.
@visibleForTesting
List<(int, double, Rect)> parseDetections(List<Object> outputs, {double minScore = 0.35}) {
  List<List<double>>? boxes;
  final lists = <List<double>>[];
  var count = -1;
  for (final o in outputs) {
    if (o is List &&
        o.isNotEmpty &&
        o.first is List &&
        (o.first as List).isNotEmpty &&
        (o.first as List).first is List) {
      boxes = [for (final b in (o.first as List)) (b as List).cast<double>()];
    } else if (o is List && o.isNotEmpty && o.first is List) {
      lists.add((o.first as List).cast<double>());
    } else if (o is List && o.isNotEmpty && o.first is double) {
      count = (o.first as double).round();
    }
  }
  if (boxes == null || lists.length < 2) return const [];
  // Classes are whole numbers; scores are fractions.
  bool whole(List<double> l) => l.every((v) => v == v.roundToDouble());
  final classes = whole(lists[0]) && !whole(lists[1]) ? lists[0] : lists[1];
  final scores = identical(classes, lists[0]) ? lists[1] : lists[0];
  final n = count >= 0 ? count.clamp(0, scores.length) : scores.length;
  final out = <(int, double, Rect)>[];
  for (var i = 0; i < n; i++) {
    if (scores[i] < minScore) continue;
    final b = boxes[i];
    final top = b[0].clamp(0.0, 1.0), left = b[1].clamp(0.0, 1.0);
    final bottom = b[2].clamp(0.0, 1.0), right = b[3].clamp(0.0, 1.0);
    if (bottom <= top || right <= left) continue;
    out.add((classes[i].round(), scores[i], Rect.fromLTRB(left, top, right, bottom)));
  }
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}

/// Drops boxes that mostly overlap a better one (the same dish found twice).
@visibleForTesting
List<(int, double, Rect)> keepDistinct(List<(int, double, Rect)> best, {double maxOverlap = 0.5}) {
  double iou(Rect a, Rect b) {
    final i = a.intersect(b);
    if (i.width <= 0 || i.height <= 0) return 0;
    final inter = i.width * i.height;
    return inter / (a.width * a.height + b.width * b.height - inter);
  }

  final out = <(int, double, Rect)>[];
  for (final d in best) {
    if (out.every((k) => iou(k.$3, d.$3) < maxOverlap)) out.add(d);
  }
  return out;
}

/// One guess per box from the dish classifier's top answer. Its second and
/// third answers come after, scored low, so the app offers them as
/// alternatives without putting them on the plate.
@visibleForTesting
List<(String, double, Rect?)> nameBoxes(List<Rect> boxes, List<List<(String, double)>> names) {
  final top = <(String, double, Rect?)>[];
  final alternatives = <(String, double, Rect?)>[];
  for (var i = 0; i < boxes.length && i < names.length; i++) {
    final n = names[i];
    if (n.isEmpty) continue;
    top.add((n.first.$1, n.first.$2, boxes[i]));
    for (final alt in n.skip(1)) {
      alternatives.add((alt.$1, alt.$2 * 0.1, boxes[i]));
    }
  }
  top.sort((a, b) => b.$2.compareTo(a.$2));
  return [...top, ...alternatives];
}

/// Decodes raw SSD outputs the way MediaPipe does: [raw] holds (dy, dx, dh, dw)
/// per anchor, [scores] one score per class per anchor (class 0 is
/// background), [anchors] (x, y, w, h) per anchor. Returns (class, score, box)
/// best first, overlapping boxes removed.
@visibleForTesting
List<(int, double, Rect)> decodeSsd(
  List<double> raw,
  List<double> scores,
  List<double> anchors, {
  required int classes,
  double minScore = 0.25,
  double maxOverlap = 0.5,
  int maxResults = 10,
}) {
  final n = anchors.length ~/ 4;
  final found = <(int, double, Rect)>[];
  for (var i = 0; i < n; i++) {
    var best = 0, bestScore = 0.0;
    for (var c = 1; c < classes; c++) {
      final s = scores[i * classes + c];
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    if (bestScore < minScore) continue;
    final ax = anchors[i * 4], ay = anchors[i * 4 + 1], aw = anchors[i * 4 + 2], ah = anchors[i * 4 + 3];
    final yc = raw[i * 4] * ah + ay, xc = raw[i * 4 + 1] * aw + ax;
    final h = math.exp(raw[i * 4 + 2]) * ah, w = math.exp(raw[i * 4 + 3]) * aw;
    final box = Rect.fromLTRB(
      (xc - w / 2).clamp(0.0, 1.0),
      (yc - h / 2).clamp(0.0, 1.0),
      (xc + w / 2).clamp(0.0, 1.0),
      (yc + h / 2).clamp(0.0, 1.0),
    );
    if (box.width <= 0.02 || box.height <= 0.02) continue;
    found.add((best, bestScore, box));
  }
  found.sort((a, b) => b.$2.compareTo(a.$2));
  return keepDistinct(found, maxOverlap: maxOverlap).take(maxResults).toList();
}
