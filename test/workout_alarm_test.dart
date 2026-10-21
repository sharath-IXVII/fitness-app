import 'package:fitalarm/features/alarm/domain/workout_alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday 21 Oct 2026, 07:30.
  final now = DateTime(2026, 10, 21, 7, 30);

  WorkoutAlarm alarm(int h, int m, [Set<int> days = const {}]) => WorkoutAlarm(
    id: 1,
    time: TimeOfDay(hour: h, minute: m),
    routineId: 'beginner',
    days: days,
  );

  test('one-off alarm rings later today, or tomorrow if the time has passed', () {
    expect(alarm(8, 0).nextOccurrence(now), DateTime(2026, 10, 21, 8, 0));
    expect(alarm(6, 0).nextOccurrence(now), DateTime(2026, 10, 22, 6, 0));
    expect(alarm(7, 30).nextOccurrence(now), DateTime(2026, 10, 22, 7, 30));
  });

  test('repeating alarm skips days that are not selected', () {
    const weekends = {6, 7};
    expect(alarm(6, 0, weekends).nextOccurrence(now), DateTime(2026, 10, 24, 6, 0));
    // Wednesday only, time already passed today → next Wednesday.
    expect(alarm(6, 0, {3}).nextOccurrence(now), DateTime(2026, 10, 28, 6, 0));
    expect(alarm(9, 0, {3}).nextOccurrence(now), DateTime(2026, 10, 21, 9, 0));
  });

  test('handles month boundaries', () {
    final endOfMonth = DateTime(2026, 10, 31, 23, 0);
    expect(alarm(6, 0).nextOccurrence(endOfMonth), DateTime(2026, 11, 1, 6, 0));
  });

  test('day labels', () {
    expect(alarm(6, 0).daysLabel, 'Once');
    expect(alarm(6, 0, {1, 2, 3, 4, 5, 6, 7}).daysLabel, 'Every day');
    expect(alarm(6, 0, {1, 2, 3, 4, 5}).daysLabel, 'Weekdays');
    expect(alarm(6, 0, {6, 7}).daysLabel, 'Weekends');
    expect(alarm(6, 0, {5, 1}).daysLabel, 'Mon, Fri');
  });

  test('json round-trip', () {
    final a = alarm(5, 45, {1, 3});
    expect(WorkoutAlarm.fromJson(a.toJson()).toJson(), a.toJson());
  });

  test('skip next silences exactly one occurrence', () {
    final daily = alarm(6, 0, {1, 2, 3, 4, 5, 6, 7});
    final next = daily.upcomingIgnoringSkip(now);
    expect(next, DateTime(2026, 10, 22, 6, 0));
    final skipped = daily.copyWith(skipDate: DateTime(2026, 10, 22));
    expect(skipped.nextOccurrence(now), DateTime(2026, 10, 23, 6, 0));
    expect(skipped.isSkipping(now), isTrue);
    expect(skipped.isSkipping(DateTime(2026, 10, 23)), isFalse);
    expect(skipped.copyWith(clearSkip: true).nextOccurrence(now), next);
  });

  test('hard mode removes snoozes', () {
    final a = alarm(6, 0).copyWith(maxSnoozes: 3);
    expect(a.allowedSnoozes, 3);
    expect(a.copyWith(hardMode: true).allowedSnoozes, 0);
  });

  test('all settings survive json, and old saves get defaults', () {
    final a = alarm(6, 15, {2}).copyWith(
      sound: AlarmSound.bells,
      volume: 0.6,
      fadeIn: false,
      vibrate: false,
      maxSnoozes: 2,
      snoozeMinutes: 10,
      hardMode: true,
      skipDate: DateTime(2026, 10, 27),
    );
    expect(WorkoutAlarm.fromJson(a.toJson()).toJson(), a.toJson());

    final legacy = WorkoutAlarm.fromJson({'id': 3, 'time': 360, 'days': [], 'routine': 'beginner'});
    expect(legacy.sound, AlarmSound.sunrise);
    expect(legacy.maxSnoozes, 1);
    expect(legacy.hardMode, isFalse);
  });
}
