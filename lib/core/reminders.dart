import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../features/myday/domain/day_block.dart';

/// Storage keys shared with the background notification handler, which runs
/// in its own isolate and can't use providers.
abstract final class ReminderKeys {
  static final _date = DateFormat('yyyy-MM-dd');
  static String done(DateTime day) => 'myday.done.v1.${_date.format(day)}';
  static String log(DateTime day) => 'log.v1.${_date.format(day)}';
}

/// Local notifications for My Day blocks and water reminders.
///
/// Every reminder carries action buttons ("Done", "Snooze 10 min",
/// "+250 ml") that work straight from the notification shade, even when
/// the app is closed.
abstract final class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // Id ranges so each group can be cleared without touching the others.
  static const _blockBase = 100000;
  static const _waterBase = 200000;
  static const _snoozeBase = 300000;
  static const _workoutBase = 400000;
  static const _workoutEnd = 500000;

  /// Days ahead that one-off reminders are scheduled for. They are
  /// re-planned whenever the app opens, so this only matters if the app
  /// isn't opened for a while.
  static const daysAhead = 7;

  /// Storage key for today's water goal, read by the background handler to
  /// stop water reminders once the goal is reached.
  static const waterGoalKey = 'water.goal.ml.v1';

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _routineChannel = AndroidNotificationDetails(
    'routine',
    'My Day reminders',
    channelDescription: 'Reminders for the items in your daily routine',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_notify',
    actions: [
      AndroidNotificationAction('done', 'Done ✓', showsUserInterface: false),
      AndroidNotificationAction('snooze', 'Snooze 10 min', showsUserInterface: false),
    ],
  );

  static const _waterChannel = AndroidNotificationDetails(
    'water',
    'Water reminders',
    channelDescription: 'Regular nudges to drink water',
    importance: Importance.defaultImportance,
    icon: 'ic_stat_notify',
    actions: [
      AndroidNotificationAction('water_250', 'Yes, I had a glass ✓', showsUserInterface: false),
      AndroidNotificationAction('water_500', '+500 ml', showsUserInterface: false),
    ],
  );

  static const _workoutChannel = AndroidNotificationDetails(
    'workout',
    'Workout reminders',
    channelDescription: 'A daily nudge for your workout or 30-day challenge',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_notify',
  );

  /// Called in the foreground isolate when a reminder or action is tapped.
  static void Function()? onChanged;

  static Future<void> init() async {
    if (!supported || _ready) return;
    await _initTimeZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) async {
        await handleAction(r.actionId, r.payload);
        onChanged?.call();
      },
      onDidReceiveBackgroundNotificationResponse: reminderBackgroundHandler,
    );
    _ready = true;
  }

  static Future<void> _initTimeZone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<bool> requestPermission() async {
    if (!supported) return true;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: true) ?? false;
  }

  static Future<void> _cancelRange(int from, int to) async {
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= from && p.id < to) await _plugin.cancel(id: p.id);
    }
  }

  /// Next occurrence of [minuteOfDay] on ISO [weekday], from now.
  static tz.TZDateTime _next(int weekday, int minuteOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var dayShift = 0;
    var m = minuteOfDay;
    if (m < 0) {
      // A lead time that crosses midnight belongs to the previous day.
      m += 24 * 60;
      dayShift = -1;
    }
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, m ~/ 60, m % 60);
    final target = ((weekday - 1 + dayShift) % 7) + 1;
    while (d.weekday != target || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Replaces all My Day reminders with weekly ones for [blocks].
  static Future<void> scheduleBlocks(List<DayBlock> blocks, {required bool enabled}) async {
    if (!supported) return;
    await init();
    await _cancelRange(_blockBase, _waterBase);
    if (!enabled) return;
    for (final b in blocks.where((b) => b.remind)) {
      for (final day in b.days) {
        await _plugin.zonedSchedule(
          id: _blockBase + b.id * 8 + day,
          title: _title(b),
          body: _body(b),
          scheduledDate: _next(day, b.remindMinute),
          notificationDetails: const NotificationDetails(android: _routineChannel, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: jsonEncode({'type': 'block', 'id': b.id, 'title': _title(b), 'body': _body(b)}),
        );
      }
    }
  }

  static String _title(DayBlock b) => switch (b.kind) {
    BlockKind.wake => 'Good morning ☀️',
    BlockKind.water => 'Time for water 💧',
    BlockKind.sleep => 'Wind down for bed 🌙',
    _ when b.kind.isMeal => '${b.name} time 🍽️',
    BlockKind.workout => 'Workout time 💪',
    _ => b.name,
  };

  static String _body(DayBlock b) {
    final at = '${b.time.hour.toString().padLeft(2, '0')}:${b.time.minute.toString().padLeft(2, '0')}';
    if (b.leadMinutes > 0) return '${b.name} starts in ${b.leadMinutes} min ($at)';
    return switch (b.kind) {
      BlockKind.water => 'A glass now keeps you on track for today.',
      _ when b.kind.isMeal => 'Log what you eat to hit your protein target.',
      BlockKind.sleep => 'A good night makes tomorrow\'s alarm easier.',
      _ => b.minutes > 0 ? '$at · ${b.minutes} min' : at,
    };
  }

  static String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Water nudges every [everyMinutes] between [from] and [to] for the next
  /// [daysAhead] days. [skipToday] when today's goal is already reached.
  static Future<void> scheduleWater({
    required TimeOfDay from,
    required TimeOfDay to,
    required int everyMinutes,
    required bool enabled,
    bool skipToday = false,
  }) async {
    if (!supported) return;
    await init();
    await _cancelRange(_waterBase, _snoozeBase);
    if (!enabled) return;
    final slots = waterSlots(from, to, everyMinutes);
    final now = tz.TZDateTime.now(tz.local);
    for (var d = skipToday ? 1 : 0; d < daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      for (final (i, m) in slots.indexed) {
        final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, m ~/ 60, m % 60);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _waterBase + d * 100 + i,
          title: 'Time for water 💧',
          body: 'Had a glass? Tap "Yes" and it\'s logged.',
          scheduledDate: at,
          notificationDetails: const NotificationDetails(android: _waterChannel, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({'type': 'water', 'day': _dayKey(day)}),
        );
      }
    }
  }

  /// Cancels the rest of today's water reminders (goal reached).
  static Future<void> cancelWaterToday() async {
    final today = _dayKey(DateTime.now());
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id < _waterBase || p.id >= _snoozeBase) continue;
      try {
        if ((jsonDecode(p.payload ?? '{}') as Map)['day'] == today) await _plugin.cancel(id: p.id);
      } catch (_) {}
    }
  }

  /// One workout reminder a day at [minuteOfDay] for the next [daysAhead]
  /// days. [title] and [body] give the text per day; return null to skip a
  /// day (already worked out, or a rest day).
  static Future<void> scheduleWorkout({
    required int minuteOfDay,
    required bool enabled,
    required (String, String)? Function(DateTime day) textFor,
  }) async {
    if (!supported) return;
    await init();
    await _cancelRange(_workoutBase, _workoutEnd);
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    for (var d = 0; d < daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);
      if (!at.isAfter(now)) continue;
      final text = textFor(day);
      if (text == null) continue;
      await _plugin.zonedSchedule(
        id: _workoutBase + d,
        title: text.$1,
        body: text.$2,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(android: _workoutChannel, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'type': 'workout'}),
      );
    }
  }

  /// Minutes-after-midnight for each water reminder.
  static List<int> waterSlots(TimeOfDay from, TimeOfDay to, int everyMinutes) {
    final start = from.hour * 60 + from.minute + 60; // first one an hour after waking
    final end = to.hour * 60 + to.minute - 60; // none in the last hour before bed
    return [for (var m = start; m <= end && everyMinutes > 0; m += everyMinutes) m];
  }

  /// Applies a notification action. Safe to call from any isolate.
  static Future<void> handleAction(String? action, String? payload) async {
    if (action == null || payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final today = DateTime.now();

    switch (action) {
      case 'done':
        final key = ReminderKeys.done(today);
        final done = {...(jsonDecode(prefs.getString(key) ?? '[]') as List).cast<int>(), data['id'] as int};
        await prefs.setString(key, jsonEncode(done.toList()));
      case 'snooze':
        await _ensureInBackground();
        await _plugin.zonedSchedule(
          id: _snoozeBase + (data['id'] as int),
          title: data['title'] as String?,
          body: data['body'] as String?,
          scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
          notificationDetails: const NotificationDetails(android: _routineChannel, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      case 'water_250' || 'water_500':
        final key = ReminderKeys.log(today);
        final log = jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
        final water = (log['water'] as int? ?? 0) + (action == 'water_250' ? 250 : 500);
        log['water'] = water;
        await prefs.setString(key, jsonEncode(log));
        // Goal reached: no more water nudges today.
        final goal = prefs.getInt(waterGoalKey);
        if (goal != null && water >= goal) {
          await _ensureInBackground();
          await cancelWaterToday();
        }
    }
  }

  static Future<void> _ensureInBackground() async {
    if (_ready) return;
    await _initTimeZone();
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
    );
    _ready = true;
  }
}

/// Entry point for notification actions tapped while the app isn't running.
@pragma('vm:entry-point')
Future<void> reminderBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Reminders.handleAction(response.actionId, response.payload);
}
