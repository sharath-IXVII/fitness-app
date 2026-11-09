import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;

/// Web and other platforms without dart:ffi have no on-device food model.
Future<Future<List<(String, double, Rect?)>> Function(Uint8List)?> loadFoodModel() async => null;
