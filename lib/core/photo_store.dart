import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Meal and snap photos live only in the app's private storage on this
/// phone. They are never uploaded, are deleted after 30 days, and go with
/// the app or with "Reset data".
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

  /// How long meal and snap photos are kept on the phone.
  static const keepFor = Duration(days: 30);

  /// Deletes photos older than [keepFor], so they never fill the phone.
  /// Run once when the app starts.
  static Future<int> deleteOld({DateTime? now}) async {
    if (!supported) return 0;
    try {
      return await deleteOlderThan(await _folder(), (now ?? DateTime.now()).subtract(keepFor));
    } catch (e) {
      debugPrint('photo cleanup failed: $e');
      return 0;
    }
  }

  /// Deletes files in [dir] last changed before [cutoff]; returns how many.
  @visibleForTesting
  static Future<int> deleteOlderThan(Directory dir, DateTime cutoff) async {
    var n = 0;
    if (!await dir.exists()) return 0;
    await for (final e in dir.list()) {
      if (e is File && (await e.lastModified()).isBefore(cutoff)) {
        await e.delete();
        n++;
      }
    }
    return n;
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
