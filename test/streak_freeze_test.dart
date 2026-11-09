import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scores for [days] (counted back from today = 0): true = goals kept.
Map<DateTime, DayScore> _history(DateTime today, List<bool> oldestFirst) {
  final full = DayScore({...DailyTask.values});
  return {
    for (final (i, kept) in oldestFirst.indexed)
      if (kept) addDays(dayOnly(today), i - oldestFirst.length + 1): full,
  };
}

void main() {
  final today = DateTime(2026, 11, 9, 20);

  test('7 days in a row earn a freeze that covers a missed day', () {
    // 7 kept, 1 missed, 3 kept (today included).
    final s = streakWithFreezes(_history(today, [...List.filled(7, true), false, true, true, true]), today);
    expect(s.current, 10); // the frozen day isn't counted, but the streak goes on
    expect(s.freezes, 0); // used up
    expect(s.frozen, hasLength(1));
  });

  test('without a freeze, a missed day ends the streak', () {
    final s = streakWithFreezes(_history(today, [...List.filled(5, true), false, true, true]), today);
    expect(s.current, 2);
    expect(s.longest, 5);
    expect(s.frozen, isEmpty);
  });

  test('at most 2 freezes are kept, and two misses in a row use both', () {
    final s = streakWithFreezes(_history(today, [...List.filled(21, true), false, false, true]), today);
    expect(s.current, 22);
    expect(s.freezes, 0);
    final saved = streakWithFreezes(_history(today, List.filled(21, true)), today);
    expect(saved.freezes, 2); // 3 earned, 2 kept
  });

  test('today, not done yet, never uses a freeze', () {
    final s = streakWithFreezes(_history(today, [...List.filled(7, true), false]), today);
    expect(s.current, 7);
    expect(s.freezes, 1);
    expect(s.frozen, isEmpty);
  });
}
