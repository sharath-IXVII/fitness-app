import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/arcs/domain/arc.dart';

/// Switches the Android launcher icon to the current arc's version
/// (Winter, Revolution, Summer, Monsoon). The change is made only when the
/// arc actually changes, because launchers briefly refresh when it happens.
abstract final class LauncherIcon {
  static const _channel = MethodChannel('fittiepi/icon');
  static const _key = 'launcher.icon.v1';

  static Future<void> sync(SharedPreferences prefs, Season season) async {
    if (kIsWeb || !Platform.isAndroid) return;
    // The manifest starts with Winter enabled.
    final current = prefs.getString(_key) ?? Season.winter.name;
    if (current == season.name) return;
    try {
      final ok = await _channel.invokeMethod<bool>('set', season.name);
      if (ok == true) await prefs.setString(_key, season.name);
    } on PlatformException catch (e) {
      debugPrint('launcher icon: $e');
    } on MissingPluginException {
      // Tests and other platforms.
    }
  }
}
