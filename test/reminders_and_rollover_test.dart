import 'package:clock/clock.dart';
import 'package:fitalarm/core/reminders.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/arcs/arc_providers.dart';
import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/training/domain/plans.dart';
import 'package:fitalarm/features/training/training_providers.dart';
import 'package:fitalarm/features/training/workout_reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('water reminders every 1.5 hours from an hour after waking to an hour before bed', () {
    final slots = Reminders.waterSlots(const TimeOfDay(hour: 6, minute: 30), const TimeOfDay(hour: 23, minute: 0), 90);
    expect(slots.first, 7 * 60 + 30);
    expect(slots[1] - slots[0], 90);
    expect(slots.last, lessThanOrEqualTo(22 * 60));
    expect(slots, hasLength(10));
  });

  test('late sleepers (bed after midnight) still get water reminders', () {
    final slots = Reminders.waterSlots(const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 1, minute: 0), 90);
    expect(slots.first, 10 * 60);
    expect(slots.last, lessThanOrEqualTo(24 * 60));
    expect(slots.length, greaterThan(8));
  });

  group('workout reminder text', () {
    final today = DateTime(2026, 10, 23);

    test('quiet once today\'s workout is done', () {
      expect(
        workoutReminderText(day: today, today: today, doneToday: true, challenges: const {}, arcName: 'Winter Arc'),
        isNull,
      );
      expect(
        workoutReminderText(
          day: today.add(const Duration(days: 1)),
          today: today,
          doneToday: true,
          challenges: const {},
          arcName: 'Winter Arc',
        ),
        isNotNull,
      );
    });

    test('names the next challenge day, or the rest day', () {
      final day6 = workoutReminderText(
        day: today,
        today: today,
        doneToday: false,
        challenges: {
          'abs30': const ChallengeProgress(level: Level.beginner, done: {1, 2, 3, 4, 5}),
        },
        arcName: 'Winter Arc',
      )!;
      expect(day6.$1, 'Day 6 is ready 💪');
      expect(day6.$2, contains('Abs in 30 days'));

      final rest = workoutReminderText(
        day: today,
        today: today,
        doneToday: false,
        challenges: {
          'abs30': const ChallengeProgress(level: Level.beginner, done: {1, 2, 3}),
        },
        arcName: 'Winter Arc',
      )!;
      expect(rest.$1, contains('Rest day'));
    });

    test('without a challenge it mentions the arc', () {
      final t = workoutReminderText(
        day: today,
        today: today,
        doneToday: false,
        challenges: const {},
        arcName: 'Rise of Revolution',
      )!;
      expect(t.$2, contains('Rise of Revolution'));
    });
  });

  test('just after midnight on 31 December the app moves to the next arc, no update needed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 12, 31, 23, 59);
    await withClock(Clock(() => now), () async {
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      expect(c.read(currentArcProvider).label, 'Winter Arc 2026');
      expect(c.read(themeSeasonProvider), Season.winter);

      now = DateTime(2027, 1, 1, 0, 0, 5); // the midnight refresh fires
      c.read(todayProvider.notifier).refresh();
      expect(c.read(currentArcProvider).label, 'Rise of Revolution 2027');
      expect(c.read(themeSeasonProvider), Season.revolution);

      // And on through the year.
      for (final (date, name) in [
        (DateTime(2027, 4, 1), 'Summer Arc 2027'),
        (DateTime(2027, 7, 1), 'Monsoon Arc 2027'),
        (DateTime(2027, 10, 1), 'Winter Arc 2027'),
      ]) {
        now = date;
        c.read(todayProvider.notifier).refresh();
        expect(c.read(currentArcProvider).label, name);
      }
    });
  });
}
