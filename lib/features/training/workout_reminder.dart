import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reminders.dart';
import '../../core/storage.dart';
import '../arcs/arc_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/plans.dart';
import 'training_providers.dart';

class WorkoutReminderSettings {
  const WorkoutReminderSettings({this.enabled = true, this.minute = 18 * 60 + 30});

  final bool enabled;

  /// Minutes after midnight.
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
}

/// A daily workout nudge. It names the next 30-day challenge day, and stays
/// quiet on days the workout is already done.
class WorkoutReminderNotifier extends Notifier<WorkoutReminderSettings> {
  static const _onKey = 'workout.remind.v1';
  static const _atKey = 'workout.remind.at.v1';

  @override
  WorkoutReminderSettings build() {
    final p = ref.read(sharedPrefsProvider);
    return WorkoutReminderSettings(enabled: p.getBool(_onKey) ?? true, minute: p.getInt(_atKey) ?? 18 * 60 + 30);
  }

  Future<void> set({bool? enabled, TimeOfDay? time}) async {
    state = WorkoutReminderSettings(
      enabled: enabled ?? state.enabled,
      minute: time == null ? state.minute : time.hour * 60 + time.minute,
    );
    final p = ref.read(sharedPrefsProvider);
    await p.setBool(_onKey, state.enabled);
    await p.setInt(_atKey, state.minute);
    if (state.enabled) await Reminders.requestPermission();
    await reschedule();
  }

  Future<void> reschedule() async {
    final today = ref.read(todayProvider);
    final doneToday = ref.read(todayLogProvider).workoutDone;
    final training = ref.read(trainingProvider);
    final arc = ref.read(currentArcProvider);
    await Reminders.scheduleWorkout(
      minuteOfDay: state.minute,
      enabled: state.enabled,
      textFor: (day) => workoutReminderText(
        day: day,
        today: today,
        doneToday: doneToday,
        challenges: training.challenges,
        arcName: arc.season.title,
      ),
    );
  }
}

final workoutReminderProvider = NotifierProvider<WorkoutReminderNotifier, WorkoutReminderSettings>(
  WorkoutReminderNotifier.new,
);

/// The reminder for [day]: null to stay quiet. Pure, for tests.
(String, String)? workoutReminderText({
  required DateTime day,
  required DateTime today,
  required bool doneToday,
  required Map<String, ChallengeProgress> challenges,
  required String arcName,
}) {
  final isToday = day == today;
  if (isToday && doneToday) return null;
  for (final e in challenges.entries) {
    final c = challengeById(e.key);
    final next = e.value.nextDay;
    if (c == null || next == null) continue;
    if (!isToday) return ('Keep your challenge going 💪', '${c.title}: your next day is waiting.');
    if (Challenge.isRestDay(next)) {
      return ('Rest day 😌', 'Day $next of ${c.title} is a rest day. Mark it done and stretch a little.');
    }
    return ('Day $next is ready 💪', '${c.title}: about ${c.workoutFor(next, e.value.level)!.minutes} minutes.');
  }
  return ('Workout time 💪', 'A quick session keeps your $arcName streak alive.');
}
