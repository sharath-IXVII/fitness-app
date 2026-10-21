import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Meal photos live only in the app's private storage on this phone. They
/// are never uploaded for storage (a scan sends the photo once for analysis
/// and keeps nothing on the server), and they are deleted with the app or
/// with "Reset data".
abstract final class PhotoStore {
  static Directory? _dir;

  static bool get supported => !kIsWeb;

  static Future<Directory> _folder() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    return _dir = await Directory('${base.path}/meal_photos').create(recursive: true);
  }

  /// Saves [bytes] as [name] (e.g. "abc123.jpg") and returns the name.
  static Future<String?> save(String name, Uint8List bytes) async {
    if (!supported) return null;
    try {
      await File('${(await _folder()).path}/$name').writeAsBytes(bytes, flush: true);
      return name;
    } catch (e) {
      debugPrint('photo save failed: $e');
      return null;
    }
  }

  /// The file for [name], or null if it's gone.
  static Future<File?> file(String name) async {
    if (!supported) return null;
    try {
      final f = File('${(await _folder()).path}/$name');
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String name) async {
    final f = await file(name);
    if (f != null) await f.delete();
  }

  static Future<void> clearAll() async {
    if (!supported) return;
    try {
      final d = await _folder();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
