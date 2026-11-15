import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reminders.dart';
import '../../core/storage.dart';
import '../arcs/arc_providers.dart';
import '../profile/profile_providers.dart';
import 'daily_log_providers.dart';
import 'domain/daily_log.dart';

/// The evening streak nudge: on by default at 8:00 PM.
class StreakReminderSettings {
  const StreakReminderSettings({this.enabled = true, this.minute = 20 * 60});

  final bool enabled;

  /// Minutes after midnight.
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
}

/// Nudges in the evening only when the day still needs goals to count, so
/// a streak is never lost just by forgetting. Quiet once 3 of 5 are done.
class StreakReminderNotifier extends Notifier<StreakReminderSettings> {
  static const key = 'streak.remind.v1';

  @override
  StreakReminderSettings build() {
    try {
      final j = jsonDecode(ref.read(sharedPrefsProvider).getString(key) ?? '{}') as Map<String, dynamic>;
      return StreakReminderSettings(enabled: j['on'] as bool? ?? true, minute: (j['m'] as num?)?.toInt() ?? 20 * 60);
    } catch (_) {
      return const StreakReminderSettings();
    }
  }

  Future<void> set({bool? enabled, int? minute}) async {
    state = StreakReminderSettings(enabled: enabled ?? state.enabled, minute: minute ?? state.minute);
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode({'on': state.enabled, 'm': state.minute}));
    if (state.enabled) await Reminders.requestPermission();
    await reschedule();
  }

  Future<void> reschedule() async {
    final targets = ref.read(targetsProvider);
    if (targets == null) return;
    final today = ref.read(todayProvider);
    final done = DayScore.of(ref.read(todayLogProvider), targets).count;
    final streak = ref.read(streakProvider).current;
    await Reminders.scheduleStreak(
      minuteOfDay: state.minute,
      enabled: state.enabled,
      textFor: (day) => streakReminderText(day: day, today: today, doneToday: done, streak: streak),
    );
  }
}

final streakReminderProvider = NotifierProvider<StreakReminderNotifier, StreakReminderSettings>(
  StreakReminderNotifier.new,
);

/// The nudge for [day]: null to stay quiet. [doneToday] is how many of the
/// five goals are done today and [streak] the streak so far. Pure, for tests.
(String, String)? streakReminderText({
  required DateTime day,
  required DateTime today,
  required int doneToday,
  required int streak,
}) {
  const needed = 3;
  if (day != today) {
    // Planned ahead in case the app isn't opened that day.
    return ('Keep your streak going 🔥', 'Hit 3 of your 5 goals before midnight. A few minutes is enough.');
  }
  if (doneToday >= needed) return null;
  final left = needed - doneToday;
  final goals = left == 1 ? '1 more goal keeps' : '$left more goals keep';
  if (streak > 0) {
    return ('Your $streak-day streak ends at midnight 🔥', '$goals it alive. You still have time.');
  }
  return ('Start a streak today 🔥', '$goals today on the board. You still have time.');
}
