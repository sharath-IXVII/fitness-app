import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permissions the workout alarm depends on.
abstract final class AppPermissions {
  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static List<Permission> get _alarm => [
    Permission.notification,
    if (!kIsWeb && Platform.isAndroid) Permission.scheduleExactAlarm,
  ];

  /// True when notifications, exact alarms and the camera are all allowed.
  static Future<bool> allGranted() async {
    if (!_mobile) return true;
    for (final p in [..._alarm, Permission.camera]) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  /// Asks for everything at once. Returns whether all were granted.
  static Future<bool> requestAll() async {
    if (!_mobile) return true;
    for (final p in [..._alarm, Permission.camera]) {
      if (!await p.isGranted) await p.request();
    }
    // Battery optimisation can delay alarms on some phones; ask, but don't require it.
    if (Platform.isAndroid && !await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    return allGranted();
  }

  static Future<bool> camera() async {
    if (!_mobile) return false;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();
}
