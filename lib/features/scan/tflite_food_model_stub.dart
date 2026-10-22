import 'package:flutter/foundation.dart';

/// Web and other platforms without dart:ffi have no on-device food model.
Future<Future<List<(String, double)>> Function(Uint8List)?> loadFoodModel() async => null;
