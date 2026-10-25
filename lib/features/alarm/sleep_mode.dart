import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One night's Sleep mode.
class SleepSession {
  const SleepSession({required this.end, required this.block, this.boot});

  /// When Sleep mode ends by itself.
  final DateTime end;

  /// Block other apps (calls and the dialer stay available).
  final bool block;

  /// The phone's boot counter when it started. A different value later means
  /// the phone was restarted, which releases Sleep mode.
  final int? boot;
}

/// Sleep mode, from the bedtime alarm until the chosen end time (3:00 AM by
/// default).
///
/// - the app shows a calm night screen;
/// - with "block other apps" on, leaving the app brings it back (Android,
///   needs "Display over other apps"), except for phone calls, the dialer
///   and emergency numbers, which are never covered;
/// - there is no exit button. A restart of the phone releases it, and so
///   does the end time; the screen says so.
abstract final class SleepMode {
  static const _channel = MethodChannel('fittiepi/strict');
  static const activeKey = 'sleep.active.v1';

  static bool get _android => !kIsWeb && Platform.isAndroid;

  static Future<void> start(SharedPreferences prefs, {required DateTime end, required bool block}) async {
    final boot = _android ? await _call<int>('bootCount') : null;
    await prefs.setString(activeKey, jsonEncode({'end': end.millisecondsSinceEpoch, 'block': block, 'boot': ?boot}));
    if (_android && block) await _call('engageSleep', end.millisecondsSinceEpoch);
  }

  static Future<void> release(SharedPreferences prefs) async {
    await prefs.remove(activeKey);
    if (_android) await _call('releaseSleep');
  }

  static SleepSession? current(SharedPreferences prefs) {
    try {
      final j = jsonDecode(prefs.getString(activeKey) ?? '') as Map<String, dynamic>;
      return SleepSession(
        end: DateTime.fromMillisecondsSinceEpoch(j['end'] as int),
        block: j['block'] as bool? ?? false,
        boot: j['boot'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Run when the app starts: ends a session whose time has passed or that
  /// the phone's restart released, and re-arms a live one (the app's process
  /// may have been restarted). Returns the session still in force, if any.
  static Future<SleepSession?> reconcile(SharedPreferences prefs, {DateTime? now}) async {
    final s = current(prefs);
    if (s == null) return null;
    final boot = _android ? await _call<int>('bootCount') : null;
    final restarted = s.boot != null && boot != null && boot != s.boot;
    if (!s.end.isAfter(now ?? DateTime.now()) || restarted) {
      await release(prefs);
      return null;
    }
    if (_android && s.block) await _call('engageSleep', s.end.millisecondsSinceEpoch);
    return s;
  }

  /// Opens the phone's dialer, optionally with [number] typed in. The user
  /// still has to press call. The dialer is not covered while it is open.
  static Future<void> openDialer([String? number]) async {
    if (_android) await _call('openDialer', number);
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('sleep mode $method failed: $e');
    } on MissingPluginException {
      // Tests and platforms without the native side.
    }
    return null;
  }
}
