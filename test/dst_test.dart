// Run under a timezone with daylight saving to catch 23/25-hour days:
//   TZ=Europe/Berlin flutter test test/dst_test.dart
import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/progress/domain/progress.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _ok = DayScore({DailyTask.workout, DailyTask.water, DailyTask.steps});

void main() {
  test('streaks run straight through the autumn and spring clock changes', () {
    for (final (from, to) in [
      (DateTime(2026, 10, 20), DateTime(2026, 11, 5)), // EU 25 Oct, US 1 Nov
      (DateTime(2027, 3, 20), DateTime(2027, 4, 5)), // EU 28 Mar
      (DateTime(2027, 3, 5), DateTime(2027, 3, 20)), // US 14 Mar
    ]) {
      final days = daysBetween(from, to) + 1;
      final scores = {for (var i = 0; i < days; i++) addDays(from, i): _ok};
      expect(currentStreak(scores, to), days, reason: '$from');
      expect(longestStreak(scores), days, reason: '$from');
      expect(totalXp(scores), greaterThan(0));
    }
  });

  test('day helpers are calendar days', () {
    expect(addDays(DateTime(2026, 10, 26), -1), DateTime(2026, 10, 25));
    expect(daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 23)), 22);
    expect(daysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 29)), 2);
    final winter = ArcPeriod.of(DateTime(2026, 11, 2));
    expect(daysBetween(winter.start, DateTime(2026, 11, 2)) + 1, 33);
  });
}
