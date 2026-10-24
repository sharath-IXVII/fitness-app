import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_scheduler.dart';

/// Strict alarm mode, from the moment it rings until the workout or brain
/// game is finished:
///
/// - full screen with the system bars hidden;
/// - leaving the app (home, recents, another app) brings it straight back
///   (Android, needs "Display over other apps");
/// - the screen is pinned where the system allows it;
/// - the volume keys can't lower the alarm (see [AlarmScheduler]);
/// - if the phone is switched off, the alarm rings again after it restarts.
///
/// What no app can do: block the power button or a forced restart. Those are
/// reserved to the system, so strict mode makes the alarm come back instead.
abstract final class StrictMode {
  static const _channel = MethodChannel('fittiepi/strict');

  /// Saved while a strict alarm is unresolved. Read natively after a reboot
  /// (see StrictBootReceiver.kt), so keep the key in sync.
  static const activeKey = 'strict.active.v1';

  static bool get _android => !kIsWeb && Platform.isAndroid;

  static Future<void> engage(SharedPreferences prefs, RingInfo info) async {
    await prefs.setString(activeKey, info.toPayload());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    if (_android) await _call('engage');
  }

  static Future<void> release(SharedPreferences prefs) async {
    await prefs.remove(activeKey);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    if (_android) await _call('release');
  }

  /// The strict alarm that was interrupted before it was finished, if any.
  static RingInfo? pending(SharedPreferences prefs) => RingInfo.fromPayload(prefs.getString(activeKey));

  static bool isActive(SharedPreferences prefs) => prefs.containsKey(activeKey);

  /// Needed on Android for the app to bring itself back to the front.
  static Future<bool> canReopenItself() async {
    if (!_android) return true;
    return await _call<bool>('canDrawOverlays') ?? false;
  }

  static Future<void> openReopenSettings() async {
    if (_android) await _call('openOverlaySettings');
  }

  /// Runs [action] (a permission dialog, a settings page) without strict
  /// mode pulling the app back on top of it.
  static Future<T> whileAway<T>(Future<T> Function() action) async {
    if (_android) await _call('suspend');
    try {
      return await action();
    } finally {
      if (_android) await _call('resume');
    }
  }

  static Future<T?> _call<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException catch (e) {
      debugPrint('strict mode $method failed: $e');
    } on MissingPluginException {
      // Tests and platforms without the native side.
    }
    return null;
  }
}
